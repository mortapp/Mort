-- MORT account deletion: request API + processor state machine, ported onto
-- the production-baseline schema.
--
-- STATUS: QA ONLY. Applied to QA (ckcxakhxqlkhppsxxjhv) on 2026-11-19.
-- NOT approved for production. PENDING_PRODUCTION_APPROVAL.txt includes this
-- only for local replica testing. Never expose this prerequisite alone: apply
-- the follow-up 20261122151000 before enabling user traffic or the scheduler.
--
-- Why: the shipping Flutter and iOS clients call request_account_deletion,
-- get_my_account_deletion_request and cancel_account_deletion_request, and
-- the deployed account-deletion-processor Edge Function calls the
-- service_* RPCs below. None of these exist in the production-baseline
-- schema (production or QA); they only existed in the retired generic chain
-- (20260720090000, 20260720091500, 20260728222202, 20260728223111,
-- 20260730120000). This port keeps the generic-chain API contract
-- (names, arguments, JSON shapes) so the clients and the processor work
-- unchanged, but is rewritten against the current schema:
--   * staff = private.has_staff_role(admin, moderator) (no public.is_admin)
--   * updated_at via private.touch_updated_at()
--   * rate limit counts the user's own requests (no check_rate_limit table)
--   * no admin notification fan-out (no enqueue_notification); staff read
--     the queue through RLS
--   * retention check is generic and fail-closed (see below)
--
-- Retention (fail closed): the processor hard-deletes the Auth user. In the
-- production-baseline schema 50+ foreign keys reference profiles/auth.users
-- with ON DELETE RESTRICT (jobs, applications, messages, safety reports,
-- legal acceptances, contracts, payments ...). Deleting such a user would
-- fail AFTER storage objects were removed (partial deletion). The approved
-- retention matrix (docs/MORT_DATA_RETENTION_AND_DELETION_MATRIX.md) leaves
-- these classes "BLOCKED-EXTERNAL / legal approval required". So
-- service_check_account_deletion_financial_retention reports
-- retention_review_required = true whenever ANY restricting row exists, and
-- the processor then parks the request in 'retention_review' before touching
-- storage or Auth. No data is removed until a human-approved
-- de-identification rule exists. Name kept for processor compatibility.
--
-- Security: RLS on; clients get SELECT on their own row only (staff: all);
-- all writes go through SECURITY DEFINER RPCs; service_* RPCs are
-- service_role only; no broad grants; Stripe objects are read, never written.
--
-- Rollback (QA): no other object depends on these. Safe to drop while the
-- table is empty; if it has rows, export them first:
--   drop function if exists public.request_account_deletion(text),
--     public.get_my_account_deletion_request(), public.cancel_account_deletion_request(),
--     public.service_claim_account_deletion_request(uuid),
--     public.service_complete_account_deletion_request(uuid, uuid, text),
--     public.service_fail_account_deletion_request(uuid, uuid, text),
--     public.service_list_account_deletion_storage_objects(uuid, integer),
--     public.service_check_account_deletion_financial_retention(uuid),
--     public.service_hold_account_deletion_for_financial_retention(uuid, uuid),
--     private.mort_account_deletion_retention_blockers(uuid);
--   drop table if exists public.account_deletion_requests;

create table if not exists public.account_deletion_requests (
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
  attempt_count integer not null default 0,
  last_attempt_at timestamptz,
  last_error_code text,
  processor_lock_id uuid,
  retention_blockers text[] not null default '{}',
  updated_at timestamptz not null default now(),
  constraint account_deletion_source_check check (source in ('in_app', 'web')),
  constraint account_deletion_status_check check (status in (
    'requested', 'processing', 'retry_pending', 'retention_review',
    'completed', 'cancelled', 'failed')),
  constraint account_deletion_fingerprint_check check (requester_fingerprint ~ '^[0-9a-f]{64}$'),
  constraint account_deletion_retention_summary_length
    check (retention_summary is null or char_length(retention_summary) <= 1000),
  constraint account_deletion_attempt_count_check check (attempt_count between 0 and 5),
  constraint account_deletion_last_error_code_check
    check (last_error_code is null or last_error_code ~ '^[a-z][a-z0-9_]{2,63}$')
);

create unique index if not exists account_deletion_one_open_request_idx
  on public.account_deletion_requests(user_id)
  where user_id is not null and status in ('requested', 'processing', 'retry_pending', 'retention_review');
create index if not exists account_deletion_user_requested_idx
  on public.account_deletion_requests(user_id, requested_at desc);
create index if not exists account_deletion_queue_idx
  on public.account_deletion_requests(status, requested_at);

drop trigger if exists account_deletion_requests_set_updated_at on public.account_deletion_requests;
create trigger account_deletion_requests_set_updated_at
  before update on public.account_deletion_requests
  for each row execute function private.touch_updated_at();

alter table public.account_deletion_requests enable row level security;

drop policy if exists account_deletion_select_self on public.account_deletion_requests;
create policy account_deletion_select_self on public.account_deletion_requests
  for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists account_deletion_select_staff on public.account_deletion_requests;
create policy account_deletion_select_staff on public.account_deletion_requests
  for select to authenticated
  using ((select private.has_staff_role(array['admin', 'moderator']::public.mort_role[])));

revoke all on public.account_deletion_requests from public, anon, authenticated;
grant select on public.account_deletion_requests to authenticated;
grant select, insert, update, delete on public.account_deletion_requests to service_role;

-- Client-safe projection (no fingerprint, lock id or blocker table names).
create or replace function private.mort_account_deletion_request_json(p public.account_deletion_requests)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select case when p.id is null then null else jsonb_build_object(
    'id', p.id, 'status', p.status, 'source', p.source,
    'requested_at', p.requested_at, 'processing_started_at', p.processing_started_at,
    'completed_at', p.completed_at, 'cancelled_at', p.cancelled_at,
    'retention_summary', p.retention_summary) end;
$$;
revoke all on function private.mort_account_deletion_request_json(public.account_deletion_requests) from public, anon, authenticated;

create or replace function public.get_my_account_deletion_request()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request public.account_deletion_requests%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  select r.* into v_request from public.account_deletion_requests r
  where r.user_id = auth.uid() order by r.requested_at desc limit 1;
  return jsonb_build_object('ok', true, 'request', private.mort_account_deletion_request_json(v_request));
end;
$$;

create or replace function public.request_account_deletion(p_source text default 'in_app')
returns jsonb
language plpgsql
security definer
set search_path = ''
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

  -- Recent sign-in required: the access token must have been issued <= 10 min ago.
  begin
    v_issued_at := (auth.jwt() ->> 'iat')::bigint;
  exception when others then
    v_issued_at := null;
  end;
  if v_issued_at is null or extract(epoch from now())::bigint - v_issued_at > 600 then
    return jsonb_build_object('ok', false, 'code', 'recent_reauthentication_required');
  end if;

  -- Serialize per user so concurrent calls cannot create two open requests.
  perform pg_advisory_xact_lock(hashtextextended('account_deletion:' || auth.uid()::text, 0));

  select r.* into v_request from public.account_deletion_requests r
  where r.user_id = auth.uid()
    and r.status in ('requested', 'processing', 'retry_pending', 'retention_review')
  order by r.requested_at desc limit 1;
  if v_request.id is not null then
    return jsonb_build_object('ok', true, 'request', private.mort_account_deletion_request_json(v_request));
  end if;

  if (select count(*) from public.account_deletion_requests r
      where r.user_id = auth.uid() and r.requested_at > now() - interval '24 hours') >= 3 then
    return jsonb_build_object('ok', false, 'code', 'account_deletion_rate_limited');
  end if;

  insert into public.account_deletion_requests (user_id, requester_fingerprint, source, identity_confirmed_at)
  values (auth.uid(), encode(extensions.digest(auth.uid()::text, 'sha256'), 'hex'), v_source, now())
  returning * into v_request;

  return jsonb_build_object('ok', true, 'request', private.mort_account_deletion_request_json(v_request));
end;
$$;

create or replace function public.cancel_account_deletion_request()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request public.account_deletion_requests%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  update public.account_deletion_requests r
  set status = 'cancelled', cancelled_at = now()
  where r.user_id = auth.uid() and r.status = 'requested'
  returning r.* into v_request;
  if v_request.id is null then
    return jsonb_build_object('ok', false, 'code', 'deletion_request_not_cancellable');
  end if;
  return jsonb_build_object('ok', true, 'request', private.mort_account_deletion_request_json(v_request));
end;
$$;

-- Every table whose foreign key to profiles/auth.users would block (RESTRICT /
-- NO ACTION) deleting this user, and that has a row for them. Generic over the
-- catalog so new tables are covered automatically. Returns table names only.
create or replace function private.mort_account_deletion_retention_blockers(p_user_id uuid)
returns text[]
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  r record;
  v_found boolean;
  v_blockers text[] := '{}';
begin
  if p_user_id is null then
    return v_blockers;
  end if;
  for r in
    select distinct n.nspname as sch, c.relname as tbl, a.attname as col
    from pg_constraint con
    join pg_class c on c.oid = con.conrelid
    join pg_namespace n on n.oid = c.relnamespace
    join pg_attribute a on a.attrelid = con.conrelid and a.attnum = con.conkey[1]
    where con.contype = 'f'
      and array_length(con.conkey, 1) = 1
      and con.confdeltype in ('r', 'a')
      and con.confrelid in ('public.profiles'::regclass, 'auth.users'::regclass)
      and n.nspname in ('public', 'private')
  loop
    execute format('select exists (select 1 from %I.%I where %I = $1)', r.sch, r.tbl, r.col)
      into v_found using p_user_id;
    if v_found then
      v_blockers := array_append(v_blockers, r.sch || '.' || r.tbl);
    end if;
  end loop;
  return (select coalesce(array_agg(distinct b order by b), '{}') from unnest(v_blockers) b);
end;
$$;
revoke all on function private.mort_account_deletion_retention_blockers(uuid) from public, anon, authenticated;

create or replace function public.service_check_account_deletion_financial_retention(p_user_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_blockers text[];
begin
  if auth.role() <> 'service_role' then
    raise insufficient_privilege using message = 'service_role_required';
  end if;
  v_blockers := private.mort_account_deletion_retention_blockers(p_user_id);
  return jsonb_build_object(
    'ok', true,
    'retention_review_required', cardinality(v_blockers) > 0,
    'code', case when cardinality(v_blockers) > 0 then 'retention_review_required' else 'clear' end,
    'blocker_count', cardinality(v_blockers));
end;
$$;

create or replace function public.service_hold_account_deletion_for_financial_retention(
  p_request_id uuid, p_processor_lock_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request public.account_deletion_requests%rowtype;
  v_blockers text[];
begin
  if auth.role() <> 'service_role' then
    raise insufficient_privilege using message = 'service_role_required';
  end if;
  select r.* into v_request from public.account_deletion_requests r
  where r.id = p_request_id and r.status = 'processing' and r.processor_lock_id = p_processor_lock_id
  for update;
  if v_request.id is null then
    return jsonb_build_object('ok', false, 'code', 'deletion_lock_or_retention_mismatch');
  end if;
  v_blockers := private.mort_account_deletion_retention_blockers(v_request.user_id);
  if cardinality(v_blockers) = 0 then
    return jsonb_build_object('ok', false, 'code', 'deletion_lock_or_retention_mismatch');
  end if;
  update public.account_deletion_requests r
  set status = 'retention_review',
      last_error_code = 'retention_review_required',
      retention_blockers = v_blockers,
      retention_summary = 'Records that must be reviewed under the retention policy exist. Deletion is paused before any data is removed, pending an approved retention and de-identification decision.',
      processor_lock_id = null
  where r.id = v_request.id
  returning r.* into v_request;
  return jsonb_build_object('ok', true, 'request_id', v_request.id, 'status', v_request.status);
end;
$$;

create or replace function public.service_claim_account_deletion_request(p_request_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request public.account_deletion_requests%rowtype;
  v_lock_id uuid := gen_random_uuid();
begin
  if auth.role() <> 'service_role' then
    return jsonb_build_object('ok', false, 'code', 'service_role_required');
  end if;
  select r.* into v_request from public.account_deletion_requests r
  where (p_request_id is null or r.id = p_request_id)
    and r.status in ('requested', 'retry_pending', 'processing')
    and (r.status <> 'processing'
         or coalesce(r.last_attempt_at, r.processing_started_at, r.requested_at) < now() - interval '15 minutes')
    and r.attempt_count < 5
  order by r.requested_at
  for update skip locked
  limit 1;
  if v_request.id is null then
    return jsonb_build_object('ok', false, 'code', 'deletion_request_unavailable');
  end if;

  if v_request.user_id is not null then
    update public.profiles set account_status = 'suspended', updated_at = now()
    where id = v_request.user_id and account_status <> 'closed';
    delete from auth.refresh_tokens where user_id = v_request.user_id::text;
    delete from auth.sessions where user_id = v_request.user_id;
  end if;

  update public.account_deletion_requests r
  set status = 'processing',
      processing_started_at = coalesce(r.processing_started_at, now()),
      attempt_count = r.attempt_count + 1,
      last_attempt_at = now(),
      last_error_code = null,
      processor_lock_id = v_lock_id
  where r.id = v_request.id
  returning r.* into v_request;

  return jsonb_build_object('ok', true, 'request', jsonb_build_object(
    'id', v_request.id, 'user_id', v_request.user_id,
    'attempt_count', v_request.attempt_count, 'processor_lock_id', v_request.processor_lock_id));
end;
$$;

create or replace function public.service_complete_account_deletion_request(
  p_request_id uuid, p_processor_lock_id uuid, p_retention_summary text)
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
  update public.account_deletion_requests r
  set status = 'completed', completed_at = now(),
      retention_summary = left(btrim(p_retention_summary), 1000),
      last_error_code = null, processor_lock_id = null
  where r.id = p_request_id and r.status = 'processing' and r.processor_lock_id = p_processor_lock_id
  returning r.* into v_request;
  if v_request.id is null then
    return jsonb_build_object('ok', false, 'code', 'deletion_lock_mismatch');
  end if;
  return jsonb_build_object('ok', true, 'request_id', v_request.id);
end;
$$;

create or replace function public.service_fail_account_deletion_request(
  p_request_id uuid, p_processor_lock_id uuid, p_error_code text)
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
  update public.account_deletion_requests r
  set status = case when r.attempt_count >= 5 then 'failed' else 'retry_pending' end,
      last_error_code = v_code, processor_lock_id = null
  where r.id = p_request_id and r.status = 'processing' and r.processor_lock_id = p_processor_lock_id
  returning r.* into v_request;
  if v_request.id is null then
    return jsonb_build_object('ok', false, 'code', 'deletion_lock_mismatch');
  end if;
  return jsonb_build_object('ok', true, 'request_id', v_request.id, 'status', v_request.status);
end;
$$;

create or replace function public.service_list_account_deletion_storage_objects(
  p_user_id uuid, p_limit integer default 500)
returns table(bucket_id text, object_name text)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.role() <> 'service_role' then
    raise insufficient_privilege using message = 'service_role_required';
  end if;
  if p_user_id is null then
    return;
  end if;
  return query
  select o.bucket_id, o.name from storage.objects o
  where o.owner_id = p_user_id::text
  order by o.bucket_id, o.name
  limit least(greatest(coalesce(p_limit, 500), 1), 500);
end;
$$;

revoke all on function public.get_my_account_deletion_request() from public, anon;
revoke all on function public.request_account_deletion(text) from public, anon;
revoke all on function public.cancel_account_deletion_request() from public, anon;
grant execute on function public.get_my_account_deletion_request() to authenticated;
grant execute on function public.request_account_deletion(text) to authenticated;
grant execute on function public.cancel_account_deletion_request() to authenticated;

revoke all on function public.service_claim_account_deletion_request(uuid) from public, anon, authenticated;
revoke all on function public.service_complete_account_deletion_request(uuid, uuid, text) from public, anon, authenticated;
revoke all on function public.service_fail_account_deletion_request(uuid, uuid, text) from public, anon, authenticated;
revoke all on function public.service_list_account_deletion_storage_objects(uuid, integer) from public, anon, authenticated;
revoke all on function public.service_check_account_deletion_financial_retention(uuid) from public, anon, authenticated;
revoke all on function public.service_hold_account_deletion_for_financial_retention(uuid, uuid) from public, anon, authenticated;
grant execute on function public.service_claim_account_deletion_request(uuid) to service_role;
grant execute on function public.service_complete_account_deletion_request(uuid, uuid, text) to service_role;
grant execute on function public.service_fail_account_deletion_request(uuid, uuid, text) to service_role;
grant execute on function public.service_list_account_deletion_storage_objects(uuid, integer) to service_role;
grant execute on function public.service_check_account_deletion_financial_retention(uuid) to service_role;
grant execute on function public.service_hold_account_deletion_for_financial_retention(uuid, uuid) to service_role;
