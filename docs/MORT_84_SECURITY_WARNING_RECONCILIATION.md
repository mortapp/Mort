# MORT 84 Security Warning Reconciliation

Generated from the hosted PostgreSQL catalog for project `rakjydmgwwgtdislanbt` on 2026-07-18T07:12:37.772Z. No secret values are included.

## Result

The pre-foundation baseline had 84 WARN findings: 82 authenticated SECURITY DEFINER findings, one anonymous SECURITY DEFINER finding, and one Auth leaked-password finding. After the multi-signal trust migration, the current live advisor has 100 WARN and 4 INFO findings. The anonymous grant remains fixed; 99 authenticated function findings are intentional checked RPC surfaces. There are no ERROR findings.

- Authenticated SECURITY DEFINER findings: 99
- Anonymous SECURITY DEFINER findings: 0
- Auth leaked-password finding: 1
- RLS-with-no-policy INFO findings: 4 (`private.trust_policy_versions`, `public.job_arrival_handshakes`, `public.job_location_share_sessions`, `public.job_private_locations`)
- Current warning status: 100 WARN, 4 INFO, 0 ERROR

The four no-policy tables are intentionally deny-by-default private policy/location/arrival state tables. RLS is enabled and no Data API role receives a permissive policy. Their INFO status is acceptable while access remains exclusively through checked RPCs.

## Multi-Signal Trust Addendum

The trust migration added 17 net authenticated SECURITY DEFINER findings and redefined one previously counted badge function. The affected caller-bound or specialized-role-bound functions are: `get_marketplace_trust_eligibility`, `get_my_account_trust_profile`, `get_public_trust_badges`, `update_account_security_preferences`, `set_trust_signal_visibility`, `submit_account_trust_appeal`, `request_school_email_affiliation`, `redeem_partner_invite_code`, `request_business_registry_match`, `request_business_representative_claim`, `admin_review_school_domain`, `admin_create_partner_organization`, `admin_review_partner_organization`, `admin_create_partner_invite_code`, `admin_review_business_registry_match`, `admin_review_business_representative_claim`, `admin_review_account_trust_appeal`, and `get_admin_trust_review_queue`.

These functions require definer rights to make atomic decisions across tables that remain directly non-writable. They use `SET search_path = ''`, schema-qualified names, `auth.uid()` actor binding, specialized admin roles where applicable, environment isolation, reason/case audit requirements, and explicit authenticated/service grants. `anon` can execute none. The service-only digital credential and reauthentication functions do not appear as authenticated findings. Full details are in `MORT_MULTI_SIGNAL_TRUST_ADVISOR_REPORT.md` and the hosted forgery/isolation QA.

## Auth Plan Limitation

The leaked-password finding is **DEFERRED - PLAN-LIMITED SECURITY ENHANCEMENT**. Supabase Free cannot enable the HaveIBeenPwned control. This is not an unresolved MORT application-code security bug, and no paid upgrade was authorized.

Current mitigations: strong password minimum length, required password complexity, Auth rate limiting, email verification, RLS, account restriction logic, and a secure password reset flow.

> When Supabase is upgraded to Pro, enable leaked-password protection immediately and rerun Auth security advisors.

## Function Findings

### 1. `public.accept_guardian_invite(p_invite_code text)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `202607070001_initial_mort.sql`
- Why SECURITY DEFINER is required: Performs an atomic relationship workflow across rows that are not broadly exposed through RLS.
- Explicit search_path: `search_path=public, extensions, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Checks the authenticated relationship owner/participant (or an authorized admin) before mutation or disclosure.
- Client-controlled identifier review: No client UUID is used as an acting identity.
- Test coverage: optional Guardian Mode; Safety Circle permissions; complete multi-user isolation.
- Risk classification: MEDIUM state-changing surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 2. `public.accept_safety_circle_invite(p_invite_code text)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260717161132_mutual_trust_real_world_safety.sql`
- Why SECURITY DEFINER is required: Performs an atomic relationship workflow across rows that are not broadly exposed through RLS.
- Explicit search_path: `search_path=public, extensions, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Checks the authenticated relationship owner/participant (or an authorized admin) before mutation or disclosure.
- Client-controlled identifier review: No client UUID is used as an acting identity.
- Test coverage: optional Guardian Mode; Safety Circle permissions; complete multi-user isolation.
- Risk classification: MEDIUM state-changing surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 3. `public.admin_grant_username_change_credit(p_user_id uuid, p_credit_count integer, p_reason text)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260708163330_add_voluntary_paywall_perks.sql`
- Why SECURITY DEFINER is required: Performs an audited privileged workflow across restricted rows after an in-function role check.
- Explicit search_path: `search_path=public` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Requires the applicable admin, restricted safety, or trained-reviewer role; the acting identity is never accepted as an argument.
- Client-controlled identifier review: User UUIDs are targets only. The acting identity comes from `auth.uid()` and ownership/role checks are reapplied.
- Test coverage: existing monetization/username QA plus complete multi-user isolation.
- Risk classification: HIGH surface, fail-closed controls verified.
- Status: **ACCEPTABLE - intentional privileged RPC; recurring manual review required**.

### 4. `public.admin_record_law_enforcement_request(p_incident_id uuid, p_request_reference text, p_agency_name text, p_request_type text, p_scope_summary text, p_received_at timestamp with time zone, p_emergency_request boolean)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260717161132_mutual_trust_real_world_safety.sql`
- Why SECURITY DEFINER is required: Performs an audited privileged workflow across restricted rows after an in-function role check.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Requires the applicable admin, restricted safety, or trained-reviewer role; the acting identity is never accepted as an argument.
- Client-controlled identifier review: Object UUIDs are selectors only; ownership/participant/role checks are reapplied and no caller identity is accepted from input.
- Test coverage: complete multi-user isolation and the existing hosted regression suite.
- Risk classification: HIGH surface, fail-closed controls verified.
- Status: **ACCEPTABLE - intentional privileged RPC; recurring manual review required**.

### 5. `public.admin_review_identity_verification(p_verification_id uuid, p_action text, p_decision_code text, p_identity_match_result text, p_liveness_result text, p_email_result text, p_phone_result text, p_address_result text, p_expires_at timestamp with time zone)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260717161125_mutual_identity_verification.sql`
- Why SECURITY DEFINER is required: Crosses locked verification/evidence tables to enforce a server-side deny or authorized reviewer workflow; direct table access remains unavailable.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Requires the applicable admin, restricted safety, or trained-reviewer role; the acting identity is never accepted as an argument.
- Client-controlled identifier review: Object UUIDs are selectors only; ownership/participant/role checks are reapplied and no caller identity is accepted from input.
- Test coverage: new verification-mode suites; mutual verification; teen/adult ID isolation; verification forgery; evidence preservation.
- Risk classification: HIGH surface, fail-closed controls verified.
- Status: **ACCEPTABLE - fail-closed provider-safe compatibility surface; recurring manual review required**.

### 6. `public.admin_set_safety_role(p_user_id uuid, p_role text, p_enabled boolean, p_reason text)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260717161132_mutual_trust_real_world_safety.sql`
- Why SECURITY DEFINER is required: Performs an audited privileged workflow across restricted rows after an in-function role check.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Requires the applicable admin, restricted safety, or trained-reviewer role; the acting identity is never accepted as an argument.
- Client-controlled identifier review: User UUIDs are targets only. The acting identity comes from `auth.uid()` and ownership/role checks are reapplied.
- Test coverage: complete multi-user isolation and the existing hosted regression suite.
- Risk classification: HIGH surface, fail-closed controls verified.
- Status: **ACCEPTABLE - intentional privileged RPC; recurring manual review required**.

### 7. `public.admin_update_incident_case(p_incident_id uuid, p_status text, p_public_status_note text, p_restricted_note text, p_severity text)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260717161132_mutual_trust_real_world_safety.sql`
- Why SECURITY DEFINER is required: Performs an audited privileged workflow across restricted rows after an in-function role check.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Requires the applicable admin, restricted safety, or trained-reviewer role; the acting identity is never accepted as an argument.
- Client-controlled identifier review: Object UUIDs are selectors only; ownership/participant/role checks are reapplied and no caller identity is accepted from input.
- Test coverage: incident isolation; evidence preservation; complete multi-user isolation.
- Risk classification: HIGH surface, fail-closed controls verified.
- Status: **ACCEPTABLE - intentional privileged RPC; recurring manual review required**.

### 8. `public.authorize_identity_evidence_access(p_evidence_id uuid, p_reason text)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260717161125_mutual_identity_verification.sql`
- Why SECURITY DEFINER is required: Crosses locked verification/evidence tables to enforce a server-side deny or authorized reviewer workflow; direct table access remains unavailable.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Requires the applicable admin, restricted safety, or trained-reviewer role; the acting identity is never accepted as an argument.
- Client-controlled identifier review: Object UUIDs are selectors only; ownership/participant/role checks are reapplied and no caller identity is accepted from input.
- Test coverage: new verification-mode suites; mutual verification; teen/adult ID isolation; verification forgery; evidence preservation.
- Risk classification: HIGH surface, fail-closed controls verified.
- Status: **ACCEPTABLE - fail-closed provider-safe compatibility surface; recurring manual review required**.

### 9. `public.authorize_incident_evidence_access(p_evidence_id uuid, p_reason text)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260717161132_mutual_trust_real_world_safety.sql`
- Why SECURITY DEFINER is required: Crosses locked verification/evidence tables to enforce a server-side deny or authorized reviewer workflow; direct table access remains unavailable.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Requires the applicable admin, restricted safety, or trained-reviewer role; the acting identity is never accepted as an argument.
- Client-controlled identifier review: Object UUIDs are selectors only; ownership/participant/role checks are reapplied and no caller identity is accepted from input.
- Test coverage: new verification-mode suites; mutual verification; teen/adult ID isolation; verification forgery; evidence preservation.
- Risk classification: HIGH surface, fail-closed controls verified.
- Status: **ACCEPTABLE - intentional privileged RPC; recurring manual review required**.

### 10. `public.cancel_guardian_invite(p_link_id uuid)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260711170513_guardian_jobs_profiles_backend.sql`
- Why SECURITY DEFINER is required: Performs an atomic relationship workflow across rows that are not broadly exposed through RLS.
- Explicit search_path: `search_path=public` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Checks the authenticated relationship owner/participant (or an authorized admin) before mutation or disclosure.
- Client-controlled identifier review: Object UUIDs are selectors only; ownership/participant/role checks are reapplied and no caller identity is accepted from input.
- Test coverage: optional Guardian Mode; Safety Circle permissions; complete multi-user isolation.
- Risk classification: LOW/MEDIUM minimized read or predicate surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 11. `public.confirm_job_arrival_code(p_application_id uuid, p_code text, p_person_matches_profile boolean)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260717161132_mutual_trust_real_world_safety.sql`
- Why SECURITY DEFINER is required: Performs an atomic job workflow and rechecks ownership, participation, eligibility, or private-location release rules.
- Explicit search_path: `search_path=public, extensions, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Checks job owner, applicant, accepted participant, or authorized reviewer before acting.
- Client-controlled identifier review: Object UUIDs are selectors only; ownership/participant/role checks are reapplied and no caller identity is accepted from input.
- Test coverage: address privacy; complete multi-user isolation.
- Risk classification: MEDIUM state-changing surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 12. `public.confirm_job_checkout(p_application_id uuid)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260717161132_mutual_trust_real_world_safety.sql`
- Why SECURITY DEFINER is required: Performs an atomic job workflow and rechecks ownership, participation, eligibility, or private-location release rules.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Checks job owner, applicant, accepted participant, or authorized reviewer before acting.
- Client-controlled identifier review: Object UUIDs are selectors only; ownership/participant/role checks are reapplied and no caller identity is accepted from input.
- Test coverage: address privacy; complete multi-user isolation.
- Risk classification: MEDIUM state-changing surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 13. `public.confirm_job_safety_agreement(p_application_id uuid, p_agreement_version integer)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260717161132_mutual_trust_real_world_safety.sql`
- Why SECURITY DEFINER is required: Performs an atomic job workflow and rechecks ownership, participation, eligibility, or private-location release rules.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Checks job owner, applicant, accepted participant, or authorized reviewer before acting.
- Client-controlled identifier review: Object UUIDs are selectors only; ownership/participant/role checks are reapplied and no caller identity is accepted from input.
- Test coverage: complete multi-user isolation; production fail-closed; proof and job regression QA.
- Risk classification: MEDIUM state-changing surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 14. `public.consume_job_boost_credit(p_job_id uuid)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260709030114_add_revenuecat_webhook_job_boost_credits.sql`
- Why SECURITY DEFINER is required: Performs an atomic job workflow and rechecks ownership, participation, eligibility, or private-location release rules.
- Explicit search_path: `search_path=public` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Checks job owner, applicant, accepted participant, or authorized reviewer before acting.
- Client-controlled identifier review: Object UUIDs are selectors only; ownership/participant/role checks are reapplied and no caller identity is accepted from input.
- Test coverage: complete multi-user isolation; production fail-closed; proof and job regression QA.
- Risk classification: MEDIUM state-changing surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 15. `public.consume_username_change_credit()`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260708163330_add_voluntary_paywall_perks.sql`
- Why SECURITY DEFINER is required: Performs a caller-bound atomic workflow across protected tables and audit records.
- Explicit search_path: `search_path=public` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Caller/participant or role checks are performed directly or by the delegated helper before protected access.
- Client-controlled identifier review: No client UUID is used as an acting identity.
- Test coverage: existing monetization/username QA plus complete multi-user isolation.
- Risk classification: MEDIUM state-changing surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 16. `public.create_guardian_invite()`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `202607070001_initial_mort.sql`
- Why SECURITY DEFINER is required: Performs an atomic relationship workflow across rows that are not broadly exposed through RLS.
- Explicit search_path: `search_path=public` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Delegates to `create_guardian_invite_v2`, which binds the caller with `auth.uid()`.
- Ownership/role checks: Checks the authenticated relationship owner/participant (or an authorized admin) before mutation or disclosure.
- Client-controlled identifier review: No client UUID is used as an acting identity.
- Test coverage: optional Guardian Mode; Safety Circle permissions; complete multi-user isolation.
- Risk classification: MEDIUM state-changing surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 17. `public.create_guardian_invite_v2(p_invite_email text)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260711170513_guardian_jobs_profiles_backend.sql`
- Why SECURITY DEFINER is required: Performs an atomic relationship workflow across rows that are not broadly exposed through RLS.
- Explicit search_path: `search_path=public, extensions, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Checks the authenticated relationship owner/participant (or an authorized admin) before mutation or disclosure.
- Client-controlled identifier review: No client UUID is used as an acting identity.
- Test coverage: optional Guardian Mode; Safety Circle permissions; complete multi-user isolation.
- Risk classification: MEDIUM state-changing surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 18. `public.create_safety_circle_invite(p_relationship_label text, p_permissions jsonb)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260717161132_mutual_trust_real_world_safety.sql`
- Why SECURITY DEFINER is required: Performs an atomic relationship workflow across rows that are not broadly exposed through RLS.
- Explicit search_path: `search_path=public, extensions, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Checks the authenticated relationship owner/participant (or an authorized admin) before mutation or disclosure.
- Client-controlled identifier review: No client UUID is used as an acting identity.
- Test coverage: optional Guardian Mode; Safety Circle permissions; complete multi-user isolation.
- Risk classification: MEDIUM state-changing surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 19. `public.create_support_ticket(p_subject text, p_message text)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260713124500_support_center_rpc.sql`
- Why SECURITY DEFINER is required: Performs a caller-bound atomic workflow across protected tables and audit records.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Caller/participant or role checks are performed directly or by the delegated helper before protected access.
- Client-controlled identifier review: No client UUID is used as an acting identity.
- Test coverage: complete multi-user isolation and the existing hosted regression suite.
- Risk classification: MEDIUM state-changing surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 20. `public.current_profile_is_test()`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260713131500_fix_test_account_rls_recursion.sql`
- Why SECURITY DEFINER is required: Returns a caller-bound or minimized derived result from rows that are intentionally not directly readable.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Caller/participant or role checks are performed directly or by the delegated helper before protected access.
- Client-controlled identifier review: No client UUID is used as an acting identity.
- Test coverage: complete multi-user isolation and the existing hosted regression suite.
- Risk classification: LOW/MEDIUM minimized read or predicate surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 21. `public.current_profile_role()`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `202607070001_initial_mort.sql`
- Why SECURITY DEFINER is required: Returns a caller-bound or minimized derived result from rows that are intentionally not directly readable.
- Explicit search_path: `search_path=public` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Caller/participant or role checks are performed directly or by the delegated helper before protected access.
- Client-controlled identifier review: No client UUID is used as an acting identity.
- Test coverage: complete multi-user isolation and the existing hosted regression suite.
- Risk classification: LOW/MEDIUM minimized read or predicate surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 22. `public.generate_job_arrival_code(p_application_id uuid)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260717161132_mutual_trust_real_world_safety.sql`
- Why SECURITY DEFINER is required: Performs an atomic job workflow and rechecks ownership, participation, eligibility, or private-location release rules.
- Explicit search_path: `search_path=public, extensions, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Checks job owner, applicant, accepted participant, or authorized reviewer before acting.
- Client-controlled identifier review: Object UUIDs are selectors only; ownership/participant/role checks are reapplied and no caller identity is accepted from input.
- Test coverage: address privacy; complete multi-user isolation.
- Risk classification: LOW/MEDIUM minimized read or predicate surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 23. `public.get_authorized_location_shares()`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260717161132_mutual_trust_real_world_safety.sql`
- Why SECURITY DEFINER is required: Performs an atomic job workflow and rechecks ownership, participation, eligibility, or private-location release rules.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Checks job owner, applicant, accepted participant, or authorized reviewer before acting.
- Client-controlled identifier review: No client UUID is used as an acting identity.
- Test coverage: address privacy; complete multi-user isolation.
- Risk classification: HIGH surface, fail-closed controls verified.
- Status: **ACCEPTABLE - intentional privileged RPC; recurring manual review required**.

### 24. `public.get_guardian_policy_for_user(p_user_id uuid)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260711170513_guardian_jobs_profiles_backend.sql`
- Why SECURITY DEFINER is required: Performs an atomic relationship workflow across rows that are not broadly exposed through RLS.
- Explicit search_path: `search_path=public` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Checks the authenticated relationship owner/participant (or an authorized admin) before mutation or disclosure.
- Client-controlled identifier review: User UUIDs are targets only. The acting identity comes from `auth.uid()` and ownership/role checks are reapplied.
- Test coverage: optional Guardian Mode; Safety Circle permissions; complete multi-user isolation.
- Risk classification: LOW/MEDIUM minimized read or predicate surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 25. `public.get_identity_evidence_manifest(p_verification_id uuid)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260717193747_trust_safety_evidence_manifests.sql`
- Why SECURITY DEFINER is required: Performs a caller-bound atomic workflow across protected tables and audit records.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Own-record reads are caller-bound; write/review paths are disabled or require server-authorized production decision context.
- Client-controlled identifier review: Object UUIDs are selectors only; ownership/participant/role checks are reapplied and no caller identity is accepted from input.
- Test coverage: new verification-mode suites; mutual verification; teen/adult ID isolation; verification forgery; evidence preservation.
- Risk classification: HIGH surface, fail-closed controls verified.
- Status: **ACCEPTABLE - fail-closed provider-safe compatibility surface; recurring manual review required**.

### 26. `public.get_incident_evidence_manifest(p_incident_id uuid)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260717193747_trust_safety_evidence_manifests.sql`
- Why SECURITY DEFINER is required: Creates or reads a minimized safety workflow while keeping restricted incident data behind server checks.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Checks reporter, case participant, evidence authorization, or restricted safety role before returning or changing data.
- Client-controlled identifier review: Object UUIDs are selectors only; ownership/participant/role checks are reapplied and no caller identity is accepted from input.
- Test coverage: new verification-mode suites; mutual verification; teen/adult ID isolation; verification forgery; evidence preservation.
- Risk classification: HIGH surface, fail-closed controls verified.
- Status: **ACCEPTABLE - intentional privileged RPC; recurring manual review required**.

### 27. `public.get_job_application_eligibility(p_job_id uuid)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260711170513_guardian_jobs_profiles_backend.sql`
- Why SECURITY DEFINER is required: Performs an atomic job workflow and rechecks ownership, participation, eligibility, or private-location release rules.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Checks job owner, applicant, accepted participant, or authorized reviewer before acting.
- Client-controlled identifier review: Object UUIDs are selectors only; ownership/participant/role checks are reapplied and no caller identity is accepted from input.
- Test coverage: complete multi-user isolation; production fail-closed; proof and job regression QA.
- Risk classification: LOW/MEDIUM minimized read or predicate surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 28. `public.get_job_boost_credit_status()`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260709030114_add_revenuecat_webhook_job_boost_credits.sql`
- Why SECURITY DEFINER is required: Performs an atomic job workflow and rechecks ownership, participation, eligibility, or private-location release rules.
- Explicit search_path: `search_path=public` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Checks job owner, applicant, accepted participant, or authorized reviewer before acting.
- Client-controlled identifier review: No client UUID is used as an acting identity.
- Test coverage: complete multi-user isolation; production fail-closed; proof and job regression QA.
- Risk classification: LOW/MEDIUM minimized read or predicate surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 29. `public.get_my_active_sessions()`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260717161132_mutual_trust_real_world_safety.sql`
- Why SECURITY DEFINER is required: Returns a caller-bound or minimized derived result from rows that are intentionally not directly readable.
- Explicit search_path: `search_path=auth, extensions, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Caller/participant or role checks are performed directly or by the delegated helper before protected access.
- Client-controlled identifier review: No client UUID is used as an acting identity.
- Test coverage: complete multi-user isolation and the existing hosted regression suite.
- Risk classification: LOW/MEDIUM minimized read or predicate surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 30. `public.get_my_identity_verification()`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260717161125_mutual_identity_verification.sql`
- Why SECURITY DEFINER is required: Returns a caller-bound or minimized derived result from rows that are intentionally not directly readable.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Own-record reads are caller-bound; write/review paths are disabled or require server-authorized production decision context.
- Client-controlled identifier review: No client UUID is used as an acting identity.
- Test coverage: new verification-mode suites; mutual verification; teen/adult ID isolation; verification forgery; evidence preservation.
- Risk classification: HIGH surface, fail-closed controls verified.
- Status: **ACCEPTABLE - fail-closed provider-safe compatibility surface; recurring manual review required**.

### 31. `public.get_my_incident_cases()`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260717161132_mutual_trust_real_world_safety.sql`
- Why SECURITY DEFINER is required: Creates or reads a minimized safety workflow while keeping restricted incident data behind server checks.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Checks reporter, case participant, evidence authorization, or restricted safety role before returning or changing data.
- Client-controlled identifier review: No client UUID is used as an acting identity.
- Test coverage: incident isolation; evidence preservation; complete multi-user isolation.
- Risk classification: HIGH surface, fail-closed controls verified.
- Status: **ACCEPTABLE - intentional privileged RPC; recurring manual review required**.

### 32. `public.get_my_message_threads()`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260717082454_feature_expansion_unread_proof_review.sql`
- Why SECURITY DEFINER is required: Evaluates participant/block state and performs an atomic messaging operation without exposing private relationship rows.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Caller/participant or role checks are performed directly or by the delegated helper before protected access.
- Client-controlled identifier review: No client UUID is used as an acting identity.
- Test coverage: complete multi-user isolation; mutual trust regression QA.
- Risk classification: LOW/MEDIUM minimized read or predicate surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 33. `public.get_my_safety_circle()`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260717161132_mutual_trust_real_world_safety.sql`
- Why SECURITY DEFINER is required: Performs an atomic relationship workflow across rows that are not broadly exposed through RLS.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Checks the authenticated relationship owner/participant (or an authorized admin) before mutation or disclosure.
- Client-controlled identifier review: No client UUID is used as an acting identity.
- Test coverage: optional Guardian Mode; Safety Circle permissions; complete multi-user isolation.
- Risk classification: LOW/MEDIUM minimized read or predicate surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 34. `public.get_public_trust_badges(p_user_id uuid)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260717161125_mutual_identity_verification.sql`
- Why SECURITY DEFINER is required: Returns a caller-bound or minimized derived result from rows that are intentionally not directly readable.
- Explicit search_path: `search_path=public, auth, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Caller/participant or role checks are performed directly or by the delegated helper before protected access.
- Client-controlled identifier review: The UUID is a target selector only; the result is minimized and requires a current production provider decision.
- Test coverage: complete multi-user isolation and the existing hosted regression suite.
- Risk classification: LOW/MEDIUM minimized read or predicate surface.
- Status: **ACCEPTABLE (authenticated minimized RPC); FIXED anonymous execution grant**.

### 35. `public.get_released_job_location(p_application_id uuid)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260717161132_mutual_trust_real_world_safety.sql`
- Why SECURITY DEFINER is required: Performs an atomic job workflow and rechecks ownership, participation, eligibility, or private-location release rules.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Checks job owner, applicant, accepted participant, or authorized reviewer before acting.
- Client-controlled identifier review: Object UUIDs are selectors only; ownership/participant/role checks are reapplied and no caller identity is accepted from input.
- Test coverage: address privacy; complete multi-user isolation.
- Risk classification: HIGH surface, fail-closed controls verified.
- Status: **ACCEPTABLE - intentional privileged RPC; recurring manual review required**.

### 36. `public.get_username_change_status()`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260708163330_add_voluntary_paywall_perks.sql`
- Why SECURITY DEFINER is required: Performs a caller-bound atomic workflow across protected tables and audit records.
- Explicit search_path: `search_path=public` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Caller/participant or role checks are performed directly or by the delegated helper before protected access.
- Client-controlled identifier review: No client UUID is used as an acting identity.
- Test coverage: existing monetization/username QA plus complete multi-user isolation.
- Risk classification: LOW/MEDIUM minimized read or predicate surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 37. `public.guardian_is_connected_to_teen(p_teen_id uuid, p_guardian_id uuid)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `202607070001_initial_mort.sql`
- Why SECURITY DEFINER is required: Performs an atomic relationship workflow across rows that are not broadly exposed through RLS.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Checks the authenticated relationship owner/participant (or an authorized admin) before mutation or disclosure.
- Client-controlled identifier review: User UUIDs are targets only. The acting identity comes from `auth.uid()` and ownership/role checks are reapplied.
- Test coverage: optional Guardian Mode; Safety Circle permissions; complete multi-user isolation.
- Risk classification: LOW/MEDIUM minimized read or predicate surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 38. `public.guardian_receives_safety_pings(p_teen_id uuid, p_guardian_id uuid)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260713140000_guardian_safety_ping_delivery.sql`
- Why SECURITY DEFINER is required: Performs an atomic relationship workflow across rows that are not broadly exposed through RLS.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Checks the authenticated relationship owner/participant (or an authorized admin) before mutation or disclosure.
- Client-controlled identifier review: User UUIDs are targets only. The acting identity comes from `auth.uid()` and ownership/role checks are reapplied.
- Test coverage: optional Guardian Mode; Safety Circle permissions; complete multi-user isolation.
- Risk classification: LOW/MEDIUM minimized read or predicate surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 39. `public.is_action_allowed(p_action text)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260709040300_add_rate_limiting.sql`
- Why SECURITY DEFINER is required: Returns a caller-bound or minimized derived result from rows that are intentionally not directly readable.
- Explicit search_path: `search_path=public` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Delegates to the server rate-limit helper, which keys the action to the current authenticated caller.
- Ownership/role checks: Caller/participant or role checks are performed directly or by the delegated helper before protected access.
- Client-controlled identifier review: No client UUID is used as an acting identity.
- Test coverage: complete multi-user isolation and the existing hosted regression suite.
- Risk classification: LOW/MEDIUM minimized read or predicate surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 40. `public.is_admin()`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `202607070001_initial_mort.sql`
- Why SECURITY DEFINER is required: Returns a caller-bound or minimized derived result from rows that are intentionally not directly readable.
- Explicit search_path: `search_path=public` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Delegates to `current_profile_role()`, which resolves the role from `auth.uid()`.
- Ownership/role checks: Caller/participant or role checks are performed directly or by the delegated helper before protected access.
- Client-controlled identifier review: No client UUID is used as an acting identity.
- Test coverage: complete multi-user isolation and the existing hosted regression suite.
- Risk classification: LOW/MEDIUM minimized read or predicate surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 41. `public.is_application_participant(p_application_id uuid)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `202607070001_initial_mort.sql`
- Why SECURITY DEFINER is required: Performs an atomic job workflow and rechecks ownership, participation, eligibility, or private-location release rules.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Checks job owner, applicant, accepted participant, or authorized reviewer before acting.
- Client-controlled identifier review: Object UUIDs are selectors only; ownership/participant/role checks are reapplied and no caller identity is accepted from input.
- Test coverage: complete multi-user isolation; production fail-closed; proof and job regression QA.
- Risk classification: LOW/MEDIUM minimized read or predicate surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 42. `public.is_profile_active(p_user_id uuid)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `202607070001_initial_mort.sql`
- Why SECURITY DEFINER is required: Returns a caller-bound or minimized derived result from rows that are intentionally not directly readable.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Caller/participant or role checks are performed directly or by the delegated helper before protected access.
- Client-controlled identifier review: User UUIDs are targets only. The acting identity comes from `auth.uid()` and ownership/role checks are reapplied.
- Test coverage: complete multi-user isolation and the existing hosted regression suite.
- Risk classification: LOW/MEDIUM minimized read or predicate surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 43. `public.is_thread_participant(p_thread_id uuid)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `202607070001_initial_mort.sql`
- Why SECURITY DEFINER is required: Evaluates participant/block state and performs an atomic messaging operation without exposing private relationship rows.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Caller/participant or role checks are performed directly or by the delegated helper before protected access.
- Client-controlled identifier review: Object UUIDs are selectors only; ownership/participant/role checks are reapplied and no caller identity is accepted from input.
- Test coverage: complete multi-user isolation; mutual trust regression QA.
- Risk classification: LOW/MEDIUM minimized read or predicate surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 44. `public.is_verified_adult()`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `202607070001_initial_mort.sql`
- Why SECURITY DEFINER is required: Returns a caller-bound or minimized derived result from rows that are intentionally not directly readable.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Caller/participant or role checks are performed directly or by the delegated helper before protected access.
- Client-controlled identifier review: No client UUID is used as an acting identity.
- Test coverage: complete multi-user isolation and the existing hosted regression suite.
- Risk classification: LOW/MEDIUM minimized read or predicate surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 45. `public.manage_job(p_job_id uuid, p_action text)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260711170513_guardian_jobs_profiles_backend.sql`
- Why SECURITY DEFINER is required: Performs an atomic job workflow and rechecks ownership, participation, eligibility, or private-location release rules.
- Explicit search_path: `search_path=public` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Checks job owner, applicant, accepted participant, or authorized reviewer before acting.
- Client-controlled identifier review: Object UUIDs are selectors only; ownership/participant/role checks are reapplied and no caller identity is accepted from input.
- Test coverage: complete multi-user isolation; production fail-closed; proof and job regression QA.
- Risk classification: MEDIUM state-changing surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 46. `public.mark_message_thread_read(p_thread_id uuid)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260717082454_feature_expansion_unread_proof_review.sql`
- Why SECURITY DEFINER is required: Evaluates participant/block state and performs an atomic messaging operation without exposing private relationship rows.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Caller/participant or role checks are performed directly or by the delegated helper before protected access.
- Client-controlled identifier review: Object UUIDs are selectors only; ownership/participant/role checks are reapplied and no caller identity is accepted from input.
- Test coverage: complete multi-user isolation; mutual trust regression QA.
- Risk classification: LOW/MEDIUM minimized read or predicate surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 47. `public.place_incident_preservation_hold(p_incident_id uuid, p_legal_basis text, p_scope text, p_expires_at timestamp with time zone)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260717161132_mutual_trust_real_world_safety.sql`
- Why SECURITY DEFINER is required: Performs an audited privileged workflow across restricted rows after an in-function role check.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Requires the applicable admin, restricted safety, or trained-reviewer role; the acting identity is never accepted as an argument.
- Client-controlled identifier review: Object UUIDs are selectors only; ownership/participant/role checks are reapplied and no caller identity is accepted from input.
- Test coverage: incident isolation; evidence preservation; complete multi-user isolation.
- Risk classification: HIGH surface, fail-closed controls verified.
- Status: **ACCEPTABLE - intentional privileged RPC; recurring manual review required**.

### 48. `public.record_feature_usage(p_feature_key text, p_entitlement_required text, p_allowed boolean)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260708163330_add_voluntary_paywall_perks.sql`
- Why SECURITY DEFINER is required: Performs a caller-bound atomic workflow across protected tables and audit records.
- Explicit search_path: `search_path=public` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Caller/participant or role checks are performed directly or by the delegated helper before protected access.
- Client-controlled identifier review: No client UUID is used as an acting identity.
- Test coverage: existing monetization/username QA plus complete multi-user isolation.
- Risk classification: LOW/MEDIUM minimized read or predicate surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 49. `public.register_identity_evidence(p_verification_id uuid, p_evidence_id uuid, p_storage_path text, p_evidence_type text, p_sha256 text)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260717161125_mutual_identity_verification.sql`
- Why SECURITY DEFINER is required: Crosses locked verification/evidence tables to enforce a server-side deny or authorized reviewer workflow; direct table access remains unavailable.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Own-record reads are caller-bound; write/review paths are disabled or require server-authorized production decision context.
- Client-controlled identifier review: Object UUIDs are selectors only; ownership/participant/role checks are reapplied and no caller identity is accepted from input.
- Test coverage: new verification-mode suites; mutual verification; teen/adult ID isolation; verification forgery; evidence preservation.
- Risk classification: HIGH surface, fail-closed controls verified.
- Status: **ACCEPTABLE - fail-closed provider-safe compatibility surface; recurring manual review required**.

### 50. `public.register_incident_evidence(p_incident_id uuid, p_evidence_id uuid, p_storage_path text, p_evidence_type text, p_sha256 text)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260717161132_mutual_trust_real_world_safety.sql`
- Why SECURITY DEFINER is required: Crosses locked verification/evidence tables to enforce a server-side deny or authorized reviewer workflow; direct table access remains unavailable.
- Explicit search_path: `search_path=public, storage, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Checks reporter, case participant, evidence authorization, or restricted safety role before returning or changing data.
- Client-controlled identifier review: Object UUIDs are selectors only; ownership/participant/role checks are reapplied and no caller identity is accepted from input.
- Test coverage: new verification-mode suites; mutual verification; teen/adult ID isolation; verification forgery; evidence preservation.
- Risk classification: HIGH surface, fail-closed controls verified.
- Status: **ACCEPTABLE - intentional privileged RPC; recurring manual review required**.

### 51. `public.report_account_security_concern(p_event_type text, p_session_reference text, p_details text)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260717161132_mutual_trust_real_world_safety.sql`
- Why SECURITY DEFINER is required: Performs a caller-bound atomic workflow across protected tables and audit records.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Caller/participant or role checks are performed directly or by the delegated helper before protected access.
- Client-controlled identifier review: No client UUID is used as an acting identity.
- Test coverage: complete multi-user isolation and the existing hosted regression suite.
- Risk classification: LOW/MEDIUM minimized read or predicate surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 52. `public.report_person_mismatch(p_application_id uuid, p_details text)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260717161132_mutual_trust_real_world_safety.sql`
- Why SECURITY DEFINER is required: Creates or reads a minimized safety workflow while keeping restricted incident data behind server checks.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Caller/participant or role checks are performed directly or by the delegated helper before protected access.
- Client-controlled identifier review: Object UUIDs are selectors only; ownership/participant/role checks are reapplied and no caller identity is accepted from input.
- Test coverage: incident isolation; evidence preservation; complete multi-user isolation.
- Risk classification: LOW/MEDIUM minimized read or predicate surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 53. `public.request_username_change(p_new_username text)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260708163330_add_voluntary_paywall_perks.sql`
- Why SECURITY DEFINER is required: Performs a caller-bound atomic workflow across protected tables and audit records.
- Explicit search_path: `search_path=public` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Caller/participant or role checks are performed directly or by the delegated helper before protected access.
- Client-controlled identifier review: No client UUID is used as an acting identity.
- Test coverage: existing monetization/username QA plus complete multi-user isolation.
- Risk classification: LOW/MEDIUM minimized read or predicate surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 54. `public.resend_guardian_invite(p_link_id uuid)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260711170513_guardian_jobs_profiles_backend.sql`
- Why SECURITY DEFINER is required: Performs an atomic relationship workflow across rows that are not broadly exposed through RLS.
- Explicit search_path: `search_path=public, extensions, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Checks the authenticated relationship owner/participant (or an authorized admin) before mutation or disclosure.
- Client-controlled identifier review: Object UUIDs are selectors only; ownership/participant/role checks are reapplied and no caller identity is accepted from input.
- Test coverage: optional Guardian Mode; Safety Circle permissions; complete multi-user isolation.
- Risk classification: LOW/MEDIUM minimized read or predicate surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 55. `public.review_application_proof(p_proof_id uuid, p_action text, p_note text)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260717082454_feature_expansion_unread_proof_review.sql`
- Why SECURITY DEFINER is required: Performs an atomic job workflow and rechecks ownership, participation, eligibility, or private-location release rules.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Checks job owner, applicant, accepted participant, or authorized reviewer before acting.
- Client-controlled identifier review: Object UUIDs are selectors only; ownership/participant/role checks are reapplied and no caller identity is accepted from input.
- Test coverage: complete multi-user isolation; production fail-closed; proof and job regression QA.
- Risk classification: LOW/MEDIUM minimized read or predicate surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 56. `public.save_job_draft_or_publish(p_job_id uuid, p_client_request_id uuid, p_payload jsonb, p_publish boolean)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260711170513_guardian_jobs_profiles_backend.sql`
- Why SECURITY DEFINER is required: Performs an atomic job workflow and rechecks ownership, participation, eligibility, or private-location release rules.
- Explicit search_path: `search_path=public` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Checks job owner, applicant, accepted participant, or authorized reviewer before acting.
- Client-controlled identifier review: Object UUIDs are selectors only; ownership/participant/role checks are reapplied and no caller identity is accepted from input.
- Test coverage: complete multi-user isolation; production fail-closed; proof and job regression QA.
- Risk classification: MEDIUM state-changing surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 57. `public.save_job_private_location(p_job_id uuid, p_exact_address text, p_arrival_instructions text, p_access_notes text)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260717161132_mutual_trust_real_world_safety.sql`
- Why SECURITY DEFINER is required: Performs an atomic job workflow and rechecks ownership, participation, eligibility, or private-location release rules.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Checks job owner, applicant, accepted participant, or authorized reviewer before acting.
- Client-controlled identifier review: Object UUIDs are selectors only; ownership/participant/role checks are reapplied and no caller identity is accepted from input.
- Test coverage: address privacy; complete multi-user isolation.
- Risk classification: HIGH surface, fail-closed controls verified.
- Status: **ACCEPTABLE - intentional privileged RPC; recurring manual review required**.

### 58. `public.save_job_safety_disclosures(p_job_id uuid, p_who_will_be_present text, p_animal_risk_disclosed boolean, p_animal_risk_notes text, p_equipment_risk_disclosed boolean, p_equipment_risk_notes text, p_transportation_required boolean, p_public_meeting_available boolean, p_daylight_only boolean, p_weather_risk_acknowledged boolean)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260717161132_mutual_trust_real_world_safety.sql`
- Why SECURITY DEFINER is required: Performs an atomic job workflow and rechecks ownership, participation, eligibility, or private-location release rules.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Checks job owner, applicant, accepted participant, or authorized reviewer before acting.
- Client-controlled identifier review: Object UUIDs are selectors only; ownership/participant/role checks are reapplied and no caller identity is accepted from input.
- Test coverage: complete multi-user isolation; production fail-closed; proof and job regression QA.
- Risk classification: MEDIUM state-changing surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 59. `public.save_job_safety_plan(p_application_id uuid, p_expected_people text, p_public_or_visible_meeting boolean, p_daylight_preferred boolean, p_transportation_plan text, p_checkin_cadence_minutes integer)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260717161132_mutual_trust_real_world_safety.sql`
- Why SECURITY DEFINER is required: Performs an atomic job workflow and rechecks ownership, participation, eligibility, or private-location release rules.
- Explicit search_path: `search_path=public, extensions, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Checks job owner, applicant, accepted participant, or authorized reviewer before acting.
- Client-controlled identifier review: Object UUIDs are selectors only; ownership/participant/role checks are reapplied and no caller identity is accepted from input.
- Test coverage: complete multi-user isolation; production fail-closed; proof and job regression QA.
- Risk classification: MEDIUM state-changing surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 60. `public.send_safe_message(p_thread_id uuid, p_body text)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `202607070001_initial_mort.sql`
- Why SECURITY DEFINER is required: Evaluates participant/block state and performs an atomic messaging operation without exposing private relationship rows.
- Explicit search_path: `search_path=public, extensions, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Caller/participant or role checks are performed directly or by the delegated helper before protected access.
- Client-controlled identifier review: Object UUIDs are selectors only; ownership/participant/role checks are reapplied and no caller identity is accepted from input.
- Test coverage: complete multi-user isolation; mutual trust regression QA.
- Risk classification: LOW/MEDIUM minimized read or predicate surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 61. `public.set_guardian_setup_skipped()`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260711170513_guardian_jobs_profiles_backend.sql`
- Why SECURITY DEFINER is required: Performs an atomic relationship workflow across rows that are not broadly exposed through RLS.
- Explicit search_path: `search_path=public` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Checks the authenticated relationship owner/participant (or an authorized admin) before mutation or disclosure.
- Client-controlled identifier review: No client UUID is used as an acting identity.
- Test coverage: optional Guardian Mode; Safety Circle permissions; complete multi-user isolation.
- Risk classification: MEDIUM state-changing surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 62. `public.set_teen_pause(p_teen_id uuid, p_paused boolean, p_reason text)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `202607070001_initial_mort.sql`
- Why SECURITY DEFINER is required: Performs an atomic relationship workflow across rows that are not broadly exposed through RLS.
- Explicit search_path: `search_path=public` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Checks the authenticated relationship owner/participant (or an authorized admin) before mutation or disclosure.
- Client-controlled identifier review: User UUIDs are targets only. The acting identity comes from `auth.uid()` and ownership/role checks are reapplied.
- Test coverage: optional Guardian Mode; Safety Circle permissions; complete multi-user isolation.
- Risk classification: MEDIUM state-changing surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 63. `public.set_trusted_relationship(p_target_user_id uuid, p_relationship_type text, p_source_job_id uuid, p_enabled boolean)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260717161132_mutual_trust_real_world_safety.sql`
- Why SECURITY DEFINER is required: Performs a caller-bound atomic workflow across protected tables and audit records.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Caller/participant or role checks are performed directly or by the delegated helper before protected access.
- Client-controlled identifier review: User UUIDs are targets only. The acting identity comes from `auth.uid()` and ownership/role checks are reapplied.
- Test coverage: complete multi-user isolation and the existing hosted regression suite.
- Risk classification: MEDIUM state-changing surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 64. `public.start_identity_verification(p_evidence_route text, p_attested boolean, p_exception_reason text)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260717161125_mutual_identity_verification.sql`
- Why SECURITY DEFINER is required: Crosses locked verification/evidence tables to enforce a server-side deny or authorized reviewer workflow; direct table access remains unavailable.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Own-record reads are caller-bound; write/review paths are disabled or require server-authorized production decision context.
- Client-controlled identifier review: No client UUID is used as an acting identity.
- Test coverage: new verification-mode suites; mutual verification; teen/adult ID isolation; verification forgery; evidence preservation.
- Risk classification: HIGH surface, fail-closed controls verified.
- Status: **ACCEPTABLE - fail-closed provider-safe compatibility surface; recurring manual review required**.

### 65. `public.start_temporary_location_share(p_application_id uuid, p_recipient_user_id uuid, p_mode text, p_expires_at timestamp with time zone, p_coarse_location text, p_latitude double precision, p_longitude double precision, p_explicit_consent boolean)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260717161132_mutual_trust_real_world_safety.sql`
- Why SECURITY DEFINER is required: Performs an atomic job workflow and rechecks ownership, participation, eligibility, or private-location release rules.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Checks job owner, applicant, accepted participant, or authorized reviewer before acting.
- Client-controlled identifier review: Object UUIDs are selectors only; ownership/participant/role checks are reapplied and no caller identity is accepted from input.
- Test coverage: address privacy; complete multi-user isolation.
- Risk classification: HIGH surface, fail-closed controls verified.
- Status: **ACCEPTABLE - intentional privileged RPC; recurring manual review required**.

### 66. `public.stop_temporary_location_share(p_share_id uuid)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260717161132_mutual_trust_real_world_safety.sql`
- Why SECURITY DEFINER is required: Performs an atomic job workflow and rechecks ownership, participation, eligibility, or private-location release rules.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Checks job owner, applicant, accepted participant, or authorized reviewer before acting.
- Client-controlled identifier review: Object UUIDs are selectors only; ownership/participant/role checks are reapplied and no caller identity is accepted from input.
- Test coverage: address privacy; complete multi-user isolation.
- Risk classification: HIGH surface, fail-closed controls verified.
- Status: **ACCEPTABLE - intentional privileged RPC; recurring manual review required**.

### 67. `public.submit_application_proof(p_proof_id uuid, p_application_id uuid, p_storage_path text, p_note text)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260713134000_real_proof_submission_rpc.sql`
- Why SECURITY DEFINER is required: Performs an atomic job workflow and rechecks ownership, participation, eligibility, or private-location release rules.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Checks job owner, applicant, accepted participant, or authorized reviewer before acting.
- Client-controlled identifier review: Object UUIDs are selectors only; ownership/participant/role checks are reapplied and no caller identity is accepted from input.
- Test coverage: complete multi-user isolation; production fail-closed; proof and job regression QA.
- Risk classification: MEDIUM state-changing surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 68. `public.submit_business_verification(p_verification_id uuid, p_storage_path text, p_business_name text, p_business_type text, p_notes text)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260713140500_real_business_verification_submission.sql`
- Why SECURITY DEFINER is required: Crosses locked verification/evidence tables to enforce a server-side deny or authorized reviewer workflow; direct table access remains unavailable.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Own-record reads are caller-bound; write/review paths are disabled or require server-authorized production decision context.
- Client-controlled identifier review: Object UUIDs are selectors only; ownership/participant/role checks are reapplied and no caller identity is accepted from input.
- Test coverage: new verification-mode suites; mutual verification; teen/adult ID isolation; verification forgery; evidence preservation.
- Risk classification: HIGH surface, fail-closed controls verified.
- Status: **ACCEPTABLE - fail-closed provider-safe compatibility surface; recurring manual review required**.

### 69. `public.submit_identity_verification(p_verification_id uuid, p_acknowledged boolean)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260717161125_mutual_identity_verification.sql`
- Why SECURITY DEFINER is required: Crosses locked verification/evidence tables to enforce a server-side deny or authorized reviewer workflow; direct table access remains unavailable.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Own-record reads are caller-bound; write/review paths are disabled or require server-authorized production decision context.
- Client-controlled identifier review: Object UUIDs are selectors only; ownership/participant/role checks are reapplied and no caller identity is accepted from input.
- Test coverage: new verification-mode suites; mutual verification; teen/adult ID isolation; verification forgery; evidence preservation.
- Risk classification: HIGH surface, fail-closed controls verified.
- Status: **ACCEPTABLE - fail-closed provider-safe compatibility surface; recurring manual review required**.

### 70. `public.submit_identity_verification_appeal(p_verification_id uuid, p_reason text)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260717161125_mutual_identity_verification.sql`
- Why SECURITY DEFINER is required: Crosses locked verification/evidence tables to enforce a server-side deny or authorized reviewer workflow; direct table access remains unavailable.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Own-record reads are caller-bound; write/review paths are disabled or require server-authorized production decision context.
- Client-controlled identifier review: Object UUIDs are selectors only; ownership/participant/role checks are reapplied and no caller identity is accepted from input.
- Test coverage: new verification-mode suites; mutual verification; teen/adult ID isolation; verification forgery; evidence preservation.
- Risk classification: HIGH surface, fail-closed controls verified.
- Status: **ACCEPTABLE - fail-closed provider-safe compatibility surface; recurring manual review required**.

### 71. `public.submit_incident_appeal(p_incident_id uuid, p_reason text)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260717161132_mutual_trust_real_world_safety.sql`
- Why SECURITY DEFINER is required: Creates or reads a minimized safety workflow while keeping restricted incident data behind server checks.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Checks reporter, case participant, evidence authorization, or restricted safety role before returning or changing data.
- Client-controlled identifier review: Object UUIDs are selectors only; ownership/participant/role checks are reapplied and no caller identity is accepted from input.
- Test coverage: incident isolation; evidence preservation; complete multi-user isolation.
- Risk classification: HIGH surface, fail-closed controls verified.
- Status: **ACCEPTABLE - intentional privileged RPC; recurring manual review required**.

### 72. `public.submit_job_application(p_job_id uuid, p_note text, p_availability_confirmed boolean, p_portfolio_ids uuid[])`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260711170513_guardian_jobs_profiles_backend.sql`
- Why SECURITY DEFINER is required: Performs an atomic job workflow and rechecks ownership, participation, eligibility, or private-location release rules.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Checks job owner, applicant, accepted participant, or authorized reviewer before acting.
- Client-controlled identifier review: Object UUIDs are selectors only; ownership/participant/role checks are reapplied and no caller identity is accepted from input.
- Test coverage: complete multi-user isolation; production fail-closed; proof and job regression QA.
- Risk classification: MEDIUM state-changing surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 73. `public.submit_private_review_safety_feedback(p_review_id uuid, p_structured_feedback jsonb, p_notes text)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260717161132_mutual_trust_real_world_safety.sql`
- Why SECURITY DEFINER is required: Performs a caller-bound atomic workflow across protected tables and audit records.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Caller/participant or role checks are performed directly or by the delegated helper before protected access.
- Client-controlled identifier review: Object UUIDs are selectors only; ownership/participant/role checks are reapplied and no caller identity is accepted from input.
- Test coverage: complete multi-user isolation and the existing hosted regression suite.
- Risk classification: MEDIUM state-changing surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 74. `public.submit_safety_cancellation(p_application_id uuid, p_reason text, p_details text)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260717161132_mutual_trust_real_world_safety.sql`
- Why SECURITY DEFINER is required: Creates or reads a minimized safety workflow while keeping restricted incident data behind server checks.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Caller/participant or role checks are performed directly or by the delegated helper before protected access.
- Client-controlled identifier review: Object UUIDs are selectors only; ownership/participant/role checks are reapplied and no caller identity is accepted from input.
- Test coverage: incident isolation; evidence preservation; complete multi-user isolation.
- Risk classification: MEDIUM state-changing surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 75. `public.submit_safety_report(p_target_user_id uuid, p_target_job_id uuid, p_target_message_id uuid, p_target_review_id uuid, p_application_id uuid, p_category text, p_severity text, p_immediate_danger boolean, p_details text, p_occurred_at timestamp with time zone, p_location_type text, p_desired_outcome text, p_confidential_safety_feedback boolean)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260717161132_mutual_trust_real_world_safety.sql`
- Why SECURITY DEFINER is required: Creates or reads a minimized safety workflow while keeping restricted incident data behind server checks.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Checks reporter, case participant, evidence authorization, or restricted safety role before returning or changing data.
- Client-controlled identifier review: User UUIDs are targets only. The acting identity comes from `auth.uid()` and ownership/role checks are reapplied.
- Test coverage: incident isolation; evidence preservation; complete multi-user isolation.
- Risk classification: MEDIUM state-changing surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 76. `public.teen_is_paused(p_teen_id uuid)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `202607070001_initial_mort.sql`
- Why SECURITY DEFINER is required: Performs a caller-bound atomic workflow across protected tables and audit records.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Caller/participant or role checks are performed directly or by the delegated helper before protected access.
- Client-controlled identifier review: User UUIDs are targets only. The acting identity comes from `auth.uid()` and ownership/role checks are reapplied.
- Test coverage: complete multi-user isolation and the existing hosted regression suite.
- Risk classification: LOW/MEDIUM minimized read or predicate surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 77. `public.unlink_guardian(p_link_id uuid)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260711170513_guardian_jobs_profiles_backend.sql`
- Why SECURITY DEFINER is required: Performs an atomic relationship workflow across rows that are not broadly exposed through RLS.
- Explicit search_path: `search_path=public` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Checks the authenticated relationship owner/participant (or an authorized admin) before mutation or disclosure.
- Client-controlled identifier review: Object UUIDs are selectors only; ownership/participant/role checks are reapplied and no caller identity is accepted from input.
- Test coverage: optional Guardian Mode; Safety Circle permissions; complete multi-user isolation.
- Risk classification: MEDIUM state-changing surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 78. `public.unlink_safety_circle_member(p_circle_id uuid)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260717161132_mutual_trust_real_world_safety.sql`
- Why SECURITY DEFINER is required: Performs an atomic relationship workflow across rows that are not broadly exposed through RLS.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Checks the authenticated relationship owner/participant (or an authorized admin) before mutation or disclosure.
- Client-controlled identifier review: Object UUIDs are selectors only; ownership/participant/role checks are reapplied and no caller identity is accepted from input.
- Test coverage: optional Guardian Mode; Safety Circle permissions; complete multi-user isolation.
- Risk classification: MEDIUM state-changing surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 79. `public.update_application_status_v2(p_application_id uuid, p_action text)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260711170513_guardian_jobs_profiles_backend.sql`
- Why SECURITY DEFINER is required: Performs an atomic job workflow and rechecks ownership, participation, eligibility, or private-location release rules.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Checks job owner, applicant, accepted participant, or authorized reviewer before acting.
- Client-controlled identifier review: Object UUIDs are selectors only; ownership/participant/role checks are reapplied and no caller identity is accepted from input.
- Test coverage: complete multi-user isolation; production fail-closed; proof and job regression QA.
- Risk classification: MEDIUM state-changing surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 80. `public.update_safety_circle_permissions(p_circle_id uuid, p_permissions jsonb)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260717161132_mutual_trust_real_world_safety.sql`
- Why SECURITY DEFINER is required: Performs an atomic relationship workflow across rows that are not broadly exposed through RLS.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Checks the authenticated relationship owner/participant (or an authorized admin) before mutation or disclosure.
- Client-controlled identifier review: Object UUIDs are selectors only; ownership/participant/role checks are reapplied and no caller identity is accepted from input.
- Test coverage: optional Guardian Mode; Safety Circle permissions; complete multi-user isolation.
- Risk classification: MEDIUM state-changing surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

### 81. `public.update_temporary_job_location(p_share_id uuid, p_latitude double precision, p_longitude double precision)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `20260717161132_mutual_trust_real_world_safety.sql`
- Why SECURITY DEFINER is required: Performs an atomic job workflow and rechecks ownership, participation, eligibility, or private-location release rules.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Checks job owner, applicant, accepted participant, or authorized reviewer before acting.
- Client-controlled identifier review: Object UUIDs are selectors only; ownership/participant/role checks are reapplied and no caller identity is accepted from input.
- Test coverage: address privacy; complete multi-user isolation.
- Risk classification: HIGH surface, fail-closed controls verified.
- Status: **ACCEPTABLE - intentional privileged RPC; recurring manual review required**.

### 82. `public.users_are_blocked(p_user_one uuid, p_user_two uuid)`

- Existing before this provider pass: yes
- New in this provider pass: no
- First retained migration: `202607070001_initial_mort.sql`
- Why SECURITY DEFINER is required: Evaluates participant/block state and performs an atomic messaging operation without exposing private relationship rows.
- Explicit search_path: `search_path=public, pg_temp` (present)
- Owner / execution grants: `postgres`; explicit/default EXECUTE ACL: authenticated, postgres, service_role; effective authenticated=true, service_role=true, anon=false
- Caller authentication: authenticated role plus Direct `auth.uid()` caller binding; a missing session fails or returns no authority.
- Ownership/role checks: Caller/participant or role checks are performed directly or by the delegated helper before protected access.
- Client-controlled identifier review: Both UUIDs are lookup operands for a boolean relationship result; neither becomes the acting user or grants authority.
- Test coverage: complete multi-user isolation; mutual trust regression QA.
- Risk classification: LOW/MEDIUM minimized read or predicate surface.
- Status: **ACCEPTABLE - intentional caller-bound authenticated RPC**.

## Required Negative Assertions

Catalog inspection and hosted QA confirm:

- No public SECURITY DEFINER function is executable by `anon`.
- No acting user identity is accepted from a client parameter; direct functions use `auth.uid()` and the three wrappers without a direct reference delegate to caller-bound helpers.
- Client self-verification, status changes, environment changes, provider changes, role assignment, and production approval were rejected.
- `get_public_trust_badges` is authenticated-only and returns no address or identity-evidence metadata.
- Production verification requires a current production provider result from the signed server webhook path; sandbox, expired, unsigned, replayed, malformed, and client-authored results fail closed.

## Advisor References

- [Supabase function lint 0029](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable)
- [Supabase password security](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection)
- [Supabase RLS no-policy lint](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)
