create index if not exists account_trust_appeals_reviewer_idx
  on public.account_trust_appeals (reviewer_id);
create index if not exists account_trust_appeals_signal_idx
  on public.account_trust_appeals (signal_id);
create index if not exists account_trust_appeals_user_idx
  on public.account_trust_appeals (user_id);

create index if not exists business_registry_checks_reviewer_idx
  on public.business_registry_checks (reviewed_by);
create index if not exists business_representative_claims_check_idx
  on public.business_representative_claims (business_registry_check_id);
create index if not exists business_representative_claims_reviewer_idx
  on public.business_representative_claims (reviewed_by);

create index if not exists digital_credential_events_session_idx
  on public.digital_credential_events (session_id);
create index if not exists digital_credential_sessions_user_idx
  on public.digital_credential_sessions (user_id);

create index if not exists partner_audit_events_actor_idx
  on public.partner_audit_events (actor_id);
create index if not exists partner_domains_approver_idx
  on public.partner_domains (approved_by);
create index if not exists partner_invite_codes_creator_idx
  on public.partner_invite_codes (created_by);
create index if not exists partner_invite_codes_program_idx
  on public.partner_invite_codes (program_id);
create index if not exists partner_memberships_organization_idx
  on public.partner_memberships (organization_id);
create index if not exists partner_memberships_program_idx
  on public.partner_memberships (program_id);
create index if not exists partner_organizations_verifier_idx
  on public.partner_organizations (verified_by);
create index if not exists partner_programs_organization_idx
  on public.partner_programs (organization_id);
create index if not exists partner_verification_requests_organization_idx
  on public.partner_verification_requests (organization_id);
create index if not exists partner_verification_requests_program_idx
  on public.partner_verification_requests (program_id);
create index if not exists partner_verification_requests_reviewer_idx
  on public.partner_verification_requests (reviewer_id);
create index if not exists partner_verification_requests_user_idx
  on public.partner_verification_requests (user_id);

create index if not exists school_domains_approver_idx
  on public.school_domains (approved_by);
create index if not exists sensitive_action_reauth_events_user_idx
  on public.sensitive_action_reauth_events (user_id);
create index if not exists trust_signal_events_creator_idx
  on public.trust_signal_events (created_by);
