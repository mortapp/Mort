-- DISCUSSION DRAFT. Disposable replica only, never a production migration.
-- Do not put this in PENDING_PRODUCTION_APPROVAL.txt. Data and lifecycle
-- decisions in MORT_TEEN_GUARDIAN_CONSENT_DRAFT.md are not yet approved.
begin;

create table private.teen_guardian_activation_consent (
  request_id uuid primary key default gen_random_uuid(),
  teen_id uuid not null,
  guardian_id uuid not null,
  issuer_id uuid not null,
  authority_ref uuid not null unique,
  consent_version integer not null check (consent_version > 0),
  issued_at timestamptz not null,
  expires_at timestamptz not null,
  teen_assented_at timestamptz,
  guardian_consented_at timestamptz,
  closed_at timestamptz,
  closed_by uuid,
  close_reason text check (close_reason in (
    'participant_withdrew', 'request_expired', 'authority_invalid',
    'policy_recheck', 'guardian_no_longer_eligible'
  )),
  check (teen_id <> guardian_id and issuer_id <> teen_id and issuer_id <> guardian_id),
  check (expires_at > issued_at),
  check (teen_assented_at is null or (teen_assented_at >= issued_at and teen_assented_at < expires_at)),
  check (guardian_consented_at is null or (
    teen_assented_at is not null and guardian_consented_at >= teen_assented_at and guardian_consented_at < expires_at
  )),
  check (
    (closed_at is null and closed_by is null and close_reason is null)
    or (closed_at is not null and closed_by is not null and close_reason is not null
        and closed_at >= coalesce(guardian_consented_at, teen_assented_at, issued_at))
  )
);
create unique index teen_guardian_activation_consent_one_open
  on private.teen_guardian_activation_consent (teen_id) where closed_at is null;
create index teen_guardian_activation_consent_history
  on private.teen_guardian_activation_consent (teen_id, issued_at desc);
alter table private.teen_guardian_activation_consent enable row level security;
revoke all on private.teen_guardian_activation_consent from public, anon, authenticated, service_role;

create function private.teen_guardian_consent_current_version()
returns integer language sql immutable set search_path = '' as $$
  select 1;
$$;

create function private.teen_guardian_identity_qualified(p_guardian_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select
    exists(select 1 from public.verification_cases vc
      join private.verification_provider_allowlist pa
        on pa.provider_key=vc.provider and pa.verification_type=vc.verification_type and pa.is_enabled
      where vc.user_id=p_guardian_id and vc.verification_type='identity'
        and vc.status='verified'::public.mort_verification_status and (vc.expires_at is null or vc.expires_at>now()))
    and exists(select 1 from public.profiles pr where pr.id=p_guardian_id
      and pr.date_of_birth is not null and private.mort_age_years(pr.date_of_birth) >= 18)
    and exists(select 1 from auth.users u where u.id=p_guardian_id and u.email_confirmed_at is not null);
$$;

create function private.teen_guardian_consent_guardian_eligible(p_guardian_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = p_guardian_id and p.role = 'guardian'::public.mort_role and p.account_status = 'active'
      and p.onboarding_completed_at is not null and private.mort_user_has_current_legal_acceptances(p.id)
      and private.teen_guardian_identity_qualified(p.id)
  );
$$;

create function private.teen_guardian_activation_consent_valid(p_teen_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from private.teen_guardian_activation_consent c
    where c.teen_id = p_teen_id and c.closed_at is null
      and c.consent_version = private.teen_guardian_consent_current_version()
      and c.teen_assented_at is not null and c.guardian_consented_at is not null
      and private.teen_guardian_consent_guardian_eligible(c.guardian_id)
  );
$$;

create function public.get_teen_guardian_consent_status_v1()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_actor uuid := auth.uid();
  v_profile_status text;
  v_status text;
  v record;
  v_version integer := private.teen_guardian_consent_current_version();
begin
  select account_status into v_profile_status
  from public.profiles where id = v_actor and role = 'teen'::public.mort_role;
  if not found then return jsonb_build_object('ok', false, 'code', 'not_eligible'); end if;

  select * into v
  from private.teen_guardian_activation_consent
  where teen_id = v_actor
  order by (closed_at is null) desc, issued_at desc, request_id
  limit 1;

  v_status := case
    when not found or v.consent_version <> v_version then 'required'
    when v.close_reason = 'participant_withdrew' then 'withdrawn'
    when v.close_reason = 'request_expired' then 'expired'
    when v.closed_at is not null then 'invalidated'
    when v.guardian_consented_at is null and v.expires_at <= now() then 'expired'
    when not private.teen_guardian_consent_guardian_eligible(v.guardian_id) then 'guardian_not_eligible'
    when v.teen_assented_at is null then 'awaiting_teen_assent'
    when v.guardian_consented_at is null then 'awaiting_guardian_consent'
    when v_profile_status = 'pending' then 'ready_for_staff_review'
    else 'consent_recorded'
  end;

  return jsonb_build_object(
    'ok', true, 'contract_version', 1, 'consent_version', v_version, 'status', v_status,
    'request_id', case when v_status in (
      'awaiting_teen_assent', 'awaiting_guardian_consent', 'ready_for_staff_review',
      'consent_recorded', 'guardian_not_eligible'
    ) then v.request_id end,
    'expires_at', case when v_status in ('awaiting_teen_assent', 'awaiting_guardian_consent')
      then v.expires_at end
  );
end;
$$;

create function public.attest_teen_guardian_authority_v1(
  p_teen_id uuid, p_guardian_id uuid, p_authority_ref uuid, p_consent_version integer
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_actor uuid := auth.uid();
  v_id uuid;
  v_now timestamptz;
  v_expires timestamptz;
  v_version integer := private.teen_guardian_consent_current_version();
begin
  if v_actor is null or not private.has_staff_role(array['admin']::public.mort_role[]) then
    return jsonb_build_object('ok', false, 'code', 'administrator_required');
  end if;
  if p_consent_version is distinct from v_version then
    return jsonb_build_object('ok', false, 'code', 'consent_version_required');
  end if;
  if p_teen_id is null or p_guardian_id is null or p_authority_ref is null
      or p_teen_id = p_guardian_id or v_actor in (p_teen_id, p_guardian_id) then
    return jsonb_build_object('ok', false, 'code', 'request_unavailable');
  end if;

  perform 1 from public.profiles
  where id = p_teen_id and role = 'teen'::public.mort_role and account_status = 'pending'
  for update;
  if not found or not private.teen_guardian_consent_guardian_eligible(p_guardian_id) then
    return jsonb_build_object('ok', false, 'code', 'request_unavailable');
  end if;

  v_now := clock_timestamp();
  v_expires := v_now + interval '7 days';
  update private.teen_guardian_activation_consent
  set closed_at = v_now, closed_by = v_actor, close_reason = 'request_expired'
  where teen_id = p_teen_id and closed_at is null and guardian_consented_at is null and expires_at <= v_now;

  -- Binding is based on an approved review process, not on the UUID by itself.
  -- Only an opaque, one-use reference is retained here; no evidence is uploaded.
  insert into private.teen_guardian_activation_consent
    (teen_id, guardian_id, issuer_id, authority_ref, consent_version, issued_at, expires_at)
  values (p_teen_id, p_guardian_id, v_actor, p_authority_ref, v_version, v_now, v_expires)
  on conflict do nothing returning request_id into v_id;
  if v_id is null then return jsonb_build_object('ok', false, 'code', 'request_unavailable'); end if;
  return jsonb_build_object('ok', true, 'code', 'authority_attested', 'request_id', v_id, 'expires_at', v_expires);
end;
$$;

create function public.record_teen_guardian_assent_v1(p_request_id uuid, p_consent_version integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_actor uuid := auth.uid();
  v_now timestamptz;
  v_version integer := private.teen_guardian_consent_current_version();
begin
  if p_consent_version is distinct from v_version then
    return jsonb_build_object('ok', false, 'code', 'consent_version_required');
  end if;
  perform 1 from public.profiles
  where id = v_actor and role = 'teen'::public.mort_role and account_status = 'pending'
  for update;
  if not found then return jsonb_build_object('ok', false, 'code', 'request_unavailable'); end if;

  v_now := clock_timestamp();
  update private.teen_guardian_activation_consent
  set teen_assented_at = v_now
  where request_id = p_request_id and teen_id = v_actor and consent_version = v_version
    and closed_at is null and teen_assented_at is null and expires_at > v_now
    and private.teen_guardian_consent_guardian_eligible(guardian_id);
  if not found then return jsonb_build_object('ok', false, 'code', 'request_unavailable'); end if;
  return jsonb_build_object('ok', true, 'code', 'teen_assent_recorded');
end;
$$;

create function public.accept_teen_guardian_consent_v1(p_request_id uuid, p_consent_version integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_actor uuid := auth.uid();
  v_teen_id uuid;
  v_now timestamptz;
  v_version integer := private.teen_guardian_consent_current_version();
begin
  if p_consent_version is distinct from v_version then
    return jsonb_build_object('ok', false, 'code', 'consent_version_required');
  end if;
  select teen_id into v_teen_id from private.teen_guardian_activation_consent
    where request_id = p_request_id and guardian_id = v_actor;
  perform 1 from public.profiles
  where id = v_teen_id and role = 'teen'::public.mort_role and account_status = 'pending'
  for update;
  if not found or not private.teen_guardian_consent_guardian_eligible(v_actor) then
    return jsonb_build_object('ok', false, 'code', 'request_unavailable');
  end if;

  v_now := clock_timestamp();
  update private.teen_guardian_activation_consent
  set guardian_consented_at = v_now
  where request_id = p_request_id and teen_id = v_teen_id and guardian_id = v_actor and consent_version = v_version
    and closed_at is null and teen_assented_at is not null
    and guardian_consented_at is null and expires_at > v_now;
  if not found then return jsonb_build_object('ok', false, 'code', 'request_unavailable'); end if;

  perform private.mort_queue_role_activation(v_teen_id);
  return jsonb_build_object('ok', true, 'code', 'guardian_consent_recorded');
end;
$$;

create function private.teen_guardian_consent_close(
  p_request_id uuid, p_actor uuid, p_reason text, p_require_participant boolean
)
returns boolean language plpgsql security definer set search_path = '' as $$
declare
  v_teen_id uuid;
  v_had_consent boolean;
begin
  select teen_id into v_teen_id
  from private.teen_guardian_activation_consent
  where request_id = p_request_id
    and (not p_require_participant or p_actor in (teen_id, guardian_id));
  perform 1 from public.profiles
  where id = v_teen_id and role = 'teen'::public.mort_role
  for update;
  if not found then return false; end if;

  update private.teen_guardian_activation_consent
  set closed_at = clock_timestamp(), closed_by = p_actor, close_reason = p_reason
  where request_id = p_request_id and teen_id = v_teen_id and closed_at is null
    and (not p_require_participant or p_actor in (teen_id, guardian_id))
    and (not p_require_participant or guardian_consented_at is not null or expires_at > clock_timestamp())
  returning guardian_consented_at is not null into v_had_consent;
  if not found then return false; end if;

  -- Keep the Auth identity, support/deletion routes and evidence intact.
  -- An unsigned pending request cannot suspend an account.
  if v_had_consent then
    update public.profiles set account_status = 'suspended', updated_at = now()
    where id = v_teen_id and role = 'teen'::public.mort_role and account_status = 'active';
  end if;
  return true;
end;
$$;

create function public.withdraw_teen_guardian_consent_v1(p_request_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_actor uuid := auth.uid();
begin
  if v_actor is null or not private.teen_guardian_consent_close(
    p_request_id, v_actor, 'participant_withdrew', true
  ) then return jsonb_build_object('ok', false, 'code', 'request_unavailable'); end if;
  return jsonb_build_object('ok', true, 'code', 'consent_withdrawn');
end;
$$;

create function public.invalidate_teen_guardian_consent_v1(p_request_id uuid, p_reason_code text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_actor uuid := auth.uid();
begin
  if v_actor is null or not private.has_staff_role(array['admin']::public.mort_role[]) then
    return jsonb_build_object('ok', false, 'code', 'administrator_required');
  end if;
  if p_reason_code is null or p_reason_code not in ('authority_invalid', 'policy_recheck', 'guardian_no_longer_eligible') then
    return jsonb_build_object('ok', false, 'code', 'reason_required');
  end if;
  if not private.teen_guardian_consent_close(p_request_id, v_actor, p_reason_code, false) then
    return jsonb_build_object('ok', false, 'code', 'request_unavailable');
  end if;
  return jsonb_build_object('ok', true, 'code', 'consent_invalidated');
end;
$$;

-- Preserve existing legal/onboarding and role-verification predicates. Only
-- the teen activation branch gains the separate consent requirement.
create or replace function private.mort_is_eligible_for_role_activation(p_user_id uuid, p_role public.mort_role)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.profiles pr where pr.id=p_user_id and pr.onboarding_completed_at is not null)
  and private.mort_user_has_current_legal_acceptances(p_user_id)
  and case p_role
  when 'teen'::public.mort_role then (
    private.teen_guardian_activation_consent_valid(p_user_id)
    and exists(select 1 from public.verification_cases vc join private.verification_provider_allowlist pa on pa.provider_key=vc.provider and pa.verification_type=vc.verification_type and pa.is_enabled where vc.user_id=p_user_id and vc.verification_type='age' and vc.status='verified'::public.mort_verification_status and (vc.expires_at is null or vc.expires_at>now()))
    and exists(select 1 from public.verification_cases vc join private.verification_provider_allowlist pa on pa.provider_key=vc.provider and pa.verification_type=vc.verification_type and pa.is_enabled where vc.user_id=p_user_id and vc.verification_type='school_id' and vc.status='verified'::public.mort_verification_status and (vc.expires_at is null or vc.expires_at>now()))
    and exists(select 1 from auth.users u where u.id=p_user_id and u.email_confirmed_at is not null and private.is_approved_school_email(u.email)))
  when 'adult'::public.mort_role then exists(select 1 from public.verification_cases vc join private.verification_provider_allowlist pa on pa.provider_key=vc.provider and pa.verification_type=vc.verification_type and pa.is_enabled where vc.user_id=p_user_id and vc.verification_type='identity' and vc.status='verified'::public.mort_verification_status and (vc.expires_at is null or vc.expires_at>now()))
  when 'guardian'::public.mort_role then private.teen_guardian_identity_qualified(p_user_id)
  else false end;
$$;

-- Same baseline reviewer, with a uniform profile-before-request lock order.
-- The admin status RPC already holds the profile lock before calling it.
create or replace function public.mort_review_role_request(
  p_request_id uuid, p_approve boolean, p_reason text default null
)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_target uuid;
  v_req public.role_requests%rowtype;
begin
  if v_user is null or not private.has_staff_role(array['admin']::public.mort_role[]) then raise exception 'Administrator role required for role approval'; end if;
  if p_approve is null then raise exception 'Approval decision is required'; end if;
  select user_id into v_target from public.role_requests where id = p_request_id;
  if not found then raise exception 'Pending role request not found'; end if;
  if v_target = v_user then raise exception 'self_review_not_allowed'; end if;
  perform 1 from public.profiles where id = v_target for update;
  if not found then raise exception 'Profile not found'; end if;
  select * into v_req from public.role_requests where id = p_request_id and user_id = v_target for update;
  if not found or v_req.status <> 'pending' then raise exception 'Pending role request not found'; end if;
  if p_approve then
    if not private.mort_is_eligible_for_role_activation(v_req.user_id, v_req.requested_role) then
      raise exception 'Role request does not meet the required verification tracks';
    end if;
    update public.profiles set role=v_req.requested_role,account_status='active',updated_at=now() where id=v_req.user_id;
    update public.role_requests set status='approved',reviewed_at=now(),reviewed_by=v_user,review_note=nullif(btrim(p_reason),'') where id=p_request_id;
  else
    update public.role_requests set status='rejected',reviewed_at=now(),reviewed_by=v_user,review_note=nullif(btrim(p_reason),'') where id=p_request_id;
  end if;
  insert into public.admin_audit_log(actor_id,action,target_type,target_id,reason,metadata)
  values(v_user,case when p_approve then 'role_request_approved' else 'role_request_rejected' end,
    'role_request',p_request_id::text,nullif(btrim(p_reason),''),
    jsonb_build_object('user_id',v_req.user_id,'requested_role',v_req.requested_role));
  return p_request_id;
end;
$$;

-- Backstop for any other profile-write path, not an active-account backfill.
create function private.require_teen_guardian_consent_on_activation()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.role <> 'teen'::public.mort_role or new.account_status <> 'active' then return new; end if;
  if tg_op = 'UPDATE' then
    if old.role = new.role and old.account_status = new.account_status then return new; end if;
  end if;
  if not private.teen_guardian_activation_consent_valid(new.id) then
    raise exception 'current_guardian_consent_required' using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger require_teen_guardian_consent_on_activation
  before insert or update of role, account_status on public.profiles
  for each row execute function private.require_teen_guardian_consent_on_activation();

revoke all on function
  private.teen_guardian_consent_current_version(),
  private.teen_guardian_identity_qualified(uuid),
  private.teen_guardian_consent_guardian_eligible(uuid),
  private.teen_guardian_activation_consent_valid(uuid),
  private.teen_guardian_consent_close(uuid, uuid, text, boolean),
  private.require_teen_guardian_consent_on_activation()
  from public, anon, authenticated, service_role;
revoke all on function
  public.get_teen_guardian_consent_status_v1(),
  public.attest_teen_guardian_authority_v1(uuid, uuid, uuid, integer),
  public.record_teen_guardian_assent_v1(uuid, integer),
  public.accept_teen_guardian_consent_v1(uuid, integer),
  public.withdraw_teen_guardian_consent_v1(uuid),
  public.invalidate_teen_guardian_consent_v1(uuid, text)
  from public, anon, authenticated, service_role;
grant execute on function
  public.get_teen_guardian_consent_status_v1(),
  public.attest_teen_guardian_authority_v1(uuid, uuid, uuid, integer),
  public.record_teen_guardian_assent_v1(uuid, integer),
  public.accept_teen_guardian_consent_v1(uuid, integer),
  public.withdraw_teen_guardian_consent_v1(uuid),
  public.invalidate_teen_guardian_consent_v1(uuid, text)
  to authenticated;
notify pgrst, 'reload schema';
commit;
