begin;

create extension if not exists pgtap with schema extensions;
set local search_path = extensions, public;

select plan(22);

create temporary table push_delivery_cron_fixture (
  queue_before bigint not null,
  disabled_request_id bigint,
  missing_vault_request_id bigint,
  wrong_host_request_id bigint,
  configured_request_id bigint
) on commit drop;

insert into push_delivery_cron_fixture (queue_before)
select count(*) from net.http_request_queue;

select is(
  (select count(*)::integer from cron.job
   where jobname = 'mort-send-push' and username = current_user),
  1,
  'the migration installs exactly one MORT push schedule for its database role'
);
select cron.schedule(
  'mort-send-push',
  '* * * * *',
  'select private.invoke_send_push_cron();'
);
select is(
  (select count(*)::integer from cron.job
   where jobname = 'mort-send-push' and username = current_user),
  1,
  'reapplying the named schedule keeps one job for its database role'
);
select is(
  (select schedule from cron.job
   where jobname = 'mort-send-push' and username = current_user),
  '* * * * *',
  'the MORT push worker is scheduled every minute'
);
select ok(
  (select active from cron.job
   where jobname = 'mort-send-push' and username = current_user),
  'the schedule is active; its function remains gated at invocation time'
);
select is(
  (select command from cron.job
   where jobname = 'mort-send-push' and username = current_user),
  'select private.invoke_send_push_cron();',
  'the schedule calls only the private guarded helper'
);
select ok(
  (select prosecdef from pg_proc where oid =
    'private.invoke_send_push_cron()'::regprocedure),
  'the private helper is SECURITY DEFINER'
);
select ok(
  (select coalesce(bool_or(replace(setting, '"', '') = 'search_path='), false)
   from pg_proc proc
   cross join lateral unnest(proc.proconfig) as config(setting)
   where proc.oid = 'private.invoke_send_push_cron()'::regprocedure),
  'the private helper pins an empty search_path'
);
select ok(
  not has_function_privilege('anon', 'private.invoke_send_push_cron()', 'EXECUTE'),
  'anonymous clients cannot invoke the scheduler helper'
);
select ok(
  not has_function_privilege('authenticated', 'private.invoke_send_push_cron()', 'EXECUTE'),
  'signed-in users cannot invoke the scheduler helper'
);
select ok(
  not has_function_privilege('service_role', 'private.invoke_send_push_cron()', 'EXECUTE'),
  'mobile/service clients cannot invoke the scheduler helper'
);

-- Keep release policy disabled and the runtime switch on to prove the policy
-- gate alone blocks HTTP. This entire test transaction is rolled back.
update private.pilot_policy_versions set remote_push = false where is_active;
update public.push_delivery_runtime set remote_push_enabled = true where singleton;
delete from vault.secrets
where name in ('mort_supabase_url', 'mort_supabase_anon_key', 'mort_send_push_invoke_secret');
select vault.create_secret(
  'https://rakjydmgwwgtdislanbt.supabase.co', 'mort_supabase_url', 'pgTAP placeholder', null
);
select vault.create_secret('dummy-anon-jwt', 'mort_supabase_anon_key', 'pgTAP placeholder', null);
select vault.create_secret(
  'dummy-invoke-secret', 'mort_send_push_invoke_secret', 'pgTAP placeholder', null
);
update push_delivery_cron_fixture set disabled_request_id = private.invoke_send_push_cron();
select is(
  (select disabled_request_id from push_delivery_cron_fixture),
  null::bigint,
  'the helper does not enqueue a request while release policy disables push'
);
select is(
  (select count(*)::bigint from net.http_request_queue),
  (select queue_before from push_delivery_cron_fixture),
  'the disabled policy does not write to the pg_net request queue'
);

-- Isolate the missing-Vault check: keep this mock inside the transaction and
-- roll it back with the rest of the test at the end of the file.
create or replace function private.push_delivery_available()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$ select true $$;

delete from vault.secrets
where name in ('mort_supabase_url', 'mort_supabase_anon_key', 'mort_send_push_invoke_secret');
update push_delivery_cron_fixture set missing_vault_request_id = private.invoke_send_push_cron();
select is(
  (select missing_vault_request_id from push_delivery_cron_fixture),
  null::bigint,
  'the helper does not enqueue a request when Vault credentials are missing'
);
select is(
  (select count(*)::bigint from net.http_request_queue),
  (select queue_before from push_delivery_cron_fixture),
  'missing Vault credentials do not write to the pg_net request queue'
);

select vault.create_secret('https://attacker.invalid', 'mort_supabase_url', 'pgTAP placeholder', null);
select vault.create_secret('dummy-anon-jwt', 'mort_supabase_anon_key', 'pgTAP placeholder', null);
select vault.create_secret(
  'dummy-invoke-secret', 'mort_send_push_invoke_secret', 'pgTAP placeholder', null
);
update push_delivery_cron_fixture set wrong_host_request_id = private.invoke_send_push_cron();
select is(
  (select wrong_host_request_id from push_delivery_cron_fixture),
  null::bigint,
  'the helper rejects a project URL outside the configured Supabase project'
);
select is(
  (select count(*)::bigint from net.http_request_queue),
  (select queue_before from push_delivery_cron_fixture),
  'an invalid project URL does not write to the pg_net request queue'
);

delete from vault.secrets
where name in ('mort_supabase_url', 'mort_supabase_anon_key', 'mort_send_push_invoke_secret');
select vault.create_secret(
  'https://rakjydmgwwgtdislanbt.supabase.co', 'mort_supabase_url', 'pgTAP placeholder', null
);
select vault.create_secret('dummy-anon-jwt', 'mort_supabase_anon_key', 'pgTAP placeholder', null);
select vault.create_secret(
  'dummy-invoke-secret', 'mort_send_push_invoke_secret', 'pgTAP placeholder', null
);
update push_delivery_cron_fixture set configured_request_id = private.invoke_send_push_cron();
select isnt(
  (select configured_request_id from push_delivery_cron_fixture),
  null::bigint,
  'complete Vault configuration queues the authenticated Edge Function request'
);
select is(
  (select count(*)::bigint from net.http_request_queue),
  (select queue_before + 1 from push_delivery_cron_fixture),
  'the configured path queues exactly one HTTP request'
);
select is(
  (select url from net.http_request_queue
   where id = (select configured_request_id from push_delivery_cron_fixture)),
  'https://rakjydmgwwgtdislanbt.supabase.co/functions/v1/send-push',
  'the queued request targets MORT send-push only'
);
select is(
  (select headers ->> 'x-mort-push-secret' from net.http_request_queue
   where id = (select configured_request_id from push_delivery_cron_fixture)),
  'dummy-invoke-secret',
  'the queued request includes the protected sender invoke header'
);
select is(
  (select headers ->> 'Authorization' from net.http_request_queue
   where id = (select configured_request_id from push_delivery_cron_fixture)),
  'Bearer dummy-anon-jwt',
  'the queued request uses the non-privileged anon JWT'
);
select is(
  (select headers ->> 'apikey' from net.http_request_queue
   where id = (select configured_request_id from push_delivery_cron_fixture)),
  'dummy-anon-jwt',
  'the queued request includes the anon API key'
);

select * from finish();
rollback;
