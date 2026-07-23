create table public.account_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  requester_fingerprint text not null,
  source text not null default 'in_app',
  status text not null default 'requested',
  identity_confirmed_at timestamptz not null,
  requested_at timestamptz not null default now(),
  processing_started_at timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz,
  retention_summary text,
  updated_at timestamptz not null default now(),
  constraint account_deletion_source_check
    check (source in ('in_app', 'web')),
  constraint account_deletion_status_check
    check (status in ('requested', 'processing', 'completed', 'cancelled')),
  constraint account_deletion_fingerprint_check
    check (requester_fingerprint ~ '^[0-9a-f]{64}$'),
  constraint account_deletion_retention_summary_length
    check (retention_summary is null or char_length(retention_summary) <= 1000)
);

create unique index account_deletion_one_open_request_idx
on public.account_deletion_requests(user_id)
where user_id is not null and status in ('requested', 'processing');

create index account_deletion_user_requested_idx
on public.account_deletion_requests(user_id, requested_at desc);

create index account_deletion_queue_idx
on public.account_deletion_requests(status, requested_at);

create trigger account_deletion_requests_set_updated_at
before update on public.account_deletion_requests
for each row execute function public.set_updated_at();

alter table public.account_deletion_requests enable row level security;

create policy account_deletion_select_self
on public.account_deletion_requests for select to authenticated
using ((select auth.uid()) = user_id);

create policy account_deletion_select_admin
on public.account_deletion_requests for select to authenticated
using ((select public.is_admin()));

create or replace function public.get_my_account_deletion_request()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_request public.account_deletion_requests%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;

  select request.* into v_request
  from public.account_deletion_requests request
  where request.user_id = auth.uid()
  order by request.requested_at desc
  limit 1;

  return jsonb_build_object(
    'ok', true,
    'request', case when v_request.id is null then null else to_jsonb(v_request) end
  );
end;
$$;

create or replace function public.request_account_deletion(
  p_source text default 'in_app'
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_source text := lower(btrim(coalesce(p_source, 'in_app')));
  v_issued_at bigint;
  v_request public.account_deletion_requests%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if v_source not in ('in_app', 'web') then
    return jsonb_build_object('ok', false, 'code', 'invalid_request_source');
  end if;

  begin
    v_issued_at := (auth.jwt() ->> 'iat')::bigint;
  exception when others then
    return jsonb_build_object('ok', false, 'code', 'recent_reauthentication_required');
  end;

  if v_issued_at is null
     or extract(epoch from now())::bigint - v_issued_at > 600 then
    return jsonb_build_object('ok', false, 'code', 'recent_reauthentication_required');
  end if;

  select request.* into v_request
  from public.account_deletion_requests request
  where request.user_id = auth.uid()
    and request.status in ('requested', 'processing')
  order by request.requested_at desc
  limit 1;

  if v_request.id is not null then
    return jsonb_build_object('ok', true, 'request', to_jsonb(v_request));
  end if;

  if not public.check_rate_limit('account_deletion_request', 3, 86400) then
    return jsonb_build_object('ok', false, 'code', 'account_deletion_rate_limited');
  end if;

  insert into public.account_deletion_requests (
    user_id,
    requester_fingerprint,
    source,
    identity_confirmed_at
  ) values (
    auth.uid(),
    encode(digest(auth.uid()::text, 'sha256'), 'hex'),
    v_source,
    now()
  )
  returning * into v_request;

  perform public.record_rate_limit_event('account_deletion_request');

  return jsonb_build_object('ok', true, 'request', to_jsonb(v_request));
end;
$$;

create or replace function public.cancel_account_deletion_request()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_request public.account_deletion_requests%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;

  update public.account_deletion_requests request
  set status = 'cancelled', cancelled_at = now()
  where request.user_id = auth.uid()
    and request.status = 'requested'
  returning request.* into v_request;

  if v_request.id is null then
    return jsonb_build_object('ok', false, 'code', 'deletion_request_not_cancellable');
  end if;

  return jsonb_build_object('ok', true, 'request', to_jsonb(v_request));
end;
$$;

create or replace function public.service_update_account_deletion_request(
  p_request_id uuid,
  p_status text,
  p_retention_summary text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_status text := lower(btrim(coalesce(p_status, '')));
  v_request public.account_deletion_requests%rowtype;
begin
  if auth.role() <> 'service_role' then
    return jsonb_build_object('ok', false, 'code', 'service_role_required');
  end if;
  if v_status not in ('processing', 'completed') then
    return jsonb_build_object('ok', false, 'code', 'invalid_deletion_status');
  end if;

  update public.account_deletion_requests request
  set status = v_status,
      processing_started_at = case
        when v_status = 'processing' then coalesce(request.processing_started_at, now())
        else request.processing_started_at
      end,
      completed_at = case when v_status = 'completed' then now() else null end,
      retention_summary = nullif(btrim(coalesce(p_retention_summary, '')), '')
  where request.id = p_request_id
    and (
      (v_status = 'processing' and request.status = 'requested')
      or (v_status = 'completed' and request.status = 'processing')
    )
  returning request.* into v_request;

  if v_request.id is null then
    return jsonb_build_object('ok', false, 'code', 'invalid_deletion_transition');
  end if;

  return jsonb_build_object('ok', true, 'request', to_jsonb(v_request));
end;
$$;

create or replace function public.queue_account_deletion_request_notification()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_admin record;
begin
  for v_admin in
    select profile.id from public.profiles profile where profile.role = 'admin'
  loop
    perform public.enqueue_notification(
      v_admin.id,
      'Account deletion request',
      'A verified account deletion request is ready for restricted review.',
      jsonb_build_object('accountDeletionRequestId', new.id)
    );
  end loop;
  return new;
end;
$$;

create trigger account_deletion_queue_notifications
after insert on public.account_deletion_requests
for each row execute function public.queue_account_deletion_request_notification();

revoke all on public.account_deletion_requests from public, anon;
grant select on public.account_deletion_requests to authenticated, service_role;
grant insert, update, delete on public.account_deletion_requests to service_role;

revoke all on function public.get_my_account_deletion_request() from public, anon;
revoke all on function public.request_account_deletion(text) from public, anon;
revoke all on function public.cancel_account_deletion_request() from public, anon;
revoke all on function public.service_update_account_deletion_request(uuid, text, text) from public, anon, authenticated;
revoke all on function public.queue_account_deletion_request_notification() from public, anon, authenticated;

grant execute on function public.get_my_account_deletion_request() to authenticated, service_role;
grant execute on function public.request_account_deletion(text) to authenticated, service_role;
grant execute on function public.cancel_account_deletion_request() to authenticated, service_role;
grant execute on function public.service_update_account_deletion_request(uuid, text, text) to service_role;
