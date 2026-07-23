-- Synthetic-only first-party trust APIs and controlled team operations.
-- Provider result writers are service-role only and still require an explicit
-- server-side signature-verification result.

create or replace function private.team_prerequisites_complete(
  p_user_id uuid,
  p_role_key text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_user_id is not null
    and exists (
      select 1 from public.team_confidentiality_acknowledgements confidentiality
      where confidentiality.user_id = p_user_id
        and confidentiality.affirmative_checkbox
        and confidentiality.revoked_at is null
        and confidentiality.expires_at > now()
    )
    and exists (
      select 1 from public.team_conflict_disclosures conflict
      where conflict.user_id = p_user_id
        and conflict.review_status = 'cleared'
        and conflict.expires_at > now()
    )
    and exists (
      select 1 from public.team_device_compliance device
      where device.user_id = p_user_id
        and device.review_status = 'approved'
        and device.expires_at > now()
    )
    and not exists (
      select 1
      from public.team_role_training_requirements requirement
      join public.team_training_modules module
        on module.module_key = requirement.module_key
       and module.active
      where requirement.role_key = p_role_key
        and requirement.required
        and not exists (
          select 1 from public.team_training_completions completion
          where completion.user_id = p_user_id
            and completion.module_key = requirement.module_key
            and completion.module_version = module.module_version
            and completion.assessment_passed
            and completion.expires_at > now()
        )
    );
$$;

create or replace function private.has_ready_team_role(
  p_user_id uuid,
  p_role_keys text[]
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_user_id is not null and exists (
    select 1
    from public.team_role_assignments assignment
    where assignment.user_id = p_user_id
      and assignment.role_key = any(p_role_keys)
      and assignment.access_status = 'active'
      and assignment.granted_at is not null
      and assignment.expires_at > now()
      and private.team_prerequisites_complete(p_user_id, assignment.role_key)
  );
$$;

create or replace function public.get_first_party_trust_status()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'real_document_collection_enabled', control.real_document_collection_enabled,
    'external_web_reuse_enabled', control.external_web_reuse_enabled,
    'real_live_presence_enabled', control.real_live_presence_enabled,
    'real_appearance_review_enabled', control.real_appearance_review_enabled,
    'synthetic_qa_only', true,
    'authoritative_identity_provider_connected', false,
    'public_marketplace_open', false,
    'document_quality_is_identity', false,
    'web_reuse_is_authenticity', false,
    'liveness_is_legal_identity', false,
    'device_biometric_is_legal_identity', false,
    'guardian_mode_optional', true
  )
  from private.first_party_trust_control control
  where control.singleton;
$$;

create or replace function public.start_synthetic_document_capture(
  p_document_type text,
  p_retention_minutes integer default 60
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile public.profiles%rowtype;
  v_session public.document_capture_sessions%rowtype;
begin
  select * into v_profile from public.profiles where id = auth.uid();
  if v_profile.id is null then return jsonb_build_object('ok', false, 'code', 'authentication_required'); end if;
  if not v_profile.is_test_account then return jsonb_build_object('ok', false, 'code', 'synthetic_qa_test_account_required'); end if;
  if p_document_type not in ('synthetic_government_id', 'synthetic_school_id', 'synthetic_test_document') then return jsonb_build_object('ok', false, 'code', 'synthetic_document_type_required'); end if;
  if p_retention_minutes not between 5 and 1440 then return jsonb_build_object('ok', false, 'code', 'bounded_retention_required'); end if;
  insert into public.document_capture_sessions (
    subject_user_id, document_type, synthetic_qa, contains_real_person_data,
    retention_expires_at
  ) values (
    v_profile.id, p_document_type, true, false, now() + make_interval(mins => p_retention_minutes)
  ) returning * into v_session;
  return jsonb_build_object('ok', true, 'capture_session_id', v_session.id, 'synthetic_qa_only', true, 'real_document_upload_allowed', false);
end;
$$;

create or replace function private.record_synthetic_document_quality_result(
  p_capture_session_id uuid,
  p_result_level text,
  p_glare_detected boolean,
  p_blur_detected boolean,
  p_cutoff_edge_detected boolean,
  p_low_resolution_detected boolean,
  p_screenshot_signal_detected boolean,
  p_reproduction_warning boolean,
  p_exact_duplicate_hash text default null,
  p_perceptual_duplicate_hash text default null,
  p_cross_account_reuse_signal boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session public.document_capture_sessions%rowtype;
  v_result public.document_capture_quality_results%rowtype;
begin
  select * into v_session from public.document_capture_sessions where id = p_capture_session_id for update;
  if v_session.id is null or not v_session.synthetic_qa or v_session.contains_real_person_data then raise exception 'Synthetic QA capture session required'; end if;
  insert into public.document_capture_quality_results (
    capture_session_id, result_level, glare_detected, blur_detected,
    cutoff_edge_detected, low_resolution_detected, screenshot_signal_detected,
    reproduction_warning, synthetic_fixture_recognized, exact_duplicate_hash,
    perceptual_duplicate_hash, cross_account_reuse_signal,
    authenticity_authoritatively_confirmed, created_by_server
  ) values (
    v_session.id, p_result_level, p_glare_detected, p_blur_detected,
    p_cutoff_edge_detected, p_low_resolution_detected, p_screenshot_signal_detected,
    p_reproduction_warning, true, p_exact_duplicate_hash,
    p_perceptual_duplicate_hash, p_cross_account_reuse_signal, false, true
  ) returning * into v_result;
  update public.document_capture_sessions
  set capture_state = case when p_result_level = 'rejected' then 'rejected' else 'completed' end,
      completed_at = now()
  where id = v_session.id;
  return v_result.id;
end;
$$;

create or replace function public.request_synthetic_web_reuse_signal(
  p_capture_session_id uuid,
  p_consent_disclosure_version text,
  p_consent_recorded boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session public.document_capture_sessions%rowtype;
  v_request public.document_web_reuse_requests%rowtype;
begin
  select * into v_session from public.document_capture_sessions where id = p_capture_session_id;
  if v_session.id is null or v_session.subject_user_id <> auth.uid() then return jsonb_build_object('ok', false, 'code', 'capture_owner_required'); end if;
  if not v_session.synthetic_qa or v_session.contains_real_person_data then return jsonb_build_object('ok', false, 'code', 'synthetic_qa_only'); end if;
  if not coalesce(p_consent_recorded, false) then return jsonb_build_object('ok', false, 'code', 'explicit_disclosure_acknowledgment_required'); end if;
  insert into public.document_web_reuse_requests (
    capture_session_id, subject_user_id, provider_key,
    consent_disclosure_version, consent_recorded, request_status,
    synthetic_qa, expires_at
  ) values (
    v_session.id, auth.uid(), 'unconfigured', left(btrim(p_consent_disclosure_version), 100),
    true, 'disabled', true, least(v_session.retention_expires_at, now() + interval '24 hours')
  ) returning * into v_request;
  return jsonb_build_object(
    'ok', true,
    'request_id', v_request.id,
    'status', 'disabled',
    'external_provider_called', false,
    'no_match_would_not_approve_identity', true,
    'match_would_require_human_review', true
  );
end;
$$;

create or replace function private.record_document_web_reuse_result(
  p_request_id uuid,
  p_provider_event_id text,
  p_provider_signature_verified boolean,
  p_result_level text,
  p_exact_full_match_count integer,
  p_partial_match_count integer,
  p_known_test_fixture_match boolean,
  p_risk_reasons text[] default '{}',
  p_reviewer_url_manifest jsonb default '[]'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request public.document_web_reuse_requests%rowtype;
  v_result public.document_web_reuse_results%rowtype;
begin
  if not coalesce(p_provider_signature_verified, false) then raise exception 'Unsigned provider result rejected'; end if;
  select * into v_request from public.document_web_reuse_requests where id = p_request_id for update;
  if v_request.id is null or not v_request.synthetic_qa then raise exception 'Synthetic web-reuse request required'; end if;
  if p_result_level not in ('document_web_reuse_signal_clear', 'document_web_reuse_signal_flagged', 'additional_information_required') then raise exception 'Signal-only result level required'; end if;
  insert into public.document_web_reuse_results (
    request_id, provider_event_id, provider_signature_verified, result_level,
    exact_full_match_count, partial_match_count, known_test_fixture_match,
    risk_reasons, reviewer_url_manifest, automatically_approved,
    automatically_rejected, authenticity_conclusion, synthetic_qa
  ) values (
    v_request.id, left(btrim(p_provider_event_id), 200), true, p_result_level,
    greatest(p_exact_full_match_count, 0), greatest(p_partial_match_count, 0),
    p_known_test_fixture_match, coalesce(p_risk_reasons, '{}'),
    coalesce(p_reviewer_url_manifest, '[]'::jsonb), false, false,
    'authenticity_not_authoritatively_confirmed', true
  ) returning * into v_result;
  update public.document_web_reuse_requests set request_status = 'synthetic_completed' where id = v_request.id;
  return v_result.id;
end;
$$;

create or replace function public.start_live_presence_challenge(
  p_synthetic_qa boolean,
  p_accessibility_requested boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile public.profiles%rowtype;
  v_nonce text;
  v_nonce_hash text;
  v_binding_hash text;
  v_expires_at timestamptz := now() + interval '5 minutes';
  v_steps text[];
  v_challenge public.live_presence_challenges%rowtype;
begin
  select * into v_profile from public.profiles where id = auth.uid();
  if v_profile.id is null then return jsonb_build_object('ok', false, 'code', 'authentication_required'); end if;
  if not coalesce(p_synthetic_qa, false) or not v_profile.is_test_account then return jsonb_build_object('ok', false, 'code', 'synthetic_qa_test_account_required'); end if;
  select array_agg(step) into v_steps
  from (
    select step
    from unnest(array['face_forward', 'turn_head_left', 'turn_head_right', 'look_slightly_up', 'look_slightly_down', 'blink', 'nod_once', 'follow_moving_marker']) step
    order by random()
    limit 4
  ) selected;
  v_nonce := encode(extensions.gen_random_bytes(32), 'hex');
  v_nonce_hash := encode(extensions.digest(v_nonce, 'sha256'), 'hex');
  v_binding_hash := encode(extensions.digest(v_nonce || auth.uid()::text || v_expires_at::text || array_to_string(v_steps, ','), 'sha256'), 'hex');
  insert into public.live_presence_challenges (
    subject_user_id, server_nonce_hash, challenge_steps,
    challenge_binding_hash, expires_at, status,
    accessibility_alternative_requested, accessibility_reason_code,
    synthetic_qa, contains_real_face_data
  ) values (
    auth.uid(), v_nonce_hash, v_steps, v_binding_hash, v_expires_at,
    case when p_accessibility_requested then 'accessibility_alternative_requested' else 'issued' end,
    p_accessibility_requested,
    case when p_accessibility_requested then 'user_requested_before_challenge' else null end,
    true, false
  ) returning * into v_challenge;
  return jsonb_build_object(
    'ok', true,
    'challenge_id', v_challenge.id,
    'server_nonce', v_nonce,
    'challenge_binding_hash', v_binding_hash,
    'steps', v_steps,
    'expires_at', v_expires_at,
    'synthetic_qa_only', true,
    'legal_identity_result', false,
    'accessibility_alternative_available', true
  );
end;
$$;

create or replace function public.request_live_presence_accessibility_alternative(
  p_challenge_id uuid,
  p_reason_code text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.live_presence_challenges
  set accessibility_alternative_requested = true,
      accessibility_reason_code = left(btrim(coalesce(p_reason_code, 'user_requested_alternative')), 100),
      status = 'accessibility_alternative_requested'
  where id = p_challenge_id
    and subject_user_id = auth.uid()
    and status in ('issued', 'accessibility_alternative_requested')
    and expires_at > now();
  if not found then return jsonb_build_object('ok', false, 'code', 'active_owned_challenge_required'); end if;
  return jsonb_build_object('ok', true, 'alternative_route_requested', true, 'disability_penalty', false);
end;
$$;

create or replace function private.record_live_presence_result(
  p_challenge_id uuid,
  p_server_nonce text,
  p_provider_event_id text,
  p_provider_signature_verified boolean,
  p_replay_detected boolean,
  p_frame_continuity_passed boolean,
  p_face_presence_passed boolean,
  p_multiple_faces_detected boolean,
  p_result_level text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_challenge public.live_presence_challenges%rowtype;
  v_result public.live_presence_results%rowtype;
begin
  if not coalesce(p_provider_signature_verified, false) then raise exception 'Unsigned provider result rejected'; end if;
  select * into v_challenge from public.live_presence_challenges where id = p_challenge_id for update;
  if v_challenge.id is null or not v_challenge.synthetic_qa or v_challenge.contains_real_face_data then raise exception 'Synthetic challenge required'; end if;
  if v_challenge.expires_at <= now() then update public.live_presence_challenges set status = 'expired' where id = v_challenge.id; raise exception 'Challenge expired'; end if;
  if encode(extensions.digest(p_server_nonce, 'sha256'), 'hex') <> v_challenge.server_nonce_hash then raise exception 'Challenge nonce mismatch'; end if;
  if exists (select 1 from public.live_presence_results result where result.challenge_id = v_challenge.id) then raise exception 'Challenge replay rejected'; end if;
  if p_replay_detected and p_result_level <> 'rejected_replay' then raise exception 'Replay signal must reject'; end if;
  if p_multiple_faces_detected and p_result_level <> 'rejected_multiple_faces' then raise exception 'Multiple-face signal must reject'; end if;
  if p_result_level = 'live_presence_challenge_passed' and (p_replay_detected or p_multiple_faces_detected or not p_frame_continuity_passed or not p_face_presence_passed) then raise exception 'Pass criteria not satisfied'; end if;
  insert into public.live_presence_results (
    challenge_id, provider_event_id, provider_signature_verified, nonce_verified,
    challenge_binding_verified, replay_detected, frame_continuity_passed,
    face_presence_passed, multiple_faces_detected, result_level,
    legal_identity_verified, persistent_face_template_created, synthetic_qa
  ) values (
    v_challenge.id, left(btrim(p_provider_event_id), 200), true, true, true,
    p_replay_detected, p_frame_continuity_passed, p_face_presence_passed,
    p_multiple_faces_detected, p_result_level, false, false, true
  ) returning * into v_result;
  update public.live_presence_challenges
  set status = case p_result_level
    when 'live_presence_challenge_passed' then 'passed_signal_only'
    when 'rejected_replay' then 'rejected_replay'
    when 'rejected_multiple_faces' then 'rejected_multiple_faces'
    else 'submitted' end,
      completed_at = now()
  where id = v_challenge.id;
  return v_result.id;
end;
$$;

create or replace function public.admin_create_team_role_assignment(
  p_user_id uuid,
  p_role_key text,
  p_environment_scope text,
  p_approval_reason text,
  p_access_reason text,
  p_expires_at timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_assignment public.team_role_assignments%rowtype;
begin
  if auth.uid() is null or not public.is_admin() then return jsonb_build_object('ok', false, 'code', 'admin_required'); end if;
  if p_expires_at <= now() or p_expires_at > now() + interval '90 days' then return jsonb_build_object('ok', false, 'code', 'bounded_expiry_required'); end if;
  insert into public.team_role_assignments (
    user_id, role_key, environment_scope, access_status, approved_by,
    approval_reason, access_reason, expires_at
  ) values (
    p_user_id, p_role_key, p_environment_scope, 'pending_training', auth.uid(),
    left(btrim(p_approval_reason), 1000), left(btrim(p_access_reason), 1000), p_expires_at
  ) returning * into v_assignment;
  insert into public.team_access_audit_events (user_id, role_assignment_id, action, target_category, target_id, purpose, access_allowed)
  values (p_user_id, v_assignment.id, 'role_requested', 'team_role_assignment', v_assignment.id, v_assignment.access_reason, false);
  return jsonb_build_object('ok', true, 'assignment_id', v_assignment.id, 'status', v_assignment.access_status, 'access_granted', false);
end;
$$;

create or replace function public.acknowledge_team_confidentiality(
  p_policy_version text,
  p_content_hash text,
  p_affirmative_checkbox boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_id uuid;
begin
  if auth.uid() is null or not coalesce(p_affirmative_checkbox, false) then return jsonb_build_object('ok', false, 'code', 'affirmative_authenticated_acknowledgment_required'); end if;
  if p_content_hash !~ '^[a-f0-9]{64}$' then return jsonb_build_object('ok', false, 'code', 'valid_content_hash_required'); end if;
  insert into public.team_confidentiality_acknowledgements (
    user_id, policy_version, content_hash, affirmative_checkbox, expires_at
  ) values (
    auth.uid(), left(btrim(p_policy_version), 100), p_content_hash, true, now() + interval '1 year'
  ) on conflict (user_id, policy_version) do nothing returning id into v_id;
  return jsonb_build_object('ok', true, 'acknowledgment_id', v_id);
end;
$$;

create or replace function public.submit_team_conflict_disclosure(
  p_disclosure_version text,
  p_has_conflict boolean,
  p_conflict_summary text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_id uuid;
begin
  if auth.uid() is null then return jsonb_build_object('ok', false, 'code', 'authentication_required'); end if;
  if p_has_conflict and char_length(btrim(coalesce(p_conflict_summary, ''))) < 5 then return jsonb_build_object('ok', false, 'code', 'conflict_summary_required'); end if;
  insert into public.team_conflict_disclosures (
    user_id, disclosure_version, has_conflict, conflict_summary, review_status, expires_at
  ) values (
    auth.uid(), left(btrim(p_disclosure_version), 100), p_has_conflict,
    nullif(left(btrim(coalesce(p_conflict_summary, '')), 1000), ''), 'pending', now() + interval '1 year'
  ) returning id into v_id;
  return jsonb_build_object('ok', true, 'disclosure_id', v_id, 'access_granted', false, 'admin_review_required', true);
end;
$$;

create or replace function public.submit_team_device_compliance(
  p_device_reference_hash text,
  p_passcode_enabled boolean,
  p_encryption_enabled boolean,
  p_supported_os boolean,
  p_shared_device boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_id uuid;
begin
  if auth.uid() is null then return jsonb_build_object('ok', false, 'code', 'authentication_required'); end if;
  if p_device_reference_hash !~ '^[a-f0-9]{64}$' then return jsonb_build_object('ok', false, 'code', 'valid_device_reference_hash_required'); end if;
  insert into public.team_device_compliance (
    user_id, device_reference_hash, passcode_enabled, encryption_enabled,
    supported_os, shared_device, review_status, expires_at
  ) values (
    auth.uid(), p_device_reference_hash, p_passcode_enabled, p_encryption_enabled,
    p_supported_os, p_shared_device, 'pending', now() + interval '180 days'
  ) returning id into v_id;
  return jsonb_build_object('ok', true, 'device_compliance_id', v_id, 'access_granted', false, 'admin_review_required', true);
end;
$$;

create or replace function public.admin_record_team_training_completion(
  p_user_id uuid,
  p_module_key text,
  p_score_percent numeric,
  p_expires_at timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_module public.team_training_modules%rowtype; v_id uuid;
begin
  if auth.uid() is null or not public.is_admin() then return jsonb_build_object('ok', false, 'code', 'admin_required'); end if;
  select * into v_module from public.team_training_modules where module_key = p_module_key and active;
  if v_module.module_key is null then return jsonb_build_object('ok', false, 'code', 'active_training_module_required'); end if;
  if p_score_percent < 80 or p_score_percent > 100 then return jsonb_build_object('ok', false, 'code', 'passing_score_required'); end if;
  if p_expires_at <= now() or p_expires_at > now() + interval '2 years' then return jsonb_build_object('ok', false, 'code', 'bounded_training_expiry_required'); end if;
  insert into public.team_training_completions (
    user_id, module_key, module_version, assessment_passed,
    score_percent, expires_at, approved_by
  ) values (
    p_user_id, v_module.module_key, v_module.module_version, true,
    p_score_percent, p_expires_at, auth.uid()
  ) on conflict (user_id, module_key, module_version) do update
  set assessment_passed = true, score_percent = excluded.score_percent,
      completed_at = now(), expires_at = excluded.expires_at,
      approved_by = excluded.approved_by
  returning id into v_id;
  return jsonb_build_object('ok', true, 'completion_id', v_id);
end;
$$;

create or replace function public.admin_review_team_readiness_item(
  p_item_type text,
  p_item_id uuid,
  p_decision text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not public.is_admin() then return jsonb_build_object('ok', false, 'code', 'admin_required'); end if;
  if p_item_type = 'conflict' and p_decision in ('cleared', 'restricted', 'recusal_required') then
    update public.team_conflict_disclosures set review_status = p_decision, reviewed_by = auth.uid(), reviewed_at = now() where id = p_item_id;
  elsif p_item_type = 'device' and p_decision in ('approved', 'rejected', 'revoked') then
    update public.team_device_compliance set review_status = p_decision, reviewed_by = auth.uid(), reviewed_at = now() where id = p_item_id;
  else
    return jsonb_build_object('ok', false, 'code', 'supported_item_and_decision_required');
  end if;
  if not found then return jsonb_build_object('ok', false, 'code', 'readiness_item_not_found'); end if;
  return jsonb_build_object('ok', true, 'decision', p_decision);
end;
$$;

create or replace function public.admin_activate_team_role(p_assignment_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_assignment public.team_role_assignments%rowtype;
begin
  if auth.uid() is null or not public.is_admin() then return jsonb_build_object('ok', false, 'code', 'admin_required'); end if;
  select * into v_assignment from public.team_role_assignments where id = p_assignment_id for update;
  if v_assignment.id is null then return jsonb_build_object('ok', false, 'code', 'assignment_not_found'); end if;
  if not private.team_prerequisites_complete(v_assignment.user_id, v_assignment.role_key) then return jsonb_build_object('ok', false, 'code', 'training_confidentiality_conflict_and_device_readiness_required'); end if;
  update public.team_role_assignments
  set access_status = 'active', granted_at = now(), approved_by = auth.uid()
  where id = v_assignment.id and expires_at > now();
  insert into public.team_access_audit_events (user_id, role_assignment_id, action, target_category, target_id, purpose, access_allowed)
  values (v_assignment.user_id, v_assignment.id, 'role_approved', 'team_role_assignment', v_assignment.id, v_assignment.access_reason, true);
  return jsonb_build_object('ok', true, 'assignment_id', v_assignment.id, 'status', 'active');
end;
$$;

create or replace function public.admin_assign_appearance_reviewer(
  p_case_id uuid,
  p_reviewer_id uuid,
  p_review_position integer,
  p_purpose text,
  p_expires_at timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_case public.appearance_review_cases%rowtype; v_assignment public.appearance_review_assignments%rowtype;
begin
  if auth.uid() is null or not public.is_admin() then return jsonb_build_object('ok', false, 'code', 'admin_required'); end if;
  select * into v_case from public.appearance_review_cases where id = p_case_id for update;
  if v_case.id is null or not v_case.synthetic_qa or v_case.contains_real_face_data then return jsonb_build_object('ok', false, 'code', 'synthetic_appearance_case_required'); end if;
  if p_reviewer_id = v_case.subject_user_id then return jsonb_build_object('ok', false, 'code', 'subject_cannot_review_own_case'); end if;
  if not private.has_ready_team_role(p_reviewer_id, array['document_reviewer', 'senior_document_reviewer']::text[]) then return jsonb_build_object('ok', false, 'code', 'ready_document_reviewer_required'); end if;
  if p_review_position not in (1, 2) or p_expires_at <= now() or p_expires_at > now() + interval '14 days' then return jsonb_build_object('ok', false, 'code', 'valid_bounded_assignment_required'); end if;
  insert into public.appearance_review_assignments (
    appearance_case_id, reviewer_id, review_position, assigned_by, purpose, expires_at
  ) values (
    v_case.id, p_reviewer_id, p_review_position, auth.uid(), left(btrim(p_purpose), 500), p_expires_at
  ) returning * into v_assignment;
  update public.appearance_review_cases set review_state = case when p_review_position = 1 then 'first_review' else 'second_review_required' end where id = v_case.id;
  return jsonb_build_object('ok', true, 'assignment_id', v_assignment.id);
end;
$$;

create or replace function public.submit_appearance_review_decision(
  p_assignment_id uuid,
  p_result_level text,
  p_rationale_code text,
  p_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_assignment public.appearance_review_assignments%rowtype;
  v_case public.appearance_review_cases%rowtype;
  v_decision public.appearance_review_decisions%rowtype;
  v_distinct_reviewers integer;
begin
  select * into v_assignment from public.appearance_review_assignments where id = p_assignment_id for update;
  select * into v_case from public.appearance_review_cases where id = v_assignment.appearance_case_id for update;
  if v_assignment.reviewer_id <> auth.uid() or not private.is_assigned_appearance_reviewer(v_case.id, auth.uid()) then return jsonb_build_object('ok', false, 'code', 'assigned_ready_reviewer_required'); end if;
  if p_result_level not in ('appearance_consistency_reviewed', 'appearance_mismatch_requires_review', 'additional_information_required') then return jsonb_build_object('ok', false, 'code', 'limited_appearance_result_required'); end if;
  insert into public.appearance_review_decisions (
    appearance_case_id, assignment_id, reviewer_id, result_level,
    rationale_code, notes, legal_identity_verified
  ) values (
    v_case.id, v_assignment.id, auth.uid(), p_result_level,
    left(btrim(p_rationale_code), 100), nullif(left(btrim(coalesce(p_notes, '')), 1000), ''), false
  ) returning * into v_decision;
  update public.appearance_review_assignments set status = 'completed', completed_at = now() where id = v_assignment.id;

  if p_result_level = 'appearance_mismatch_requires_review' then
    select count(distinct reviewer_id) into v_distinct_reviewers
    from public.appearance_review_decisions
    where appearance_case_id = v_case.id and result_level = 'appearance_mismatch_requires_review';
    if v_distinct_reviewers < 2 then
      update public.appearance_review_cases set review_state = 'second_review_required', final_result = null where id = v_case.id;
      return jsonb_build_object('ok', true, 'decision_id', v_decision.id, 'second_independent_reviewer_required', true, 'legal_identity_verified', false);
    end if;
  end if;
  update public.appearance_review_cases
  set review_state = 'resolved', final_result = p_result_level, resolved_at = now()
  where id = v_case.id;
  return jsonb_build_object('ok', true, 'decision_id', v_decision.id, 'final_result', p_result_level, 'legal_identity_verified', false);
end;
$$;

revoke all on function private.team_prerequisites_complete(uuid, text) from public, anon;
revoke all on function private.record_synthetic_document_quality_result(uuid, text, boolean, boolean, boolean, boolean, boolean, boolean, text, text, boolean) from public, anon, authenticated;
revoke all on function private.record_document_web_reuse_result(uuid, text, boolean, text, integer, integer, boolean, text[], jsonb) from public, anon, authenticated;
revoke all on function private.record_live_presence_result(uuid, text, text, boolean, boolean, boolean, boolean, boolean, text) from public, anon, authenticated;

revoke all on function public.get_first_party_trust_status() from public, anon;
revoke all on function public.start_synthetic_document_capture(text, integer) from public, anon;
revoke all on function public.request_synthetic_web_reuse_signal(uuid, text, boolean) from public, anon;
revoke all on function public.start_live_presence_challenge(boolean, boolean) from public, anon;
revoke all on function public.request_live_presence_accessibility_alternative(uuid, text) from public, anon;
revoke all on function public.admin_create_team_role_assignment(uuid, text, text, text, text, timestamptz) from public, anon;
revoke all on function public.acknowledge_team_confidentiality(text, text, boolean) from public, anon;
revoke all on function public.submit_team_conflict_disclosure(text, boolean, text) from public, anon;
revoke all on function public.submit_team_device_compliance(text, boolean, boolean, boolean, boolean) from public, anon;
revoke all on function public.admin_record_team_training_completion(uuid, text, numeric, timestamptz) from public, anon;
revoke all on function public.admin_review_team_readiness_item(text, uuid, text) from public, anon;
revoke all on function public.admin_activate_team_role(uuid) from public, anon;
revoke all on function public.admin_assign_appearance_reviewer(uuid, uuid, integer, text, timestamptz) from public, anon;
revoke all on function public.submit_appearance_review_decision(uuid, text, text, text) from public, anon;

grant execute on function private.team_prerequisites_complete(uuid, text) to authenticated, service_role;
grant execute on function private.record_synthetic_document_quality_result(uuid, text, boolean, boolean, boolean, boolean, boolean, boolean, text, text, boolean) to service_role;
grant execute on function private.record_document_web_reuse_result(uuid, text, boolean, text, integer, integer, boolean, text[], jsonb) to service_role;
grant execute on function private.record_live_presence_result(uuid, text, text, boolean, boolean, boolean, boolean, boolean, text) to service_role;

grant execute on function public.get_first_party_trust_status() to authenticated, service_role;
grant execute on function public.start_synthetic_document_capture(text, integer) to authenticated, service_role;
grant execute on function public.request_synthetic_web_reuse_signal(uuid, text, boolean) to authenticated, service_role;
grant execute on function public.start_live_presence_challenge(boolean, boolean) to authenticated, service_role;
grant execute on function public.request_live_presence_accessibility_alternative(uuid, text) to authenticated, service_role;
grant execute on function public.admin_create_team_role_assignment(uuid, text, text, text, text, timestamptz) to authenticated, service_role;
grant execute on function public.acknowledge_team_confidentiality(text, text, boolean) to authenticated, service_role;
grant execute on function public.submit_team_conflict_disclosure(text, boolean, text) to authenticated, service_role;
grant execute on function public.submit_team_device_compliance(text, boolean, boolean, boolean, boolean) to authenticated, service_role;
grant execute on function public.admin_record_team_training_completion(uuid, text, numeric, timestamptz) to authenticated, service_role;
grant execute on function public.admin_review_team_readiness_item(text, uuid, text) to authenticated, service_role;
grant execute on function public.admin_activate_team_role(uuid) to authenticated, service_role;
grant execute on function public.admin_assign_appearance_reviewer(uuid, uuid, integer, text, timestamptz) to authenticated, service_role;
grant execute on function public.submit_appearance_review_decision(uuid, text, text, text) to authenticated, service_role;
