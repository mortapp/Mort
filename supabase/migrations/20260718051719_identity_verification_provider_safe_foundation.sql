-- Fail-closed identity-verification foundation. MORT does not collect identity
-- documents or grant public marketplace eligibility until an approved provider
-- and every production-readiness control are configured server-side.

do $$
begin
  create type public.verification_environment as enum ('sandbox', 'production');
exception
  when duplicate_object then null;
end
$$;

create table if not exists private.identity_verification_control (
  singleton boolean primary key default true check (singleton),
  mode text not null default 'disabled'
    check (mode in ('disabled', 'sandbox', 'production')),
  provider_slug text,
  provider_environment public.verification_environment,
  provider_configuration_present boolean not null default false,
  signed_webhook_configured boolean not null default false,
  workflow_approved boolean not null default false,
  retention_policy_configured boolean not null default false,
  legal_approved boolean not null default false,
  operational_ready boolean not null default false,
  trained_reviewers_ready boolean not null default false,
  manual_exception_approved boolean not null default false,
  updated_at timestamptz not null default now(),
  constraint identity_verification_production_readiness_check check (
    mode <> 'production'
    or (
      provider_slug is not null
      and char_length(provider_slug) between 2 and 80
      and provider_environment = 'production'
      and provider_configuration_present
      and signed_webhook_configured
      and workflow_approved
      and retention_policy_configured
      and legal_approved
      and operational_ready
      and trained_reviewers_ready
    )
  )
);

insert into private.identity_verification_control (singleton, mode)
values (true, 'disabled')
on conflict (singleton) do update
set mode = 'disabled',
    provider_slug = null,
    provider_environment = null,
    provider_configuration_present = false,
    signed_webhook_configured = false,
    workflow_approved = false,
    retention_policy_configured = false,
    legal_approved = false,
    operational_ready = false,
    trained_reviewers_ready = false,
    manual_exception_approved = false,
    updated_at = now();

create table if not exists private.production_identity_reviewers (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  trained_at timestamptz not null,
  approved_at timestamptz not null,
  approval_reference text not null,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  constraint production_identity_reviewer_reference_check
    check (char_length(approval_reference) between 8 and 200)
);

create table if not exists private.identity_verification_sessions (
  id uuid primary key default gen_random_uuid(),
  verification_id uuid not null unique
    references public.identity_verifications(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  environment public.verification_environment not null,
  provider text not null,
  provider_reference text not null unique,
  workflow_reference text not null,
  status text not null default 'created'
    check (status in ('created', 'pending', 'completed', 'failed', 'expired', 'cancelled')),
  created_at timestamptz not null default now(),
  expires_at timestamptz,
  completed_at timestamptz,
  constraint identity_verification_session_provider_check
    check (char_length(provider) between 2 and 80),
  constraint identity_verification_session_reference_check
    check (char_length(provider_reference) between 8 and 200),
  constraint identity_verification_session_workflow_check
    check (char_length(workflow_reference) between 2 and 120)
);

create table if not exists private.identity_verification_webhook_events (
  id bigint generated always as identity primary key,
  provider text not null,
  event_id text not null,
  environment public.verification_environment not null,
  provider_reference text not null,
  verification_id uuid references public.identity_verifications(id) on delete restrict,
  user_id uuid references public.profiles(id) on delete restrict,
  event_timestamp timestamptz not null,
  signature_verified boolean not null,
  payload_sha256 text not null,
  result_status text not null,
  processing_status text not null,
  failure_reason text,
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  constraint identity_webhook_event_unique unique (provider, event_id),
  constraint identity_webhook_hash_check
    check (payload_sha256 ~ '^[A-Fa-f0-9]{64}$'),
  constraint identity_webhook_signature_check check (signature_verified),
  constraint identity_webhook_processing_check
    check (processing_status in ('received', 'processed', 'rejected'))
);

revoke all on private.identity_verification_control,
  private.production_identity_reviewers,
  private.identity_verification_sessions,
  private.identity_verification_webhook_events
from public, anon, authenticated;

alter table public.identity_verifications
  add column if not exists environment public.verification_environment,
  add column if not exists decision_source text,
  add column if not exists verified_at timestamptz;

update public.identity_verifications
set environment = 'sandbox',
    provider_reference = coalesce(
      nullif(btrim(provider_reference), ''),
      'legacy-' || id::text
    ),
    decision_source = case
      when provider = 'mort_isolated_qa' then 'sandbox_simulation'
      else 'legacy_import'
    end,
    verified_at = case
      when status = 'verified' then coalesce(reviewed_at, submitted_at, created_at)
      else verified_at
    end,
    risk_flags = risk_flags || jsonb_build_object(
      'production_eligible', false,
      'quarantined_by', 'verification-provider-safe-foundation'
    ),
    updated_at = now()
where environment is null
   or provider_reference is null
   or decision_source is null
   or (status = 'verified' and verified_at is null);

alter table public.identity_verifications
  alter column environment set not null,
  alter column provider_reference set not null,
  alter column decision_source set not null;

alter table public.identity_verifications
  drop constraint if exists identity_verification_decision_source_check;
alter table public.identity_verifications
  add constraint identity_verification_decision_source_check check (
    decision_source in (
      'sandbox_simulation',
      'provider_webhook',
      'approved_manual_exception',
      'legacy_import'
    )
  );

alter table public.identity_verifications
  drop constraint if exists identity_verification_verified_fields_check;
alter table public.identity_verifications
  add constraint identity_verification_verified_fields_check check (
    status <> 'verified'
    or (
      verified_at is not null
      and char_length(provider_reference) between 8 and 200
      and verification_level > 0
    )
  );

alter table public.identity_verifications
  drop constraint if exists identity_verification_production_source_check;
alter table public.identity_verifications
  add constraint identity_verification_production_source_check check (
    environment <> 'production'
    or status <> 'verified'
    or (
      decision_source in ('provider_webhook', 'approved_manual_exception')
      and provider not like 'mort_%'
      and provider not in ('local_upload', 'manual_image_upload')
    )
  );

alter table public.identity_verification_evidence
  add column if not exists environment public.verification_environment;

update public.identity_verification_evidence evidence
set environment = verification.environment,
    evidence_status = case
      when verification.environment = 'sandbox' then 'legacy_quarantined'
      else evidence.evidence_status
    end
from public.identity_verifications verification
where verification.id = evidence.verification_id
  and evidence.environment is null;

alter table public.identity_verification_evidence
  alter column environment set not null;

update public.verification_evidence_access_grants access_grant
set revoked_at = now()
from public.identity_verification_evidence evidence
where evidence.id = access_grant.evidence_id
  and evidence.environment = 'sandbox'
  and access_grant.revoked_at is null;

do $$
begin
  perform set_config('mort.internal_update', 'true', true);
  update public.profiles profile
  set verification_status = 'not_started',
      updated_at = now()
  where profile.role in ('teen', 'adult', 'guardian')
    and not exists (
      select 1
      from public.identity_verifications verification
      where verification.user_id = profile.id
        and verification.environment = 'production'
        and verification.status = 'verified'
        and verification.verified_at is not null
        and (verification.expires_at is null or verification.expires_at > now())
    );
end
$$;

create or replace function private.identity_verification_mode()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select control.mode
  from private.identity_verification_control control
  where control.singleton
  limit 1;
$$;

create or replace function private.production_identity_ready()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select
      control.mode = 'production'
      and control.provider_slug is not null
      and control.provider_environment = 'production'
      and control.provider_configuration_present
      and control.signed_webhook_configured
      and control.workflow_approved
      and control.retention_policy_configured
      and control.legal_approved
      and control.operational_ready
      and control.trained_reviewers_ready
    from private.identity_verification_control control
    where control.singleton
  ), false);
$$;

create or replace function private.is_production_identity_reviewer(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles profile
    join private.production_identity_reviewers reviewer
      on reviewer.user_id = profile.id
    where profile.id = p_user_id
      and profile.role = 'admin'
      and profile.account_status = 'active'
      and reviewer.revoked_at is null
      and reviewer.trained_at <= now()
      and reviewer.approved_at <= now()
  );
$$;

create or replace function private.has_current_production_identity(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.production_identity_ready()
    and exists (
      select 1
      from public.identity_verifications verification
      where verification.user_id = p_user_id
        and verification.environment = 'production'
        and verification.status = 'verified'
        and verification.verified_at is not null
        and verification.decision_source in ('provider_webhook', 'approved_manual_exception')
        and (verification.expires_at is null or verification.expires_at > now())
    );
$$;

create or replace function private.has_current_sandbox_identity(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles profile
    join public.identity_verifications verification
      on verification.user_id = profile.id
    where profile.id = p_user_id
      and profile.is_test_account
      and profile.account_status = 'active'
      and verification.environment = 'sandbox'
      and verification.status = 'verified'
      and verification.decision_source in ('sandbox_simulation', 'legacy_import')
      and coalesce((verification.risk_flags->>'isolated_qa')::boolean, false)
      and (verification.expires_at is null or verification.expires_at > now())
  );
$$;

revoke all on function private.identity_verification_mode(),
  private.production_identity_ready(),
  private.is_production_identity_reviewer(uuid),
  private.has_current_production_identity(uuid),
  private.has_current_sandbox_identity(uuid)
from public, anon, authenticated;

create or replace function private.marketplace_identity_level(p_user_id uuid)
returns smallint
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when exists (
      select 1
      from public.profiles profile
      where profile.id = p_user_id
        and profile.role = 'admin'
        and profile.account_status = 'active'
    ) then 4::smallint
    when private.has_current_sandbox_identity(p_user_id) then coalesce((
      select max(verification.verification_level)::smallint
      from public.identity_verifications verification
      where verification.user_id = p_user_id
        and verification.environment = 'sandbox'
        and verification.status = 'verified'
        and (verification.expires_at is null or verification.expires_at > now())
    ), 0::smallint)
    when private.has_current_production_identity(p_user_id) then coalesce((
      select max(verification.verification_level)::smallint
      from public.identity_verifications verification
      where verification.user_id = p_user_id
        and verification.environment = 'production'
        and verification.status = 'verified'
        and verification.verified_at is not null
        and (verification.expires_at is null or verification.expires_at > now())
    ), 0::smallint)
    else 0::smallint
  end;
$$;

create or replace function private.has_marketplace_identity(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles profile
    where profile.id = p_user_id
      and profile.account_status = 'active'
      and (
        profile.role = 'admin'
        or (
          profile.is_test_account
          and private.has_current_sandbox_identity(profile.id)
          and (
            (profile.role = 'teen' and private.marketplace_identity_level(profile.id) >= 1)
            or (profile.role in ('adult', 'guardian') and private.marketplace_identity_level(profile.id) >= 2)
          )
        )
        or (
          not profile.is_test_account
          and private.has_current_production_identity(profile.id)
          and (
            (profile.role = 'teen' and private.marketplace_identity_level(profile.id) >= 1)
            or (profile.role in ('adult', 'guardian') and private.marketplace_identity_level(profile.id) >= 2)
          )
        )
      )
  );
$$;

revoke all on function private.marketplace_identity_level(uuid),
  private.has_marketplace_identity(uuid)
from public, anon, authenticated;

create or replace function private.can_view_marketplace_job(p_job_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_job public.jobs%rowtype;
  v_profile public.profiles%rowtype;
begin
  if v_user_id is null then
    return false;
  end if;

  select * into v_job from public.jobs job where job.id = p_job_id;
  select * into v_profile from public.profiles profile where profile.id = v_user_id;
  if v_job.id is null or v_profile.id is null or v_profile.account_status <> 'active' then
    return false;
  end if;

  if v_profile.role = 'admin' or v_job.poster_id = v_user_id then
    return true;
  end if;

  if exists (
    select 1
    from public.applications application
    where application.job_id = p_job_id
      and (
        application.teen_id = v_user_id
        or application.guardian_id = v_user_id
      )
  ) then
    return true;
  end if;

  if v_job.status <> 'open' then
    return false;
  end if;

  if v_profile.is_test_account then
    return v_job.is_test
      and private.has_current_sandbox_identity(v_user_id)
      and private.has_current_sandbox_identity(v_job.poster_id);
  end if;

  return not v_job.is_test
    and private.production_identity_ready()
    and private.has_current_production_identity(v_user_id)
    and private.has_current_production_identity(v_job.poster_id);
end;
$$;

revoke all on function private.can_view_marketplace_job(uuid)
from public, anon;
grant execute on function private.can_view_marketplace_job(uuid)
to authenticated, service_role;

drop policy if exists jobs_select_visible on public.jobs;
create policy jobs_select_visible
on public.jobs for select to authenticated
using (private.can_view_marketplace_job(id));

create or replace function public.get_my_identity_verification()
returns jsonb
language plpgsql
stable
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_user_id uuid := auth.uid();
  v_profile public.profiles%rowtype;
  v_verification public.identity_verifications%rowtype;
  v_mode text := private.identity_verification_mode();
  v_effective_status text;
  v_production_ready boolean := private.production_identity_ready();
  v_sandbox_eligible boolean := false;
  v_production_verified boolean := false;
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;

  select * into v_profile from public.profiles profile where profile.id = v_user_id;
  if v_profile.id is null then
    return jsonb_build_object('ok', false, 'code', 'profile_not_found');
  end if;

  v_sandbox_eligible := v_profile.is_test_account and v_mode = 'sandbox';
  v_production_verified := private.has_current_production_identity(v_user_id);

  select * into v_verification
  from public.identity_verifications verification
  where verification.user_id = v_user_id
  order by
    (verification.environment = 'production') desc,
    (verification.status in (
      'verification_started', 'verification_pending',
      'additional_information_required', 'manual_review', 'appeal_pending'
    )) desc,
    verification.created_at desc
  limit 1;

  if v_verification.id is null then
    return jsonb_build_object(
      'ok', true,
      'status', 'unverified',
      'verification_mode', v_mode,
      'environment', null,
      'provider', null,
      'provider_reference', null,
      'decision_source', null,
      'verification_level', 0,
      'marketplace_enabled', false,
      'production_verified', false,
      'sandbox_eligible', v_sandbox_eligible,
      'test_mode', v_mode = 'sandbox',
      'submissions_enabled', v_sandbox_eligible,
      'production_provider_available', v_production_ready,
      'guardian_mode_optional', true,
      'role', v_profile.role,
      'public_message', case
        when v_mode = 'disabled' then 'Identity verification is not accepting public submissions yet.'
        when v_mode = 'sandbox' and not v_sandbox_eligible then 'Identity verification sandbox is restricted to isolated QA accounts.'
        when v_mode = 'sandbox' then 'Test verification - do not use real documents.'
        else 'Production identity verification is unavailable until the approved provider is ready.'
      end,
      'raw_documents_visible_to_marketplace_users', false
    );
  end if;

  v_effective_status := v_verification.status::text;
  if v_verification.status = 'verified'
     and v_verification.expires_at is not null
     and v_verification.expires_at <= now() then
    v_effective_status := 'verification_expired';
  elsif v_verification.environment = 'sandbox'
        and v_verification.status = 'verified' then
    v_effective_status := 'sandbox_verified';
  elsif v_verification.environment = 'sandbox'
        and v_verification.decision_source = 'legacy_import' then
    v_effective_status := 'legacy_not_production_verified';
  end if;

  return jsonb_build_object(
    'ok', true,
    'id', v_verification.id,
    'role', v_verification.account_role,
    'status', v_effective_status,
    'verification_mode', v_mode,
    'environment', v_verification.environment,
    'provider', v_verification.provider,
    'provider_reference', v_verification.provider_reference,
    'decision_source', v_verification.decision_source,
    'evidence_route', v_verification.evidence_route,
    'verification_level', case when v_production_verified then v_verification.verification_level else 0 end,
    'age_band', v_verification.age_band,
    'submitted_at', v_verification.submitted_at,
    'verified_at', v_verification.verified_at,
    'reviewed_at', v_verification.reviewed_at,
    'expires_at', v_verification.expires_at,
    'appeal_status', v_verification.appeal_status,
    'rejection_code', v_verification.rejection_code,
    'marketplace_enabled', private.has_marketplace_identity(v_user_id),
    'production_verified', v_production_verified,
    'sandbox_eligible', v_sandbox_eligible,
    'test_mode', v_mode = 'sandbox' or v_verification.environment = 'sandbox',
    'submissions_enabled', v_sandbox_eligible,
    'production_provider_available', v_production_ready,
    'guardian_mode_optional', true,
    'public_message', case
      when v_mode = 'disabled' then 'Identity verification is not accepting public submissions yet.'
      when v_mode = 'sandbox' and v_sandbox_eligible then 'Test verification - do not use real documents.'
      when v_mode = 'sandbox' then 'Identity verification sandbox is restricted to isolated QA accounts.'
      else 'Production identity verification requires an approved provider session.'
    end,
    'evidence_types', '[]'::jsonb,
    'raw_documents_visible_to_marketplace_users', false
  );
end;
$$;

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
  select * into v_verification
  from public.identity_verifications verification
  where verification.id = p_verification_id
    and verification.user_id = auth.uid();
  if v_verification.id is null then
    return jsonb_build_object('ok', false, 'code', 'verification_not_found');
  end if;
  return jsonb_build_object(
    'ok', false,
    'code', case
      when v_verification.environment = 'sandbox' then 'sandbox_provider_managed'
      else 'production_provider_managed'
    end,
    'message', 'Verification outcomes must come from the configured server-side provider flow.'
  );
end;
$$;

create or replace function private.can_upload_identity_evidence(
  p_verification_id text,
  p_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select false;
$$;

revoke all on function private.can_upload_identity_evidence(text, uuid)
from public, anon, authenticated;
revoke all on function private.can_delete_unregistered_identity_object(text, text, uuid)
from public, anon, authenticated;

drop policy if exists identity_evidence_upload_started_attempt
on storage.objects;
drop policy if exists identity_evidence_delete_unregistered
on storage.objects;
drop policy if exists identity_evidence_authorized_reviewer_read
on storage.objects;

drop policy if exists identity_verifications_reviewer_select
on public.identity_verifications;
create policy identity_verifications_production_reviewer_select
on public.identity_verifications for select to authenticated
using (
  environment = 'production'
  and private.is_production_identity_reviewer((select auth.uid()))
);

drop policy if exists identity_evidence_reviewer_select
on public.identity_verification_evidence;
create policy identity_evidence_production_reviewer_select
on public.identity_verification_evidence for select to authenticated
using (
  environment = 'production'
  and private.is_production_identity_reviewer((select auth.uid()))
  and exists (
    select 1
    from public.verification_evidence_access_grants access_grant
    where access_grant.evidence_id = identity_verification_evidence.id
      and access_grant.reviewer_id = (select auth.uid())
      and access_grant.revoked_at is null
      and access_grant.expires_at > now()
  )
);

drop policy if exists identity_appeals_owner_or_reviewer_select
on public.identity_verification_appeals;
create policy identity_appeals_owner_or_production_reviewer_select
on public.identity_verification_appeals for select to authenticated
using (
  user_id = (select auth.uid())
  or (
    private.is_production_identity_reviewer((select auth.uid()))
    and exists (
      select 1
      from public.identity_verifications verification
      where verification.id = identity_verification_appeals.verification_id
        and verification.environment = 'production'
    )
  )
);

drop policy if exists verification_access_grants_reviewer_select
on public.verification_evidence_access_grants;
create policy verification_access_grants_production_reviewer_select
on public.verification_evidence_access_grants for select to authenticated
using (
  reviewer_id = (select auth.uid())
  and private.is_production_identity_reviewer((select auth.uid()))
);

drop policy if exists identity_risk_signals_authorized_select
on public.identity_risk_signals;
create policy identity_risk_signals_production_reviewer_select
on public.identity_risk_signals for select to authenticated
using (
  private.is_production_identity_reviewer((select auth.uid()))
  and exists (
    select 1
    from public.identity_verifications verification
    where verification.id = identity_risk_signals.verification_id
      and verification.environment = 'production'
  )
);

create policy identity_evidence_authorized_production_reviewer_read
on storage.objects for select to authenticated
using (
  bucket_id = 'identity-evidence'
  and private.production_identity_ready()
  and private.is_production_identity_reviewer((select auth.uid()))
  and storage.allow_any_operation(array['object.get_authenticated_info', 'object.get_authenticated'])
  and exists (
    select 1
    from public.identity_verification_evidence evidence
    join public.verification_evidence_access_grants access_grant
      on access_grant.evidence_id = evidence.id
    where evidence.storage_path = name
      and evidence.environment = 'production'
      and evidence.storage_path like 'production/%'
      and access_grant.reviewer_id = (select auth.uid())
      and access_grant.revoked_at is null
      and access_grant.expires_at > now()
  )
);

revoke insert, update, delete on public.identity_verifications,
  public.identity_verification_evidence
from anon, authenticated;

create or replace function public.get_identity_evidence_manifest(
  p_verification_id uuid
)
returns table (
  evidence_id uuid,
  evidence_type public.identity_evidence_type,
  evidence_status text,
  content_type text,
  byte_size bigint,
  submitted_at timestamptz,
  retention_delete_at timestamptz,
  preserved boolean
)
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
begin
  if auth.uid() is null
     or not private.is_production_identity_reviewer(auth.uid()) then
    raise exception 'production_identity_reviewer_required';
  end if;
  if not private.production_identity_ready() then
    raise exception 'production_verification_not_ready';
  end if;
  if not exists (
    select 1
    from public.identity_verifications verification
    where verification.id = p_verification_id
      and verification.environment = 'production'
  ) then
    raise exception 'production_verification_not_found';
  end if;

  insert into public.verification_audit_events (
    verification_id, actor_id, action, access_reason
  ) values (
    p_verification_id,
    auth.uid(),
    'production_evidence_manifest_viewed',
    'Trained production reviewer opened metadata-only evidence manifest.'
  );

  return query
  select
    evidence.id,
    evidence.evidence_type,
    evidence.evidence_status,
    evidence.content_type,
    evidence.byte_size,
    evidence.submitted_at,
    evidence.retention_delete_at,
    evidence.preserved_until is not null and evidence.preserved_until > now()
  from public.identity_verification_evidence evidence
  where evidence.verification_id = p_verification_id
    and evidence.environment = 'production'
  order by evidence.submitted_at;
end;
$$;

create or replace function public.authorize_identity_evidence_access(
  p_evidence_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_evidence public.identity_verification_evidence%rowtype;
  v_grant public.verification_evidence_access_grants%rowtype;
begin
  if auth.uid() is null
     or not private.is_production_identity_reviewer(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'production_identity_reviewer_required');
  end if;
  if not private.production_identity_ready() then
    return jsonb_build_object('ok', false, 'code', 'production_verification_not_ready');
  end if;
  if char_length(btrim(coalesce(p_reason, ''))) < 20 then
    return jsonb_build_object('ok', false, 'code', 'evidence_access_reason_required');
  end if;

  select * into v_evidence
  from public.identity_verification_evidence evidence
  where evidence.id = p_evidence_id
    and evidence.environment = 'production'
    and evidence.storage_path like 'production/%';
  if v_evidence.id is null then
    return jsonb_build_object('ok', false, 'code', 'production_evidence_not_found');
  end if;

  insert into public.verification_evidence_access_grants (
    evidence_id, reviewer_id, access_reason, expires_at
  ) values (
    p_evidence_id,
    auth.uid(),
    left(btrim(p_reason), 500),
    now() + interval '5 minutes'
  ) returning * into v_grant;

  insert into public.verification_audit_events (
    verification_id,
    evidence_id,
    actor_id,
    action,
    access_reason,
    event_data
  ) values (
    v_evidence.verification_id,
    p_evidence_id,
    auth.uid(),
    'production_evidence_access_authorized',
    left(btrim(p_reason), 500),
    jsonb_build_object('expires_at', v_grant.expires_at)
  );

  return jsonb_build_object(
    'ok', true,
    'evidence_id', v_evidence.id,
    'bucket_id', v_evidence.bucket_id,
    'storage_path', v_evidence.storage_path,
    'content_type', v_evidence.content_type,
    'expires_at', v_grant.expires_at
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

create or replace function public.process_identity_verification_provider_result(
  p_event_id text,
  p_provider text,
  p_environment text,
  p_provider_reference text,
  p_user_id uuid,
  p_result_status text,
  p_age_band text,
  p_verification_level smallint,
  p_expires_at timestamptz,
  p_event_timestamp timestamptz,
  p_payload_sha256 text,
  p_signature_verified boolean
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_control private.identity_verification_control%rowtype;
  v_verification public.identity_verifications%rowtype;
  v_status text := lower(btrim(coalesce(p_result_status, '')));
begin
  if coalesce(auth.jwt()->>'role', '') <> 'service_role' then
    return jsonb_build_object('ok', false, 'code', 'service_role_required');
  end if;

  select * into v_control
  from private.identity_verification_control control
  where control.singleton;

  if not private.production_identity_ready() then
    return jsonb_build_object('ok', false, 'code', 'production_verification_not_ready');
  end if;
  if not p_signature_verified then
    return jsonb_build_object('ok', false, 'code', 'provider_signature_required');
  end if;
  if lower(btrim(coalesce(p_environment, ''))) <> 'production' then
    return jsonb_build_object('ok', false, 'code', 'provider_environment_mismatch');
  end if;
  if p_provider is null or p_provider <> v_control.provider_slug then
    return jsonb_build_object('ok', false, 'code', 'unknown_identity_provider');
  end if;
  if char_length(btrim(coalesce(p_event_id, ''))) < 8
     or char_length(btrim(coalesce(p_event_id, ''))) > 200 then
    return jsonb_build_object('ok', false, 'code', 'invalid_provider_event_id');
  end if;
  if p_event_timestamp is null
     or p_event_timestamp < now() - interval '5 minutes'
     or p_event_timestamp > now() + interval '1 minute' then
    return jsonb_build_object('ok', false, 'code', 'provider_timestamp_outside_tolerance');
  end if;
  if p_payload_sha256 is null
     or p_payload_sha256 !~ '^[A-Fa-f0-9]{64}$' then
    return jsonb_build_object('ok', false, 'code', 'provider_payload_hash_required');
  end if;
  if v_status not in ('approved', 'rejected', 'needs_review') then
    return jsonb_build_object('ok', false, 'code', 'unknown_provider_result');
  end if;

  select * into v_verification
  from public.identity_verifications verification
  where verification.user_id = p_user_id
    and verification.provider = p_provider
    and verification.provider_reference = p_provider_reference
    and verification.environment = 'production'
  order by verification.created_at desc
  limit 1
  for update;

  if v_verification.id is null then
    return jsonb_build_object('ok', false, 'code', 'provider_account_binding_mismatch');
  end if;
  if v_verification.age_band <> p_age_band then
    return jsonb_build_object('ok', false, 'code', 'provider_age_band_mismatch');
  end if;
  if v_status = 'approved' and (
    p_expires_at is null
    or p_expires_at <= now()
    or p_expires_at > now() + interval '3 years'
    or p_verification_level < case when v_verification.account_role = 'teen' then 1 else 2 end
    or p_verification_level > 4
  ) then
    return jsonb_build_object('ok', false, 'code', 'invalid_provider_approval_scope');
  end if;

  begin
    insert into private.identity_verification_webhook_events (
      provider,
      event_id,
      environment,
      provider_reference,
      verification_id,
      user_id,
      event_timestamp,
      signature_verified,
      payload_sha256,
      result_status,
      processing_status
    ) values (
      p_provider,
      left(btrim(p_event_id), 200),
      'production',
      p_provider_reference,
      v_verification.id,
      p_user_id,
      p_event_timestamp,
      true,
      upper(p_payload_sha256),
      v_status,
      'received'
    );
  exception
    when unique_violation then
      return jsonb_build_object('ok', false, 'code', 'provider_webhook_replay');
  end;

  if v_status = 'approved' then
    update public.identity_verifications
    set status = 'verified',
        verification_level = p_verification_level,
        decision_source = 'provider_webhook',
        verified_at = now(),
        reviewed_at = now(),
        expires_at = p_expires_at,
        identity_match_result = 'provider_passed',
        liveness_result = 'provider_passed',
        rejection_code = null,
        updated_at = now()
    where id = v_verification.id
    returning * into v_verification;
  elsif v_status = 'rejected' then
    update public.identity_verifications
    set status = 'verification_rejected',
        verification_level = 0,
        decision_source = 'provider_webhook',
        verified_at = null,
        reviewed_at = now(),
        rejection_code = 'provider_rejected',
        updated_at = now()
    where id = v_verification.id
    returning * into v_verification;
  else
    update public.identity_verifications
    set status = 'manual_review',
        verification_level = 0,
        decision_source = 'provider_webhook',
        verified_at = null,
        reviewed_at = now(),
        updated_at = now()
    where id = v_verification.id
    returning * into v_verification;
  end if;

  update private.identity_verification_sessions session
  set status = case when v_status = 'needs_review' then 'pending' else 'completed' end,
      completed_at = case when v_status = 'needs_review' then null else now() end
  where session.verification_id = v_verification.id;

  update private.identity_verification_webhook_events event
  set processing_status = 'processed',
      processed_at = now()
  where event.provider = p_provider
    and event.event_id = p_event_id;

  perform set_config('mort.internal_update', 'true', true);
  update public.profiles
  set verification_status = case when v_status = 'approved' then 'approved'::public.verification_status
                                 when v_status = 'rejected' then 'rejected'::public.verification_status
                                 else 'pending'::public.verification_status end,
      updated_at = now()
  where id = p_user_id;
  perform set_config('mort.internal_update', '', true);

  insert into public.verification_audit_events (
    verification_id, actor_id, action, event_data
  ) values (
    v_verification.id,
    null,
    'signed_provider_result_processed',
    jsonb_build_object(
      'provider', p_provider,
      'event_id', p_event_id,
      'environment', 'production',
      'result_status', v_status,
      'payload_sha256', upper(p_payload_sha256)
    )
  );

  return jsonb_build_object(
    'ok', true,
    'verification_id', v_verification.id,
    'status', v_verification.status,
    'environment', 'production',
    'decision_source', 'provider_webhook',
    'production_eligible', private.has_current_production_identity(p_user_id)
  );
end;
$$;

create or replace function public.get_public_trust_badges(p_user_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = 'public', 'auth', 'pg_temp'
as $$
declare
  v_caller_id uuid := auth.uid();
  v_caller public.profiles%rowtype;
  v_profile public.profiles%rowtype;
  v_verification public.identity_verifications%rowtype;
  v_email_verified boolean := false;
  v_phone_verified boolean := false;
  v_business_verified boolean := false;
  v_badges jsonb := '[]'::jsonb;
begin
  if v_caller_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;

  select * into v_caller
  from public.profiles profile
  where profile.id = v_caller_id
    and profile.account_status = 'active';
  select * into v_profile
  from public.profiles profile
  where profile.id = p_user_id
    and profile.account_status = 'active';
  if v_profile.id is null or v_caller.id is null then
    return jsonb_build_object('ok', false, 'code', 'profile_not_found');
  end if;
  if v_caller.role <> 'admin'
     and v_caller.is_test_account <> v_profile.is_test_account then
    return jsonb_build_object('ok', false, 'code', 'profile_not_found');
  end if;

  select user_record.email_confirmed_at is not null,
         user_record.phone_confirmed_at is not null
  into v_email_verified, v_phone_verified
  from auth.users user_record
  where user_record.id = p_user_id;

  if not v_profile.is_test_account and private.production_identity_ready() then
    select * into v_verification
    from public.identity_verifications verification
    where verification.user_id = p_user_id
      and verification.environment = 'production'
      and verification.status = 'verified'
      and verification.verified_at is not null
      and verification.decision_source in ('provider_webhook', 'approved_manual_exception')
      and (verification.expires_at is null or verification.expires_at > now())
    order by verification.verification_level desc, verification.verified_at desc
    limit 1;
  end if;

  select exists (
    select 1
    from public.business_verifications business
    where business.adult_id = p_user_id
      and business.status = 'approved'
      and not v_profile.is_test_account
  ) into v_business_verified;

  if v_email_verified then
    v_badges := v_badges || jsonb_build_array(jsonb_build_object(
      'key', 'email_verified',
      'label', 'Email verified',
      'explanation', 'The account confirmed access to its email address. This does not guarantee safety.',
      'optional', false
    ));
  end if;
  if v_phone_verified then
    v_badges := v_badges || jsonb_build_array(jsonb_build_object(
      'key', 'phone_verified',
      'label', 'Phone verified',
      'explanation', 'The account confirmed access to a phone number. The number is not public and verification does not guarantee safety.',
      'optional', false
    ));
  end if;
  if v_verification.id is not null then
    v_badges := v_badges || jsonb_build_array(jsonb_build_object(
      'key', case when v_profile.role = 'teen' then 'teen_identity_verified' else 'adult_identity_verified' end,
      'label', case when v_profile.role = 'teen' then 'Teen identity verified' else 'Adult identity verified' end,
      'explanation', 'An approved production provider returned a current identity and age result. Verification does not guarantee safety.',
      'environment', 'production',
      'expires_at', v_verification.expires_at,
      'optional', false
    ));
  end if;
  if v_business_verified then
    v_badges := v_badges || jsonb_build_array(jsonb_build_object(
      'key', 'business_verified',
      'label', 'Business verified',
      'explanation', 'MORT approved submitted business evidence for the responsible account owner. This does not guarantee safety.',
      'optional', true
    ));
  end if;

  return jsonb_build_object('ok', true, 'badges', v_badges);
end;
$$;

revoke all on function public.process_identity_verification_provider_result(
  text, text, text, text, uuid, text, text, smallint,
  timestamptz, timestamptz, text, boolean
) from public, anon, authenticated;
grant execute on function public.process_identity_verification_provider_result(
  text, text, text, text, uuid, text, text, smallint,
  timestamptz, timestamptz, text, boolean
) to service_role;

revoke all on function public.get_public_trust_badges(uuid)
from public, anon;
grant execute on function public.get_public_trust_badges(uuid)
to authenticated, service_role;

revoke all on function public.get_my_identity_verification(),
  public.start_identity_verification(text, boolean, text),
  public.register_identity_evidence(uuid, uuid, text, text, text),
  public.submit_identity_verification(uuid, boolean),
  public.get_identity_evidence_manifest(uuid),
  public.authorize_identity_evidence_access(uuid, text),
  public.admin_review_identity_verification(
    uuid, text, text, text, text, text, text, text, timestamptz
  )
from public, anon;

grant execute on function public.get_my_identity_verification(),
  public.start_identity_verification(text, boolean, text),
  public.register_identity_evidence(uuid, uuid, text, text, text),
  public.submit_identity_verification(uuid, boolean),
  public.get_identity_evidence_manifest(uuid),
  public.authorize_identity_evidence_access(uuid, text),
  public.admin_review_identity_verification(
    uuid, text, text, text, text, text, text, text, timestamptz
  )
to authenticated, service_role;
