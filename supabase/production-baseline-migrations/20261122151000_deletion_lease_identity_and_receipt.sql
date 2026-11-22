-- Depends on 20261119100000_account_deletion_processor_port.sql.
-- Deploy the updated worker with the scheduler paused; no scheduler is created here.
alter table public.account_deletion_requests
  add column if not exists processor_user_id uuid,
  add column if not exists receipt_hash bytea,
  add column if not exists receipt_expires_at timestamptz;

create unique index if not exists account_deletion_receipt_hash_idx
  on public.account_deletion_requests(receipt_hash) where receipt_hash is not null;
-- Route ordinary users through the intentionally redacted RPC. The existing
-- staff SECURITY DEFINER paths are unaffected; direct rows are service-only.
revoke select on public.account_deletion_requests from authenticated;

create or replace function private.mort_deletion_caller_session(p_recent boolean)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from auth.sessions s join auth.users u on u.id = s.user_id
    where s.user_id = auth.uid()
      and s.id::text = (auth.jwt() ->> 'session_id')
      and (s.not_after is null or s.not_after > now())
      and u.email_confirmed_at is not null
      and (
        not exists (select 1 from auth.mfa_factors f where f.user_id = u.id and f.status = 'verified')
        or (s.aal::text = 'aal2' and auth.jwt() ->> 'aal' = 'aal2')
      )
      and (not p_recent or s.created_at between now() - interval '10 minutes' and now())
  );
$$;
revoke all on function private.mort_deletion_caller_session(boolean) from public, anon, authenticated;

create or replace function public.get_my_account_deletion_request()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_request public.account_deletion_requests%rowtype;
begin
  if not private.mort_deletion_caller_session(false) then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  select r.* into v_request from public.account_deletion_requests r
    where r.user_id = auth.uid() order by r.requested_at desc limit 1;
  return jsonb_build_object('ok', true, 'request', private.mort_account_deletion_request_json(v_request));
end;
$$;

create or replace function public.request_account_deletion(p_source text default 'in_app')
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_source text := lower(btrim(coalesce(p_source, 'in_app')));
  v_request public.account_deletion_requests%rowtype;
begin
  -- Refreshed tokens can have a new iat; GoTrue's session creation time does not change.
  if not private.mort_deletion_caller_session(true) then
    return jsonb_build_object('ok', false, 'code', 'recent_reauthentication_required');
  end if;
  if v_source not in ('in_app', 'web') then
    return jsonb_build_object('ok', false, 'code', 'invalid_request_source');
  end if;
  if not exists (select 1 from public.profiles where id = v_user) then
    return jsonb_build_object('ok', false, 'code', 'deletion_profile_unavailable');
  end if;
  perform pg_advisory_xact_lock(hashtextextended('account_deletion:' || v_user::text, 0));
  select r.* into v_request from public.account_deletion_requests r
    where r.user_id = v_user and r.status in ('requested','processing','retry_pending','retention_review')
    order by r.requested_at desc limit 1;
  if v_request.id is null then
    if (select count(*) from public.account_deletion_requests r where r.user_id = v_user
        and r.requested_at > now() - interval '24 hours') >= 3 then
      return jsonb_build_object('ok', false, 'code', 'account_deletion_rate_limited');
    end if;
    insert into public.account_deletion_requests(user_id, requester_fingerprint, source, identity_confirmed_at)
    values (v_user, encode(extensions.digest(v_user::text, 'sha256'), 'hex'), v_source, now())
    returning * into v_request;
  end if;
  return jsonb_build_object('ok', true, 'request', private.mort_account_deletion_request_json(v_request));
end;
$$;

create or replace function public.cancel_account_deletion_request()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_request public.account_deletion_requests%rowtype;
begin
  if not private.mort_deletion_caller_session(true) then
    return jsonb_build_object('ok', false, 'code', 'recent_reauthentication_required');
  end if;
  perform pg_advisory_xact_lock(hashtextextended('account_deletion:' || auth.uid()::text, 0));
  update public.account_deletion_requests r set status = 'cancelled', cancelled_at = now()
    where r.user_id = auth.uid() and r.status = 'requested' returning r.* into v_request;
  if v_request.id is null then
    return jsonb_build_object('ok', false, 'code', 'deletion_request_not_cancellable');
  end if;
  return jsonb_build_object('ok', true, 'request', private.mort_account_deletion_request_json(v_request));
end;
$$;

create or replace function public.issue_my_account_deletion_receipt(p_request_id uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare v_code text := encode(extensions.gen_random_bytes(32), 'hex');
begin
  if not private.mort_deletion_caller_session(true) then return null; end if;
  update public.account_deletion_requests r
    set receipt_hash = extensions.digest(v_code, 'sha256'), receipt_expires_at = now() + interval '90 days'
    where r.id = p_request_id and r.user_id = auth.uid()
      and r.status in ('requested','retry_pending','retention_review','cancelled');
  if not found then return null; end if;
  return v_code;
end;
$$;

create or replace function public.get_account_deletion_receipt_status(p_receipt text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_status text;
begin
  if p_receipt is null or length(p_receipt) <> 64 or p_receipt !~ '^[0-9a-f]{64}$' then return null; end if;
  select r.status into v_status from public.account_deletion_requests r
    where r.receipt_hash = extensions.digest(p_receipt, 'sha256') and r.receipt_expires_at > now();
  if v_status is null then return null; end if;
  return jsonb_build_object('status', v_status);
end;
$$;
revoke all on function public.issue_my_account_deletion_receipt(uuid) from public, anon, authenticated;
grant execute on function public.issue_my_account_deletion_receipt(uuid) to authenticated;
revoke all on function public.get_account_deletion_receipt_status(text) from public, anon, authenticated;
grant execute on function public.get_account_deletion_receipt_status(text) to anon, authenticated;

create or replace function public.service_assert_account_deletion_lease(p_request_id uuid, p_processor_lock_id uuid)
returns boolean language sql volatile security definer set search_path = '' as $$
  select coalesce(auth.role() = 'service_role', false) and exists (
    select 1 from public.account_deletion_requests r where r.id = p_request_id
      and r.status = 'processing' and r.processor_lock_id = p_processor_lock_id
      and r.processor_user_id is not null
      and r.last_attempt_at > clock_timestamp() - interval '15 minutes'
  );
$$;
revoke all on function public.service_assert_account_deletion_lease(uuid,uuid) from public, anon, authenticated;
grant execute on function public.service_assert_account_deletion_lease(uuid,uuid) to service_role;

create or replace function public.service_claim_account_deletion_request(p_request_id uuid default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_request public.account_deletion_requests%rowtype;
  v_user uuid;
begin
  if auth.role() is distinct from 'service_role' then
    return jsonb_build_object('ok', false, 'code', 'service_role_required');
  end if;
  update public.account_deletion_requests r
    set status = 'failed', processor_lock_id = null, last_error_code = 'deletion_lease_exhausted'
    where (p_request_id is null or r.id = p_request_id) and r.status = 'processing'
      and r.attempt_count >= 5 and coalesce(r.last_attempt_at,r.requested_at) <= now() - interval '15 minutes';
  select r.* into v_request from public.account_deletion_requests r
    where (p_request_id is null or r.id = p_request_id)
      and (
        (r.status = 'requested' and r.requested_at <= now() - interval '5 minutes') or
        (r.status = 'retry_pending' and r.last_attempt_at <= now() - (1 << greatest(r.attempt_count-1,0)) * interval '1 minute') or
        (r.status = 'processing' and coalesce(r.last_attempt_at,r.requested_at) <= now() - interval '15 minutes')
      )
      and r.attempt_count < 5
    order by r.requested_at limit 1 for update skip locked;
  if v_request.id is null then
    return jsonb_build_object('ok', false, 'code', 'deletion_request_unavailable');
  end if;
  v_user := coalesce(v_request.processor_user_id, v_request.user_id);
  if v_user is null then
    update public.account_deletion_requests r set status = 'failed', processor_lock_id = null,
      last_error_code = 'deletion_target_unconfirmed' where r.id = v_request.id;
    return jsonb_build_object('ok', false, 'code', 'deletion_target_unconfirmed');
  end if;

  update public.account_deletion_requests r
    set status = 'processing', processing_started_at = coalesce(r.processing_started_at, now()),
        attempt_count = r.attempt_count + 1, last_attempt_at = clock_timestamp(), last_error_code = null,
        processor_lock_id = gen_random_uuid(), processor_user_id = v_user
    where r.id = v_request.id returning r.* into v_request;
  update public.profiles set account_status = 'suspended', updated_at = now()
    where id = v_user and account_status <> 'closed';
  delete from auth.refresh_tokens where user_id = v_user::text;
  delete from auth.sessions where user_id = v_user;
  return jsonb_build_object('ok', true, 'request', jsonb_build_object(
    'id',v_request.id,'user_id',v_user,'attempt_count',v_request.attempt_count,
    'processor_lock_id',v_request.processor_lock_id));
end;
$$;

create or replace function public.service_complete_account_deletion_request(
  p_request_id uuid, p_processor_lock_id uuid, p_retention_summary text
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_request public.account_deletion_requests%rowtype;
begin
  if auth.role() is distinct from 'service_role' then
    return jsonb_build_object('ok', false, 'code', 'service_role_required');
  end if;
  select r.* into v_request from public.account_deletion_requests r
    where r.id = p_request_id for update;
  if not public.service_assert_account_deletion_lease(p_request_id, p_processor_lock_id) then
    return jsonb_build_object('ok', false, 'code', 'deletion_lock_mismatch');
  end if;
  if v_request.user_id is not null or
    exists (select 1 from auth.users where id = v_request.processor_user_id) or
    exists (select 1 from auth.identities where user_id = v_request.processor_user_id) or
    exists (select 1 from auth.sessions where user_id = v_request.processor_user_id) or
    exists (select 1 from auth.refresh_tokens where user_id = v_request.processor_user_id::text) or
    exists (select 1 from storage.objects o where o.owner_id = v_request.processor_user_id::text
              or o.owner = v_request.processor_user_id)
  then
    return jsonb_build_object('ok', false, 'code', 'deletion_absence_unconfirmed');
  end if;
  update public.account_deletion_requests r set status = 'completed', completed_at = now(),
    retention_summary = left(btrim(p_retention_summary),1000), last_error_code = null,
    processor_lock_id = null, processor_user_id = null,
    requester_fingerprint = encode(extensions.gen_random_bytes(32), 'hex')
    where r.id = p_request_id;
  return jsonb_build_object('ok', true, 'request_id', p_request_id);
end;
$$;

create or replace function public.service_fail_account_deletion_request(
  p_request_id uuid, p_processor_lock_id uuid, p_error_code text
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_code text := lower(btrim(coalesce(p_error_code, 'deletion_worker_failed')));
  v_status text;
begin
  if auth.role() is distinct from 'service_role' then
    return jsonb_build_object('ok', false, 'code', 'service_role_required');
  end if;
  if v_code !~ '^[a-z][a-z0-9_]{2,63}$' then v_code := 'deletion_worker_failed'; end if;
  update public.account_deletion_requests r set
    status = case when r.attempt_count >= 5 then 'failed' else 'retry_pending' end,
    last_error_code = v_code, processor_lock_id = null
    where r.id = p_request_id and r.status = 'processing' and r.processor_lock_id = p_processor_lock_id
      and r.last_attempt_at > clock_timestamp() - interval '15 minutes'
    returning r.status into v_status;
  if v_status is null then return jsonb_build_object('ok', false, 'code', 'deletion_lock_mismatch'); end if;
  return jsonb_build_object('ok', true, 'request_id', p_request_id, 'status', v_status);
end;
$$;

-- Preserve any owned evidence or unknown bucket pending a reviewed retention
-- rule. Worker Storage API deletion is limited to explicitly disposable data.
create or replace function private.mort_deletion_storage_retention(p_user_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from storage.objects o
    where (o.owner_id = p_user_id::text or o.owner = p_user_id)
      and o.bucket_id not in ('profile-avatars'));
$$;
revoke all on function private.mort_deletion_storage_retention(uuid) from public, anon, authenticated;

-- Record an explicit legal/safety hold without including case narrative or
-- filing data in the queue. The private audit rows survive release. The user
-- reference is erased when the profile is deleted after all holds are cleared.
create table if not exists private.account_deletion_legal_holds (
  id uuid primary key default gen_random_uuid(),
  subject_id uuid references public.profiles(id) on delete set null,
  category text not null check (category in ('legal','safety','financial','regulatory')),
  case_reference text not null check (length(case_reference) between 1 and 100),
  placed_at timestamptz not null default now(),
  released_at timestamptz,
  check (released_at is null or released_at >= placed_at)
);
alter table private.account_deletion_legal_holds enable row level security;
revoke all on table private.account_deletion_legal_holds from public, anon, authenticated;
create index if not exists account_deletion_active_holds_idx
  on private.account_deletion_legal_holds(subject_id) where released_at is null;

create or replace function private.mort_deletion_protected_history(p_user_id uuid)
returns text[] language plpgsql stable security definer set search_path = '' as $$
declare
  target record;
  has_records boolean;
  blockers text[] := '{}';
begin
  if exists (select 1 from private.account_deletion_legal_holds h where h.subject_id = p_user_id and h.released_at is null) then
    blockers := array_append(blockers,'private.account_deletion_legal_holds');
  end if;
  -- These current CASCADEs remove shared or sensitive history. Preserve them
  -- pending a separate, individually approved retention disposition.
  for target in select * from (values
    ('private','verification_provider_results','user_id'),
    ('public','verification_cases','user_id'),
    ('public','consents','user_id'),
    ('public','job_safety_checkins','adult_user_id'),
    ('public','job_safety_checkins','teen_user_id'),
    ('public','role_requests','user_id'),
    ('public','team_hustles','poster_id')
  ) as protected(sch,tbl,col)
  loop
    execute format('select exists (select 1 from %I.%I where %I = $1)',target.sch,target.tbl,target.col)
      into has_records using p_user_id;
    if has_records then blockers := array_append(blockers,target.sch || '.' || target.tbl); end if;
  end loop;
  return blockers;
end;
$$;
revoke all on function private.mort_deletion_protected_history(uuid) from public, anon, authenticated;

create or replace function private.mort_deletion_protect_profile_history()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  -- Serialize hold changes with deletion. Maintenance users must not disable this trigger.
  lock table private.account_deletion_legal_holds in share mode;
  if exists (select 1 from private.account_deletion_legal_holds h where h.subject_id = old.id and h.released_at is null)
    or (
      exists (select 1 from public.account_deletion_requests r
              where r.processor_user_id = old.id and r.status = 'processing')
      and cardinality(private.mort_deletion_protected_history(old.id)) > 0
    )
  then
    raise exception 'account_deletion_protected_history' using errcode = '23503';
  end if;
  return old;
end;
$$;
revoke all on function private.mort_deletion_protect_profile_history() from public, anon, authenticated;
create trigger mort_deletion_protect_profile_history before delete on public.profiles
  for each row execute function private.mort_deletion_protect_profile_history();

create or replace function public.service_check_account_deletion_financial_retention(p_user_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_blockers text[];
begin
  if auth.role() is distinct from 'service_role' then
    raise insufficient_privilege using message = 'service_role_required';
  end if;
  v_blockers := private.mort_account_deletion_retention_blockers(p_user_id)
    || private.mort_deletion_protected_history(p_user_id);
  if private.mort_deletion_storage_retention(p_user_id) then
    v_blockers := array_append(v_blockers, 'storage.retention_review');
  end if;
  return jsonb_build_object('ok',true,'retention_review_required',cardinality(v_blockers)>0);
end;
$$;

create or replace function public.service_hold_account_deletion_for_financial_retention(
  p_request_id uuid, p_processor_lock_id uuid
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_request public.account_deletion_requests%rowtype;
  v_blockers text[];
begin
  if auth.role() is distinct from 'service_role' then
    raise insufficient_privilege using message = 'service_role_required';
  end if;
  select r.* into v_request from public.account_deletion_requests r where r.id = p_request_id for update;
  if not public.service_assert_account_deletion_lease(p_request_id,p_processor_lock_id) then
    return jsonb_build_object('ok',false,'code','deletion_lock_mismatch');
  end if;
  v_blockers := private.mort_account_deletion_retention_blockers(v_request.processor_user_id)
    || private.mort_deletion_protected_history(v_request.processor_user_id);
  if private.mort_deletion_storage_retention(v_request.processor_user_id) then
    v_blockers := array_append(v_blockers,'storage.retention_review');
  end if;
  if cardinality(v_blockers) = 0 then
    return jsonb_build_object('ok',false,'code','deletion_lock_or_retention_mismatch');
  end if;
  update public.account_deletion_requests r set status = 'retention_review',
    last_error_code = 'retention_review_required', retention_blockers = v_blockers,
    retention_summary = 'Some records require a retention review. Your request is paused.',
    processor_lock_id = null, processor_user_id = null where r.id = p_request_id;
  return jsonb_build_object('ok',true,'request_id',p_request_id,'status','retention_review');
end;
$$;

create or replace function public.service_list_account_deletion_storage_objects(
  p_user_id uuid, p_limit integer default 500
)
returns table(bucket_id text, object_name text)
language plpgsql security definer set search_path = '' as $$
begin
  if auth.role() is distinct from 'service_role' then
    raise insufficient_privilege using message = 'service_role_required';
  end if;
  return query select o.bucket_id,o.name from storage.objects o
    where o.bucket_id = 'profile-avatars' and (o.owner_id = p_user_id::text or o.owner = p_user_id)
    order by o.bucket_id,o.name limit least(greatest(coalesce(p_limit,500),1),500);
end;
$$;

notify pgrst, 'reload schema';
