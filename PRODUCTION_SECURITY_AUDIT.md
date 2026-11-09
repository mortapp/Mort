# MORT Production Security Audit — Release Blockers

**Assessment date:** 2026-11-08
**Scope:** Evidence-backed review of current release PRs, previously completed 59-function review, Issue #70 Guardian reader finding, current production release flags, mobile artifact, and available CI. This is not a claim that every endpoint was retested in hosted production.

## Findings

### HIGH — Guardian application rows can outlive Guardian-ID masking checks

- **Affected:** `public.get_my_job_applications(uuid)` and the application's Guardian-linked reader workflow.
- **Unsafe behavior:** The production row-selection predicate has been identified as less restrictive than the Guardian-ID disclosure CASE. A linked Guardian who fails role/account/age/email eligibility can still receive the application row, even when the Guardian ID is masked. Masking one field does not deny the rest of the application data.
- **Evidence:** Focused proposal and 49-assertion production-baseline pgTAP suite in [PR #71](https://github.com/mortapp/Mort/pull/71); current production migration ledger still ends at `20261102113314`, before the Issue #70 proposal. PR #71 exact head has CI success, but no review and no authenticated hosted personas.
- **Narrow fix:** Review and apply only the exact-source-guarded reader-predicate migration after independent security approval and isolated authenticated tests. Preserve applicant self-access and intended adult poster access. Do not grant Guardian/admin broad table reads.
- **Required tests:** Eligible consenting Guardian, ineligible role/account/age/email, missing/revoked consent/link, unrelated teen, direct UUID substitution, status-update nested response, direct table denial, grants/SECURITY DEFINER/search_path.
- **Status:** Open; no production change.

### HIGH — No complete restore proof

- **Affected:** Database schema/data, Auth records, Storage metadata and bytes, secrets/configuration, recovery operations.
- **Unsafe assumption:** Partial encrypted feature snapshots do not establish recoverability. PR #69 explicitly excludes Auth internals and Storage bytes and reports that no backup or restore was run.
- **Evidence:** [PR #69](https://github.com/mortapp/Mort/pull/69), current restore runbook, and its backup-envelope CI tests. These tests cover envelope behavior, not end-to-end restoration.
- **Narrow fix:** Owner-approved full provider-supported backup plus isolated restore; compare schema/migration state, approved aggregate counts, object checksums/accessibility, Auth recovery, application relationships, and measured RPO/RTO. Keep production untouched.
- **Status:** Open; no backup or restore executed here.

### HIGH — Production database credential rotation is unverified

- **Affected:** Direct database consumers and any protected deployment or operator secret using that password.
- **Risk:** A production database password was previously disclosed in this conversation history. Its current validity/revocation and dependent-secret updates cannot be verified from read-only project metadata. Do not print or reuse it.
- **Narrow fix:** Treat as compromised until the owner rotates it through the authorized Supabase control plane, updates only dependent secret stores, restarts/drains connection pools, and verifies connections without exposing the new value. Follow `docs/operations/MORT_DATABASE_CREDENTIAL_ROTATION.md` once PR #69 is reviewed; the base branch's runbook inventory may be stale.
- **Status:** Open pending owner/operator confirmation. No rotation was performed here.

### HIGH — Legal and teen-safety release approvals are absent

- **Affected:** Signup, consent, identity/document collection, teen marketplace participation, moderation and support escalation.
- **Evidence:** The built AAB manifest identifies all four legal content versions as `draft-2026-07`. Real document collection remains false. No legal reviewer, approved evidence policy, support/on-call roster, or moderation acceptance was verified.
- **Narrow fix:** Obtain authorized legal and operational sign-off, publish final versioned content, and bind accepted versions to the production clickwrap before activating affected features.
- **Status:** Open; engineering cannot approve legal content or create staff identities.

### HIGH — Authenticated role-isolation acceptance is unavailable

- **Affected:** Teen/adult/Guardian/admin auth, jobs, applications, messaging, blocking/reporting, private locations, sessions, and account states.
- **Evidence:** Read-only isolated QA aggregate counts are all zero for Auth users, profiles, Guardian links, jobs, applications, and Storage objects. No authenticated API outcomes are available.
- **Narrow fix:** With legal approval, authorized reviewer provisioning, provider sandbox credentials, and synthetic fixtures, run the role matrix through normal onboarding and server-backed verification workflows. Never bypass triggers, RLS, or evidence checks.
- **Status:** Open; static and local pgTAP evidence is not a substitute.

### MEDIUM — Supabase Auth SMTP and email delivery are not verified

- **Affected:** Confirmation, password recovery, and security notification flows.
- **Evidence:** The owner reports Resend credential rotation is complete. The sender domain was previously observed as verified/sending-enabled. Current Auth SMTP settings are not exposed through the available Supabase project read API; no approved QA account exists for delivery testing. Tracked website/Edge Function code has no active Resend consumer; a previously observed Vercel key variable alone does not prove use.
- **Narrow fix:** Inspect Auth SMTP in the Supabase dashboard, update the new credential there only if Resend is actually configured, then test confirmation/recovery to authorized test addresses and verify provider and Supabase logs. Do not rotate again or rebuild Supabase.
- **Status:** Open pending dashboard and test-account access.

### MEDIUM — OAuth and provider verification are not verified

- **Affected:** Google sign-in, mobile callback, school/age/identity verification.
- **Evidence:** The production prelaunch artifact disables Google auth and identity verification. No live Google OAuth callback test or approved age/identity/school provider test was performed.
- **Narrow fix:** Verify OAuth client IDs, origins, callback allowlists, and PKCE flows in provider dashboards; obtain provider sandbox, legal approval, and authorized reviewer workflow before enabling identity features.
- **Status:** Open; fail closed.

### MEDIUM — Android and iOS release acceptance is incomplete

- **Affected:** Play/App Store distribution, callback behavior, permissions, accessibility, and offline/retry behavior.
- **Evidence:** Signed AAB exists and CI packaged a device-test APK; `adb devices` showed no device. No macOS/Xcode or Apple signing was available. Play Console upload/App Signing certificate match was not inspected.
- **Narrow fix:** Physical Android matrix, Play Console certificate comparison, and signed iOS archive/device matrix on an authorized Mac.
- **Status:** Open.

## Controls verified read-only

Production `get_release_mode_status()` returned `production_public`, maintenance off, `real_document_collection=false`, and `public_marketplace_enabled=false`. Stripe/payments were not activated. No DDL, data, Auth, RLS, secrets, provider settings, or release controls were changed.

The current read-only catalog/ACL query confirmed `job_applications` has RLS enabled and forced; direct SELECT is false for `anon` and `authenticated`, true for `service_role`; `anon` cannot execute `get_my_job_applications(uuid)`, `authenticated` can; the function is SECURITY DEFINER with an empty `search_path`. This correctly blocks direct table reads but does not resolve the broader Guardian row-selection predicate described above.

## Review boundaries

- Previously completed 59-function SECURITY DEFINER review is preserved; this report does not repeat it.
- PR #71 remains a proposal until reviewed and safely tested; no production migration is applied.
- Full CI/pgTAP history does not establish real provider behavior or authenticated hosted authorization.
- The database credential item remains unresolved until rotation is independently confirmed.
