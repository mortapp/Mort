alter table public.account_deletion_requests
  add column if not exists attempt_count integer not null default 0,
  add column if not exists last_attempt_at timestamptz,
  add column if not exists last_error_code text,
  add column if not exists processor_lock_id uuid;

alter table public.account_deletion_requests
  drop constraint if exists account_deletion_status_check,
  add constraint account_deletion_status_check check (
    status in (
      'requested', 'processing', 'retry_pending',
      'completed', 'cancelled', 'failed'
    )
  ),
  drop constraint if exists account_deletion_attempt_count_check,
  add constraint account_deletion_attempt_count_check check (
    attempt_count between 0 and 5
  ),
  drop constraint if exists account_deletion_last_error_code_check,
  add constraint account_deletion_last_error_code_check check (
    last_error_code is null
    or last_error_code ~ '^[a-z][a-z0-9_]{2,63}$'
  );

drop index if exists public.account_deletion_one_open_request_idx;
create unique index account_deletion_one_open_request_idx
on public.account_deletion_requests(user_id)
where user_id is not null
  and status in ('requested', 'processing', 'retry_pending');

create or replace function public.service_claim_account_deletion_request(
  p_request_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request public.account_deletion_requests%rowtype;
  v_lock_id uuid := extensions.gen_random_uuid();
begin
  if auth.role() <> 'service_role' then
    return jsonb_build_object('ok', false, 'code', 'service_role_required');
  end if;

  select request.* into v_request
  from public.account_deletion_requests request
  where (p_request_id is null or request.id = p_request_id)
    and request.status in ('requested', 'retry_pending', 'processing')
    and (
      request.status <> 'processing'
      or coalesce(
        request.last_attempt_at,
        request.processing_started_at,
        request.requested_at
      ) < now() - interval '15 minutes'
    )
    and request.attempt_count < 5
  order by request.requested_at
  for update skip locked
  limit 1;

  if v_request.id is null then
    return jsonb_build_object('ok', false, 'code', 'deletion_request_unavailable');
  end if;

  if v_request.user_id is not null then
    update public.profiles
    set account_status = 'suspended',
        updated_at = now()
    where id = v_request.user_id;

    delete from auth.sessions
    where user_id = v_request.user_id;
  end if;

  update public.account_deletion_requests request
  set status = 'processing',
      processing_started_at = coalesce(request.processing_started_at, now()),
      attempt_count = request.attempt_count + 1,
      last_attempt_at = now(),
      last_error_code = null,
      processor_lock_id = v_lock_id
  where request.id = v_request.id
  returning request.* into v_request;

  return jsonb_build_object(
    'ok', true,
    'request', jsonb_build_object(
      'id', v_request.id,
      'user_id', v_request.user_id,
      'attempt_count', v_request.attempt_count,
      'processor_lock_id', v_request.processor_lock_id
    )
  );
end;
$$;

create or replace function public.service_complete_account_deletion_request(
  p_request_id uuid,
  p_processor_lock_id uuid,
  p_retention_summary text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request public.account_deletion_requests%rowtype;
begin
  if auth.role() <> 'service_role' then
    return jsonb_build_object('ok', false, 'code', 'service_role_required');
  end if;

  update public.account_deletion_requests request
  set status = 'completed',
      completed_at = now(),
      retention_summary = left(btrim(p_retention_summary), 1000),
      last_error_code = null,
      processor_lock_id = null
  where request.id = p_request_id
    and request.status = 'processing'
    and request.processor_lock_id = p_processor_lock_id
  returning request.* into v_request;

  if v_request.id is null then
    return jsonb_build_object('ok', false, 'code', 'deletion_lock_mismatch');
  end if;
  return jsonb_build_object('ok', true, 'request_id', v_request.id);
end;
$$;

create or replace function public.service_fail_account_deletion_request(
  p_request_id uuid,
  p_processor_lock_id uuid,
  p_error_code text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code text := lower(btrim(coalesce(p_error_code, 'deletion_worker_failed')));
  v_request public.account_deletion_requests%rowtype;
begin
  if auth.role() <> 'service_role' then
    return jsonb_build_object('ok', false, 'code', 'service_role_required');
  end if;
  if v_code !~ '^[a-z][a-z0-9_]{2,63}$' then
    v_code := 'deletion_worker_failed';
  end if;

  update public.account_deletion_requests request
  set status = case
        when request.attempt_count >= 5 then 'failed'
        else 'retry_pending'
      end,
      last_error_code = v_code,
      processor_lock_id = null
  where request.id = p_request_id
    and request.status = 'processing'
    and request.processor_lock_id = p_processor_lock_id
  returning request.* into v_request;

  if v_request.id is null then
    return jsonb_build_object('ok', false, 'code', 'deletion_lock_mismatch');
  end if;
  return jsonb_build_object(
    'ok', true,
    'request_id', v_request.id,
    'status', v_request.status
  );
end;
$$;

revoke all on function public.service_claim_account_deletion_request(uuid)
from public, anon, authenticated;
revoke all on function public.service_complete_account_deletion_request(uuid, uuid, text)
from public, anon, authenticated;
revoke all on function public.service_fail_account_deletion_request(uuid, uuid, text)
from public, anon, authenticated;

grant execute on function public.service_claim_account_deletion_request(uuid)
to service_role;
grant execute on function public.service_complete_account_deletion_request(uuid, uuid, text)
to service_role;
grant execute on function public.service_fail_account_deletion_request(uuid, uuid, text)
to service_role;
