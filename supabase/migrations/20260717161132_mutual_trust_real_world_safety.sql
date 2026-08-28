-- Mutual, two-sided trust and real-world safety. Identity verification does
-- not imply safety, and Guardian Mode remains optional.

create type public.safety_report_category as enum (
  'harassment',
  'sexual_harassment',
  'sexual_conduct',
  'stalking',
  'threats',
  'assault',
  'attempted_assault',
  'coercion',
  'kidnapping_abduction_concern',
  'inappropriate_touching',
  'property_damage',
  'theft',
  'scam',
  'nonpayment',
  'underpayment',
  'false_accusation',
  'blackmail',
  'discrimination',
  'hate_speech',
  'intoxication',
  'weapons',
  'unsafe_job_conditions',
  'unexpected_people',
  'unexpected_location',
  'off_platform_pressure',
  'personal_information_request',
  'repeated_unwanted_contact',
  'inappropriate_images',
  'child_safety_concern',
  'adult_safety_concern',
  'identity_mismatch',
  'impersonation',
  'fake_document',
  'account_sharing',
  'payment_threat',
  'doxxing',
  'other_urgent_concern'
);

create type public.safety_incident_severity as enum (
  'low', 'moderate', 'high', 'critical'
);

create type public.safety_incident_status as enum (
  'submitted',
  'triage',
  'investigating',
  'waiting_for_information',
  'safety_action_taken',
  'resolved',
  'closed',
  'appeal_pending'
);

create type public.job_risk_tier as enum (
  'lower_risk', 'elevated_review', 'prohibited_for_teens'
);

create type public.safety_agreement_state as enum (
  'awaiting_both', 'awaiting_teen', 'awaiting_adult', 'confirmed', 'reconfirmation_required', 'canceled'
);

create type public.location_share_mode as enum (
  'none',
  'arrival_only',
  'departure_only',
  'coarse_area',
  'temporary_active_job',
  'trusted_contact_only',
  'safety_ping_emergency'
);

alter table public.reports
  add column category public.safety_report_category not null default 'other_urgent_concern',
  add column severity public.safety_incident_severity not null default 'moderate',
  add column immediate_danger boolean not null default false,
  add column related_application_id uuid references public.applications(id) on delete set null,
  add column occurred_at timestamptz,
  add column location_type text,
  add column desired_outcome text,
  add column confidential_safety_feedback boolean not null default false,
  add column evidence_preserved boolean not null default false;

alter table public.messages
  add column safety_category public.safety_report_category,
  add column safety_severity public.safety_incident_severity,
  add column preserved_for_safety boolean not null default false,
  add column safer_rewrite_available boolean not null default false;

alter table public.reviews
  add column reveal_at timestamptz not null default (now() + interval '14 days'),
  add column revealed_at timestamptz,
  add column confidential_safety_feedback boolean not null default false,
  add column appeal_status text not null default 'none';

update public.reviews
set revealed_at = created_at
where revealed_at is null;

alter table public.jobs
  add column risk_tier public.job_risk_tier not null default 'lower_risk',
  add column who_will_be_present text,
  add column animal_risk_disclosed boolean not null default false,
  add column animal_risk_notes text,
  add column equipment_risk_disclosed boolean not null default false,
  add column equipment_risk_notes text,
  add column transportation_required boolean not null default false,
  add column public_meeting_available boolean not null default false,
  add column daylight_only boolean not null default false,
  add column weather_risk_acknowledged boolean not null default false,
  add column scope_version integer not null default 1;

alter table public.safety_pings
  add column job_id uuid references public.jobs(id) on delete set null,
  add column immediate_danger boolean not null default false,
  add column coarse_location text;

create sequence public.safety_case_number_seq;

create table public.safety_incidents (
  id uuid primary key default gen_random_uuid(),
  case_number text not null unique default (
    'MORT-' || to_char(now(), 'YYYY') || '-' || lpad(nextval('public.safety_case_number_seq')::text, 8, '0')
  ),
  initial_report_id uuid unique references public.reports(id) on delete restrict,
  reporter_id uuid references public.profiles(id) on delete set null,
  subject_user_id uuid references public.profiles(id) on delete set null,
  job_id uuid references public.jobs(id) on delete set null,
  application_id uuid references public.applications(id) on delete set null,
  category public.safety_report_category not null,
  severity public.safety_incident_severity not null,
  immediate_danger boolean not null default false,
  status public.safety_incident_status not null default 'submitted',
  priority smallint not null default 3,
  sla_due_at timestamptz,
  assigned_team text,
  preservation_status text not null default 'preserve_relevant_records',
  victim_safety_notes text,
  accused_user_notice_status text not null default 'not_sent',
  appeal_status text not null default 'none',
  legal_hold boolean not null default false,
  closed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint safety_incident_priority_check check (priority between 1 and 5),
  constraint safety_incident_notes_length check (victim_safety_notes is null or char_length(victim_safety_notes) <= 5000)
);

alter table public.reports
  add column incident_id uuid references public.safety_incidents(id) on delete set null;

create index safety_incidents_queue_idx
on public.safety_incidents(status, severity, priority, created_at);

create index safety_incidents_reporter_idx
on public.safety_incidents(reporter_id, created_at desc);

create index safety_incidents_subject_idx
on public.safety_incidents(subject_user_id, created_at desc);

create index reports_incident_idx on public.reports(incident_id);
create index reports_category_severity_idx on public.reports(category, severity, created_at desc);

create table public.incident_participants (
  id uuid primary key default gen_random_uuid(),
  incident_id uuid not null references public.safety_incidents(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  participant_role text not null,
  can_view_status boolean not null default true,
  can_submit_evidence boolean not null default true,
  created_at timestamptz not null default now(),
  constraint incident_participant_role_check check (
    participant_role in ('reporter', 'affected_person', 'accused_person', 'witness', 'guardian_support', 'trusted_contact')
  ),
  unique (incident_id, user_id, participant_role)
);

create index incident_participants_user_idx
on public.incident_participants(user_id, incident_id);

create table public.incident_evidence (
  id uuid primary key,
  incident_id uuid not null references public.safety_incidents(id) on delete restrict,
  submitted_by uuid references public.profiles(id) on delete set null,
  evidence_type text not null,
  bucket_id text not null default 'incident-evidence',
  storage_path text not null unique,
  content_type text not null,
  byte_size bigint not null,
  sha256 text,
  evidence_status text not null default 'received',
  preserved_until timestamptz,
  retention_delete_at timestamptz not null default (now() + interval '180 days'),
  created_at timestamptz not null default now(),
  constraint incident_evidence_bucket_check check (bucket_id = 'incident-evidence'),
  constraint incident_evidence_type_length check (char_length(evidence_type) between 2 and 80),
  constraint incident_evidence_content_type_check check (
    content_type in ('image/jpeg', 'image/png', 'application/pdf', 'text/plain')
  ),
  constraint incident_evidence_size_check check (byte_size between 1 and 15728640),
  constraint incident_evidence_sha256_check check (sha256 is null or sha256 ~ '^[A-Fa-f0-9]{64}$')
);

create index incident_evidence_incident_idx
on public.incident_evidence(incident_id, created_at);

create index incident_evidence_retention_idx
on public.incident_evidence(retention_delete_at)
where preserved_until is null;

create table public.incident_evidence_access_grants (
  id uuid primary key default gen_random_uuid(),
  evidence_id uuid not null references public.incident_evidence(id) on delete cascade,
  reviewer_id uuid not null references public.profiles(id) on delete cascade,
  access_reason text not null,
  granted_at timestamptz not null default now(),
  expires_at timestamptz not null,
  revoked_at timestamptz,
  constraint incident_evidence_access_reason_length check (char_length(access_reason) between 10 and 500),
  constraint incident_evidence_access_expiry_check check (
    expires_at > granted_at and expires_at <= granted_at + interval '15 minutes'
  )
);

create index incident_evidence_access_active_idx
on public.incident_evidence_access_grants(reviewer_id, evidence_id, expires_at)
where revoked_at is null;

create table public.incident_timeline_events (
  id bigint generated always as identity primary key,
  incident_id uuid not null references public.safety_incidents(id) on delete restrict,
  actor_id uuid references public.profiles(id) on delete set null,
  event_type text not null,
  public_status_note text,
  restricted_note text,
  event_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint incident_timeline_type_length check (char_length(event_type) between 2 and 100),
  constraint incident_timeline_public_note_length check (public_status_note is null or char_length(public_status_note) <= 1000),
  constraint incident_timeline_restricted_note_length check (restricted_note is null or char_length(restricted_note) <= 5000)
);

create index incident_timeline_incident_idx
on public.incident_timeline_events(incident_id, created_at);

create table public.incident_assignments (
  id uuid primary key default gen_random_uuid(),
  incident_id uuid not null references public.safety_incidents(id) on delete cascade,
  assigned_to uuid not null references public.profiles(id) on delete restrict,
  assigned_by uuid not null references public.profiles(id) on delete restrict,
  assignment_role public.admin_safety_role not null,
  assigned_at timestamptz not null default now(),
  ended_at timestamptz
);

create unique index incident_assignments_active_idx
on public.incident_assignments(incident_id, assigned_to)
where ended_at is null;

create table public.incident_actions (
  id uuid primary key default gen_random_uuid(),
  incident_id uuid not null references public.safety_incidents(id) on delete restrict,
  actor_id uuid not null references public.profiles(id) on delete restrict,
  action_type text not null,
  action_reason text not null,
  high_impact boolean not null default false,
  approval_status text not null default 'not_required',
  approved_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  approved_at timestamptz,
  constraint incident_action_reason_length check (char_length(action_reason) between 10 and 5000),
  constraint incident_action_approval_check check (approval_status in ('not_required', 'pending', 'approved', 'rejected'))
);

create index incident_actions_incident_idx
on public.incident_actions(incident_id, created_at);

create table public.incident_preservation_orders (
  id uuid primary key default gen_random_uuid(),
  incident_id uuid not null references public.safety_incidents(id) on delete restrict,
  ordered_by uuid not null references public.profiles(id) on delete restrict,
  legal_basis text not null,
  scope text not null,
  starts_at timestamptz not null default now(),
  expires_at timestamptz not null,
  released_at timestamptz,
  created_at timestamptz not null default now(),
  constraint preservation_legal_basis_length check (char_length(legal_basis) between 10 and 2000),
  constraint preservation_scope_length check (char_length(scope) between 10 and 2000),
  constraint preservation_expiry_check check (expires_at > starts_at)
);

create table public.incident_law_enforcement_requests (
  id uuid primary key default gen_random_uuid(),
  incident_id uuid references public.safety_incidents(id) on delete restrict,
  request_reference text not null unique,
  agency_name text not null,
  request_type text not null,
  identity_validation_status text not null default 'pending',
  legal_review_status text not null default 'pending',
  emergency_request boolean not null default false,
  scope_summary text not null,
  received_at timestamptz not null,
  due_at timestamptz,
  reviewed_by uuid references public.profiles(id) on delete set null,
  status text not null default 'received',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint law_request_reference_length check (char_length(request_reference) between 3 and 120),
  constraint law_request_agency_length check (char_length(agency_name) between 2 and 200),
  constraint law_request_scope_length check (char_length(scope_summary) between 10 and 2000)
);

create table public.incident_contact_attempts (
  id uuid primary key default gen_random_uuid(),
  incident_id uuid not null references public.safety_incidents(id) on delete restrict,
  actor_id uuid not null references public.profiles(id) on delete restrict,
  contact_target text not null,
  method text not null,
  outcome text not null,
  created_at timestamptz not null default now(),
  constraint incident_contact_target_length check (char_length(contact_target) between 2 and 200),
  constraint incident_contact_outcome_length check (char_length(outcome) between 2 and 1000)
);

create table public.incident_appeals (
  id uuid primary key default gen_random_uuid(),
  incident_id uuid not null references public.safety_incidents(id) on delete restrict,
  appellant_id uuid not null references public.profiles(id) on delete cascade,
  reason text not null,
  status text not null default 'pending',
  reviewer_id uuid references public.profiles(id) on delete set null,
  decision_note text,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  constraint incident_appeal_reason_length check (char_length(reason) between 20 and 3000),
  constraint incident_appeal_status_check check (status in ('pending', 'reviewing', 'approved', 'denied', 'withdrawn'))
);

create table public.incident_outcomes (
  id uuid primary key default gen_random_uuid(),
  incident_id uuid not null unique references public.safety_incidents(id) on delete restrict,
  outcome_code text not null,
  public_summary text,
  restricted_summary text,
  decided_by uuid not null references public.profiles(id) on delete restrict,
  decided_at timestamptz not null default now(),
  appeal_deadline timestamptz,
  constraint incident_outcome_code_length check (char_length(outcome_code) between 2 and 100),
  constraint incident_outcome_public_length check (public_summary is null or char_length(public_summary) <= 1000),
  constraint incident_outcome_restricted_length check (restricted_summary is null or char_length(restricted_summary) <= 5000)
);

create table public.safety_circle_members (
  id uuid primary key default gen_random_uuid(),
  teen_id uuid not null references public.profiles(id) on delete cascade,
  contact_id uuid references public.profiles(id) on delete cascade,
  relationship_label text not null,
  status text not null default 'invited',
  invite_code_hash bytea not null,
  invite_expires_at timestamptz not null,
  receive_safety_ping boolean not null default true,
  receive_missed_checkin boolean not null default true,
  receive_job_summary boolean not null default false,
  receive_job_status boolean not null default false,
  receive_emergency_request boolean not null default true,
  view_limited_safety_plan boolean not null default false,
  receive_completion boolean not null default false,
  accepted_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint safety_circle_relationship_length check (char_length(relationship_label) between 2 and 60),
  constraint safety_circle_status_check check (status in ('invited', 'active', 'revoked', 'expired', 'declined')),
  constraint safety_circle_invite_expiry_check check (invite_expires_at > created_at)
);

create unique index safety_circle_active_pair_idx
on public.safety_circle_members(teen_id, contact_id)
where contact_id is not null and status = 'active';

create index safety_circle_teen_status_idx
on public.safety_circle_members(teen_id, status);

create index safety_circle_contact_status_idx
on public.safety_circle_members(contact_id, status);

create table public.job_safety_plans (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null unique references public.applications(id) on delete cascade,
  job_id uuid not null references public.jobs(id) on delete cascade,
  teen_id uuid not null references public.profiles(id) on delete cascade,
  adult_id uuid not null references public.profiles(id) on delete cascade,
  expected_people text,
  public_or_visible_meeting boolean not null default false,
  daylight_preferred boolean not null default false,
  transportation_plan text,
  checkin_cadence_minutes integer,
  emergency_exit_acknowledged boolean not null default true,
  teen_updated_at timestamptz,
  adult_updated_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint safety_plan_people_length check (expected_people is null or char_length(expected_people) <= 500),
  constraint safety_plan_transport_length check (transportation_plan is null or char_length(transportation_plan) <= 1000),
  constraint safety_plan_cadence_check check (checkin_cadence_minutes is null or checkin_cadence_minutes between 15 and 240)
);

create table public.job_safety_agreements (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null unique references public.applications(id) on delete cascade,
  job_id uuid not null references public.jobs(id) on delete cascade,
  teen_id uuid not null references public.profiles(id) on delete cascade,
  adult_id uuid not null references public.profiles(id) on delete cascade,
  agreement_version integer not null default 1,
  terms_snapshot jsonb not null,
  material_terms_hash text not null,
  status public.safety_agreement_state not null default 'awaiting_both',
  teen_confirmed_at timestamptz,
  adult_confirmed_at timestamptz,
  teen_confirmed_version integer,
  adult_confirmed_version integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint safety_agreement_version_check check (agreement_version > 0),
  constraint safety_agreement_hash_check check (material_terms_hash ~ '^[A-Fa-f0-9]{64}$')
);

create index job_safety_agreements_participants_idx
on public.job_safety_agreements(teen_id, adult_id, status);

create table public.job_private_locations (
  job_id uuid primary key references public.jobs(id) on delete cascade,
  poster_id uuid not null references public.profiles(id) on delete cascade,
  exact_address text not null,
  arrival_instructions text,
  access_notes text,
  location_version integer not null default 1,
  verified_for_job boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint job_private_address_length check (char_length(exact_address) between 5 and 500),
  constraint job_arrival_instructions_length check (arrival_instructions is null or char_length(arrival_instructions) <= 2000),
  constraint job_access_notes_length check (access_notes is null or char_length(access_notes) <= 1000)
);

create table public.private_data_access_events (
  id bigint generated always as identity primary key,
  actor_id uuid references public.profiles(id) on delete set null,
  resource_type text not null,
  resource_id uuid not null,
  action text not null,
  reason text not null,
  created_at timestamptz not null default now(),
  constraint private_access_resource_type_length check (char_length(resource_type) between 2 and 80),
  constraint private_access_action_length check (char_length(action) between 2 and 80),
  constraint private_access_reason_length check (char_length(reason) between 3 and 500)
);

create index private_data_access_actor_idx
on public.private_data_access_events(actor_id, created_at desc);

create table public.job_location_share_sessions (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references public.applications(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  recipient_user_id uuid references public.profiles(id) on delete cascade,
  mode public.location_share_mode not null,
  coarse_location text,
  latitude double precision,
  longitude double precision,
  status text not null default 'active',
  starts_at timestamptz not null default now(),
  expires_at timestamptz not null,
  stopped_at timestamptz,
  last_location_at timestamptz,
  created_at timestamptz not null default now(),
  constraint location_share_status_check check (status in ('active', 'stopped', 'expired')),
  constraint location_share_expiry_check check (expires_at > starts_at and expires_at <= starts_at + interval '12 hours'),
  constraint location_share_latitude_check check (latitude is null or latitude between -90 and 90),
  constraint location_share_longitude_check check (longitude is null or longitude between -180 and 180),
  constraint location_share_coordinates_pair_check check ((latitude is null) = (longitude is null)),
  constraint location_share_coarse_length check (coarse_location is null or char_length(coarse_location) <= 200)
);

create index job_location_share_active_idx
on public.job_location_share_sessions(application_id, status, expires_at);

create index job_location_share_recipient_idx
on public.job_location_share_sessions(recipient_user_id, status, expires_at);

create table public.job_arrival_handshakes (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null unique references public.applications(id) on delete cascade,
  job_id uuid not null references public.jobs(id) on delete cascade,
  teen_id uuid not null references public.profiles(id) on delete cascade,
  adult_id uuid not null references public.profiles(id) on delete cascade,
  code_hash bytea,
  code_generation integer not null default 0,
  code_expires_at timestamptz,
  code_used_at timestamptz,
  checkin_at timestamptz,
  teen_identity_match_confirmed boolean,
  adult_identity_match_confirmed boolean,
  teen_checkout_at timestamptz,
  adult_checkout_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.job_checkins (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references public.applications(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  checkin_type text not null,
  expected_at timestamptz,
  completed_at timestamptz,
  escalation_sent_at timestamptz,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  constraint job_checkin_type_check check (checkin_type in ('pre_meeting', 'arrival', 'cadence', 'departure')),
  constraint job_checkin_status_check check (status in ('pending', 'completed', 'missed', 'canceled'))
);

create index job_checkins_due_idx
on public.job_checkins(status, expected_at)
where status = 'pending';

create table public.trusted_relationships (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  target_id uuid not null references public.profiles(id) on delete cascade,
  relationship_type text not null,
  source_job_id uuid references public.jobs(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint trusted_relationship_self_check check (owner_id <> target_id),
  constraint trusted_relationship_type_check check (
    relationship_type in ('trusted_worker', 'trusted_poster', 'private_favorite', 'decline_future_invites', 'no_contact')
  ),
  unique (owner_id, target_id, relationship_type)
);

create index trusted_relationships_target_idx
on public.trusted_relationships(target_id, relationship_type);

create table public.safety_cancellations (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references public.applications(id) on delete restrict,
  job_id uuid not null references public.jobs(id) on delete restrict,
  actor_id uuid not null references public.profiles(id) on delete restrict,
  reason text not null,
  details text,
  is_safety_related boolean not null default false,
  reputation_penalty_applied boolean not null default false,
  incident_id uuid references public.safety_incidents(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint safety_cancellation_reason_check check (
    reason in ('schedule_conflict', 'illness', 'transportation_problem', 'scope_changed', 'location_changed', 'person_mismatch', 'unsafe_condition', 'harassment', 'emergency', 'payment_disagreement', 'equipment_issue')
  ),
  constraint safety_cancellation_details_length check (details is null or char_length(details) <= 3000),
  constraint safety_cancellation_reputation_check check (not is_safety_related or not reputation_penalty_applied)
);

create table public.review_private_safety_feedback (
  id uuid primary key default gen_random_uuid(),
  review_id uuid not null unique references public.reviews(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  subject_id uuid not null references public.profiles(id) on delete cascade,
  structured_feedback jsonb not null default '{}'::jsonb,
  notes text,
  created_at timestamptz not null default now(),
  constraint review_private_notes_length check (notes is null or char_length(notes) <= 3000)
);

create table public.message_safety_evidence (
  message_id uuid primary key references public.messages(id) on delete restrict,
  sender_id uuid not null references public.profiles(id) on delete restrict,
  thread_id uuid not null references public.message_threads(id) on delete restrict,
  raw_body text not null,
  body_sha256 text not null,
  category public.safety_report_category not null,
  severity public.safety_incident_severity not null,
  preserved_until timestamptz,
  created_at timestamptz not null default now(),
  constraint message_safety_body_length check (char_length(raw_body) between 1 and 2000),
  constraint message_safety_hash_check check (body_sha256 ~ '^[A-Fa-f0-9]{64}$')
);

create table public.account_security_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  event_type text not null,
  severity text not null default 'review',
  session_reference text,
  event_data jsonb not null default '{}'::jsonb,
  status text not null default 'open',
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  constraint account_security_event_type_length check (char_length(event_type) between 2 and 100),
  constraint account_security_event_severity_check check (severity in ('info', 'review', 'high')),
  constraint account_security_event_status_check check (status in ('open', 'reviewing', 'cleared', 'confirmed'))
);

create index account_security_events_user_idx
on public.account_security_events(user_id, created_at desc);

create table public.jurisdiction_safety_policies (
  id uuid primary key default gen_random_uuid(),
  country_code text not null,
  region_code text,
  minimum_teen_age integer not null default 13,
  maximum_teen_age integer not null default 17,
  prohibited_categories text[] not null default '{}',
  curfew_start time,
  curfew_end time,
  policy_status text not null default 'draft_legal_review',
  enabled boolean not null default false,
  effective_from timestamptz not null default now(),
  effective_until timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint jurisdiction_safety_country_check check (country_code ~ '^[A-Z]{2}$'),
  constraint jurisdiction_safety_region_check check (region_code is null or region_code ~ '^[A-Z]{2}$'),
  constraint jurisdiction_safety_age_check check (
    minimum_teen_age between 13 and 17
    and maximum_teen_age between minimum_teen_age and 17
  ),
  constraint jurisdiction_safety_policy_status_check check (policy_status in ('draft_legal_review', 'approved', 'retired'))
);

create unique index jurisdiction_safety_policy_scope_idx
on public.jurisdiction_safety_policies(country_code, coalesce(region_code, ''), effective_from);

insert into public.jurisdiction_safety_policies (
  country_code, prohibited_categories, policy_status, enabled
)
values (
  'US',
  array[
    'dangerous_heights', 'firearms_weapons', 'hazardous_chemicals',
    'adult_entertainment', 'sexual_services', 'illegal_activity',
    'alcohol_drug_handling', 'private_overnight_work', 'high_risk_machinery',
    'hazardous_construction', 'unsafe_driving', 'nudity_intimate_care'
  ],
  'draft_legal_review',
  false
);

create or replace function private.is_incident_participant(
  p_incident_id uuid,
  p_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.safety_incidents incident
    where incident.id = p_incident_id
      and (
        incident.reporter_id = p_user_id
        or incident.subject_user_id = p_user_id
        or exists (
          select 1
          from public.incident_participants participant
          where participant.incident_id = incident.id
            and participant.user_id = p_user_id
        )
      )
  );
$$;

create or replace function private.can_manage_incident(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.has_admin_safety_role(
    p_user_id,
    array[
      'moderator', 'senior_safety_moderator', 'child_safety_specialist',
      'incident_manager', 'legal_request_reviewer'
    ]::public.admin_safety_role[]
  );
$$;

create or replace function private.can_view_report(
  p_report_id uuid,
  p_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.reports report
    where report.id = p_report_id
      and (
        report.reporter_id = p_user_id
        or (
          report.category in (
            'sexual_harassment', 'sexual_conduct', 'inappropriate_touching',
            'inappropriate_images', 'child_safety_concern',
            'kidnapping_abduction_concern'
          )
          and private.has_admin_safety_role(
            p_user_id,
            array['child_safety_specialist', 'senior_safety_moderator', 'incident_manager']::public.admin_safety_role[]
          )
        )
        or (
          report.category not in (
            'sexual_harassment', 'sexual_conduct', 'inappropriate_touching',
            'inappropriate_images', 'child_safety_concern',
            'kidnapping_abduction_concern'
          )
          and private.can_manage_incident(p_user_id)
        )
      )
  );
$$;

create or replace function private.is_job_safety_participant(
  p_application_id uuid,
  p_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.applications application
    join public.jobs job on job.id = application.job_id
    where application.id = p_application_id
      and (
        application.teen_id = p_user_id
        or job.poster_id = p_user_id
        or application.guardian_id = p_user_id
        or private.can_manage_incident(p_user_id)
      )
  );
$$;

create or replace function private.is_safety_circle_participant(
  p_circle_id uuid,
  p_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.safety_circle_members circle
    where circle.id = p_circle_id
      and (circle.teen_id = p_user_id or circle.contact_id = p_user_id)
  );
$$;

revoke all on function private.is_incident_participant(uuid, uuid)
from public, anon, authenticated;
revoke all on function private.can_manage_incident(uuid)
from public, anon, authenticated;
revoke all on function private.can_view_report(uuid, uuid)
from public, anon, authenticated;
revoke all on function private.is_job_safety_participant(uuid, uuid)
from public, anon, authenticated;
revoke all on function private.is_safety_circle_participant(uuid, uuid)
from public, anon, authenticated;

alter table public.safety_incidents enable row level security;
alter table public.incident_participants enable row level security;
alter table public.incident_evidence enable row level security;
alter table public.incident_evidence_access_grants enable row level security;
alter table public.incident_timeline_events enable row level security;
alter table public.incident_assignments enable row level security;
alter table public.incident_actions enable row level security;
alter table public.incident_preservation_orders enable row level security;
alter table public.incident_law_enforcement_requests enable row level security;
alter table public.incident_contact_attempts enable row level security;
alter table public.incident_appeals enable row level security;
alter table public.incident_outcomes enable row level security;
alter table public.safety_circle_members enable row level security;
alter table public.job_safety_plans enable row level security;
alter table public.job_safety_agreements enable row level security;
alter table public.job_private_locations enable row level security;
alter table public.private_data_access_events enable row level security;
alter table public.job_location_share_sessions enable row level security;
alter table public.job_arrival_handshakes enable row level security;
alter table public.job_checkins enable row level security;
alter table public.trusted_relationships enable row level security;
alter table public.safety_cancellations enable row level security;
alter table public.review_private_safety_feedback enable row level security;
alter table public.message_safety_evidence enable row level security;
alter table public.account_security_events enable row level security;
alter table public.jurisdiction_safety_policies enable row level security;

drop policy if exists reports_select_reporter_or_admin on public.reports;
drop policy if exists reports_update_admin on public.reports;

create policy reports_select_submitter_or_authorized
on public.reports for select to authenticated
using (private.can_view_report(id, (select auth.uid())));

create policy reports_update_authorized_moderator
on public.reports for update to authenticated
using (private.can_view_report(id, (select auth.uid())) and private.can_manage_incident((select auth.uid())))
with check (private.can_view_report(id, (select auth.uid())) and private.can_manage_incident((select auth.uid())));

create policy safety_incidents_authorized_admin_select
on public.safety_incidents for select to authenticated
using (private.can_manage_incident((select auth.uid())));

create policy incident_participants_authorized_admin_select
on public.incident_participants for select to authenticated
using (private.can_manage_incident((select auth.uid())));

create policy incident_evidence_authorized_grant_select
on public.incident_evidence for select to authenticated
using (
  private.can_manage_incident((select auth.uid()))
  and exists (
    select 1
    from public.incident_evidence_access_grants access_grant
    where access_grant.evidence_id = incident_evidence.id
      and access_grant.reviewer_id = (select auth.uid())
      and access_grant.revoked_at is null
      and access_grant.expires_at > now()
  )
);

create policy incident_evidence_access_grants_reviewer_select
on public.incident_evidence_access_grants for select to authenticated
using (reviewer_id = (select auth.uid()));

create policy incident_timeline_authorized_admin_select
on public.incident_timeline_events for select to authenticated
using (private.can_manage_incident((select auth.uid())));

create policy incident_assignments_authorized_admin_select
on public.incident_assignments for select to authenticated
using (private.can_manage_incident((select auth.uid())));

create policy incident_actions_authorized_admin_select
on public.incident_actions for select to authenticated
using (private.can_manage_incident((select auth.uid())));

create policy preservation_orders_incident_or_legal_select
on public.incident_preservation_orders for select to authenticated
using (
  private.has_admin_safety_role(
    (select auth.uid()),
    array['incident_manager', 'legal_request_reviewer']::public.admin_safety_role[]
  )
);

create policy law_requests_legal_reviewer_select
on public.incident_law_enforcement_requests for select to authenticated
using (
  private.has_admin_safety_role(
    (select auth.uid()),
    array['legal_request_reviewer']::public.admin_safety_role[]
  )
);

create policy incident_contacts_authorized_admin_select
on public.incident_contact_attempts for select to authenticated
using (private.can_manage_incident((select auth.uid())));

create policy incident_appeals_owner_or_authorized_select
on public.incident_appeals for select to authenticated
using (
  appellant_id = (select auth.uid())
  or private.can_manage_incident((select auth.uid()))
);

create policy incident_outcomes_authorized_admin_select
on public.incident_outcomes for select to authenticated
using (private.can_manage_incident((select auth.uid())));

create policy safety_circle_participants_select
on public.safety_circle_members for select to authenticated
using (teen_id = (select auth.uid()) or contact_id = (select auth.uid()));

create policy job_safety_plans_participants_select
on public.job_safety_plans for select to authenticated
using (private.is_job_safety_participant(application_id, (select auth.uid())));

create policy job_safety_agreements_participants_select
on public.job_safety_agreements for select to authenticated
using (private.is_job_safety_participant(application_id, (select auth.uid())));

create policy private_access_events_authorized_admin_select
on public.private_data_access_events for select to authenticated
using (
  private.has_admin_safety_role(
    (select auth.uid()),
    array['verification_reviewer', 'incident_manager', 'legal_request_reviewer', 'senior_safety_moderator']::public.admin_safety_role[]
  )
);

create policy job_checkins_participant_select
on public.job_checkins for select to authenticated
using (private.is_job_safety_participant(application_id, (select auth.uid())));

create policy trusted_relationships_owner_select
on public.trusted_relationships for select to authenticated
using (owner_id = (select auth.uid()));

create policy safety_cancellations_participant_select
on public.safety_cancellations for select to authenticated
using (private.is_job_safety_participant(application_id, (select auth.uid())));

create policy review_private_safety_author_or_specialist_select
on public.review_private_safety_feedback for select to authenticated
using (
  author_id = (select auth.uid())
  or private.has_admin_safety_role(
    (select auth.uid()),
    array['moderator', 'senior_safety_moderator', 'child_safety_specialist', 'incident_manager']::public.admin_safety_role[]
  )
);

create policy message_safety_evidence_specialist_select
on public.message_safety_evidence for select to authenticated
using (
  private.has_admin_safety_role(
    (select auth.uid()),
    array['senior_safety_moderator', 'child_safety_specialist', 'incident_manager']::public.admin_safety_role[]
  )
);

create policy account_security_events_owner_or_safety_select
on public.account_security_events for select to authenticated
using (
  user_id = (select auth.uid())
  or private.has_admin_safety_role(
    (select auth.uid()),
    array['senior_safety_moderator', 'verification_reviewer', 'incident_manager']::public.admin_safety_role[]
  )
);

create policy jurisdiction_safety_approved_select
on public.jurisdiction_safety_policies for select to authenticated
using (
  (enabled and policy_status = 'approved')
  or private.has_admin_safety_role(
    (select auth.uid()),
    array['senior_safety_moderator', 'child_safety_specialist', 'incident_manager', 'legal_request_reviewer']::public.admin_safety_role[]
  )
);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'incident-evidence',
  'incident-evidence',
  false,
  15728640,
  array['image/jpeg', 'image/png', 'application/pdf', 'text/plain']
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

create policy incident_evidence_participant_upload
on storage.objects for insert to authenticated
with check (
  bucket_id = 'incident-evidence'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and (storage.foldername(name))[2] ~ '^[0-9a-fA-F-]{36}$'
  and name !~ '(^|/)\.\.(/|$)'
  and lower(storage.extension(name)) in ('jpg', 'jpeg', 'png', 'pdf', 'txt')
  and private.is_incident_participant(
    ((storage.foldername(name))[2])::uuid,
    (select auth.uid())
  )
);

create policy incident_evidence_delete_unregistered
on storage.objects for delete to authenticated
using (
  bucket_id = 'incident-evidence'
  and owner_id = (select auth.uid())::text
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and not exists (
    select 1 from public.incident_evidence evidence
    where evidence.storage_path = name
  )
);

create policy incident_evidence_authorized_reviewer_read
on storage.objects for select to authenticated
using (
  bucket_id = 'incident-evidence'
  and private.can_manage_incident((select auth.uid()))
  and exists (
    select 1
    from public.incident_evidence evidence
    join public.incident_evidence_access_grants access_grant
      on access_grant.evidence_id = evidence.id
    where evidence.storage_path = name
      and access_grant.reviewer_id = (select auth.uid())
      and access_grant.revoked_at is null
      and access_grant.expires_at > now()
  )
);

create or replace function private.normalize_safety_report()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.category = 'other_urgent_concern' then
    new.category := case lower(coalesce(new.reason, ''))
      when 'harassment' then 'harassment'::public.safety_report_category
      when 'sexual_content' then 'sexual_conduct'::public.safety_report_category
      when 'exploitation' then 'child_safety_concern'::public.safety_report_category
      when 'scam' then 'scam'::public.safety_report_category
      when 'privacy' then 'personal_information_request'::public.safety_report_category
      when 'contact_sharing' then 'off_platform_pressure'::public.safety_report_category
      when 'discrimination' then 'discrimination'::public.safety_report_category
      when 'unsafe_job' then 'unsafe_job_conditions'::public.safety_report_category
      else new.category
    end;
  end if;

  if new.immediate_danger then
    new.severity := 'critical';
  elsif new.category in (
    'kidnapping_abduction_concern', 'assault', 'attempted_assault',
    'sexual_conduct', 'inappropriate_touching', 'child_safety_concern',
    'weapons', 'threats', 'blackmail', 'doxxing'
  ) and new.severity in ('low', 'moderate') then
    new.severity := 'high';
  end if;

  if new.category in (
    'kidnapping_abduction_concern', 'assault', 'attempted_assault',
    'sexual_harassment', 'sexual_conduct', 'inappropriate_touching',
    'child_safety_concern', 'weapons', 'threats', 'blackmail',
    'doxxing', 'identity_mismatch', 'account_sharing'
  ) then
    new.evidence_preserved := true;
  end if;

  new.details := nullif(left(btrim(coalesce(new.details, '')), 5000), '');
  new.location_type := nullif(left(btrim(coalesce(new.location_type, '')), 100), '');
  new.desired_outcome := nullif(left(btrim(coalesce(new.desired_outcome, '')), 1000), '');
  return new;
end;
$$;

create trigger reports_normalize_safety_fields
before insert or update of category, severity, immediate_danger, details
on public.reports
for each row execute function private.normalize_safety_report();

create or replace function private.create_incident_for_report()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_incident public.safety_incidents%rowtype;
  v_priority smallint;
  v_sla interval;
begin
  if new.incident_id is not null then
    return new;
  end if;

  v_priority := case new.severity
    when 'critical' then 1
    when 'high' then 2
    when 'moderate' then 3
    else 4
  end;
  v_sla := case new.severity
    when 'critical' then interval '15 minutes'
    when 'high' then interval '2 hours'
    when 'moderate' then interval '24 hours'
    else interval '72 hours'
  end;

  insert into public.safety_incidents (
    initial_report_id, reporter_id, subject_user_id, job_id, application_id,
    category, severity, immediate_danger, priority, sla_due_at,
    preservation_status
  ) values (
    new.id, new.reporter_id, new.target_user_id, new.target_job_id,
    new.related_application_id, new.category, new.severity,
    new.immediate_danger, v_priority, now() + v_sla,
    case when new.evidence_preserved then 'preserve_relevant_records' else 'standard_retention' end
  ) returning * into v_incident;

  update public.reports
  set incident_id = v_incident.id
  where id = new.id;

  if new.reporter_id is not null then
    insert into public.incident_participants (
      incident_id, user_id, participant_role
    ) values (
      v_incident.id, new.reporter_id, 'reporter'
    ) on conflict do nothing;
  end if;
  if new.target_user_id is not null and new.target_user_id is distinct from new.reporter_id then
    insert into public.incident_participants (
      incident_id, user_id, participant_role
    ) values (
      v_incident.id, new.target_user_id, 'accused_person'
    ) on conflict do nothing;
  end if;

  insert into public.incident_timeline_events (
    incident_id, actor_id, event_type, public_status_note,
    event_data
  ) values (
    v_incident.id,
    new.reporter_id,
    'report_submitted',
    'Report received and queued for safety review.',
    jsonb_build_object('severity', new.severity, 'category', new.category)
  );

  return new;
end;
$$;

create trigger reports_create_incident_case
after insert on public.reports
for each row execute function private.create_incident_for_report();

update public.reports
set category = case lower(reason)
    when 'harassment' then 'harassment'::public.safety_report_category
    when 'sexual_content' then 'sexual_conduct'::public.safety_report_category
    when 'exploitation' then 'child_safety_concern'::public.safety_report_category
    when 'scam' then 'scam'::public.safety_report_category
    when 'privacy' then 'personal_information_request'::public.safety_report_category
    when 'contact_sharing' then 'off_platform_pressure'::public.safety_report_category
    when 'discrimination' then 'discrimination'::public.safety_report_category
    when 'unsafe_job' then 'unsafe_job_conditions'::public.safety_report_category
    else 'other_urgent_concern'::public.safety_report_category
  end,
  severity = case
    when lower(reason) in ('sexual_content', 'exploitation', 'harassment')
      then 'high'::public.safety_incident_severity
    else severity
  end,
  evidence_preserved = lower(reason) in ('sexual_content', 'exploitation', 'harassment')
where incident_id is null;

insert into public.safety_incidents (
  initial_report_id, reporter_id, subject_user_id, job_id,
  category, severity, immediate_danger, priority, sla_due_at,
  preservation_status, created_at, updated_at
)
select
  report.id,
  report.reporter_id,
  report.target_user_id,
  report.target_job_id,
  report.category,
  report.severity,
  report.immediate_danger,
  case report.severity
    when 'critical' then 1
    when 'high' then 2
    when 'moderate' then 3
    else 4
  end,
  report.created_at + case report.severity
    when 'critical' then interval '15 minutes'
    when 'high' then interval '2 hours'
    when 'moderate' then interval '24 hours'
    else interval '72 hours'
  end,
  case when report.evidence_preserved then 'preserve_relevant_records' else 'standard_retention' end,
  report.created_at,
  report.updated_at
from public.reports report
where report.incident_id is null
  and not exists (
    select 1 from public.safety_incidents incident
    where incident.initial_report_id = report.id
  );

update public.reports report
set incident_id = incident.id
from public.safety_incidents incident
where incident.initial_report_id = report.id
  and report.incident_id is null;

insert into public.incident_participants (
  incident_id, user_id, participant_role
)
select incident.id, incident.reporter_id, 'reporter'
from public.safety_incidents incident
where incident.reporter_id is not null
on conflict do nothing;

insert into public.incident_participants (
  incident_id, user_id, participant_role
)
select incident.id, incident.subject_user_id, 'accused_person'
from public.safety_incidents incident
where incident.subject_user_id is not null
  and incident.subject_user_id is distinct from incident.reporter_id
on conflict do nothing;

insert into public.incident_timeline_events (
  incident_id, actor_id, event_type, public_status_note,
  event_data, created_at
)
select
  incident.id,
  incident.reporter_id,
  'report_migrated',
  'Report is available in the restricted incident system.',
  jsonb_build_object('severity', incident.severity, 'category', incident.category),
  incident.created_at
from public.safety_incidents incident
where not exists (
  select 1 from public.incident_timeline_events event
  where event.incident_id = incident.id
);

create or replace function public.submit_safety_report(
  p_target_user_id uuid default null,
  p_target_job_id uuid default null,
  p_target_message_id uuid default null,
  p_target_review_id uuid default null,
  p_application_id uuid default null,
  p_category text default 'other_urgent_concern',
  p_severity text default 'moderate',
  p_immediate_danger boolean default false,
  p_details text default null,
  p_occurred_at timestamptz default null,
  p_location_type text default null,
  p_desired_outcome text default null,
  p_confidential_safety_feedback boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_category public.safety_report_category;
  v_severity public.safety_incident_severity;
  v_report public.reports%rowtype;
  v_incident public.safety_incidents%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if not public.is_profile_active(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'user_account_restricted');
  end if;
  if p_target_user_id is null and p_target_job_id is null
     and p_target_message_id is null and p_target_review_id is null then
    return jsonb_build_object('ok', false, 'code', 'report_target_required');
  end if;
  if p_target_user_id = auth.uid() then
    return jsonb_build_object('ok', false, 'code', 'cannot_report_self');
  end if;
  if char_length(btrim(coalesce(p_details, ''))) < 10 then
    return jsonb_build_object('ok', false, 'code', 'report_details_required');
  end if;

  begin
    v_category := lower(btrim(p_category))::public.safety_report_category;
    v_severity := lower(btrim(p_severity))::public.safety_incident_severity;
  exception when invalid_text_representation then
    return jsonb_build_object('ok', false, 'code', 'invalid_report_classification');
  end;

  insert into public.reports (
    reporter_id, target_user_id, target_job_id, target_message_id,
    target_review_id, related_application_id, reason, details,
    category, severity, immediate_danger, occurred_at, location_type,
    desired_outcome, confidential_safety_feedback
  ) values (
    auth.uid(), p_target_user_id, p_target_job_id, p_target_message_id,
    p_target_review_id, p_application_id, v_category::text,
    left(btrim(p_details), 5000), v_category, v_severity,
    p_immediate_danger, p_occurred_at,
    nullif(left(btrim(coalesce(p_location_type, '')), 100), ''),
    nullif(left(btrim(coalesce(p_desired_outcome, '')), 1000), ''),
    p_confidential_safety_feedback
  ) returning * into v_report;

  select * into v_incident
  from public.safety_incidents incident
  where incident.initial_report_id = v_report.id;

  if p_immediate_danger then
    perform public.enqueue_notification(
      auth.uid(),
      'Urgent report recorded',
      'MORT recorded your report. Contact local emergency services now if anyone is in immediate danger.',
      jsonb_build_object('reportId', v_report.id, 'incidentId', v_incident.id)
    );
  end if;

  return jsonb_build_object(
    'ok', true,
    'report_id', v_report.id,
    'incident_id', v_incident.id,
    'case_number', v_incident.case_number,
    'status', v_incident.status,
    'immediate_danger_guidance', p_immediate_danger
  );
end;
$$;

create or replace function public.get_my_incident_cases()
returns table (
  incident_id uuid,
  case_number text,
  category public.safety_report_category,
  severity public.safety_incident_severity,
  status public.safety_incident_status,
  public_status_note text,
  created_at timestamptz,
  updated_at timestamptz,
  appeal_status text
)
language sql
stable
security definer
set search_path = 'public', 'pg_temp'
as $$
  select
    incident.id,
    incident.case_number,
    incident.category,
    incident.severity,
    incident.status,
    (
      select event.public_status_note
      from public.incident_timeline_events event
      where event.incident_id = incident.id
        and event.public_status_note is not null
      order by event.created_at desc
      limit 1
    ),
    incident.created_at,
    incident.updated_at,
    incident.appeal_status
  from public.safety_incidents incident
  where auth.uid() is not null
    and private.is_incident_participant(incident.id, auth.uid())
  order by incident.created_at desc;
$$;

create or replace function public.register_incident_evidence(
  p_incident_id uuid,
  p_evidence_id uuid,
  p_storage_path text,
  p_evidence_type text,
  p_sha256 text default null
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'storage', 'pg_temp'
as $$
declare
  v_mime text;
  v_size bigint;
  v_expected_prefix text;
  v_evidence public.incident_evidence%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if not private.is_incident_participant(p_incident_id, auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'incident_access_denied');
  end if;
  if char_length(btrim(coalesce(p_evidence_type, ''))) < 2 then
    return jsonb_build_object('ok', false, 'code', 'evidence_type_required');
  end if;

  v_expected_prefix := auth.uid()::text || '/' || p_incident_id::text || '/' || p_evidence_id::text;
  if p_storage_path is null
     or p_storage_path not like v_expected_prefix || '.%'
     or position('..' in p_storage_path) > 0 then
    return jsonb_build_object('ok', false, 'code', 'invalid_evidence_path');
  end if;

  select
    lower(coalesce(object.metadata->>'mimetype', '')),
    case when coalesce(object.metadata->>'size', '') ~ '^[0-9]+$'
      then (object.metadata->>'size')::bigint else 0 end
  into v_mime, v_size
  from storage.objects object
  where object.bucket_id = 'incident-evidence'
    and object.name = p_storage_path
    and object.owner_id = auth.uid()::text;

  if not found then
    return jsonb_build_object('ok', false, 'code', 'evidence_object_not_found');
  end if;
  if v_mime not in ('image/jpeg', 'image/png', 'application/pdf', 'text/plain') then
    return jsonb_build_object('ok', false, 'code', 'evidence_file_type_invalid');
  end if;
  if v_size < 1 or v_size > 15728640 then
    return jsonb_build_object('ok', false, 'code', 'evidence_file_size_invalid');
  end if;
  if p_sha256 is not null and p_sha256 !~ '^[A-Fa-f0-9]{64}$' then
    return jsonb_build_object('ok', false, 'code', 'evidence_hash_invalid');
  end if;

  insert into public.incident_evidence (
    id, incident_id, submitted_by, evidence_type, storage_path,
    content_type, byte_size, sha256, preserved_until
  ) values (
    p_evidence_id, p_incident_id, auth.uid(),
    left(btrim(p_evidence_type), 80), p_storage_path,
    v_mime, v_size, upper(p_sha256),
    case when exists (
      select 1 from public.safety_incidents incident
      where incident.id = p_incident_id
        and (incident.legal_hold or incident.preservation_status = 'preserve_relevant_records')
    ) then now() + interval '1 year' else null end
  ) returning * into v_evidence;

  insert into public.incident_timeline_events (
    incident_id, actor_id, event_type, public_status_note,
    event_data
  ) values (
    p_incident_id,
    auth.uid(),
    'evidence_submitted',
    'Additional evidence was received.',
    jsonb_build_object('evidence_id', p_evidence_id, 'evidence_type', p_evidence_type, 'byte_size', v_size)
  );

  return jsonb_build_object('ok', true, 'evidence_id', v_evidence.id, 'status', v_evidence.evidence_status);
exception when unique_violation then
  select * into v_evidence
  from public.incident_evidence evidence
  where evidence.id = p_evidence_id
    and evidence.incident_id = p_incident_id
    and evidence.submitted_by = auth.uid()
    and evidence.storage_path = p_storage_path;
  if v_evidence.id is not null then
    return jsonb_build_object('ok', true, 'idempotent', true, 'evidence_id', v_evidence.id, 'status', v_evidence.evidence_status);
  end if;
  return jsonb_build_object('ok', false, 'code', 'evidence_conflict');
end;
$$;

create or replace function public.authorize_incident_evidence_access(
  p_evidence_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_evidence public.incident_evidence%rowtype;
  v_grant public.incident_evidence_access_grants%rowtype;
begin
  if auth.uid() is null or not private.can_manage_incident(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'incident_reviewer_required');
  end if;
  if char_length(btrim(coalesce(p_reason, ''))) < 10 then
    return jsonb_build_object('ok', false, 'code', 'evidence_access_reason_required');
  end if;

  select * into v_evidence from public.incident_evidence where id = p_evidence_id;
  if v_evidence.id is null then
    return jsonb_build_object('ok', false, 'code', 'evidence_not_found');
  end if;

  insert into public.incident_evidence_access_grants (
    evidence_id, reviewer_id, access_reason, expires_at
  ) values (
    p_evidence_id, auth.uid(), left(btrim(p_reason), 500), now() + interval '5 minutes'
  ) returning * into v_grant;

  insert into public.incident_timeline_events (
    incident_id, actor_id, event_type, restricted_note,
    event_data
  ) values (
    v_evidence.incident_id,
    auth.uid(),
    'evidence_access_authorized',
    left(btrim(p_reason), 500),
    jsonb_build_object('evidence_id', p_evidence_id, 'expires_at', v_grant.expires_at)
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

create or replace function public.admin_update_incident_case(
  p_incident_id uuid,
  p_status text,
  p_public_status_note text,
  p_restricted_note text default null,
  p_severity text default null
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_status public.safety_incident_status;
  v_severity public.safety_incident_severity;
  v_incident public.safety_incidents%rowtype;
begin
  if auth.uid() is null or not private.can_manage_incident(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'incident_reviewer_required');
  end if;
  if char_length(btrim(coalesce(p_public_status_note, ''))) < 5 then
    return jsonb_build_object('ok', false, 'code', 'public_status_note_required');
  end if;
  begin
    v_status := lower(btrim(p_status))::public.safety_incident_status;
    v_severity := coalesce(lower(btrim(p_severity))::public.safety_incident_severity, null);
  exception when invalid_text_representation then
    return jsonb_build_object('ok', false, 'code', 'invalid_incident_update');
  end;

  update public.safety_incidents
  set status = v_status,
      severity = coalesce(v_severity, severity),
      updated_at = now(),
      closed_at = case when v_status in ('closed', 'resolved') then now() else closed_at end
  where id = p_incident_id
  returning * into v_incident;

  if v_incident.id is null then
    return jsonb_build_object('ok', false, 'code', 'incident_not_found');
  end if;

  insert into public.incident_timeline_events (
    incident_id, actor_id, event_type, public_status_note,
    restricted_note, event_data
  ) values (
    p_incident_id,
    auth.uid(),
    'case_status_updated',
    left(btrim(p_public_status_note), 1000),
    nullif(left(btrim(coalesce(p_restricted_note, '')), 5000), ''),
    jsonb_build_object('status', v_status, 'severity', v_incident.severity)
  );

  return jsonb_build_object('ok', true, 'incident_id', v_incident.id, 'case_number', v_incident.case_number, 'status', v_incident.status);
end;
$$;

create or replace function public.place_incident_preservation_hold(
  p_incident_id uuid,
  p_legal_basis text,
  p_scope text,
  p_expires_at timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_order public.incident_preservation_orders%rowtype;
begin
  if auth.uid() is null or not private.has_admin_safety_role(
    auth.uid(),
    array['incident_manager', 'legal_request_reviewer']::public.admin_safety_role[]
  ) then
    return jsonb_build_object('ok', false, 'code', 'preservation_authority_required');
  end if;
  if char_length(btrim(coalesce(p_legal_basis, ''))) < 10
     or char_length(btrim(coalesce(p_scope, ''))) < 10
     or p_expires_at <= now() then
    return jsonb_build_object('ok', false, 'code', 'invalid_preservation_order');
  end if;

  insert into public.incident_preservation_orders (
    incident_id, ordered_by, legal_basis, scope, expires_at
  ) values (
    p_incident_id, auth.uid(), left(btrim(p_legal_basis), 2000),
    left(btrim(p_scope), 2000), p_expires_at
  ) returning * into v_order;

  update public.safety_incidents
  set legal_hold = true, preservation_status = 'legal_hold', updated_at = now()
  where id = p_incident_id;
  update public.incident_evidence
  set preserved_until = greatest(coalesce(preserved_until, p_expires_at), p_expires_at)
  where incident_id = p_incident_id;

  insert into public.incident_timeline_events (
    incident_id, actor_id, event_type, restricted_note,
    event_data
  ) values (
    p_incident_id, auth.uid(), 'preservation_hold_placed',
    left(btrim(p_legal_basis), 5000),
    jsonb_build_object('order_id', v_order.id, 'expires_at', p_expires_at, 'scope', p_scope)
  );

  return jsonb_build_object('ok', true, 'order_id', v_order.id, 'expires_at', v_order.expires_at);
end;
$$;

create or replace function public.submit_incident_appeal(
  p_incident_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_appeal public.incident_appeals%rowtype;
begin
  if auth.uid() is null or not private.is_incident_participant(p_incident_id, auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'incident_access_denied');
  end if;
  if char_length(btrim(coalesce(p_reason, ''))) < 20 then
    return jsonb_build_object('ok', false, 'code', 'appeal_reason_required');
  end if;
  if exists (
    select 1 from public.incident_appeals appeal
    where appeal.incident_id = p_incident_id
      and appeal.appellant_id = auth.uid()
      and appeal.status in ('pending', 'reviewing')
  ) then
    return jsonb_build_object('ok', false, 'code', 'appeal_already_pending');
  end if;

  insert into public.incident_appeals (
    incident_id, appellant_id, reason
  ) values (
    p_incident_id, auth.uid(), left(btrim(p_reason), 3000)
  ) returning * into v_appeal;

  update public.safety_incidents
  set status = 'appeal_pending', appeal_status = 'pending', updated_at = now()
  where id = p_incident_id;

  insert into public.incident_timeline_events (
    incident_id, actor_id, event_type, public_status_note
  ) values (
    p_incident_id, auth.uid(), 'appeal_submitted', 'An appeal was submitted for independent review.'
  );

  return jsonb_build_object('ok', true, 'appeal_id', v_appeal.id, 'status', v_appeal.status);
end;
$$;

create or replace function public.admin_record_law_enforcement_request(
  p_incident_id uuid,
  p_request_reference text,
  p_agency_name text,
  p_request_type text,
  p_scope_summary text,
  p_received_at timestamptz,
  p_emergency_request boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_request public.incident_law_enforcement_requests%rowtype;
begin
  if auth.uid() is null or not private.has_admin_safety_role(
    auth.uid(),
    array['legal_request_reviewer']::public.admin_safety_role[]
  ) then
    return jsonb_build_object('ok', false, 'code', 'legal_request_reviewer_required');
  end if;
  if char_length(btrim(coalesce(p_request_reference, ''))) < 3
     or char_length(btrim(coalesce(p_agency_name, ''))) < 2
     or char_length(btrim(coalesce(p_scope_summary, ''))) < 10 then
    return jsonb_build_object('ok', false, 'code', 'invalid_law_enforcement_request');
  end if;

  insert into public.incident_law_enforcement_requests (
    incident_id, request_reference, agency_name, request_type,
    scope_summary, received_at, emergency_request
  ) values (
    p_incident_id, left(btrim(p_request_reference), 120),
    left(btrim(p_agency_name), 200), left(btrim(p_request_type), 100),
    left(btrim(p_scope_summary), 2000), p_received_at, p_emergency_request
  ) returning * into v_request;

  insert into public.incident_timeline_events (
    incident_id, actor_id, event_type, restricted_note,
    event_data
  ) values (
    p_incident_id, auth.uid(), 'law_enforcement_request_received',
    'Request recorded; identity validation and legal review remain pending.',
    jsonb_build_object('request_id', v_request.id, 'emergency_request', p_emergency_request)
  );

  return jsonb_build_object('ok', true, 'request_id', v_request.id, 'status', v_request.status);
end;
$$;

create or replace function public.create_safety_circle_invite(
  p_relationship_label text,
  p_permissions jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'extensions', 'pg_temp'
as $$
declare
  v_profile public.profiles%rowtype;
  v_code text;
  v_circle public.safety_circle_members%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  select * into v_profile from public.profiles where id = auth.uid();
  if v_profile.role <> 'teen' then
    return jsonb_build_object('ok', false, 'code', 'teen_role_required');
  end if;
  if char_length(btrim(coalesce(p_relationship_label, ''))) < 2 then
    return jsonb_build_object('ok', false, 'code', 'relationship_required');
  end if;
  if (
    select count(*)
    from public.safety_circle_members circle
    where circle.teen_id = auth.uid()
      and circle.status in ('invited', 'active')
  ) >= 5 then
    return jsonb_build_object('ok', false, 'code', 'safety_circle_limit_reached');
  end if;

  v_code := upper(substr(encode(extensions.gen_random_bytes(8), 'hex'), 1, 10));
  insert into public.safety_circle_members (
    teen_id, relationship_label, invite_code_hash, invite_expires_at,
    receive_safety_ping, receive_missed_checkin, receive_job_summary,
    receive_job_status, receive_emergency_request,
    view_limited_safety_plan, receive_completion
  ) values (
    auth.uid(), left(btrim(p_relationship_label), 60),
    extensions.digest(v_code, 'sha256'), now() + interval '7 days',
    coalesce((p_permissions->>'receive_safety_ping')::boolean, true),
    coalesce((p_permissions->>'receive_missed_checkin')::boolean, true),
    coalesce((p_permissions->>'receive_job_summary')::boolean, false),
    coalesce((p_permissions->>'receive_job_status')::boolean, false),
    coalesce((p_permissions->>'receive_emergency_request')::boolean, true),
    coalesce((p_permissions->>'view_limited_safety_plan')::boolean, false),
    coalesce((p_permissions->>'receive_completion')::boolean, false)
  ) returning * into v_circle;

  return jsonb_build_object(
    'ok', true,
    'circle_id', v_circle.id,
    'invite_code', v_code,
    'expires_at', v_circle.invite_expires_at,
    'guardian_mode_optional', true,
    'full_account_control', false
  );
end;
$$;

create or replace function public.accept_safety_circle_invite(p_invite_code text)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'extensions', 'pg_temp'
as $$
declare
  v_profile public.profiles%rowtype;
  v_circle public.safety_circle_members%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  select * into v_profile from public.profiles where id = auth.uid();
  if v_profile.role not in ('adult', 'guardian') then
    return jsonb_build_object('ok', false, 'code', 'trusted_adult_role_required');
  end if;
  if not private.has_marketplace_identity(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'identity_verification_required');
  end if;

  select * into v_circle
  from public.safety_circle_members circle
  where circle.invite_code_hash = extensions.digest(upper(btrim(p_invite_code)), 'sha256')
    and circle.status = 'invited'
    and circle.invite_expires_at > now()
  for update;

  if v_circle.id is null then
    return jsonb_build_object('ok', false, 'code', 'safety_circle_invite_invalid');
  end if;
  if v_circle.teen_id = auth.uid() then
    return jsonb_build_object('ok', false, 'code', 'cannot_accept_own_invite');
  end if;

  update public.safety_circle_members
  set contact_id = auth.uid(), status = 'active', accepted_at = now(), updated_at = now()
  where id = v_circle.id
  returning * into v_circle;

  perform public.enqueue_notification(
    v_circle.teen_id,
    'Safety Circle contact linked',
    'A trusted contact accepted your Safety Circle invitation. You remain in control of ordinary sharing.',
    jsonb_build_object('safetyCircleId', v_circle.id)
  );

  return jsonb_build_object('ok', true, 'circle_id', v_circle.id, 'status', v_circle.status);
end;
$$;

create or replace function public.update_safety_circle_permissions(
  p_circle_id uuid,
  p_permissions jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_circle public.safety_circle_members%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  update public.safety_circle_members
  set receive_safety_ping = coalesce((p_permissions->>'receive_safety_ping')::boolean, receive_safety_ping),
      receive_missed_checkin = coalesce((p_permissions->>'receive_missed_checkin')::boolean, receive_missed_checkin),
      receive_job_summary = coalesce((p_permissions->>'receive_job_summary')::boolean, receive_job_summary),
      receive_job_status = coalesce((p_permissions->>'receive_job_status')::boolean, receive_job_status),
      receive_emergency_request = coalesce((p_permissions->>'receive_emergency_request')::boolean, receive_emergency_request),
      view_limited_safety_plan = coalesce((p_permissions->>'view_limited_safety_plan')::boolean, view_limited_safety_plan),
      receive_completion = coalesce((p_permissions->>'receive_completion')::boolean, receive_completion),
      updated_at = now()
  where id = p_circle_id
    and teen_id = auth.uid()
    and status in ('invited', 'active')
  returning * into v_circle;

  if v_circle.id is null then
    return jsonb_build_object('ok', false, 'code', 'safety_circle_not_found');
  end if;
  return jsonb_build_object('ok', true, 'circle_id', v_circle.id, 'status', v_circle.status);
end;
$$;

create or replace function public.unlink_safety_circle_member(p_circle_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_circle public.safety_circle_members%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  update public.safety_circle_members
  set status = 'revoked', revoked_at = now(), updated_at = now()
  where id = p_circle_id
    and (teen_id = auth.uid() or contact_id = auth.uid())
    and status in ('invited', 'active')
  returning * into v_circle;
  if v_circle.id is null then
    return jsonb_build_object('ok', false, 'code', 'safety_circle_not_found');
  end if;
  return jsonb_build_object('ok', true, 'circle_id', v_circle.id, 'status', v_circle.status);
end;
$$;

create or replace function public.get_my_safety_circle()
returns table (
  id uuid,
  teen_id uuid,
  contact_id uuid,
  relationship_label text,
  status text,
  receive_safety_ping boolean,
  receive_missed_checkin boolean,
  receive_job_summary boolean,
  receive_job_status boolean,
  receive_emergency_request boolean,
  view_limited_safety_plan boolean,
  receive_completion boolean,
  created_at timestamptz,
  accepted_at timestamptz
)
language sql
stable
security definer
set search_path = 'public', 'pg_temp'
as $$
  select
    circle.id, circle.teen_id, circle.contact_id, circle.relationship_label,
    circle.status, circle.receive_safety_ping, circle.receive_missed_checkin,
    circle.receive_job_summary, circle.receive_job_status,
    circle.receive_emergency_request, circle.view_limited_safety_plan,
    circle.receive_completion, circle.created_at, circle.accepted_at
  from public.safety_circle_members circle
  where auth.uid() is not null
    and (circle.teen_id = auth.uid() or circle.contact_id = auth.uid())
  order by circle.created_at desc;
$$;

create or replace function private.notify_safety_circle_ping()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_contact record;
begin
  for v_contact in
    select circle.contact_id
    from public.safety_circle_members circle
    where circle.teen_id = new.teen_id
      and circle.status = 'active'
      and circle.contact_id is not null
      and circle.receive_safety_ping
  loop
    perform public.enqueue_notification(
      v_contact.contact_id,
      case when new.status = 'needs_help' then 'Safety Circle help ping' else 'Safety Circle check-in' end,
      case
        when new.status = 'needs_help' then 'A Safety Circle member sent a help ping. Contact emergency services for immediate danger.'
        else 'A Safety Circle member sent a check-in.'
      end,
      jsonb_build_object('safetyPingId', new.id, 'teenId', new.teen_id, 'jobId', new.job_id)
    );
  end loop;
  return new;
end;
$$;

create trigger safety_pings_notify_safety_circle
after insert on public.safety_pings
for each row execute function private.notify_safety_circle_ping();

drop policy if exists safety_pings_select_participant on public.safety_pings;
create policy safety_pings_select_authorized_participant
on public.safety_pings for select to authenticated
using (
  teen_id = (select auth.uid())
  or public.guardian_receives_safety_pings(teen_id, (select auth.uid()))
  or exists (
    select 1
    from public.safety_circle_members circle
    where circle.teen_id = safety_pings.teen_id
      and circle.contact_id = (select auth.uid())
      and circle.status = 'active'
      and circle.receive_safety_ping
  )
  or public.is_admin()
);

create or replace function private.job_safety_terms(
  p_application_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'agreement_version', 1,
    'job_id', job.id,
    'job_title', job.title,
    'scope', job.description,
    'schedule', jsonb_build_object('starts_at', job.starts_at, 'ends_at', job.ends_at, 'schedule_type', job.schedule_type),
    'approximate_location', jsonb_build_object('city', job.city, 'state', job.state, 'area', job.location_text, 'location_type', job.location_type),
    'exact_location_release', 'Only after acceptance and both confirmations, while the job is active.',
    'private_location_version', coalesce((
      select location.location_version
      from public.job_private_locations location
      where location.job_id = job.id
    ), 0),
    'private_location_available', exists (
      select 1
      from public.job_private_locations location
      where location.job_id = job.id
    ),
    'who_will_be_present', coalesce(job.who_will_be_present, case when job.adult_supervision_present then 'The job poster reports adult supervision will be present.' else 'Presence details require confirmation.' end),
    'equipment', jsonb_build_object('provided', job.equipment_provided, 'worker_brings', job.equipment_worker_brings, 'risk_disclosed', job.equipment_risk_disclosed, 'risk_notes', job.equipment_risk_notes),
    'physical_requirements', job.physical_requirements,
    'animal_risk', jsonb_build_object('disclosed', job.animal_risk_disclosed, 'notes', job.animal_risk_notes),
    'payment', jsonb_build_object('amount_cents', job.pay_amount_cents, 'type', job.payment_type, 'method_preference', job.payment_method, 'timing', job.payment_timing),
    'proof_expected', job.proof_expected,
    'communication_boundaries', array[
      'Keep job communication in MORT', 'No harassment or sexual behavior',
      'No threats, weapons, alcohol, or drugs', 'No forced off-platform contact',
      'No material extra work without reconfirmation'
    ],
    'right_to_leave', true,
    'safety_tools_free', true,
    'verification_not_safety_guarantee', true,
    'scope_version', job.scope_version,
    'safety_plan', to_jsonb(plan)
  )
  from public.applications application
  join public.jobs job on job.id = application.job_id
  left join public.job_safety_plans plan on plan.application_id = application.id
  where application.id = p_application_id;
$$;

create or replace function private.ensure_job_safety_agreement()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job public.jobs%rowtype;
  v_terms jsonb;
begin
  if new.status = 'accepted' and old.status is distinct from new.status then
    select * into v_job from public.jobs where id = new.job_id;
    insert into public.job_safety_plans (
      application_id, job_id, teen_id, adult_id,
      expected_people, public_or_visible_meeting, daylight_preferred
    ) values (
      new.id, new.job_id, new.teen_id, v_job.poster_id,
      v_job.who_will_be_present, v_job.public_meeting_available, v_job.daylight_only
    ) on conflict (application_id) do nothing;

    v_terms := private.job_safety_terms(new.id);
    insert into public.job_safety_agreements (
      application_id, job_id, teen_id, adult_id,
      terms_snapshot, material_terms_hash
    ) values (
      new.id, new.job_id, new.teen_id, v_job.poster_id,
      v_terms,
      encode(extensions.digest(v_terms::text, 'sha256'), 'hex')
    ) on conflict (application_id) do nothing;

    insert into public.job_arrival_handshakes (
      application_id, job_id, teen_id, adult_id
    ) values (
      new.id, new.job_id, new.teen_id, v_job.poster_id
    ) on conflict (application_id) do nothing;
  end if;
  return new;
end;
$$;

create trigger applications_create_safety_agreement
after update of status on public.applications
for each row execute function private.ensure_job_safety_agreement();

insert into public.job_safety_plans (
  application_id, job_id, teen_id, adult_id,
  expected_people, public_or_visible_meeting, daylight_preferred
)
select
  application.id, application.job_id, application.teen_id, job.poster_id,
  job.who_will_be_present, job.public_meeting_available, job.daylight_only
from public.applications application
join public.jobs job on job.id = application.job_id
where application.status in ('accepted', 'in_progress', 'proof_submitted', 'completed')
on conflict (application_id) do nothing;

insert into public.job_safety_agreements (
  application_id, job_id, teen_id, adult_id,
  terms_snapshot, material_terms_hash
)
select
  application.id, application.job_id, application.teen_id, job.poster_id,
  private.job_safety_terms(application.id),
  encode(extensions.digest(private.job_safety_terms(application.id)::text, 'sha256'), 'hex')
from public.applications application
join public.jobs job on job.id = application.job_id
where application.status in ('accepted', 'in_progress', 'proof_submitted', 'completed')
on conflict (application_id) do nothing;

insert into public.job_arrival_handshakes (
  application_id, job_id, teen_id, adult_id
)
select application.id, application.job_id, application.teen_id, job.poster_id
from public.applications application
join public.jobs job on job.id = application.job_id
where application.status in ('accepted', 'in_progress', 'proof_submitted', 'completed')
on conflict (application_id) do nothing;

create or replace function public.save_job_safety_plan(
  p_application_id uuid,
  p_expected_people text,
  p_public_or_visible_meeting boolean,
  p_daylight_preferred boolean,
  p_transportation_plan text,
  p_checkin_cadence_minutes integer
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'extensions', 'pg_temp'
as $$
declare
  v_plan public.job_safety_plans%rowtype;
  v_agreement public.job_safety_agreements%rowtype;
  v_terms jsonb;
begin
  if auth.uid() is null or not private.is_job_safety_participant(p_application_id, auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'job_participant_required');
  end if;
  if p_checkin_cadence_minutes is not null and p_checkin_cadence_minutes not between 15 and 240 then
    return jsonb_build_object('ok', false, 'code', 'invalid_checkin_cadence');
  end if;

  update public.job_safety_plans
  set expected_people = nullif(left(btrim(coalesce(p_expected_people, '')), 500), ''),
      public_or_visible_meeting = p_public_or_visible_meeting,
      daylight_preferred = p_daylight_preferred,
      transportation_plan = nullif(left(btrim(coalesce(p_transportation_plan, '')), 1000), ''),
      checkin_cadence_minutes = p_checkin_cadence_minutes,
      teen_updated_at = case when teen_id = auth.uid() then now() else teen_updated_at end,
      adult_updated_at = case when adult_id = auth.uid() then now() else adult_updated_at end,
      updated_at = now()
  where application_id = p_application_id
  returning * into v_plan;

  if v_plan.id is null then
    return jsonb_build_object('ok', false, 'code', 'safety_plan_not_found');
  end if;

  v_terms := private.job_safety_terms(p_application_id);
  update public.job_safety_agreements
  set agreement_version = agreement_version + 1,
      terms_snapshot = v_terms,
      material_terms_hash = encode(extensions.digest(v_terms::text, 'sha256'), 'hex'),
      status = 'reconfirmation_required',
      teen_confirmed_at = null,
      adult_confirmed_at = null,
      teen_confirmed_version = null,
      adult_confirmed_version = null,
      updated_at = now()
  where application_id = p_application_id
  returning * into v_agreement;

  return jsonb_build_object(
    'ok', true,
    'plan', to_jsonb(v_plan),
    'agreement_version', v_agreement.agreement_version,
    'agreement_status', v_agreement.status
  );
end;
$$;

create or replace function public.confirm_job_safety_agreement(
  p_application_id uuid,
  p_agreement_version integer
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_agreement public.job_safety_agreements%rowtype;
begin
  if auth.uid() is null or not private.has_marketplace_identity(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'identity_verification_required');
  end if;
  select * into v_agreement
  from public.job_safety_agreements agreement
  where agreement.application_id = p_application_id
  for update;
  if v_agreement.id is null then
    return jsonb_build_object('ok', false, 'code', 'safety_agreement_not_found');
  end if;
  if auth.uid() not in (v_agreement.teen_id, v_agreement.adult_id) then
    return jsonb_build_object('ok', false, 'code', 'job_participant_required');
  end if;
  if p_agreement_version <> v_agreement.agreement_version then
    return jsonb_build_object('ok', false, 'code', 'safety_agreement_version_changed');
  end if;

  update public.job_safety_agreements
  set teen_confirmed_at = case when teen_id = auth.uid() then now() else teen_confirmed_at end,
      adult_confirmed_at = case when adult_id = auth.uid() then now() else adult_confirmed_at end,
      teen_confirmed_version = case when teen_id = auth.uid() then agreement_version else teen_confirmed_version end,
      adult_confirmed_version = case when adult_id = auth.uid() then agreement_version else adult_confirmed_version end,
      updated_at = now()
  where id = v_agreement.id
  returning * into v_agreement;

  update public.job_safety_agreements
  set status = case
    when teen_confirmed_version = agreement_version and adult_confirmed_version = agreement_version then 'confirmed'::public.safety_agreement_state
    when teen_confirmed_version = agreement_version then 'awaiting_adult'::public.safety_agreement_state
    when adult_confirmed_version = agreement_version then 'awaiting_teen'::public.safety_agreement_state
    else 'awaiting_both'::public.safety_agreement_state
  end,
  updated_at = now()
  where id = v_agreement.id
  returning * into v_agreement;

  if v_agreement.status = 'confirmed' then
    perform public.enqueue_notification(
      v_agreement.teen_id,
      'Safety Agreement confirmed',
      'Both job participants confirmed the current safety terms.',
      jsonb_build_object('applicationId', p_application_id, 'agreementVersion', v_agreement.agreement_version)
    );
    perform public.enqueue_notification(
      v_agreement.adult_id,
      'Safety Agreement confirmed',
      'Both job participants confirmed the current safety terms.',
      jsonb_build_object('applicationId', p_application_id, 'agreementVersion', v_agreement.agreement_version)
    );
  end if;

  return jsonb_build_object(
    'ok', true,
    'agreement_id', v_agreement.id,
    'agreement_version', v_agreement.agreement_version,
    'status', v_agreement.status,
    'teen_confirmed_at', v_agreement.teen_confirmed_at,
    'adult_confirmed_at', v_agreement.adult_confirmed_at
  );
end;
$$;

create or replace function private.enforce_safety_agreement_before_start()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'in_progress' and old.status is distinct from new.status then
    if not exists (
      select 1
      from public.job_safety_agreements agreement
      where agreement.application_id = new.id
        and agreement.status = 'confirmed'
        and agreement.teen_confirmed_version = agreement.agreement_version
        and agreement.adult_confirmed_version = agreement.agreement_version
    ) then
      raise exception 'mutual_safety_agreement_required';
    end if;
  end if;
  return new;
end;
$$;

create trigger applications_require_safety_agreement_before_start
before update of status on public.applications
for each row execute function private.enforce_safety_agreement_before_start();

create or replace function private.refresh_agreements_after_job_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_agreement record;
  v_terms jsonb;
begin
  if row(
    old.title, old.description, old.starts_at, old.ends_at, old.location_text,
    old.location_type, old.pay_amount_cents, old.payment_type,
    old.payment_method, old.payment_timing, old.equipment_provided,
    old.equipment_worker_brings, old.physical_requirements, old.proof_expected,
    old.who_will_be_present, old.animal_risk_notes, old.equipment_risk_notes
  ) is distinct from row(
    new.title, new.description, new.starts_at, new.ends_at, new.location_text,
    new.location_type, new.pay_amount_cents, new.payment_type,
    new.payment_method, new.payment_timing, new.equipment_provided,
    new.equipment_worker_brings, new.physical_requirements, new.proof_expected,
    new.who_will_be_present, new.animal_risk_notes, new.equipment_risk_notes
  ) then
    new.scope_version := old.scope_version + 1;
  end if;
  return new;
end;
$$;

create trigger jobs_version_material_safety_terms
before update on public.jobs
for each row execute function private.refresh_agreements_after_job_change();

create or replace function private.reconfirm_agreements_after_job_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_agreement record;
  v_terms jsonb;
begin
  if new.scope_version <> old.scope_version then
    for v_agreement in
      select agreement.id, agreement.application_id
      from public.job_safety_agreements agreement
      where agreement.job_id = new.id
        and agreement.status <> 'canceled'
    loop
      v_terms := private.job_safety_terms(v_agreement.application_id);
      update public.job_safety_agreements
      set agreement_version = agreement_version + 1,
          terms_snapshot = v_terms,
          material_terms_hash = encode(extensions.digest(v_terms::text, 'sha256'), 'hex'),
          status = 'reconfirmation_required',
          teen_confirmed_at = null,
          adult_confirmed_at = null,
          teen_confirmed_version = null,
          adult_confirmed_version = null,
          updated_at = now()
      where id = v_agreement.id;
    end loop;
  end if;
  return new;
end;
$$;

create trigger jobs_reconfirm_material_safety_terms
after update of scope_version on public.jobs
for each row execute function private.reconfirm_agreements_after_job_change();

create or replace function public.save_job_private_location(
  p_job_id uuid,
  p_exact_address text,
  p_arrival_instructions text default null,
  p_access_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_job public.jobs%rowtype;
  v_location public.job_private_locations%rowtype;
  v_agreement record;
  v_terms jsonb;
begin
  if auth.uid() is null or not private.has_marketplace_identity(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'identity_verification_required');
  end if;
  select * into v_job from public.jobs where id = p_job_id;
  if v_job.id is null or (v_job.poster_id <> auth.uid() and not public.is_admin()) then
    return jsonb_build_object('ok', false, 'code', 'job_not_found');
  end if;
  if char_length(btrim(coalesce(p_exact_address, ''))) < 5 then
    return jsonb_build_object('ok', false, 'code', 'exact_job_address_required');
  end if;

  insert into public.job_private_locations (
    job_id, poster_id, exact_address, arrival_instructions, access_notes
  ) values (
    p_job_id, v_job.poster_id, left(btrim(p_exact_address), 500),
    nullif(left(btrim(coalesce(p_arrival_instructions, '')), 2000), ''),
    nullif(left(btrim(coalesce(p_access_notes, '')), 1000), '')
  )
  on conflict (job_id) do update
  set exact_address = excluded.exact_address,
      arrival_instructions = excluded.arrival_instructions,
      access_notes = excluded.access_notes,
      location_version = public.job_private_locations.location_version + 1,
      verified_for_job = false,
      updated_at = now()
  returning * into v_location;

  for v_agreement in
    select agreement.id, agreement.application_id
    from public.job_safety_agreements agreement
    where agreement.job_id = p_job_id
      and agreement.status <> 'canceled'
  loop
    v_terms := private.job_safety_terms(v_agreement.application_id);
    update public.job_safety_agreements
    set agreement_version = agreement_version + 1,
        terms_snapshot = v_terms,
        material_terms_hash = encode(extensions.digest(v_terms::text, 'sha256'), 'hex'),
        status = 'reconfirmation_required',
        teen_confirmed_at = null,
        adult_confirmed_at = null,
        teen_confirmed_version = null,
        adult_confirmed_version = null,
        updated_at = now()
    where id = v_agreement.id;
  end loop;

  insert into public.private_data_access_events (
    actor_id, resource_type, resource_id, action, reason
  ) values (
    auth.uid(), 'job_private_location', p_job_id, 'write',
    'Job poster saved or updated the restricted job location.'
  );

  return jsonb_build_object(
    'ok', true,
    'job_id', p_job_id,
    'location_version', v_location.location_version,
    'public_feed_contains_exact_address', false
  );
end;
$$;

create or replace function public.get_released_job_location(p_application_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_application public.applications%rowtype;
  v_job public.jobs%rowtype;
  v_location public.job_private_locations%rowtype;
  v_agreement public.job_safety_agreements%rowtype;
  v_allowed boolean := false;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  select * into v_application from public.applications where id = p_application_id;
  if v_application.id is null then
    return jsonb_build_object('ok', false, 'code', 'application_not_found');
  end if;
  select * into v_job from public.jobs where id = v_application.job_id;
  select * into v_location from public.job_private_locations where job_id = v_job.id;
  select * into v_agreement from public.job_safety_agreements where application_id = p_application_id;

  if v_job.poster_id = auth.uid() then
    v_allowed := true;
  elsif v_application.teen_id = auth.uid()
    and v_application.status in ('accepted', 'in_progress', 'proof_submitted')
    and v_job.status in ('assigned', 'in_progress', 'proof_submitted')
    and v_agreement.status = 'confirmed'
    and v_agreement.teen_confirmed_version = v_agreement.agreement_version
    and v_agreement.adult_confirmed_version = v_agreement.agreement_version then
    v_allowed := true;
  end if;

  if not v_allowed then
    return jsonb_build_object(
      'ok', false,
      'code', 'exact_location_not_released',
      'public_location', jsonb_build_object('area', v_job.location_text, 'city', v_job.city, 'state', v_job.state, 'location_type', v_job.location_type)
    );
  end if;
  if v_location.job_id is null then
    return jsonb_build_object('ok', false, 'code', 'exact_location_not_configured');
  end if;

  insert into public.private_data_access_events (
    actor_id, resource_type, resource_id, action, reason
  ) values (
    auth.uid(), 'job_private_location', v_job.id, 'read',
    case when v_job.poster_id = auth.uid() then 'Job poster accessed own restricted location.' else 'Accepted verified worker accessed location after mutual confirmation.' end
  );

  return jsonb_build_object(
    'ok', true,
    'job_id', v_job.id,
    'exact_address', v_location.exact_address,
    'arrival_instructions', v_location.arrival_instructions,
    'access_notes', v_location.access_notes,
    'location_version', v_location.location_version,
    'release_stage', case when v_job.poster_id = auth.uid() then 'poster' else 'accepted_confirmed' end
  );
end;
$$;

create or replace function public.start_temporary_location_share(
  p_application_id uuid,
  p_recipient_user_id uuid,
  p_mode text,
  p_expires_at timestamptz,
  p_coarse_location text default null,
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_explicit_consent boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_mode public.location_share_mode;
  v_application public.applications%rowtype;
  v_job public.jobs%rowtype;
  v_share public.job_location_share_sessions%rowtype;
  v_recipient_allowed boolean := false;
begin
  if auth.uid() is null or not private.has_marketplace_identity(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'identity_verification_required');
  end if;
  if not p_explicit_consent then
    return jsonb_build_object('ok', false, 'code', 'location_share_consent_required');
  end if;
  begin
    v_mode := lower(btrim(p_mode))::public.location_share_mode;
  exception when invalid_text_representation then
    return jsonb_build_object('ok', false, 'code', 'invalid_location_share_mode');
  end;
  if v_mode = 'none' or p_expires_at <= now() or p_expires_at > now() + interval '12 hours' then
    return jsonb_build_object('ok', false, 'code', 'invalid_location_share_window');
  end if;
  if (p_latitude is null) <> (p_longitude is null)
     or (p_latitude is not null and (p_latitude not between -90 and 90 or p_longitude not between -180 and 180)) then
    return jsonb_build_object('ok', false, 'code', 'invalid_location_coordinates');
  end if;
  if p_latitude is not null and v_mode not in ('temporary_active_job', 'safety_ping_emergency') then
    return jsonb_build_object('ok', false, 'code', 'coordinates_not_allowed_for_mode');
  end if;

  select * into v_application from public.applications where id = p_application_id;
  select * into v_job from public.jobs where id = v_application.job_id;
  if v_application.id is null
     or auth.uid() not in (v_application.teen_id, v_job.poster_id)
     or v_application.status not in ('accepted', 'in_progress', 'proof_submitted') then
    return jsonb_build_object('ok', false, 'code', 'active_job_participant_required');
  end if;

  v_recipient_allowed := p_recipient_user_id in (v_application.teen_id, v_job.poster_id)
    and p_recipient_user_id <> auth.uid();
  if not v_recipient_allowed and auth.uid() = v_application.teen_id then
    select exists (
      select 1
      from public.safety_circle_members circle
      where circle.teen_id = auth.uid()
        and circle.contact_id = p_recipient_user_id
        and circle.status = 'active'
    ) into v_recipient_allowed;
  end if;
  if not v_recipient_allowed then
    return jsonb_build_object('ok', false, 'code', 'location_share_recipient_not_authorized');
  end if;

  update public.job_location_share_sessions
  set status = 'stopped', stopped_at = now()
  where application_id = p_application_id
    and owner_id = auth.uid()
    and status = 'active';

  insert into public.job_location_share_sessions (
    application_id, owner_id, recipient_user_id, mode,
    coarse_location, latitude, longitude, expires_at,
    last_location_at
  ) values (
    p_application_id, auth.uid(), p_recipient_user_id, v_mode,
    nullif(left(btrim(coalesce(p_coarse_location, '')), 200), ''),
    p_latitude, p_longitude, p_expires_at,
    case when p_latitude is not null then now() else null end
  ) returning * into v_share;

  return jsonb_build_object(
    'ok', true,
    'share_id', v_share.id,
    'mode', v_share.mode,
    'expires_at', v_share.expires_at,
    'visible_active_indicator_required', true
  );
end;
$$;

create or replace function public.update_temporary_job_location(
  p_share_id uuid,
  p_latitude double precision,
  p_longitude double precision
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_share public.job_location_share_sessions%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_latitude not between -90 and 90 or p_longitude not between -180 and 180 then
    return jsonb_build_object('ok', false, 'code', 'invalid_location_coordinates');
  end if;
  update public.job_location_share_sessions
  set latitude = p_latitude, longitude = p_longitude, last_location_at = now()
  where id = p_share_id
    and owner_id = auth.uid()
    and status = 'active'
    and expires_at > now()
    and mode in ('temporary_active_job', 'safety_ping_emergency')
  returning * into v_share;
  if v_share.id is null then
    return jsonb_build_object('ok', false, 'code', 'location_share_not_active');
  end if;
  return jsonb_build_object('ok', true, 'share_id', v_share.id, 'last_location_at', v_share.last_location_at);
end;
$$;

create or replace function public.stop_temporary_location_share(p_share_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_share public.job_location_share_sessions%rowtype;
begin
  update public.job_location_share_sessions
  set status = 'stopped', stopped_at = now()
  where id = p_share_id and owner_id = auth.uid() and status = 'active'
  returning * into v_share;
  if v_share.id is null then
    return jsonb_build_object('ok', false, 'code', 'location_share_not_active');
  end if;
  return jsonb_build_object('ok', true, 'share_id', v_share.id, 'status', v_share.status);
end;
$$;

create or replace function public.get_authorized_location_shares()
returns table (
  id uuid,
  application_id uuid,
  owner_id uuid,
  recipient_user_id uuid,
  mode public.location_share_mode,
  coarse_location text,
  latitude double precision,
  longitude double precision,
  status text,
  expires_at timestamptz,
  last_location_at timestamptz
)
language sql
stable
security definer
set search_path = 'public', 'pg_temp'
as $$
  select
    share.id, share.application_id, share.owner_id, share.recipient_user_id,
    share.mode, share.coarse_location, share.latitude, share.longitude,
    case when share.expires_at <= now() then 'expired' else share.status end,
    share.expires_at, share.last_location_at
  from public.job_location_share_sessions share
  where auth.uid() is not null
    and (share.owner_id = auth.uid() or share.recipient_user_id = auth.uid())
    and share.status = 'active'
    and share.expires_at > now()
  order by share.created_at desc;
$$;

create or replace function public.generate_job_arrival_code(p_application_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'extensions', 'pg_temp'
as $$
declare
  v_handshake public.job_arrival_handshakes%rowtype;
  v_agreement public.job_safety_agreements%rowtype;
  v_code text;
begin
  if auth.uid() is null or not private.has_marketplace_identity(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'identity_verification_required');
  end if;
  select * into v_handshake
  from public.job_arrival_handshakes handshake
  where handshake.application_id = p_application_id
  for update;
  if v_handshake.id is null or v_handshake.adult_id <> auth.uid() then
    return jsonb_build_object('ok', false, 'code', 'job_poster_required');
  end if;
  select * into v_agreement from public.job_safety_agreements where application_id = p_application_id;
  if v_agreement.status <> 'confirmed' then
    return jsonb_build_object('ok', false, 'code', 'mutual_safety_agreement_required');
  end if;
  if not exists (
    select 1 from public.applications application
    where application.id = p_application_id and application.status = 'accepted'
  ) then
    return jsonb_build_object('ok', false, 'code', 'accepted_application_required');
  end if;

  v_code := upper(substr(encode(extensions.gen_random_bytes(6), 'hex'), 1, 6));
  update public.job_arrival_handshakes
  set code_hash = extensions.digest(v_code, 'sha256'),
      code_generation = code_generation + 1,
      code_expires_at = now() + interval '10 minutes',
      code_used_at = null,
      updated_at = now()
  where id = v_handshake.id
  returning * into v_handshake;

  return jsonb_build_object(
    'ok', true,
    'handshake_id', v_handshake.id,
    'arrival_code', v_code,
    'expires_at', v_handshake.code_expires_at,
    'code_generation', v_handshake.code_generation,
    'qr_payload', 'mort://arrival/' || p_application_id::text || '?code=' || v_code
  );
end;
$$;

create or replace function public.confirm_job_arrival_code(
  p_application_id uuid,
  p_code text,
  p_person_matches_profile boolean
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'extensions', 'pg_temp'
as $$
declare
  v_handshake public.job_arrival_handshakes%rowtype;
begin
  if auth.uid() is null or not private.has_marketplace_identity(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'identity_verification_required');
  end if;
  select * into v_handshake
  from public.job_arrival_handshakes handshake
  where handshake.application_id = p_application_id
  for update;
  if v_handshake.id is null or v_handshake.teen_id <> auth.uid() then
    return jsonb_build_object('ok', false, 'code', 'assigned_worker_required');
  end if;
  if not p_person_matches_profile then
    return public.report_person_mismatch(p_application_id, 'The person at the job did not match the MORT profile.');
  end if;
  if v_handshake.code_used_at is not null then
    return jsonb_build_object('ok', false, 'code', 'arrival_code_already_used');
  end if;
  if v_handshake.code_expires_at is null or v_handshake.code_expires_at <= now() then
    return jsonb_build_object('ok', false, 'code', 'arrival_code_expired');
  end if;
  if v_handshake.code_hash <> extensions.digest(upper(btrim(p_code)), 'sha256') then
    return jsonb_build_object('ok', false, 'code', 'arrival_code_invalid');
  end if;

  update public.job_arrival_handshakes
  set code_used_at = now(), checkin_at = now(),
      teen_identity_match_confirmed = true,
      adult_identity_match_confirmed = true,
      updated_at = now()
  where id = v_handshake.id
  returning * into v_handshake;

  insert into public.job_checkins (
    application_id, user_id, checkin_type, completed_at, status
  ) values (
    p_application_id, auth.uid(), 'arrival', now(), 'completed'
  );

  return jsonb_build_object(
    'ok', true,
    'handshake_id', v_handshake.id,
    'checkin_at', v_handshake.checkin_at,
    'identity_documents_exchanged', false
  );
end;
$$;

create or replace function public.confirm_job_checkout(p_application_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_handshake public.job_arrival_handshakes%rowtype;
begin
  select * into v_handshake
  from public.job_arrival_handshakes handshake
  where handshake.application_id = p_application_id
  for update;
  if v_handshake.id is null or auth.uid() not in (v_handshake.teen_id, v_handshake.adult_id) then
    return jsonb_build_object('ok', false, 'code', 'job_participant_required');
  end if;
  if v_handshake.checkin_at is null then
    return jsonb_build_object('ok', false, 'code', 'arrival_checkin_required');
  end if;

  update public.job_arrival_handshakes
  set teen_checkout_at = case when teen_id = auth.uid() then now() else teen_checkout_at end,
      adult_checkout_at = case when adult_id = auth.uid() then now() else adult_checkout_at end,
      updated_at = now()
  where id = v_handshake.id
  returning * into v_handshake;

  insert into public.job_checkins (
    application_id, user_id, checkin_type, completed_at, status
  ) values (
    p_application_id, auth.uid(), 'departure', now(), 'completed'
  );

  update public.job_location_share_sessions
  set status = 'stopped', stopped_at = now()
  where application_id = p_application_id
    and owner_id = auth.uid()
    and status = 'active';

  return jsonb_build_object(
    'ok', true,
    'handshake_id', v_handshake.id,
    'teen_checkout_at', v_handshake.teen_checkout_at,
    'adult_checkout_at', v_handshake.adult_checkout_at,
    'both_checked_out', v_handshake.teen_checkout_at is not null and v_handshake.adult_checkout_at is not null
  );
end;
$$;

create or replace function public.report_person_mismatch(
  p_application_id uuid,
  p_details text
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_application public.applications%rowtype;
  v_job public.jobs%rowtype;
  v_target uuid;
  v_result jsonb;
begin
  select * into v_application from public.applications where id = p_application_id;
  select * into v_job from public.jobs where id = v_application.job_id;
  if v_application.id is null or auth.uid() not in (v_application.teen_id, v_job.poster_id) then
    return jsonb_build_object('ok', false, 'code', 'job_participant_required');
  end if;
  v_target := case when auth.uid() = v_application.teen_id then v_job.poster_id else v_application.teen_id end;
  v_result := public.submit_safety_report(
    v_target,
    v_job.id,
    null,
    null,
    p_application_id,
    'identity_mismatch',
    'high',
    false,
    p_details,
    now(),
    v_job.location_type,
    'Pause contact and review identity mismatch.',
    true
  );

  update public.job_location_share_sessions
  set status = 'stopped', stopped_at = now()
  where application_id = p_application_id and status = 'active';

  return v_result || jsonb_build_object('person_mismatch', true, 'safe_exit_recommended', true);
end;
$$;

create or replace function public.set_trusted_relationship(
  p_target_user_id uuid,
  p_relationship_type text,
  p_source_job_id uuid default null,
  p_enabled boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_type text := lower(btrim(coalesce(p_relationship_type, '')));
  v_relationship public.trusted_relationships%rowtype;
begin
  if auth.uid() is null or not private.has_marketplace_identity(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'identity_verification_required');
  end if;
  if p_target_user_id is null or p_target_user_id = auth.uid() then
    return jsonb_build_object('ok', false, 'code', 'invalid_relationship_target');
  end if;
  if v_type not in ('trusted_worker', 'trusted_poster', 'private_favorite', 'decline_future_invites', 'no_contact') then
    return jsonb_build_object('ok', false, 'code', 'invalid_relationship_type');
  end if;
  if v_type in ('trusted_worker', 'trusted_poster') and not exists (
    select 1
    from public.applications application
    join public.jobs job on job.id = application.job_id
    where application.status = 'completed'
      and (
        (application.teen_id = auth.uid() and job.poster_id = p_target_user_id)
        or (job.poster_id = auth.uid() and application.teen_id = p_target_user_id)
      )
  ) then
    return jsonb_build_object('ok', false, 'code', 'completed_job_required');
  end if;

  if not p_enabled then
    delete from public.trusted_relationships
    where owner_id = auth.uid()
      and target_id = p_target_user_id
      and relationship_type = v_type;
    return jsonb_build_object('ok', true, 'enabled', false);
  end if;

  insert into public.trusted_relationships (
    owner_id, target_id, relationship_type, source_job_id
  ) values (
    auth.uid(), p_target_user_id, v_type, p_source_job_id
  )
  on conflict (owner_id, target_id, relationship_type) do update
  set source_job_id = coalesce(excluded.source_job_id, public.trusted_relationships.source_job_id),
      updated_at = now()
  returning * into v_relationship;

  return jsonb_build_object('ok', true, 'enabled', true, 'relationship', to_jsonb(v_relationship));
end;
$$;

create or replace function public.submit_safety_cancellation(
  p_application_id uuid,
  p_reason text,
  p_details text default null
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_application public.applications%rowtype;
  v_job public.jobs%rowtype;
  v_reason text := lower(btrim(coalesce(p_reason, '')));
  v_safety_related boolean;
  v_target uuid;
  v_report jsonb;
  v_cancellation public.safety_cancellations%rowtype;
begin
  select * into v_application
  from public.applications application
  where application.id = p_application_id
  for update;
  select * into v_job
  from public.jobs job
  where job.id = v_application.job_id
  for update;
  if v_application.id is null or auth.uid() not in (v_application.teen_id, v_job.poster_id) then
    return jsonb_build_object('ok', false, 'code', 'job_participant_required');
  end if;
  if v_reason not in (
    'schedule_conflict', 'illness', 'transportation_problem', 'scope_changed',
    'location_changed', 'person_mismatch', 'unsafe_condition', 'harassment',
    'emergency', 'payment_disagreement', 'equipment_issue'
  ) then
    return jsonb_build_object('ok', false, 'code', 'invalid_cancellation_reason');
  end if;

  v_safety_related := v_reason in (
    'scope_changed', 'location_changed', 'person_mismatch', 'unsafe_condition',
    'harassment', 'emergency', 'payment_disagreement', 'equipment_issue'
  );
  if v_safety_related and char_length(btrim(coalesce(p_details, ''))) < 10 then
    return jsonb_build_object('ok', false, 'code', 'safety_cancellation_details_required');
  end if;

  v_target := case when auth.uid() = v_application.teen_id then v_job.poster_id else v_application.teen_id end;
  if v_safety_related then
    v_report := public.submit_safety_report(
      v_target,
      v_job.id,
      null,
      null,
      p_application_id,
      case v_reason
        when 'person_mismatch' then 'identity_mismatch'
        when 'harassment' then 'harassment'
        when 'payment_disagreement' then 'payment_threat'
        else 'unsafe_job_conditions'
      end,
      case when v_reason in ('person_mismatch', 'harassment', 'emergency') then 'high' else 'moderate' end,
      v_reason = 'emergency',
      p_details,
      now(),
      v_job.location_type,
      'End the job safely and prevent retaliation.',
      true
    );
  end if;

  insert into public.safety_cancellations (
    application_id, job_id, actor_id, reason, details,
    is_safety_related, reputation_penalty_applied, incident_id
  ) values (
    p_application_id, v_job.id, auth.uid(), v_reason,
    nullif(left(btrim(coalesce(p_details, '')), 3000), ''),
    v_safety_related, false,
    case when v_safety_related then (v_report->>'incident_id')::uuid else null end
  ) returning * into v_cancellation;

  if v_safety_related then
    update public.applications set status = 'disputed' where id = p_application_id;
    update public.jobs set status = 'paused', applications_open = false where id = v_job.id;
    insert into public.trusted_relationships (
      owner_id, target_id, relationship_type, source_job_id
    ) values (
      auth.uid(), v_target, 'no_contact', v_job.id
    ) on conflict (owner_id, target_id, relationship_type) do nothing;
  elsif auth.uid() = v_application.teen_id
    and v_application.status in ('submitted', 'guardian_pending', 'adult_review', 'viewed', 'accepted') then
    update public.applications set status = 'withdrawn', withdrawn_at = now() where id = p_application_id;
  elsif auth.uid() = v_job.poster_id then
    update public.jobs set status = 'canceled', applications_open = false where id = v_job.id;
  end if;

  update public.job_location_share_sessions
  set status = 'stopped', stopped_at = now()
  where application_id = p_application_id and status = 'active';

  return jsonb_build_object(
    'ok', true,
    'cancellation_id', v_cancellation.id,
    'safety_related', v_safety_related,
    'reputation_penalty_applied', false,
    'incident_id', v_cancellation.incident_id
  );
end;
$$;

create or replace function private.enforce_no_contact_after_block()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.trusted_relationships (
    owner_id, target_id, relationship_type
  ) values (
    new.blocker_id, new.blocked_id, 'no_contact'
  ) on conflict (owner_id, target_id, relationship_type) do nothing;

  update public.job_location_share_sessions share
  set status = 'stopped', stopped_at = now()
  where share.status = 'active'
    and (
      (share.owner_id = new.blocker_id and share.recipient_user_id = new.blocked_id)
      or (share.owner_id = new.blocked_id and share.recipient_user_id = new.blocker_id)
    );
  return new;
end;
$$;

create trigger blocks_enforce_no_contact
after insert on public.blocks
for each row execute function private.enforce_no_contact_after_block();

create or replace function private.reveal_mutual_reviews()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1
    from public.reviews other
    where other.job_id = new.job_id
      and other.reviewer_id = new.subject_id
      and other.subject_id = new.reviewer_id
  ) then
    update public.reviews
    set revealed_at = now(), updated_at = now()
    where job_id = new.job_id
      and reviewer_id in (new.reviewer_id, new.subject_id)
      and subject_id in (new.reviewer_id, new.subject_id);
  end if;
  return new;
end;
$$;

create trigger reviews_blind_reveal_when_both_submit
after insert on public.reviews
for each row execute function private.reveal_mutual_reviews();

drop policy if exists reviews_select_visible on public.reviews;
create policy reviews_select_blind_reveal
on public.reviews for select to authenticated
using (
  reviewer_id = (select auth.uid())
  or (
    moderation_status = 'approved'
    and (revealed_at is not null or reveal_at <= now())
  )
  or private.has_admin_safety_role(
    (select auth.uid()),
    array['moderator', 'senior_safety_moderator', 'child_safety_specialist', 'incident_manager']::public.admin_safety_role[]
  )
);

create or replace function private.protect_serious_review_content()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(new.body, '') ~* '(kidnap|rape|sexual assault|molest|weapon|kill|murder|stalk|blackmail|home address|school address)' then
    new.moderation_status := 'held_for_safety';
    new.confidential_safety_feedback := true;
  end if;
  return new;
end;
$$;

create trigger reviews_hold_serious_accusations
before insert or update of body on public.reviews
for each row execute function private.protect_serious_review_content();

create or replace function public.submit_private_review_safety_feedback(
  p_review_id uuid,
  p_structured_feedback jsonb,
  p_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_review public.reviews%rowtype;
  v_feedback public.review_private_safety_feedback%rowtype;
begin
  select * into v_review from public.reviews where id = p_review_id;
  if v_review.id is null or v_review.reviewer_id <> auth.uid() then
    return jsonb_build_object('ok', false, 'code', 'review_author_required');
  end if;
  insert into public.review_private_safety_feedback (
    review_id, author_id, subject_id, structured_feedback, notes
  ) values (
    p_review_id, auth.uid(), v_review.subject_id,
    coalesce(p_structured_feedback, '{}'::jsonb),
    nullif(left(btrim(coalesce(p_notes, '')), 3000), '')
  )
  on conflict (review_id) do update
  set structured_feedback = excluded.structured_feedback,
      notes = excluded.notes
  returning * into v_feedback;

  update public.reviews
  set confidential_safety_feedback = true, updated_at = now()
  where id = p_review_id;

  return jsonb_build_object('ok', true, 'feedback_id', v_feedback.id, 'public', false);
end;
$$;

create or replace function private.classify_message_safety(p_body text)
returns jsonb
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_text text := lower(btrim(coalesce(p_body, '')));
begin
  if v_text = '' then
    return jsonb_build_object('blocked', true, 'category', 'harassment', 'severity', 'low', 'reason', 'Message cannot be empty.', 'safer_rewrite', false);
  end if;
  if char_length(v_text) > 2000 then
    return jsonb_build_object('blocked', true, 'category', 'harassment', 'severity', 'low', 'reason', 'Message is too long.', 'safer_rewrite', true);
  end if;
  if v_text ~ '(nude|naked|sexual|sex |send.{0,20}(pic|photo)|hotel room|private bedroom|dating|hook up|touch you|show me your body)' then
    return jsonb_build_object('blocked', true, 'category', 'sexual_conduct', 'severity', 'critical', 'reason', 'Sexual content involving job participants is blocked.', 'safer_rewrite', false);
  end if;
  if v_text ~ '(don''?t tell.{0,30}(parent|guardian|adult)|keep.{0,20}secret|hide this.{0,20}(parent|guardian)|gift.{0,30}secret|pay.{0,30}secret)' then
    return jsonb_build_object('blocked', true, 'category', 'child_safety_concern', 'severity', 'critical', 'reason', 'Secrecy or grooming-style language is blocked.', 'safer_rewrite', false);
  end if;
  if v_text ~ '(i will kill|kill you|hurt you|beat you|weapon|gun|knife|i know where you live|i will find you|watching your house)' then
    return jsonb_build_object('blocked', true, 'category', 'threats', 'severity', 'critical', 'reason', 'Threatening language is blocked and preserved for safety review.', 'safer_rewrite', false);
  end if;
  if v_text ~ '(blackmail|expose you|post your photos|ruin you unless|pay me or|do this or else)' then
    return jsonb_build_object('blocked', true, 'category', 'blackmail', 'severity', 'high', 'reason', 'Blackmail or coercive language is blocked.', 'safer_rewrite', false);
  end if;
  if v_text ~ '(school name|student number|school address|home address|social security|license number|passport number)' then
    return jsonb_build_object('blocked', true, 'category', 'doxxing', 'severity', 'high', 'reason', 'Sensitive identity, school, or address information is blocked.', 'safer_rewrite', true);
  end if;
  if p_body ~* '(\+?1[-.\s]?)?(\(?[0-9]{3}\)?[-.\s]?)?[0-9]{3}[-.\s]?[0-9]{4}'
     or p_body ~* '[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}'
     or v_text ~ '(instagram|snapchat|tiktok|discord|telegram|whatsapp|signal|kik|off app|text me|call me)' then
    return jsonb_build_object('blocked', true, 'category', 'off_platform_pressure', 'severity', 'moderate', 'reason', 'Off-platform contact details or pressure are blocked.', 'safer_rewrite', true);
  end if;
  if v_text ~ '(gift card|crypto payment|deposit first|upfront fee|cashapp|venmo|zelle|paypal|pay or else|withhold pay)' then
    return jsonb_build_object('blocked', true, 'category', 'payment_threat', 'severity', 'high', 'reason', 'Unsafe payment pressure is blocked.', 'safer_rewrite', true);
  end if;
  if v_text ~ '(slur|worthless|stupid kid|stupid adult|hate you|humiliate)' then
    return jsonb_build_object('blocked', false, 'category', 'harassment', 'severity', 'moderate', 'reason', 'Potential harassment was flagged for review.', 'safer_rewrite', true);
  end if;
  return jsonb_build_object('blocked', false, 'category', null, 'severity', null, 'reason', null, 'safer_rewrite', false);
end;
$$;

revoke all on function private.classify_message_safety(text)
from public, anon, authenticated;

create or replace function public.scan_message_body(p_body text)
returns text
language sql
immutable
set search_path = 'public', 'pg_temp'
as $$
  select case
    when coalesce((private.classify_message_safety(p_body)->>'blocked')::boolean, false)
      then private.classify_message_safety(p_body)->>'reason'
    else null
  end;
$$;

create or replace function public.send_safe_message(p_thread_id uuid, p_body text)
returns public.messages
language plpgsql
security definer
set search_path = 'public', 'extensions', 'pg_temp'
as $$
declare
  v_scan jsonb;
  v_message public.messages%rowtype;
  v_thread public.message_threads%rowtype;
  v_target uuid;
  v_repeated boolean := false;
  v_incident public.safety_incidents%rowtype;
begin
  if auth.uid() is null then
    raise exception 'authentication_required';
  end if;
  if not public.is_profile_active(auth.uid()) then
    raise exception 'user_account_restricted';
  end if;
  if not private.has_marketplace_identity(auth.uid()) then
    raise exception 'identity_verification_required';
  end if;
  if not public.is_thread_participant(p_thread_id) then
    raise exception 'thread_participant_required';
  end if;

  select * into v_thread from public.message_threads where id = p_thread_id;
  if v_thread.teen_id = auth.uid() and public.teen_is_paused(v_thread.teen_id) then
    raise exception 'guardian_mode_paused';
  end if;
  if (v_thread.teen_id is not null and v_thread.teen_id <> auth.uid() and public.users_are_blocked(auth.uid(), v_thread.teen_id))
    or (v_thread.adult_id is not null and v_thread.adult_id <> auth.uid() and public.users_are_blocked(auth.uid(), v_thread.adult_id))
    or (v_thread.guardian_id is not null and v_thread.guardian_id <> auth.uid() and public.users_are_blocked(auth.uid(), v_thread.guardian_id)) then
    raise exception 'participant_blocked';
  end if;

  select count(*) >= 4 into v_repeated
  from public.messages message
  where message.thread_id = p_thread_id
    and message.sender_id = auth.uid()
    and message.created_at > now() - interval '15 minutes'
    and not exists (
      select 1
      from public.messages reply
      where reply.thread_id = p_thread_id
        and reply.sender_id <> auth.uid()
        and reply.created_at > message.created_at
    );

  v_scan := private.classify_message_safety(p_body);
  if v_repeated then
    v_scan := jsonb_build_object(
      'blocked', true,
      'category', 'repeated_unwanted_contact',
      'severity', 'moderate',
      'reason', 'Pause and wait for the other participant to respond.',
      'safer_rewrite', false
    );
  end if;

  if coalesce((v_scan->>'blocked')::boolean, false) then
    insert into public.messages (
      thread_id, sender_id, body, scanner_status, scanner_reason,
      safety_category, safety_severity, preserved_for_safety,
      safer_rewrite_available
    ) values (
      p_thread_id,
      auth.uid(),
      '[Blocked by MORT safety controls]',
      'blocked',
      v_scan->>'reason',
      (v_scan->>'category')::public.safety_report_category,
      (v_scan->>'severity')::public.safety_incident_severity,
      (v_scan->>'severity') in ('high', 'critical'),
      coalesce((v_scan->>'safer_rewrite')::boolean, false)
    ) returning * into v_message;

    insert into public.message_safety_evidence (
      message_id, sender_id, thread_id, raw_body, body_sha256,
      category, severity, preserved_until
    ) values (
      v_message.id,
      auth.uid(),
      p_thread_id,
      left(p_body, 2000),
      encode(extensions.digest(left(p_body, 2000), 'sha256'), 'hex'),
      (v_scan->>'category')::public.safety_report_category,
      (v_scan->>'severity')::public.safety_incident_severity,
      case when (v_scan->>'severity') in ('high', 'critical') then now() + interval '1 year' else null end
    );

    if (v_scan->>'severity') in ('high', 'critical') then
      v_target := case
        when v_thread.teen_id is distinct from auth.uid() then v_thread.teen_id
        when v_thread.adult_id is distinct from auth.uid() then v_thread.adult_id
        else v_thread.guardian_id
      end;

      insert into public.safety_incidents (
        reporter_id, subject_user_id, job_id, application_id,
        category, severity, immediate_danger, priority, sla_due_at,
        preservation_status
      ) values (
        null,
        auth.uid(),
        v_thread.job_id,
        v_thread.application_id,
        (v_scan->>'category')::public.safety_report_category,
        (v_scan->>'severity')::public.safety_incident_severity,
        (v_scan->>'severity') = 'critical',
        case when (v_scan->>'severity') = 'critical' then 1 else 2 end,
        now() + case when (v_scan->>'severity') = 'critical' then interval '15 minutes' else interval '2 hours' end,
        'preserve_relevant_records'
      ) returning * into v_incident;

      insert into public.incident_participants (
        incident_id, user_id, participant_role
      ) values (
        v_incident.id, auth.uid(), 'accused_person'
      ) on conflict do nothing;
      if v_target is not null then
        insert into public.incident_participants (
          incident_id, user_id, participant_role
        ) values (
          v_incident.id, v_target, 'affected_person'
        ) on conflict do nothing;
        perform public.enqueue_notification(
          v_target,
          'MORT blocked a safety-sensitive message',
          'A message was blocked. You can report, block, leave the job, or use Safety Ping. Contact emergency services for immediate danger.',
          jsonb_build_object('threadId', p_thread_id, 'incidentId', v_incident.id)
        );
      end if;
      insert into public.incident_timeline_events (
        incident_id, actor_id, event_type, public_status_note,
        restricted_note, event_data
      ) values (
        v_incident.id,
        null,
        'automated_message_signal',
        'A message safety signal was queued for human review.',
        'Raw content is stored separately with restricted access.',
        jsonb_build_object('message_id', v_message.id, 'category', v_scan->>'category', 'severity', v_scan->>'severity')
      );
    end if;
    return v_message;
  end if;

  insert into public.messages (
    thread_id, sender_id, body, scanner_status, scanner_reason,
    safety_category, safety_severity, safer_rewrite_available
  ) values (
    p_thread_id,
    auth.uid(),
    btrim(p_body),
    case when v_scan->>'category' is null then 'clean'::public.scanner_status else 'flagged'::public.scanner_status end,
    v_scan->>'reason',
    nullif(v_scan->>'category', '')::public.safety_report_category,
    nullif(v_scan->>'severity', '')::public.safety_incident_severity,
    coalesce((v_scan->>'safer_rewrite')::boolean, false)
  ) returning * into v_message;

  return v_message;
end;
$$;

create or replace function public.get_my_active_sessions()
returns table (
  session_reference text,
  created_at timestamptz,
  updated_at timestamptz,
  refreshed_at timestamp,
  user_agent text,
  assurance_level text,
  is_current boolean
)
language sql
stable
security definer
set search_path = 'auth', 'extensions', 'pg_temp'
as $$
  select
    substr(encode(extensions.digest(session.id::text, 'sha256'), 'hex'), 1, 16),
    session.created_at,
    session.updated_at,
    session.refreshed_at,
    left(coalesce(session.user_agent, 'Unknown device'), 300),
    session.aal::text,
    session.id::text = auth.jwt()->>'session_id'
  from auth.sessions session
  where auth.uid() is not null
    and session.user_id = auth.uid()
    and (session.not_after is null or session.not_after > now())
  order by session.updated_at desc;
$$;

create or replace function public.report_account_security_concern(
  p_event_type text,
  p_session_reference text default null,
  p_details text default null
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_event public.account_security_events%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if char_length(btrim(coalesce(p_event_type, ''))) < 2 then
    return jsonb_build_object('ok', false, 'code', 'event_type_required');
  end if;
  insert into public.account_security_events (
    user_id, event_type, severity, session_reference, event_data
  ) values (
    auth.uid(), left(btrim(p_event_type), 100), 'review',
    nullif(left(btrim(coalesce(p_session_reference, '')), 100), ''),
    jsonb_build_object('details', nullif(left(btrim(coalesce(p_details, '')), 1000), ''))
  ) returning * into v_event;

  return jsonb_build_object(
    'ok', true,
    'event_id', v_event.id,
    'status', v_event.status,
    'global_sign_out_available_in_client', true
  );
end;
$$;

create or replace function private.classify_job_risk()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_content text := lower(
    coalesce(new.title, '') || ' ' || coalesce(new.description, '') || ' ' ||
    coalesce(new.special_instructions, '') || ' ' || coalesce(new.equipment_provided, '') || ' ' ||
    coalesce(new.equipment_worker_brings, '')
  );
begin
  if v_content ~ '(roof|firearm|\mgun\M|hazardous chemical|adult entertainment|sexual service|illegal activity|overnight|alcohol handling|drug handling|heavy machinery|intimate care|nudity)' then
    new.risk_tier := 'prohibited_for_teens';
  elsif new.location_type in ('private_residence', 'isolated_property')
    or new.transportation_required
    or new.recurring
    or v_content ~ '(power tool|heavy lift|aggressive animal|unsupervised access)'
    or (new.starts_at is not null and extract(hour from new.starts_at at time zone new.timezone) not between 7 and 19) then
    new.risk_tier := 'elevated_review';
  else
    new.risk_tier := 'lower_risk';
  end if;

  if new.status <> 'draft' and new.risk_tier = 'prohibited_for_teens' then
    raise exception 'prohibited_teen_job';
  end if;
  if new.status <> 'draft' and new.animal_risk_notes is not null and not new.animal_risk_disclosed then
    raise exception 'animal_risk_disclosure_required';
  end if;
  if new.status <> 'draft' and new.equipment_risk_notes is not null and not new.equipment_risk_disclosed then
    raise exception 'equipment_risk_disclosure_required';
  end if;
  return new;
end;
$$;

create trigger jobs_classify_mutual_safety_risk
before insert or update of title, description, special_instructions,
  equipment_provided, equipment_worker_brings, location_type,
  transportation_required, recurring, starts_at, timezone, status,
  animal_risk_disclosed, animal_risk_notes,
  equipment_risk_disclosed, equipment_risk_notes
on public.jobs
for each row execute function private.classify_job_risk();

create or replace function public.save_job_safety_disclosures(
  p_job_id uuid,
  p_who_will_be_present text,
  p_animal_risk_disclosed boolean,
  p_animal_risk_notes text,
  p_equipment_risk_disclosed boolean,
  p_equipment_risk_notes text,
  p_transportation_required boolean,
  p_public_meeting_available boolean,
  p_daylight_only boolean,
  p_weather_risk_acknowledged boolean
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_job public.jobs%rowtype;
begin
  if auth.uid() is null or not private.has_marketplace_identity(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'identity_verification_required');
  end if;
  update public.jobs
  set who_will_be_present = nullif(left(btrim(coalesce(p_who_will_be_present, '')), 500), ''),
      animal_risk_disclosed = p_animal_risk_disclosed,
      animal_risk_notes = nullif(left(btrim(coalesce(p_animal_risk_notes, '')), 1000), ''),
      equipment_risk_disclosed = p_equipment_risk_disclosed,
      equipment_risk_notes = nullif(left(btrim(coalesce(p_equipment_risk_notes, '')), 1000), ''),
      transportation_required = p_transportation_required,
      public_meeting_available = p_public_meeting_available,
      daylight_only = p_daylight_only,
      weather_risk_acknowledged = p_weather_risk_acknowledged,
      updated_at = now()
  where id = p_job_id
    and poster_id = auth.uid()
    and status in ('draft', 'open', 'paused')
  returning * into v_job;
  if v_job.id is null then
    return jsonb_build_object('ok', false, 'code', 'job_not_editable');
  end if;
  return jsonb_build_object('ok', true, 'job_id', v_job.id, 'risk_tier', v_job.risk_tier, 'scope_version', v_job.scope_version);
end;
$$;

create or replace function public.escalate_missed_job_checkins()
returns integer
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_checkin record;
  v_count integer := 0;
  v_contact record;
begin
  if coalesce(auth.jwt()->>'role', '') <> 'service_role' then
    raise exception 'service_role_required';
  end if;
  for v_checkin in
    update public.job_checkins
    set status = 'missed', escalation_sent_at = now()
    where status = 'pending'
      and expected_at is not null
      and expected_at < now() - interval '10 minutes'
    returning *
  loop
    v_count := v_count + 1;
    for v_contact in
      select circle.contact_id
      from public.safety_circle_members circle
      where circle.teen_id = v_checkin.user_id
        and circle.status = 'active'
        and circle.receive_missed_checkin
        and circle.contact_id is not null
    loop
      perform public.enqueue_notification(
        v_contact.contact_id,
        'Missed MORT check-in',
        'A Safety Circle member missed a scheduled job check-in. Contact emergency services for immediate danger.',
        jsonb_build_object('applicationId', v_checkin.application_id, 'checkinId', v_checkin.id)
      );
    end loop;
  end loop;
  return v_count;
end;
$$;

create or replace function public.admin_set_safety_role(
  p_user_id uuid,
  p_role text,
  p_enabled boolean,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_role public.admin_safety_role;
  v_target public.profiles%rowtype;
  v_changed integer := 0;
begin
  if auth.uid() is null or not private.has_admin_safety_role(
    auth.uid(),
    array['super_admin']::public.admin_safety_role[]
  ) then
    return jsonb_build_object('ok', false, 'code', 'super_admin_required');
  end if;
  if char_length(btrim(coalesce(p_reason, ''))) < 10 then
    return jsonb_build_object('ok', false, 'code', 'role_change_reason_required');
  end if;
  begin
    v_role := lower(btrim(p_role))::public.admin_safety_role;
  exception when invalid_text_representation then
    return jsonb_build_object('ok', false, 'code', 'invalid_admin_safety_role');
  end;

  select * into v_target from public.profiles where id = p_user_id;
  if v_target.id is null or v_target.role <> 'admin' then
    return jsonb_build_object('ok', false, 'code', 'admin_profile_required');
  end if;

  if p_enabled then
    insert into public.admin_role_assignments (
      user_id, role, granted_by, grant_reason
    ) values (
      p_user_id, v_role, auth.uid(), left(btrim(p_reason), 500)
    )
    on conflict (user_id, role) where revoked_at is null
    do update set
      granted_by = excluded.granted_by,
      grant_reason = excluded.grant_reason;
    get diagnostics v_changed = row_count;
  else
    if v_role = 'super_admin' and (
      select count(*)
      from public.admin_role_assignments assignment
      join public.profiles profile on profile.id = assignment.user_id
      where assignment.role = 'super_admin'
        and assignment.revoked_at is null
        and profile.role = 'admin'
        and profile.account_status = 'active'
    ) <= 1 then
      return jsonb_build_object('ok', false, 'code', 'last_super_admin_cannot_be_removed');
    end if;
    update public.admin_role_assignments
    set revoked_at = now()
    where user_id = p_user_id
      and role = v_role
      and revoked_at is null;
    get diagnostics v_changed = row_count;
  end if;

  insert into public.verification_audit_events (
    actor_id, action, access_reason, event_data
  ) values (
    auth.uid(),
    case when p_enabled then 'admin_safety_role_enabled' else 'admin_safety_role_disabled' end,
    left(btrim(p_reason), 500),
    jsonb_build_object('target_user_id', p_user_id, 'role', v_role, 'changed_rows', v_changed)
  );

  return jsonb_build_object(
    'ok', true,
    'user_id', p_user_id,
    'role', v_role,
    'enabled', p_enabled,
    'changed_rows', v_changed
  );
end;
$$;

create index incident_evidence_submitted_by_idx
on public.incident_evidence(submitted_by, created_at desc);
create index incident_evidence_access_evidence_idx
on public.incident_evidence_access_grants(evidence_id, expires_at);
create index incident_assignments_assignee_idx
on public.incident_assignments(assigned_to, ended_at);
create index incident_assignments_assigner_idx
on public.incident_assignments(assigned_by, assigned_at desc);
create index incident_actions_actor_idx
on public.incident_actions(actor_id, created_at desc);
create index incident_actions_approver_idx
on public.incident_actions(approved_by) where approved_by is not null;
create index incident_preservation_ordered_by_idx
on public.incident_preservation_orders(ordered_by, created_at desc);
create index incident_law_requests_incident_idx
on public.incident_law_enforcement_requests(incident_id, created_at desc);
create index incident_law_requests_reviewer_idx
on public.incident_law_enforcement_requests(reviewed_by) where reviewed_by is not null;
create index incident_contact_actor_idx
on public.incident_contact_attempts(actor_id, created_at desc);
create index incident_appeals_appellant_idx
on public.incident_appeals(appellant_id, created_at desc);
create index incident_appeals_reviewer_idx
on public.incident_appeals(reviewer_id) where reviewer_id is not null;
create index incident_outcomes_decider_idx
on public.incident_outcomes(decided_by, decided_at desc);
create index job_safety_plans_job_idx
on public.job_safety_plans(job_id);
create index job_safety_plans_teen_idx
on public.job_safety_plans(teen_id);
create index job_safety_plans_adult_idx
on public.job_safety_plans(adult_id);
create index job_safety_agreements_job_idx
on public.job_safety_agreements(job_id, status);
create index job_safety_agreements_adult_idx
on public.job_safety_agreements(adult_id, status);
create index job_private_locations_poster_idx
on public.job_private_locations(poster_id);
create index job_location_share_owner_idx
on public.job_location_share_sessions(owner_id, status, expires_at);
create index job_arrival_handshakes_job_idx
on public.job_arrival_handshakes(job_id);
create index job_arrival_handshakes_teen_idx
on public.job_arrival_handshakes(teen_id);
create index job_arrival_handshakes_adult_idx
on public.job_arrival_handshakes(adult_id);
create index job_checkins_application_idx
on public.job_checkins(application_id, created_at desc);
create index job_checkins_user_idx
on public.job_checkins(user_id, created_at desc);
create index trusted_relationships_source_job_idx
on public.trusted_relationships(source_job_id) where source_job_id is not null;
create index safety_cancellations_application_idx
on public.safety_cancellations(application_id, created_at desc);
create index safety_cancellations_job_idx
on public.safety_cancellations(job_id, created_at desc);
create index safety_cancellations_actor_idx
on public.safety_cancellations(actor_id, created_at desc);
create index safety_cancellations_incident_idx
on public.safety_cancellations(incident_id) where incident_id is not null;
create index review_private_safety_author_idx
on public.review_private_safety_feedback(author_id, created_at desc);
create index review_private_safety_subject_idx
on public.review_private_safety_feedback(subject_id, created_at desc);
create index message_safety_evidence_sender_idx
on public.message_safety_evidence(sender_id, created_at desc);
create index message_safety_evidence_thread_idx
on public.message_safety_evidence(thread_id, created_at desc);

revoke all on function private.normalize_safety_report() from public, anon, authenticated;
revoke all on function private.create_incident_for_report() from public, anon, authenticated;
revoke all on function private.notify_safety_circle_ping() from public, anon, authenticated;
revoke all on function private.job_safety_terms(uuid) from public, anon, authenticated;
revoke all on function private.ensure_job_safety_agreement() from public, anon, authenticated;
revoke all on function private.enforce_safety_agreement_before_start() from public, anon, authenticated;
revoke all on function private.refresh_agreements_after_job_change() from public, anon, authenticated;
revoke all on function private.reconfirm_agreements_after_job_change() from public, anon, authenticated;
revoke all on function private.enforce_no_contact_after_block() from public, anon, authenticated;
revoke all on function private.reveal_mutual_reviews() from public, anon, authenticated;
revoke all on function private.protect_serious_review_content() from public, anon, authenticated;
revoke all on function private.classify_job_risk() from public, anon, authenticated;

revoke all on function public.submit_safety_report(uuid, uuid, uuid, uuid, uuid, text, text, boolean, text, timestamptz, text, text, boolean) from public, anon;
revoke all on function public.get_my_incident_cases() from public, anon;
revoke all on function public.register_incident_evidence(uuid, uuid, text, text, text) from public, anon;
revoke all on function public.authorize_incident_evidence_access(uuid, text) from public, anon;
revoke all on function public.admin_update_incident_case(uuid, text, text, text, text) from public, anon;
revoke all on function public.place_incident_preservation_hold(uuid, text, text, timestamptz) from public, anon;
revoke all on function public.submit_incident_appeal(uuid, text) from public, anon;
revoke all on function public.admin_record_law_enforcement_request(uuid, text, text, text, text, timestamptz, boolean) from public, anon;
revoke all on function public.create_safety_circle_invite(text, jsonb) from public, anon;
revoke all on function public.accept_safety_circle_invite(text) from public, anon;
revoke all on function public.update_safety_circle_permissions(uuid, jsonb) from public, anon;
revoke all on function public.unlink_safety_circle_member(uuid) from public, anon;
revoke all on function public.get_my_safety_circle() from public, anon;
revoke all on function public.save_job_safety_plan(uuid, text, boolean, boolean, text, integer) from public, anon;
revoke all on function public.confirm_job_safety_agreement(uuid, integer) from public, anon;
revoke all on function public.save_job_private_location(uuid, text, text, text) from public, anon;
revoke all on function public.get_released_job_location(uuid) from public, anon;
revoke all on function public.start_temporary_location_share(uuid, uuid, text, timestamptz, text, double precision, double precision, boolean) from public, anon;
revoke all on function public.update_temporary_job_location(uuid, double precision, double precision) from public, anon;
revoke all on function public.stop_temporary_location_share(uuid) from public, anon;
revoke all on function public.get_authorized_location_shares() from public, anon;
revoke all on function public.generate_job_arrival_code(uuid) from public, anon;
revoke all on function public.confirm_job_arrival_code(uuid, text, boolean) from public, anon;
revoke all on function public.confirm_job_checkout(uuid) from public, anon;
revoke all on function public.report_person_mismatch(uuid, text) from public, anon;
revoke all on function public.set_trusted_relationship(uuid, text, uuid, boolean) from public, anon;
revoke all on function public.submit_safety_cancellation(uuid, text, text) from public, anon;
revoke all on function public.submit_private_review_safety_feedback(uuid, jsonb, text) from public, anon;
revoke all on function public.scan_message_body(text) from public, anon;
revoke all on function public.send_safe_message(uuid, text) from public, anon;
revoke all on function public.get_my_active_sessions() from public, anon;
revoke all on function public.report_account_security_concern(text, text, text) from public, anon;
revoke all on function public.save_job_safety_disclosures(uuid, text, boolean, text, boolean, text, boolean, boolean, boolean, boolean) from public, anon;
revoke all on function public.escalate_missed_job_checkins() from public, anon, authenticated;
revoke all on function public.admin_set_safety_role(uuid, text, boolean, text) from public, anon;

grant execute on function public.submit_safety_report(uuid, uuid, uuid, uuid, uuid, text, text, boolean, text, timestamptz, text, text, boolean) to authenticated, service_role;
grant execute on function public.get_my_incident_cases() to authenticated, service_role;
grant execute on function public.register_incident_evidence(uuid, uuid, text, text, text) to authenticated, service_role;
grant execute on function public.authorize_incident_evidence_access(uuid, text) to authenticated, service_role;
grant execute on function public.admin_update_incident_case(uuid, text, text, text, text) to authenticated, service_role;
grant execute on function public.place_incident_preservation_hold(uuid, text, text, timestamptz) to authenticated, service_role;
grant execute on function public.submit_incident_appeal(uuid, text) to authenticated, service_role;
grant execute on function public.admin_record_law_enforcement_request(uuid, text, text, text, text, timestamptz, boolean) to authenticated, service_role;
grant execute on function public.create_safety_circle_invite(text, jsonb) to authenticated, service_role;
grant execute on function public.accept_safety_circle_invite(text) to authenticated, service_role;
grant execute on function public.update_safety_circle_permissions(uuid, jsonb) to authenticated, service_role;
grant execute on function public.unlink_safety_circle_member(uuid) to authenticated, service_role;
grant execute on function public.get_my_safety_circle() to authenticated, service_role;
grant execute on function public.save_job_safety_plan(uuid, text, boolean, boolean, text, integer) to authenticated, service_role;
grant execute on function public.confirm_job_safety_agreement(uuid, integer) to authenticated, service_role;
grant execute on function public.save_job_private_location(uuid, text, text, text) to authenticated, service_role;
grant execute on function public.get_released_job_location(uuid) to authenticated, service_role;
grant execute on function public.start_temporary_location_share(uuid, uuid, text, timestamptz, text, double precision, double precision, boolean) to authenticated, service_role;
grant execute on function public.update_temporary_job_location(uuid, double precision, double precision) to authenticated, service_role;
grant execute on function public.stop_temporary_location_share(uuid) to authenticated, service_role;
grant execute on function public.get_authorized_location_shares() to authenticated, service_role;
grant execute on function public.generate_job_arrival_code(uuid) to authenticated, service_role;
grant execute on function public.confirm_job_arrival_code(uuid, text, boolean) to authenticated, service_role;
grant execute on function public.confirm_job_checkout(uuid) to authenticated, service_role;
grant execute on function public.report_person_mismatch(uuid, text) to authenticated, service_role;
grant execute on function public.set_trusted_relationship(uuid, text, uuid, boolean) to authenticated, service_role;
grant execute on function public.submit_safety_cancellation(uuid, text, text) to authenticated, service_role;
grant execute on function public.submit_private_review_safety_feedback(uuid, jsonb, text) to authenticated, service_role;
grant execute on function public.scan_message_body(text) to authenticated, service_role;
grant execute on function public.send_safe_message(uuid, text) to authenticated, service_role;
grant execute on function public.get_my_active_sessions() to authenticated, service_role;
grant execute on function public.report_account_security_concern(text, text, text) to authenticated, service_role;
grant execute on function public.save_job_safety_disclosures(uuid, text, boolean, text, boolean, text, boolean, boolean, boolean, boolean) to authenticated, service_role;
grant execute on function public.escalate_missed_job_checkins() to service_role;
grant execute on function public.admin_set_safety_role(uuid, text, boolean, text) to authenticated, service_role;

grant select on public.safety_incidents,
  public.incident_participants,
  public.incident_evidence,
  public.incident_evidence_access_grants,
  public.incident_timeline_events,
  public.incident_assignments,
  public.incident_actions,
  public.incident_preservation_orders,
  public.incident_law_enforcement_requests,
  public.incident_contact_attempts,
  public.incident_appeals,
  public.incident_outcomes,
  public.safety_circle_members,
  public.job_safety_plans,
  public.job_safety_agreements,
  public.job_private_locations,
  public.private_data_access_events,
  public.job_location_share_sessions,
  public.job_arrival_handshakes,
  public.job_checkins,
  public.trusted_relationships,
  public.safety_cancellations,
  public.review_private_safety_feedback,
  public.message_safety_evidence,
  public.account_security_events,
  public.jurisdiction_safety_policies
to authenticated, service_role;

grant all on public.safety_incidents,
  public.incident_participants,
  public.incident_evidence,
  public.incident_evidence_access_grants,
  public.incident_timeline_events,
  public.incident_assignments,
  public.incident_actions,
  public.incident_preservation_orders,
  public.incident_law_enforcement_requests,
  public.incident_contact_attempts,
  public.incident_appeals,
  public.incident_outcomes,
  public.safety_circle_members,
  public.job_safety_plans,
  public.job_safety_agreements,
  public.job_private_locations,
  public.private_data_access_events,
  public.job_location_share_sessions,
  public.job_arrival_handshakes,
  public.job_checkins,
  public.trusted_relationships,
  public.safety_cancellations,
  public.review_private_safety_feedback,
  public.message_safety_evidence,
  public.account_security_events,
  public.jurisdiction_safety_policies
to service_role;

grant usage, select on sequence public.safety_case_number_seq to service_role;
grant usage, select on sequence public.incident_timeline_events_id_seq to service_role;
grant usage, select on sequence public.private_data_access_events_id_seq to service_role;
