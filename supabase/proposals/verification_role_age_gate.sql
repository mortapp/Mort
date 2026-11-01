-- PROPOSAL ONLY. Production's current role-review RPC requires an identity
-- verification case for adult role approval but does not independently verify
-- the applicant's server-stored DOB is 18+. This additive replacement preserves
-- the live signature and audit behavior while closing that role-escalation gap.
-- Do not apply until exercised against a schema-matched isolated database.

create or replace function public.mort_review_role_request(
  p_request_id uuid,
  p_approve boolean,
  p_reason text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user uuid := auth.uid();
  v_req public.role_requests%rowtype;
  v_dob date;
begin
  if v_user is null or not private.has_staff_role(array['admin']::public.mort_role[]) then
    raise exception using errcode = '42501', message = 'administrator_role_required';
  end if;

  select * into v_req
  from public.role_requests
  where id = p_request_id
  for update;
  if not found or v_req.status <> 'pending' then
    raise exception using errcode = 'P0001', message = 'pending_role_request_not_found';
  end if;

  -- Freeze verification evidence while its status is used for this role
  -- decision, so a concurrent revocation cannot race approval.
  perform verification.id
  from public.verification_cases verification
  where verification.user_id = v_req.user_id
    and verification.verification_type in ('age', 'identity', 'school_id', 'school_email')
  order by verification.id
  for share;

  if p_approve then
    if v_req.requested_role = 'teen'::public.mort_role then
      if not exists (
        select 1 from public.verification_cases vc
        where vc.user_id = v_req.user_id
          and vc.verification_type = 'age'
          and vc.status = 'verified'::public.mort_verification_status
          and (vc.expires_at is null or vc.expires_at > now())
      ) or not exists (
        select 1 from public.verification_cases vc
        where vc.user_id = v_req.user_id
          and vc.verification_type = 'school_id'
          and vc.status = 'verified'::public.mort_verification_status
          and (vc.expires_at is null or vc.expires_at > now())
      ) or not exists (
        select 1 from public.verification_cases vc
        where vc.user_id = v_req.user_id
          and vc.verification_type = 'school_email'
          and vc.status = 'verified'::public.mort_verification_status
          and (vc.expires_at is null or vc.expires_at > now())
      ) then
        raise exception using errcode = 'P0001', message = 'teen_verification_requirements_missing';
      end if;
    elsif v_req.requested_role = 'adult'::public.mort_role then
      select profile.date_of_birth into v_dob
      from public.profiles profile
      where profile.id = v_req.user_id
      for update;
      if not found or v_dob is null
        or extract(year from age(current_date, v_dob)) < 18 then
        raise exception using errcode = 'P0001', message = 'adult_minimum_age_required';
      end if;
      if not exists (
        select 1 from public.verification_cases vc
        where vc.user_id = v_req.user_id
          and vc.verification_type = 'identity'
          and vc.status = 'verified'::public.mort_verification_status
          and (vc.expires_at is null or vc.expires_at > now())
      ) then
        raise exception using errcode = 'P0001', message = 'adult_identity_verification_required';
      end if;
    else
      raise exception using errcode = 'P0001', message = 'unsupported_requested_role';
    end if;

    update public.profiles
    set role = v_req.requested_role,
        account_status = 'active',
        updated_at = now()
    where id = v_req.user_id;
    if not found then raise exception using errcode = 'P0001', message = 'profile_not_found'; end if;
    update public.role_requests
    set status = 'approved', reviewed_at = now(), reviewed_by = v_user,
        review_note = nullif(btrim(p_reason), '')
    where id = p_request_id;
  else
    update public.role_requests
    set status = 'rejected', reviewed_at = now(), reviewed_by = v_user,
        review_note = nullif(btrim(p_reason), '')
    where id = p_request_id;
  end if;

  insert into public.admin_audit_log(actor_id, action, target_type, target_id, reason, metadata)
  values (
    v_user,
    case when p_approve then 'role_request_approved' else 'role_request_rejected' end,
    'role_request', p_request_id::text, nullif(btrim(p_reason), ''),
    jsonb_build_object('user_id', v_req.user_id, 'requested_role', v_req.requested_role)
  );
  return p_request_id;
end;
$function$;

revoke all on function public.mort_review_role_request(uuid, boolean, text) from public, anon;
grant execute on function public.mort_review_role_request(uuid, boolean, text) to authenticated, service_role;
