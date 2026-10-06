-- Qualify pgcrypto calls while retaining empty security-definer search paths.
-- CREATE OR REPLACE retains existing grants; the raw-code verifier stays revoked.

create or replace function public.start_mort_verify_teen_session(
  p_school_email text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_control private.mort_verify_control%rowtype;
  v_profile public.profiles%rowtype;
  v_domain text;
  v_school public.school_domains%rowtype;
  v_environment public.verification_environment;
  v_session_id uuid := gen_random_uuid();
  v_verification public.identity_verifications%rowtype;
  v_age integer;
  v_email text := lower(btrim(coalesce(p_school_email, '')));
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;

  select * into v_control from private.mort_verify_control_row();
  if v_control.mode = 'disabled'
     or not v_control.school_email_enabled
     or not v_control.school_id_enabled then
    return jsonb_build_object(
      'ok', false,
      'code', 'mort_verify_disabled',
      'message', 'MORT Verify is not accepting submissions yet.'
    );
  end if;

  select * into v_profile
  from public.profiles profile
  where profile.id = auth.uid();

  if v_profile.id is null or v_profile.role <> 'teen' or v_profile.dob is null then
    return jsonb_build_object('ok', false, 'code', 'teen_profile_age_required');
  end if;

  v_age := date_part('year', age(current_date, v_profile.dob))::integer;
  if v_age < 13 then
    return jsonb_build_object('ok', false, 'code', 'under_13_not_eligible');
  end if;
  if v_age >= 18 then
    return jsonb_build_object('ok', false, 'code', 'adult_account_required');
  end if;

  if v_control.mode = 'sandbox' and not v_profile.is_test_account then
    return jsonb_build_object('ok', false, 'code', 'sandbox_test_account_required');
  end if;
  if v_control.mode = 'production' and not v_control.production_document_collection_approved then
    return jsonb_build_object('ok', false, 'code', 'production_collection_not_approved');
  end if;

  if char_length(v_email) < 3
     or char_length(v_email) > 320
     or position('@' in v_email) <= 1 then
    return jsonb_build_object('ok', false, 'code', 'invalid_school_email');
  end if;

  if exists (
    select 1 from private.mort_verify_sessions session
    where session.user_id = auth.uid()
      and session.status in (
        'email_pending','school_id_required','document_pending',
        'manual_review','needs_age_evidence'
      )
  ) then
    return jsonb_build_object('ok', false, 'code', 'mort_verify_session_already_active');
  end if;

  v_environment := case
    when v_control.mode = 'sandbox' then 'sandbox'::public.verification_environment
    else 'production'::public.verification_environment
  end;

  v_domain := lower(split_part(v_email, '@', 2));

  select * into v_school
  from public.school_domains school
  where school.normalized_domain = v_domain
    and school.environment = v_environment
    and school.status = 'approved'
    and (school.expires_at is null or school.expires_at > now())
  order by school.approved_at desc nulls last, school.created_at desc
  limit 1;

  if v_school.id is null then
    return jsonb_build_object(
      'ok', false,
      'code', 'school_domain_not_approved',
      'message', 'That school email domain has not been approved for MORT Verify.'
    );
  end if;

  if exists (
    select 1 from public.identity_verifications verification
    where verification.user_id = auth.uid()
      and verification.status in (
        'verification_started','verification_pending',
        'additional_information_required','manual_review','appeal_pending'
      )
  ) then
    return jsonb_build_object('ok', false, 'code', 'identity_verification_already_active');
  end if;

  insert into public.identity_verifications (
    id,
    user_id,
    account_role,
    evidence_route,
    provider,
    provider_reference,
    status,
    verification_level,
    age_band,
    identity_match_result,
    liveness_result,
    email_verification_result,
    phone_verification_result,
    address_validation_result,
    submitted_at,
    retention_delete_at,
    risk_flags,
    audit_version,
    environment,
    decision_source
  ) values (
    gen_random_uuid(),
    auth.uid(),
    'teen',
    'school_photo_id',
    'mort_verify',
    'mort-verify:' || v_session_id::text,
    'verification_started',
    0,
    'teen_13_17',
    'not_checked',
    'not_checked',
    'pending',
    'not_checked',
    'not_checked',
    null,
    now() + make_interval(days => v_control.raw_document_retention_days),
    jsonb_build_object(
      'school_domain_id', v_school.id,
      'first_party', true,
      'legal_identity_claimed', false,
      'age_claim_only', true
    ),
    'mort-verify-v1',
    v_environment,
    'mort_verify_pending'
  ) returning * into v_verification;

  insert into private.mort_verify_sessions (
    id,
    user_id,
    identity_verification_id,
    environment,
    school_domain_id,
    school_email,
    school_email_hash,
    claimed_dob,
    status,
    expires_at,
    retention_delete_at
  ) values (
    v_session_id,
    auth.uid(),
    v_verification.id,
    v_environment,
    v_school.id,
    v_email,
    encode(extensions.digest(convert_to(v_email, 'UTF8'), 'sha256'), 'hex'),
    v_profile.dob,
    'email_pending',
    now() + make_interval(hours => v_control.session_ttl_hours),
    now() + make_interval(days => v_control.raw_document_retention_days)
  );

  insert into private.mort_verify_audit_events(
    session_id,user_id,actor_id,action,safe_metadata
  ) values (
    v_session_id,auth.uid(),auth.uid(),'session_started',
    jsonb_build_object(
      'environment', v_environment,
      'school_domain_id', v_school.id,
      'claimed_age_eligible', true
    )
  );

  return jsonb_build_object(
    'ok', true,
    'session_id', v_session_id,
    'status', 'email_pending',
    'school', v_school.organization_name,
    'email_masked',
      left(split_part(v_email,'@',1), 1) || '***@' || v_domain,
    'age_verified', false,
    'school_affiliation_verified', false,
    'student_identity_verified', false,
    'expires_at', now() + make_interval(hours => v_control.session_ttl_hours)
  );
end;
$$;

create or replace function public.verify_mort_school_email_code(
  p_session_id uuid,
  p_code text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session private.mort_verify_sessions%rowtype;
  v_challenge private.mort_verify_email_challenges%rowtype;
  v_hash text;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;

  if p_code is null or p_code !~ '^[0-9]{8}$' then
    return jsonb_build_object('ok', false, 'code', 'invalid_verification_code');
  end if;

  select * into v_session
  from private.mort_verify_sessions session
  where session.id = p_session_id
    and session.user_id = auth.uid()
    and session.status = 'email_pending'
    and session.expires_at > now()
  for update;

  if v_session.id is null then
    return jsonb_build_object('ok', false, 'code', 'session_not_available');
  end if;

  select * into v_challenge
  from private.mort_verify_email_challenges challenge
  where challenge.session_id = p_session_id
    and challenge.consumed_at is null
    and challenge.delivery_status = 'sent'
  order by challenge.created_at desc
  limit 1
  for update;

  if v_challenge.id is null or v_challenge.expires_at <= now() then
    return jsonb_build_object('ok', false, 'code', 'verification_code_expired');
  end if;
  if v_challenge.attempts >= 5 then
    return jsonb_build_object('ok', false, 'code', 'verification_code_attempts_exhausted');
  end if;

  v_hash := encode(extensions.digest(convert_to(p_code, 'UTF8'), 'sha256'), 'hex');

  if v_hash <> v_challenge.code_hash then
    update private.mort_verify_email_challenges
    set attempts = attempts + 1
    where id = v_challenge.id;
    return jsonb_build_object('ok', false, 'code', 'verification_code_invalid');
  end if;

  update private.mort_verify_email_challenges
  set consumed_at = now(), delivery_status = 'consumed'
  where id = v_challenge.id;

  update private.mort_verify_sessions
  set school_email_verified_at = now(),
      status = 'school_id_required',
      updated_at = now()
  where id = p_session_id;

  update public.identity_verifications
  set email_verification_result = 'school_email_verified',
      status = 'additional_information_required',
      updated_at = now()
  where id = v_session.identity_verification_id;

  insert into private.mort_verify_audit_events(
    session_id,user_id,actor_id,action,safe_metadata
  ) values (
    p_session_id,auth.uid(),auth.uid(),'school_email_verified',
    jsonb_build_object('challenge_id', v_challenge.id)
  );

  return jsonb_build_object(
    'ok', true,
    'status', 'school_id_required',
    'school_email_verified', true,
    'next_step', 'school_id'
  );
end;
$$;
