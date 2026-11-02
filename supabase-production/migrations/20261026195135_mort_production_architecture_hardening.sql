
-- MORT production architecture hardening: fail closed until trusted workflow RPCs exist.
-- No data is deleted; current production tables were verified empty before this migration.

-- Prevent clients from adding themselves to arbitrary conversations or mutating membership records.
drop policy if exists members_insert_self on public.conversation_members;
revoke insert, update, delete on public.conversation_members from anon, authenticated;
grant select on public.conversation_members to authenticated;
grant update (last_read_at, muted_at) on public.conversation_members to authenticated;

-- Direct conversation creation is unsafe without an atomic, validated membership workflow.
drop policy if exists conversations_insert_authenticated on public.conversations;
revoke insert, update, delete on public.conversations from anon, authenticated;

-- Application status/identity/job association must be changed only by a trusted workflow.
drop policy if exists applications_update_parties on public.job_applications;
revoke update, delete on public.job_applications from anon, authenticated;

-- Guardian consent timestamps and relationship status must not be self-asserted by either participant.
drop policy if exists guardian_links_update_participant on public.guardian_links;
revoke update, delete on public.guardian_links from anon, authenticated;

-- Evidence metadata must be written by a trusted upload workflow that verifies the object path,
-- assignment/report/dispute linkage, MIME type, size and uploader authorization.
drop policy if exists evidence_insert_self on public.evidence_files;
revoke insert, update, delete on public.evidence_files from anon, authenticated;

-- Audit events must be server-written, not client-authored.
drop policy if exists audit_insert_staff on public.admin_audit_log;
revoke insert, update, delete on public.admin_audit_log from anon, authenticated;

-- Do not let a client approve/publish a job by changing safety_review_status.
revoke update on public.jobs from anon, authenticated;
grant update (
  title, description, category, pay_type, pay_amount, estimated_minutes,
  city, region, location_notes, exact_address, age_min, age_max,
  remote_allowed, starts_at, ends_at, status
) on public.jobs to authenticated;

-- Restrict profile edits to non-sensitive profile fields; identity, role, account status,
-- date of birth and onboarding status are trusted-workflow controlled.
revoke update on public.profiles from anon, authenticated;
grant update (display_name, avatar_path, bio, city, region, timezone)
  on public.profiles to authenticated;

-- Consent records are append-only from clients and cannot forge source or timestamps.
revoke insert, update, delete on public.consents from anon, authenticated;
grant insert (user_id, consent_type, document_version, granted)
  on public.consents to authenticated;

-- Notification clients may only mark their own notification read; all payload fields are server-owned.
revoke update on public.notifications from anon, authenticated;
grant update (read_at) on public.notifications to authenticated;

-- Block clients from changing moderation results or message content after submission.
revoke update, delete on public.messages from anon, authenticated;

-- Role request review outcomes are exclusively server/staff workflow controlled.
revoke update, delete on public.role_requests from anon, authenticated;

-- Verification outcomes/evidence/reviewer fields remain trusted-workflow controlled.
revoke update, delete on public.verification_cases from anon, authenticated;

-- Report assignment/resolution and moderation state are trusted-workflow controlled.
revoke update, delete on public.safety_reports from anon, authenticated;

-- Payment rows are server-owned, including status and provider identifiers.
revoke insert, update, delete on public.payment_records from anon, authenticated;

-- Staff role registry must never be directly accessible to API roles.
revoke all on schema private from anon, authenticated;
grant usage on schema private to authenticated;
revoke all on table private.user_roles from anon, authenticated;

-- Force row-level security on all client-exposed public tables as defense in depth.
alter table public.profiles force row level security;
alter table public.role_requests force row level security;
alter table public.guardian_links force row level security;
alter table public.verification_cases force row level security;
alter table public.jobs force row level security;
alter table public.job_applications force row level security;
alter table public.job_assignments force row level security;
alter table public.conversations force row level security;
alter table public.conversation_members force row level security;
alter table public.user_blocks force row level security;
alter table public.messages force row level security;
alter table public.safety_reports force row level security;
alter table public.disputes force row level security;
alter table public.evidence_files force row level security;
alter table public.payment_records force row level security;
alter table public.notification_preferences force row level security;
alter table public.notifications force row level security;
alter table public.consents force row level security;
alter table public.admin_audit_log force row level security;

-- Cover FK joins and frequent owner/participant lookups for production growth.
create index if not exists idx_user_roles_granted_by on private.user_roles(granted_by);
create index if not exists idx_admin_audit_actor on public.admin_audit_log(actor_id);
create index if not exists idx_consents_user on public.consents(user_id);
create index if not exists idx_conversations_assignment on public.conversations(assignment_id);
create index if not exists idx_conversations_job on public.conversations(job_id);
create index if not exists idx_disputes_assignment on public.disputes(assignment_id);
create index if not exists idx_disputes_opened_by on public.disputes(opened_by);
create index if not exists idx_disputes_assigned_to on public.disputes(assigned_to);
create index if not exists idx_evidence_dispute on public.evidence_files(dispute_id);
create index if not exists idx_evidence_report on public.evidence_files(report_id);
create index if not exists idx_evidence_uploader on public.evidence_files(uploaded_by);
create index if not exists idx_guardian_links_guardian on public.guardian_links(guardian_user_id);
create index if not exists idx_guardian_links_initiator on public.guardian_links(initiated_by);
create index if not exists idx_messages_sender on public.messages(sender_id);
create index if not exists idx_payments_assignment on public.payment_records(assignment_id);
create index if not exists idx_payments_payee on public.payment_records(payee_id);
create index if not exists idx_payments_payer on public.payment_records(payer_id);
create index if not exists idx_role_requests_reviewer on public.role_requests(reviewed_by);
create index if not exists idx_safety_reports_assigned on public.safety_reports(assigned_to);
create index if not exists idx_safety_reports_job on public.safety_reports(job_id);
create index if not exists idx_safety_reports_message on public.safety_reports(message_id);
create index if not exists idx_safety_reports_reported_user on public.safety_reports(reported_user_id);
create index if not exists idx_safety_reports_reporter on public.safety_reports(reporter_id);
create index if not exists idx_user_blocks_blocked on public.user_blocks(blocked_id);
create index if not exists idx_verification_reviewer on public.verification_cases(reviewer_id);
create index if not exists idx_verification_user on public.verification_cases(user_id);
