-- MORT multi-signal account trust foundation.
-- Account security, affiliation, registry matching, and identity are separate
-- signals. Only server-owned policy can grant marketplace eligibility.

alter type public.admin_safety_role add value if not exists 'affiliation_reviewer';
alter type public.admin_safety_role add value if not exists 'business_reviewer';
alter type public.admin_safety_role add value if not exists 'safety_moderator';

create table private.trust_policy_versions (
  id uuid primary key default gen_random_uuid(),
  version integer not null unique check (version > 0),
  policy_name text not null,
  is_active boolean not null default false,
  minimum_teen_trust_level smallint not null check (minimum_teen_trust_level between 0 and 5),
  minimum_adult_trust_level smallint not null check (minimum_adult_trust_level between 0 and 5),
  minimum_business_trust_level smallint not null check (minimum_business_trust_level between 0 and 5),
  allow_affiliation_only_pilot boolean not null default false,
  require_digital_government_id boolean not null default false,
  require_provider_verification boolean not null default true,
  require_enhanced_adult_screening boolean not null default false,
  require_business_registry_match boolean not null default true,
  pilot_region text,
  pilot_account_allowlist uuid[] not null default '{}',
  production_marketplace_enabled boolean not null default false,
  identity_document_collection_enabled boolean not null default false,
  passkeys_enabled boolean not null default false,
  phone_verification_available boolean not null default false,
  school_affiliation_enabled boolean not null default true,
  partner_codes_enabled boolean not null default true,
  business_registry_manual_review_enabled boolean not null default true,
  apple_wallet_enabled boolean not null default false,
  android_digital_credentials_enabled boolean not null default false,
  approved_by uuid references public.profiles(id) on delete set null,
  approval_reference text,
  effective_at timestamptz not null default now(),
  retired_at timestamptz,
  created_at timestamptz not null default now(),
  constraint trust_policy_name_length check (char_length(policy_name) between 3 and 120),
  constraint trust_policy_production_controls check (
    not production_marketplace_enabled
    or (
      approval_reference is not null
      and char_length(approval_reference) between 8 and 200
      and approved_by is not null
    )
  )
);

create unique index trust_policy_one_active_idx
on private.trust_policy_versions(is_active)
where is_active;

insert into private.trust_policy_versions (
  version,
  policy_name,
  is_active,
  minimum_teen_trust_level,
  minimum_adult_trust_level,
  minimum_business_trust_level,
  allow_affiliation_only_pilot,
  require_digital_government_id,
  require_provider_verification,
  require_enhanced_adult_screening,
  require_business_registry_match,
  pilot_region,
  production_marketplace_enabled,
  identity_document_collection_enabled,
  passkeys_enabled,
  phone_verification_available,
  school_affiliation_enabled,
  partner_codes_enabled,
  business_registry_manual_review_enabled,
  apple_wallet_enabled,
  android_digital_credentials_enabled
) values (
  1,
  'zero-budget-hosted-closed',
  true,
  4,
  4,
  4,
  false,
  false,
  true,
  false,
  true,
  null,
  false,
  false,
  false,
  false,
  true,
  true,
  true,
  false,
  false
)
on conflict (version) do update
set policy_name = excluded.policy_name,
    is_active = true,
    production_marketplace_enabled = false,
    identity_document_collection_enabled = false,
    passkeys_enabled = false,
    phone_verification_available = false,
    apple_wallet_enabled = false,
    android_digital_credentials_enabled = false,
    retired_at = null;

create table public.account_trust_profiles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  current_level smallint not null default 0 check (current_level between 0 and 5),
  signal_environment public.verification_environment not null default 'production',
  risk_level text not null default 'low'
    check (risk_level in ('low', 'review', 'elevated', 'restricted')),
  risk_reasons jsonb not null default '[]'::jsonb check (jsonb_typeof(risk_reasons) = 'array'),
  recommended_action text not null default 'none'
    check (recommended_action in ('none', 'review_sessions', 'contact_support', 'human_review', 'account_restricted')),
  human_review_required boolean not null default false,
  address_validation_status text not null default 'unavailable'
    check (address_validation_status in ('unavailable', 'sandbox_only', 'pending', 'validated', 'failed', 'expired')),
  address_validation_method text,
  address_verified_at timestamptz,
  address_change_pending boolean not null default false,
  address_risk_flags jsonb not null default '[]'::jsonb check (jsonb_typeof(address_risk_flags) = 'array'),
  calculated_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint account_trust_no_address_payload check (
    address_validation_method is null
    or char_length(address_validation_method) <= 80
  )
);

create table public.trust_signal_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  signal_type text not null,
  category text not null
    check (category in ('account_security', 'contact', 'affiliation', 'business_registry', 'digital_identity', 'provider_identity', 'adult_screening', 'risk')),
  status text not null
    check (status in ('pending', 'verified', 'rejected', 'revoked', 'expired')),
  environment public.verification_environment not null,
  source_kind text not null
    check (source_kind in ('auth', 'device_security', 'school_domain', 'partner_code', 'business_registry', 'digital_credential', 'identity_provider', 'screening_provider', 'moderation', 'system')),
  source_reference text,
  public_label text not null,
  what_was_checked text not null,
  what_was_not_checked text not null,
  checked_at timestamptz,
  expires_at timestamptz,
  revoked_at timestamptz,
  public_visibility boolean not null default false,
  grants_marketplace_access boolean not null default false,
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint trust_signal_type_length check (char_length(signal_type) between 3 and 80),
  constraint trust_signal_explanation_length check (
    char_length(public_label) between 3 and 100
    and char_length(what_was_checked) between 12 and 800
    and char_length(what_was_not_checked) between 12 and 800
  ),
  constraint trust_signal_verified_timestamp check (status <> 'verified' or checked_at is not null),
  constraint trust_signal_expiry_order check (expires_at is null or checked_at is null or expires_at > checked_at),
  constraint trust_signal_no_sensitive_payload check (
    not (metadata ?| array[
      'email', 'phone', 'full_address', 'residential_address', 'raw_credential',
      'document', 'document_number', 'selfie', 'biometric', 'portrait'
    ])
  ),
  constraint trust_signal_no_local_biometric_identity check (
    signal_type not in ('device_biometric', 'device_reauthentication')
    or (category = 'account_security' and source_kind = 'device_security' and grants_marketplace_access = false)
  )
);

create index trust_signal_user_current_idx
on public.trust_signal_events(user_id, environment, status, expires_at);
create index trust_signal_review_idx
on public.trust_signal_events(category, status, created_at desc);

create table public.account_security_preferences (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  device_reauthentication_enabled boolean not null default false,
  lock_after_minutes smallint not null default 15 check (lock_after_minutes between 1 and 240),
  protect_private_location boolean not null default true,
  protect_payment_preferences boolean not null default true,
  protect_verification_settings boolean not null default true,
  protect_incident_records boolean not null default true,
  protect_account_deletion boolean not null default true,
  protect_data_export boolean not null default true,
  protect_session_revocation boolean not null default true,
  suspicious_session_monitoring_enabled boolean not null default true
    check (suspicious_session_monitoring_enabled),
  configured_at timestamptz,
  updated_at timestamptz not null default now()
);

create table public.sensitive_action_reauth_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  action_type text not null,
  authentication_method text not null
    check (authentication_method in ('device_owner_authentication', 'passcode_fallback', 'webauthn', 'secure_fallback')),
  result text not null check (result in ('succeeded', 'failed', 'cancelled', 'denied', 'locked_out', 'unavailable')),
  session_reference text,
  valid_until timestamptz,
  identity_effect boolean not null default false check (identity_effect = false),
  biometric_material_stored boolean not null default false check (biometric_material_stored = false),
  created_at timestamptz not null default now(),
  constraint sensitive_reauth_action_length check (char_length(action_type) between 3 and 100),
  constraint sensitive_reauth_reference_length check (session_reference is null or char_length(session_reference) <= 100)
);

create table public.school_domains (
  id uuid primary key default gen_random_uuid(),
  normalized_domain text not null,
  organization_name text not null,
  organization_type text not null
    check (organization_type in ('school', 'online_school', 'vocational_program')),
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected', 'revoked')),
  environment public.verification_environment not null default 'production',
  official_source_url text,
  public_directory_enabled boolean not null default false check (public_directory_enabled = false),
  approved_by uuid references public.profiles(id) on delete set null,
  approved_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint school_domain_format check (normalized_domain = lower(normalized_domain) and normalized_domain ~ '^[a-z0-9.-]+\.[a-z]{2,}$'),
  constraint school_domain_unique unique (normalized_domain, environment),
  constraint school_domain_approval_fields check (status <> 'approved' or approved_at is not null)
);

create table public.partner_organizations (
  id uuid primary key default gen_random_uuid(),
  organization_type text not null
    check (organization_type in ('school', 'online_school', 'vocational_program', 'nonprofit', 'youth_program', 'community_center', 'workforce_program')),
  legal_name text not null,
  display_name text not null,
  status text not null default 'pending'
    check (status in ('pending', 'verified', 'rejected', 'suspended', 'revoked')),
  environment public.verification_environment not null default 'production',
  official_directory_url text,
  verified_by uuid references public.profiles(id) on delete set null,
  verified_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint partner_org_name_length check (
    char_length(legal_name) between 2 and 200 and char_length(display_name) between 2 and 120
  ),
  constraint partner_org_verified_fields check (status <> 'verified' or (verified_by is not null and verified_at is not null))
);

create table public.partner_domains (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.partner_organizations(id) on delete cascade,
  normalized_domain text not null,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected', 'revoked')),
  approved_by uuid references public.profiles(id) on delete set null,
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  constraint partner_domain_format check (normalized_domain = lower(normalized_domain) and normalized_domain ~ '^[a-z0-9.-]+\.[a-z]{2,}$'),
  constraint partner_domain_unique unique (organization_id, normalized_domain)
);

create table public.partner_programs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.partner_organizations(id) on delete cascade,
  name text not null,
  status text not null default 'active' check (status in ('active', 'paused', 'closed')),
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint partner_program_name_length check (char_length(name) between 2 and 120),
  constraint partner_program_dates check (ends_at is null or starts_at is null or ends_at > starts_at)
);

create table public.partner_invite_codes (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.partner_organizations(id) on delete cascade,
  program_id uuid references public.partner_programs(id) on delete cascade,
  code_hash bytea not null unique,
  code_prefix text not null,
  max_uses integer not null check (max_uses between 1 and 10000),
  use_count integer not null default 0 check (use_count >= 0 and use_count <= max_uses),
  expires_at timestamptz not null,
  revoked_at timestamptz,
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint partner_code_prefix_length check (char_length(code_prefix) between 3 and 12),
  constraint partner_code_expiry_required check (expires_at > created_at)
);

create index partner_invite_active_idx
on public.partner_invite_codes(organization_id, expires_at)
where revoked_at is null;

create table public.partner_memberships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  organization_id uuid not null references public.partner_organizations(id) on delete cascade,
  program_id uuid references public.partner_programs(id) on delete set null,
  status text not null default 'active' check (status in ('active', 'expired', 'revoked', 'removed_by_user')),
  verification_method text not null check (verification_method in ('school_email', 'partner_code', 'program_code', 'approved_future_review')),
  public_display_enabled boolean not null default false,
  verified_at timestamptz not null default now(),
  expires_at timestamptz not null,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint partner_membership_expiry check (expires_at > verified_at)
);

create unique index partner_membership_active_unique_idx
on public.partner_memberships(user_id, organization_id, coalesce(program_id, '00000000-0000-0000-0000-000000000000'::uuid))
where status = 'active' and revoked_at is null;

create table public.partner_verification_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  request_type text not null check (request_type in ('school_email', 'school_partner_code', 'youth_program_code', 'manual_future_review')),
  requested_domain text,
  organization_id uuid references public.partner_organizations(id) on delete set null,
  program_id uuid references public.partner_programs(id) on delete set null,
  status text not null default 'pending' check (status in ('pending', 'pending_domain_review', 'verified', 'rejected', 'cancelled')),
  environment public.verification_environment not null,
  reviewer_id uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  decision_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint partner_request_domain_format check (requested_domain is null or requested_domain ~ '^[a-z0-9.-]+\.[a-z]{2,}$')
);

create table public.partner_audit_events (
  id bigint generated always as identity primary key,
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  resource_type text not null,
  resource_id uuid,
  access_reason text not null,
  case_id text,
  event_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint partner_audit_reason_length check (char_length(access_reason) between 8 and 800),
  constraint partner_audit_case_length check (case_id is null or char_length(case_id) between 4 and 100),
  constraint partner_audit_no_sensitive_payload check (
    not (event_data ?| array['email', 'phone', 'full_address', 'raw_document', 'raw_credential', 'selfie', 'biometric'])
  )
);

create table public.official_source_allowlist (
  id uuid primary key default gen_random_uuid(),
  hostname text not null,
  source_category text not null check (source_category in ('business_registry', 'professional_license', 'organization_directory', 'digital_credential_issuer')),
  jurisdiction text not null default 'GLOBAL',
  source_owner text not null,
  manual_review_allowed boolean not null default false,
  automated_matching_allowed boolean not null default false,
  legal_review_status text not null default 'pending' check (legal_review_status in ('pending', 'approved', 'rejected')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint official_source_hostname_format check (hostname = lower(hostname) and hostname ~ '^[a-z0-9.-]+\.[a-z]{2,}$'),
  constraint official_source_unique unique (hostname, source_category, jurisdiction),
  constraint official_source_automation_review check (not automated_matching_allowed or legal_review_status = 'approved')
);

insert into public.official_source_allowlist (
  hostname, source_category, jurisdiction, source_owner,
  manual_review_allowed, automated_matching_allowed, legal_review_status, notes
) values
  ('inbiz.in.gov', 'business_registry', 'US-IN', 'Indiana Secretary of State', true, false, 'pending', 'Manual official-source review only; no production scraping adapter is enabled.'),
  ('bsd.sos.in.gov', 'business_registry', 'US-IN', 'Indiana Secretary of State Business Services Division', true, false, 'pending', 'Manual official business-search review only; HTML scraping is not enabled.')
on conflict (hostname, source_category, jurisdiction) do update
set manual_review_allowed = true,
    automated_matching_allowed = false,
    notes = excluded.notes,
    updated_at = now();

create table public.business_registry_checks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  jurisdiction text not null,
  legal_business_name text not null,
  registration_number text not null,
  entity_type text,
  registration_status text,
  official_source_url text not null,
  official_source_host text not null,
  source_snapshot_at timestamptz,
  match_confidence numeric(4,3),
  status text not null default 'pending_manual_review'
    check (status in ('pending_manual_review', 'matched', 'mismatched', 'appealed', 'expired', 'revoked')),
  mismatch_explanation text,
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint business_registry_name_length check (char_length(legal_business_name) between 2 and 200),
  constraint business_registry_number_length check (char_length(registration_number) between 2 and 100),
  constraint business_registry_url_https check (official_source_url ~ '^https://'),
  constraint business_registry_confidence_range check (match_confidence is null or (match_confidence >= 0 and match_confidence <= 1)),
  constraint business_registry_review_fields check (
    status not in ('matched', 'mismatched')
    or (reviewed_by is not null and reviewed_at is not null and source_snapshot_at is not null)
  )
);

create unique index business_registry_pending_unique_idx
on public.business_registry_checks(user_id, jurisdiction, registration_number)
where status in ('pending_manual_review', 'appealed');

create table public.business_representative_claims (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  business_registry_check_id uuid not null references public.business_registry_checks(id) on delete cascade,
  relationship_type text not null check (relationship_type in ('owner', 'officer', 'employee', 'authorized_agent', 'other')),
  attested boolean not null check (attested),
  status text not null default 'pending_future_verification'
    check (status in ('pending_future_verification', 'more_information_required', 'rejected', 'verified_by_future_provider', 'revoked')),
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  decision_reason text,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint business_representative_one_claim unique (user_id, business_registry_check_id)
);

create table public.digital_credential_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  provider text not null check (provider in ('apple_wallet', 'android_credential_manager')),
  environment public.verification_environment not null,
  nonce_sha256 text not null unique check (nonce_sha256 ~ '^[A-Fa-f0-9]{64}$'),
  expected_issuer text not null,
  expected_credential_type text not null,
  requested_attributes jsonb not null default '[]'::jsonb check (jsonb_typeof(requested_attributes) = 'array'),
  status text not null default 'created' check (status in ('created', 'presented', 'verified', 'rejected', 'expired', 'cancelled')),
  account_bound boolean not null default false,
  expires_at timestamptz not null,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint digital_session_expiry check (expires_at > created_at),
  constraint digital_session_minimal_attributes check (
    not (requested_attributes ?| array['document_number', 'full_address', 'portrait', 'signature'])
  )
);

create table public.digital_credential_events (
  id bigint generated always as identity primary key,
  session_id uuid not null references public.digital_credential_sessions(id) on delete cascade,
  provider text not null,
  event_id text not null,
  payload_sha256 text not null check (payload_sha256 ~ '^[A-Fa-f0-9]{64}$'),
  signature_valid boolean not null,
  nonce_valid boolean not null,
  issuer_valid boolean not null,
  credential_type_valid boolean not null,
  account_binding_valid boolean not null,
  credential_current boolean not null,
  result text not null check (result in ('verified', 'rejected')),
  failure_code text,
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  constraint digital_credential_event_unique unique (provider, event_id)
);

create table public.account_trust_appeals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  signal_id uuid references public.trust_signal_events(id) on delete set null,
  reason text not null,
  status text not null default 'pending' check (status in ('pending', 'reviewing', 'resolved', 'denied', 'cancelled')),
  resolution text,
  reviewer_id uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint account_trust_appeal_reason_length check (char_length(reason) between 20 and 2000)
);

insert into public.school_domains (
  normalized_domain, organization_name, organization_type, status,
  environment, official_source_url, approved_at, expires_at
) values (
  'mort.test',
  'MORT synthetic QA school domain',
  'school',
  'approved',
  'sandbox',
  'https://mort.test/qa-only',
  now(),
  now() + interval '10 years'
)
on conflict (normalized_domain, environment) do update
set organization_name = excluded.organization_name,
    status = 'approved',
    public_directory_enabled = false,
    approved_at = coalesce(public.school_domains.approved_at, excluded.approved_at),
    expires_at = excluded.expires_at,
    updated_at = now();

create or replace function private.has_trust_admin_role(
  p_user_id uuid,
  p_allowed_roles text[]
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles profile
    join public.admin_role_assignments assignment
      on assignment.user_id = profile.id
     and assignment.revoked_at is null
    where profile.id = p_user_id
      and profile.role = 'admin'
      and profile.account_status = 'active'
      and (
        assignment.role::text = 'super_admin'
        or assignment.role::text = any(p_allowed_roles)
      )
  );
$$;

revoke all on function private.has_trust_admin_role(uuid, text[])
from public, anon, authenticated;

alter table private.trust_policy_versions enable row level security;
alter table public.account_trust_profiles enable row level security;
alter table public.trust_signal_events enable row level security;
alter table public.account_security_preferences enable row level security;
alter table public.sensitive_action_reauth_events enable row level security;
alter table public.school_domains enable row level security;
alter table public.partner_organizations enable row level security;
alter table public.partner_domains enable row level security;
alter table public.partner_programs enable row level security;
alter table public.partner_invite_codes enable row level security;
alter table public.partner_memberships enable row level security;
alter table public.partner_verification_requests enable row level security;
alter table public.partner_audit_events enable row level security;
alter table public.official_source_allowlist enable row level security;
alter table public.business_registry_checks enable row level security;
alter table public.business_representative_claims enable row level security;
alter table public.digital_credential_sessions enable row level security;
alter table public.digital_credential_events enable row level security;
alter table public.account_trust_appeals enable row level security;

create policy account_trust_profiles_select_own
on public.account_trust_profiles for select to authenticated
using (user_id = (select auth.uid()));

create policy trust_signal_events_select_own
on public.trust_signal_events for select to authenticated
using (user_id = (select auth.uid()));

create policy account_security_preferences_select_own
on public.account_security_preferences for select to authenticated
using (user_id = (select auth.uid()));

create policy sensitive_action_reauth_events_select_own
on public.sensitive_action_reauth_events for select to authenticated
using (user_id = (select auth.uid()));

create policy school_domains_reviewer_select
on public.school_domains for select to authenticated
using (
  private.has_trust_admin_role(
    (select auth.uid()),
    array['affiliation_reviewer']::text[]
  )
);

create policy partner_organizations_reviewer_select
on public.partner_organizations for select to authenticated
using (
  private.has_trust_admin_role(
    (select auth.uid()),
    array['affiliation_reviewer']::text[]
  )
);

create policy partner_domains_reviewer_select
on public.partner_domains for select to authenticated
using (
  private.has_trust_admin_role(
    (select auth.uid()),
    array['affiliation_reviewer']::text[]
  )
);

create policy partner_programs_reviewer_select
on public.partner_programs for select to authenticated
using (
  private.has_trust_admin_role(
    (select auth.uid()),
    array['affiliation_reviewer']::text[]
  )
);

create policy partner_invite_codes_reviewer_select
on public.partner_invite_codes for select to authenticated
using (
  private.has_trust_admin_role(
    (select auth.uid()),
    array['affiliation_reviewer']::text[]
  )
);

create policy partner_memberships_select_own
on public.partner_memberships for select to authenticated
using (user_id = (select auth.uid()));

create policy partner_requests_select_own_or_reviewer
on public.partner_verification_requests for select to authenticated
using (
  user_id = (select auth.uid())
  or private.has_trust_admin_role(
    (select auth.uid()),
    array['affiliation_reviewer']::text[]
  )
);

create policy partner_audit_reviewer_select
on public.partner_audit_events for select to authenticated
using (
  private.has_trust_admin_role(
    (select auth.uid()),
    array['affiliation_reviewer', 'business_reviewer', 'verification_reviewer', 'senior_safety_moderator']::text[]
  )
);

create policy official_sources_reviewer_select
on public.official_source_allowlist for select to authenticated
using (
  private.has_trust_admin_role(
    (select auth.uid()),
    array['affiliation_reviewer', 'business_reviewer', 'verification_reviewer']::text[]
  )
);

create policy business_registry_checks_select_own_or_reviewer
on public.business_registry_checks for select to authenticated
using (
  user_id = (select auth.uid())
  or private.has_trust_admin_role(
    (select auth.uid()),
    array['business_reviewer']::text[]
  )
);

create policy business_representative_claims_select_own_or_reviewer
on public.business_representative_claims for select to authenticated
using (
  user_id = (select auth.uid())
  or private.has_trust_admin_role(
    (select auth.uid()),
    array['business_reviewer', 'verification_reviewer']::text[]
  )
);

create policy digital_credential_sessions_select_own
on public.digital_credential_sessions for select to authenticated
using (user_id = (select auth.uid()));

create policy digital_credential_events_select_own
on public.digital_credential_events for select to authenticated
using (
  exists (
    select 1
    from public.digital_credential_sessions session
    where session.id = digital_credential_events.session_id
      and session.user_id = (select auth.uid())
  )
);

create policy account_trust_appeals_select_own_or_reviewer
on public.account_trust_appeals for select to authenticated
using (
  user_id = (select auth.uid())
  or private.has_trust_admin_role(
    (select auth.uid()),
    array['affiliation_reviewer', 'business_reviewer', 'verification_reviewer', 'senior_safety_moderator']::text[]
  )
);

revoke all on private.trust_policy_versions
from public, anon, authenticated;

revoke all on public.account_trust_profiles,
  public.trust_signal_events,
  public.account_security_preferences,
  public.sensitive_action_reauth_events,
  public.school_domains,
  public.partner_organizations,
  public.partner_domains,
  public.partner_programs,
  public.partner_invite_codes,
  public.partner_memberships,
  public.partner_verification_requests,
  public.partner_audit_events,
  public.official_source_allowlist,
  public.business_registry_checks,
  public.business_representative_claims,
  public.digital_credential_sessions,
  public.digital_credential_events,
  public.account_trust_appeals
from public, anon, authenticated;

grant select on public.account_trust_profiles,
  public.trust_signal_events,
  public.account_security_preferences,
  public.sensitive_action_reauth_events,
  public.school_domains,
  public.partner_organizations,
  public.partner_domains,
  public.partner_programs,
  public.partner_invite_codes,
  public.partner_memberships,
  public.partner_verification_requests,
  public.partner_audit_events,
  public.official_source_allowlist,
  public.business_registry_checks,
  public.business_representative_claims,
  public.digital_credential_sessions,
  public.digital_credential_events,
  public.account_trust_appeals
to authenticated;

grant all on private.trust_policy_versions to service_role;
grant all on public.account_trust_profiles,
  public.trust_signal_events,
  public.account_security_preferences,
  public.sensitive_action_reauth_events,
  public.school_domains,
  public.partner_organizations,
  public.partner_domains,
  public.partner_programs,
  public.partner_invite_codes,
  public.partner_memberships,
  public.partner_verification_requests,
  public.partner_audit_events,
  public.official_source_allowlist,
  public.business_registry_checks,
  public.business_representative_claims,
  public.digital_credential_sessions,
  public.digital_credential_events,
  public.account_trust_appeals
to service_role;

grant usage, select on sequence public.partner_audit_events_id_seq to service_role;
grant usage, select on sequence public.digital_credential_events_id_seq to service_role;

alter table public.trust_signal_events
  add constraint trust_signal_never_grants_access_alone
  check (grants_marketplace_access = false);

create trigger account_trust_profiles_updated_at
before update on public.account_trust_profiles
for each row execute function public.set_updated_at();

create trigger trust_signal_events_updated_at
before update on public.trust_signal_events
for each row execute function public.set_updated_at();

create trigger account_security_preferences_updated_at
before update on public.account_security_preferences
for each row execute function public.set_updated_at();

create trigger school_domains_updated_at
before update on public.school_domains
for each row execute function public.set_updated_at();

create trigger partner_organizations_updated_at
before update on public.partner_organizations
for each row execute function public.set_updated_at();

create trigger partner_programs_updated_at
before update on public.partner_programs
for each row execute function public.set_updated_at();

create trigger partner_memberships_updated_at
before update on public.partner_memberships
for each row execute function public.set_updated_at();

create trigger partner_verification_requests_updated_at
before update on public.partner_verification_requests
for each row execute function public.set_updated_at();

create trigger official_source_allowlist_updated_at
before update on public.official_source_allowlist
for each row execute function public.set_updated_at();

create trigger business_registry_checks_updated_at
before update on public.business_registry_checks
for each row execute function public.set_updated_at();

create trigger business_representative_claims_updated_at
before update on public.business_representative_claims
for each row execute function public.set_updated_at();

create trigger digital_credential_sessions_updated_at
before update on public.digital_credential_sessions
for each row execute function public.set_updated_at();

create trigger account_trust_appeals_updated_at
before update on public.account_trust_appeals
for each row execute function public.set_updated_at();

create or replace function private.current_trust_policy()
returns private.trust_policy_versions
language sql
stable
security definer
set search_path = ''
as $$
  select policy.*
  from private.trust_policy_versions policy
  where policy.is_active
    and policy.effective_at <= now()
    and policy.retired_at is null
  order by policy.version desc
  limit 1;
$$;

create or replace function private.user_trust_environment(p_user_id uuid)
returns public.verification_environment
language sql
stable
security definer
set search_path = ''
as $$
  select case when profile.is_test_account then 'sandbox'::public.verification_environment
              else 'production'::public.verification_environment end
  from public.profiles profile
  where profile.id = p_user_id;
$$;

create or replace function private.compute_account_trust_level(p_user_id uuid)
returns smallint
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_profile public.profiles%rowtype;
  v_policy private.trust_policy_versions%rowtype;
  v_environment public.verification_environment;
  v_email_verified boolean := false;
  v_phone_verified boolean := false;
  v_password_present boolean := false;
  v_passkey_present boolean := false;
  v_device_reauth boolean := false;
  v_monitoring boolean := true;
  v_level smallint := 0;
  v_signal_level smallint := 0;
begin
  select * into v_profile
  from public.profiles profile
  where profile.id = p_user_id;
  if v_profile.id is null then
    return 0;
  end if;

  select * into v_policy from private.current_trust_policy();
  v_environment := case when v_profile.is_test_account then 'sandbox'::public.verification_environment
                        else 'production'::public.verification_environment end;

  select user_record.email_confirmed_at is not null,
         user_record.phone_confirmed_at is not null,
         nullif(user_record.encrypted_password, '') is not null
  into v_email_verified, v_phone_verified, v_password_present
  from auth.users user_record
  where user_record.id = p_user_id;

  select exists (
    select 1
    from auth.webauthn_credentials credential
    where credential.user_id = p_user_id
  ) into v_passkey_present;

  select preference.device_reauthentication_enabled,
         preference.suspicious_session_monitoring_enabled
  into v_device_reauth, v_monitoring
  from public.account_security_preferences preference
  where preference.user_id = p_user_id;

  v_device_reauth := coalesce(v_device_reauth, false);
  v_monitoring := coalesce(v_monitoring, true);
  if v_email_verified
     and (not coalesce(v_policy.phone_verification_available, false) or v_phone_verified)
     and (v_password_present or v_passkey_present)
     and v_device_reauth
     and v_monitoring then
    v_level := 1;
  end if;

  select coalesce(max(case
    when signal.signal_type = 'enhanced_adult_screening' then 5
    when signal.signal_type = 'digital_government_id' then 3
    when signal.signal_type in (
      'school_affiliation', 'program_affiliation', 'business_registry_match'
    ) then 2
    when signal.signal_type in (
      'phone_verified', 'passkey_enabled', 'device_reauthentication'
    ) then 1
    else 0
  end), 0)::smallint
  into v_signal_level
  from public.trust_signal_events signal
  where signal.user_id = p_user_id
    and signal.environment = v_environment
    and signal.status = 'verified'
    and signal.checked_at is not null
    and (signal.expires_at is null or signal.expires_at > now())
    and signal.revoked_at is null;

  v_level := greatest(v_level, v_signal_level);

  if not v_profile.is_test_account
     and private.has_current_production_identity(p_user_id) then
    v_level := greatest(v_level, 4);
  end if;

  return least(v_level, 5)::smallint;
end;
$$;

create or replace function private.evaluate_account_risk(p_user_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_profile public.profiles%rowtype;
  v_reasons jsonb := '[]'::jsonb;
  v_level text := 'low';
  v_action text := 'none';
  v_review boolean := false;
  v_security_events integer := 0;
  v_expired_signals integer := 0;
begin
  select * into v_profile
  from public.profiles profile
  where profile.id = p_user_id;
  if v_profile.id is null then
    return jsonb_build_object(
      'risk_level', 'review',
      'risk_reasons', jsonb_build_array('profile_not_found'),
      'recommended_action', 'contact_support',
      'human_review_required', true
    );
  end if;

  if v_profile.account_status <> 'active'
     or (v_profile.blocked_until is not null and v_profile.blocked_until > now()) then
    v_level := 'restricted';
    v_action := 'account_restricted';
    v_review := true;
    v_reasons := v_reasons || jsonb_build_array('active_account_restriction');
  end if;

  select count(*)::integer into v_security_events
  from public.account_security_events event
  where event.user_id = p_user_id
    and event.severity in ('high', 'critical', 'review')
    and event.status not in ('resolved', 'dismissed')
    and event.created_at > now() - interval '30 days';

  if v_security_events > 0 and v_level <> 'restricted' then
    v_level := case when v_security_events >= 3 then 'elevated' else 'review' end;
    v_action := 'review_sessions';
    v_review := v_security_events >= 3;
    v_reasons := v_reasons || jsonb_build_array('recent_account_security_concern');
  end if;

  select count(*)::integer into v_expired_signals
  from public.trust_signal_events signal
  where signal.user_id = p_user_id
    and (
      signal.status = 'expired'
      or (signal.status = 'verified' and signal.expires_at is not null and signal.expires_at <= now())
    );

  if v_expired_signals > 0 then
    v_reasons := v_reasons || jsonb_build_array('trust_signal_expired');
    if v_level = 'low' then
      v_level := 'review';
      v_action := 'contact_support';
    end if;
  end if;

  if v_profile.is_test_account then
    v_reasons := v_reasons || jsonb_build_array('sandbox_test_account_isolated');
  end if;

  return jsonb_build_object(
    'risk_level', v_level,
    'risk_reasons', v_reasons,
    'recommended_action', v_action,
    'human_review_required', v_review
  );
end;
$$;

create or replace function private.refresh_account_trust_profile(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_environment public.verification_environment;
  v_risk jsonb;
begin
  if not exists (select 1 from public.profiles profile where profile.id = p_user_id) then
    return;
  end if;
  v_environment := private.user_trust_environment(p_user_id);
  v_risk := private.evaluate_account_risk(p_user_id);

  insert into public.account_trust_profiles (
    user_id,
    current_level,
    signal_environment,
    risk_level,
    risk_reasons,
    recommended_action,
    human_review_required,
    address_validation_status,
    calculated_at
  ) values (
    p_user_id,
    private.compute_account_trust_level(p_user_id),
    v_environment,
    v_risk->>'risk_level',
    v_risk->'risk_reasons',
    v_risk->>'recommended_action',
    coalesce((v_risk->>'human_review_required')::boolean, false),
    case when v_environment = 'sandbox' then 'sandbox_only' else 'unavailable' end,
    now()
  )
  on conflict (user_id) do update
  set current_level = excluded.current_level,
      signal_environment = excluded.signal_environment,
      risk_level = excluded.risk_level,
      risk_reasons = excluded.risk_reasons,
      recommended_action = excluded.recommended_action,
      human_review_required = excluded.human_review_required,
      address_validation_status = case
        when public.account_trust_profiles.address_validation_status in ('validated', 'pending', 'failed', 'expired')
          then public.account_trust_profiles.address_validation_status
        else excluded.address_validation_status
      end,
      calculated_at = now(),
      updated_at = now();
end;
$$;

create or replace function private.account_trust_refresh_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_record jsonb;
  v_column text := tg_argv[0];
  v_user_id uuid;
begin
  v_record := case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end;
  v_user_id := nullif(v_record->>v_column, '')::uuid;
  if v_user_id is not null then
    perform private.refresh_account_trust_profile(v_user_id);
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

create trigger trust_signal_refresh_account_profile
after insert or update or delete on public.trust_signal_events
for each row execute function private.account_trust_refresh_trigger('user_id');

create trigger account_security_preferences_refresh_account_profile
after insert or update or delete on public.account_security_preferences
for each row execute function private.account_trust_refresh_trigger('user_id');

create trigger identity_verification_refresh_account_profile
after insert or update or delete on public.identity_verifications
for each row execute function private.account_trust_refresh_trigger('user_id');

create trigger profile_restriction_refresh_account_profile
after insert or update of role, account_status, blocked_until, is_test_account on public.profiles
for each row execute function private.account_trust_refresh_trigger('id');

create or replace function private.trust_level_key(p_level smallint)
returns text
language sql
immutable
set search_path = ''
as $$
  select case p_level
    when 5 then 'TRUST_LEVEL_5'
    when 4 then 'TRUST_LEVEL_4'
    when 3 then 'TRUST_LEVEL_3'
    when 2 then 'TRUST_LEVEL_2'
    when 1 then 'TRUST_LEVEL_1'
    else 'TRUST_LEVEL_0'
  end;
$$;

create or replace function private.trust_level_title(p_level smallint)
returns text
language sql
immutable
set search_path = ''
as $$
  select case p_level
    when 5 then 'Enhanced adult screening'
    when 4 then 'Provider identity verified'
    when 3 then 'Government digital ID verified'
    when 2 then 'Affiliation verified'
    when 1 then 'Account secured'
    else 'Basic account'
  end;
$$;

create or replace function private.get_trust_indicators(
  p_user_id uuid,
  p_include_private boolean default false
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_indicators jsonb := '[]'::jsonb;
  v_email_verified boolean := false;
  v_phone_verified boolean := false;
  v_passkey_enabled boolean := false;
  v_device_reauth boolean := false;
  v_signal record;
  v_environment public.verification_environment := private.user_trust_environment(p_user_id);
begin
  select user_record.email_confirmed_at is not null,
         user_record.phone_confirmed_at is not null
  into v_email_verified, v_phone_verified
  from auth.users user_record
  where user_record.id = p_user_id;

  select exists (
    select 1 from auth.webauthn_credentials credential
    where credential.user_id = p_user_id
  ) into v_passkey_enabled;

  select coalesce(preference.device_reauthentication_enabled, false)
  into v_device_reauth
  from public.account_security_preferences preference
  where preference.user_id = p_user_id;
  v_device_reauth := coalesce(v_device_reauth, false);

  if v_email_verified then
    v_indicators := v_indicators || jsonb_build_array(jsonb_build_object(
      'key', 'email_verified',
      'category', 'contact',
      'label', 'Email verified',
      'status', 'verified',
      'what_was_checked', 'The account confirmed access to its email address through Supabase Auth.',
      'what_was_not_checked', 'Legal identity, age, address, school affiliation, and safety were not verified.',
      'checked_at', (select user_record.email_confirmed_at from auth.users user_record where user_record.id = p_user_id),
      'expires_at', null,
      'grants_marketplace_access', false,
      'does_not_guarantee_safety', true
    ));
  end if;

  if v_phone_verified then
    v_indicators := v_indicators || jsonb_build_array(jsonb_build_object(
      'key', 'phone_verified',
      'category', 'contact',
      'label', 'Phone verified',
      'status', 'verified',
      'what_was_checked', 'The account confirmed access to a phone number through Supabase Auth.',
      'what_was_not_checked', 'The number owner, legal identity, age, address, and safety were not verified.',
      'checked_at', (select user_record.phone_confirmed_at from auth.users user_record where user_record.id = p_user_id),
      'expires_at', null,
      'grants_marketplace_access', false,
      'does_not_guarantee_safety', true
    ));
  end if;

  if v_passkey_enabled then
    v_indicators := v_indicators || jsonb_build_array(jsonb_build_object(
      'key', 'passkey_enabled',
      'category', 'account_security',
      'label', 'Passkey enabled',
      'status', 'verified',
      'what_was_checked', 'Supabase Auth has a registered public passkey credential for this account.',
      'what_was_not_checked', 'The authenticator does not establish legal identity, age, address, or safety.',
      'checked_at', (select min(credential.created_at) from auth.webauthn_credentials credential where credential.user_id = p_user_id),
      'expires_at', null,
      'grants_marketplace_access', false,
      'does_not_guarantee_safety', true
    ));
  end if;

  if v_device_reauth then
    v_indicators := v_indicators || jsonb_build_array(jsonb_build_object(
      'key', 'device_reauthentication',
      'category', 'account_security',
      'label', 'Account secured with device authentication',
      'status', 'configured',
      'what_was_checked', 'The user enabled local device-owner authentication before sensitive MORT actions.',
      'what_was_not_checked', 'Face ID, Touch ID, or a device passcode does not verify legal identity, age, address, or safety.',
      'checked_at', (select preference.configured_at from public.account_security_preferences preference where preference.user_id = p_user_id),
      'expires_at', null,
      'grants_marketplace_access', false,
      'does_not_guarantee_safety', true
    ));
  end if;

  for v_signal in
    select distinct on (signal.signal_type)
      signal.*
    from public.trust_signal_events signal
    where signal.user_id = p_user_id
      and signal.environment = v_environment
      and (p_include_private or signal.public_visibility)
    order by signal.signal_type, signal.created_at desc
  loop
    v_indicators := v_indicators || jsonb_build_array(jsonb_build_object(
      'key', v_signal.signal_type,
      'category', v_signal.category,
      'label', case when v_signal.environment = 'sandbox' then 'TEST MODE: ' || v_signal.public_label else v_signal.public_label end,
      'status', case
        when v_signal.revoked_at is not null then 'revoked'
        when v_signal.expires_at is not null and v_signal.expires_at <= now() then 'expired'
        else v_signal.status
      end,
      'what_was_checked', v_signal.what_was_checked,
      'what_was_not_checked', v_signal.what_was_not_checked,
      'checked_at', v_signal.checked_at,
      'expires_at', v_signal.expires_at,
      'grants_marketplace_access', false,
      'does_not_guarantee_safety', true,
      'environment', v_signal.environment
    ));
  end loop;

  if v_environment = 'production'
     and private.has_current_production_identity(p_user_id) then
    v_indicators := v_indicators || jsonb_build_array((
      select jsonb_build_object(
        'key', 'provider_identity_verified',
        'category', 'provider_identity',
        'label', 'Provider identity verified',
        'status', 'verified',
        'what_was_checked', 'An approved production provider returned a current signed identity and age result.',
        'what_was_not_checked', 'Verification does not guarantee behavior, intent, or safety.',
        'checked_at', verification.verified_at,
        'expires_at', verification.expires_at,
        'grants_marketplace_access', false,
        'does_not_guarantee_safety', true,
        'environment', 'production'
      )
      from public.identity_verifications verification
      where verification.user_id = p_user_id
        and verification.environment = 'production'
        and verification.status = 'verified'
        and verification.verified_at is not null
        and (verification.expires_at is null or verification.expires_at > now())
      order by verification.verified_at desc
      limit 1
    ));
  end if;

  return v_indicators;
end;
$$;

revoke all on function private.current_trust_policy(),
  private.user_trust_environment(uuid),
  private.compute_account_trust_level(uuid),
  private.evaluate_account_risk(uuid),
  private.refresh_account_trust_profile(uuid),
  private.account_trust_refresh_trigger(),
  private.trust_level_key(smallint),
  private.trust_level_title(smallint),
  private.get_trust_indicators(uuid, boolean)
from public, anon, authenticated;

create or replace function private.marketplace_identity_level(p_user_id uuid)
returns smallint
language sql
stable
security definer
set search_path = ''
as $$
  select private.compute_account_trust_level(p_user_id);
$$;

create or replace function private.has_marketplace_identity(p_user_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_profile public.profiles%rowtype;
  v_policy private.trust_policy_versions%rowtype;
  v_required_level smallint;
  v_current_level smallint;
  v_is_business boolean := false;
begin
  select * into v_profile
  from public.profiles profile
  where profile.id = p_user_id;
  if v_profile.id is null or v_profile.account_status <> 'active'
     or (v_profile.blocked_until is not null and v_profile.blocked_until > now()) then
    return false;
  end if;

  if v_profile.role = 'admin' then
    return true;
  end if;

  if v_profile.is_test_account then
    return private.has_current_sandbox_identity(p_user_id);
  end if;

  select * into v_policy from private.current_trust_policy();
  if v_policy.id is null or not v_policy.production_marketplace_enabled then
    return false;
  end if;

  if cardinality(v_policy.pilot_account_allowlist) > 0
     and not (p_user_id = any(v_policy.pilot_account_allowlist)) then
    return false;
  end if;
  if v_policy.pilot_region is not null
     and upper(coalesce(v_profile.state, '')) <> upper(v_policy.pilot_region) then
    return false;
  end if;

  select exists (
    select 1 from public.adult_profiles adult
    where adult.user_id = p_user_id
      and nullif(btrim(adult.business_name), '') is not null
  ) into v_is_business;

  v_required_level := case
    when v_profile.role = 'teen' then v_policy.minimum_teen_trust_level
    when v_is_business then v_policy.minimum_business_trust_level
    else v_policy.minimum_adult_trust_level
  end;
  v_current_level := private.compute_account_trust_level(p_user_id);

  if v_current_level < v_required_level then
    return false;
  end if;
  if v_policy.require_provider_verification
     and not private.has_current_production_identity(p_user_id) then
    return false;
  end if;
  if v_policy.require_digital_government_id and not exists (
    select 1 from public.trust_signal_events signal
    where signal.user_id = p_user_id
      and signal.signal_type = 'digital_government_id'
      and signal.environment = 'production'
      and signal.status = 'verified'
      and signal.revoked_at is null
      and (signal.expires_at is null or signal.expires_at > now())
  ) then
    return false;
  end if;
  if v_policy.require_enhanced_adult_screening
     and v_profile.role in ('adult', 'guardian')
     and not exists (
       select 1 from public.trust_signal_events signal
       where signal.user_id = p_user_id
         and signal.signal_type = 'enhanced_adult_screening'
         and signal.environment = 'production'
         and signal.status = 'verified'
         and signal.revoked_at is null
         and (signal.expires_at is null or signal.expires_at > now())
     ) then
    return false;
  end if;
  if v_policy.require_business_registry_match and v_is_business and not exists (
    select 1 from public.trust_signal_events signal
    where signal.user_id = p_user_id
      and signal.signal_type = 'business_registry_match'
      and signal.environment = 'production'
      and signal.status = 'verified'
      and signal.revoked_at is null
      and (signal.expires_at is null or signal.expires_at > now())
  ) then
    return false;
  end if;

  return true;
end;
$$;

revoke all on function private.marketplace_identity_level(uuid),
  private.has_marketplace_identity(uuid)
from public, anon, authenticated;

create or replace function public.get_marketplace_trust_eligibility(
  p_action text default 'browse',
  p_job_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_profile public.profiles%rowtype;
  v_policy private.trust_policy_versions%rowtype;
  v_current_level smallint := 0;
  v_required_level smallint := 0;
  v_allowed boolean := false;
  v_is_business boolean := false;
  v_email_verified boolean := false;
  v_phone_verified boolean := false;
  v_missing jsonb := '[]'::jsonb;
  v_reasons jsonb := '[]'::jsonb;
  v_job_requires_guardian boolean := false;
  v_has_guardian boolean := false;
begin
  if p_action not in (
    'browse', 'publish_job', 'apply', 'accept_worker', 'message',
    'reveal_private_address', 'start_job', 'submit_proof', 'approve_proof',
    'complete_job', 'leave_review', 'add_trusted_worker', 'join_repeat_crew',
    'create_recurring_job'
  ) then
    return jsonb_build_object(
      'allowed', false,
      'required_level', 0,
      'current_level', 0,
      'missing_requirements', jsonb_build_array('supported_action'),
      'reason_codes', jsonb_build_array('unsupported_action'),
      'retry_after', null,
      'support_route', '/support/account-trust'
    );
  end if;

  if v_user_id is null then
    return jsonb_build_object(
      'allowed', false,
      'required_level', 0,
      'current_level', 0,
      'missing_requirements', jsonb_build_array('authenticated_account'),
      'reason_codes', jsonb_build_array('authentication_required'),
      'retry_after', null,
      'support_route', '/auth/sign-in'
    );
  end if;

  select * into v_profile
  from public.profiles profile
  where profile.id = v_user_id;
  select * into v_policy from private.current_trust_policy();
  if v_profile.id is null then
    return jsonb_build_object(
      'allowed', false,
      'required_level', 0,
      'current_level', 0,
      'missing_requirements', jsonb_build_array('completed_profile'),
      'reason_codes', jsonb_build_array('profile_not_found'),
      'retry_after', null,
      'support_route', '/support/account-trust'
    );
  end if;

  select user_record.email_confirmed_at is not null,
         user_record.phone_confirmed_at is not null
  into v_email_verified, v_phone_verified
  from auth.users user_record
  where user_record.id = v_user_id;
  select exists (
    select 1 from public.adult_profiles adult
    where adult.user_id = v_user_id
      and nullif(btrim(adult.business_name), '') is not null
  ) into v_is_business;

  v_current_level := private.compute_account_trust_level(v_user_id);
  v_required_level := case
    when v_profile.role = 'admin' then 0
    when v_profile.role = 'teen' then v_policy.minimum_teen_trust_level
    when v_is_business then v_policy.minimum_business_trust_level
    else v_policy.minimum_adult_trust_level
  end;

  if v_profile.account_status <> 'active'
     or (v_profile.blocked_until is not null and v_profile.blocked_until > now()) then
    v_missing := v_missing || jsonb_build_array('active_account');
    v_reasons := v_reasons || jsonb_build_array('account_restricted');
  end if;

  if not v_email_verified then
    v_missing := v_missing || jsonb_build_array('confirmed_email');
    v_reasons := v_reasons || jsonb_build_array('email_not_verified');
  end if;
  if v_policy.phone_verification_available and not v_phone_verified then
    v_missing := v_missing || jsonb_build_array('confirmed_phone');
    v_reasons := v_reasons || jsonb_build_array('phone_not_verified');
  end if;

  if p_job_id is not null and v_profile.role = 'teen' then
    select coalesce(job.requires_guardian_approval, false)
    into v_job_requires_guardian
    from public.jobs job
    where job.id = p_job_id;
    if v_job_requires_guardian then
      select exists (
        select 1 from public.guardian_connections connection
        where connection.teen_id = v_user_id
          and connection.status = 'active'
      ) into v_has_guardian;
      if not v_has_guardian then
        v_missing := v_missing || jsonb_build_array('guardian_for_this_specific_job');
        v_reasons := v_reasons || jsonb_build_array('specific_job_guardian_requirement');
      end if;
    else
      v_reasons := v_reasons || jsonb_build_array('guardian_not_required');
    end if;
  else
    v_reasons := v_reasons || jsonb_build_array('guardian_not_required');
  end if;

  if v_profile.is_test_account then
    v_allowed := private.has_current_sandbox_identity(v_user_id)
      and v_profile.account_status = 'active'
      and (not v_job_requires_guardian or v_has_guardian);
    v_reasons := v_reasons || jsonb_build_array('sandbox_account_only');
    if not private.has_current_sandbox_identity(v_user_id) then
      v_missing := v_missing || jsonb_build_array('current_sandbox_qa_verification');
      v_reasons := v_reasons || jsonb_build_array('identity_verification_unavailable');
    end if;
  elsif not v_policy.production_marketplace_enabled then
    v_allowed := false;
    v_missing := v_missing || jsonb_build_array('approved_production_marketplace_policy');
    v_reasons := v_reasons || jsonb_build_array('production_marketplace_closed');
    if v_policy.require_provider_verification
       and not private.has_current_production_identity(v_user_id) then
      v_missing := v_missing || jsonb_build_array('current_provider_identity_verification');
      v_reasons := v_reasons || jsonb_build_array('identity_verification_unavailable');
    end if;
  else
    v_allowed := private.has_marketplace_identity(v_user_id)
      and (not v_job_requires_guardian or v_has_guardian);
    if v_current_level < v_required_level then
      v_missing := v_missing || jsonb_build_array('trust_level_' || v_required_level::text);
      v_reasons := v_reasons || jsonb_build_array('account_security_incomplete');
    end if;
    if v_is_business and v_policy.require_business_registry_match and not exists (
      select 1 from public.trust_signal_events signal
      where signal.user_id = v_user_id
        and signal.signal_type = 'business_registry_match'
        and signal.environment = 'production'
        and signal.status = 'verified'
        and signal.revoked_at is null
        and (signal.expires_at is null or signal.expires_at > now())
    ) then
      v_missing := v_missing || jsonb_build_array('current_business_registry_match');
      v_reasons := v_reasons || jsonb_build_array('business_registry_unmatched');
    end if;
  end if;

  if v_profile.role = 'admin' and v_profile.account_status = 'active' then
    v_allowed := true;
  end if;

  return jsonb_build_object(
    'allowed', v_allowed,
    'action', p_action,
    'required_level', v_required_level,
    'current_level', v_current_level,
    'missing_requirements', v_missing,
    'reason_codes', v_reasons,
    'retry_after', null,
    'support_route', '/support/account-trust',
    'policy_version', v_policy.version,
    'production_marketplace_enabled', v_policy.production_marketplace_enabled,
    'guardian_mode_optional', true,
    'test_mode', v_profile.is_test_account
  );
end;
$$;

create or replace function public.get_my_account_trust_profile()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_profile public.profiles%rowtype;
  v_trust public.account_trust_profiles%rowtype;
  v_policy private.trust_policy_versions%rowtype;
  v_email_verified boolean := false;
  v_phone_verified boolean := false;
  v_passkey_count integer := 0;
  v_completed_jobs integer := 0;
  v_review_count integer := 0;
  v_identity_status text := 'not_identity_verified';
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  select * into v_profile from public.profiles profile where profile.id = v_user_id;
  if v_profile.id is null then
    return jsonb_build_object('ok', false, 'code', 'profile_not_found');
  end if;

  perform private.refresh_account_trust_profile(v_user_id);
  select * into v_trust from public.account_trust_profiles trust where trust.user_id = v_user_id;
  select * into v_policy from private.current_trust_policy();
  select user_record.email_confirmed_at is not null,
         user_record.phone_confirmed_at is not null
  into v_email_verified, v_phone_verified
  from auth.users user_record where user_record.id = v_user_id;
  select count(*)::integer into v_passkey_count
  from auth.webauthn_credentials credential where credential.user_id = v_user_id;

  select count(*)::integer into v_completed_jobs
  from public.applications application
  join public.jobs job on job.id = application.job_id
  where application.status = 'completed'
    and (application.teen_id = v_user_id or job.poster_id = v_user_id);
  select count(*)::integer into v_review_count
  from public.reviews review
  where review.subject_id = v_user_id
    and review.moderation_status in ('approved', 'visible');

  if private.has_current_production_identity(v_user_id) then
    v_identity_status := 'provider_identity_verified';
  elsif v_profile.is_test_account and private.has_current_sandbox_identity(v_user_id) then
    v_identity_status := 'sandbox_qa_only_not_production_verified';
  end if;

  return jsonb_build_object(
    'ok', true,
    'current_level', v_trust.current_level,
    'level_key', private.trust_level_key(v_trust.current_level),
    'level_title', private.trust_level_title(v_trust.current_level),
    'signal_environment', v_trust.signal_environment,
    'indicators', private.get_trust_indicators(v_user_id, true),
    'contact_status', jsonb_build_object(
      'email_verified', v_email_verified,
      'phone_verified', v_phone_verified,
      'phone_verification_available', v_policy.phone_verification_available,
      'email_or_phone_is_legal_identity', false
    ),
    'account_security', jsonb_build_object(
      'passkey_count', v_passkey_count,
      'passkeys_enabled_by_server', v_policy.passkeys_enabled,
      'device_biometrics_are_local_account_security_only', true,
      'suspicious_session_monitoring_enabled', true
    ),
    'identity_status', v_identity_status,
    'marketplace_eligibility', public.get_marketplace_trust_eligibility('browse', null),
    'risk_profile', jsonb_build_object(
      'risk_level', v_trust.risk_level,
      'risk_reasons', v_trust.risk_reasons,
      'recommended_action', v_trust.recommended_action,
      'human_review_required', v_trust.human_review_required,
      'not_a_criminal_accusation', true
    ),
    'work_history', jsonb_build_object(
      'completed_jobs', v_completed_jobs,
      'reviews', v_review_count,
      'separate_from_identity', true
    ),
    'availability', jsonb_build_object(
      'production_marketplace_enabled', v_policy.production_marketplace_enabled,
      'identity_document_collection_enabled', v_policy.identity_document_collection_enabled,
      'provider_identity_available', private.production_identity_ready(),
      'apple_wallet_enabled', v_policy.apple_wallet_enabled,
      'android_digital_credentials_enabled', v_policy.android_digital_credentials_enabled,
      'manual_affiliation_evidence_collection_enabled', false
    ),
    'guardian_mode_optional', true,
    'school_name_public_by_default', false,
    'residential_address_public', false,
    'email_or_phone_public', false,
    'people_search_used', false,
    'safety_guarantee', false,
    'policy_version', v_policy.version,
    'calculated_at', v_trust.calculated_at
  );
end;
$$;

create or replace function public.get_public_trust_badges(p_user_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_caller public.profiles%rowtype;
  v_subject public.profiles%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  select * into v_caller from public.profiles profile where profile.id = auth.uid();
  select * into v_subject from public.profiles profile where profile.id = p_user_id;
  if v_caller.id is null or v_subject.id is null or v_subject.account_status = 'banned' then
    return jsonb_build_object('ok', false, 'code', 'profile_not_found');
  end if;
  if v_caller.role <> 'admin' and v_caller.is_test_account <> v_subject.is_test_account then
    return jsonb_build_object('ok', false, 'code', 'profile_not_found');
  end if;

  return jsonb_build_object(
    'ok', true,
    'badges', private.get_trust_indicators(p_user_id, auth.uid() = p_user_id),
    'account_restricted', v_subject.account_status <> 'active'
      or (v_subject.blocked_until is not null and v_subject.blocked_until > now()),
    'school_name_exposed', false,
    'residential_address_exposed', false,
    'email_or_phone_exposed', false,
    'verification_guarantees_safety', false
  );
end;
$$;

create or replace function public.update_account_security_preferences(
  p_device_reauthentication_enabled boolean,
  p_lock_after_minutes smallint default 15
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_preference public.account_security_preferences%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_lock_after_minutes not between 1 and 240 then
    return jsonb_build_object('ok', false, 'code', 'invalid_lock_timeout');
  end if;

  insert into public.account_security_preferences (
    user_id,
    device_reauthentication_enabled,
    lock_after_minutes,
    configured_at
  ) values (
    auth.uid(),
    p_device_reauthentication_enabled,
    p_lock_after_minutes,
    case when p_device_reauthentication_enabled then now() else null end
  )
  on conflict (user_id) do update
  set device_reauthentication_enabled = excluded.device_reauthentication_enabled,
      lock_after_minutes = excluded.lock_after_minutes,
      configured_at = excluded.configured_at,
      updated_at = now()
  returning * into v_preference;

  return jsonb_build_object(
    'ok', true,
    'device_reauthentication_enabled', v_preference.device_reauthentication_enabled,
    'lock_after_minutes', v_preference.lock_after_minutes,
    'identity_verified', false,
    'biometric_material_stored', false,
    'message', 'Device authentication protects this MORT account on this device. It does not verify legal identity.'
  );
end;
$$;

create or replace function public.set_trust_signal_visibility(
  p_signal_type text,
  p_visible boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_signal public.trust_signal_events%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_signal_type not in ('school_affiliation', 'program_affiliation', 'business_registry_match') then
    return jsonb_build_object('ok', false, 'code', 'visibility_not_user_configurable');
  end if;

  update public.trust_signal_events signal
  set public_visibility = p_visible,
      updated_at = now()
  where signal.id = (
    select candidate.id
    from public.trust_signal_events candidate
    where candidate.user_id = auth.uid()
      and candidate.signal_type = p_signal_type
      and candidate.status = 'verified'
      and candidate.revoked_at is null
    order by candidate.created_at desc
    limit 1
  )
  returning * into v_signal;

  if v_signal.id is null then
    return jsonb_build_object('ok', false, 'code', 'trust_signal_not_found');
  end if;
  return jsonb_build_object(
    'ok', true,
    'signal_type', v_signal.signal_type,
    'public_visibility', v_signal.public_visibility,
    'organization_name_public', false
  );
end;
$$;

create or replace function public.submit_account_trust_appeal(
  p_reason text,
  p_signal_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_appeal public.account_trust_appeals%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if char_length(btrim(coalesce(p_reason, ''))) not between 20 and 2000 then
    return jsonb_build_object('ok', false, 'code', 'appeal_reason_length_invalid');
  end if;
  if p_signal_id is not null and not exists (
    select 1 from public.trust_signal_events signal
    where signal.id = p_signal_id and signal.user_id = auth.uid()
  ) then
    return jsonb_build_object('ok', false, 'code', 'trust_signal_not_found');
  end if;

  insert into public.account_trust_appeals (user_id, signal_id, reason)
  values (auth.uid(), p_signal_id, btrim(p_reason))
  returning * into v_appeal;

  return jsonb_build_object(
    'ok', true,
    'appeal_id', v_appeal.id,
    'status', v_appeal.status,
    'marketplace_access_restored', false
  );
end;
$$;

create or replace function public.request_school_email_affiliation(
  p_school_email text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile public.profiles%rowtype;
  v_policy private.trust_policy_versions%rowtype;
  v_auth_email text;
  v_email_confirmed boolean := false;
  v_domain text;
  v_environment public.verification_environment;
  v_school public.school_domains%rowtype;
  v_request public.partner_verification_requests%rowtype;
  v_signal public.trust_signal_events%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  select * into v_profile from public.profiles profile where profile.id = auth.uid();
  if v_profile.id is null or v_profile.role <> 'teen' then
    return jsonb_build_object('ok', false, 'code', 'teen_account_required');
  end if;
  select * into v_policy from private.current_trust_policy();
  if not v_policy.school_affiliation_enabled then
    return jsonb_build_object('ok', false, 'code', 'school_affiliation_disabled');
  end if;

  select lower(user_record.email), user_record.email_confirmed_at is not null
  into v_auth_email, v_email_confirmed
  from auth.users user_record
  where user_record.id = auth.uid();
  if not v_email_confirmed then
    return jsonb_build_object('ok', false, 'code', 'email_not_verified');
  end if;
  if lower(btrim(coalesce(p_school_email, ''))) <> v_auth_email then
    return jsonb_build_object(
      'ok', false,
      'code', 'school_email_must_match_confirmed_account_email',
      'message', 'A separate school-email verification link is not available yet. No affiliation was granted.'
    );
  end if;

  v_domain := lower(split_part(v_auth_email, '@', 2));
  if v_domain = '' then
    return jsonb_build_object('ok', false, 'code', 'invalid_email_domain');
  end if;
  v_environment := private.user_trust_environment(auth.uid());

  select * into v_school
  from public.school_domains school
  where school.normalized_domain = v_domain
    and school.environment = v_environment
    and school.status = 'approved'
    and (school.expires_at is null or school.expires_at > now())
  order by school.approved_at desc
  limit 1;

  if v_school.id is null then
    insert into public.partner_verification_requests (
      user_id, request_type, requested_domain, status, environment
    ) values (
      auth.uid(), 'school_email', v_domain, 'pending_domain_review', v_environment
    ) returning * into v_request;
    return jsonb_build_object(
      'ok', true,
      'status', v_request.status,
      'request_id', v_request.id,
      'affiliation_verified', false,
      'identity_verified', false,
      'message', 'The domain is pending manual approval. No school affiliation or identity badge was granted.'
    );
  end if;

  select * into v_signal
  from public.trust_signal_events signal
  where signal.user_id = auth.uid()
    and signal.signal_type = 'school_affiliation'
    and signal.source_reference = v_school.id::text
    and signal.environment = v_environment
    and signal.status = 'verified'
    and signal.revoked_at is null
    and (signal.expires_at is null or signal.expires_at > now())
  order by signal.created_at desc
  limit 1;

  if v_signal.id is null then
    insert into public.trust_signal_events (
      user_id, signal_type, category, status, environment, source_kind,
      source_reference, public_label, what_was_checked, what_was_not_checked,
      checked_at, expires_at, public_visibility, grants_marketplace_access,
      metadata
    ) values (
      auth.uid(),
      'school_affiliation',
      'affiliation',
      'verified',
      v_environment,
      'school_domain',
      v_school.id::text,
      'School affiliation verified',
      'The confirmed account email uses an approved school or program domain.',
      'No government ID, legal name, age record, school roster, residential address, or safety guarantee was checked.',
      now(),
      coalesce(v_school.expires_at, now() + interval '1 year'),
      false,
      false,
      jsonb_build_object('domain_record_id', v_school.id, 'school_name_public', false)
    ) returning * into v_signal;
  end if;

  insert into public.partner_verification_requests (
    user_id, request_type, requested_domain, status, environment, reviewed_at,
    decision_reason
  ) values (
    auth.uid(), 'school_email', v_domain, 'verified', v_environment, now(),
    'Confirmed account email matched an approved domain record.'
  ) returning * into v_request;

  return jsonb_build_object(
    'ok', true,
    'status', 'verified',
    'request_id', v_request.id,
    'signal_id', v_signal.id,
    'affiliation_verified', true,
    'identity_verified', false,
    'government_id_verified', false,
    'school_name_public', false,
    'grants_marketplace_access', false,
    'message', 'School affiliation verification confirms access to an approved school or program account. It does not equal government ID verification.'
  );
end;
$$;

create or replace function public.redeem_partner_invite_code(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile public.profiles%rowtype;
  v_policy private.trust_policy_versions%rowtype;
  v_code public.partner_invite_codes%rowtype;
  v_org public.partner_organizations%rowtype;
  v_program public.partner_programs%rowtype;
  v_membership public.partner_memberships%rowtype;
  v_signal_type text;
  v_public_label text;
  v_expiry timestamptz;
  v_method text;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  select * into v_profile from public.profiles profile where profile.id = auth.uid();
  if v_profile.id is null or v_profile.role <> 'teen' then
    return jsonb_build_object('ok', false, 'code', 'teen_account_required');
  end if;
  select * into v_policy from private.current_trust_policy();
  if not v_policy.partner_codes_enabled then
    return jsonb_build_object('ok', false, 'code', 'partner_codes_disabled');
  end if;
  if char_length(btrim(coalesce(p_code, ''))) not between 12 and 100 then
    return jsonb_build_object('ok', false, 'code', 'partner_code_invalid');
  end if;

  select * into v_code
  from public.partner_invite_codes code
  where code.code_hash = extensions.digest(convert_to(upper(btrim(p_code)), 'UTF8'), 'sha256')
  for update;
  if v_code.id is null or v_code.revoked_at is not null
     or v_code.expires_at <= now() or v_code.use_count >= v_code.max_uses then
    return jsonb_build_object('ok', false, 'code', 'partner_code_invalid_or_expired');
  end if;

  select * into v_org from public.partner_organizations organization
  where organization.id = v_code.organization_id;
  if v_org.id is null or v_org.status <> 'verified'
     or (v_org.expires_at is not null and v_org.expires_at <= now()) then
    return jsonb_build_object('ok', false, 'code', 'partner_organization_unavailable');
  end if;
  if v_org.environment <> private.user_trust_environment(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'partner_environment_mismatch');
  end if;

  if v_code.program_id is not null then
    select * into v_program from public.partner_programs program
    where program.id = v_code.program_id
      and program.organization_id = v_org.id
      and program.status = 'active'
      and (program.ends_at is null or program.ends_at > now());
    if v_program.id is null then
      return jsonb_build_object('ok', false, 'code', 'partner_program_unavailable');
    end if;
  end if;

  select * into v_membership
  from public.partner_memberships membership
  where membership.user_id = auth.uid()
    and membership.organization_id = v_org.id
    and membership.program_id is not distinct from v_code.program_id
    and membership.status = 'active'
    and membership.revoked_at is null
    and membership.expires_at > now()
  order by membership.created_at desc
  limit 1;
  if v_membership.id is not null then
    return jsonb_build_object(
      'ok', true,
      'status', 'already_redeemed',
      'membership_id', v_membership.id,
      'affiliation_verified', true,
      'identity_verified', false,
      'grants_marketplace_access', false
    );
  end if;

  v_expiry := least(
    v_code.expires_at,
    coalesce(v_org.expires_at, v_code.expires_at),
    coalesce(v_program.ends_at, v_code.expires_at)
  );
  v_signal_type := case
    when v_org.organization_type in ('school', 'online_school', 'vocational_program') then 'school_affiliation'
    else 'program_affiliation'
  end;
  v_public_label := case when v_signal_type = 'school_affiliation'
    then 'School affiliation verified' else 'Program affiliation verified' end;
  v_method := case when v_org.organization_type in ('school', 'online_school')
    then 'partner_code' else 'program_code' end;

  insert into public.partner_memberships (
    user_id, organization_id, program_id, verification_method, expires_at
  ) values (
    auth.uid(), v_org.id, v_program.id, v_method, v_expiry
  ) returning * into v_membership;
  update public.partner_invite_codes
  set use_count = use_count + 1
  where id = v_code.id;

  insert into public.trust_signal_events (
    user_id, signal_type, category, status, environment, source_kind,
    source_reference, public_label, what_was_checked, what_was_not_checked,
    checked_at, expires_at, public_visibility, grants_marketplace_access, metadata
  ) values (
    auth.uid(), v_signal_type, 'affiliation', 'verified', v_org.environment,
    'partner_code', v_membership.id::text, v_public_label,
    'A current limited-use code from an admin-approved partner organization was redeemed.',
    'The code did not verify government identity, legal name, age, residential address, or safety.',
    now(), v_membership.expires_at, false, false,
    jsonb_build_object('membership_id', v_membership.id, 'organization_name_public', false)
  );

  insert into public.partner_verification_requests (
    user_id, request_type, organization_id, program_id, status,
    environment, reviewed_at, decision_reason
  ) values (
    auth.uid(),
    case when v_org.organization_type in ('school', 'online_school') then 'school_partner_code' else 'youth_program_code' end,
    v_org.id, v_program.id, 'verified', v_org.environment, now(),
    'Redeemed a valid hashed, limited-use partner invitation code.'
  );
  insert into public.partner_audit_events (
    actor_id, action, resource_type, resource_id, access_reason, event_data
  ) values (
    auth.uid(), 'partner_code_redeemed', 'partner_membership', v_membership.id,
    'User redeemed a hashed partner invitation code.',
    jsonb_build_object('organization_id', v_org.id, 'program_id', v_program.id)
  );

  return jsonb_build_object(
    'ok', true,
    'status', 'verified',
    'membership_id', v_membership.id,
    'affiliation_verified', true,
    'identity_verified', false,
    'government_id_verified', false,
    'organization_name_public', false,
    'grants_marketplace_access', false,
    'expires_at', v_membership.expires_at,
    'message', 'Partner affiliation was confirmed. Affiliation does not equal legal identity verification.'
  );
end;
$$;

create or replace function public.request_business_registry_match(
  p_jurisdiction text,
  p_legal_business_name text,
  p_registration_number text,
  p_entity_type text,
  p_official_source_url text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile public.profiles%rowtype;
  v_policy private.trust_policy_versions%rowtype;
  v_host text;
  v_check public.business_registry_checks%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  select * into v_profile from public.profiles profile where profile.id = auth.uid();
  if v_profile.id is null or v_profile.role <> 'adult' or v_profile.account_status <> 'active' then
    return jsonb_build_object('ok', false, 'code', 'active_adult_account_required');
  end if;
  select * into v_policy from private.current_trust_policy();
  if not v_policy.business_registry_manual_review_enabled then
    return jsonb_build_object('ok', false, 'code', 'business_registry_review_disabled');
  end if;
  if char_length(btrim(coalesce(p_legal_business_name, ''))) not between 2 and 200
     or char_length(btrim(coalesce(p_registration_number, ''))) not between 2 and 100
     or char_length(btrim(coalesce(p_jurisdiction, ''))) not between 2 and 30 then
    return jsonb_build_object('ok', false, 'code', 'business_registry_fields_invalid');
  end if;

  v_host := lower(substring(btrim(coalesce(p_official_source_url, '')) from '^https://([^/:?#]+)'));
  if v_host is null or not exists (
    select 1 from public.official_source_allowlist source
    where source.hostname = v_host
      and source.source_category = 'business_registry'
      and source.jurisdiction = upper(btrim(p_jurisdiction))
      and source.manual_review_allowed
  ) then
    return jsonb_build_object(
      'ok', false,
      'code', 'official_source_not_allowed',
      'message', 'MORT accepts only an approved official registry source. People-search and data-broker sources are rejected.'
    );
  end if;

  select * into v_check
  from public.business_registry_checks registry
  where registry.user_id = auth.uid()
    and registry.jurisdiction = upper(btrim(p_jurisdiction))
    and registry.registration_number = upper(btrim(p_registration_number))
    and registry.status in ('pending_manual_review', 'appealed')
  order by registry.created_at desc
  limit 1;
  if v_check.id is null then
    insert into public.business_registry_checks (
      user_id, jurisdiction, legal_business_name, registration_number,
      entity_type, official_source_url, official_source_host
    ) values (
      auth.uid(), upper(btrim(p_jurisdiction)), btrim(p_legal_business_name),
      upper(btrim(p_registration_number)), nullif(btrim(coalesce(p_entity_type, '')), ''),
      btrim(p_official_source_url), v_host
    ) returning * into v_check;
  end if;

  return jsonb_build_object(
    'ok', true,
    'check_id', v_check.id,
    'status', v_check.status,
    'manual_review_required', true,
    'automated_scraping_used', false,
    'business_record_matched', false,
    'representative_identity_verified', false,
    'grants_marketplace_access', false,
    'message', 'Business registration matching confirms that a public business record exists. It does not prove the account holder owns the business.'
  );
end;
$$;

create or replace function public.request_business_representative_claim(
  p_business_registry_check_id uuid,
  p_relationship_type text,
  p_attested boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_check public.business_registry_checks%rowtype;
  v_claim public.business_representative_claims%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  select * into v_check from public.business_registry_checks registry
  where registry.id = p_business_registry_check_id and registry.user_id = auth.uid();
  if v_check.id is null then
    return jsonb_build_object('ok', false, 'code', 'business_registry_check_not_found');
  end if;
  if p_relationship_type not in ('owner', 'officer', 'employee', 'authorized_agent', 'other') or not p_attested then
    return jsonb_build_object('ok', false, 'code', 'representative_attestation_required');
  end if;

  insert into public.business_representative_claims (
    user_id, business_registry_check_id, relationship_type, attested
  ) values (
    auth.uid(), p_business_registry_check_id, p_relationship_type, true
  )
  on conflict (user_id, business_registry_check_id) do update
  set relationship_type = excluded.relationship_type,
      attested = true,
      status = 'pending_future_verification',
      reviewed_by = null,
      reviewed_at = null,
      decision_reason = null,
      updated_at = now()
  returning * into v_claim;

  return jsonb_build_object(
    'ok', true,
    'claim_id', v_claim.id,
    'status', v_claim.status,
    'representative_identity_verified', false,
    'provider_required', true,
    'grants_marketplace_access', false,
    'message', 'The representative claim is recorded but not verified. A registry match alone does not prove authority to act for the business.'
  );
end;
$$;

create or replace function private.trust_admin_context_valid(
  p_access_reason text,
  p_case_id text
)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select char_length(btrim(coalesce(p_access_reason, ''))) between 12 and 800
    and char_length(btrim(coalesce(p_case_id, ''))) between 4 and 100;
$$;

create or replace function public.admin_review_school_domain(
  p_domain text,
  p_organization_name text,
  p_organization_type text,
  p_environment public.verification_environment,
  p_official_source_url text,
  p_approve boolean,
  p_access_reason text,
  p_case_id text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_domain public.school_domains%rowtype;
begin
  if auth.uid() is null or not private.has_trust_admin_role(
    auth.uid(), array['affiliation_reviewer']::text[]
  ) then
    return jsonb_build_object('ok', false, 'code', 'affiliation_reviewer_required');
  end if;
  if not private.trust_admin_context_valid(p_access_reason, p_case_id) then
    return jsonb_build_object('ok', false, 'code', 'admin_access_reason_and_case_required');
  end if;
  if lower(btrim(coalesce(p_domain, ''))) !~ '^[a-z0-9.-]+\.[a-z]{2,}$'
     or p_organization_type not in ('school', 'online_school', 'vocational_program')
     or char_length(btrim(coalesce(p_organization_name, ''))) not between 2 and 200 then
    return jsonb_build_object('ok', false, 'code', 'school_domain_fields_invalid');
  end if;
  if p_approve and btrim(coalesce(p_official_source_url, '')) !~ '^https://' then
    return jsonb_build_object('ok', false, 'code', 'official_source_required');
  end if;

  insert into public.school_domains (
    normalized_domain, organization_name, organization_type, status,
    environment, official_source_url, approved_by, approved_at, expires_at
  ) values (
    lower(btrim(p_domain)), btrim(p_organization_name), p_organization_type,
    case when p_approve then 'approved' else 'rejected' end,
    p_environment, nullif(btrim(coalesce(p_official_source_url, '')), ''),
    auth.uid(), case when p_approve then now() else null end,
    case when p_approve then now() + interval '1 year' else null end
  )
  on conflict (normalized_domain, environment) do update
  set organization_name = excluded.organization_name,
      organization_type = excluded.organization_type,
      status = excluded.status,
      official_source_url = excluded.official_source_url,
      approved_by = excluded.approved_by,
      approved_at = excluded.approved_at,
      expires_at = excluded.expires_at,
      public_directory_enabled = false,
      updated_at = now()
  returning * into v_domain;

  insert into public.partner_audit_events (
    actor_id, action, resource_type, resource_id, access_reason, case_id, event_data
  ) values (
    auth.uid(), case when p_approve then 'school_domain_approved' else 'school_domain_rejected' end,
    'school_domain', v_domain.id, btrim(p_access_reason), btrim(p_case_id),
    jsonb_build_object('environment', p_environment, 'domain', v_domain.normalized_domain)
  );

  return jsonb_build_object(
    'ok', true,
    'domain_id', v_domain.id,
    'status', v_domain.status,
    'public_directory_enabled', false
  );
end;
$$;

create or replace function public.admin_create_partner_organization(
  p_organization_type text,
  p_legal_name text,
  p_display_name text,
  p_environment public.verification_environment,
  p_official_directory_url text,
  p_access_reason text,
  p_case_id text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org public.partner_organizations%rowtype;
begin
  if auth.uid() is null or not private.has_trust_admin_role(
    auth.uid(), array['affiliation_reviewer']::text[]
  ) then
    return jsonb_build_object('ok', false, 'code', 'affiliation_reviewer_required');
  end if;
  if not private.trust_admin_context_valid(p_access_reason, p_case_id) then
    return jsonb_build_object('ok', false, 'code', 'admin_access_reason_and_case_required');
  end if;
  if p_organization_type not in (
    'school', 'online_school', 'vocational_program', 'nonprofit',
    'youth_program', 'community_center', 'workforce_program'
  ) or char_length(btrim(coalesce(p_legal_name, ''))) not between 2 and 200
    or char_length(btrim(coalesce(p_display_name, ''))) not between 2 and 120 then
    return jsonb_build_object('ok', false, 'code', 'partner_organization_fields_invalid');
  end if;

  insert into public.partner_organizations (
    organization_type, legal_name, display_name, status, environment,
    official_directory_url
  ) values (
    p_organization_type, btrim(p_legal_name), btrim(p_display_name), 'pending',
    p_environment, nullif(btrim(coalesce(p_official_directory_url, '')), '')
  ) returning * into v_org;
  insert into public.partner_audit_events (
    actor_id, action, resource_type, resource_id, access_reason, case_id, event_data
  ) values (
    auth.uid(), 'partner_organization_created', 'partner_organization', v_org.id,
    btrim(p_access_reason), btrim(p_case_id), jsonb_build_object('environment', p_environment)
  );
  return jsonb_build_object('ok', true, 'organization_id', v_org.id, 'status', v_org.status);
end;
$$;

create or replace function public.admin_review_partner_organization(
  p_organization_id uuid,
  p_approve boolean,
  p_access_reason text,
  p_case_id text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org public.partner_organizations%rowtype;
begin
  if auth.uid() is null or not private.has_trust_admin_role(
    auth.uid(), array['affiliation_reviewer']::text[]
  ) then
    return jsonb_build_object('ok', false, 'code', 'affiliation_reviewer_required');
  end if;
  if not private.trust_admin_context_valid(p_access_reason, p_case_id) then
    return jsonb_build_object('ok', false, 'code', 'admin_access_reason_and_case_required');
  end if;
  update public.partner_organizations organization
  set status = case when p_approve then 'verified' else 'rejected' end,
      verified_by = case when p_approve then auth.uid() else null end,
      verified_at = case when p_approve then now() else null end,
      expires_at = case when p_approve then now() + interval '1 year' else null end,
      updated_at = now()
  where organization.id = p_organization_id
  returning * into v_org;
  if v_org.id is null then
    return jsonb_build_object('ok', false, 'code', 'partner_organization_not_found');
  end if;
  insert into public.partner_audit_events (
    actor_id, action, resource_type, resource_id, access_reason, case_id, event_data
  ) values (
    auth.uid(), case when p_approve then 'partner_organization_approved' else 'partner_organization_rejected' end,
    'partner_organization', v_org.id, btrim(p_access_reason), btrim(p_case_id),
    jsonb_build_object('environment', v_org.environment)
  );
  return jsonb_build_object('ok', true, 'organization_id', v_org.id, 'status', v_org.status);
end;
$$;

create or replace function public.admin_create_partner_invite_code(
  p_organization_id uuid,
  p_program_id uuid,
  p_expires_at timestamptz,
  p_max_uses integer,
  p_access_reason text,
  p_case_id text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org public.partner_organizations%rowtype;
  v_code_id uuid;
  v_raw_code text;
begin
  if auth.uid() is null or not private.has_trust_admin_role(
    auth.uid(), array['affiliation_reviewer']::text[]
  ) then
    return jsonb_build_object('ok', false, 'code', 'affiliation_reviewer_required');
  end if;
  if not private.trust_admin_context_valid(p_access_reason, p_case_id) then
    return jsonb_build_object('ok', false, 'code', 'admin_access_reason_and_case_required');
  end if;
  select * into v_org from public.partner_organizations organization
  where organization.id = p_organization_id
    and organization.status = 'verified'
    and (organization.expires_at is null or organization.expires_at > now());
  if v_org.id is null then
    return jsonb_build_object('ok', false, 'code', 'verified_partner_organization_required');
  end if;
  if p_program_id is not null and not exists (
    select 1 from public.partner_programs program
    where program.id = p_program_id
      and program.organization_id = p_organization_id
      and program.status = 'active'
  ) then
    return jsonb_build_object('ok', false, 'code', 'active_partner_program_required');
  end if;
  if p_expires_at <= now() + interval '1 hour'
     or p_expires_at > now() + interval '1 year'
     or p_max_uses not between 1 and 10000 then
    return jsonb_build_object('ok', false, 'code', 'partner_code_limits_invalid');
  end if;

  v_raw_code := 'MORT-' || upper(encode(extensions.gen_random_bytes(16), 'hex'));
  insert into public.partner_invite_codes (
    organization_id, program_id, code_hash, code_prefix,
    max_uses, expires_at, created_by
  ) values (
    p_organization_id, p_program_id,
    extensions.digest(convert_to(v_raw_code, 'UTF8'), 'sha256'),
    left(v_raw_code, 10), p_max_uses, p_expires_at, auth.uid()
  ) returning id into v_code_id;
  insert into public.partner_audit_events (
    actor_id, action, resource_type, resource_id, access_reason, case_id, event_data
  ) values (
    auth.uid(), 'partner_invite_code_created', 'partner_invite_code', v_code_id,
    btrim(p_access_reason), btrim(p_case_id),
    jsonb_build_object('organization_id', p_organization_id, 'program_id', p_program_id, 'max_uses', p_max_uses)
  );
  return jsonb_build_object(
    'ok', true,
    'code_id', v_code_id,
    'invite_code', v_raw_code,
    'shown_once', true,
    'stored_as_hash_only', true,
    'expires_at', p_expires_at
  );
end;
$$;

create or replace function public.admin_review_business_registry_match(
  p_check_id uuid,
  p_decision text,
  p_match_confidence numeric,
  p_registration_status text,
  p_mismatch_explanation text,
  p_access_reason text,
  p_case_id text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_check public.business_registry_checks%rowtype;
begin
  if auth.uid() is null or not private.has_trust_admin_role(
    auth.uid(), array['business_reviewer']::text[]
  ) then
    return jsonb_build_object('ok', false, 'code', 'business_reviewer_required');
  end if;
  if not private.trust_admin_context_valid(p_access_reason, p_case_id) then
    return jsonb_build_object('ok', false, 'code', 'admin_access_reason_and_case_required');
  end if;
  if p_decision not in ('matched', 'mismatched')
     or p_match_confidence is null or p_match_confidence < 0 or p_match_confidence > 1
     or (p_decision = 'mismatched' and char_length(btrim(coalesce(p_mismatch_explanation, ''))) < 8) then
    return jsonb_build_object('ok', false, 'code', 'business_review_decision_invalid');
  end if;

  update public.business_registry_checks registry
  set status = p_decision,
      match_confidence = p_match_confidence,
      registration_status = nullif(btrim(coalesce(p_registration_status, '')), ''),
      mismatch_explanation = case when p_decision = 'mismatched' then btrim(p_mismatch_explanation) else null end,
      source_snapshot_at = now(),
      reviewed_by = auth.uid(),
      reviewed_at = now(),
      expires_at = case when p_decision = 'matched' then now() + interval '180 days' else null end,
      updated_at = now()
  where registry.id = p_check_id
    and registry.status in ('pending_manual_review', 'appealed')
  returning * into v_check;
  if v_check.id is null then
    return jsonb_build_object('ok', false, 'code', 'business_registry_check_not_reviewable');
  end if;

  if p_decision = 'matched' then
    update public.trust_signal_events signal
    set status = 'revoked', revoked_at = now(), updated_at = now()
    where signal.user_id = v_check.user_id
      and signal.signal_type = 'business_registry_match'
      and signal.status = 'verified'
      and signal.revoked_at is null;
    insert into public.trust_signal_events (
      user_id, signal_type, category, status, environment, source_kind,
      source_reference, public_label, what_was_checked, what_was_not_checked,
      checked_at, expires_at, public_visibility, grants_marketplace_access, metadata,
      created_by
    ) values (
      v_check.user_id, 'business_registry_match', 'business_registry', 'verified',
      private.user_trust_environment(v_check.user_id), 'business_registry', v_check.id::text,
      'Business registration matched',
      'A reviewer matched the supplied business name and registration number against the recorded official government source.',
      'The check did not prove the account holder owns, controls, or represents the business, and it does not guarantee safety.',
      now(), v_check.expires_at, false, false,
      jsonb_build_object('check_id', v_check.id, 'representative_identity_verified', false),
      auth.uid()
    );
  end if;

  insert into public.partner_audit_events (
    actor_id, action, resource_type, resource_id, access_reason, case_id, event_data
  ) values (
    auth.uid(), 'business_registry_' || p_decision, 'business_registry_check', v_check.id,
    btrim(p_access_reason), btrim(p_case_id),
    jsonb_build_object('match_confidence', p_match_confidence, 'source_host', v_check.official_source_host)
  );
  return jsonb_build_object(
    'ok', true,
    'check_id', v_check.id,
    'status', v_check.status,
    'business_record_matched', p_decision = 'matched',
    'representative_identity_verified', false,
    'grants_marketplace_access', false
  );
end;
$$;

create or replace function public.admin_review_business_representative_claim(
  p_claim_id uuid,
  p_action text,
  p_decision_reason text,
  p_access_reason text,
  p_case_id text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_claim public.business_representative_claims%rowtype;
begin
  if auth.uid() is null or not private.has_trust_admin_role(
    auth.uid(), array['business_reviewer', 'verification_reviewer']::text[]
  ) then
    return jsonb_build_object('ok', false, 'code', 'business_or_verification_reviewer_required');
  end if;
  if not private.trust_admin_context_valid(p_access_reason, p_case_id) then
    return jsonb_build_object('ok', false, 'code', 'admin_access_reason_and_case_required');
  end if;
  if p_action = 'verify' then
    return jsonb_build_object(
      'ok', false,
      'code', 'representative_verification_provider_unavailable',
      'message', 'MORT cannot verify a representative claim without an approved production workflow and provider.'
    );
  end if;
  if p_action not in ('request_information', 'reject', 'defer')
     or char_length(btrim(coalesce(p_decision_reason, ''))) < 12 then
    return jsonb_build_object('ok', false, 'code', 'representative_review_action_invalid');
  end if;
  update public.business_representative_claims claim
  set status = case when p_action = 'request_information' then 'more_information_required'
                    when p_action = 'reject' then 'rejected'
                    else 'pending_future_verification' end,
      reviewed_by = auth.uid(),
      reviewed_at = now(),
      decision_reason = btrim(p_decision_reason),
      updated_at = now()
  where claim.id = p_claim_id
  returning * into v_claim;
  if v_claim.id is null then
    return jsonb_build_object('ok', false, 'code', 'representative_claim_not_found');
  end if;
  insert into public.partner_audit_events (
    actor_id, action, resource_type, resource_id, access_reason, case_id, event_data
  ) values (
    auth.uid(), 'business_representative_' || p_action, 'business_representative_claim', v_claim.id,
    btrim(p_access_reason), btrim(p_case_id), jsonb_build_object('status', v_claim.status)
  );
  return jsonb_build_object(
    'ok', true,
    'claim_id', v_claim.id,
    'status', v_claim.status,
    'representative_identity_verified', false
  );
end;
$$;

create or replace function public.admin_review_account_trust_appeal(
  p_appeal_id uuid,
  p_decision text,
  p_resolution text,
  p_access_reason text,
  p_case_id text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_appeal public.account_trust_appeals%rowtype;
begin
  if auth.uid() is null or not private.has_trust_admin_role(
    auth.uid(), array['affiliation_reviewer', 'business_reviewer', 'verification_reviewer', 'senior_safety_moderator']::text[]
  ) then
    return jsonb_build_object('ok', false, 'code', 'trust_appeal_reviewer_required');
  end if;
  if not private.trust_admin_context_valid(p_access_reason, p_case_id) then
    return jsonb_build_object('ok', false, 'code', 'admin_access_reason_and_case_required');
  end if;
  if p_decision not in ('resolved', 'denied')
     or char_length(btrim(coalesce(p_resolution, ''))) not between 12 and 2000 then
    return jsonb_build_object('ok', false, 'code', 'appeal_resolution_invalid');
  end if;
  update public.account_trust_appeals appeal
  set status = p_decision,
      resolution = btrim(p_resolution),
      reviewer_id = auth.uid(),
      reviewed_at = now(),
      updated_at = now()
  where appeal.id = p_appeal_id and appeal.status in ('pending', 'reviewing')
  returning * into v_appeal;
  if v_appeal.id is null then
    return jsonb_build_object('ok', false, 'code', 'appeal_not_reviewable');
  end if;
  insert into public.partner_audit_events (
    actor_id, action, resource_type, resource_id, access_reason, case_id, event_data
  ) values (
    auth.uid(), 'account_trust_appeal_' || p_decision, 'account_trust_appeal', v_appeal.id,
    btrim(p_access_reason), btrim(p_case_id), jsonb_build_object('status', v_appeal.status)
  );
  return jsonb_build_object(
    'ok', true,
    'appeal_id', v_appeal.id,
    'status', v_appeal.status,
    'trust_level_changed_automatically', false
  );
end;
$$;

create or replace function public.get_admin_trust_review_queue(
  p_queue text,
  p_access_reason text,
  p_case_id text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_authorized boolean := false;
  v_items jsonb := '[]'::jsonb;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if not private.trust_admin_context_valid(p_access_reason, p_case_id) then
    return jsonb_build_object('ok', false, 'code', 'admin_access_reason_and_case_required');
  end if;

  v_authorized := case
    when p_queue in ('school_domains', 'partner_organizations', 'partner_codes') then
      private.has_trust_admin_role(auth.uid(), array['affiliation_reviewer']::text[])
    when p_queue in ('business_registry', 'business_representatives') then
      private.has_trust_admin_role(auth.uid(), array['business_reviewer']::text[])
    when p_queue = 'verification_appeals' then
      private.has_trust_admin_role(auth.uid(), array['support_agent', 'verification_reviewer', 'senior_safety_moderator']::text[])
    when p_queue in ('risk_signals', 'account_security') then
      private.has_trust_admin_role(auth.uid(), array['support_agent', 'safety_moderator', 'moderator', 'senior_safety_moderator']::text[])
    when p_queue = 'provider_events' then
      private.has_trust_admin_role(auth.uid(), array['verification_reviewer', 'senior_safety_moderator']::text[])
    else false
  end;
  if not v_authorized then
    return jsonb_build_object('ok', false, 'code', 'trust_review_queue_access_denied');
  end if;

  if p_queue = 'school_domains' then
    select coalesce(jsonb_agg(item), '[]'::jsonb) into v_items from (
      select jsonb_build_object(
        'id', request.id,
        'user_id', request.user_id,
        'domain', request.requested_domain,
        'status', request.status,
        'environment', request.environment,
        'created_at', request.created_at
      ) as item
      from public.partner_verification_requests request
      where request.request_type = 'school_email'
        and request.status = 'pending_domain_review'
      order by request.created_at
      limit 100
    ) queue;
  elsif p_queue = 'partner_organizations' then
    select coalesce(jsonb_agg(item), '[]'::jsonb) into v_items from (
      select jsonb_build_object(
        'id', organization.id,
        'organization_type', organization.organization_type,
        'legal_name', organization.legal_name,
        'display_name', organization.display_name,
        'status', organization.status,
        'environment', organization.environment,
        'official_directory_url', organization.official_directory_url,
        'created_at', organization.created_at
      ) as item
      from public.partner_organizations organization
      where organization.status = 'pending'
      order by organization.created_at
      limit 100
    ) queue;
  elsif p_queue = 'partner_codes' then
    select coalesce(jsonb_agg(item), '[]'::jsonb) into v_items from (
      select jsonb_build_object(
        'id', code.id,
        'organization_id', code.organization_id,
        'program_id', code.program_id,
        'code_prefix', code.code_prefix,
        'use_count', code.use_count,
        'max_uses', code.max_uses,
        'expires_at', code.expires_at,
        'revoked_at', code.revoked_at
      ) as item
      from public.partner_invite_codes code
      order by code.created_at desc
      limit 100
    ) queue;
  elsif p_queue = 'business_registry' then
    select coalesce(jsonb_agg(item), '[]'::jsonb) into v_items from (
      select jsonb_build_object(
        'id', registry.id,
        'user_id', registry.user_id,
        'jurisdiction', registry.jurisdiction,
        'legal_business_name', registry.legal_business_name,
        'registration_number', registry.registration_number,
        'entity_type', registry.entity_type,
        'official_source_url', registry.official_source_url,
        'status', registry.status,
        'created_at', registry.created_at
      ) as item
      from public.business_registry_checks registry
      where registry.status in ('pending_manual_review', 'appealed')
      order by registry.created_at
      limit 100
    ) queue;
  elsif p_queue = 'business_representatives' then
    select coalesce(jsonb_agg(item), '[]'::jsonb) into v_items from (
      select jsonb_build_object(
        'id', claim.id,
        'user_id', claim.user_id,
        'business_registry_check_id', claim.business_registry_check_id,
        'relationship_type', claim.relationship_type,
        'status', claim.status,
        'created_at', claim.created_at
      ) as item
      from public.business_representative_claims claim
      where claim.status in ('pending_future_verification', 'more_information_required')
      order by claim.created_at
      limit 100
    ) queue;
  elsif p_queue = 'verification_appeals' then
    select coalesce(jsonb_agg(item), '[]'::jsonb) into v_items from (
      select jsonb_build_object(
        'id', appeal.id,
        'user_id', appeal.user_id,
        'signal_id', appeal.signal_id,
        'reason', appeal.reason,
        'status', appeal.status,
        'created_at', appeal.created_at
      ) as item
      from public.account_trust_appeals appeal
      where appeal.status in ('pending', 'reviewing')
      order by appeal.created_at
      limit 100
    ) queue;
  elsif p_queue = 'risk_signals' then
    select coalesce(jsonb_agg(item), '[]'::jsonb) into v_items from (
      select jsonb_build_object(
        'user_id', trust.user_id,
        'risk_level', trust.risk_level,
        'risk_reasons', trust.risk_reasons,
        'recommended_action', trust.recommended_action,
        'human_review_required', trust.human_review_required,
        'calculated_at', trust.calculated_at
      ) as item
      from public.account_trust_profiles trust
      where trust.risk_level in ('review', 'elevated', 'restricted')
      order by trust.calculated_at desc
      limit 100
    ) queue;
  elsif p_queue = 'account_security' then
    select coalesce(jsonb_agg(item), '[]'::jsonb) into v_items from (
      select jsonb_build_object(
        'id', event.id,
        'user_id', event.user_id,
        'event_type', event.event_type,
        'severity', event.severity,
        'session_reference', event.session_reference,
        'status', event.status,
        'created_at', event.created_at
      ) as item
      from public.account_security_events event
      where event.status not in ('resolved', 'dismissed')
      order by event.created_at
      limit 100
    ) queue;
  elsif p_queue = 'provider_events' then
    select coalesce(jsonb_agg(item), '[]'::jsonb) into v_items from (
      select jsonb_build_object(
        'id', event.id,
        'provider', event.provider,
        'environment', event.environment,
        'result_status', event.result_status,
        'processing_status', event.processing_status,
        'received_at', event.received_at
      ) as item
      from private.identity_verification_webhook_events event
      order by event.received_at desc
      limit 100
    ) queue;
  end if;

  insert into public.partner_audit_events (
    actor_id, action, resource_type, access_reason, case_id, event_data
  ) values (
    auth.uid(), 'trust_review_queue_accessed', 'trust_review_queue',
    btrim(p_access_reason), btrim(p_case_id), jsonb_build_object('queue', p_queue)
  );
  return jsonb_build_object(
    'ok', true,
    'queue', p_queue,
    'items', v_items,
    'raw_identity_evidence_included', false
  );
end;
$$;

create or replace function public.create_digital_credential_session(
  p_user_id uuid,
  p_provider text,
  p_environment public.verification_environment,
  p_nonce_sha256 text,
  p_expected_issuer text,
  p_expected_credential_type text,
  p_requested_attributes jsonb,
  p_expires_at timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_policy private.trust_policy_versions%rowtype;
  v_session public.digital_credential_sessions%rowtype;
begin
  select * into v_policy from private.current_trust_policy();
  if p_provider = 'apple_wallet' and not v_policy.apple_wallet_enabled then
    return jsonb_build_object('ok', false, 'code', 'apple_wallet_identity_disabled');
  end if;
  if p_provider = 'android_credential_manager' and not v_policy.android_digital_credentials_enabled then
    return jsonb_build_object('ok', false, 'code', 'android_digital_credentials_disabled');
  end if;
  if p_provider not in ('apple_wallet', 'android_credential_manager') then
    return jsonb_build_object('ok', false, 'code', 'digital_credential_provider_unsupported');
  end if;
  if not exists (
    select 1 from public.profiles profile
    where profile.id = p_user_id
      and private.user_trust_environment(profile.id) = p_environment
  ) then
    return jsonb_build_object('ok', false, 'code', 'credential_account_environment_mismatch');
  end if;
  if p_nonce_sha256 !~ '^[A-Fa-f0-9]{64}$'
     or char_length(btrim(coalesce(p_expected_issuer, ''))) not between 3 and 200
     or char_length(btrim(coalesce(p_expected_credential_type, ''))) not between 3 and 120
     or jsonb_typeof(p_requested_attributes) <> 'array'
     or p_expires_at <= now()
     or p_expires_at > now() + interval '10 minutes' then
    return jsonb_build_object('ok', false, 'code', 'digital_credential_session_invalid');
  end if;
  if exists (
    select 1
    from jsonb_array_elements_text(p_requested_attributes) requested(attribute)
    where requested.attribute not in ('age_over_13', 'age_over_18', 'age_band', 'given_name', 'family_name')
  ) then
    return jsonb_build_object('ok', false, 'code', 'digital_credential_attribute_not_minimal');
  end if;

  insert into public.digital_credential_sessions (
    user_id, provider, environment, nonce_sha256, expected_issuer,
    expected_credential_type, requested_attributes, expires_at
  ) values (
    p_user_id, p_provider, p_environment, upper(p_nonce_sha256),
    btrim(p_expected_issuer), btrim(p_expected_credential_type),
    p_requested_attributes, p_expires_at
  ) returning * into v_session;
  return jsonb_build_object(
    'ok', true,
    'session_id', v_session.id,
    'expires_at', v_session.expires_at,
    'server_validation_required', true,
    'raw_credential_stored', false
  );
end;
$$;

create or replace function public.process_digital_credential_result(
  p_session_id uuid,
  p_event_id text,
  p_payload_sha256 text,
  p_signature_valid boolean,
  p_nonce_valid boolean,
  p_account_binding_valid boolean,
  p_issuer text,
  p_credential_type text,
  p_credential_valid_until timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session public.digital_credential_sessions%rowtype;
  v_event_db_id bigint;
  v_issuer_valid boolean;
  v_type_valid boolean;
  v_current boolean;
  v_failure text;
begin
  select * into v_session
  from public.digital_credential_sessions session
  where session.id = p_session_id
  for update;
  if v_session.id is null then
    return jsonb_build_object('ok', false, 'code', 'digital_credential_session_not_found');
  end if;
  if v_session.status <> 'created' then
    return jsonb_build_object(
      'ok', false,
      'code', case when exists (
        select 1 from public.digital_credential_events event
        where event.provider = v_session.provider and event.event_id = p_event_id
      ) then 'digital_credential_replay_detected' else 'digital_credential_session_not_active' end
    );
  end if;
  if v_session.expires_at <= now() then
    update public.digital_credential_sessions set status = 'expired', updated_at = now()
    where id = v_session.id;
    return jsonb_build_object('ok', false, 'code', 'digital_credential_session_expired');
  end if;
  if char_length(btrim(coalesce(p_event_id, ''))) not between 8 and 200
     or p_payload_sha256 !~ '^[A-Fa-f0-9]{64}$' then
    return jsonb_build_object('ok', false, 'code', 'digital_credential_event_invalid');
  end if;

  v_issuer_valid := btrim(coalesce(p_issuer, '')) = v_session.expected_issuer;
  v_type_valid := btrim(coalesce(p_credential_type, '')) = v_session.expected_credential_type;
  v_current := p_credential_valid_until is not null and p_credential_valid_until > now();
  v_failure := case
    when not p_signature_valid then 'signature_validation_failed'
    when not p_nonce_valid then 'nonce_validation_failed'
    when not p_account_binding_valid then 'account_binding_failed'
    when not v_issuer_valid then 'unknown_issuer'
    when not v_type_valid then 'credential_type_mismatch'
    when not v_current then 'credential_expired'
    else null
  end;

  insert into public.digital_credential_events (
    session_id, provider, event_id, payload_sha256, signature_valid,
    nonce_valid, issuer_valid, credential_type_valid, account_binding_valid,
    credential_current, result, failure_code, processed_at
  ) values (
    v_session.id, v_session.provider, btrim(p_event_id), upper(p_payload_sha256),
    p_signature_valid, p_nonce_valid, v_issuer_valid, v_type_valid,
    p_account_binding_valid, v_current,
    case when v_failure is null then 'verified' else 'rejected' end,
    v_failure, now()
  )
  on conflict (provider, event_id) do nothing
  returning id into v_event_db_id;
  if v_event_db_id is null then
    return jsonb_build_object('ok', false, 'code', 'digital_credential_replay_detected');
  end if;

  if v_failure is not null then
    update public.digital_credential_sessions
    set status = 'rejected', updated_at = now()
    where id = v_session.id;
    return jsonb_build_object(
      'ok', false,
      'code', v_failure,
      'identity_verified', false,
      'marketplace_access_granted', false
    );
  end if;

  update public.digital_credential_sessions
  set status = 'verified',
      account_bound = true,
      verified_at = now(),
      updated_at = now()
  where id = v_session.id;
  insert into public.trust_signal_events (
    user_id, signal_type, category, status, environment, source_kind,
    source_reference, public_label, what_was_checked, what_was_not_checked,
    checked_at, expires_at, public_visibility, grants_marketplace_access, metadata
  ) values (
    v_session.user_id, 'digital_government_id', 'digital_identity', 'verified',
    v_session.environment, 'digital_credential', v_session.id::text,
    'Government digital ID verified',
    'A trusted backend validated the credential signature, nonce, issuer, credential type, account binding, and current validity.',
    'The credential does not guarantee behavior, intent, work quality, or safety.',
    now(), p_credential_valid_until, false, false,
    jsonb_build_object('session_id', v_session.id, 'event_id', p_event_id, 'raw_credential_stored', false)
  );
  return jsonb_build_object(
    'ok', true,
    'status', 'verified',
    'government_digital_id_verified', true,
    'environment', v_session.environment,
    'raw_credential_stored', false,
    'marketplace_access_granted', false
  );
end;
$$;

create or replace function public.record_server_reauthentication_event(
  p_user_id uuid,
  p_action_type text,
  p_authentication_method text,
  p_result text,
  p_session_reference text,
  p_valid_until timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_event public.sensitive_action_reauth_events%rowtype;
begin
  if p_authentication_method not in ('device_owner_authentication', 'passcode_fallback', 'webauthn', 'secure_fallback')
     or p_result not in ('succeeded', 'failed', 'cancelled', 'denied', 'locked_out', 'unavailable')
     or char_length(btrim(coalesce(p_action_type, ''))) not between 3 and 100 then
    return jsonb_build_object('ok', false, 'code', 'reauthentication_event_invalid');
  end if;
  insert into public.sensitive_action_reauth_events (
    user_id, action_type, authentication_method, result,
    session_reference, valid_until
  ) values (
    p_user_id, btrim(p_action_type), p_authentication_method, p_result,
    nullif(left(btrim(coalesce(p_session_reference, '')), 100), ''),
    case when p_result = 'succeeded' then p_valid_until else null end
  ) returning * into v_event;
  return jsonb_build_object(
    'ok', true,
    'event_id', v_event.id,
    'identity_effect', false,
    'biometric_material_stored', false
  );
end;
$$;

revoke all on function private.trust_admin_context_valid(text, text)
from public, anon, authenticated;

revoke all on function public.get_marketplace_trust_eligibility(text, uuid),
  public.get_my_account_trust_profile(),
  public.get_public_trust_badges(uuid),
  public.update_account_security_preferences(boolean, smallint),
  public.set_trust_signal_visibility(text, boolean),
  public.submit_account_trust_appeal(text, uuid),
  public.request_school_email_affiliation(text),
  public.redeem_partner_invite_code(text),
  public.request_business_registry_match(text, text, text, text, text),
  public.request_business_representative_claim(uuid, text, boolean),
  public.admin_review_school_domain(text, text, text, public.verification_environment, text, boolean, text, text),
  public.admin_create_partner_organization(text, text, text, public.verification_environment, text, text, text),
  public.admin_review_partner_organization(uuid, boolean, text, text),
  public.admin_create_partner_invite_code(uuid, uuid, timestamptz, integer, text, text),
  public.admin_review_business_registry_match(uuid, text, numeric, text, text, text, text),
  public.admin_review_business_representative_claim(uuid, text, text, text, text),
  public.admin_review_account_trust_appeal(uuid, text, text, text, text),
  public.get_admin_trust_review_queue(text, text, text),
  public.create_digital_credential_session(uuid, text, public.verification_environment, text, text, text, jsonb, timestamptz),
  public.process_digital_credential_result(uuid, text, text, boolean, boolean, boolean, text, text, timestamptz),
  public.record_server_reauthentication_event(uuid, text, text, text, text, timestamptz)
from public, anon, authenticated;

grant execute on function public.get_marketplace_trust_eligibility(text, uuid),
  public.get_my_account_trust_profile(),
  public.get_public_trust_badges(uuid),
  public.update_account_security_preferences(boolean, smallint),
  public.set_trust_signal_visibility(text, boolean),
  public.submit_account_trust_appeal(text, uuid),
  public.request_school_email_affiliation(text),
  public.redeem_partner_invite_code(text),
  public.request_business_registry_match(text, text, text, text, text),
  public.request_business_representative_claim(uuid, text, boolean),
  public.admin_review_school_domain(text, text, text, public.verification_environment, text, boolean, text, text),
  public.admin_create_partner_organization(text, text, text, public.verification_environment, text, text, text),
  public.admin_review_partner_organization(uuid, boolean, text, text),
  public.admin_create_partner_invite_code(uuid, uuid, timestamptz, integer, text, text),
  public.admin_review_business_registry_match(uuid, text, numeric, text, text, text, text),
  public.admin_review_business_representative_claim(uuid, text, text, text, text),
  public.admin_review_account_trust_appeal(uuid, text, text, text, text),
  public.get_admin_trust_review_queue(text, text, text)
to authenticated, service_role;

grant execute on function public.create_digital_credential_session(uuid, text, public.verification_environment, text, text, text, jsonb, timestamptz),
  public.process_digital_credential_result(uuid, text, text, boolean, boolean, boolean, text, text, timestamptz),
  public.record_server_reauthentication_event(uuid, text, text, text, text, timestamptz)
to service_role;

do $$
declare
  v_profile record;
begin
  for v_profile in select profile.id from public.profiles profile loop
    perform private.refresh_account_trust_profile(v_profile.id);
  end loop;
end
$$;

comment on table public.account_trust_profiles is
  'Server-derived trust level and private risk summary. It is not a numerical safety score.';
comment on table public.trust_signal_events is
  'Precise account-security, contact, affiliation, registry, digital credential, provider, and screening signals. No signal alone grants marketplace access.';
comment on table public.sensitive_action_reauth_events is
  'Trusted-server reauthentication audit metadata only. No biometric material and no legal-identity effect.';
comment on function public.get_marketplace_trust_eligibility(text, uuid) is
  'Returns server-owned structured marketplace eligibility and exact reason codes.';
comment on function public.request_school_email_affiliation(text) is
  'Confirms approved-domain affiliation using the already-confirmed account email; never claims government identity.';
comment on function public.request_business_registry_match(text, text, text, text, text) is
  'Creates an official-source manual registry review; never proves representative authority.';
