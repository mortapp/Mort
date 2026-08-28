-- MORT economic mobility and safe independence foundation.
-- This additive migration creates a closed, partner-supported pilot. It does
-- not enable unrestricted marketplace access or real identity-document intake.

alter type public.admin_safety_role add value if not exists 'document_reviewer';
alter type public.admin_safety_role add value if not exists 'senior_verification_reviewer';

create table private.pilot_policy_versions (
  id uuid primary key default gen_random_uuid(),
  version integer not null unique check (version > 0),
  policy_name text not null,
  is_active boolean not null default false,
  pilot_mode_enabled boolean not null default true,
  unrestricted_public_access_enabled boolean not null default false check (unrestricted_public_access_enabled = false),
  real_document_collection_enabled boolean not null default false check (real_document_collection_enabled = false),
  require_partner_supported_entry boolean not null default true check (require_partner_supported_entry),
  require_manual_adult_approval boolean not null default true check (require_manual_adult_approval),
  guardian_mode_optional boolean not null default true check (guardian_mode_optional),
  maximum_document_signed_url_seconds integer not null default 180 check (maximum_document_signed_url_seconds between 30 and 300),
  created_at timestamptz not null default now(),
  retired_at timestamptz,
  constraint pilot_policy_name_length check (char_length(policy_name) between 3 and 120)
);

create unique index pilot_policy_one_active_idx
on private.pilot_policy_versions(is_active)
where is_active;

insert into private.pilot_policy_versions (
  version, policy_name, is_active, pilot_mode_enabled,
  unrestricted_public_access_enabled, real_document_collection_enabled,
  require_partner_supported_entry, require_manual_adult_approval,
  guardian_mode_optional
) values (
  1, 'closed-organization-supported-pilot', true, true,
  false, false, true, true, true
);

create or replace function private.current_pilot_policy()
returns private.pilot_policy_versions
language sql
stable
security definer
set search_path = ''
as $$
  select policy.*
  from private.pilot_policy_versions policy
  where policy.is_active
  order by policy.version desc
  limit 1;
$$;

revoke all on function private.current_pilot_policy()
from public, anon, authenticated;

alter table public.partner_organizations
  drop constraint if exists partner_organizations_organization_type_check;

alter table public.partner_organizations
  add constraint partner_organizations_organization_type_check
  check (organization_type in (
    'school', 'online_school', 'vocational_program', 'nonprofit',
    'youth_program', 'youth_shelter', 'community_center',
    'workforce_program', 'verified_business', 'local_government_youth_program'
  ));

alter table public.partner_organizations
  add column pilot_approved boolean not null default false,
  add column pilot_approved_by uuid references public.profiles(id) on delete set null,
  add column pilot_approved_at timestamptz,
  add column privacy_training_acknowledged_at timestamptz,
  add column child_safety_training_acknowledged_at timestamptz,
  add constraint partner_pilot_approval_fields check (
    not pilot_approved
    or (
      status = 'verified'
      and pilot_approved_by is not null
      and pilot_approved_at is not null
    )
  );

alter table public.partner_invite_codes
  add column audience_role text not null default 'teen'
    check (audience_role in ('teen', 'adult', 'guardian', 'partner_staff', 'any_pilot_participant')),
  add column purpose text not null default 'affiliation'
    check (purpose in ('affiliation', 'pilot_enrollment', 'partner_staff')),
  add column revoked_by uuid references public.profiles(id) on delete set null,
  add column revocation_reason text,
  add constraint partner_code_revocation_reason check (
    revoked_at is null
    or char_length(btrim(coalesce(revocation_reason, ''))) between 8 and 500
  );

create table public.partner_staff (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.partner_organizations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  staff_role text not null check (staff_role in (
    'staff', 'school_liaison', 'program_coordinator', 'case_worker',
    'shelter_staff', 'workforce_coach', 'organization_admin'
  )),
  status text not null default 'pending' check (status in ('pending', 'active', 'suspended', 'revoked')),
  verified_by uuid references public.profiles(id) on delete set null,
  verified_at timestamptz,
  expires_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint partner_staff_active_fields check (
    status <> 'active'
    or (verified_by is not null and verified_at is not null)
  ),
  constraint partner_staff_expiry_order check (
    expires_at is null or verified_at is null or expires_at > verified_at
  )
);

create unique index partner_staff_active_user_org_idx
on public.partner_staff(organization_id, user_id)
where status = 'active' and revoked_at is null;

create table public.partner_permissions (
  id uuid primary key default gen_random_uuid(),
  partner_staff_id uuid not null references public.partner_staff(id) on delete cascade,
  permission_key text not null check (permission_key in (
    'view_connected_participants', 'attest_person_appeared',
    'attest_affiliation', 'attest_age_band', 'attest_program_participation',
    'manage_partner_invites', 'receive_granted_support_alerts'
  )),
  enabled boolean not null default true,
  granted_by uuid not null references public.profiles(id) on delete restrict,
  grant_reason text not null,
  granted_at timestamptz not null default now(),
  revoked_at timestamptz,
  constraint partner_permission_reason_length check (char_length(btrim(grant_reason)) between 8 and 500),
  constraint partner_permission_unique unique (partner_staff_id, permission_key)
);

create table public.partner_attestations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.partner_organizations(id) on delete restrict,
  partner_staff_id uuid not null references public.partner_staff(id) on delete restrict,
  subject_user_id uuid not null references public.profiles(id) on delete cascade,
  fact_type text not null check (fact_type in (
    'person_appeared_before_partner', 'school_or_program_affiliation',
    'approximate_age_band_eligible', 'partner_program_participation',
    'staff_identity_confirmed', 'partner_relationship_confirmed'
  )),
  attestation_version integer not null check (attestation_version > 0),
  status text not null default 'active' check (status in ('active', 'superseded', 'revoked', 'expired')),
  attestation_statement text not null,
  what_was_not_established text not null,
  effective_at timestamptz not null default now(),
  expires_at timestamptz not null,
  supersedes_id uuid references public.partner_attestations(id) on delete restrict,
  revoked_at timestamptz,
  revocation_reason text,
  created_at timestamptz not null default now(),
  constraint partner_attestation_statement_length check (
    char_length(btrim(attestation_statement)) between 12 and 800
    and char_length(btrim(what_was_not_established)) between 20 and 800
  ),
  constraint partner_attestation_expiry_order check (expires_at > effective_at),
  constraint partner_attestation_revocation_fields check (
    revoked_at is null
    or char_length(btrim(coalesce(revocation_reason, ''))) between 8 and 800
  ),
  constraint partner_attestation_version_unique unique (
    organization_id, subject_user_id, fact_type, attestation_version
  )
);

create index partner_attestations_subject_current_idx
on public.partner_attestations(subject_user_id, status, expires_at);
create index partner_attestations_staff_idx
on public.partner_attestations(partner_staff_id, created_at desc);

alter table public.partner_audit_events
  add column organization_id uuid references public.partner_organizations(id) on delete set null,
  add column subject_user_id uuid references public.profiles(id) on delete set null,
  add column event_version integer not null default 1 check (event_version > 0);

create table public.pilot_enrollments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  organization_id uuid not null references public.partner_organizations(id) on delete restrict,
  source_type text not null check (source_type in (
    'organization_invitation', 'partner_code', 'verified_partner_email',
    'partner_staff_attestation', 'manual_pilot_enrollment'
  )),
  status text not null default 'pending' check (status in ('pending', 'approved', 'denied', 'revoked', 'expired')),
  participation_role text not null check (participation_role in ('teen', 'adult', 'guardian', 'partner_staff')),
  permanent_address_required boolean not null default false check (permanent_address_required = false),
  guardian_connection_required boolean not null default false check (guardian_connection_required = false),
  approved_by uuid references public.profiles(id) on delete set null,
  approved_at timestamptz,
  expires_at timestamptz,
  revoked_at timestamptz,
  decision_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint pilot_enrollment_approval_fields check (
    status <> 'approved'
    or (approved_by is not null and approved_at is not null and expires_at is not null)
  ),
  constraint pilot_enrollment_expiry_order check (
    expires_at is null or approved_at is null or expires_at > approved_at
  )
);

create unique index pilot_enrollments_active_user_idx
on public.pilot_enrollments(user_id)
where status = 'approved' and revoked_at is null;
create index pilot_enrollments_org_status_idx
on public.pilot_enrollments(organization_id, status, created_at desc);

create table public.pilot_participant_acknowledgements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  acknowledgement_type text not null check (acknowledgement_type in (
    'teen_safety_training', 'adult_safety_training', 'prohibited_work',
    'payment_scope', 'incident_policy', 'pilot_rules', 'explicit_consent'
  )),
  policy_version integer not null check (policy_version > 0),
  acknowledged_at timestamptz not null default now(),
  revoked_at timestamptz,
  constraint pilot_ack_unique unique (user_id, acknowledgement_type, policy_version)
);

alter table public.jobs
  add column pilot_organization_id uuid references public.partner_organizations(id) on delete set null,
  add column pilot_location_class text not null default 'unclassified' check (pilot_location_class in (
    'unclassified', 'verified_business', 'school', 'nonprofit',
    'community_center', 'public_event', 'staffed_community_project',
    'visible_outdoor_community_space', 'private_residence', 'hotel',
    'isolated_property', 'unknown_location'
  )),
  add column pilot_staffed_or_visible boolean not null default false,
  add column pilot_review_status text not null default 'not_evaluated' check (pilot_review_status in (
    'not_evaluated', 'eligible', 'manual_review_required', 'blocked'
  )),
  add column pilot_restriction_reasons text[] not null default '{}',
  add column pilot_policy_version integer,
  add column pilot_reviewed_by uuid references public.profiles(id) on delete set null,
  add column pilot_reviewed_at timestamptz;

create table public.pilot_job_reviews (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete cascade,
  policy_version integer not null check (policy_version > 0),
  decision text not null check (decision in ('eligible', 'manual_review_required', 'blocked')),
  reason_codes text[] not null default '{}',
  reviewer_id uuid references public.profiles(id) on delete set null,
  review_method text not null check (review_method in ('server_rules', 'authorized_human_review')),
  created_at timestamptz not null default now(),
  constraint pilot_job_human_reviewer check (
    review_method <> 'authorized_human_review' or reviewer_id is not null
  )
);

create index pilot_job_reviews_job_idx
on public.pilot_job_reviews(job_id, created_at desc);

create table public.document_review_cases (
  id uuid primary key default gen_random_uuid(),
  subject_user_id uuid not null references public.profiles(id) on delete cascade,
  environment public.verification_environment not null default 'production',
  evidence_category text not null check (evidence_category in (
    'age_evidence', 'affiliation_evidence', 'government_document',
    'program_document', 'alternative_evidence'
  )),
  status text not null default 'document_review_pending' check (status in (
    'document_uploaded', 'document_review_pending', 'document_reviewed',
    'age_evidence_reviewed', 'affiliation_reviewed',
    'authenticity_not_authoritatively_validated',
    'additional_information_required', 'rejected', 'appeal_pending', 'expired'
  )),
  public_label text not null default 'Document review pending',
  what_was_established text not null default 'No review decision has been made.',
  what_was_not_established text not null default 'Legal identity, document authenticity, and account ownership have not been authoritatively established.',
  contains_real_person_data boolean not null default false,
  requires_two_person_review boolean not null default false,
  final_decision_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint document_case_label_length check (char_length(btrim(public_label)) between 3 and 100),
  constraint document_case_explanation_length check (
    char_length(btrim(what_was_established)) between 12 and 1000
    and char_length(btrim(what_was_not_established)) between 20 and 1000
  ),
  constraint document_case_no_authoritative_overclaim check (
    lower(public_label) not in ('verified', 'identity verified', 'government identity verified')
  )
);

create index document_review_cases_subject_idx
on public.document_review_cases(subject_user_id, status, created_at desc);

create table public.document_review_assignments (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.document_review_cases(id) on delete cascade,
  reviewer_id uuid not null references public.profiles(id) on delete restrict,
  assignment_stage text not null check (assignment_stage in ('reviewer_a', 'reviewer_b', 'appeal')),
  status text not null default 'assigned' check (status in ('assigned', 'completed', 'recused', 'revoked')),
  conflict_checked_at timestamptz,
  conflict_found boolean not null default false,
  assigned_by uuid not null references public.profiles(id) on delete restrict,
  assigned_at timestamptz not null default now(),
  completed_at timestamptz,
  constraint document_assignment_unique unique (case_id, reviewer_id, assignment_stage)
);

create table public.document_review_decisions (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.document_review_cases(id) on delete cascade,
  reviewer_id uuid not null references public.profiles(id) on delete restrict,
  decision_stage text not null check (decision_stage in ('reviewer_a_recommendation', 'reviewer_b_independent_decision', 'appeal_decision')),
  decision text not null check (decision in (
    'document_reviewed', 'age_evidence_reviewed', 'affiliation_reviewed',
    'authenticity_not_authoritatively_validated',
    'additional_information_required', 'rejected', 'expired'
  )),
  decision_reason text not null,
  public_explanation text not null,
  conflict_of_interest_confirmed_clear boolean not null,
  created_at timestamptz not null default now(),
  constraint document_decision_reason_length check (
    char_length(btrim(decision_reason)) between 20 and 2000
    and char_length(btrim(public_explanation)) between 20 and 1000
  ),
  constraint document_decision_unique_stage unique (case_id, decision_stage),
  constraint document_decision_not_identity_claim check (
    lower(public_explanation) not like '%government identity verified%'
    and lower(public_explanation) not like '%legal identity verified%'
  )
);

create table public.document_review_appeals (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.document_review_cases(id) on delete cascade,
  appellant_id uuid not null references public.profiles(id) on delete cascade,
  reason text not null,
  status text not null default 'pending' check (status in ('pending', 'under_review', 'upheld', 'changed', 'closed')),
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  decision_reason text,
  created_at timestamptz not null default now(),
  constraint document_appeal_reason_length check (char_length(btrim(reason)) between 20 and 2000)
);

create table private.document_vault_objects (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.document_review_cases(id) on delete cascade,
  object_identifier uuid not null unique default gen_random_uuid(),
  environment public.verification_environment not null,
  storage_bucket text not null default 'mort-document-vault' check (storage_bucket = 'mort-document-vault'),
  storage_path text not null unique,
  evidence_sha256 text not null check (evidence_sha256 ~ '^[a-f0-9]{64}$'),
  mime_type text not null check (mime_type in ('image/jpeg', 'image/png', 'application/pdf')),
  byte_size bigint not null check (byte_size between 1 and 10485760),
  retention_delete_at timestamptz not null,
  preservation_lock_status text not null default 'none' check (preservation_lock_status in ('none', 'appeal_hold', 'incident_hold', 'legal_hold')),
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  constraint document_vault_random_path check (
    storage_path = environment::text || '/' || object_identifier::text
  ),
  constraint document_vault_retention_order check (retention_delete_at > created_at)
);

create table private.document_vault_access_grants (
  id uuid primary key default gen_random_uuid(),
  vault_object_id uuid not null references private.document_vault_objects(id) on delete cascade,
  reviewer_id uuid not null references public.profiles(id) on delete restrict,
  case_id uuid not null references public.document_review_cases(id) on delete cascade,
  access_reason text not null,
  access_action text not null check (access_action in ('view', 'download')),
  expires_at timestamptz not null,
  consumed_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  constraint document_vault_access_reason_length check (char_length(btrim(access_reason)) between 12 and 1000),
  constraint document_vault_access_expiry check (expires_at > created_at and expires_at <= created_at + interval '5 minutes')
);

create table private.document_vault_audit_events (
  id bigint generated always as identity primary key,
  vault_object_id uuid references private.document_vault_objects(id) on delete restrict,
  case_id uuid not null references public.document_review_cases(id) on delete restrict,
  actor_id uuid references public.profiles(id) on delete set null,
  event_type text not null check (event_type in (
    'upload_authorized', 'object_registered', 'view_authorized', 'viewed',
    'download_authorized', 'downloaded', 'access_denied', 'retention_extended',
    'preservation_locked', 'deletion_requested', 'deleted', 'breach_response_logged'
  )),
  access_reason text not null,
  event_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint document_vault_audit_reason_length check (char_length(btrim(access_reason)) between 8 and 1000),
  constraint document_vault_audit_no_raw_evidence check (
    not (event_data ?| array[
      'raw_evidence', 'document_bytes', 'original_filename', 'document_number',
      'full_name', 'residential_address', 'selfie', 'biometric'
    ])
  )
);

create table private.document_retention_actions (
  id uuid primary key default gen_random_uuid(),
  vault_object_id uuid not null references private.document_vault_objects(id) on delete restrict,
  action text not null check (action in ('schedule_delete', 'extend_for_appeal', 'preservation_lock', 'release_lock', 'delete_confirmed')),
  actor_id uuid references public.profiles(id) on delete set null,
  reason text not null,
  previous_delete_at timestamptz,
  new_delete_at timestamptz,
  created_at timestamptz not null default now(),
  constraint document_retention_reason_length check (char_length(btrim(reason)) between 12 and 1000)
);

create table private.document_operational_readiness_gates (
  gate_key text primary key,
  passed boolean not null default false,
  evidence_reference text,
  approved_by uuid references public.profiles(id) on delete set null,
  approved_at timestamptz,
  updated_at timestamptz not null default now(),
  constraint document_gate_key_check check (gate_key in (
    'adult_operating_entity', 'trained_reviewers', 'reviewer_access_policy',
    'written_review_procedure', 'written_privacy_policy', 'retention_schedule',
    'deletion_procedure_tested', 'breach_response_process', 'appeal_process',
    'two_person_approval', 'storage_rls_qa', 'legal_privacy_review',
    'child_safety_review', 'incident_response_staffing', 'production_monitoring',
    'production_audit_logging', 'founder_raw_access_restricted',
    'pilot_partners_approved'
  )),
  constraint document_gate_pass_fields check (
    not passed
    or (
      approved_by is not null
      and approved_at is not null
      and char_length(btrim(coalesce(evidence_reference, ''))) between 8 and 500
    )
  )
);

insert into private.document_operational_readiness_gates (gate_key)
select gate_key
from unnest(array[
  'adult_operating_entity', 'trained_reviewers', 'reviewer_access_policy',
  'written_review_procedure', 'written_privacy_policy', 'retention_schedule',
  'deletion_procedure_tested', 'breach_response_process', 'appeal_process',
  'two_person_approval', 'storage_rls_qa', 'legal_privacy_review',
  'child_safety_review', 'incident_response_staffing', 'production_monitoring',
  'production_audit_logging', 'founder_raw_access_restricted',
  'pilot_partners_approved'
]) as gate_key;

create table public.discreet_mode_preferences (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  enabled boolean not null default false,
  generic_notification_title boolean not null default true,
  hide_notification_content boolean not null default true,
  hide_job_address_on_lock_screen boolean not null default true check (hide_job_address_on_lock_screen),
  hide_sensitive_activity boolean not null default true,
  app_lock_enabled boolean not null default false,
  automatic_lock_minutes smallint not null default 5 check (automatic_lock_minutes between 1 and 60),
  quick_exit_destination text not null default 'home' check (quick_exit_destination in ('home', 'job_feed', 'sign_in')),
  clear_sensitive_navigation_on_exit boolean not null default true,
  updated_at timestamptz not null default now()
);

create table public.trusted_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  device_reference_hash text not null,
  display_label text not null,
  trusted_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  revoked_at timestamptz,
  constraint trusted_device_hash check (device_reference_hash ~ '^[a-f0-9]{64}$'),
  constraint trusted_device_label_length check (char_length(btrim(display_label)) between 1 and 80),
  constraint trusted_device_unique unique (user_id, device_reference_hash)
);

create table public.support_circles (
  id uuid primary key default gen_random_uuid(),
  teen_id uuid not null unique references public.profiles(id) on delete cascade,
  enabled boolean not null default false,
  affects_profile_completion boolean not null default false check (affects_profile_completion = false),
  affects_marketplace_eligibility boolean not null default false check (affects_marketplace_eligibility = false),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.support_circle_members (
  id uuid primary key default gen_random_uuid(),
  circle_id uuid not null references public.support_circles(id) on delete cascade,
  member_user_id uuid not null references public.profiles(id) on delete cascade,
  relationship_type text not null check (relationship_type in (
    'parent', 'guardian', 'relative', 'adult_sibling', 'counselor', 'mentor',
    'school_liaison', 'social_worker', 'shelter_staff', 'youth_program_worker',
    'trusted_adult'
  )),
  status text not null default 'invited' check (status in ('invited', 'active', 'declined', 'revoked')),
  invited_by uuid not null references public.profiles(id) on delete cascade,
  accepted_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  constraint support_circle_member_unique unique (circle_id, member_user_id)
);

create table public.support_circle_permissions (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.support_circle_members(id) on delete cascade,
  permission_key text not null check (permission_key in (
    'receive_safety_ping', 'receive_missed_check_in', 'receive_accepted_job_summary',
    'receive_job_completion_alert', 'receive_transportation_plan_alert',
    'help_access_resources', 'confirm_organization_relationship'
  )),
  enabled boolean not null default false,
  configured_by uuid not null references public.profiles(id) on delete cascade,
  updated_at timestamptz not null default now(),
  constraint support_circle_permission_unique unique (member_id, permission_key)
);

create table public.support_circle_alert_events (
  id uuid primary key default gen_random_uuid(),
  circle_id uuid not null references public.support_circles(id) on delete cascade,
  member_id uuid not null references public.support_circle_members(id) on delete cascade,
  teen_id uuid not null references public.profiles(id) on delete cascade,
  alert_type text not null check (alert_type in (
    'safety_ping', 'missed_check_in', 'accepted_job_summary',
    'job_completion', 'transportation_plan', 'resource_help_request'
  )),
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  read_at timestamptz,
  constraint support_alert_no_sensitive_payload check (
    not (payload ?| array[
      'message_body', 'full_location_history', 'identity_document',
      'earnings', 'password', 'housing_status', 'residential_address'
    ])
  )
);

create table public.work_earning_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  application_id uuid references public.applications(id) on delete set null,
  amount_cents integer not null check (amount_cents >= 0 and amount_cents <= 10000000),
  earned_on date not null,
  source_label text not null,
  payment_status text not null default 'self_reported' check (payment_status in ('self_reported', 'poster_confirmed', 'disputed')),
  mort_held_payment boolean not null default false check (mort_held_payment = false),
  private_by_default boolean not null default true check (private_by_default),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint work_earning_source_length check (char_length(btrim(source_label)) between 2 and 120)
);

create index work_earning_user_date_idx
on public.work_earning_entries(user_id, earned_on desc);

create table public.independence_goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  goal_type text not null check (goal_type in (
    'weekly_earnings', 'emergency_savings', 'future_housing', 'transportation',
    'school_supplies', 'family_support', 'work_equipment', 'custom'
  )),
  title text not null,
  target_amount_cents integer check (target_amount_cents between 0 and 100000000),
  current_amount_cents integer not null default 0 check (current_amount_cents between 0 and 100000000),
  target_date date,
  visibility text not null default 'private' check (visibility = 'private'),
  status text not null default 'active' check (status in ('active', 'completed', 'paused', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint independence_goal_title_length check (char_length(btrim(title)) between 2 and 100)
);

create table public.future_independence_plans (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  target_date date,
  education_plan text,
  employment_plan text,
  transportation_plan text,
  savings_target_cents integer check (savings_target_cents between 0 and 100000000),
  emergency_fund_target_cents integer check (emergency_fund_target_cents between 0 and 100000000),
  trusted_support_notes text,
  private_by_default boolean not null default true check (private_by_default),
  runaway_guidance_provided boolean not null default false check (runaway_guidance_provided = false),
  updated_at timestamptz not null default now()
);

create table public.future_independence_tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  task_type text not null check (task_type in (
    'resume', 'references', 'transportation', 'identification_checklist',
    'budgeting', 'housing_costs', 'renter_terms', 'utilities',
    'emergency_fund', 'education', 'employment', 'age_18_transition',
    'resource_referral'
  )),
  completed boolean not null default false,
  private_note text,
  updated_at timestamptz not null default now(),
  constraint future_task_unique unique (user_id, task_type)
);

create table public.skill_passport_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  skill_name text not null,
  evidence_type text not null check (evidence_type in ('self_reported', 'completed_job', 'partner_program', 'reference')),
  source_application_id uuid references public.applications(id) on delete set null,
  verified_work_history boolean not null default false,
  visibility text not null default 'private' check (visibility in ('private', 'profile')),
  created_at timestamptz not null default now(),
  constraint skill_passport_name_length check (char_length(btrim(skill_name)) between 2 and 80)
);

create table public.work_reference_requests (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles(id) on delete cascade,
  application_id uuid not null references public.applications(id) on delete cascade,
  requested_from uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'provided', 'declined', 'withdrawn')),
  reference_text text,
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  constraint work_reference_unique unique (requester_id, application_id, requested_from),
  constraint work_reference_text_length check (reference_text is null or char_length(btrim(reference_text)) between 20 and 1000)
);

create table public.resource_directory_entries (
  id uuid primary key default gen_random_uuid(),
  organization_name text not null,
  category text not null check (category in (
    'school_homeless_education_liaison', 'youth_shelter', 'food_assistance',
    'transportation_assistance', 'work_clothing_equipment', 'healthcare',
    'mental_health_support', 'legal_aid', 'education_support', 'job_training',
    'apprenticeships', 'youthbuild_program', 'workforce_program',
    'community_organization', 'document_replacement_assistance',
    'housing_support', 'emergency_resources'
  )),
  source_url text not null,
  source_status text not null default 'pending_review' check (source_status in ('pending_review', 'official', 'reviewed', 'outdated', 'removed')),
  organization_verification_status text not null default 'unverified' check (organization_verification_status in ('unverified', 'source_reviewed', 'partner_verified')),
  city text,
  state text,
  summary text not null,
  emergency_limitations text not null,
  availability_claimed boolean not null default false check (availability_claimed = false),
  last_reviewed_at timestamptz,
  reviewed_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint resource_name_length check (char_length(btrim(organization_name)) between 2 and 160),
  constraint resource_summary_length check (
    char_length(btrim(summary)) between 20 and 1000
    and char_length(btrim(emergency_limitations)) between 20 and 1000
  )
);

create table public.private_resource_bookmarks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  resource_id uuid not null references public.resource_directory_entries(id) on delete cascade,
  private_note text,
  created_at timestamptz not null default now(),
  constraint resource_bookmark_unique unique (user_id, resource_id)
);

create table public.resource_directory_reports (
  id uuid primary key default gen_random_uuid(),
  resource_id uuid not null references public.resource_directory_entries(id) on delete cascade,
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reason text not null,
  status text not null default 'open' check (status in ('open', 'reviewed', 'resolved', 'dismissed')),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  constraint resource_report_reason_length check (char_length(btrim(reason)) between 8 and 1000)
);

create or replace function private.has_active_partner_permission(
  p_user_id uuid,
  p_organization_id uuid,
  p_permission_key text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.partner_staff staff
    join public.partner_permissions permission
      on permission.partner_staff_id = staff.id
     and permission.permission_key = p_permission_key
     and permission.enabled
     and permission.revoked_at is null
    join public.partner_organizations organization
      on organization.id = staff.organization_id
     and organization.status = 'verified'
     and organization.pilot_approved
     and (organization.expires_at is null or organization.expires_at > now())
    where staff.user_id = p_user_id
      and staff.organization_id = p_organization_id
      and staff.status = 'active'
      and staff.revoked_at is null
      and (staff.expires_at is null or staff.expires_at > now())
  );
$$;

create or replace function private.user_has_active_pilot_enrollment(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.pilot_enrollments enrollment
    join public.partner_organizations organization
      on organization.id = enrollment.organization_id
     and organization.status = 'verified'
     and organization.pilot_approved
     and organization.environment = private.user_trust_environment(p_user_id)
     and (organization.expires_at is null or organization.expires_at > now())
    where enrollment.user_id = p_user_id
      and enrollment.status = 'approved'
      and enrollment.revoked_at is null
      and enrollment.expires_at > now()
  );
$$;

create or replace function private.is_sandbox_pilot_user(p_user_id uuid)
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
      and profile.is_test_account
      and profile.account_status = 'active'
  );
$$;

create or replace function private.document_collection_operationally_ready()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(policy.real_document_collection_enabled, false)
    and not coalesce(policy.unrestricted_public_access_enabled, false)
    and not exists (
      select 1
      from private.document_operational_readiness_gates gate_record
      where not gate_record.passed
    )
  from private.current_pilot_policy() policy;
$$;

revoke all on function private.has_active_partner_permission(uuid, uuid, text),
  private.user_has_active_pilot_enrollment(uuid),
  private.is_sandbox_pilot_user(uuid),
  private.document_collection_operationally_ready()
from public, anon, authenticated;

alter table private.pilot_policy_versions enable row level security;
alter table public.partner_staff enable row level security;
alter table public.partner_permissions enable row level security;
alter table public.partner_attestations enable row level security;
alter table public.pilot_enrollments enable row level security;
alter table public.pilot_participant_acknowledgements enable row level security;
alter table public.pilot_job_reviews enable row level security;
alter table public.document_review_cases enable row level security;
alter table public.document_review_assignments enable row level security;
alter table public.document_review_decisions enable row level security;
alter table public.document_review_appeals enable row level security;
alter table private.document_vault_objects enable row level security;
alter table private.document_vault_access_grants enable row level security;
alter table private.document_vault_audit_events enable row level security;
alter table private.document_retention_actions enable row level security;
alter table private.document_operational_readiness_gates enable row level security;
alter table public.discreet_mode_preferences enable row level security;
alter table public.trusted_devices enable row level security;
alter table public.support_circles enable row level security;
alter table public.support_circle_members enable row level security;
alter table public.support_circle_permissions enable row level security;
alter table public.support_circle_alert_events enable row level security;
alter table public.work_earning_entries enable row level security;
alter table public.independence_goals enable row level security;
alter table public.future_independence_plans enable row level security;
alter table public.future_independence_tasks enable row level security;
alter table public.skill_passport_entries enable row level security;
alter table public.work_reference_requests enable row level security;
alter table public.resource_directory_entries enable row level security;
alter table public.private_resource_bookmarks enable row level security;
alter table public.resource_directory_reports enable row level security;

create policy partner_staff_select_scoped
on public.partner_staff for select to authenticated
using (
  user_id = (select auth.uid())
  or private.has_trust_admin_role(
    (select auth.uid()),
    array['affiliation_reviewer', 'super_admin']::text[]
  )
);

create policy partner_permissions_select_scoped
on public.partner_permissions for select to authenticated
using (
  exists (
    select 1 from public.partner_staff staff
    where staff.id = partner_permissions.partner_staff_id
      and staff.user_id = (select auth.uid())
  )
  or private.has_trust_admin_role(
    (select auth.uid()),
    array['affiliation_reviewer', 'super_admin']::text[]
  )
);

create policy partner_attestations_select_scoped
on public.partner_attestations for select to authenticated
using (
  subject_user_id = (select auth.uid())
  or private.has_active_partner_permission(
    (select auth.uid()), organization_id, 'view_connected_participants'
  )
  or private.has_trust_admin_role(
    (select auth.uid()),
    array['affiliation_reviewer', 'child_safety_specialist', 'super_admin']::text[]
  )
);

create policy pilot_enrollments_select_scoped
on public.pilot_enrollments for select to authenticated
using (
  user_id = (select auth.uid())
  or private.has_active_partner_permission(
    (select auth.uid()), organization_id, 'view_connected_participants'
  )
  or private.has_trust_admin_role(
    (select auth.uid()),
    array['affiliation_reviewer', 'child_safety_specialist', 'super_admin']::text[]
  )
);

create policy pilot_acknowledgements_select_own
on public.pilot_participant_acknowledgements for select to authenticated
using (user_id = (select auth.uid()));

create policy document_cases_select_subject_or_assigned_reviewer
on public.document_review_cases for select to authenticated
using (
  subject_user_id = (select auth.uid())
  or exists (
    select 1
    from public.document_review_assignments assignment
    where assignment.case_id = document_review_cases.id
      and assignment.reviewer_id = (select auth.uid())
      and assignment.status = 'assigned'
  )
);

create policy document_assignments_select_assigned
on public.document_review_assignments for select to authenticated
using (reviewer_id = (select auth.uid()));

create policy document_decisions_select_subject_or_reviewer
on public.document_review_decisions for select to authenticated
using (
  reviewer_id = (select auth.uid())
  or exists (
    select 1 from public.document_review_cases review_case
    where review_case.id = document_review_decisions.case_id
      and review_case.subject_user_id = (select auth.uid())
  )
);

create policy document_appeals_select_own_or_assigned
on public.document_review_appeals for select to authenticated
using (
  appellant_id = (select auth.uid())
  or exists (
    select 1 from public.document_review_assignments assignment
    where assignment.case_id = document_review_appeals.case_id
      and assignment.reviewer_id = (select auth.uid())
      and assignment.status = 'assigned'
  )
);

create policy document_appeals_insert_own
on public.document_review_appeals for insert to authenticated
with check (
  appellant_id = (select auth.uid())
  and exists (
    select 1 from public.document_review_cases review_case
    where review_case.id = case_id
      and review_case.subject_user_id = (select auth.uid())
  )
);

create policy discreet_preferences_own
on public.discreet_mode_preferences for all to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

create policy trusted_devices_own
on public.trusted_devices for all to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

create policy support_circles_participant_select
on public.support_circles for select to authenticated
using (
  teen_id = (select auth.uid())
  or exists (
    select 1 from public.support_circle_members member
    where member.circle_id = support_circles.id
      and member.member_user_id = (select auth.uid())
      and member.status = 'active'
  )
);

create policy support_circles_teen_manage
on public.support_circles for all to authenticated
using (teen_id = (select auth.uid()))
with check (
  teen_id = (select auth.uid())
  and public.current_profile_role() = 'teen'
);

create policy support_circle_members_scoped_select
on public.support_circle_members for select to authenticated
using (
  member_user_id = (select auth.uid())
  or exists (
    select 1 from public.support_circles circle_record
    where circle_record.id = support_circle_members.circle_id
      and circle_record.teen_id = (select auth.uid())
  )
);

create policy support_circle_permissions_scoped_select
on public.support_circle_permissions for select to authenticated
using (
  exists (
    select 1
    from public.support_circle_members member
    join public.support_circles circle_record on circle_record.id = member.circle_id
    where member.id = support_circle_permissions.member_id
      and (
        member.member_user_id = (select auth.uid())
        or circle_record.teen_id = (select auth.uid())
      )
  )
);

create policy support_circle_alerts_recipient_or_owner
on public.support_circle_alert_events for select to authenticated
using (
  teen_id = (select auth.uid())
  or exists (
    select 1 from public.support_circle_members member
    where member.id = support_circle_alert_events.member_id
      and member.member_user_id = (select auth.uid())
      and member.status = 'active'
  )
);

create policy work_earnings_own
on public.work_earning_entries for all to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()) and public.current_profile_role() = 'teen');

create policy independence_goals_own
on public.independence_goals for all to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()) and public.current_profile_role() = 'teen');

create policy future_plans_own
on public.future_independence_plans for all to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()) and public.current_profile_role() = 'teen');

create policy future_tasks_own
on public.future_independence_tasks for all to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()) and public.current_profile_role() = 'teen');

create policy skill_passport_own
on public.skill_passport_entries for all to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()) and public.current_profile_role() = 'teen');

create policy work_references_participants
on public.work_reference_requests for select to authenticated
using (
  requester_id = (select auth.uid())
  or requested_from = (select auth.uid())
);

create policy work_references_requester_insert
on public.work_reference_requests for insert to authenticated
with check (
  requester_id = (select auth.uid())
  and exists (
    select 1 from public.applications application
    where application.id = application_id
      and application.teen_id = (select auth.uid())
      and application.status = 'completed'
  )
);

create policy work_references_participant_update
on public.work_reference_requests for update to authenticated
using (
  requester_id = (select auth.uid())
  or requested_from = (select auth.uid())
)
with check (
  requester_id = (select auth.uid())
  or requested_from = (select auth.uid())
);

create policy resource_directory_reviewed_select
on public.resource_directory_entries for select to authenticated
using (
  source_status in ('official', 'reviewed')
  or private.has_trust_admin_role(
    (select auth.uid()),
    array['support_agent', 'child_safety_specialist', 'super_admin']::text[]
  )
);

create policy resource_bookmarks_own
on public.private_resource_bookmarks for all to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

create policy resource_reports_own_select
on public.resource_directory_reports for select to authenticated
using (
  reporter_id = (select auth.uid())
  or private.has_trust_admin_role(
    (select auth.uid()),
    array['support_agent', 'child_safety_specialist', 'super_admin']::text[]
  )
);

create policy resource_reports_own_insert
on public.resource_directory_reports for insert to authenticated
with check (reporter_id = (select auth.uid()));

-- Restrictive policies close feed access to random authenticated or anonymous
-- accounts while preserving owners, existing application participants, admins,
-- and isolated sandbox QA.
create policy jobs_closed_pilot_authenticated_gate
on public.jobs as restrictive for select to authenticated
using (
  poster_id = (select auth.uid())
  or public.is_admin()
  or exists (
    select 1 from public.applications application
    where application.job_id = jobs.id
      and public.is_application_participant(application.id)
  )
  or (
    status = 'open'
    and applications_open
    and pilot_review_status = 'eligible'
    and (
      private.user_has_active_pilot_enrollment((select auth.uid()))
      or (
        jobs.is_test
        and private.is_sandbox_pilot_user((select auth.uid()))
      )
    )
  )
);

create policy jobs_closed_pilot_anon_gate
on public.jobs as restrictive for select to anon
using (false);

grant select on table public.partner_staff,
  public.partner_permissions,
  public.partner_attestations,
  public.pilot_enrollments,
  public.pilot_participant_acknowledgements,
  public.document_review_cases,
  public.document_review_assignments,
  public.document_review_decisions,
  public.document_review_appeals,
  public.support_circles,
  public.support_circle_members,
  public.support_circle_permissions,
  public.support_circle_alert_events,
  public.resource_directory_entries
to authenticated;

grant insert on table public.document_review_appeals to authenticated;

grant select, insert, update, delete on table public.discreet_mode_preferences,
  public.trusted_devices,
  public.work_earning_entries,
  public.independence_goals,
  public.future_independence_plans,
  public.future_independence_tasks,
  public.skill_passport_entries,
  public.work_reference_requests,
  public.private_resource_bookmarks,
  public.resource_directory_reports
to authenticated;

grant select, insert, update, delete on table public.partner_staff,
  public.partner_permissions,
  public.partner_attestations,
  public.pilot_enrollments,
  public.pilot_participant_acknowledgements,
  public.pilot_job_reviews,
  public.document_review_cases,
  public.document_review_assignments,
  public.document_review_decisions,
  public.document_review_appeals,
  public.discreet_mode_preferences,
  public.trusted_devices,
  public.support_circles,
  public.support_circle_members,
  public.support_circle_permissions,
  public.support_circle_alert_events,
  public.work_earning_entries,
  public.independence_goals,
  public.future_independence_plans,
  public.future_independence_tasks,
  public.skill_passport_entries,
  public.work_reference_requests,
  public.resource_directory_entries,
  public.private_resource_bookmarks,
  public.resource_directory_reports
to service_role;

create or replace function public.get_closed_pilot_eligibility(
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
  v_policy private.pilot_policy_versions%rowtype;
  v_enrollment public.pilot_enrollments%rowtype;
  v_email_confirmed boolean := false;
  v_phone_confirmed boolean := false;
  v_missing jsonb := '[]'::jsonb;
  v_reasons jsonb := '[]'::jsonb;
  v_required_acknowledgements text[] := '{}';
  v_allowed boolean := false;
  v_job_eligible boolean := true;
begin
  if p_action not in (
    'browse', 'publish_job', 'apply', 'message', 'start_job',
    'submit_proof', 'complete_job', 'manage_support_circle',
    'manage_independence_plan'
  ) then
    return jsonb_build_object(
      'allowed', false,
      'code', 'unsupported_action',
      'guardian_mode_optional', true,
      'permanent_address_required', false
    );
  end if;

  if v_user_id is null then
    return jsonb_build_object(
      'allowed', false,
      'code', 'authentication_required',
      'guardian_mode_optional', true,
      'permanent_address_required', false
    );
  end if;

  select * into v_profile
  from public.profiles profile
  where profile.id = v_user_id;
  select * into v_policy from private.current_pilot_policy();

  if v_profile.id is null or v_profile.account_status <> 'active'
     or (v_profile.blocked_until is not null and v_profile.blocked_until > now()) then
    v_missing := v_missing || jsonb_build_array('active_account');
    v_reasons := v_reasons || jsonb_build_array('account_restricted');
  end if;

  select user_record.email_confirmed_at is not null,
         user_record.phone_confirmed_at is not null
  into v_email_confirmed, v_phone_confirmed
  from auth.users user_record
  where user_record.id = v_user_id;

  if not v_email_confirmed then
    v_missing := v_missing || jsonb_build_array('confirmed_email');
    v_reasons := v_reasons || jsonb_build_array('email_not_confirmed');
  end if;

  select * into v_enrollment
  from public.pilot_enrollments enrollment
  where enrollment.user_id = v_user_id
    and enrollment.status = 'approved'
    and enrollment.revoked_at is null
    and enrollment.expires_at > now()
  order by enrollment.approved_at desc
  limit 1;

  if v_enrollment.id is null
     or not private.user_has_active_pilot_enrollment(v_user_id) then
    v_missing := v_missing || jsonb_build_array('approved_partner_supported_pilot_enrollment');
    v_reasons := v_reasons || jsonb_build_array('closed_pilot_enrollment_required');
  end if;

  if v_profile.role = 'teen' then
    v_required_acknowledgements := array['teen_safety_training', 'pilot_rules', 'explicit_consent'];
  elsif v_profile.role in ('adult', 'admin') then
    v_required_acknowledgements := array[
      'adult_safety_training', 'prohibited_work', 'payment_scope',
      'incident_policy', 'pilot_rules'
    ];
    if not v_phone_confirmed then
      v_missing := v_missing || jsonb_build_array('confirmed_phone');
      v_reasons := v_reasons || jsonb_build_array('adult_phone_not_confirmed');
    end if;
  end if;

  if exists (
    select 1
    from unnest(v_required_acknowledgements) required_acknowledgement
    where not exists (
      select 1
      from public.pilot_participant_acknowledgements acknowledgement
      where acknowledgement.user_id = v_user_id
        and acknowledgement.acknowledgement_type = required_acknowledgement
        and acknowledgement.policy_version = v_policy.version
        and acknowledgement.revoked_at is null
    )
  ) then
    v_missing := v_missing || jsonb_build_array('current_pilot_training_and_acknowledgements');
    v_reasons := v_reasons || jsonb_build_array('pilot_training_incomplete');
  end if;

  if p_job_id is not null then
    select exists (
      select 1 from public.jobs job
      where job.id = p_job_id
        and job.status = 'open'
        and job.applications_open
        and job.pilot_review_status = 'eligible'
    ) into v_job_eligible;
    if not v_job_eligible then
      v_missing := v_missing || jsonb_build_array('pilot_eligible_job');
      v_reasons := v_reasons || jsonb_build_array('job_not_pilot_eligible');
    end if;
  end if;

  if not v_policy.pilot_mode_enabled then
    v_missing := v_missing || jsonb_build_array('active_closed_pilot_policy');
    v_reasons := v_reasons || jsonb_build_array('pilot_disabled');
  end if;

  v_allowed := jsonb_array_length(v_missing) = 0
    and v_policy.pilot_mode_enabled
    and not v_policy.unrestricted_public_access_enabled;

  return jsonb_build_object(
    'allowed', v_allowed,
    'action', p_action,
    'code', case when v_allowed then 'closed_pilot_eligible' else 'closed_pilot_requirements_missing' end,
    'missing_requirements', v_missing,
    'reason_codes', v_reasons,
    'policy_version', v_policy.version,
    'pilot_mode_enabled', v_policy.pilot_mode_enabled,
    'unrestricted_public_access_enabled', false,
    'real_document_collection_enabled', false,
    'guardian_mode_optional', true,
    'guardian_connection_required', false,
    'permanent_address_required', false,
    'housing_status_collected', false,
    'support_circle_affects_eligibility', false
  );
end;
$$;

create or replace function public.submit_pilot_enrollment_request(
  p_organization_id uuid,
  p_source_type text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile public.profiles%rowtype;
  v_organization public.partner_organizations%rowtype;
  v_enrollment public.pilot_enrollments%rowtype;
  v_relationship_exists boolean := false;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_source_type not in ('partner_code', 'verified_partner_email', 'partner_staff_attestation') then
    return jsonb_build_object('ok', false, 'code', 'unsupported_enrollment_source');
  end if;

  select * into v_profile from public.profiles profile where profile.id = auth.uid();
  select * into v_organization
  from public.partner_organizations organization
  where organization.id = p_organization_id
    and organization.status = 'verified'
    and organization.pilot_approved
    and (organization.expires_at is null or organization.expires_at > now());
  if v_profile.id is null or v_organization.id is null then
    return jsonb_build_object('ok', false, 'code', 'approved_partner_required');
  end if;
  if v_organization.environment <> private.user_trust_environment(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'partner_environment_mismatch');
  end if;

  select (
    exists (
      select 1 from public.partner_memberships membership
      where membership.user_id = auth.uid()
        and membership.organization_id = p_organization_id
        and membership.status = 'active'
        and membership.revoked_at is null
        and membership.expires_at > now()
    )
    or exists (
      select 1 from public.partner_attestations attestation
      where attestation.subject_user_id = auth.uid()
        and attestation.organization_id = p_organization_id
        and attestation.status = 'active'
        and attestation.expires_at > now()
    )
  ) into v_relationship_exists;
  if not v_relationship_exists then
    return jsonb_build_object('ok', false, 'code', 'partner_relationship_not_confirmed');
  end if;

  select * into v_enrollment
  from public.pilot_enrollments enrollment
  where enrollment.user_id = auth.uid()
    and enrollment.organization_id = p_organization_id
    and enrollment.status in ('pending', 'approved')
    and enrollment.revoked_at is null
  order by enrollment.created_at desc
  limit 1;
  if v_enrollment.id is null then
    insert into public.pilot_enrollments (
      user_id, organization_id, source_type, participation_role
    ) values (
      auth.uid(), p_organization_id, p_source_type, v_profile.role::text
    ) returning * into v_enrollment;
  end if;

  return jsonb_build_object(
    'ok', true,
    'enrollment_id', v_enrollment.id,
    'status', v_enrollment.status,
    'manual_approval_required', true,
    'guardian_mode_optional', true,
    'permanent_address_required', false,
    'message', 'Your closed-pilot enrollment is pending authorized review.'
  );
end;
$$;

create or replace function public.acknowledge_pilot_policy(
  p_acknowledgement_type text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_policy private.pilot_policy_versions%rowtype;
  v_acknowledgement public.pilot_participant_acknowledgements%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_acknowledgement_type not in (
    'teen_safety_training', 'adult_safety_training', 'prohibited_work',
    'payment_scope', 'incident_policy', 'pilot_rules', 'explicit_consent'
  ) then
    return jsonb_build_object('ok', false, 'code', 'unsupported_acknowledgement');
  end if;
  select * into v_policy from private.current_pilot_policy();
  insert into public.pilot_participant_acknowledgements (
    user_id, acknowledgement_type, policy_version
  ) values (
    auth.uid(), p_acknowledgement_type, v_policy.version
  )
  on conflict (user_id, acknowledgement_type, policy_version)
  do update set acknowledged_at = now(), revoked_at = null
  returning * into v_acknowledgement;
  return jsonb_build_object(
    'ok', true,
    'acknowledgement_type', v_acknowledgement.acknowledgement_type,
    'policy_version', v_acknowledgement.policy_version
  );
end;
$$;

create or replace function public.get_my_partner_attestations()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'ok', true,
    'identity_verified', false,
    'government_id_verified', false,
    'attestations', coalesce(jsonb_agg(jsonb_build_object(
      'id', attestation.id,
      'fact_type', attestation.fact_type,
      'version', attestation.attestation_version,
      'status', attestation.status,
      'statement', attestation.attestation_statement,
      'what_was_not_established', attestation.what_was_not_established,
      'effective_at', attestation.effective_at,
      'expires_at', attestation.expires_at
    ) order by attestation.created_at desc) filter (where attestation.id is not null), '[]'::jsonb)
  )
  from public.partner_attestations attestation
  where attestation.subject_user_id = auth.uid();
$$;

create or replace function public.get_partner_connected_participants(
  p_organization_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_items jsonb;
begin
  if auth.uid() is null
     or not private.has_active_partner_permission(
       auth.uid(), p_organization_id, 'view_connected_participants'
     ) then
    return jsonb_build_object('ok', false, 'code', 'partner_permission_required');
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'user_id', enrollment.user_id,
    'display_name', profile.display_name,
    'role', profile.role,
    'enrollment_status', enrollment.status,
    'expires_at', enrollment.expires_at
  ) order by profile.display_name), '[]'::jsonb)
  into v_items
  from public.pilot_enrollments enrollment
  join public.profiles profile on profile.id = enrollment.user_id
  where enrollment.organization_id = p_organization_id
    and enrollment.status in ('pending', 'approved')
    and enrollment.revoked_at is null;
  insert into public.partner_audit_events (
    actor_id, organization_id, action, resource_type, access_reason, event_data
  ) values (
    auth.uid(), p_organization_id, 'view_connected_participants',
    'pilot_enrollment', 'Partner staff opened the minimum connected-participant roster.',
    jsonb_build_object('message_content_included', false, 'earnings_included', false)
  );
  return jsonb_build_object(
    'ok', true,
    'items', v_items,
    'messages_included', false,
    'earnings_included', false,
    'housing_status_included', false
  );
end;
$$;

create or replace function public.submit_partner_attestation(
  p_subject_user_id uuid,
  p_organization_id uuid,
  p_fact_type text,
  p_expires_at timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_staff public.partner_staff%rowtype;
  v_permission text;
  v_version integer;
  v_statement text;
  v_attestation public.partner_attestations%rowtype;
  v_connected boolean := false;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  v_permission := case p_fact_type
    when 'person_appeared_before_partner' then 'attest_person_appeared'
    when 'school_or_program_affiliation' then 'attest_affiliation'
    when 'approximate_age_band_eligible' then 'attest_age_band'
    when 'partner_program_participation' then 'attest_program_participation'
    when 'staff_identity_confirmed' then 'attest_affiliation'
    when 'partner_relationship_confirmed' then 'attest_affiliation'
    else null
  end;
  if v_permission is null
     or not private.has_active_partner_permission(auth.uid(), p_organization_id, v_permission) then
    return jsonb_build_object('ok', false, 'code', 'partner_attestation_permission_required');
  end if;
  select * into v_staff
  from public.partner_staff staff
  where staff.user_id = auth.uid()
    and staff.organization_id = p_organization_id
    and staff.status = 'active'
    and staff.revoked_at is null
    and (staff.expires_at is null or staff.expires_at > now());
  if v_staff.id is null then
    return jsonb_build_object('ok', false, 'code', 'active_partner_staff_required');
  end if;
  if p_expires_at <= now() or p_expires_at > now() + interval '1 year' then
    return jsonb_build_object('ok', false, 'code', 'attestation_expiry_invalid');
  end if;
  select exists (
    select 1 from public.partner_memberships membership
    where membership.user_id = p_subject_user_id
      and membership.organization_id = p_organization_id
      and membership.status = 'active'
      and membership.revoked_at is null
      and membership.expires_at > now()
    union all
    select 1 from public.pilot_enrollments enrollment
    where enrollment.user_id = p_subject_user_id
      and enrollment.organization_id = p_organization_id
      and enrollment.status in ('pending', 'approved')
      and enrollment.revoked_at is null
  ) into v_connected;
  if not v_connected then
    return jsonb_build_object('ok', false, 'code', 'subject_not_connected_to_partner');
  end if;

  v_statement := case p_fact_type
    when 'person_appeared_before_partner' then 'A qualified partner staff member attested that the participant appeared before the partner.'
    when 'school_or_program_affiliation' then 'A qualified partner staff member attested to current school or program affiliation.'
    when 'approximate_age_band_eligible' then 'A qualified partner staff member attested that the participant is within the pilot age band.'
    when 'partner_program_participation' then 'A qualified partner staff member attested to participation in the partner program.'
    when 'staff_identity_confirmed' then 'The approved organization confirmed the staff relationship associated with this attestation.'
    else 'A qualified partner staff member attested to the participant relationship with the organization.'
  end;
  select coalesce(max(attestation.attestation_version), 0) + 1 into v_version
  from public.partner_attestations attestation
  where attestation.organization_id = p_organization_id
    and attestation.subject_user_id = p_subject_user_id
    and attestation.fact_type = p_fact_type;

  update public.partner_attestations attestation
  set status = 'superseded'
  where attestation.organization_id = p_organization_id
    and attestation.subject_user_id = p_subject_user_id
    and attestation.fact_type = p_fact_type
    and attestation.status = 'active';

  insert into public.partner_attestations (
    organization_id, partner_staff_id, subject_user_id, fact_type,
    attestation_version, attestation_statement, what_was_not_established,
    expires_at
  ) values (
    p_organization_id, v_staff.id, p_subject_user_id, p_fact_type,
    v_version, v_statement,
    'This attestation does not establish government identity, document authenticity, legal name, residential address, account ownership, or a safety guarantee.',
    p_expires_at
  ) returning * into v_attestation;

  insert into public.partner_audit_events (
    actor_id, organization_id, subject_user_id, action, resource_type,
    resource_id, access_reason, event_version, event_data
  ) values (
    auth.uid(), p_organization_id, p_subject_user_id,
    'partner_attestation_created', 'partner_attestation', v_attestation.id,
    'Authorized partner staff recorded a versioned, limited-scope attestation.',
    v_version,
    jsonb_build_object('fact_type', p_fact_type, 'government_identity_effect', false)
  );

  insert into public.trust_signal_events (
    user_id, signal_type, category, status, environment, source_kind,
    source_reference, public_label, what_was_checked, what_was_not_checked,
    checked_at, expires_at, public_visibility, grants_marketplace_access,
    metadata, created_by
  ) values (
    p_subject_user_id,
    case
      when p_fact_type = 'approximate_age_band_eligible' then 'partner_age_band_attestation'
      else 'partner_organization_attestation'
    end,
    'affiliation', 'verified', private.user_trust_environment(p_subject_user_id),
    'moderation', v_attestation.id::text,
    case
      when p_fact_type = 'approximate_age_band_eligible' then 'Age-band eligibility attested'
      else 'Partner organization confirmed'
    end,
    v_statement,
    'Government identity, document authenticity, legal name, address, account ownership, and safety were not verified.',
    now(), p_expires_at, false, false,
    jsonb_build_object('attestation_id', v_attestation.id, 'fact_type', p_fact_type),
    auth.uid()
  );

  return jsonb_build_object(
    'ok', true,
    'attestation_id', v_attestation.id,
    'version', v_version,
    'public_label', case
      when p_fact_type = 'approximate_age_band_eligible' then 'Age-band eligibility attested'
      else 'Partner organization confirmed'
    end,
    'government_identity_verified', false,
    'provider_identity_verified', false,
    'grants_marketplace_access', false
  );
end;
$$;

create or replace function public.revoke_partner_attestation(
  p_attestation_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_attestation public.partner_attestations%rowtype;
begin
  select * into v_attestation
  from public.partner_attestations attestation
  where attestation.id = p_attestation_id;
  if v_attestation.id is null then
    return jsonb_build_object('ok', false, 'code', 'attestation_not_found');
  end if;
  if char_length(btrim(coalesce(p_reason, ''))) not between 8 and 800 then
    return jsonb_build_object('ok', false, 'code', 'revocation_reason_required');
  end if;
  if not (
    private.has_active_partner_permission(
      auth.uid(), v_attestation.organization_id,
      case v_attestation.fact_type
        when 'person_appeared_before_partner' then 'attest_person_appeared'
        when 'approximate_age_band_eligible' then 'attest_age_band'
        when 'partner_program_participation' then 'attest_program_participation'
        else 'attest_affiliation'
      end
    )
    or private.has_trust_admin_role(
      auth.uid(), array['affiliation_reviewer', 'super_admin']::text[]
    )
  ) then
    return jsonb_build_object('ok', false, 'code', 'attestation_revocation_permission_required');
  end if;
  update public.partner_attestations
  set status = 'revoked', revoked_at = now(), revocation_reason = btrim(p_reason)
  where id = p_attestation_id;
  update public.trust_signal_events
  set status = 'revoked', revoked_at = now(), updated_at = now()
  where source_reference = p_attestation_id::text
    and source_kind = 'moderation';
  insert into public.partner_audit_events (
    actor_id, organization_id, subject_user_id, action, resource_type,
    resource_id, access_reason, event_version
  ) values (
    auth.uid(), v_attestation.organization_id, v_attestation.subject_user_id,
    'partner_attestation_revoked', 'partner_attestation', p_attestation_id,
    btrim(p_reason), v_attestation.attestation_version
  );
  return jsonb_build_object(
    'ok', true,
    'status', 'revoked',
    'only_associated_indicator_removed', true
  );
end;
$$;

create or replace function public.admin_assign_partner_staff(
  p_organization_id uuid,
  p_user_id uuid,
  p_staff_role text,
  p_expires_at timestamptz,
  p_access_reason text,
  p_case_id text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_staff public.partner_staff%rowtype;
begin
  if not private.trust_admin_context_valid(p_access_reason, p_case_id)
     or not private.has_trust_admin_role(
       auth.uid(), array['affiliation_reviewer', 'super_admin']::text[]
     ) then
    return jsonb_build_object('ok', false, 'code', 'affiliation_reviewer_required');
  end if;
  if p_staff_role not in (
    'staff', 'school_liaison', 'program_coordinator', 'case_worker',
    'shelter_staff', 'workforce_coach', 'organization_admin'
  ) or p_expires_at <= now() or p_expires_at > now() + interval '1 year' then
    return jsonb_build_object('ok', false, 'code', 'partner_staff_assignment_invalid');
  end if;
  if not exists (
    select 1 from public.partner_organizations organization
    where organization.id = p_organization_id
      and organization.status = 'verified'
      and organization.pilot_approved
  ) then
    return jsonb_build_object('ok', false, 'code', 'approved_partner_required');
  end if;
  insert into public.partner_staff (
    organization_id, user_id, staff_role, status, verified_by,
    verified_at, expires_at
  ) values (
    p_organization_id, p_user_id, p_staff_role, 'active', auth.uid(),
    now(), p_expires_at
  ) returning * into v_staff;
  insert into public.partner_audit_events (
    actor_id, organization_id, subject_user_id, action, resource_type,
    resource_id, access_reason, case_id
  ) values (
    auth.uid(), p_organization_id, p_user_id, 'partner_staff_assigned',
    'partner_staff', v_staff.id, btrim(p_access_reason), btrim(p_case_id)
  );
  return jsonb_build_object('ok', true, 'partner_staff_id', v_staff.id, 'status', 'active');
end;
$$;

create or replace function public.admin_set_partner_permission(
  p_partner_staff_id uuid,
  p_permission_key text,
  p_enabled boolean,
  p_access_reason text,
  p_case_id text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_staff public.partner_staff%rowtype;
  v_permission public.partner_permissions%rowtype;
begin
  if not private.trust_admin_context_valid(p_access_reason, p_case_id)
     or not private.has_trust_admin_role(
       auth.uid(), array['affiliation_reviewer', 'super_admin']::text[]
     ) then
    return jsonb_build_object('ok', false, 'code', 'affiliation_reviewer_required');
  end if;
  select * into v_staff from public.partner_staff staff where staff.id = p_partner_staff_id;
  if v_staff.id is null then
    return jsonb_build_object('ok', false, 'code', 'partner_staff_not_found');
  end if;
  insert into public.partner_permissions (
    partner_staff_id, permission_key, enabled, granted_by, grant_reason,
    revoked_at
  ) values (
    p_partner_staff_id, p_permission_key, p_enabled, auth.uid(),
    btrim(p_access_reason), case when p_enabled then null else now() end
  )
  on conflict (partner_staff_id, permission_key)
  do update set enabled = excluded.enabled,
                granted_by = excluded.granted_by,
                grant_reason = excluded.grant_reason,
                granted_at = now(),
                revoked_at = excluded.revoked_at
  returning * into v_permission;
  insert into public.partner_audit_events (
    actor_id, organization_id, subject_user_id, action, resource_type,
    resource_id, access_reason, case_id, event_data
  ) values (
    auth.uid(), v_staff.organization_id, v_staff.user_id,
    'partner_permission_changed', 'partner_permission', v_permission.id,
    btrim(p_access_reason), btrim(p_case_id),
    jsonb_build_object('permission_key', p_permission_key, 'enabled', p_enabled)
  );
  return jsonb_build_object('ok', true, 'permission_key', p_permission_key, 'enabled', p_enabled);
end;
$$;

create or replace function public.admin_review_pilot_enrollment(
  p_enrollment_id uuid,
  p_approve boolean,
  p_expires_at timestamptz,
  p_decision_reason text,
  p_case_id text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_enrollment public.pilot_enrollments%rowtype;
begin
  if not private.trust_admin_context_valid(p_decision_reason, p_case_id)
     or not private.has_trust_admin_role(
       auth.uid(), array['affiliation_reviewer', 'child_safety_specialist', 'super_admin']::text[]
     ) then
    return jsonb_build_object('ok', false, 'code', 'pilot_reviewer_required');
  end if;
  select * into v_enrollment
  from public.pilot_enrollments enrollment
  where enrollment.id = p_enrollment_id
  for update;
  if v_enrollment.id is null then
    return jsonb_build_object('ok', false, 'code', 'pilot_enrollment_not_found');
  end if;
  if p_approve and (p_expires_at is null or p_expires_at <= now() or p_expires_at > now() + interval '1 year') then
    return jsonb_build_object('ok', false, 'code', 'pilot_enrollment_expiry_invalid');
  end if;
  update public.pilot_enrollments
  set status = case when p_approve then 'approved' else 'denied' end,
      approved_by = case when p_approve then auth.uid() else null end,
      approved_at = case when p_approve then now() else null end,
      expires_at = case when p_approve then p_expires_at else null end,
      decision_reason = btrim(p_decision_reason),
      updated_at = now()
  where id = p_enrollment_id;
  insert into public.partner_audit_events (
    actor_id, organization_id, subject_user_id, action, resource_type,
    resource_id, access_reason, case_id
  ) values (
    auth.uid(), v_enrollment.organization_id, v_enrollment.user_id,
    case when p_approve then 'pilot_enrollment_approved' else 'pilot_enrollment_denied' end,
    'pilot_enrollment', p_enrollment_id, btrim(p_decision_reason), btrim(p_case_id)
  );
  return jsonb_build_object(
    'ok', true,
    'status', case when p_approve then 'approved' else 'denied' end,
    'guardian_mode_optional', true,
    'permanent_address_required', false
  );
end;
$$;

create or replace function private.create_pending_pilot_enrollment_from_membership()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role text;
begin
  if new.status <> 'active' or new.revoked_at is not null then
    return new;
  end if;
  if not exists (
    select 1 from public.partner_organizations organization
    where organization.id = new.organization_id
      and organization.status = 'verified'
      and organization.pilot_approved
  ) then
    return new;
  end if;
  select profile.role::text into v_role
  from public.profiles profile where profile.id = new.user_id;
  if v_role is null or v_role not in ('teen', 'adult', 'guardian') then
    return new;
  end if;
  if not exists (
    select 1 from public.pilot_enrollments enrollment
    where enrollment.user_id = new.user_id
      and enrollment.organization_id = new.organization_id
      and enrollment.status in ('pending', 'approved')
      and enrollment.revoked_at is null
  ) then
    insert into public.pilot_enrollments (
      user_id, organization_id, source_type, participation_role
    ) values (
      new.user_id, new.organization_id,
      case when new.verification_method in ('partner_code', 'program_code')
        then 'partner_code' else 'verified_partner_email' end,
      v_role
    );
  end if;
  return new;
end;
$$;

create trigger partner_membership_create_pilot_request
after insert or update of status, revoked_at on public.partner_memberships
for each row execute function private.create_pending_pilot_enrollment_from_membership();

create or replace function private.evaluate_closed_pilot_job()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_policy private.pilot_policy_versions%rowtype;
  v_profile public.profiles%rowtype;
  v_enrollment public.pilot_enrollments%rowtype;
  v_content text;
  v_reasons text[] := '{}';
  v_blocked boolean := false;
  v_manual boolean := false;
  v_allowed_locations text[] := array[
    'verified_business', 'school', 'nonprofit', 'community_center',
    'public_event', 'staffed_community_project',
    'visible_outdoor_community_space'
  ];
begin
  select * into v_policy from private.current_pilot_policy();
  select * into v_profile from public.profiles profile where profile.id = new.poster_id;

  if new.pilot_location_class = 'unclassified' then
    new.pilot_location_class := case lower(coalesce(new.location_type, ''))
      when 'business' then 'verified_business'
      when 'verified_business' then 'verified_business'
      when 'school' then 'school'
      when 'nonprofit' then 'nonprofit'
      when 'community_center' then 'community_center'
      when 'public_event' then 'public_event'
      when 'public' then 'public_event'
      when 'staffed_community_project' then 'staffed_community_project'
      when 'visible_outdoor' then 'visible_outdoor_community_space'
      when 'private_residence' then 'private_residence'
      when 'hotel' then 'hotel'
      when 'isolated_property' then 'isolated_property'
      when 'unknown' then 'unknown_location'
      else 'unknown_location'
    end;
  end if;

  new.pilot_staffed_or_visible := new.pilot_staffed_or_visible
    or coalesce(new.adult_supervision_present, false)
    or coalesce(new.public_meeting_available, false)
    or new.pilot_location_class in ('verified_business', 'school', 'nonprofit', 'community_center', 'public_event');

  v_content := lower(concat_ws(
    ' ', new.title, new.summary, new.description, new.special_instructions,
    new.safety_notes, new.equipment_provided, new.equipment_worker_brings,
    array_to_string(new.physical_requirements, ' ')
  ));

  if new.pilot_location_class in ('private_residence', 'hotel', 'isolated_property', 'unknown_location') then
    v_reasons := array_append(v_reasons, 'pilot_location_not_allowed');
    v_blocked := true;
  elsif not (new.pilot_location_class = any(v_allowed_locations)) then
    v_reasons := array_append(v_reasons, 'pilot_location_unclassified');
    v_manual := true;
  end if;

  if not new.pilot_staffed_or_visible then
    v_reasons := array_append(v_reasons, 'staffed_or_visible_location_required');
    v_blocked := true;
  end if;

  if v_content ~ '(mbedroomM|mhotelM|movernightM|misolatedM|private property|secret|do not tell|keep this private)' then
    v_reasons := array_append(v_reasons, 'isolation_or_secrecy_prohibited');
    v_blocked := true;
  end if;
  if v_content ~ '(mroofM|dangerous height|scaffold|firearm|mweaponM|mgunM|hazardous chemical|pesticide|alcohol|illegal drug|adult service|sexual service|heavy machinery|industrial machinery)' then
    v_reasons := array_append(v_reasons, 'hazardous_or_prohibited_work');
    v_blocked := true;
  end if;
  if v_content ~ '(poster will drive|I will drive|ride with me|private ride|pick you up|transport you)' then
    v_reasons := array_append(v_reasons, 'poster_transportation_prohibited');
    v_blocked := true;
  elsif coalesce(new.transportation_required, false) then
    v_reasons := array_append(v_reasons, 'transportation_plan_manual_review');
    v_manual := true;
  end if;
  if new.risk_tier::text in ('higher_risk', 'prohibited') then
    v_reasons := array_append(v_reasons, 'job_risk_tier_not_pilot_eligible');
    v_blocked := true;
  end if;
  if new.starts_at is not null
     and extract(hour from new.starts_at at time zone coalesce(new.timezone, 'America/Indianapolis')) not between 6 and 19 then
    v_reasons := array_append(v_reasons, 'overnight_or_late_work_prohibited');
    v_blocked := true;
  end if;
  if new.ends_at is not null
     and extract(hour from new.ends_at at time zone coalesce(new.timezone, 'America/Indianapolis')) > 21 then
    v_reasons := array_append(v_reasons, 'overnight_or_late_work_prohibited');
    v_blocked := true;
  end if;

  if not coalesce(v_profile.is_test_account, false) then
    select * into v_enrollment
    from public.pilot_enrollments enrollment
    where enrollment.user_id = new.poster_id
      and enrollment.status = 'approved'
      and enrollment.revoked_at is null
      and enrollment.expires_at > now()
    order by enrollment.approved_at desc
    limit 1;
    if v_enrollment.id is null
       or not private.user_has_active_pilot_enrollment(new.poster_id) then
      v_reasons := array_append(v_reasons, 'approved_adult_pilot_enrollment_required');
      v_manual := true;
    else
      if new.pilot_organization_id is null then
        new.pilot_organization_id := v_enrollment.organization_id;
      elsif new.pilot_organization_id <> v_enrollment.organization_id then
        v_reasons := array_append(v_reasons, 'pilot_organization_mismatch');
        v_blocked := true;
      end if;
    end if;
  end if;

  if not v_policy.pilot_mode_enabled or v_policy.unrestricted_public_access_enabled then
    v_reasons := array_append(v_reasons, 'closed_pilot_policy_unavailable');
    v_blocked := true;
  end if;

  new.pilot_policy_version := v_policy.version;
  new.pilot_restriction_reasons := v_reasons;
  new.pilot_reviewed_at := now();

  if v_blocked then
    new.pilot_review_status := 'blocked';
  elsif v_manual then
    new.pilot_review_status := 'manual_review_required';
  else
    new.pilot_review_status := 'eligible';
  end if;

  if new.status = 'open' and new.pilot_review_status <> 'eligible' then
    new.status := 'pending_review';
    new.applications_open := false;
  elsif new.status = 'open' then
    new.applications_open := true;
  end if;

  return new;
end;
$$;

create or replace function private.audit_closed_pilot_job_evaluation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT'
     or old.pilot_review_status is distinct from new.pilot_review_status
     or old.pilot_restriction_reasons is distinct from new.pilot_restriction_reasons then
    insert into public.pilot_job_reviews (
      job_id, policy_version, decision, reason_codes, review_method
    ) values (
      new.id, new.pilot_policy_version, new.pilot_review_status,
      new.pilot_restriction_reasons, 'server_rules'
    );
  end if;
  return new;
end;
$$;

create trigger jobs_closed_pilot_evaluate
before insert or update of
  title, summary, description, category, location_type, work_environment,
  starts_at, ends_at, timezone, status, applications_open,
  adult_supervision_present, public_meeting_available, transportation_required,
  risk_tier, special_instructions, safety_notes, pilot_organization_id,
  pilot_location_class, pilot_staffed_or_visible
on public.jobs
for each row execute function private.evaluate_closed_pilot_job();

create trigger jobs_closed_pilot_audit
after insert or update of pilot_review_status, pilot_restriction_reasons
on public.jobs
for each row execute function private.audit_closed_pilot_job_evaluation();

create or replace function private.enforce_closed_pilot_application()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job public.jobs%rowtype;
  v_profile public.profiles%rowtype;
  v_trusted_server boolean := session_user in ('postgres', 'supabase_admin')
    or coalesce(auth.jwt()->>'role', '') = 'service_role';
begin
  if v_trusted_server then
    return new;
  end if;
  if auth.uid() is null or new.teen_id <> auth.uid() then
    raise exception 'closed_pilot_application_authentication_required';
  end if;
  select * into v_job from public.jobs job where job.id = new.job_id;
  select * into v_profile from public.profiles profile where profile.id = new.teen_id;
  if v_job.id is null
     or v_job.status <> 'open'
     or not v_job.applications_open
     or v_job.pilot_review_status <> 'eligible' then
    raise exception 'job_not_closed_pilot_eligible';
  end if;
  if coalesce(v_profile.is_test_account, false) and v_job.is_test then
    return new;
  end if;
  if not private.user_has_active_pilot_enrollment(new.teen_id) then
    raise exception 'approved_teen_pilot_enrollment_required';
  end if;
  return new;
end;
$$;

create trigger applications_closed_pilot_enforce
before insert on public.applications
for each row execute function private.enforce_closed_pilot_application();

create or replace function public.get_pilot_job_eligibility(p_job_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when job.id is null then jsonb_build_object('ok', false, 'code', 'job_not_found')
    else jsonb_build_object(
      'ok', true,
      'job_id', job.id,
      'eligible', job.pilot_review_status = 'eligible' and job.status = 'open' and job.applications_open,
      'review_status', job.pilot_review_status,
      'location_class', job.pilot_location_class,
      'staffed_or_visible', job.pilot_staffed_or_visible,
      'reason_codes', job.pilot_restriction_reasons,
      'policy_version', job.pilot_policy_version,
      'server_owned_decision', true
    )
  end
  from (select 1) seed
  left join public.jobs job on job.id = p_job_id;
$$;

create or replace function public.admin_review_pilot_job(
  p_job_id uuid,
  p_decision text,
  p_reason_codes text[],
  p_access_reason text,
  p_case_id text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job public.jobs%rowtype;
  v_policy private.pilot_policy_versions%rowtype;
begin
  if not private.trust_admin_context_valid(p_access_reason, p_case_id)
     or not private.has_trust_admin_role(
       auth.uid(), array['safety_moderator', 'child_safety_specialist', 'super_admin']::text[]
     ) then
    return jsonb_build_object('ok', false, 'code', 'pilot_job_reviewer_required');
  end if;
  if p_decision not in ('eligible', 'blocked') or cardinality(coalesce(p_reason_codes, '{}')) = 0 then
    return jsonb_build_object('ok', false, 'code', 'pilot_job_decision_invalid');
  end if;
  select * into v_job from public.jobs job where job.id = p_job_id for update;
  if v_job.id is null then
    return jsonb_build_object('ok', false, 'code', 'job_not_found');
  end if;
  select * into v_policy from private.current_pilot_policy();
  update public.jobs
  set pilot_review_status = p_decision,
      pilot_restriction_reasons = p_reason_codes,
      pilot_policy_version = v_policy.version,
      pilot_reviewed_by = auth.uid(),
      pilot_reviewed_at = now(),
      status = case when p_decision = 'eligible' then 'open'::public.job_status else 'rejected'::public.job_status end,
      applications_open = p_decision = 'eligible',
      updated_at = now()
  where id = p_job_id
  returning * into v_job;
  insert into public.pilot_job_reviews (
    job_id, policy_version, decision, reason_codes, reviewer_id, review_method
  ) values (
    p_job_id, v_policy.version, p_decision, p_reason_codes,
    auth.uid(), 'authorized_human_review'
  );
  return jsonb_build_object(
    'ok', true,
    'job_id', p_job_id,
    'decision', p_decision,
    'server_owned_decision', true
  );
end;
$$;

create or replace function public.admin_set_partner_pilot_approval(
  p_organization_id uuid,
  p_approved boolean,
  p_access_reason text,
  p_case_id text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_organization public.partner_organizations%rowtype;
begin
  if not private.trust_admin_context_valid(p_access_reason, p_case_id)
     or not private.has_trust_admin_role(
       auth.uid(), array['affiliation_reviewer', 'child_safety_specialist', 'super_admin']::text[]
     ) then
    return jsonb_build_object('ok', false, 'code', 'pilot_partner_reviewer_required');
  end if;
  select * into v_organization
  from public.partner_organizations organization
  where organization.id = p_organization_id
  for update;
  if v_organization.id is null or (p_approved and v_organization.status <> 'verified') then
    return jsonb_build_object('ok', false, 'code', 'verified_partner_required');
  end if;
  update public.partner_organizations
  set pilot_approved = p_approved,
      pilot_approved_by = case when p_approved then auth.uid() else null end,
      pilot_approved_at = case when p_approved then now() else null end,
      updated_at = now()
  where id = p_organization_id
  returning * into v_organization;
  insert into public.partner_audit_events (
    actor_id, organization_id, action, resource_type, resource_id,
    access_reason, case_id, event_data
  ) values (
    auth.uid(), p_organization_id, 'partner_pilot_approval_changed',
    'partner_organization', p_organization_id, btrim(p_access_reason),
    btrim(p_case_id), jsonb_build_object('pilot_approved', p_approved)
  );
  return jsonb_build_object(
    'ok', true,
    'organization_id', p_organization_id,
    'pilot_approved', v_organization.pilot_approved
  );
end;
$$;

create index partner_staff_organization_idx on public.partner_staff(organization_id);
create index partner_staff_user_idx on public.partner_staff(user_id);
create index partner_staff_verified_by_idx on public.partner_staff(verified_by) where verified_by is not null;
create index partner_permissions_granted_by_idx on public.partner_permissions(granted_by);
create index partner_attestations_organization_idx on public.partner_attestations(organization_id);
create index partner_attestations_supersedes_idx on public.partner_attestations(supersedes_id) where supersedes_id is not null;
create index pilot_enrollments_user_idx on public.pilot_enrollments(user_id);
create index pilot_enrollments_approved_by_idx on public.pilot_enrollments(approved_by) where approved_by is not null;
create index pilot_ack_user_idx on public.pilot_participant_acknowledgements(user_id);
create index jobs_pilot_organization_idx on public.jobs(pilot_organization_id) where pilot_organization_id is not null;
create index jobs_pilot_reviewed_by_idx on public.jobs(pilot_reviewed_by) where pilot_reviewed_by is not null;
create index pilot_job_reviews_reviewer_idx on public.pilot_job_reviews(reviewer_id) where reviewer_id is not null;
create index document_cases_subject_idx on public.document_review_cases(subject_user_id);
create index document_assignments_reviewer_idx on public.document_review_assignments(reviewer_id);
create index document_assignments_assigned_by_idx on public.document_review_assignments(assigned_by);
create index document_decisions_reviewer_idx on public.document_review_decisions(reviewer_id);
create index document_appeals_appellant_idx on public.document_review_appeals(appellant_id);
create index document_appeals_reviewer_idx on public.document_review_appeals(reviewed_by) where reviewed_by is not null;
create index document_vault_case_idx on private.document_vault_objects(case_id);
create index document_vault_grants_object_idx on private.document_vault_access_grants(vault_object_id);
create index document_vault_grants_reviewer_idx on private.document_vault_access_grants(reviewer_id);
create index document_vault_grants_case_idx on private.document_vault_access_grants(case_id);
create index document_vault_audit_object_idx on private.document_vault_audit_events(vault_object_id) where vault_object_id is not null;
create index document_vault_audit_case_idx on private.document_vault_audit_events(case_id, created_at desc);
create index document_vault_audit_actor_idx on private.document_vault_audit_events(actor_id) where actor_id is not null;
create index document_retention_object_idx on private.document_retention_actions(vault_object_id);
create index document_retention_actor_idx on private.document_retention_actions(actor_id) where actor_id is not null;
create index document_gates_approved_by_idx on private.document_operational_readiness_gates(approved_by) where approved_by is not null;
create index support_members_member_idx on public.support_circle_members(member_user_id);
create index support_members_invited_by_idx on public.support_circle_members(invited_by);
create index support_alerts_circle_idx on public.support_circle_alert_events(circle_id, created_at desc);
create index support_alerts_member_idx on public.support_circle_alert_events(member_id, created_at desc);
create index support_alerts_teen_idx on public.support_circle_alert_events(teen_id, created_at desc);
create index work_earnings_application_idx on public.work_earning_entries(application_id) where application_id is not null;
create index independence_goals_user_idx on public.independence_goals(user_id, status);
create index skill_passport_user_idx on public.skill_passport_entries(user_id);
create index skill_passport_application_idx on public.skill_passport_entries(source_application_id) where source_application_id is not null;
create index work_references_application_idx on public.work_reference_requests(application_id);
create index work_references_requested_from_idx on public.work_reference_requests(requested_from);
create index resources_reviewed_by_idx on public.resource_directory_entries(reviewed_by) where reviewed_by is not null;
create index resource_bookmarks_resource_idx on public.private_resource_bookmarks(resource_id);
create index resource_reports_resource_idx on public.resource_directory_reports(resource_id, created_at desc);
create index resource_reports_reporter_idx on public.resource_directory_reports(reporter_id);

create trigger partner_staff_updated_at
before update on public.partner_staff
for each row execute function public.set_updated_at();
create trigger pilot_enrollments_updated_at
before update on public.pilot_enrollments
for each row execute function public.set_updated_at();
create trigger document_review_cases_updated_at
before update on public.document_review_cases
for each row execute function public.set_updated_at();
create trigger discreet_mode_preferences_updated_at
before update on public.discreet_mode_preferences
for each row execute function public.set_updated_at();
create trigger support_circles_updated_at
before update on public.support_circles
for each row execute function public.set_updated_at();
create trigger work_earning_entries_updated_at
before update on public.work_earning_entries
for each row execute function public.set_updated_at();
create trigger independence_goals_updated_at
before update on public.independence_goals
for each row execute function public.set_updated_at();
create trigger future_independence_plans_updated_at
before update on public.future_independence_plans
for each row execute function public.set_updated_at();
create trigger future_independence_tasks_updated_at
before update on public.future_independence_tasks
for each row execute function public.set_updated_at();
create trigger resource_directory_entries_updated_at
before update on public.resource_directory_entries
for each row execute function public.set_updated_at();

create or replace function public.get_document_collection_readiness()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'ready', private.document_collection_operationally_ready(),
    'real_document_collection_enabled', false,
    'client_can_enable', false,
    'collection_status', 'disabled_until_operational_readiness',
    'required_gate_count', count(*),
    'passed_gate_count', count(*) filter (where gate_record.passed),
    'remaining_gate_keys', coalesce(
      jsonb_agg(gate_record.gate_key order by gate_record.gate_key)
        filter (where not gate_record.passed),
      '[]'::jsonb
    ),
    'truth_statement', 'Visual review does not by itself prove document authenticity or legal identity.'
  )
  from private.document_operational_readiness_gates gate_record;
$$;

create or replace function public.begin_document_review_upload(
  p_evidence_category text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  return jsonb_build_object(
    'ok', false,
    'code', 'real_document_collection_disabled',
    'requested_category', p_evidence_category,
    'collection_enabled', false,
    'upload_url', null,
    'storage_path', null,
    'message', 'MORT is not collecting real identity documents during this closed-pilot foundation phase.',
    'government_identity_verified', false
  );
end;
$$;

create or replace function public.create_document_review_case(
  p_subject_user_id uuid,
  p_environment public.verification_environment,
  p_evidence_category text,
  p_requires_two_person_review boolean,
  p_contains_real_person_data boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_case public.document_review_cases%rowtype;
begin
  if p_contains_real_person_data and not private.document_collection_operationally_ready() then
    return jsonb_build_object('ok', false, 'code', 'document_collection_not_operationally_ready');
  end if;
  if p_evidence_category not in (
    'age_evidence', 'affiliation_evidence', 'government_document',
    'program_document', 'alternative_evidence'
  ) then
    return jsonb_build_object('ok', false, 'code', 'evidence_category_invalid');
  end if;
  insert into public.document_review_cases (
    subject_user_id, environment, evidence_category, status,
    contains_real_person_data, requires_two_person_review
  ) values (
    p_subject_user_id, p_environment, p_evidence_category,
    'document_review_pending', p_contains_real_person_data,
    p_requires_two_person_review
  ) returning * into v_case;
  insert into private.document_vault_audit_events (
    case_id, event_type, access_reason, event_data
  ) values (
    v_case.id, 'object_registered',
    'A document-review case was created without recording raw evidence in the case row.',
    jsonb_build_object(
      'contains_real_person_data', p_contains_real_person_data,
      'vault_object_registered', false
    )
  );
  return jsonb_build_object(
    'ok', true,
    'case_id', v_case.id,
    'status', v_case.status,
    'contains_real_person_data', v_case.contains_real_person_data
  );
end;
$$;

create or replace function public.assign_document_review_case(
  p_case_id uuid,
  p_reviewer_id uuid,
  p_assignment_stage text,
  p_access_reason text,
  p_case_reference text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_assignment public.document_review_assignments%rowtype;
begin
  if not private.trust_admin_context_valid(p_access_reason, p_case_reference)
     or not private.has_trust_admin_role(
       auth.uid(), array['senior_verification_reviewer', 'child_safety_specialist', 'incident_manager']::text[]
     ) then
    return jsonb_build_object('ok', false, 'code', 'senior_review_assignment_role_required');
  end if;
  if p_assignment_stage not in ('reviewer_a', 'reviewer_b', 'appeal') then
    return jsonb_build_object('ok', false, 'code', 'assignment_stage_invalid');
  end if;
  if not private.has_trust_admin_role(
    p_reviewer_id,
    array['document_reviewer', 'senior_verification_reviewer', 'child_safety_specialist', 'incident_manager']::text[]
  ) then
    return jsonb_build_object('ok', false, 'code', 'qualified_document_reviewer_required');
  end if;
  if exists (
    select 1 from public.document_review_assignments assignment
    where assignment.case_id = p_case_id
      and assignment.reviewer_id = p_reviewer_id
      and assignment.assignment_stage <> p_assignment_stage
      and assignment.status in ('assigned', 'completed')
  ) then
    return jsonb_build_object('ok', false, 'code', 'two_person_reviewer_must_be_independent');
  end if;
  insert into public.document_review_assignments (
    case_id, reviewer_id, assignment_stage, conflict_checked_at,
    conflict_found, assigned_by
  ) values (
    p_case_id, p_reviewer_id, p_assignment_stage, now(), false, auth.uid()
  ) returning * into v_assignment;
  insert into private.document_vault_audit_events (
    case_id, actor_id, event_type, access_reason, event_data
  ) values (
    p_case_id, auth.uid(), 'view_authorized', btrim(p_access_reason),
    jsonb_build_object(
      'assignment_id', v_assignment.id,
      'assignment_stage', p_assignment_stage,
      'raw_evidence_access_granted', false
    )
  );
  return jsonb_build_object('ok', true, 'assignment_id', v_assignment.id, 'raw_evidence_access_granted', false);
end;
$$;

create or replace function public.submit_document_review_decision(
  p_case_id uuid,
  p_decision_stage text,
  p_decision text,
  p_decision_reason text,
  p_public_explanation text,
  p_conflict_confirmed_clear boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_case public.document_review_cases%rowtype;
  v_assignment_stage text;
  v_first_reviewer uuid;
  v_final boolean := false;
  v_public_label text;
  v_decision public.document_review_decisions%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_decision_stage not in ('reviewer_a_recommendation', 'reviewer_b_independent_decision', 'appeal_decision')
     or p_decision not in (
       'document_reviewed', 'age_evidence_reviewed', 'affiliation_reviewed',
       'authenticity_not_authoritatively_validated',
       'additional_information_required', 'rejected', 'expired'
     ) then
    return jsonb_build_object('ok', false, 'code', 'document_decision_invalid');
  end if;
  if not p_conflict_confirmed_clear
     or char_length(btrim(coalesce(p_decision_reason, ''))) not between 20 and 2000
     or char_length(btrim(coalesce(p_public_explanation, ''))) not between 20 and 1000 then
    return jsonb_build_object('ok', false, 'code', 'decision_reason_and_conflict_check_required');
  end if;
  if lower(p_public_explanation) like '%government identity verified%'
     or lower(p_public_explanation) like '%legal identity verified%'
     or lower(p_public_explanation) = 'verified' then
    return jsonb_build_object('ok', false, 'code', 'authoritative_identity_overclaim_blocked');
  end if;

  select * into v_case
  from public.document_review_cases review_case
  where review_case.id = p_case_id
  for update;
  if v_case.id is null then
    return jsonb_build_object('ok', false, 'code', 'document_review_case_not_found');
  end if;
  v_assignment_stage := case p_decision_stage
    when 'reviewer_a_recommendation' then 'reviewer_a'
    when 'reviewer_b_independent_decision' then 'reviewer_b'
    else 'appeal'
  end;
  if not exists (
    select 1 from public.document_review_assignments assignment
    where assignment.case_id = p_case_id
      and assignment.reviewer_id = auth.uid()
      and assignment.assignment_stage = v_assignment_stage
      and assignment.status = 'assigned'
      and assignment.conflict_checked_at is not null
      and not assignment.conflict_found
  ) then
    return jsonb_build_object('ok', false, 'code', 'independent_reviewer_assignment_required');
  end if;

  select decision.reviewer_id into v_first_reviewer
  from public.document_review_decisions decision
  where decision.case_id = p_case_id
    and decision.decision_stage = 'reviewer_a_recommendation';
  if p_decision_stage = 'reviewer_b_independent_decision' then
    if v_first_reviewer is null then
      return jsonb_build_object('ok', false, 'code', 'reviewer_a_recommendation_required');
    end if;
    if v_first_reviewer = auth.uid() then
      return jsonb_build_object('ok', false, 'code', 'reviewer_cannot_self_approve');
    end if;
  end if;

  v_public_label := case p_decision
    when 'document_reviewed' then 'MORT document reviewed'
    when 'age_evidence_reviewed' then 'Age evidence reviewed'
    when 'affiliation_reviewed' then 'Affiliation reviewed'
    when 'authenticity_not_authoritatively_validated' then 'Authenticity not authoritatively validated'
    when 'additional_information_required' then 'Additional information required'
    when 'rejected' then 'Document review rejected'
    else 'Document review expired'
  end;

  insert into public.document_review_decisions (
    case_id, reviewer_id, decision_stage, decision, decision_reason,
    public_explanation, conflict_of_interest_confirmed_clear
  ) values (
    p_case_id, auth.uid(), p_decision_stage, p_decision,
    btrim(p_decision_reason), btrim(p_public_explanation), true
  ) returning * into v_decision;

  update public.document_review_assignments
  set status = 'completed', completed_at = now()
  where case_id = p_case_id
    and reviewer_id = auth.uid()
    and assignment_stage = v_assignment_stage;

  v_final := p_decision_stage in ('reviewer_b_independent_decision', 'appeal_decision')
    or (not v_case.requires_two_person_review and p_decision_stage = 'reviewer_a_recommendation');
  if v_final then
    update public.document_review_cases
    set status = p_decision,
        public_label = v_public_label,
        what_was_established = btrim(p_public_explanation),
        what_was_not_established = 'Visual review does not by itself prove document authenticity, legal identity, account ownership, residential address, or safety.',
        final_decision_at = now(),
        updated_at = now()
    where id = p_case_id;
  end if;

  insert into private.document_vault_audit_events (
    case_id, actor_id, event_type, access_reason, event_data
  ) values (
    p_case_id, auth.uid(), 'viewed',
    'An assigned reviewer recorded a scoped document-review decision.',
    jsonb_build_object(
      'decision_id', v_decision.id,
      'decision_stage', p_decision_stage,
      'decision', p_decision,
      'final', v_final,
      'government_identity_effect', false
    )
  );

  return jsonb_build_object(
    'ok', true,
    'decision_id', v_decision.id,
    'final', v_final,
    'status', case when v_final then p_decision else 'document_review_pending' end,
    'public_label', case when v_final then v_public_label else 'Document review pending' end,
    'government_identity_verified', false,
    'provider_identity_verified', false,
    'authenticity_authoritatively_validated', false
  );
end;
$$;

create or replace function public.register_document_vault_object(
  p_case_id uuid,
  p_environment public.verification_environment,
  p_evidence_sha256 text,
  p_mime_type text,
  p_byte_size bigint,
  p_retention_delete_at timestamptz,
  p_synthetic_qa_metadata boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_case public.document_review_cases%rowtype;
  v_object private.document_vault_objects%rowtype;
  v_identifier uuid := gen_random_uuid();
begin
  select * into v_case from public.document_review_cases review_case where review_case.id = p_case_id;
  if v_case.id is null then
    return jsonb_build_object('ok', false, 'code', 'document_review_case_not_found');
  end if;
  if not p_synthetic_qa_metadata and not private.document_collection_operationally_ready() then
    return jsonb_build_object('ok', false, 'code', 'document_collection_not_operationally_ready');
  end if;
  if p_synthetic_qa_metadata and (v_case.environment <> 'sandbox' or v_case.contains_real_person_data) then
    return jsonb_build_object('ok', false, 'code', 'synthetic_qa_isolation_required');
  end if;
  insert into private.document_vault_objects (
    case_id, object_identifier, environment, storage_path,
    evidence_sha256, mime_type, byte_size, retention_delete_at
  ) values (
    p_case_id, v_identifier, p_environment,
    p_environment::text || '/' || v_identifier::text,
    lower(p_evidence_sha256), p_mime_type, p_byte_size, p_retention_delete_at
  ) returning * into v_object;
  insert into private.document_vault_audit_events (
    vault_object_id, case_id, event_type, access_reason, event_data
  ) values (
    v_object.id, p_case_id, 'object_registered',
    'Server registered randomized vault metadata without an original filename.',
    jsonb_build_object('synthetic_qa_metadata', p_synthetic_qa_metadata)
  );
  return jsonb_build_object(
    'ok', true,
    'vault_object_id', v_object.id,
    'object_identifier', v_object.object_identifier,
    'original_filename_stored', false,
    'public_url_created', false
  );
end;
$$;

create or replace function public.request_document_vault_access(
  p_case_id uuid,
  p_vault_object_id uuid,
  p_access_action text,
  p_access_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_policy private.pilot_policy_versions%rowtype;
  v_object private.document_vault_objects%rowtype;
  v_grant private.document_vault_access_grants%rowtype;
begin
  if auth.uid() is null
     or not private.has_trust_admin_role(
       auth.uid(),
       array['document_reviewer', 'senior_verification_reviewer', 'child_safety_specialist', 'incident_manager']::text[]
     ) then
    return jsonb_build_object('ok', false, 'code', 'specialized_document_reviewer_role_required');
  end if;
  if p_access_action not in ('view', 'download')
     or char_length(btrim(coalesce(p_access_reason, ''))) not between 12 and 1000 then
    return jsonb_build_object('ok', false, 'code', 'document_access_reason_required');
  end if;
  if not exists (
    select 1 from public.document_review_assignments assignment
    where assignment.case_id = p_case_id
      and assignment.reviewer_id = auth.uid()
      and assignment.status = 'assigned'
      and assignment.conflict_checked_at is not null
      and not assignment.conflict_found
  ) then
    insert into private.document_vault_audit_events (
      case_id, actor_id, event_type, access_reason, event_data
    ) values (
      p_case_id, auth.uid(), 'access_denied', btrim(p_access_reason),
      jsonb_build_object('reason_code', 'active_assignment_required')
    );
    return jsonb_build_object('ok', false, 'code', 'active_case_assignment_required');
  end if;
  select * into v_object
  from private.document_vault_objects vault_object
  where vault_object.id = p_vault_object_id
    and vault_object.case_id = p_case_id
    and vault_object.deleted_at is null;
  if v_object.id is null then
    return jsonb_build_object('ok', false, 'code', 'vault_object_not_found');
  end if;
  select * into v_policy from private.current_pilot_policy();
  insert into private.document_vault_access_grants (
    vault_object_id, reviewer_id, case_id, access_reason,
    access_action, expires_at
  ) values (
    p_vault_object_id, auth.uid(), p_case_id, btrim(p_access_reason),
    p_access_action,
    now() + make_interval(secs => v_policy.maximum_document_signed_url_seconds)
  ) returning * into v_grant;
  insert into private.document_vault_audit_events (
    vault_object_id, case_id, actor_id, event_type, access_reason, event_data
  ) values (
    p_vault_object_id, p_case_id, auth.uid(),
    case when p_access_action = 'view' then 'view_authorized' else 'download_authorized' end,
    btrim(p_access_reason),
    jsonb_build_object('grant_id', v_grant.id, 'expires_at', v_grant.expires_at)
  );
  return jsonb_build_object(
    'ok', true,
    'grant_id', v_grant.id,
    'expires_at', v_grant.expires_at,
    'signed_url', null,
    'server_must_exchange_grant', true
  );
end;
$$;

create or replace function public.consume_document_vault_access_grant(
  p_grant_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_grant private.document_vault_access_grants%rowtype;
  v_object private.document_vault_objects%rowtype;
begin
  select * into v_grant
  from private.document_vault_access_grants access_grant
  where access_grant.id = p_grant_id
  for update;
  if v_grant.id is null or v_grant.revoked_at is not null
     or v_grant.consumed_at is not null or v_grant.expires_at <= now() then
    return jsonb_build_object('ok', false, 'code', 'vault_access_grant_invalid_or_expired');
  end if;
  select * into v_object
  from private.document_vault_objects vault_object
  where vault_object.id = v_grant.vault_object_id
    and vault_object.deleted_at is null;
  if v_object.id is null then
    return jsonb_build_object('ok', false, 'code', 'vault_object_unavailable');
  end if;
  update private.document_vault_access_grants
  set consumed_at = now()
  where id = p_grant_id;
  return jsonb_build_object(
    'ok', true,
    'bucket', v_object.storage_bucket,
    'storage_path', v_object.storage_path,
    'access_action', v_grant.access_action,
    'reviewer_id', v_grant.reviewer_id,
    'case_id', v_grant.case_id,
    'signed_url_max_seconds', greatest(1, extract(epoch from (v_grant.expires_at - now()))::integer)
  );
end;
$$;

create or replace function public.record_document_vault_delivery(
  p_grant_id uuid,
  p_delivered boolean,
  p_event_reference text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_grant private.document_vault_access_grants%rowtype;
begin
  select * into v_grant
  from private.document_vault_access_grants access_grant
  where access_grant.id = p_grant_id;
  if v_grant.id is null then
    return jsonb_build_object('ok', false, 'code', 'vault_access_grant_not_found');
  end if;
  insert into private.document_vault_audit_events (
    vault_object_id, case_id, actor_id, event_type, access_reason, event_data
  ) values (
    v_grant.vault_object_id, v_grant.case_id, v_grant.reviewer_id,
    case
      when not p_delivered then 'access_denied'
      when v_grant.access_action = 'view' then 'viewed'
      else 'downloaded'
    end,
    v_grant.access_reason,
    jsonb_build_object('event_reference', left(coalesce(p_event_reference, ''), 100))
  );
  return jsonb_build_object('ok', true, 'delivery_recorded', true);
end;
$$;

insert into storage.buckets (
  id, name, public, file_size_limit, allowed_mime_types
) values (
  'mort-document-vault', 'mort-document-vault', false, 10485760,
  array['image/jpeg', 'image/png', 'application/pdf']
)
on conflict (id) do update
set public = false,
    file_size_limit = 10485760,
    allowed_mime_types = array['image/jpeg', 'image/png', 'application/pdf'];

create or replace function private.enforce_document_collection_readiness()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.contains_real_person_data
     and not private.document_collection_operationally_ready() then
    raise exception 'real_document_collection_disabled_until_operational_readiness';
  end if;
  return new;
end;
$$;

create trigger document_cases_readiness_gate
before insert or update of contains_real_person_data
on public.document_review_cases
for each row execute function private.enforce_document_collection_readiness();

create or replace function private.apply_discreet_notification_privacy()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_preferences public.discreet_mode_preferences%rowtype;
  v_route text;
begin
  select * into v_preferences
  from public.discreet_mode_preferences preferences
  where preferences.user_id = new.recipient_id
    and preferences.enabled;
  if v_preferences.user_id is null then
    return new;
  end if;
  v_route := nullif(left(coalesce(new.data->>'route', ''), 200), '');
  if v_preferences.generic_notification_title then
    new.title := 'MORT notification';
  end if;
  if v_preferences.hide_notification_content then
    new.body := 'Open MORT to view this update.';
  end if;
  new.data := jsonb_strip_nulls(jsonb_build_object(
    'route', v_route,
    'discreet', true,
    'sensitive_details_included', false,
    'job_address_included', false
  ));
  return new;
end;
$$;

create trigger notifications_apply_discreet_privacy
before insert or update of title, body, data
on public.notifications
for each row execute function private.apply_discreet_notification_privacy();

create or replace function public.update_discreet_mode(
  p_enabled boolean,
  p_app_lock_enabled boolean,
  p_automatic_lock_minutes smallint,
  p_quick_exit_destination text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_preferences public.discreet_mode_preferences%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_automatic_lock_minutes not between 1 and 60
     or p_quick_exit_destination not in ('home', 'job_feed', 'sign_in') then
    return jsonb_build_object('ok', false, 'code', 'discreet_mode_preferences_invalid');
  end if;
  insert into public.discreet_mode_preferences (
    user_id, enabled, app_lock_enabled, automatic_lock_minutes,
    quick_exit_destination
  ) values (
    auth.uid(), p_enabled, p_app_lock_enabled,
    p_automatic_lock_minutes, p_quick_exit_destination
  )
  on conflict (user_id) do update
  set enabled = excluded.enabled,
      app_lock_enabled = excluded.app_lock_enabled,
      automatic_lock_minutes = excluded.automatic_lock_minutes,
      quick_exit_destination = excluded.quick_exit_destination,
      generic_notification_title = true,
      hide_notification_content = true,
      hide_job_address_on_lock_screen = true,
      hide_sensitive_activity = true,
      clear_sensitive_navigation_on_exit = true,
      updated_at = now()
  returning * into v_preferences;
  return jsonb_build_object(
    'ok', true,
    'enabled', v_preferences.enabled,
    'generic_notification_title', true,
    'hide_notification_content', true,
    'hide_job_address_on_lock_screen', true,
    'app_lock_enabled', v_preferences.app_lock_enabled,
    'automatic_lock_minutes', v_preferences.automatic_lock_minutes,
    'quick_exit_destination', v_preferences.quick_exit_destination,
    'illegal_activity_disguise', false
  );
end;
$$;

create or replace function public.configure_support_circle(p_enabled boolean)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_circle public.support_circles%rowtype;
begin
  if auth.uid() is null or public.current_profile_role() <> 'teen' then
    return jsonb_build_object('ok', false, 'code', 'teen_account_required');
  end if;
  insert into public.support_circles (teen_id, enabled)
  values (auth.uid(), p_enabled)
  on conflict (teen_id) do update
  set enabled = excluded.enabled, updated_at = now()
  returning * into v_circle;
  return jsonb_build_object(
    'ok', true,
    'circle_id', v_circle.id,
    'enabled', v_circle.enabled,
    'optional', true,
    'affects_profile_completion', false,
    'affects_marketplace_eligibility', false
  );
end;
$$;

create or replace function public.invite_support_circle_member(
  p_member_user_id uuid,
  p_relationship_type text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_circle public.support_circles%rowtype;
  v_member public.support_circle_members%rowtype;
begin
  if auth.uid() is null or public.current_profile_role() <> 'teen' then
    return jsonb_build_object('ok', false, 'code', 'teen_account_required');
  end if;
  if p_member_user_id = auth.uid()
     or p_relationship_type not in (
       'parent', 'guardian', 'relative', 'adult_sibling', 'counselor', 'mentor',
       'school_liaison', 'social_worker', 'shelter_staff', 'youth_program_worker',
       'trusted_adult'
     ) then
    return jsonb_build_object('ok', false, 'code', 'support_circle_invitation_invalid');
  end if;
  if not exists (
    select 1 from public.profiles profile
    where profile.id = p_member_user_id
      and profile.role in ('adult', 'guardian', 'admin')
      and profile.account_status = 'active'
  ) then
    return jsonb_build_object('ok', false, 'code', 'eligible_support_account_required');
  end if;
  insert into public.support_circles (teen_id, enabled)
  values (auth.uid(), true)
  on conflict (teen_id) do update set enabled = true, updated_at = now()
  returning * into v_circle;
  insert into public.support_circle_members (
    circle_id, member_user_id, relationship_type, invited_by
  ) values (
    v_circle.id, p_member_user_id, p_relationship_type, auth.uid()
  )
  on conflict (circle_id, member_user_id) do update
  set relationship_type = excluded.relationship_type,
      status = 'invited', accepted_at = null, revoked_at = null,
      created_at = now()
  returning * into v_member;
  return jsonb_build_object(
    'ok', true,
    'member_id', v_member.id,
    'status', v_member.status,
    'permissions_granted', '[]'::jsonb
  );
end;
$$;

create or replace function public.respond_support_circle_invitation(
  p_member_id uuid,
  p_accept boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_member public.support_circle_members%rowtype;
begin
  update public.support_circle_members member
  set status = case when p_accept then 'active' else 'declined' end,
      accepted_at = case when p_accept then now() else null end
  where member.id = p_member_id
    and member.member_user_id = auth.uid()
    and member.status = 'invited'
  returning * into v_member;
  if v_member.id is null then
    return jsonb_build_object('ok', false, 'code', 'support_circle_invitation_not_found');
  end if;
  return jsonb_build_object('ok', true, 'status', v_member.status);
end;
$$;

create or replace function public.set_support_circle_permission(
  p_member_id uuid,
  p_permission_key text,
  p_enabled boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_permission public.support_circle_permissions%rowtype;
begin
  if auth.uid() is null
     or not exists (
       select 1
       from public.support_circle_members member
       join public.support_circles circle_record on circle_record.id = member.circle_id
       where member.id = p_member_id
         and circle_record.teen_id = auth.uid()
     ) then
    return jsonb_build_object('ok', false, 'code', 'support_circle_owner_required');
  end if;
  if p_permission_key not in (
    'receive_safety_ping', 'receive_missed_check_in', 'receive_accepted_job_summary',
    'receive_job_completion_alert', 'receive_transportation_plan_alert',
    'help_access_resources', 'confirm_organization_relationship'
  ) then
    return jsonb_build_object('ok', false, 'code', 'support_circle_permission_invalid');
  end if;
  insert into public.support_circle_permissions (
    member_id, permission_key, enabled, configured_by
  ) values (
    p_member_id, p_permission_key, p_enabled, auth.uid()
  )
  on conflict (member_id, permission_key) do update
  set enabled = excluded.enabled,
      configured_by = excluded.configured_by,
      updated_at = now()
  returning * into v_permission;
  return jsonb_build_object(
    'ok', true,
    'permission_key', v_permission.permission_key,
    'enabled', v_permission.enabled
  );
end;
$$;

create or replace function public.send_support_circle_alert(
  p_alert_type text,
  p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_permission_key text;
  v_circle public.support_circles%rowtype;
  v_safe_payload jsonb;
  v_count integer := 0;
begin
  if auth.uid() is null or public.current_profile_role() <> 'teen' then
    return jsonb_build_object('ok', false, 'code', 'teen_account_required');
  end if;
  v_permission_key := case p_alert_type
    when 'safety_ping' then 'receive_safety_ping'
    when 'missed_check_in' then 'receive_missed_check_in'
    when 'accepted_job_summary' then 'receive_accepted_job_summary'
    when 'job_completion' then 'receive_job_completion_alert'
    when 'transportation_plan' then 'receive_transportation_plan_alert'
    when 'resource_help_request' then 'help_access_resources'
    else null
  end;
  if v_permission_key is null then
    return jsonb_build_object('ok', false, 'code', 'support_circle_alert_type_invalid');
  end if;
  select * into v_circle
  from public.support_circles circle_record
  where circle_record.teen_id = auth.uid() and circle_record.enabled;
  if v_circle.id is null then
    return jsonb_build_object('ok', false, 'code', 'support_circle_not_enabled');
  end if;
  v_safe_payload := coalesce(p_payload, '{}'::jsonb)
    - array[
      'message_body', 'full_location_history', 'identity_document',
      'earnings', 'password', 'housing_status', 'residential_address',
      'school', 'shelter', 'counselor', 'family_status'
    ];
  insert into public.support_circle_alert_events (
    circle_id, member_id, teen_id, alert_type, payload
  )
  select v_circle.id, member.id, auth.uid(), p_alert_type, v_safe_payload
  from public.support_circle_members member
  join public.support_circle_permissions permission
    on permission.member_id = member.id
   and permission.permission_key = v_permission_key
   and permission.enabled
  where member.circle_id = v_circle.id
    and member.status = 'active'
    and member.revoked_at is null;
  get diagnostics v_count = row_count;
  return jsonb_build_object(
    'ok', true,
    'recipients', v_count,
    'only_explicitly_granted_members', true,
    'unrestricted_messages_shared', false,
    'earnings_shared', false,
    'full_location_history_shared', false
  );
end;
$$;

create or replace function public.get_mission_pilot_dashboard()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_eligibility jsonb;
  v_discreet jsonb;
  v_circle jsonb;
  v_goal_count integer := 0;
  v_resource_count integer := 0;
  v_document_status jsonb;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  v_eligibility := public.get_closed_pilot_eligibility('browse', null);
  select coalesce(to_jsonb(preferences), jsonb_build_object(
    'enabled', false,
    'generic_notification_title', true,
    'hide_notification_content', true,
    'app_lock_enabled', false,
    'automatic_lock_minutes', 5
  )) into v_discreet
  from (select 1) seed
  left join public.discreet_mode_preferences preferences
    on preferences.user_id = auth.uid();
  select coalesce(jsonb_build_object(
    'enabled', circle_record.enabled,
    'member_count', (
      select count(*) from public.support_circle_members member
      where member.circle_id = circle_record.id and member.status = 'active'
    ),
    'optional', true,
    'affects_eligibility', false
  ), jsonb_build_object('enabled', false, 'member_count', 0, 'optional', true, 'affects_eligibility', false))
  into v_circle
  from (select 1) seed
  left join public.support_circles circle_record on circle_record.teen_id = auth.uid();
  select count(*) into v_goal_count
  from public.independence_goals goal
  where goal.user_id = auth.uid() and goal.status = 'active';
  select count(*) into v_resource_count
  from public.resource_directory_entries resource
  where resource.source_status in ('official', 'reviewed');
  v_document_status := public.get_document_collection_readiness();
  return jsonb_build_object(
    'ok', true,
    'mission', 'Help teenagers gain legitimate income, work experience, skills, references, and safe pathways toward adulthood.',
    'pilot_eligibility', v_eligibility,
    'discreet_mode', v_discreet,
    'support_circle', v_circle,
    'active_goal_count', v_goal_count,
    'reviewed_resource_count', v_resource_count,
    'document_review', v_document_status,
    'mort_holds_payments', false,
    'runaway_guidance_provided', false
  );
end;
$$;

create or replace function public.get_private_work_summary()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'ok', true,
    'total_self_recorded_earnings_cents', coalesce((
      select sum(entry.amount_cents)
      from public.work_earning_entries entry
      where entry.user_id = auth.uid()
        and entry.payment_status <> 'disputed'
    ), 0),
    'completed_job_count', (
      select count(*)
      from public.applications application
      where application.teen_id = auth.uid()
        and application.status = 'completed'
    ),
    'skill_count', (
      select count(*)
      from public.skill_passport_entries skill
      where skill.user_id = auth.uid()
    ),
    'reference_count', (
      select count(*)
      from public.work_reference_requests reference_request
      where reference_request.requester_id = auth.uid()
        and reference_request.status = 'provided'
    ),
    'mort_holds_payments', false,
    'mort_guarantees_payments', false,
    'private_by_default', true
  );
$$;

-- A human-review decision is applied only inside this transaction and cannot
-- be forged by a mobile client because only the audited admin RPC sets it.
create or replace function private.evaluate_closed_pilot_job()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_policy private.pilot_policy_versions%rowtype;
  v_profile public.profiles%rowtype;
  v_enrollment public.pilot_enrollments%rowtype;
  v_content text;
  v_reasons text[] := '{}';
  v_blocked boolean := false;
  v_manual boolean := false;
  v_allowed_locations text[] := array[
    'verified_business', 'school', 'nonprofit', 'community_center',
    'public_event', 'staffed_community_project',
    'visible_outdoor_community_space'
  ];
begin
  if current_setting('mort.pilot_human_review', true) = 'true' then
    return new;
  end if;
  select * into v_policy from private.current_pilot_policy();
  select * into v_profile from public.profiles profile where profile.id = new.poster_id;
  if new.pilot_location_class = 'unclassified' then
    new.pilot_location_class := case lower(coalesce(new.location_type, ''))
      when 'business' then 'verified_business' when 'verified_business' then 'verified_business'
      when 'school' then 'school' when 'nonprofit' then 'nonprofit'
      when 'community_center' then 'community_center' when 'public_event' then 'public_event'
      when 'public' then 'public_event' when 'staffed_community_project' then 'staffed_community_project'
      when 'visible_outdoor' then 'visible_outdoor_community_space'
      when 'private_residence' then 'private_residence' when 'hotel' then 'hotel'
      when 'isolated_property' then 'isolated_property' when 'unknown' then 'unknown_location'
      else 'unknown_location'
    end;
  end if;
  new.pilot_staffed_or_visible := new.pilot_staffed_or_visible
    or coalesce(new.adult_supervision_present, false)
    or coalesce(new.public_meeting_available, false)
    or new.pilot_location_class in ('verified_business', 'school', 'nonprofit', 'community_center', 'public_event');
  v_content := lower(concat_ws(' ', new.title, new.summary, new.description, new.special_instructions, new.safety_notes, new.equipment_provided, new.equipment_worker_brings, array_to_string(new.physical_requirements, ' ')));
  if new.pilot_location_class in ('private_residence', 'hotel', 'isolated_property', 'unknown_location') then v_reasons := array_append(v_reasons, 'pilot_location_not_allowed'); v_blocked := true;
  elsif not (new.pilot_location_class = any(v_allowed_locations)) then v_reasons := array_append(v_reasons, 'pilot_location_unclassified'); v_manual := true; end if;
  if not new.pilot_staffed_or_visible then v_reasons := array_append(v_reasons, 'staffed_or_visible_location_required'); v_blocked := true; end if;
  if v_content ~ '(\mbedroom\M|\mhotel\M|\movernight\M|\misolated\M|private property|secret|do not tell|keep this private)' then v_reasons := array_append(v_reasons, 'isolation_or_secrecy_prohibited'); v_blocked := true; end if;
  if v_content ~ '(\mroof\M|dangerous height|scaffold|firearm|\mweapon\M|\mgun\M|hazardous chemical|pesticide|alcohol|illegal drug|adult service|sexual service|heavy machinery|industrial machinery)' then v_reasons := array_append(v_reasons, 'hazardous_or_prohibited_work'); v_blocked := true; end if;
  if v_content ~ '(poster will drive|I will drive|ride with me|private ride|pick you up|transport you)' then v_reasons := array_append(v_reasons, 'poster_transportation_prohibited'); v_blocked := true;
  elsif coalesce(new.transportation_required, false) then v_reasons := array_append(v_reasons, 'transportation_plan_manual_review'); v_manual := true; end if;
  if new.risk_tier::text in ('higher_risk', 'prohibited') then v_reasons := array_append(v_reasons, 'job_risk_tier_not_pilot_eligible'); v_blocked := true; end if;
  if new.starts_at is not null and extract(hour from new.starts_at at time zone coalesce(new.timezone, 'America/Indianapolis')) not between 6 and 19 then v_reasons := array_append(v_reasons, 'overnight_or_late_work_prohibited'); v_blocked := true; end if;
  if new.ends_at is not null and extract(hour from new.ends_at at time zone coalesce(new.timezone, 'America/Indianapolis')) > 21 then v_reasons := array_append(v_reasons, 'overnight_or_late_work_prohibited'); v_blocked := true; end if;
  if not coalesce(v_profile.is_test_account, false) then
    select * into v_enrollment from public.pilot_enrollments enrollment where enrollment.user_id = new.poster_id and enrollment.status = 'approved' and enrollment.revoked_at is null and enrollment.expires_at > now() order by enrollment.approved_at desc limit 1;
    if v_enrollment.id is null or not private.user_has_active_pilot_enrollment(new.poster_id) then v_reasons := array_append(v_reasons, 'approved_adult_pilot_enrollment_required'); v_manual := true;
    else if new.pilot_organization_id is null then new.pilot_organization_id := v_enrollment.organization_id;
      elsif new.pilot_organization_id <> v_enrollment.organization_id then v_reasons := array_append(v_reasons, 'pilot_organization_mismatch'); v_blocked := true; end if;
    end if;
  end if;
  if not v_policy.pilot_mode_enabled or v_policy.unrestricted_public_access_enabled then v_reasons := array_append(v_reasons, 'closed_pilot_policy_unavailable'); v_blocked := true; end if;
  new.pilot_policy_version := v_policy.version; new.pilot_restriction_reasons := v_reasons; new.pilot_reviewed_at := now();
  if v_blocked then new.pilot_review_status := 'blocked'; elsif v_manual then new.pilot_review_status := 'manual_review_required'; else new.pilot_review_status := 'eligible'; end if;
  if new.status = 'open' and new.pilot_review_status <> 'eligible' then new.status := 'pending_review'; new.applications_open := false;
  elsif new.status = 'open' then new.applications_open := true; end if;
  return new;
end;
$$;

-- Recreate the audited admin function so a human decision survives the job
-- trigger only for this transaction.
create or replace function public.admin_review_pilot_job(
  p_job_id uuid,
  p_decision text,
  p_reason_codes text[],
  p_access_reason text,
  p_case_id text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job public.jobs%rowtype;
  v_policy private.pilot_policy_versions%rowtype;
begin
  if not private.trust_admin_context_valid(p_access_reason, p_case_id)
     or not private.has_trust_admin_role(auth.uid(), array['safety_moderator', 'child_safety_specialist', 'super_admin']::text[]) then
    return jsonb_build_object('ok', false, 'code', 'pilot_job_reviewer_required');
  end if;
  if p_decision not in ('eligible', 'blocked') or cardinality(coalesce(p_reason_codes, '{}')) = 0 then return jsonb_build_object('ok', false, 'code', 'pilot_job_decision_invalid'); end if;
  select * into v_job from public.jobs job where job.id = p_job_id for update;
  if v_job.id is null then return jsonb_build_object('ok', false, 'code', 'job_not_found'); end if;
  select * into v_policy from private.current_pilot_policy();
  perform set_config('mort.pilot_human_review', 'true', true);
  update public.jobs set pilot_review_status = p_decision, pilot_restriction_reasons = p_reason_codes, pilot_policy_version = v_policy.version, pilot_reviewed_by = auth.uid(), pilot_reviewed_at = now(), status = case when p_decision = 'eligible' then 'open'::public.job_status else 'rejected'::public.job_status end, applications_open = p_decision = 'eligible', updated_at = now() where id = p_job_id returning * into v_job;
  insert into public.pilot_job_reviews (job_id, policy_version, decision, reason_codes, reviewer_id, review_method) values (p_job_id, v_policy.version, p_decision, p_reason_codes, auth.uid(), 'authorized_human_review');
  return jsonb_build_object('ok', true, 'job_id', p_job_id, 'decision', p_decision, 'server_owned_decision', true);
end;
$$;

revoke all on function public.get_closed_pilot_eligibility(text, uuid),
  public.submit_pilot_enrollment_request(uuid, text),
  public.acknowledge_pilot_policy(text),
  public.get_my_partner_attestations(),
  public.get_partner_connected_participants(uuid),
  public.submit_partner_attestation(uuid, uuid, text, timestamptz),
  public.revoke_partner_attestation(uuid, text),
  public.admin_assign_partner_staff(uuid, uuid, text, timestamptz, text, text),
  public.admin_set_partner_permission(uuid, text, boolean, text, text),
  public.admin_review_pilot_enrollment(uuid, boolean, timestamptz, text, text),
  public.get_pilot_job_eligibility(uuid),
  public.admin_review_pilot_job(uuid, text, text[], text, text),
  public.admin_set_partner_pilot_approval(uuid, boolean, text, text),
  public.get_document_collection_readiness(),
  public.begin_document_review_upload(text),
  public.create_document_review_case(uuid, public.verification_environment, text, boolean, boolean),
  public.assign_document_review_case(uuid, uuid, text, text, text),
  public.submit_document_review_decision(uuid, text, text, text, text, boolean),
  public.register_document_vault_object(uuid, public.verification_environment, text, text, bigint, timestamptz, boolean),
  public.request_document_vault_access(uuid, uuid, text, text),
  public.consume_document_vault_access_grant(uuid),
  public.record_document_vault_delivery(uuid, boolean, text),
  public.update_discreet_mode(boolean, boolean, smallint, text),
  public.configure_support_circle(boolean),
  public.invite_support_circle_member(uuid, text),
  public.respond_support_circle_invitation(uuid, boolean),
  public.set_support_circle_permission(uuid, text, boolean),
  public.send_support_circle_alert(text, jsonb),
  public.get_mission_pilot_dashboard(),
  public.get_private_work_summary()
from public, anon, authenticated;

grant execute on function public.get_closed_pilot_eligibility(text, uuid),
  public.submit_pilot_enrollment_request(uuid, text),
  public.acknowledge_pilot_policy(text),
  public.get_my_partner_attestations(),
  public.get_partner_connected_participants(uuid),
  public.submit_partner_attestation(uuid, uuid, text, timestamptz),
  public.revoke_partner_attestation(uuid, text),
  public.admin_assign_partner_staff(uuid, uuid, text, timestamptz, text, text),
  public.admin_set_partner_permission(uuid, text, boolean, text, text),
  public.admin_review_pilot_enrollment(uuid, boolean, timestamptz, text, text),
  public.get_pilot_job_eligibility(uuid),
  public.admin_review_pilot_job(uuid, text, text[], text, text),
  public.admin_set_partner_pilot_approval(uuid, boolean, text, text),
  public.get_document_collection_readiness(),
  public.begin_document_review_upload(text),
  public.assign_document_review_case(uuid, uuid, text, text, text),
  public.submit_document_review_decision(uuid, text, text, text, text, boolean),
  public.request_document_vault_access(uuid, uuid, text, text),
  public.update_discreet_mode(boolean, boolean, smallint, text),
  public.configure_support_circle(boolean),
  public.invite_support_circle_member(uuid, text),
  public.respond_support_circle_invitation(uuid, boolean),
  public.set_support_circle_permission(uuid, text, boolean),
  public.send_support_circle_alert(text, jsonb),
  public.get_mission_pilot_dashboard(),
  public.get_private_work_summary()
to authenticated, service_role;

grant execute on function public.create_document_review_case(uuid, public.verification_environment, text, boolean, boolean),
  public.register_document_vault_object(uuid, public.verification_environment, text, text, bigint, timestamptz, boolean),
  public.consume_document_vault_access_grant(uuid),
  public.record_document_vault_delivery(uuid, boolean, text)
to service_role;

revoke all on function private.create_pending_pilot_enrollment_from_membership(),
  private.evaluate_closed_pilot_job(),
  private.audit_closed_pilot_job_evaluation(),
  private.enforce_closed_pilot_application(),
  private.enforce_document_collection_readiness(),
  private.apply_discreet_notification_privacy()
from public, anon, authenticated;

comment on table public.pilot_enrollments is
  'Closed-pilot enrollment. Permanent address and guardian linkage are never prerequisites.';
comment on table public.partner_attestations is
  'Versioned, limited-scope partner attestations. They do not establish government identity.';
comment on table public.document_review_cases is
  'First-party review status only. Visual review does not prove legal identity or document authenticity.';
comment on table private.document_vault_objects is
  'Non-public vault metadata with random identifiers, hashes, retention dates, and preservation locks. No original filenames.';
comment on table public.support_circles is
  'Teen-controlled optional support sharing. It does not affect profile completion or marketplace eligibility.';
comment on table public.work_earning_entries is
  'Private work-history records. MORT does not hold, escrow, guarantee, or custody payments.';
comment on table public.future_independence_plans is
  'Lawful adulthood preparation. It does not provide guidance for minors to run away.';
comment on table public.resource_directory_entries is
  'Official or reviewed resource sources without real-time availability claims.';
