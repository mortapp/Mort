-- Keep compatibility RPCs fail-closed while explicitly consuming legacy inputs.

create or replace function public.start_identity_verification(
  p_evidence_route text,
  p_attested boolean default false,
  p_exception_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_profile public.profiles%rowtype;
  v_verification public.identity_verifications%rowtype;
  v_provider_reference text;
  v_mode text := private.identity_verification_mode();
begin
  perform p_exception_reason;

  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;

  select * into v_profile from public.profiles profile where profile.id = auth.uid();
  if v_profile.id is null or v_profile.role is null or v_profile.dob is null then
    return jsonb_build_object('ok', false, 'code', 'profile_age_required');
  end if;
  if v_profile.role = 'admin' then
    return jsonb_build_object('ok', false, 'code', 'admin_verification_managed_server_side');
  end if;

  if v_mode = 'disabled' then
    return jsonb_build_object(
      'ok', false,
      'code', 'identity_verification_disabled',
      'message', 'Identity verification is not accepting public submissions yet. Do not upload an ID or personal document.'
    );
  end if;

  if v_mode = 'production' then
    if not private.production_identity_ready() then
      return jsonb_build_object('ok', false, 'code', 'production_verification_not_ready');
    end if;
    return jsonb_build_object('ok', false, 'code', 'production_provider_session_unavailable');
  end if;

  if not v_profile.is_test_account then
    return jsonb_build_object('ok', false, 'code', 'sandbox_qa_account_required');
  end if;
  if lower(btrim(coalesce(p_evidence_route, ''))) <> 'sandbox_simulation' then
    return jsonb_build_object(
      'ok', false,
      'code', 'sandbox_documents_prohibited',
      'message', 'Test verification - do not use real documents.'
    );
  end if;
  if not p_attested then
    return jsonb_build_object('ok', false, 'code', 'sandbox_test_attestation_required');
  end if;

  if exists (
    select 1
    from public.identity_verifications verification
    where verification.user_id = auth.uid()
      and verification.status in (
        'verification_started', 'verification_pending',
        'additional_information_required', 'manual_review', 'appeal_pending'
      )
  ) then
    return jsonb_build_object('ok', false, 'code', 'verification_already_active');
  end if;

  v_provider_reference := 'sandbox-' || gen_random_uuid()::text;
  insert into public.identity_verifications (
    user_id,
    account_role,
    evidence_route,
    provider,
    provider_reference,
    environment,
    decision_source,
    status,
    verification_level,
    age_band,
    retention_delete_at,
    risk_flags,
    audit_version
  ) values (
    auth.uid(),
    v_profile.role,
    'legacy_approved_record',
    'mort_sandbox',
    v_provider_reference,
    'sandbox',
    'sandbox_simulation',
    'verification_pending',
    0,
    case when v_profile.role = 'teen' then 'teen_13_17' else 'adult_18_plus' end,
    now() + interval '7 days',
    jsonb_build_object(
      'isolated_qa', true,
      'documents_collected', false,
      'production_eligible', false
    ),
    'provider-safe-sandbox-v1'
  ) returning * into v_verification;

  insert into private.identity_verification_sessions (
    verification_id,
    user_id,
    environment,
    provider,
    provider_reference,
    workflow_reference,
    status,
    expires_at
  ) values (
    v_verification.id,
    auth.uid(),
    'sandbox',
    'mort_sandbox',
    v_provider_reference,
    'simulation-no-documents-v1',
    'pending',
    now() + interval '1 hour'
  );

  insert into public.verification_audit_events (
    verification_id, actor_id, action, event_data
  ) values (
    v_verification.id,
    auth.uid(),
    'sandbox_session_started',
    jsonb_build_object(
      'environment', 'sandbox',
      'documents_collected', false,
      'production_eligible', false
    )
  );

  return jsonb_build_object(
    'ok', true,
    'id', v_verification.id,
    'status', v_verification.status,
    'environment', 'sandbox',
    'provider', 'mort_sandbox',
    'provider_reference', v_provider_reference,
    'test_mode', true,
    'documents_allowed', false,
    'production_eligible', false,
    'message', 'Test verification - do not use real documents.',
    'guardian_mode_optional', true
  );
end;
$$;

create or replace function public.admin_review_identity_verification(
  p_verification_id uuid,
  p_action text,
  p_decision_code text default null,
  p_identity_match_result text default 'not_checked',
  p_liveness_result text default 'not_checked',
  p_email_result text default 'not_checked',
  p_phone_result text default 'not_checked',
  p_address_result text default 'not_checked',
  p_expires_at timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_verification public.identity_verifications%rowtype;
begin
  perform
    p_decision_code,
    p_identity_match_result,
    p_liveness_result,
    p_email_result,
    p_phone_result,
    p_address_result,
    p_expires_at;

  if auth.uid() is null
     or not private.is_production_identity_reviewer(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'production_identity_reviewer_required');
  end if;
  if not private.production_identity_ready() then
    return jsonb_build_object('ok', false, 'code', 'production_verification_not_ready');
  end if;

  select * into v_verification
  from public.identity_verifications verification
  where verification.id = p_verification_id
    and verification.environment = 'production';
  if v_verification.id is null then
    return jsonb_build_object('ok', false, 'code', 'production_verification_not_found');
  end if;

  if lower(btrim(coalesce(p_action, ''))) = 'approve' then
    return jsonb_build_object(
      'ok', false,
      'code', 'signed_provider_decision_required',
      'message', 'A client or ordinary admin cannot approve production identity verification.'
    );
  end if;

  return jsonb_build_object(
    'ok', false,
    'code', 'provider_review_workflow_not_configured',
    'message', 'Production reviewer actions remain unavailable until an approved workflow is configured.'
  );
end;
$$;
