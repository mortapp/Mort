-- The queue remains inert until both backend push gates and protected Vault
-- configuration are ready. pg_net dispatches asynchronously after commit.
create extension if not exists pg_net;

create or replace function private.invoke_send_push_cron()
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  project_url text;
  anon_key text;
  invoke_secret text;
begin
  if not coalesce(private.push_delivery_available(), false) then
    return null;
  end if;

  select secret.decrypted_secret into project_url
  from vault.decrypted_secrets secret
  where secret.name = 'mort_supabase_url'
  limit 1;

  select secret.decrypted_secret into anon_key
  from vault.decrypted_secrets secret
  where secret.name = 'mort_supabase_anon_key'
  limit 1;

  select secret.decrypted_secret into invoke_secret
  from vault.decrypted_secrets secret
  where secret.name = 'mort_send_push_invoke_secret'
  limit 1;

  if nullif(btrim(project_url), '') is null
     or nullif(btrim(anon_key), '') is null
     or nullif(btrim(invoke_secret), '') is null then
    return null;
  end if;

  -- The invoke secret must never be sent to a Vault-configured third-party URL.
  if project_url <> 'https://rakjydmgwwgtdislanbt.supabase.co' then
    return null;
  end if;

  return net.http_post(
    url := project_url || '/functions/v1/send-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'apikey', anon_key,
      'Authorization', 'Bearer ' || anon_key,
      'x-mort-push-secret', invoke_secret
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 5000
  );
end;
$$;

revoke all on function private.invoke_send_push_cron()
  from public, anon, authenticated, service_role;

do $$
declare
  existing_job_id bigint;
begin
  -- pg_cron names are unique per database role. Replace only this migration
  -- owner's job; a different role may legitimately use the same name.
  for existing_job_id in
    select jobid
    from cron.job
    where jobname = 'mort-send-push'
      and username = current_user
  loop
    perform cron.unschedule(existing_job_id);
  end loop;

  perform cron.schedule(
    'mort-send-push',
    '* * * * *',
    'select private.invoke_send_push_cron();'
  );
end;
$$;
