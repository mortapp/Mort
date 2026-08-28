-- Additive legal clickwrap, job-contract, completion, and payment-dispute foundation.
-- All legal text remains attorney-review draft material until explicitly published
-- through a future reviewed migration. MORT does not process or escrow payments.

alter table public.jobs
  add column if not exists excluded_work text[] not null default array['Any work not expressly described in the accepted scope', 'Any work prohibited by MORT policy']::text[],
  add column if not exists maximum_approved_hours numeric(6,2),
  add column if not exists authorized_expenses text[] not null default '{}'::text[],
  add column if not exists completion_requirements text,
  add column if not exists cancellation_terms text not null default 'Either participant may cancel for a reasonable safety concern. Other cancellation consequences remain subject to the accepted job agreement and applicable law.',
  add column if not exists payment_due_rule text not null default 'within_24_hours_of_completion';

alter table public.jobs
  drop constraint if exists jobs_maximum_approved_hours_check,
  add constraint jobs_maximum_approved_hours_check
    check (maximum_approved_hours is null or (maximum_approved_hours > 0 and maximum_approved_hours <= 24)),
  drop constraint if exists jobs_payment_due_rule_check,
  add constraint jobs_payment_due_rule_check
    check (payment_due_rule in ('at_completion', 'within_24_hours_of_completion', 'scheduled_timestamp'));

create table public.legal_documents (
  id uuid primary key default gen_random_uuid(),
  document_key text not null unique,
  title text not null,
  document_category text not null,
  plain_language_summary_key text,
  guardian_mode_independent boolean not null default true,
  publication_status text not null default 'draft_attorney_review',
  created_at timestamptz not null default now(),
  constraint legal_documents_key_check check (document_key ~ '^[a-z0-9_]{3,100}$'),
  constraint legal_documents_status_check check (publication_status in ('draft_attorney_review', 'published', 'retired')),
  constraint legal_documents_guardian_independent_check check (guardian_mode_independent)
);

create table public.legal_document_versions (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.legal_documents(id) on delete restrict,
  version_label text not null,
  content_hash text not null,
  content_path text not null,
  content_markdown text,
  effective_at timestamptz,
  published_at timestamptz,
  retired_at timestamptz,
  material_revision boolean not null default true,
  requires_electronic_signature boolean not null default false,
  publication_status text not null default 'draft_attorney_review',
  language_code text not null default 'en-US',
  jurisdiction_policy text not null default 'requires_jurisdiction_specific_attorney_review',
  acceptance_ui_version text not null default 'legal-clickwrap-v1',
  attorney_reviewed_at timestamptz,
  approved_by_counsel_reference text,
  created_at timestamptz not null default now(),
  unique (document_id, version_label),
  constraint legal_document_versions_hash_check check (content_hash ~ '^[a-f0-9]{64}$'),
  constraint legal_document_versions_status_check check (publication_status in ('draft_attorney_review', 'published', 'retired')),
  constraint legal_document_versions_published_check check (
    publication_status <> 'published'
    or (
      effective_at is not null
      and published_at is not null
      and attorney_reviewed_at is not null
      and approved_by_counsel_reference is not null
      and char_length(coalesce(content_markdown, '')) >= 200
    )
  )
);

create table public.legal_role_requirements (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.legal_documents(id) on delete restrict,
  role public.user_role not null,
  age_band text not null default 'all',
  required boolean not null default true,
  priority integer not null default 100,
  created_at timestamptz not null default now(),
  unique (document_id, role, age_band),
  constraint legal_role_age_band_check check (age_band in ('teen_13_15', 'teen_16_17', 'adult_18_plus', 'all'))
);

create table public.legal_jurisdiction_requirements (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.legal_documents(id) on delete restrict,
  country_code text not null default 'US',
  region_code text not null default '*',
  requirement_status text not null default 'legal_review_required',
  guardian_legal_consent_required boolean,
  configured_separately_from_guardian_mode boolean not null default true,
  legal_review_reference text,
  effective_at timestamptz,
  created_at timestamptz not null default now(),
  unique (document_id, country_code, region_code),
  constraint legal_jurisdiction_status_check check (requirement_status in ('legal_review_required', 'approved', 'unavailable')),
  constraint legal_jurisdiction_guardian_separation_check check (configured_separately_from_guardian_mode)
);

create table public.legal_acceptances (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete restrict,
  role public.user_role not null,
  age_band text not null,
  document_id uuid not null references public.legal_documents(id) on delete restrict,
  document_version_id uuid not null references public.legal_document_versions(id) on delete restrict,
  content_hash text not null,
  effective_date timestamptz not null,
  accepted_at timestamptz not null default now(),
  platform text not null,
  app_version text not null,
  language_code text not null,
  jurisdiction_policy text not null,
  acceptance_ui_version text not null,
  affirmative_checkbox boolean not null,
  electronic_signature_text text,
  active boolean not null default true,
  withdrawn_at timestamptz,
  withdrawal_reason text,
  server_request_id uuid not null default gen_random_uuid(),
  created_at timestamptz not null default now(),
  constraint legal_acceptances_affirmative_check check (affirmative_checkbox),
  constraint legal_acceptances_age_band_check check (age_band in ('teen_13_15', 'teen_16_17', 'adult_18_plus')),
  constraint legal_acceptances_withdrawal_check check ((active and withdrawn_at is null) or (not active and withdrawn_at is not null)),
  unique (user_id, document_version_id, server_request_id)
);

create unique index legal_acceptances_one_active_version_idx
  on public.legal_acceptances(user_id, document_version_id)
  where active;

create table public.legal_declines (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete restrict,
  document_id uuid not null references public.legal_documents(id) on delete restrict,
  document_version_id uuid not null references public.legal_document_versions(id) on delete restrict,
  role public.user_role not null,
  reason_code text not null default 'declined',
  optional_document boolean not null default false,
  platform text not null,
  app_version text not null,
  declined_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint legal_declines_reason_check check (reason_code in ('declined', 'needs_help', 'not_now', 'withdrawn'))
);

create table public.legal_reacceptance_requirements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete restrict,
  document_id uuid not null references public.legal_documents(id) on delete restrict,
  required_version_id uuid not null references public.legal_document_versions(id) on delete restrict,
  prior_acceptance_id uuid references public.legal_acceptances(id) on delete restrict,
  reason text not null,
  required_at timestamptz not null default now(),
  satisfied_by_acceptance_id uuid references public.legal_acceptances(id) on delete restrict,
  satisfied_at timestamptz,
  waived_at timestamptz,
  waiver_reason text,
  created_at timestamptz not null default now(),
  unique (user_id, required_version_id),
  constraint legal_reacceptance_resolution_check check (
    not (satisfied_at is not null and waived_at is not null)
    and (satisfied_at is null or satisfied_by_acceptance_id is not null)
  )
);

create table public.legal_acceptance_audit_events (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete restrict,
  document_id uuid not null references public.legal_documents(id) on delete restrict,
  document_version_id uuid not null references public.legal_document_versions(id) on delete restrict,
  acceptance_id uuid references public.legal_acceptances(id) on delete restrict,
  decline_id uuid references public.legal_declines(id) on delete restrict,
  event_type text not null,
  event_metadata jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now(),
  constraint legal_acceptance_audit_type_check check (event_type in ('accepted', 'declined', 'withdrawn', 'reacceptance_required', 'reacceptance_satisfied')),
  constraint legal_acceptance_audit_reference_check check (acceptance_id is not null or decline_id is not null or event_type = 'reacceptance_required')
);

create table public.job_contracts (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete restrict,
  application_id uuid not null references public.applications(id) on delete restrict,
  teen_id uuid not null references public.profiles(id) on delete restrict,
  adult_id uuid not null references public.profiles(id) on delete restrict,
  status text not null default 'pending_confirmation',
  active_version_id uuid,
  classification_status text not null default 'classification_unknown',
  created_at timestamptz not null default now(),
  activated_at timestamptz,
  closed_at timestamptz,
  unique (application_id),
  constraint job_contract_party_check check (teen_id <> adult_id),
  constraint job_contract_status_check check (status in ('pending_confirmation', 'active', 'change_pending', 'completed', 'disputed', 'cancelled')),
  constraint job_contract_classification_check check (classification_status in ('classification_unknown', 'possible_employee_relationship', 'possible_independent_service_relationship', 'organization_program_role', 'requires_review'))
);

create table public.job_contract_versions (
  id uuid primary key default gen_random_uuid(),
  contract_id uuid not null references public.job_contracts(id) on delete restrict,
  version_number integer not null,
  source text not null,
  source_change_request_id uuid,
  status text not null default 'pending_confirmation',
  teen_public_identifier text not null,
  adult_public_identifier text not null,
  agreed_scope text not null,
  excluded_work text[] not null,
  location_type text not null,
  exact_location_release_state text not null,
  service_date date,
  start_window timestamptz,
  expected_end_window timestamptz,
  amount_type text not null,
  hourly_rate_cents integer,
  maximum_approved_hours numeric(6,2),
  fixed_total_cents integer,
  currency_code text not null default 'USD',
  payment_preference text not null,
  payment_due_rule text not null,
  authorized_expenses text[] not null default '{}'::text[],
  equipment text,
  hazards text,
  expected_people_present text,
  supervision text,
  proof_requirements text,
  completion_requirements text,
  cancellation_terms text not null,
  material_change_process text not null,
  dispute_process text not null,
  safety_agreement_version text not null,
  terms_snapshot jsonb not null,
  content_hash text not null,
  created_by uuid references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  activated_at timestamptz,
  superseded_at timestamptz,
  unique (contract_id, version_number),
  constraint job_contract_versions_number_check check (version_number > 0),
  constraint job_contract_versions_source_check check (source in ('application_acceptance', 'mutual_change_request')),
  constraint job_contract_versions_status_check check (status in ('pending_confirmation', 'active', 'superseded', 'cancelled')),
  constraint job_contract_versions_amount_type_check check (amount_type in ('hourly', 'fixed')),
  constraint job_contract_versions_amount_check check (
    (amount_type = 'hourly' and hourly_rate_cents is not null and hourly_rate_cents >= 0 and maximum_approved_hours is not null and maximum_approved_hours > 0 and fixed_total_cents is null)
    or (amount_type = 'fixed' and fixed_total_cents is not null and fixed_total_cents >= 0 and hourly_rate_cents is null)
  ),
  constraint job_contract_versions_hash_check check (content_hash ~ '^[a-f0-9]{64}$')
);

alter table public.job_contracts
  add constraint job_contracts_active_version_fk
  foreign key (active_version_id) references public.job_contract_versions(id) on delete restrict;

create table public.job_contract_acceptances (
  id uuid primary key default gen_random_uuid(),
  contract_id uuid not null references public.job_contracts(id) on delete restrict,
  contract_version_id uuid not null references public.job_contract_versions(id) on delete restrict,
  user_id uuid not null references public.profiles(id) on delete restrict,
  party_role text not null,
  content_hash text not null,
  affirmative_checkbox boolean not null,
  confirmation_text text not null,
  platform text not null,
  app_version text not null,
  accepted_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (contract_version_id, user_id),
  constraint job_contract_acceptance_role_check check (party_role in ('teen', 'adult')),
  constraint job_contract_acceptance_affirmative_check check (affirmative_checkbox),
  constraint job_contract_acceptance_hash_check check (content_hash ~ '^[a-f0-9]{64}$')
);

create table public.job_contract_change_requests (
  id uuid primary key default gen_random_uuid(),
  contract_id uuid not null references public.job_contracts(id) on delete restrict,
  base_version_id uuid not null references public.job_contract_versions(id) on delete restrict,
  requested_by uuid not null references public.profiles(id) on delete restrict,
  change_categories text[] not null,
  proposed_terms jsonb not null,
  proposed_content_hash text not null,
  reason text not null,
  status text not null default 'pending_both_parties',
  requested_at timestamptz not null default now(),
  resolved_at timestamptz,
  created_version_id uuid references public.job_contract_versions(id) on delete restrict,
  constraint job_contract_change_categories_check check (cardinality(change_categories) > 0),
  constraint job_contract_change_hash_check check (proposed_content_hash ~ '^[a-f0-9]{64}$'),
  constraint job_contract_change_status_check check (status in ('pending_both_parties', 'accepted', 'declined', 'expired', 'cancelled'))
);

create table public.job_contract_change_acceptances (
  id uuid primary key default gen_random_uuid(),
  change_request_id uuid not null references public.job_contract_change_requests(id) on delete restrict,
  user_id uuid not null references public.profiles(id) on delete restrict,
  party_role text not null,
  accepted boolean not null,
  proposed_content_hash text not null,
  affirmative_checkbox boolean not null,
  responded_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (change_request_id, user_id),
  constraint job_contract_change_acceptance_role_check check (party_role in ('teen', 'adult')),
  constraint job_contract_change_acceptance_affirmative_check check ((accepted and affirmative_checkbox) or (not accepted and not affirmative_checkbox)),
  constraint job_contract_change_acceptance_hash_check check (proposed_content_hash ~ '^[a-f0-9]{64}$')
);

create table public.job_completion_assertions (
  id uuid primary key default gen_random_uuid(),
  contract_id uuid not null references public.job_contracts(id) on delete restrict,
  contract_version_id uuid not null references public.job_contract_versions(id) on delete restrict,
  asserted_by uuid not null references public.profiles(id) on delete restrict,
  assertion_role text not null,
  assertion_type text not null,
  task_checklist jsonb not null default '[]'::jsonb,
  start_timestamp timestamptz,
  completion_timestamp timestamptz not null,
  location_type_confirmation text,
  approved_scope_confirmation boolean not null,
  witness_notes text,
  statement text,
  created_at timestamptz not null default now(),
  constraint job_completion_role_check check (assertion_role in ('teen', 'adult')),
  constraint job_completion_type_check check (assertion_type in ('worker_completed', 'adult_acknowledged', 'adult_disagreed')),
  constraint job_completion_scope_check check (assertion_type = 'adult_disagreed' or approved_scope_confirmation)
);

create table public.job_payment_obligations (
  id uuid primary key default gen_random_uuid(),
  contract_id uuid not null references public.job_contracts(id) on delete restrict,
  contract_version_id uuid not null references public.job_contract_versions(id) on delete restrict,
  obligated_poster_id uuid not null references public.profiles(id) on delete restrict,
  worker_id uuid not null references public.profiles(id) on delete restrict,
  amount_cents integer not null,
  currency_code text not null default 'USD',
  payment_preference text not null,
  due_rule text not null,
  due_at timestamptz,
  status text not null default 'pending_completion',
  superseded_by_obligation_id uuid references public.job_payment_obligations(id) on delete restrict,
  created_at timestamptz not null default now(),
  became_due_at timestamptz,
  satisfied_at timestamptz,
  disputed_at timestamptz,
  unique (contract_version_id),
  constraint job_payment_obligation_amount_check check (amount_cents >= 0),
  constraint job_payment_obligation_party_check check (obligated_poster_id <> worker_id),
  constraint job_payment_obligation_status_check check (status in ('pending_completion', 'due', 'poster_marked_sent', 'worker_confirmed_received', 'disputed', 'superseded', 'waived_after_review'))
);

create table public.completion_evidence_records (
  id uuid primary key default gen_random_uuid(),
  contract_id uuid not null references public.job_contracts(id) on delete restrict,
  contract_version_id uuid not null references public.job_contract_versions(id) on delete restrict,
  submitted_by uuid not null references public.profiles(id) on delete restrict,
  evidence_type text not null,
  storage_object_id uuid references storage.objects(id) on delete restrict,
  proof_upload_id uuid references public.proof_uploads(id) on delete restrict,
  evidence_metadata jsonb not null default '{}'::jsonb,
  evidence_hash text,
  invasive_evidence_required boolean not null default false,
  preserved boolean not null default true,
  created_at timestamptz not null default now(),
  constraint completion_evidence_type_check check (evidence_type in ('before_photo', 'after_photo', 'work_product', 'task_checklist', 'arrival_handshake', 'timestamp', 'location_type', 'authorized_message', 'witness_note', 'approved_change_order', 'proof_decision')),
  constraint completion_evidence_hash_check check (evidence_hash is null or evidence_hash ~ '^[a-f0-9]{64}$'),
  constraint completion_evidence_noninvasive_check check (not invasive_evidence_required)
);

create table public.payment_confirmation_records (
  id uuid primary key default gen_random_uuid(),
  obligation_id uuid not null references public.job_payment_obligations(id) on delete restrict,
  confirmed_by uuid not null references public.profiles(id) on delete restrict,
  confirmer_role text not null,
  confirmation_type text not null,
  amount_cents integer not null,
  payment_reference text,
  occurred_at timestamptz not null,
  created_at timestamptz not null default now(),
  unique (obligation_id, confirmed_by, confirmation_type),
  constraint payment_confirmation_role_check check (confirmer_role in ('adult', 'teen')),
  constraint payment_confirmation_type_check check (confirmation_type in ('poster_marked_sent', 'worker_confirmed_received', 'worker_reports_not_received')),
  constraint payment_confirmation_amount_check check (amount_cents >= 0)
);

create table public.payment_disputes (
  id uuid primary key default gen_random_uuid(),
  obligation_id uuid not null unique references public.job_payment_obligations(id) on delete restrict,
  contract_id uuid not null references public.job_contracts(id) on delete restrict,
  opened_by uuid not null references public.profiles(id) on delete restrict,
  worker_id uuid not null references public.profiles(id) on delete restrict,
  poster_id uuid not null references public.profiles(id) on delete restrict,
  allegation_type text not null default 'reported_nonpayment',
  status text not null default 'open_private_review',
  guilt_determined boolean not null default false,
  classification_status text not null default 'classification_unknown',
  worker_statement text not null,
  poster_statement text,
  retaliation_review_active boolean not null default true,
  publication_paused boolean not null default true,
  opened_at timestamptz not null default now(),
  closed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint payment_dispute_party_check check (worker_id <> poster_id and opened_by in (worker_id, poster_id)),
  constraint payment_dispute_status_check check (status in ('open_private_review', 'awaiting_poster', 'awaiting_worker', 'mediation_review', 'appeal_pending', 'resolved_payment_recommended', 'resolved_partial_payment_recommended', 'resolved_more_evidence', 'resolved_no_platform_determination', 'closed_confirmed_paid')),
  constraint payment_dispute_no_guilt_check check (not guilt_determined),
  constraint payment_dispute_classification_check check (classification_status in ('classification_unknown', 'possible_employee_relationship', 'possible_independent_service_relationship', 'organization_program_role', 'requires_review'))
);

create table public.payment_dispute_assignments (
  id uuid primary key default gen_random_uuid(),
  dispute_id uuid not null references public.payment_disputes(id) on delete restrict,
  reviewer_id uuid not null references public.profiles(id) on delete restrict,
  assigned_by uuid not null references public.profiles(id) on delete restrict,
  purpose text not null,
  status text not null default 'active',
  assigned_at timestamptz not null default now(),
  expires_at timestamptz not null,
  completed_at timestamptz,
  unique (dispute_id, reviewer_id, status),
  constraint payment_dispute_assignment_status_check check (status in ('active', 'completed', 'revoked')),
  constraint payment_dispute_assignment_expiry_check check (expires_at > assigned_at)
);

create table public.payment_dispute_evidence (
  id uuid primary key default gen_random_uuid(),
  dispute_id uuid not null references public.payment_disputes(id) on delete restrict,
  submitted_by uuid not null references public.profiles(id) on delete restrict,
  evidence_type text not null,
  source_record_type text,
  source_record_id uuid,
  storage_object_id uuid references storage.objects(id) on delete restrict,
  description text,
  evidence_hash text,
  preserved boolean not null default true,
  created_at timestamptz not null default now(),
  constraint payment_dispute_evidence_hash_check check (evidence_hash is null or evidence_hash ~ '^[a-f0-9]{64}$')
);

create table public.payment_dispute_timeline (
  id bigint generated always as identity primary key,
  dispute_id uuid not null references public.payment_disputes(id) on delete restrict,
  actor_id uuid references public.profiles(id) on delete restrict,
  event_type text not null,
  event_summary text not null,
  private_metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table public.payment_dispute_decisions (
  id uuid primary key default gen_random_uuid(),
  dispute_id uuid not null references public.payment_disputes(id) on delete restrict,
  reviewer_id uuid not null references public.profiles(id) on delete restrict,
  decision_type text not null,
  rationale text not null,
  recommended_amount_cents integer,
  is_court_judgment boolean not null default false,
  is_criminal_finding boolean not null default false,
  appeal_available boolean not null default true,
  decided_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint payment_dispute_decision_type_check check (decision_type in ('recommend_payment', 'recommend_partial_payment', 'request_more_evidence', 'no_platform_determination', 'confirm_payment_received')),
  constraint payment_dispute_decision_boundary_check check (not is_court_judgment and not is_criminal_finding),
  constraint payment_dispute_decision_amount_check check (recommended_amount_cents is null or recommended_amount_cents >= 0)
);

create table public.poster_payment_restrictions (
  id uuid primary key default gen_random_uuid(),
  poster_id uuid not null references public.profiles(id) on delete restrict,
  dispute_id uuid not null references public.payment_disputes(id) on delete restrict,
  restriction_type text not null,
  status text not null default 'active',
  private_reason text not null,
  imposed_by uuid not null references public.profiles(id) on delete restrict,
  imposed_at timestamptz not null default now(),
  expires_at timestamptz,
  lifted_by uuid references public.profiles(id) on delete restrict,
  lifted_at timestamptz,
  appeal_status text not null default 'available',
  constraint poster_payment_restriction_type_check check (restriction_type in ('block_new_job_publication', 'block_new_application_acceptance', 'pause_repeat_worker_invites')),
  constraint poster_payment_restriction_status_check check (status in ('active', 'expired', 'lifted', 'overturned')),
  constraint poster_payment_restriction_appeal_check check (appeal_status in ('available', 'pending', 'upheld', 'overturned'))
);

create table public.jurisdiction_legal_resources (
  id uuid primary key default gen_random_uuid(),
  country_code text not null default 'US',
  region_code text not null,
  relationship_relevance text not null,
  resource_type text not null,
  title text not null,
  official_url text not null,
  status text not null default 'draft_legal_review',
  last_reviewed_at timestamptz,
  legal_review_reference text,
  active boolean not null default false,
  created_at timestamptz not null default now(),
  unique (country_code, region_code, relationship_relevance, resource_type, official_url),
  constraint jurisdiction_legal_resource_relationship_check check (relationship_relevance in ('classification_unknown', 'possible_employee_relationship', 'possible_independent_service_relationship', 'organization_program_role', 'requires_review')),
  constraint jurisdiction_legal_resource_type_check check (resource_type in ('wage_claim', 'small_claims', 'mediation', 'legal_aid', 'bar_referral', 'child_labor', 'emergency')),
  constraint jurisdiction_legal_resource_url_check check (official_url ~ '^https://'),
  constraint jurisdiction_legal_resource_status_check check (status in ('draft_legal_review', 'approved', 'retired')),
  constraint jurisdiction_legal_resource_publish_check check (not active or (status = 'approved' and last_reviewed_at is not null and legal_review_reference is not null))
);

create table public.payment_evidence_export_events (
  id uuid primary key default gen_random_uuid(),
  dispute_id uuid not null references public.payment_disputes(id) on delete restrict,
  requested_by uuid not null references public.profiles(id) on delete restrict,
  authorization_basis text not null,
  included_record_manifest jsonb not null,
  excluded_categories text[] not null,
  manifest_hash text not null,
  schema_version text not null default 'payment-evidence-export-v1',
  created_at timestamptz not null default now(),
  constraint payment_export_hash_check check (manifest_hash ~ '^[a-f0-9]{64}$')
);

create index legal_document_versions_document_status_idx on public.legal_document_versions(document_id, publication_status, effective_at desc);
create index legal_acceptances_user_document_idx on public.legal_acceptances(user_id, document_id, accepted_at desc);
create index legal_reacceptance_open_idx on public.legal_reacceptance_requirements(user_id, required_at) where satisfied_at is null and waived_at is null;
create index legal_acceptance_audit_user_idx on public.legal_acceptance_audit_events(user_id, occurred_at desc);
create index job_contracts_job_idx on public.job_contracts(job_id);
create index job_contracts_teen_idx on public.job_contracts(teen_id, created_at desc);
create index job_contracts_adult_idx on public.job_contracts(adult_id, created_at desc);
create index job_contract_versions_contract_idx on public.job_contract_versions(contract_id, version_number desc);
create index job_contract_acceptances_user_idx on public.job_contract_acceptances(user_id, accepted_at desc);
create index job_contract_change_requests_contract_idx on public.job_contract_change_requests(contract_id, requested_at desc);
create index job_completion_assertions_contract_idx on public.job_completion_assertions(contract_id, completion_timestamp desc);
create index job_payment_obligations_worker_idx on public.job_payment_obligations(worker_id, status, created_at desc);
create index job_payment_obligations_poster_idx on public.job_payment_obligations(obligated_poster_id, status, created_at desc);
create index completion_evidence_contract_idx on public.completion_evidence_records(contract_id, created_at desc);
create index payment_confirmations_obligation_idx on public.payment_confirmation_records(obligation_id, created_at desc);
create index payment_disputes_worker_idx on public.payment_disputes(worker_id, status, opened_at desc);
create index payment_disputes_poster_idx on public.payment_disputes(poster_id, status, opened_at desc);
create index payment_dispute_assignments_reviewer_idx on public.payment_dispute_assignments(reviewer_id, status, expires_at);
create index payment_dispute_evidence_dispute_idx on public.payment_dispute_evidence(dispute_id, created_at desc);
create index payment_dispute_timeline_dispute_idx on public.payment_dispute_timeline(dispute_id, created_at);
create index payment_dispute_decisions_dispute_idx on public.payment_dispute_decisions(dispute_id, decided_at desc);
create index poster_payment_restrictions_active_idx on public.poster_payment_restrictions(poster_id, restriction_type) where status = 'active';
create index payment_evidence_exports_requester_idx on public.payment_evidence_export_events(requested_by, created_at desc);
