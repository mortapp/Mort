-- Account deletion currently calls auth.admin.deleteUser() (a hard delete of
-- auth.users, cascading to public.profiles per profiles_id_fkey). 87 foreign
-- keys from safety, legal, financial, and audit tables to profiles/auth.users
-- were left at Postgres's implicit default of ON DELETE RESTRICT -- no
-- ON DELETE clause was ever specified for them, which is not a deliberate
-- retention design, it is what Postgres does when you omit the clause. That
-- default silently BLOCKS deleteUser() with a foreign-key violation the
-- moment a user has even one row in any of these tables.
--
-- The deletion worker's own summary message already documents the intended
-- behavior (supabase/functions/account-deletion-processor/index.ts):
-- "Legally required safety, fraud, and audit records may remain de-identified
-- under the retention matrix." This migration makes that the actual
-- database behavior: the record is kept (for legal/safety/financial
-- retention) but the link to the deleted person is severed.
--
-- This defect is invisible today only because the product has not launched
-- yet (zero legal acceptances, near-empty history tables as of 2026-08-29);
-- it would otherwise permanently fail every real user's account deletion the
-- moment they have any history in one of these 87 relationships. The
-- deletion worker already runs a financial-retention hold check
-- (service_check_account_deletion_financial_retention) before attempting the
-- hard delete, so by the time these constraints are evaluated, any live
-- financial exposure requiring a human decision should already have paused
-- the deletion -- this migration only affects records that are safe to
-- retain de-identified.

alter table account_ban_appeals drop constraint account_ban_appeals_user_id_fkey;
alter table account_ban_appeals alter column user_id drop not null;
alter table account_ban_appeals add constraint account_ban_appeals_user_id_fkey
  foreign key (user_id) references public.profiles(id) on delete set null;

alter table appearance_review_assignments drop constraint appearance_review_assignments_assigned_by_fkey;
alter table appearance_review_assignments alter column assigned_by drop not null;
alter table appearance_review_assignments add constraint appearance_review_assignments_assigned_by_fkey
  foreign key (assigned_by) references public.profiles(id) on delete set null;

alter table appearance_review_assignments drop constraint appearance_review_assignments_reviewer_id_fkey;
alter table appearance_review_assignments alter column reviewer_id drop not null;
alter table appearance_review_assignments add constraint appearance_review_assignments_reviewer_id_fkey
  foreign key (reviewer_id) references public.profiles(id) on delete set null;

alter table appearance_review_cases drop constraint appearance_review_cases_subject_user_id_fkey;
alter table appearance_review_cases alter column subject_user_id drop not null;
alter table appearance_review_cases add constraint appearance_review_cases_subject_user_id_fkey
  foreign key (subject_user_id) references public.profiles(id) on delete set null;

alter table appearance_review_decisions drop constraint appearance_review_decisions_reviewer_id_fkey;
alter table appearance_review_decisions alter column reviewer_id drop not null;
alter table appearance_review_decisions add constraint appearance_review_decisions_reviewer_id_fkey
  foreign key (reviewer_id) references public.profiles(id) on delete set null;

alter table completion_evidence_records drop constraint completion_evidence_records_submitted_by_fkey;
alter table completion_evidence_records alter column submitted_by drop not null;
alter table completion_evidence_records add constraint completion_evidence_records_submitted_by_fkey
  foreign key (submitted_by) references public.profiles(id) on delete set null;

alter table document_capture_sessions drop constraint document_capture_sessions_subject_user_id_fkey;
alter table document_capture_sessions alter column subject_user_id drop not null;
alter table document_capture_sessions add constraint document_capture_sessions_subject_user_id_fkey
  foreign key (subject_user_id) references public.profiles(id) on delete set null;

alter table document_review_assignments drop constraint document_review_assignments_assigned_by_fkey;
alter table document_review_assignments alter column assigned_by drop not null;
alter table document_review_assignments add constraint document_review_assignments_assigned_by_fkey
  foreign key (assigned_by) references public.profiles(id) on delete set null;

alter table document_review_assignments drop constraint document_review_assignments_reviewer_id_fkey;
alter table document_review_assignments alter column reviewer_id drop not null;
alter table document_review_assignments add constraint document_review_assignments_reviewer_id_fkey
  foreign key (reviewer_id) references public.profiles(id) on delete set null;

alter table document_review_decisions drop constraint document_review_decisions_reviewer_id_fkey;
alter table document_review_decisions alter column reviewer_id drop not null;
alter table document_review_decisions add constraint document_review_decisions_reviewer_id_fkey
  foreign key (reviewer_id) references public.profiles(id) on delete set null;

alter table document_web_reuse_requests drop constraint document_web_reuse_requests_subject_user_id_fkey;
alter table document_web_reuse_requests alter column subject_user_id drop not null;
alter table document_web_reuse_requests add constraint document_web_reuse_requests_subject_user_id_fkey
  foreign key (subject_user_id) references public.profiles(id) on delete set null;

alter table identity_verification_evidence drop constraint identity_verification_evidence_user_id_fkey;
alter table identity_verification_evidence alter column user_id drop not null;
alter table identity_verification_evidence add constraint identity_verification_evidence_user_id_fkey
  foreign key (user_id) references public.profiles(id) on delete set null;

alter table incident_actions drop constraint incident_actions_actor_id_fkey;
alter table incident_actions alter column actor_id drop not null;
alter table incident_actions add constraint incident_actions_actor_id_fkey
  foreign key (actor_id) references public.profiles(id) on delete set null;

alter table incident_assignments drop constraint incident_assignments_assigned_by_fkey;
alter table incident_assignments alter column assigned_by drop not null;
alter table incident_assignments add constraint incident_assignments_assigned_by_fkey
  foreign key (assigned_by) references public.profiles(id) on delete set null;

alter table incident_assignments drop constraint incident_assignments_assigned_to_fkey;
alter table incident_assignments alter column assigned_to drop not null;
alter table incident_assignments add constraint incident_assignments_assigned_to_fkey
  foreign key (assigned_to) references public.profiles(id) on delete set null;

alter table incident_contact_attempts drop constraint incident_contact_attempts_actor_id_fkey;
alter table incident_contact_attempts alter column actor_id drop not null;
alter table incident_contact_attempts add constraint incident_contact_attempts_actor_id_fkey
  foreign key (actor_id) references public.profiles(id) on delete set null;

alter table incident_outcomes drop constraint incident_outcomes_decided_by_fkey;
alter table incident_outcomes alter column decided_by drop not null;
alter table incident_outcomes add constraint incident_outcomes_decided_by_fkey
  foreign key (decided_by) references public.profiles(id) on delete set null;

alter table incident_preservation_orders drop constraint incident_preservation_orders_ordered_by_fkey;
alter table incident_preservation_orders alter column ordered_by drop not null;
alter table incident_preservation_orders add constraint incident_preservation_orders_ordered_by_fkey
  foreign key (ordered_by) references public.profiles(id) on delete set null;

alter table job_arrival_handshakes drop constraint job_arrival_handshakes_finish_confirmed_by_fkey;
alter table job_arrival_handshakes add constraint job_arrival_handshakes_finish_confirmed_by_fkey
  foreign key (finish_confirmed_by) references public.profiles(id) on delete set null;

alter table job_arrival_handshakes drop constraint job_arrival_handshakes_finish_requested_by_fkey;
alter table job_arrival_handshakes add constraint job_arrival_handshakes_finish_requested_by_fkey
  foreign key (finish_requested_by) references public.profiles(id) on delete set null;

alter table job_arrival_handshakes drop constraint job_arrival_handshakes_start_confirmed_by_fkey;
alter table job_arrival_handshakes add constraint job_arrival_handshakes_start_confirmed_by_fkey
  foreign key (start_confirmed_by) references public.profiles(id) on delete set null;

alter table job_completion_assertions drop constraint job_completion_assertions_asserted_by_fkey;
alter table job_completion_assertions alter column asserted_by drop not null;
alter table job_completion_assertions add constraint job_completion_assertions_asserted_by_fkey
  foreign key (asserted_by) references public.profiles(id) on delete set null;

alter table job_contract_acceptances drop constraint job_contract_acceptances_user_id_fkey;
alter table job_contract_acceptances alter column user_id drop not null;
alter table job_contract_acceptances add constraint job_contract_acceptances_user_id_fkey
  foreign key (user_id) references public.profiles(id) on delete set null;

alter table job_contract_change_acceptances drop constraint job_contract_change_acceptances_user_id_fkey;
alter table job_contract_change_acceptances alter column user_id drop not null;
alter table job_contract_change_acceptances add constraint job_contract_change_acceptances_user_id_fkey
  foreign key (user_id) references public.profiles(id) on delete set null;

alter table job_contract_change_requests drop constraint job_contract_change_requests_requested_by_fkey;
alter table job_contract_change_requests alter column requested_by drop not null;
alter table job_contract_change_requests add constraint job_contract_change_requests_requested_by_fkey
  foreign key (requested_by) references public.profiles(id) on delete set null;

alter table job_contract_versions drop constraint job_contract_versions_created_by_fkey;
alter table job_contract_versions add constraint job_contract_versions_created_by_fkey
  foreign key (created_by) references public.profiles(id) on delete set null;

alter table job_contracts drop constraint job_contracts_adult_id_fkey;
alter table job_contracts alter column adult_id drop not null;
alter table job_contracts add constraint job_contracts_adult_id_fkey
  foreign key (adult_id) references public.profiles(id) on delete set null;

alter table job_contracts drop constraint job_contracts_teen_id_fkey;
alter table job_contracts alter column teen_id drop not null;
alter table job_contracts add constraint job_contracts_teen_id_fkey
  foreign key (teen_id) references public.profiles(id) on delete set null;

alter table job_execution_cancellations drop constraint job_execution_cancellations_actor_id_fkey;
alter table job_execution_cancellations alter column actor_id drop not null;
alter table job_execution_cancellations add constraint job_execution_cancellations_actor_id_fkey
  foreign key (actor_id) references public.profiles(id) on delete set null;

alter table job_payment_obligations drop constraint job_payment_obligations_obligated_poster_id_fkey;
alter table job_payment_obligations alter column obligated_poster_id drop not null;
alter table job_payment_obligations add constraint job_payment_obligations_obligated_poster_id_fkey
  foreign key (obligated_poster_id) references public.profiles(id) on delete set null;

alter table job_payment_obligations drop constraint job_payment_obligations_worker_id_fkey;
alter table job_payment_obligations alter column worker_id drop not null;
alter table job_payment_obligations add constraint job_payment_obligations_worker_id_fkey
  foreign key (worker_id) references public.profiles(id) on delete set null;

alter table legal_acceptance_audit_events drop constraint legal_acceptance_audit_events_user_id_fkey;
alter table legal_acceptance_audit_events alter column user_id drop not null;
alter table legal_acceptance_audit_events add constraint legal_acceptance_audit_events_user_id_fkey
  foreign key (user_id) references public.profiles(id) on delete set null;

alter table legal_acceptances drop constraint legal_acceptances_user_id_fkey;
alter table legal_acceptances alter column user_id drop not null;
alter table legal_acceptances add constraint legal_acceptances_user_id_fkey
  foreign key (user_id) references public.profiles(id) on delete set null;

alter table legal_declines drop constraint legal_declines_user_id_fkey;
alter table legal_declines alter column user_id drop not null;
alter table legal_declines add constraint legal_declines_user_id_fkey
  foreign key (user_id) references public.profiles(id) on delete set null;

alter table legal_reacceptance_requirements drop constraint legal_reacceptance_requirements_user_id_fkey;
alter table legal_reacceptance_requirements alter column user_id drop not null;
alter table legal_reacceptance_requirements add constraint legal_reacceptance_requirements_user_id_fkey
  foreign key (user_id) references public.profiles(id) on delete set null;

alter table live_presence_challenges drop constraint live_presence_challenges_subject_user_id_fkey;
alter table live_presence_challenges alter column subject_user_id drop not null;
alter table live_presence_challenges add constraint live_presence_challenges_subject_user_id_fkey
  foreign key (subject_user_id) references public.profiles(id) on delete set null;

alter table message_safety_evidence drop constraint message_safety_evidence_sender_id_fkey;
alter table message_safety_evidence alter column sender_id drop not null;
alter table message_safety_evidence add constraint message_safety_evidence_sender_id_fkey
  foreign key (sender_id) references public.profiles(id) on delete set null;

alter table partner_invite_codes drop constraint partner_invite_codes_created_by_fkey;
alter table partner_invite_codes alter column created_by drop not null;
alter table partner_invite_codes add constraint partner_invite_codes_created_by_fkey
  foreign key (created_by) references public.profiles(id) on delete set null;

alter table partner_permissions drop constraint partner_permissions_granted_by_fkey;
alter table partner_permissions alter column granted_by drop not null;
alter table partner_permissions add constraint partner_permissions_granted_by_fkey
  foreign key (granted_by) references public.profiles(id) on delete set null;

alter table payment_confirmation_records drop constraint payment_confirmation_records_confirmed_by_fkey;
alter table payment_confirmation_records alter column confirmed_by drop not null;
alter table payment_confirmation_records add constraint payment_confirmation_records_confirmed_by_fkey
  foreign key (confirmed_by) references public.profiles(id) on delete set null;

alter table payment_dispute_appeals drop constraint payment_dispute_appeals_appellant_id_fkey;
alter table payment_dispute_appeals alter column appellant_id drop not null;
alter table payment_dispute_appeals add constraint payment_dispute_appeals_appellant_id_fkey
  foreign key (appellant_id) references public.profiles(id) on delete set null;

alter table payment_dispute_appeals drop constraint payment_dispute_appeals_reviewed_by_fkey;
alter table payment_dispute_appeals add constraint payment_dispute_appeals_reviewed_by_fkey
  foreign key (reviewed_by) references public.profiles(id) on delete set null;

alter table payment_dispute_assignments drop constraint payment_dispute_assignments_assigned_by_fkey;
alter table payment_dispute_assignments alter column assigned_by drop not null;
alter table payment_dispute_assignments add constraint payment_dispute_assignments_assigned_by_fkey
  foreign key (assigned_by) references public.profiles(id) on delete set null;

alter table payment_dispute_assignments drop constraint payment_dispute_assignments_reviewer_id_fkey;
alter table payment_dispute_assignments alter column reviewer_id drop not null;
alter table payment_dispute_assignments add constraint payment_dispute_assignments_reviewer_id_fkey
  foreign key (reviewer_id) references public.profiles(id) on delete set null;

alter table payment_dispute_decisions drop constraint payment_dispute_decisions_reviewer_id_fkey;
alter table payment_dispute_decisions alter column reviewer_id drop not null;
alter table payment_dispute_decisions add constraint payment_dispute_decisions_reviewer_id_fkey
  foreign key (reviewer_id) references public.profiles(id) on delete set null;

alter table payment_dispute_evidence drop constraint payment_dispute_evidence_submitted_by_fkey;
alter table payment_dispute_evidence alter column submitted_by drop not null;
alter table payment_dispute_evidence add constraint payment_dispute_evidence_submitted_by_fkey
  foreign key (submitted_by) references public.profiles(id) on delete set null;

alter table payment_dispute_statements drop constraint payment_dispute_statements_author_id_fkey;
alter table payment_dispute_statements alter column author_id drop not null;
alter table payment_dispute_statements add constraint payment_dispute_statements_author_id_fkey
  foreign key (author_id) references public.profiles(id) on delete set null;

alter table payment_dispute_timeline drop constraint payment_dispute_timeline_actor_id_fkey;
alter table payment_dispute_timeline add constraint payment_dispute_timeline_actor_id_fkey
  foreign key (actor_id) references public.profiles(id) on delete set null;

alter table payment_disputes drop constraint payment_disputes_opened_by_fkey;
alter table payment_disputes alter column opened_by drop not null;
alter table payment_disputes add constraint payment_disputes_opened_by_fkey
  foreign key (opened_by) references public.profiles(id) on delete set null;

alter table payment_disputes drop constraint payment_disputes_poster_id_fkey;
alter table payment_disputes alter column poster_id drop not null;
alter table payment_disputes add constraint payment_disputes_poster_id_fkey
  foreign key (poster_id) references public.profiles(id) on delete set null;

alter table payment_disputes drop constraint payment_disputes_worker_id_fkey;
alter table payment_disputes alter column worker_id drop not null;
alter table payment_disputes add constraint payment_disputes_worker_id_fkey
  foreign key (worker_id) references public.profiles(id) on delete set null;

alter table payment_evidence_export_events drop constraint payment_evidence_export_events_requested_by_fkey;
alter table payment_evidence_export_events alter column requested_by drop not null;
alter table payment_evidence_export_events add constraint payment_evidence_export_events_requested_by_fkey
  foreign key (requested_by) references public.profiles(id) on delete set null;

alter table poster_payment_restrictions drop constraint poster_payment_restrictions_imposed_by_fkey;
alter table poster_payment_restrictions alter column imposed_by drop not null;
alter table poster_payment_restrictions add constraint poster_payment_restrictions_imposed_by_fkey
  foreign key (imposed_by) references public.profiles(id) on delete set null;

alter table poster_payment_restrictions drop constraint poster_payment_restrictions_lifted_by_fkey;
alter table poster_payment_restrictions add constraint poster_payment_restrictions_lifted_by_fkey
  foreign key (lifted_by) references public.profiles(id) on delete set null;

alter table poster_payment_restrictions drop constraint poster_payment_restrictions_poster_id_fkey;
alter table poster_payment_restrictions alter column poster_id drop not null;
alter table poster_payment_restrictions add constraint poster_payment_restrictions_poster_id_fkey
  foreign key (poster_id) references public.profiles(id) on delete set null;

alter table private.document_vault_access_grants drop constraint document_vault_access_grants_reviewer_id_fkey;
alter table private.document_vault_access_grants alter column reviewer_id drop not null;
alter table private.document_vault_access_grants add constraint document_vault_access_grants_reviewer_id_fkey
  foreign key (reviewer_id) references public.profiles(id) on delete set null;

alter table private.first_party_trust_control drop constraint first_party_trust_control_enabled_by_fkey;
alter table private.first_party_trust_control add constraint first_party_trust_control_enabled_by_fkey
  foreign key (enabled_by) references public.profiles(id) on delete set null;

alter table private.identity_verification_webhook_events drop constraint identity_verification_webhook_events_user_id_fkey;
alter table private.identity_verification_webhook_events add constraint identity_verification_webhook_events_user_id_fkey
  foreign key (user_id) references public.profiles(id) on delete set null;

alter table private.stripe_account_onboarding_sessions drop constraint stripe_account_onboarding_sessions_user_id_fkey;
alter table private.stripe_account_onboarding_sessions alter column user_id drop not null;
alter table private.stripe_account_onboarding_sessions add constraint stripe_account_onboarding_sessions_user_id_fkey
  foreign key (user_id) references auth.users(id) on delete set null;

alter table private.stripe_connected_accounts drop constraint stripe_connected_accounts_user_id_fkey;
alter table private.stripe_connected_accounts alter column user_id drop not null;
alter table private.stripe_connected_accounts add constraint stripe_connected_accounts_user_id_fkey
  foreign key (user_id) references auth.users(id) on delete set null;

alter table private.stripe_customers drop constraint stripe_customers_user_id_fkey;
alter table private.stripe_customers alter column user_id drop not null;
alter table private.stripe_customers add constraint stripe_customers_user_id_fkey
  foreign key (user_id) references auth.users(id) on delete set null;

alter table private.stripe_financial_role_assignments drop constraint stripe_financial_role_assignments_assigned_by_fkey;
alter table private.stripe_financial_role_assignments alter column assigned_by drop not null;
alter table private.stripe_financial_role_assignments add constraint stripe_financial_role_assignments_assigned_by_fkey
  foreign key (assigned_by) references auth.users(id) on delete set null;

alter table private.stripe_job_payment_attempts drop constraint stripe_job_payment_attempts_initiated_by_fkey;
alter table private.stripe_job_payment_attempts alter column initiated_by drop not null;
alter table private.stripe_job_payment_attempts add constraint stripe_job_payment_attempts_initiated_by_fkey
  foreign key (initiated_by) references auth.users(id) on delete set null;

alter table private.stripe_job_payment_intents drop constraint stripe_job_payment_intents_adult_id_fkey;
alter table private.stripe_job_payment_intents alter column adult_id drop not null;
alter table private.stripe_job_payment_intents add constraint stripe_job_payment_intents_adult_id_fkey
  foreign key (adult_id) references auth.users(id) on delete set null;

alter table private.stripe_job_payment_intents drop constraint stripe_job_payment_intents_teen_id_fkey;
alter table private.stripe_job_payment_intents alter column teen_id drop not null;
alter table private.stripe_job_payment_intents add constraint stripe_job_payment_intents_teen_id_fkey
  foreign key (teen_id) references auth.users(id) on delete set null;

alter table private.stripe_payment_resolutions drop constraint stripe_payment_resolutions_financial_operator_id_fkey;
alter table private.stripe_payment_resolutions add constraint stripe_payment_resolutions_financial_operator_id_fkey
  foreign key (financial_operator_id) references auth.users(id) on delete set null;

alter table private.stripe_payment_resolutions drop constraint stripe_payment_resolutions_reviewer_id_fkey;
alter table private.stripe_payment_resolutions add constraint stripe_payment_resolutions_reviewer_id_fkey
  foreign key (reviewer_id) references auth.users(id) on delete set null;

alter table private.support_staff_assignments drop constraint support_staff_assignments_assigned_by_fkey;
alter table private.support_staff_assignments alter column assigned_by drop not null;
alter table private.support_staff_assignments add constraint support_staff_assignments_assigned_by_fkey
  foreign key (assigned_by) references auth.users(id) on delete set null;

alter table safety_cancellations drop constraint safety_cancellations_actor_id_fkey;
alter table safety_cancellations alter column actor_id drop not null;
alter table safety_cancellations add constraint safety_cancellations_actor_id_fkey
  foreign key (actor_id) references public.profiles(id) on delete set null;

alter table support_attachments drop constraint support_attachments_owner_id_fkey;
alter table support_attachments alter column owner_id drop not null;
alter table support_attachments add constraint support_attachments_owner_id_fkey
  foreign key (owner_id) references public.profiles(id) on delete set null;

alter table support_evidence_attachments drop constraint support_evidence_attachments_owner_id_fkey;
alter table support_evidence_attachments alter column owner_id drop not null;
alter table support_evidence_attachments add constraint support_evidence_attachments_owner_id_fkey
  foreign key (owner_id) references public.profiles(id) on delete set null;

alter table support_internal_notes drop constraint support_internal_notes_author_id_fkey;
alter table support_internal_notes alter column author_id drop not null;
alter table support_internal_notes add constraint support_internal_notes_author_id_fkey
  foreign key (author_id) references public.profiles(id) on delete set null;

alter table support_ticket_appeals drop constraint support_ticket_appeals_requester_id_fkey;
alter table support_ticket_appeals alter column requester_id drop not null;
alter table support_ticket_appeals add constraint support_ticket_appeals_requester_id_fkey
  foreign key (requester_id) references public.profiles(id) on delete set null;

alter table team_access_audit_events drop constraint team_access_audit_events_user_id_fkey;
alter table team_access_audit_events alter column user_id drop not null;
alter table team_access_audit_events add constraint team_access_audit_events_user_id_fkey
  foreign key (user_id) references public.profiles(id) on delete set null;

alter table team_confidentiality_acknowledgements drop constraint team_confidentiality_acknowledgements_user_id_fkey;
alter table team_confidentiality_acknowledgements alter column user_id drop not null;
alter table team_confidentiality_acknowledgements add constraint team_confidentiality_acknowledgements_user_id_fkey
  foreign key (user_id) references public.profiles(id) on delete set null;

alter table team_conflict_disclosures drop constraint team_conflict_disclosures_reviewed_by_fkey;
alter table team_conflict_disclosures add constraint team_conflict_disclosures_reviewed_by_fkey
  foreign key (reviewed_by) references public.profiles(id) on delete set null;

alter table team_conflict_disclosures drop constraint team_conflict_disclosures_user_id_fkey;
alter table team_conflict_disclosures alter column user_id drop not null;
alter table team_conflict_disclosures add constraint team_conflict_disclosures_user_id_fkey
  foreign key (user_id) references public.profiles(id) on delete set null;

alter table team_device_compliance drop constraint team_device_compliance_reviewed_by_fkey;
alter table team_device_compliance add constraint team_device_compliance_reviewed_by_fkey
  foreign key (reviewed_by) references public.profiles(id) on delete set null;

alter table team_device_compliance drop constraint team_device_compliance_user_id_fkey;
alter table team_device_compliance alter column user_id drop not null;
alter table team_device_compliance add constraint team_device_compliance_user_id_fkey
  foreign key (user_id) references public.profiles(id) on delete set null;

alter table team_role_assignments drop constraint team_role_assignments_approved_by_fkey;
alter table team_role_assignments add constraint team_role_assignments_approved_by_fkey
  foreign key (approved_by) references public.profiles(id) on delete set null;

alter table team_role_assignments drop constraint team_role_assignments_revoked_by_fkey;
alter table team_role_assignments add constraint team_role_assignments_revoked_by_fkey
  foreign key (revoked_by) references public.profiles(id) on delete set null;

alter table team_role_assignments drop constraint team_role_assignments_user_id_fkey;
alter table team_role_assignments alter column user_id drop not null;
alter table team_role_assignments add constraint team_role_assignments_user_id_fkey
  foreign key (user_id) references public.profiles(id) on delete set null;

alter table team_training_completions drop constraint team_training_completions_approved_by_fkey;
alter table team_training_completions add constraint team_training_completions_approved_by_fkey
  foreign key (approved_by) references public.profiles(id) on delete set null;

alter table team_training_completions drop constraint team_training_completions_user_id_fkey;
alter table team_training_completions alter column user_id drop not null;
alter table team_training_completions add constraint team_training_completions_user_id_fkey
  foreign key (user_id) references public.profiles(id) on delete set null;

alter table teen_abandonment_reports drop constraint teen_abandonment_reports_decided_by_fkey;
alter table teen_abandonment_reports add constraint teen_abandonment_reports_decided_by_fkey
  foreign key (decided_by) references public.profiles(id) on delete set null;

alter table teen_abandonment_reports drop constraint teen_abandonment_reports_reported_by_adult_id_fkey;
alter table teen_abandonment_reports add constraint teen_abandonment_reports_reported_by_adult_id_fkey
  foreign key (reported_by_adult_id) references public.profiles(id) on delete set null;

alter table teen_abandonment_reports drop constraint teen_abandonment_reports_teen_id_fkey;
alter table teen_abandonment_reports alter column teen_id drop not null;
alter table teen_abandonment_reports add constraint teen_abandonment_reports_teen_id_fkey
  foreign key (teen_id) references public.profiles(id) on delete set null;
