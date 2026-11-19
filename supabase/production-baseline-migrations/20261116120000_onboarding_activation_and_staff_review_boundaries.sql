-- Production-baseline migration: onboarding activation and staff review boundaries.
-- Source of truth: live production definitions read 2026-11-16 (catalog parity
-- verified against the local production replica). Each function below is the
-- exact production body with the minimal change described in its comment.
--
-- Defects fixed (all reproduced through the public API on the replica):
--   D2  A pending teen could not choose "skip guardian" during onboarding:
--       set_guardian_setup_skipped() required an already-active teen, and
--       save_my_onboarding_safety_v2 discarded its refusal.
--   D3  Staff activation did not require completed onboarding or current
--       legal acceptance; an account that never finished onboarding could be
--       made active.
--   D4  Guardians could never be activated (no eligibility track, role_requests
--       check constraint excluded guardian), so accept_guardian_invite() --
--       which requires an active guardian -- was unreachable.
--   D5  profiles.guardian_setup_status was client-writable via PostgREST, so a
--       teen could assert "linked" without any guardian.
--   D6  Staff could record and approve their own verification evidence and
--       role request (no separation of duties).
--
-- No RLS is disabled, no grants are broadened. Stripe objects are untouched.

begin;

-- D5: remove the client column grant; the value is owned by guardian RPCs.
revoke update (guardian_setup_status) on public.profiles from authenticated;
revoke update (guardian_setup_status) on public.profiles from anon;

-- D4: allow guardian activation requests (still staff-approved, identity-verified).
alter table public.role_requests drop constraint role_requests_requested_role_check;
alter table public.role_requests add constraint role_requests_requested_role_check
  check (requested_role = any (array['teen'::public.mort_role, 'adult'::public.mort_role, 'guardian'::public.mort_role]));


-- D3/D4: activation requires completed onboarding + current legal acceptance; adds the guardian track.
CREATE OR REPLACE FUNCTION private.mort_is_eligible_for_role_activation(p_user_id uuid, p_role mort_role)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select exists(select 1 from public.profiles pr where pr.id=p_user_id and pr.onboarding_completed_at is not null)
  and private.mort_user_has_current_legal_acceptances(p_user_id)
  and case p_role
 when 'teen'::public.mort_role then (
  exists(select 1 from public.verification_cases vc join private.verification_provider_allowlist pa on pa.provider_key=vc.provider and pa.verification_type=vc.verification_type and pa.is_enabled where vc.user_id=p_user_id and vc.verification_type='age' and vc.status='verified'::public.mort_verification_status and (vc.expires_at is null or vc.expires_at>now()))
  and exists(select 1 from public.verification_cases vc join private.verification_provider_allowlist pa on pa.provider_key=vc.provider and pa.verification_type=vc.verification_type and pa.is_enabled where vc.user_id=p_user_id and vc.verification_type='school_id' and vc.status='verified'::public.mort_verification_status and (vc.expires_at is null or vc.expires_at>now()))
  and exists(select 1 from auth.users u where u.id=p_user_id and u.email_confirmed_at is not null and private.is_approved_school_email(u.email)))
 when 'adult'::public.mort_role then exists(select 1 from public.verification_cases vc join private.verification_provider_allowlist pa on pa.provider_key=vc.provider and pa.verification_type=vc.verification_type and pa.is_enabled where vc.user_id=p_user_id and vc.verification_type='identity' and vc.status='verified'::public.mort_verification_status and (vc.expires_at is null or vc.expires_at>now()))
 when 'guardian'::public.mort_role then (
  exists(select 1 from public.verification_cases vc join private.verification_provider_allowlist pa on pa.provider_key=vc.provider and pa.verification_type=vc.verification_type and pa.is_enabled where vc.user_id=p_user_id and vc.verification_type='identity' and vc.status='verified'::public.mort_verification_status and (vc.expires_at is null or vc.expires_at>now()))
  and exists(select 1 from public.profiles pr where pr.id=p_user_id and pr.date_of_birth is not null and private.mort_age_years(pr.date_of_birth) >= 18)
  and exists(select 1 from auth.users u where u.id=p_user_id and u.email_confirmed_at is not null))
 else false end;
$function$;


-- D4: queue guardian activation requests.
CREATE OR REPLACE FUNCTION private.mort_queue_role_activation(p_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_role public.mort_role; v_status text;
begin
 select role,account_status into v_role,v_status from public.profiles where id=p_user_id for update;
 if not found or v_status<>'pending' or v_role not in ('teen','adult','guardian') then return; end if;
 if not private.mort_is_eligible_for_role_activation(p_user_id,v_role) then return; end if;
 if exists(select 1 from public.role_requests where user_id=p_user_id and status='pending') then return; end if;
 insert into public.role_requests(user_id,requested_role,status) values(p_user_id,v_role,'pending');
end;
$function$;


-- D3: queue activation when onboarding completes after verification.
CREATE OR REPLACE FUNCTION public.complete_my_onboarding_v2(p_payload jsonb, p_client_request_id uuid, p_payload_version integer DEFAULT 1, p_expected_revision text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  user_id uuid := auth.uid();
  progress jsonb;
  completed_at timestamptz;
begin
  if user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object'
     or p_client_request_id is null or p_payload_version <> 1 then
    return jsonb_build_object('ok', false, 'code', 'onboarding_request_invalid');
  end if;

  select profile.onboarding_completed_at into completed_at
  from public.profiles profile
  where profile.id = user_id;
  if completed_at is not null then
    return jsonb_build_object('ok', true, 'already_completed', true, 'completed_at', completed_at);
  end if;

  progress := private.evaluate_mort_onboarding(user_id);
  if progress->>'active_step' <> 'review' then
    return jsonb_build_object(
      'ok', false,
      'code', 'onboarding_steps_incomplete',
      'missing_requirements', progress->'missing_requirements'
    );
  end if;
  if not private.mort_user_has_current_legal_acceptances(user_id) then
    return jsonb_build_object('ok', false, 'code', 'published_legal_acceptance_required');
  end if;

  update public.profiles
  set onboarding_completed_at = coalesce(onboarding_completed_at, now()),
      updated_at = now()
  where id = user_id
  returning onboarding_completed_at into completed_at;

  -- D3: evidence may be verified before onboarding finishes; queue now.
  perform private.mort_queue_role_activation(user_id);

  return jsonb_build_object('ok', true, 'already_completed', false, 'completed_at', completed_at);
end;
$function$;


-- D2: a pending teen may skip guardian setup while onboarding.
CREATE OR REPLACE FUNCTION public.set_guardian_setup_skipped()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  user_id uuid := auth.uid();
begin
  if user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if private.current_role() <> 'teen'::public.mort_role
     or not (
       private.is_active_user()
       or exists (select 1 from public.profiles op where op.id = user_id
                  and op.account_status = 'pending' and op.onboarding_completed_at is null)
     )
     or not exists (
       select 1
       from public.profiles p
       where p.id = user_id
         and p.date_of_birth is not null
         and extract(year from age(current_date, p.date_of_birth)) between 13 and 17
     ) then
    return jsonb_build_object('ok', false, 'code', 'active_teen_account_required');
  end if;

  update public.guardian_links
  set status = 'revoked', updated_at = now()
  where teen_user_id = user_id and status = 'pending';

  update private.guardian_invite_codes
  set consumed_at = coalesce(consumed_at, now())
  where teen_user_id = user_id and consumed_at is null;

  update public.profiles
  set guardian_setup_status = 'skipped', updated_at = now()
  where id = user_id;

  return private.evaluate_mort_onboarding(user_id) || jsonb_build_object('ok', true);
end;
$function$;


-- D2: surface a refused guardian skip instead of discarding it.
CREATE OR REPLACE FUNCTION public.save_my_onboarding_safety_v2(p_payload jsonb, p_client_request_id uuid, p_payload_version integer DEFAULT 1, p_expected_revision text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user_id uuid := auth.uid();
  profile public.profiles%rowtype;
  intent text := coalesce(p_payload->>'notification_intent', 'ask_later');
  guardian_choice text := coalesce(p_payload->>'guardian_choice', 'not_applicable');
  unknown_keys text[];
begin
  if v_user_id is null then return jsonb_build_object('ok', false, 'code', 'authentication_required'); end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' or p_client_request_id is null or p_payload_version <> 1 then
    return jsonb_build_object('ok', false, 'code', 'onboarding_request_invalid');
  end if;
  select coalesce(array_agg(key order by key), array[]::text[]) into unknown_keys
  from jsonb_object_keys(p_payload) key where key not in ('notification_intent','guardian_choice');
  if cardinality(unknown_keys) > 0 or intent not in ('ask_later','preferred','not_preferred') then
    return jsonb_build_object('ok', false, 'code', 'onboarding_safety_support_invalid');
  end if;
  select * into profile from public.profiles where id = v_user_id for update;
  if profile.id is null then return jsonb_build_object('ok', false, 'code', 'onboarding_account_required'); end if;
  if p_expected_revision is not null and profile.updated_at is distinct from p_expected_revision::timestamptz then
    return jsonb_build_object('ok', false, 'code', 'onboarding_revision_conflict', 'revision', profile.updated_at);
  end if;
  if profile.role = 'teen'::public.mort_role then
    if guardian_choice = 'skip' then
      if coalesce((public.set_guardian_setup_skipped()->>'ok')::boolean, false) is not true then
        return jsonb_build_object('ok', false, 'code', 'guardian_skip_unavailable');
      end if;
    elsif guardian_choice = 'existing' and profile.guardian_setup_status not in ('invite_pending','linked') then
      return jsonb_build_object('ok', false, 'code', 'guardian_invite_required_or_skip');
    elsif guardian_choice not in ('existing','skip') then
      return jsonb_build_object('ok', false, 'code', 'guardian_invite_required_or_skip');
    end if;
  end if;
  insert into private.mort_onboarding_safety(user_id, notification_intent)
  values (v_user_id, intent)
  on conflict (user_id) do update set notification_intent = excluded.notification_intent, saved_at = now();
  return private.evaluate_mort_onboarding(v_user_id) || jsonb_build_object('replayed', false);
end;
$function$;


-- D6: staff cannot record a decision on their own evidence.
CREATE OR REPLACE FUNCTION public.mort_record_staff_document_review(p_case_id uuid, p_decision text, p_note text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user uuid := auth.uid();
  v_case public.verification_cases%rowtype;
  v_sha text;
begin
  if v_user is null or not private.has_staff_role(array['admin','moderator']::public.mort_role[]) then
    return jsonb_build_object('ok', false, 'code', 'authorized_reviewer_required');
  end if;
  if p_decision is null or p_decision not in ('verified','rejected') then
    return jsonb_build_object('ok', false, 'code', 'invalid_decision');
  end if;

  select * into v_case
  from public.verification_cases vc
  where vc.id = p_case_id
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'case_not_found');
  end if;
  if v_case.user_id = v_user then
    return jsonb_build_object('ok', false, 'code', 'self_review_not_allowed');
  end if;
  if v_case.provider is distinct from 'mort_staff_review' then
    return jsonb_build_object('ok', false, 'code', 'not_staff_review_case');
  end if;
  if v_case.status not in ('pending','needs_review') then
    return jsonb_build_object('ok', false, 'code', 'case_already_decided');
  end if;
  if v_case.evidence_path is null then
    return jsonb_build_object('ok', false, 'code', 'no_evidence_document');
  end if;
  if not exists (
    select 1 from storage.objects o
    where o.bucket_id = 'verification-evidence'
      and o.name = v_case.evidence_path
  ) then
    return jsonb_build_object('ok', false, 'code', 'evidence_document_missing');
  end if;
  if not exists (
    select 1 from private.verification_provider_allowlist a
    where a.provider_key = 'mort_staff_review'
      and a.verification_type = v_case.verification_type
      and a.is_enabled
  ) then
    return jsonb_build_object('ok', false, 'code', 'provider_not_allowlisted');
  end if;

  v_sha := encode(extensions.digest(convert_to(
    v_case.id::text || '|' || v_case.evidence_path || '|' || v_user::text || '|' || p_decision,
    'UTF8'), 'sha256'), 'hex');

  insert into private.verification_provider_results (
    verification_case_id, user_id, verification_type, provider_key,
    provider_reference, provider_event_id, result, evidence_sha256,
    verified_at, expires_at
  ) values (
    v_case.id, v_case.user_id, v_case.verification_type, 'mort_staff_review',
    v_case.provider_reference,
    'staff-' || v_case.id::text || '-' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISSUS'),
    p_decision, v_sha,
    case when p_decision = 'verified' then clock_timestamp() else null end,
    null
  );

  insert into public.admin_audit_log (actor_id, action, target_type, target_id, reason, metadata)
  values (v_user, 'staff_document_review_recorded', 'verification_case', v_case.id::text,
          nullif(btrim(coalesce(p_note, '')), ''),
          jsonb_build_object(
            'decision', p_decision,
            'verification_type', v_case.verification_type,
            'evidence_path', v_case.evidence_path,
            'provider_key', 'mort_staff_review'));

  return jsonb_build_object('ok', true, 'decision', p_decision);
end;
$function$;


-- D6: staff cannot review their own verification case.
CREATE OR REPLACE FUNCTION public.mort_review_verification_case(p_case_id uuid, p_status mort_verification_status, p_note text DEFAULT NULL::text, p_expires_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user uuid := auth.uid();
  v_owner uuid;
  v_snapshot public.verification_cases%rowtype;
  v_case public.verification_cases%rowtype;
  v_date_of_birth date;
  v_now timestamptz;
  v_evidence_result_id uuid;
  v_evidence_expires_at timestamptz;
begin
  if v_user is null or not private.has_staff_role(array['admin','moderator']::public.mort_role[]) then
    raise exception 'Authorized verification reviewer required';
  end if;
  if p_status not in ('verified'::public.mort_verification_status,
                      'rejected'::public.mort_verification_status,
                      'needs_review'::public.mort_verification_status,
                      'expired'::public.mort_verification_status) then
    raise exception 'Invalid review outcome';
  end if;

  -- Unlocked snapshot to discover the subject. Lock order for approvals:
  -- profile -> allowlist -> case -> provider result.
  select * into v_snapshot
  from public.verification_cases vc
  where vc.id = p_case_id;
  if not found then raise exception 'Verification case not found'; end if;
  v_owner := v_snapshot.user_id;
  if v_owner = v_user then raise exception 'self_review_not_allowed'; end if;

  if p_status = 'verified'::public.mort_verification_status then
    select profile.date_of_birth into v_date_of_birth
    from public.profiles profile
    where profile.id = v_owner
      for share;
    if not found or v_date_of_birth is null
       or extract(year from age(current_date, v_date_of_birth)) < 13 then
      raise exception 'minimum_age_verification_required';
    end if;

    -- Fail-closed provider allowlist: empty table means no approvals.
    perform provider.provider_key
    from private.verification_provider_allowlist provider
    where provider.provider_key = v_snapshot.provider
      and provider.verification_type = v_snapshot.verification_type
      and provider.is_enabled
    for share;
    if not found then
      raise exception 'trusted_verification_provider_unavailable';
    end if;
  end if;

  v_now := clock_timestamp();
  if p_expires_at is not null and p_expires_at <= v_now then
    raise exception 'verification_expiry_must_be_in_future';
  end if;

  -- Lock the case and refuse to apply a decision to changed details.
  select * into v_case
  from public.verification_cases vc
  where vc.id = p_case_id
    for update;
  if not found then raise exception 'Verification case not found'; end if;
  if v_case.user_id is distinct from v_snapshot.user_id
     or v_case.provider is distinct from v_snapshot.provider
     or v_case.verification_type is distinct from v_snapshot.verification_type
     or v_case.provider_reference is distinct from v_snapshot.provider_reference
     or v_case.status is distinct from v_snapshot.status
     or v_case.updated_at is distinct from v_snapshot.updated_at then
    raise exception 'verification_case_changed_retry';
  end if;

  if p_status = 'verified'::public.mort_verification_status then
    -- Case-bound evidence: same subject, provider, reference, and type;
    -- verified after submission, received after submission, not expired.
    select result.id, result.expires_at
      into v_evidence_result_id, v_evidence_expires_at
    from private.verification_provider_results result
    where result.verification_case_id = v_case.id
      and result.user_id = v_case.user_id
      and result.verification_type = v_case.verification_type
      and result.provider_key = v_case.provider
      and result.provider_reference is not distinct from v_case.provider_reference
      and result.result = 'verified'
      and result.verified_at <= v_now
      and result.verified_at >= coalesce(v_case.submitted_at, v_case.created_at)
      and result.received_at <= v_now
      and result.received_at >= coalesce(v_case.submitted_at, v_case.created_at)
      and (result.expires_at is null or result.expires_at > v_now)
    order by result.received_at desc
    limit 1
    for share;
    if not found then
      raise exception 'case_appropriate_provider_evidence_required';
    end if;
    -- The verification cannot outlive the provider evidence it rests on.
    if v_evidence_expires_at is not null
       and (p_expires_at is null or p_expires_at > v_evidence_expires_at) then
      raise exception 'review_expiry_exceeds_provider_evidence';
    end if;
  end if;

  update public.verification_cases
  set status=p_status, reviewer_id=v_user,
      reviewer_note=nullif(btrim(p_note),''),
      reviewed_at=v_now, expires_at=p_expires_at, updated_at=v_now
  where id=p_case_id;

  update public.profiles
  set verification_status = case p_status
        when 'verified' then 'verified'
        when 'rejected' then 'rejected'
        when 'needs_review' then 'pending'
        when 'expired' then 'expired'
      end,
      updated_at = now()
  where id = v_owner;

  insert into public.admin_audit_log(actor_id,action,target_type,target_id,reason,metadata)
  values (v_user,'verification_reviewed','verification_case',p_case_id::text,
          nullif(btrim(p_note),''),
          jsonb_build_object(
            'status', p_status,
            'provider_result_id', v_evidence_result_id,
            'provider_key', case when p_status = 'verified'::public.mort_verification_status then v_case.provider else null end
          ));

  if p_status = 'verified'::public.mort_verification_status then
    begin perform private.mort_queue_role_activation(v_owner);
    exception when others then insert into public.admin_audit_log(actor_id,action,target_type,target_id,reason,metadata) values(v_user,'role_activation_autoqueue_failed','profile',v_owner::text,SQLERRM,'{}'::jsonb); end;
  end if;
  return p_case_id;
end;
$function$;


-- D6: staff cannot approve their own role request.
CREATE OR REPLACE FUNCTION public.mort_review_role_request(p_request_id uuid, p_approve boolean, p_reason text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_user uuid:=auth.uid(); v_req public.role_requests%rowtype;
begin
 if v_user is null or not private.has_staff_role(array['admin']::public.mort_role[]) then raise exception 'Administrator role required for role approval'; end if;
 if p_approve is null then raise exception 'Approval decision is required'; end if;
 select * into v_req from public.role_requests where id=p_request_id for update;
 if not found or v_req.status<>'pending' then raise exception 'Pending role request not found'; end if;
 if v_req.user_id = v_user then raise exception 'self_review_not_allowed'; end if;
 if p_approve then
  if not private.mort_is_eligible_for_role_activation(v_req.user_id,v_req.requested_role) then raise exception 'Role request does not meet the required verification tracks'; end if;
  update public.profiles set role=v_req.requested_role,account_status='active',updated_at=now() where id=v_req.user_id;
  if not found then raise exception 'Profile not found'; end if;
  update public.role_requests set status='approved',reviewed_at=now(),reviewed_by=v_user,review_note=nullif(btrim(p_reason),'') where id=p_request_id;
 else update public.role_requests set status='rejected',reviewed_at=now(),reviewed_by=v_user,review_note=nullif(btrim(p_reason),'') where id=p_request_id; end if;
 insert into public.admin_audit_log(actor_id,action,target_type,target_id,reason,metadata) values(v_user,case when p_approve then 'role_request_approved' else 'role_request_rejected' end,'role_request',p_request_id::text,nullif(btrim(p_reason),''),jsonb_build_object('user_id',v_req.user_id,'requested_role',v_req.requested_role));
 return p_request_id;
end;
$function$;


notify pgrst, 'reload schema';

commit;
