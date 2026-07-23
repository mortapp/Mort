# MORT Multi-Signal Trust Advisor Report

Advisor run: 2026-07-18 on `rakjydmgwwgtdislanbt` after migrations `20260718150502` and `20260718173000`.

## Security advisor

- ERROR: 0
- WARN: 100 total: 99 authenticated `SECURITY DEFINER` executable findings and 1 Auth leaked-password finding
- INFO: 4 RLS-enabled/no-policy findings
- Anonymous `SECURITY DEFINER` execution: none

The 18 trust functions intentionally callable by authenticated users are caller-bound or specialized-role-bound: `get_marketplace_trust_eligibility`, `get_my_account_trust_profile`, `get_public_trust_badges`, `update_account_security_preferences`, `set_trust_signal_visibility`, `submit_account_trust_appeal`, `request_school_email_affiliation`, `redeem_partner_invite_code`, `request_business_registry_match`, `request_business_representative_claim`, the seven `admin_*` organization/registry/appeal functions, and `get_admin_trust_review_queue`. They need definer rights to cross locked tables atomically; direct table writes remain denied. Every function has an empty explicit `search_path`, derives actor from `auth.uid()`, and was exercised by forgery/isolation QA.

The three trust service functions are not authenticated-callable: digital credential session creation, credential result processing, and reauthentication event recording.

The four INFO tables are deliberate deny-by-default state: private trust policy plus private job arrival/location tables exposed only through checked RPCs.

The leaked-password warning is **DEFERRED - PLAN-LIMITED SECURITY ENHANCEMENT**. Supabase Free cannot enable the HaveIBeenPwned control. Current mitigations are strong password length/complexity, rate limiting, email confirmation, RLS, account restriction, and secure reset. When Supabase is upgraded to Pro, enable leaked-password protection immediately and rerun Auth security advisors. No upgrade or spending was performed.

## Performance advisor

Initial result: 51 unindexed-foreign-key INFO and 40 unused-index INFO. Twenty-three missing FK indexes belonged to the new trust tables. Migration `20260718173000_multi_signal_trust_fk_indexes.sql` added all 23; the rerun reported 28 unindexed-FK INFO and 63 unused-index INFO.

The new indexes appear as unused immediately after creation because no production traffic exists. They are retained to cover referential actions and expected reviewer/user lookups. Reassess usage only after representative traffic; do not remove them based on an immediate post-create statistic.

Remediation references: [authenticated definer lint](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable), [RLS no-policy lint](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy), [password security](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).
