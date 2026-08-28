-- Provider-neutral identity verification completion. Production remains
-- fail-closed; this migration does not select a vendor or collect documents.

alter table private.identity_verification_control
  add column if not exists provider_session_configured boolean not null default false,
  add column if not exists provider_webhook_adapter_verified boolean not null default false,
  add column if not exists adult_workflow_approved boolean not null default false,
  add column if not exists business_workflow_approved boolean not null default false,
  add column if not exists privacy_notice_version text,
  add column if not exists production_approved_at timestamptz,
  add column if not exists allowed_handoff_hosts text[] not null default '{}'::text[],
  add column if not exists session_ttl_minutes smallint not null default 15,
  add column if not exists maximum_session_attempts smallint not null default 3;

alter table private.identity_verification_control
  drop constraint if exists identity_verification_production_readiness_check;
alter table private.identity_verification_control
  add constraint identity_verification_production_readiness_check check (
    mode <> 'production'
    or (
      provider_slug is not null
      and char_length(provider_slug) between 2 and 80
      and provider_environment = 'production'
      and provider_configuration_present
      and provider_session_configured
      and signed_webhook_configured
      and provider_webhook_adapter_verified
      and workflow_approved
      and adult_workflow_approved
      and retention_policy_configured
      and legal_approved
      and operational_ready
      and trained_reviewers_ready
      and privacy_notice_version is not null
      and char_length(privacy_notice_version) between 3 and 80
      and production_approved_at is not null
      and cardinality(allowed_handoff_hosts) between 1 and 10
      and session_ttl_minutes between 5 and 30
      and maximum_session_attempts between 1 and 5
    )
  );

alter table private.identity_verification_sessions
  add column if not exists client_request_id uuid,
  add column if not exists request_payload_sha256 text,
  add column if not exists handoff_fingerprint text,
  add column if not exists handoff_expires_at timestamptz,
  add column if not exists attempt_count smallint not null default 0,
  add column if not exists maximum_attempts smallint not null default 3,
  add column if not exists normalized_status text not null default 'pending',
  add column if not exists provider_status text,
  add column if not exists failure_code text,
  add column if not exists retention_delete_at timestamptz not null default (now() + interval '90 days'),
  add column if not exists redaction_status text not null default 'not_requested',
  add column if not exists redaction_requested_at timestamptz,
  add column if not exists redacted_at timestamptz;

update private.identity_verification_sessions session
set normalized_status = case session.status
      when 'created' then 'pending'
      when 'pending' then 'under_review'
      when 'completed' then case
        when exists (
          select 1 from public.identity_verifications verification
          where verification.id = session.verification_id
            and verification.status = 'verified'
        ) then 'verified'
        else 'failed'
      end
      when 'failed' then 'failed'
      when 'expired' then 'expired'
      when 'cancelled' then 'failed'
      else 'pending'
    end,
    retention_delete_at = greatest(
      session.retention_delete_at,
      session.created_at + interval '90 days'
    );

alter table private.identity_verification_sessions
  drop constraint if exists identity_session_request_hash_check,
  drop constraint if exists identity_session_handoff_hash_check,
  drop constraint if exists identity_session_attempt_check,
  drop constraint if exists identity_session_normalized_status_check,
  drop constraint if exists identity_session_failure_code_check,
  drop constraint if exists identity_session_redaction_check;
alter table private.identity_verification_sessions
  add constraint identity_session_request_hash_check check (
    request_payload_sha256 is null or request_payload_sha256 ~ '^[A-Fa-f0-9]{64}$'
  ),
  add constraint identity_session_handoff_hash_check check (
    handoff_fingerprint is null or handoff_fingerprint ~ '^[A-Fa-f0-9]{64}$'
  ),
  add constraint identity_session_attempt_check check (
    maximum_attempts between 1 and 5
    and attempt_count between 0 and maximum_attempts
  ),
  add constraint identity_session_normalized_status_check check (
    normalized_status in (
      'pending', 'needs_input', 'under_review', 'verified',
      'failed', 'expired', 'suspended'
    )
  ),
  add constraint identity_session_failure_code_check check (
    failure_code is null or failure_code in (
      'document_unreadable', 'document_expired', 'document_unsupported',
      'selfie_mismatch', 'liveness_failed', 'age_not_confirmed',
      'provider_unavailable', 'maximum_attempts_reached',
      'manual_review_required', 'account_binding_mismatch', 'unknown_failure'
    )
  ),
  add constraint identity_session_redaction_check check (
    redaction_status in ('not_requested', 'requested', 'processing', 'completed', 'retained_legal_hold')
  );

create unique index if not exists identity_session_user_request_idx
on private.identity_verification_sessions(user_id, client_request_id)
where client_request_id is not null;
create unique index if not exists identity_session_handoff_fingerprint_idx
on private.identity_verification_sessions(handoff_fingerprint)
where handoff_fingerprint is not null;
create index if not exists identity_session_retention_idx
on private.identity_verification_sessions(retention_delete_at)
where redaction_status not in ('completed', 'retained_legal_hold');

alter table private.identity_verification_webhook_events
  add column if not exists normalized_status text,
  add column if not exists delivery_attempt smallint not null default 1,
  add column if not exists processing_attempts smallint not null default 0,
  add column if not exists last_failure_code text,
  add column if not exists payload_version text not null default 'normalized-v1',
  add column if not exists retention_delete_at timestamptz not null default (now() + interval '90 days');

alter table private.identity_verification_webhook_events
  drop constraint if exists identity_webhook_normalized_status_check,
  drop constraint if exists identity_webhook_delivery_attempt_check,
  drop constraint if exists identity_webhook_failure_code_check;
alter table private.identity_verification_webhook_events
  add constraint identity_webhook_normalized_status_check check (
    normalized_status is null or normalized_status in (
      'pending', 'needs_input', 'under_review', 'verified',
      'failed', 'expired', 'suspended'
    )
  ),
  add constraint identity_webhook_delivery_attempt_check check (
    delivery_attempt between 1 and 100 and processing_attempts between 0 and 100
  ),
  add constraint identity_webhook_failure_code_check check (
    last_failure_code is null or last_failure_code in (
      'document_unreadable', 'document_expired', 'document_unsupported',
      'selfie_mismatch', 'liveness_failed', 'age_not_confirmed',
      'provider_unavailable', 'maximum_attempts_reached',
      'manual_review_required', 'account_binding_mismatch', 'unknown_failure'
    )
  );
create index if not exists identity_webhook_retention_idx
on private.identity_verification_webhook_events(retention_delete_at);

create or replace function private.normalized_identity_status(p_status text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case lower(btrim(coalesce(p_status, '')))
    when 'unverified' then 'not_started'
    when 'verification_started' then 'pending'
    when 'verification_pending' then 'pending'
    when 'additional_information_required' then 'needs_input'
    when 'manual_review' then 'under_review'
    when 'appeal_pending' then 'under_review'
    when 'verified' then 'verified'
    when 'sandbox_verified' then 'verified'
    when 'verification_rejected' then 'failed'
    when 'legacy_not_production_verified' then 'failed'
    when 'verification_expired' then 'expired'
    when 'verification_suspended' then 'suspended'
    else 'not_started'
  end;
$$;

revoke all on function private.normalized_identity_status(text)
from public, anon, authenticated;

create or replace function public.get_my_identity_verification_v2()
returns jsonb
language plpgsql
stable
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_legacy jsonb := public.get_my_identity_verification();
  v_status text;
  v_session private.identity_verification_sessions%rowtype;
  v_control private.identity_verification_control%rowtype;
begin
  if coalesce((v_legacy->>'ok')::boolean, false) is not true then
    return v_legacy;
  end if;
  v_status := private.normalized_identity_status(v_legacy->>'status');
  select * into v_control
  from private.identity_verification_control control
  where control.singleton;
  select * into v_session
  from private.identity_verification_sessions session
  where session.user_id = auth.uid()
  order by session.created_at desc
  limit 1;

  return (v_legacy - 'provider_reference') || jsonb_build_object(
    'status', v_status,
    'failure_code', v_session.failure_code,
    'attempt_count', coalesce(v_session.attempt_count, 0),
    'maximum_attempts', coalesce(v_session.maximum_attempts, v_control.maximum_session_attempts, 3),
    'can_retry', v_status in ('needs_input', 'failed', 'expired')
      and coalesce(v_session.attempt_count, 0) < coalesce(v_session.maximum_attempts, v_control.maximum_session_attempts, 3)
      and private.production_identity_ready(),
    'support_escalation_available', true,
    'privacy_notice_version', v_control.privacy_notice_version,
    'documents_collected_by_mort', false,
    'provider_handoff_required', v_control.mode = 'production',
    'production_adult_only', true
  );
end;
$$;

revoke all on function public.get_my_identity_verification_v2()
from public, anon;
grant execute on function public.get_my_identity_verification_v2()
to authenticated, service_role;

create or replace function public.request_identity_verification_session_v2(
  p_client_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_profile public.profiles%rowtype;
  v_control private.identity_verification_control%rowtype;
  v_verification public.identity_verifications%rowtype;
  v_session private.identity_verification_sessions%rowtype;
  v_pending_reference text;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_client_request_id is null then
    return jsonb_build_object('ok', false, 'code', 'client_request_id_required');
  end if;
  select * into v_profile from public.profiles profile
  where profile.id = auth.uid() for update;
  if v_profile.id is null or v_profile.account_status <> 'active' then
    return jsonb_build_object('ok', false, 'code', 'active_profile_required');
  end if;
  if v_profile.role not in ('adult', 'guardian')
     or v_profile.dob is null
     or extract(year from age(current_date, v_profile.dob)) < 18 then
    return jsonb_build_object('ok', false, 'code', 'adult_identity_verification_required');
  end if;
  select * into v_control from private.identity_verification_control control
  where control.singleton;
  if v_control.mode <> 'production' or not private.production_identity_ready() then
    return jsonb_build_object('ok', false, 'code', 'production_verification_not_ready');
  end if;
  if not v_control.provider_session_configured then
    return jsonb_build_object('ok', false, 'code', 'production_provider_session_unavailable');
  end if;

  select * into v_session
  from private.identity_verification_sessions session
  where session.user_id = auth.uid()
    and session.client_request_id = p_client_request_id;
  if v_session.id is not null then
    return jsonb_build_object(
      'ok', true, 'idempotent', true,
      'session_request_id', v_session.id,
      'verification_id', v_session.verification_id,
      'provider', v_session.provider,
      'workflow_reference', v_session.workflow_reference
    );
  end if;

  if (
    select count(*) from private.identity_verification_sessions session
    where session.user_id = auth.uid()
      and session.created_at > now() - interval '24 hours'
  ) >= v_control.maximum_session_attempts then
    return jsonb_build_object('ok', false, 'code', 'maximum_verification_attempts_reached');
  end if;
  if exists (
    select 1 from public.identity_verifications verification
    where verification.user_id = auth.uid()
      and verification.status in (
        'verification_started', 'verification_pending',
        'additional_information_required', 'manual_review', 'appeal_pending'
      )
  ) then
    return jsonb_build_object('ok', false, 'code', 'verification_already_active');
  end if;

  v_pending_reference := 'pending-' || gen_random_uuid()::text;
  insert into public.identity_verifications (
    user_id, account_role, evidence_route, provider, provider_reference,
    environment, decision_source, status, verification_level, age_band,
    retention_delete_at, risk_flags, audit_version
  ) values (
    auth.uid(), v_profile.role, 'government_id', v_control.provider_slug,
    v_pending_reference, 'production', 'provider_webhook',
    'verification_started', 0, 'adult_18_plus', now() + interval '90 days',
    jsonb_build_object(
      'production_eligible', false,
      'documents_collected_by_mort', false,
      'provider_handoff_required', true
    ), 'provider-neutral-v2'
  ) returning * into v_verification;

  insert into private.identity_verification_sessions (
    verification_id, user_id, environment, provider, provider_reference,
    workflow_reference, status, expires_at, client_request_id,
    request_payload_sha256, maximum_attempts, normalized_status,
    retention_delete_at
  ) values (
    v_verification.id, auth.uid(), 'production', v_control.provider_slug,
    v_pending_reference, 'adult-identity-provider-v2', 'created',
    now() + make_interval(mins => v_control.session_ttl_minutes),
    p_client_request_id,
    upper(encode(extensions.digest(
      auth.uid()::text || ':' || p_client_request_id::text || ':' || v_control.provider_slug,
      'sha256'
    ), 'hex')),
    v_control.maximum_session_attempts, 'pending', now() + interval '90 days'
  ) returning * into v_session;

  insert into public.verification_audit_events(
    verification_id, actor_id, action, event_data
  ) values (
    v_verification.id, auth.uid(), 'provider_session_requested',
    jsonb_build_object(
      'provider', v_control.provider_slug,
      'environment', 'production',
      'documents_collected_by_mort', false
    )
  );

  return jsonb_build_object(
    'ok', true, 'idempotent', false,
    'session_request_id', v_session.id,
    'verification_id', v_verification.id,
    'provider', v_control.provider_slug,
    'workflow_reference', v_session.workflow_reference
  );
end;
$$;

create or replace function public.complete_identity_verification_handoff_v2(
  p_session_request_id uuid,
  p_provider_reference text,
  p_handoff_fingerprint text,
  p_handoff_expires_at timestamptz,
  p_provider_status text default 'pending'
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_session private.identity_verification_sessions%rowtype;
  v_control private.identity_verification_control%rowtype;
begin
  if coalesce(auth.jwt()->>'role', '') <> 'service_role' then
    return jsonb_build_object('ok', false, 'code', 'service_role_required');
  end if;
  select * into v_control from private.identity_verification_control control
  where control.singleton;
  if not private.production_identity_ready() then
    return jsonb_build_object('ok', false, 'code', 'production_verification_not_ready');
  end if;
  select * into v_session from private.identity_verification_sessions session
  where session.id = p_session_request_id for update;
  if v_session.id is null then
    return jsonb_build_object('ok', false, 'code', 'verification_session_not_found');
  end if;
  if v_session.provider <> v_control.provider_slug
     or char_length(btrim(coalesce(p_provider_reference, ''))) not between 8 and 200
     or coalesce(p_handoff_fingerprint, '') !~ '^[A-Fa-f0-9]{64}$'
     or p_handoff_expires_at <= now()
     or p_handoff_expires_at > now() + make_interval(mins => v_control.session_ttl_minutes)
     or lower(btrim(coalesce(p_provider_status, ''))) not in ('pending', 'requires_input') then
    return jsonb_build_object('ok', false, 'code', 'invalid_provider_handoff');
  end if;
  if v_session.handoff_fingerprint is not null then
    if v_session.handoff_fingerprint = upper(p_handoff_fingerprint)
       and v_session.provider_reference = p_provider_reference then
      return jsonb_build_object('ok', true, 'idempotent', true);
    end if;
    return jsonb_build_object('ok', false, 'code', 'provider_handoff_conflict');
  end if;

  update private.identity_verification_sessions
  set provider_reference = btrim(p_provider_reference),
      handoff_fingerprint = upper(p_handoff_fingerprint),
      handoff_expires_at = p_handoff_expires_at,
      attempt_count = least(attempt_count + 1, maximum_attempts),
      provider_status = lower(btrim(p_provider_status)),
      normalized_status = case when lower(btrim(p_provider_status)) = 'requires_input'
        then 'needs_input' else 'pending' end,
      status = 'pending'
  where id = v_session.id;
  update public.identity_verifications
  set provider_reference = btrim(p_provider_reference),
      status = case when lower(btrim(p_provider_status)) = 'requires_input'
        then 'additional_information_required'::public.identity_verification_state
        else 'verification_pending'::public.identity_verification_state end,
      updated_at = now()
  where id = v_session.verification_id;

  return jsonb_build_object('ok', true, 'idempotent', false);
end;
$$;

create or replace function public.fail_identity_verification_handoff_v2(
  p_session_request_id uuid,
  p_failure_code text
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_code text := lower(btrim(coalesce(p_failure_code, '')));
begin
  if coalesce(auth.jwt()->>'role', '') <> 'service_role' then
    return jsonb_build_object('ok', false, 'code', 'service_role_required');
  end if;
  if v_code not in ('provider_unavailable', 'unknown_failure') then
    v_code := 'unknown_failure';
  end if;
  update private.identity_verification_sessions
  set failure_code = v_code,
      provider_status = 'failed_to_create',
      normalized_status = 'needs_input',
      status = 'failed'
  where id = p_session_request_id
    and handoff_fingerprint is null;
  return jsonb_build_object('ok', found, 'code', case when found then null else 'verification_session_not_found' end);
end;
$$;

create or replace function public.process_identity_verification_provider_event_v2(
  p_event_id text,
  p_provider text,
  p_environment text,
  p_provider_reference text,
  p_user_id uuid,
  p_normalized_status text,
  p_failure_code text,
  p_age_band text,
  p_verification_level smallint,
  p_expires_at timestamptz,
  p_event_timestamp timestamptz,
  p_payload_sha256 text,
  p_signature_verified boolean,
  p_delivery_attempt smallint default 1,
  p_payload_version text default 'normalized-v1'
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_control private.identity_verification_control%rowtype;
  v_verification public.identity_verifications%rowtype;
  v_existing private.identity_verification_webhook_events%rowtype;
  v_status text := lower(btrim(coalesce(p_normalized_status, '')));
  v_failure text := nullif(lower(btrim(coalesce(p_failure_code, ''))), '');
  v_public_status public.identity_verification_state;
begin
  if coalesce(auth.jwt()->>'role', '') <> 'service_role' then
    return jsonb_build_object('ok', false, 'code', 'service_role_required');
  end if;
  select * into v_control from private.identity_verification_control control
  where control.singleton;
  if not private.production_identity_ready() then
    return jsonb_build_object('ok', false, 'code', 'production_verification_not_ready');
  end if;
  if not p_signature_verified then
    return jsonb_build_object('ok', false, 'code', 'provider_signature_required');
  end if;
  if lower(btrim(coalesce(p_environment, ''))) <> 'production'
     or p_provider is distinct from v_control.provider_slug then
    return jsonb_build_object('ok', false, 'code', 'provider_environment_mismatch');
  end if;
  if char_length(btrim(coalesce(p_event_id, ''))) not between 8 and 200
     or char_length(btrim(coalesce(p_provider_reference, ''))) not between 8 and 200
     or p_payload_sha256 is null
     or p_payload_sha256 !~ '^[A-Fa-f0-9]{64}$'
     or p_event_timestamp is null
     or p_event_timestamp < now() - interval '5 minutes'
     or p_event_timestamp > now() + interval '1 minute'
     or p_delivery_attempt not between 1 and 100
     or char_length(btrim(coalesce(p_payload_version, ''))) not between 2 and 40 then
    return jsonb_build_object('ok', false, 'code', 'invalid_provider_event');
  end if;
  if v_status not in ('pending', 'needs_input', 'under_review', 'verified', 'failed', 'expired', 'suspended') then
    return jsonb_build_object('ok', false, 'code', 'unknown_provider_result');
  end if;
  if v_failure is not null and v_failure not in (
    'document_unreadable', 'document_expired', 'document_unsupported',
    'selfie_mismatch', 'liveness_failed', 'age_not_confirmed',
    'provider_unavailable', 'maximum_attempts_reached',
    'manual_review_required', 'account_binding_mismatch', 'unknown_failure'
  ) then
    return jsonb_build_object('ok', false, 'code', 'unknown_provider_failure');
  end if;

  select * into v_existing
  from private.identity_verification_webhook_events event
  where event.provider = p_provider and event.event_id = p_event_id;
  if v_existing.id is not null then
    if v_existing.payload_sha256 = upper(p_payload_sha256)
       and v_existing.provider_reference = p_provider_reference then
      return jsonb_build_object(
        'ok', true, 'idempotent', true,
        'verification_id', v_existing.verification_id,
        'status', v_existing.normalized_status
      );
    end if;
    return jsonb_build_object('ok', false, 'code', 'provider_webhook_replay_conflict');
  end if;

  select * into v_verification
  from public.identity_verifications verification
  where verification.user_id = p_user_id
    and verification.provider = p_provider
    and verification.provider_reference = p_provider_reference
    and verification.environment = 'production'
    and verification.account_role in ('adult', 'guardian')
    and verification.age_band = 'adult_18_plus'
  order by verification.created_at desc
  limit 1 for update;
  if v_verification.id is null then
    return jsonb_build_object('ok', false, 'code', 'provider_account_binding_mismatch');
  end if;
  if p_age_band <> 'adult_18_plus' then
    return jsonb_build_object('ok', false, 'code', 'provider_age_band_mismatch');
  end if;
  if v_status = 'verified' and (
    p_expires_at is null or p_expires_at <= now()
    or p_expires_at > now() + interval '3 years'
    or p_verification_level not between 2 and 4
  ) then
    return jsonb_build_object('ok', false, 'code', 'invalid_provider_approval_scope');
  end if;

  insert into private.identity_verification_webhook_events(
    provider, event_id, environment, provider_reference,
    verification_id, user_id, event_timestamp, signature_verified,
    payload_sha256, result_status, normalized_status, processing_status,
    delivery_attempt, processing_attempts, last_failure_code,
    payload_version, processed_at, retention_delete_at
  ) values (
    p_provider, btrim(p_event_id), 'production', btrim(p_provider_reference),
    v_verification.id, p_user_id, p_event_timestamp, true,
    upper(p_payload_sha256), v_status, v_status, 'processed',
    p_delivery_attempt, 1, v_failure,
    btrim(p_payload_version), now(), now() + interval '90 days'
  );

  v_public_status := case v_status
    when 'pending' then 'verification_pending'::public.identity_verification_state
    when 'needs_input' then 'additional_information_required'::public.identity_verification_state
    when 'under_review' then 'manual_review'::public.identity_verification_state
    when 'verified' then 'verified'::public.identity_verification_state
    when 'failed' then 'verification_rejected'::public.identity_verification_state
    when 'expired' then 'verification_expired'::public.identity_verification_state
    else 'verification_suspended'::public.identity_verification_state
  end;

  update public.identity_verifications
  set status = v_public_status,
      verification_level = case when v_status = 'verified' then p_verification_level else 0 end,
      decision_source = 'provider_webhook',
      verified_at = case when v_status = 'verified' then now() else null end,
      reviewed_at = case when v_status in ('verified', 'failed', 'under_review', 'suspended') then now() else reviewed_at end,
      expires_at = case when v_status = 'verified' then p_expires_at else expires_at end,
      identity_match_result = case when v_status = 'verified' then 'provider_passed' else identity_match_result end,
      liveness_result = case when v_status = 'verified' then 'provider_passed' else liveness_result end,
      rejection_code = case when v_status in ('needs_input', 'failed', 'suspended') then coalesce(v_failure, 'unknown_failure') else null end,
      updated_at = now()
  where id = v_verification.id
  returning * into v_verification;

  update private.identity_verification_sessions
  set normalized_status = v_status,
      provider_status = v_status,
      failure_code = v_failure,
      status = case
        when v_status = 'verified' then 'completed'
        when v_status = 'failed' then 'failed'
        when v_status = 'expired' then 'expired'
        else 'pending'
      end,
      completed_at = case when v_status in ('verified', 'failed', 'expired') then now() else null end
  where verification_id = v_verification.id;

  perform set_config('mort.internal_update', 'true', true);
  update public.profiles
  set verification_status = case
      when v_status = 'verified' then 'approved'::public.verification_status
      when v_status = 'failed' then 'rejected'::public.verification_status
      else 'pending'::public.verification_status
    end,
    updated_at = now()
  where id = p_user_id;
  perform set_config('mort.internal_update', '', true);

  insert into public.verification_audit_events(
    verification_id, actor_id, action, event_data
  ) values (
    v_verification.id, null, 'normalized_provider_event_processed',
    jsonb_build_object(
      'provider', p_provider,
      'event_id', p_event_id,
      'status', v_status,
      'failure_code', v_failure,
      'payload_sha256', upper(p_payload_sha256),
      'payload_version', p_payload_version
    )
  );

  return jsonb_build_object(
    'ok', true, 'idempotent', false,
    'verification_id', v_verification.id,
    'status', v_status,
    'production_eligible', private.has_current_production_identity(p_user_id)
  );
end;
$$;

create or replace function public.expire_identity_provider_sessions_v2()
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_expired integer := 0;
begin
  if coalesce(auth.jwt()->>'role', '') <> 'service_role' then
    return jsonb_build_object('ok', false, 'code', 'service_role_required');
  end if;
  with expired as (
    update private.identity_verification_sessions
    set normalized_status = 'expired', status = 'expired', failure_code = null
    where normalized_status in ('pending', 'needs_input', 'under_review')
      and coalesce(handoff_expires_at, expires_at) <= now()
    returning verification_id
  ), updated as (
    update public.identity_verifications verification
    set status = 'verification_expired', verification_level = 0, updated_at = now()
    where verification.id in (select expired.verification_id from expired)
    returning verification.id
  ) select count(*) into v_expired from updated;
  return jsonb_build_object('ok', true, 'expired', v_expired);
end;
$$;

create or replace function public.purge_identity_provider_metadata_v2()
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_sessions integer := 0;
  v_events integer := 0;
begin
  if coalesce(auth.jwt()->>'role', '') <> 'service_role' then
    return jsonb_build_object('ok', false, 'code', 'service_role_required');
  end if;
  with removed as (
    delete from private.identity_verification_webhook_events
    where retention_delete_at <= now()
    returning id
  ) select count(*) into v_events from removed;
  with removed as (
    delete from private.identity_verification_sessions session
    where session.retention_delete_at <= now()
      and session.redaction_status <> 'retained_legal_hold'
      and not exists (
        select 1 from public.identity_verifications verification
        where verification.id = session.verification_id
          and verification.status in (
            'verification_started', 'verification_pending',
            'additional_information_required', 'manual_review',
            'appeal_pending', 'verified'
          )
      )
    returning id
  ) select count(*) into v_sessions from removed;
  return jsonb_build_object('ok', true, 'sessions_purged', v_sessions, 'events_purged', v_events);
end;
$$;

-- The legacy direct business-document path is closed. Existing records and
-- objects are preserved for owner access and controlled retention.
drop policy if exists storage_mort_owner_insert on storage.objects;
create policy storage_mort_owner_insert
on storage.objects for insert to authenticated
with check (
  bucket_id = any (array['proof-uploads', 'report-uploads'])
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists storage_mort_owner_select on storage.objects;
create policy storage_mort_owner_select
on storage.objects for select to authenticated
using (
  (
    bucket_id = any (array['proof-uploads', 'report-uploads'])
    and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or public.is_admin()
      or (
        bucket_id = 'proof-uploads'
        and exists (
          select 1 from public.proof_uploads proof
          where proof.storage_path = storage.objects.name
            and public.is_application_participant(proof.application_id)
        )
      )
    )
  )
  or (
    bucket_id = 'verification-uploads'
    and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or private.is_production_identity_reviewer((select auth.uid()))
    )
  )
);

create or replace function public.submit_business_verification(
  p_verification_id uuid,
  p_storage_path text,
  p_business_name text,
  p_business_type text,
  p_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_verification_id is null
     or char_length(btrim(coalesce(p_storage_path, ''))) > 500
     or char_length(btrim(coalesce(p_business_name, ''))) > 120
     or char_length(btrim(coalesce(p_business_type, ''))) > 80
     or char_length(coalesce(p_notes, '')) > 1000 then
    return jsonb_build_object('ok', false, 'code', 'invalid_verification_submission');
  end if;
  return jsonb_build_object(
    'ok', false,
    'code', 'business_verification_provider_required',
    'message', 'Business verification is unavailable until an approved provider and legal workflow are connected. Do not upload a document.'
  );
end;
$$;

drop policy if exists business_verifications_update_admin
on public.business_verifications;
revoke insert, update, delete on public.business_verifications
from authenticated;

-- Remove unused-parameter warnings while preserving direct-ID collection as
-- an explicit fail-closed compatibility endpoint.
create or replace function public.register_identity_evidence(
  p_verification_id uuid,
  p_evidence_id uuid,
  p_storage_path text,
  p_evidence_type text,
  p_sha256 text default null
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_verification_id is null or p_evidence_id is null
     or char_length(coalesce(p_storage_path, '')) > 500
     or char_length(coalesce(p_evidence_type, '')) > 80
     or (p_sha256 is not null and p_sha256 !~ '^[A-Fa-f0-9]{64}$') then
    return jsonb_build_object('ok', false, 'code', 'invalid_identity_evidence_request');
  end if;
  return jsonb_build_object(
    'ok', false,
    'code', 'identity_document_collection_disabled',
    'message', 'MORT does not accept direct identity-document uploads.'
  );
end;
$$;

create or replace function public.submit_identity_verification(
  p_verification_id uuid,
  p_acknowledged boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_verification public.identity_verifications%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if not p_acknowledged then
    return jsonb_build_object('ok', false, 'code', 'verification_acknowledgment_required');
  end if;
  select * into v_verification from public.identity_verifications verification
  where verification.id = p_verification_id and verification.user_id = auth.uid();
  if v_verification.id is null then
    return jsonb_build_object('ok', false, 'code', 'verification_not_found');
  end if;
  return jsonb_build_object(
    'ok', false,
    'code', case when v_verification.environment = 'sandbox'
      then 'sandbox_provider_managed' else 'production_provider_managed' end,
    'message', 'Verification outcomes must come from the configured server-side provider flow.'
  );
end;
$$;

revoke all on function public.request_identity_verification_session_v2(uuid),
  public.complete_identity_verification_handoff_v2(uuid, text, text, timestamptz, text),
  public.fail_identity_verification_handoff_v2(uuid, text),
  public.process_identity_verification_provider_event_v2(
    text, text, text, text, uuid, text, text, text, smallint,
    timestamptz, timestamptz, text, boolean, smallint, text
  ),
  public.expire_identity_provider_sessions_v2(),
  public.purge_identity_provider_metadata_v2()
from public, anon, authenticated;

grant execute on function public.request_identity_verification_session_v2(uuid)
to authenticated, service_role;
grant execute on function public.complete_identity_verification_handoff_v2(uuid, text, text, timestamptz, text),
  public.fail_identity_verification_handoff_v2(uuid, text),
  public.process_identity_verification_provider_event_v2(
    text, text, text, text, uuid, text, text, text, smallint,
    timestamptz, timestamptz, text, boolean, smallint, text
  ),
  public.expire_identity_provider_sessions_v2(),
  public.purge_identity_provider_metadata_v2()
to service_role;

revoke all on private.identity_verification_control,
  private.identity_verification_sessions,
  private.identity_verification_webhook_events
from public, anon, authenticated;

