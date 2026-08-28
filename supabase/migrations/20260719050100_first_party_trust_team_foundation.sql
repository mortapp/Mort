-- Additive first-party document-quality, web-reuse-signal, live-presence,
-- appearance-review, and controlled adult-team foundation.
-- Real document and face collection remains structurally disabled.

create table private.first_party_trust_control (
  singleton boolean primary key default true check (singleton),
  real_document_collection_enabled boolean not null default false,
  external_web_reuse_enabled boolean not null default false,
  real_live_presence_enabled boolean not null default false,
  real_appearance_review_enabled boolean not null default false,
  legal_privacy_approved boolean not null default false,
  youth_safety_approved boolean not null default false,
  reviewer_operations_ready boolean not null default false,
  incident_response_ready boolean not null default false,
  insurance_review_complete boolean not null default false,
  enabled_by uuid references public.profiles(id) on delete restrict,
  enabled_at timestamptz,
  updated_at timestamptz not null default now(),
  constraint first_party_trust_fail_closed_check check (
    not real_document_collection_enabled
    and not external_web_reuse_enabled
    and not real_live_presence_enabled
    and not real_appearance_review_enabled
  )
);

insert into private.first_party_trust_control (singleton)
values (true)
on conflict (singleton) do nothing;

create table private.document_web_reuse_provider_configs (
  id uuid primary key default gen_random_uuid(),
  provider_key text not null unique,
  provider_kind text not null,
  server_secret_reference text,
  data_processing_terms_reference text,
  retention_review_reference text,
  enabled boolean not null default false,
  synthetic_qa_only boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint document_web_provider_kind_check check (provider_kind in ('unconfigured', 'google_cloud_vision_web_detection', 'synthetic_fixture')),
  constraint document_web_provider_fail_closed_check check (not enabled and synthetic_qa_only),
  constraint document_web_provider_secret_check check (server_secret_reference is null or server_secret_reference ~ '^[a-zA-Z0-9_./:-]{3,200}$')
);

insert into private.document_web_reuse_provider_configs (
  provider_key, provider_kind, enabled, synthetic_qa_only
) values (
  'unconfigured', 'unconfigured', false, true
) on conflict (provider_key) do nothing;

create table public.document_capture_sessions (
  id uuid primary key default gen_random_uuid(),
  subject_user_id uuid not null references public.profiles(id) on delete restrict,
  review_case_id uuid references public.document_review_cases(id) on delete restrict,
  document_type text not null,
  capture_state text not null default 'created',
  front_capture_object_id uuid references storage.objects(id) on delete restrict,
  back_capture_object_id uuid references storage.objects(id) on delete restrict,
  metadata_removed boolean not null default false,
  encrypted_server_upload boolean not null default false,
  synthetic_qa boolean not null default true,
  contains_real_person_data boolean not null default false,
  retention_expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  constraint document_capture_type_check check (document_type in ('synthetic_government_id', 'synthetic_school_id', 'synthetic_test_document')),
  constraint document_capture_state_check check (capture_state in ('created', 'front_captured', 'back_captured', 'quality_review', 'completed', 'rejected', 'expired')),
  constraint document_capture_synthetic_only_check check (synthetic_qa and not contains_real_person_data),
  constraint document_capture_retention_check check (retention_expires_at <= created_at + interval '24 hours')
);

create table public.document_capture_quality_results (
  id uuid primary key default gen_random_uuid(),
  capture_session_id uuid not null references public.document_capture_sessions(id) on delete restrict,
  result_level text not null,
  glare_detected boolean not null default false,
  blur_detected boolean not null default false,
  cutoff_edge_detected boolean not null default false,
  low_resolution_detected boolean not null default false,
  screenshot_signal_detected boolean not null default false,
  reproduction_warning boolean not null default false,
  orientation_corrected boolean not null default false,
  color_integrity_signal text not null default 'not_checked',
  contrast_integrity_signal text not null default 'not_checked',
  pdf417_parse_status text not null default 'not_supported',
  mrz_parse_status text not null default 'not_supported',
  expiration_parse_status text not null default 'not_checked',
  age_calculation_status text not null default 'not_checked',
  front_back_consistency text not null default 'not_checked',
  barcode_text_consistency text not null default 'not_checked',
  invalid_date_detected boolean not null default false,
  synthetic_fixture_recognized boolean not null default true,
  exact_duplicate_hash text,
  perceptual_duplicate_hash text,
  cross_account_reuse_signal boolean not null default false,
  authenticity_authoritatively_confirmed boolean not null default false,
  created_by_server boolean not null default true,
  created_at timestamptz not null default now(),
  unique (capture_session_id),
  constraint document_capture_quality_level_check check (result_level in ('document_capture_completed', 'document_quality_passed', 'document_data_extracted', 'document_format_consistent', 'additional_information_required', 'rejected', 'authenticity_not_authoritatively_confirmed')),
  constraint document_capture_quality_hash_check check (
    (exact_duplicate_hash is null or exact_duplicate_hash ~ '^[a-f0-9]{64}$')
    and (perceptual_duplicate_hash is null or perceptual_duplicate_hash ~ '^[a-f0-9]{16,128}$')
  ),
  constraint document_capture_quality_no_authority_check check (not authenticity_authoritatively_confirmed and created_by_server and synthetic_fixture_recognized)
);

create table public.document_web_reuse_requests (
  id uuid primary key default gen_random_uuid(),
  capture_session_id uuid not null references public.document_capture_sessions(id) on delete restrict,
  subject_user_id uuid not null references public.profiles(id) on delete restrict,
  provider_key text not null default 'unconfigured',
  consent_disclosure_version text not null,
  consent_recorded boolean not null default false,
  temporary_derivative_used boolean not null default true,
  unnecessary_areas_redacted boolean not null default true,
  request_status text not null default 'disabled',
  synthetic_qa boolean not null default true,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  constraint document_web_reuse_request_status_check check (request_status in ('disabled', 'synthetic_queued', 'synthetic_completed', 'synthetic_failed', 'expired')),
  constraint document_web_reuse_request_fail_closed_check check (synthetic_qa and request_status <> 'provider_queued'),
  constraint document_web_reuse_expiry_check check (expires_at <= created_at + interval '24 hours')
);

create table public.document_web_reuse_results (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null unique references public.document_web_reuse_requests(id) on delete restrict,
  provider_event_id text not null unique,
  provider_signature_verified boolean not null,
  result_level text not null,
  exact_full_match_count integer not null default 0,
  partial_match_count integer not null default 0,
  known_test_fixture_match boolean not null default false,
  risk_reasons text[] not null default '{}'::text[],
  reviewer_url_manifest jsonb not null default '[]'::jsonb,
  automatically_approved boolean not null default false,
  automatically_rejected boolean not null default false,
  authenticity_conclusion text not null default 'authenticity_not_authoritatively_confirmed',
  synthetic_qa boolean not null default true,
  created_at timestamptz not null default now(),
  constraint document_web_reuse_count_check check (exact_full_match_count >= 0 and partial_match_count >= 0),
  constraint document_web_reuse_level_check check (result_level in ('document_web_reuse_signal_clear', 'document_web_reuse_signal_flagged', 'additional_information_required')),
  constraint document_web_reuse_no_auth_check check (
    provider_signature_verified
    and not automatically_approved
    and not automatically_rejected
    and authenticity_conclusion = 'authenticity_not_authoritatively_confirmed'
    and synthetic_qa
  )
);

create table public.live_presence_challenges (
  id uuid primary key default gen_random_uuid(),
  subject_user_id uuid not null references public.profiles(id) on delete restrict,
  server_nonce_hash text not null unique,
  challenge_steps text[] not null,
  challenge_binding_hash text not null,
  expires_at timestamptz not null,
  status text not null default 'issued',
  accessibility_alternative_available boolean not null default true,
  accessibility_alternative_requested boolean not null default false,
  accessibility_reason_code text,
  synthetic_qa boolean not null default true,
  contains_real_face_data boolean not null default false,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  constraint live_presence_nonce_hash_check check (server_nonce_hash ~ '^[a-f0-9]{64}$' and challenge_binding_hash ~ '^[a-f0-9]{64}$'),
  constraint live_presence_steps_check check (cardinality(challenge_steps) between 3 and 5),
  constraint live_presence_status_check check (status in ('issued', 'accessibility_alternative_requested', 'submitted', 'passed_signal_only', 'rejected_replay', 'rejected_multiple_faces', 'expired', 'cancelled')),
  constraint live_presence_expiry_check check (expires_at <= created_at + interval '10 minutes'),
  constraint live_presence_synthetic_only_check check (synthetic_qa and not contains_real_face_data and accessibility_alternative_available)
);

create table public.live_presence_results (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null unique references public.live_presence_challenges(id) on delete restrict,
  provider_event_id text not null unique,
  provider_signature_verified boolean not null,
  nonce_verified boolean not null,
  challenge_binding_verified boolean not null,
  replay_detected boolean not null,
  prerecorded_video_risk text not null default 'not_checked',
  screen_recapture_risk text not null default 'not_checked',
  frame_continuity_passed boolean not null,
  face_presence_passed boolean not null,
  multiple_faces_detected boolean not null,
  result_level text not null,
  legal_identity_verified boolean not null default false,
  persistent_face_template_created boolean not null default false,
  synthetic_qa boolean not null default true,
  created_at timestamptz not null default now(),
  constraint live_presence_result_level_check check (result_level in ('live_presence_challenge_passed', 'additional_information_required', 'rejected_replay', 'rejected_multiple_faces')),
  constraint live_presence_result_boundary_check check (
    provider_signature_verified
    and nonce_verified
    and challenge_binding_verified
    and not legal_identity_verified
    and not persistent_face_template_created
    and synthetic_qa
    and ((result_level = 'rejected_replay') = replay_detected)
  )
);

create table public.appearance_review_cases (
  id uuid primary key default gen_random_uuid(),
  document_review_case_id uuid not null unique references public.document_review_cases(id) on delete restrict,
  subject_user_id uuid not null references public.profiles(id) on delete restrict,
  review_state text not null default 'awaiting_assignment',
  requires_two_independent_reviewers boolean not null default true,
  reusable_biometric_embedding_created boolean not null default false,
  synthetic_qa boolean not null default true,
  contains_real_face_data boolean not null default false,
  final_result text,
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  constraint appearance_review_state_check check (review_state in ('awaiting_assignment', 'first_review', 'second_review_required', 'appeal_pending', 'resolved')),
  constraint appearance_review_result_check check (final_result is null or final_result in ('appearance_consistency_reviewed', 'appearance_mismatch_requires_review', 'additional_information_required')),
  constraint appearance_review_boundary_check check (requires_two_independent_reviewers and not reusable_biometric_embedding_created and synthetic_qa and not contains_real_face_data)
);

create table public.appearance_review_assignments (
  id uuid primary key default gen_random_uuid(),
  appearance_case_id uuid not null references public.appearance_review_cases(id) on delete restrict,
  reviewer_id uuid not null references public.profiles(id) on delete restrict,
  review_position integer not null,
  assigned_by uuid not null references public.profiles(id) on delete restrict,
  purpose text not null,
  status text not null default 'active',
  assigned_at timestamptz not null default now(),
  expires_at timestamptz not null,
  completed_at timestamptz,
  unique (appearance_case_id, reviewer_id),
  unique (appearance_case_id, review_position),
  constraint appearance_assignment_position_check check (review_position in (1, 2)),
  constraint appearance_assignment_status_check check (status in ('active', 'completed', 'revoked')),
  constraint appearance_assignment_expiry_check check (expires_at > assigned_at)
);

create table public.appearance_review_decisions (
  id uuid primary key default gen_random_uuid(),
  appearance_case_id uuid not null references public.appearance_review_cases(id) on delete restrict,
  assignment_id uuid not null unique references public.appearance_review_assignments(id) on delete restrict,
  reviewer_id uuid not null references public.profiles(id) on delete restrict,
  result_level text not null,
  rationale_code text not null,
  notes text,
  legal_identity_verified boolean not null default false,
  decided_at timestamptz not null default now(),
  unique (appearance_case_id, reviewer_id),
  constraint appearance_decision_level_check check (result_level in ('appearance_consistency_reviewed', 'appearance_mismatch_requires_review', 'additional_information_required')),
  constraint appearance_decision_no_identity_check check (not legal_identity_verified)
);

create table public.team_role_assignments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete restrict,
  role_key text not null,
  environment_scope text not null default 'synthetic_qa',
  access_status text not null default 'pending_training',
  approved_by uuid references public.profiles(id) on delete restrict,
  approval_reason text not null,
  access_reason text not null,
  granted_at timestamptz,
  expires_at timestamptz,
  revoked_by uuid references public.profiles(id) on delete restrict,
  revoked_at timestamptz,
  revocation_reason text,
  created_at timestamptz not null default now(),
  constraint team_role_key_check check (role_key in ('product_tester', 'accessibility_tester', 'qa_tester', 'security_advisor', 'developer', 'partner_coordinator', 'support_trainee', 'document_reviewer_trainee', 'document_reviewer', 'senior_document_reviewer', 'safety_moderator', 'incident_manager', 'super_admin')),
  constraint team_role_environment_check check (environment_scope in ('synthetic_qa', 'staging', 'closed_pilot', 'production_restricted')),
  constraint team_role_status_check check (access_status in ('pending_training', 'pending_approval', 'active', 'expired', 'revoked')),
  constraint team_role_active_check check (access_status <> 'active' or (approved_by is not null and granted_at is not null and expires_at is not null and expires_at > granted_at))
);

create unique index team_role_active_unique_idx
  on public.team_role_assignments(user_id, role_key, environment_scope)
  where access_status in ('pending_training', 'pending_approval', 'active');

create table public.team_training_modules (
  module_key text primary key,
  title text not null,
  module_version integer not null default 1,
  requires_assessment boolean not null default true,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint team_training_module_key_check check (module_key ~ '^[a-z0-9_]{3,100}$')
);

insert into public.team_training_modules (module_key, title) values
  ('privacy_confidentiality', 'Privacy and confidentiality'),
  ('data_minimization', 'Data minimization'),
  ('identity_review_limitations', 'Identity-review limitations'),
  ('document_security_features', 'Common document-security features'),
  ('image_manipulation_indicators', 'Image-manipulation indicators'),
  ('school_id_limitations', 'School-ID limitations'),
  ('government_id_limitations', 'Government-ID limitations'),
  ('live_presence_limitations', 'Live-presence limitations'),
  ('web_image_match_limitations', 'Web-image-match limitations'),
  ('disability_accommodation', 'Disability accommodation'),
  ('bias_nondiscrimination', 'Bias and nondiscrimination'),
  ('teen_safety', 'Teen safety'),
  ('sexual_safety_escalation', 'Sexual-safety escalation'),
  ('evidence_handling', 'Evidence handling'),
  ('conflict_of_interest', 'Conflict of interest'),
  ('appeals', 'Appeals'),
  ('no_criminal_accusations', 'No criminal accusations'),
  ('incident_escalation', 'Incident escalation'),
  ('breach_reporting', 'Breach reporting'),
  ('access_revocation', 'Access revocation')
on conflict (module_key) do update
set title = excluded.title,
    active = true;

create table public.team_role_training_requirements (
  role_key text not null,
  module_key text not null references public.team_training_modules(module_key) on delete restrict,
  required boolean not null default true,
  created_at timestamptz not null default now(),
  primary key (role_key, module_key),
  constraint team_role_training_role_check check (role_key in ('product_tester', 'accessibility_tester', 'qa_tester', 'security_advisor', 'developer', 'partner_coordinator', 'support_trainee', 'document_reviewer_trainee', 'document_reviewer', 'senior_document_reviewer', 'safety_moderator', 'incident_manager', 'super_admin'))
);

insert into public.team_role_training_requirements (role_key, module_key)
select role.role_key, module.module_key
from (
  values ('document_reviewer'), ('senior_document_reviewer'), ('safety_moderator'), ('incident_manager'), ('super_admin')
) as role(role_key)
cross join public.team_training_modules module
where module.active
on conflict (role_key, module_key) do nothing;

insert into public.team_role_training_requirements (role_key, module_key)
select role.role_key, module.module_key
from (
  values ('product_tester'), ('accessibility_tester'), ('qa_tester'), ('security_advisor'), ('developer'), ('partner_coordinator'), ('support_trainee'), ('document_reviewer_trainee')
) as role(role_key)
cross join public.team_training_modules module
where module.module_key in ('privacy_confidentiality', 'data_minimization', 'identity_review_limitations', 'disability_accommodation', 'bias_nondiscrimination', 'teen_safety', 'evidence_handling', 'conflict_of_interest', 'incident_escalation', 'breach_reporting', 'access_revocation')
on conflict (role_key, module_key) do nothing;

create table public.team_training_completions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete restrict,
  module_key text not null references public.team_training_modules(module_key) on delete restrict,
  module_version integer not null,
  assessment_passed boolean not null,
  score_percent numeric(5,2),
  completed_at timestamptz not null default now(),
  expires_at timestamptz not null,
  approved_by uuid references public.profiles(id) on delete restrict,
  unique (user_id, module_key, module_version),
  constraint team_training_completion_check check (assessment_passed and (score_percent is null or score_percent between 0 and 100)),
  constraint team_training_expiry_check check (expires_at > completed_at)
);

create table public.team_confidentiality_acknowledgements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete restrict,
  policy_version text not null,
  content_hash text not null,
  affirmative_checkbox boolean not null,
  acknowledged_at timestamptz not null default now(),
  expires_at timestamptz not null,
  revoked_at timestamptz,
  unique (user_id, policy_version),
  constraint team_confidentiality_hash_check check (content_hash ~ '^[a-f0-9]{64}$'),
  constraint team_confidentiality_affirmative_check check (affirmative_checkbox),
  constraint team_confidentiality_expiry_check check (expires_at > acknowledged_at)
);

create table public.team_conflict_disclosures (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete restrict,
  disclosure_version text not null,
  has_conflict boolean not null,
  conflict_summary text,
  reviewed_by uuid references public.profiles(id) on delete restrict,
  review_status text not null default 'pending',
  disclosed_at timestamptz not null default now(),
  reviewed_at timestamptz,
  expires_at timestamptz not null,
  constraint team_conflict_summary_check check ((has_conflict and conflict_summary is not null) or (not has_conflict)),
  constraint team_conflict_review_check check (review_status in ('pending', 'cleared', 'restricted', 'recusal_required')),
  constraint team_conflict_expiry_check check (expires_at > disclosed_at)
);

create table public.team_device_compliance (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete restrict,
  device_reference_hash text not null,
  passcode_enabled boolean not null,
  encryption_enabled boolean not null,
  supported_os boolean not null,
  shared_device boolean not null default false,
  review_status text not null default 'pending',
  reviewed_by uuid references public.profiles(id) on delete restrict,
  reviewed_at timestamptz,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  constraint team_device_hash_check check (device_reference_hash ~ '^[a-f0-9]{64}$'),
  constraint team_device_status_check check (review_status in ('pending', 'approved', 'rejected', 'revoked')),
  constraint team_device_approval_check check (review_status <> 'approved' or (passcode_enabled and encryption_enabled and supported_os and not shared_device and reviewed_by is not null and reviewed_at is not null))
);

create table public.team_access_audit_events (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete restrict,
  role_assignment_id uuid references public.team_role_assignments(id) on delete restrict,
  action text not null,
  target_category text not null,
  target_id uuid,
  purpose text not null,
  access_allowed boolean not null,
  denial_reason text,
  occurred_at timestamptz not null default now(),
  constraint team_access_action_check check (action in ('role_requested', 'role_approved', 'role_revoked', 'case_view', 'evidence_view', 'evidence_export', 'assignment_created', 'assignment_revoked', 'access_denied')),
  constraint team_access_denial_check check (access_allowed or denial_reason is not null)
);

create index document_capture_subject_idx on public.document_capture_sessions(subject_user_id, created_at desc);
create index document_capture_review_case_idx on public.document_capture_sessions(review_case_id) where review_case_id is not null;
create index document_web_reuse_subject_idx on public.document_web_reuse_requests(subject_user_id, created_at desc);
create index live_presence_subject_idx on public.live_presence_challenges(subject_user_id, created_at desc);
create index appearance_review_subject_idx on public.appearance_review_cases(subject_user_id, created_at desc);
create index appearance_assignments_reviewer_idx on public.appearance_review_assignments(reviewer_id, status, expires_at);
create index team_roles_user_idx on public.team_role_assignments(user_id, access_status, expires_at);
create index team_training_user_idx on public.team_training_completions(user_id, expires_at);
create index team_conflicts_user_idx on public.team_conflict_disclosures(user_id, expires_at);
create index team_device_user_idx on public.team_device_compliance(user_id, expires_at);
create index team_access_audit_user_idx on public.team_access_audit_events(user_id, occurred_at desc);
