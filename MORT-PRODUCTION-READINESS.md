# MORT Production Readiness — Flutter Backend Integration

**Updated:** 2026-11-01 (workspace local date)
**Branch:** `codex/flutter-backend-integration`
**Production backend:** Supabase project `jxbnrkasktbhtiujkhay`  
**Status:** In progress. No production writes, migration application, deployment, marketplace activation, or payment activation occurred.

## Work completed in this branch

- Aligned Flutter Guardian-link reads with production `guardian_links` and its live foreign-key names; map `pending` to the existing UI `invited` state.
- Replaced the direct `guardian_preferences` UPDATE (not permitted by production grants) with the existing `set_guardian_alert_preferences` RPC.
- Removed two unused Guardian RPC wrappers (`get_guardian_policy_for_user`, `set_teen_pause`) after confirming there are no callers.
- Aligned Safety Center reads with production `user_blocks` and `safety_reports`; map report `category` to the UI's `reason` field.
- Added row-mapping regression tests and local additive SQL proposals for block/unblock, Guardian invite resend, and message block enforcement.

## Verification evidence

- `flutter analyze`: passed, no issues.
- Full Flutter suite: **620 passed, 2 skipped, 0 failed** (`flutter test --no-pub`).
- Focused mapper tests: **4 passed** (`flutter test test/production_backend_row_mapping_test.dart --no-pub`).
- Proposed SQL applied and behavior-smoked against a disposable, catalog-derived local PostgreSQL 17 fixture: passed for block idempotency, self-block rejection, message rejection after block, unblock, Guardian resend, and cross-user resend denial. This is not an isolated copy of production.
- Supabase temporary branch creation was rejected because the project plan does not support branching. No upgrade/resource creation was attempted. The pgTAP integration file has not run against a schema clone.

## Production controls and safety

Read-only inspection found `public_marketplace_enabled=false`, `real_document_collection=false`, `public_marketplace_closed=true`, `new_job_publishing_disabled=true`, and `payments_disabled=true`. These controls were not changed. Production user rows and legal/release-control records were not modified.

The production schema enforces RLS on `profiles`, `guardian_links`, `safety_reports`, `user_blocks`, and `verification_cases`; direct authenticated writes to Guardian links and safety reports are unavailable. Job exact-address access is not granted to anon/authenticated. The candidate migration is additive and creates no tables or columns, but it still requires isolated review/testing before any production application.

## Remaining blockers

1. The proposed database contracts are not verified against an isolated production-schema clone. Obtain a supported isolated Supabase environment or equivalent clone before considering migration approval.
2. Production migration history (69 entries, latest observed `20261101002805_safety_reports_server_only_idempotent`) diverges from the repository's historical 239-file chain. Reconcile migration history before proposing any deployment; do not replay the chain.
3. Message blocking trigger concurrency/transaction behavior and all pgTAP cases remain unverified on the isolated clone.
4. `get_safety_center_config` is absent; identity start/submit/appeal RPCs and the provider Edge Function are absent. Document collection remains fail-closed.
5. Google OAuth provider configuration could not be verified from available Supabase connection capabilities.
6. Marketplace contracts for application state, private job location and server-side distance remain absent; marketplace stays disabled.
7. Supabase security advisor reported 46 authenticated SECURITY DEFINER review items, 18 RLS-enabled/no-policy informational items, and leaked-password protection disabled. These need routine-level assessment; the findings alone do not establish exploitability.

See [MORT-FLUTTER-BACKEND-CONTRACT-DIFF.md](MORT-FLUTTER-BACKEND-CONTRACT-DIFF.md) for the route-level dependency inventory, RLS evidence, and local migration proposal details.

## Marketplace safety contract follow-up (2026-11-01)

The Flutter branch now aligns application reads and status changes with the active production RPC contracts. `ApplicationsRepository` reads through `get_my_job_applications` (the server filters by caller/role) and submits only the supported actions through `update_my_job_application_status` with its optimistic `p_expected_updated_at` guard. It no longer queries the nonexistent `applications` relation, sends the obsolete RPC arguments, or exposes Quick Accept. Guardian application screens are read-only and state that Guardian decisions are unavailable; production has no Guardian approval/rejection contract to call.

The teen feed no longer requests or retains device coordinates to calculate private job distances and no longer calls the absent `get_nearby_job_distances_v1`. It displays distance as unavailable until the private server contract exists. This is an intentional fail-closed behavior, not an implementation of server-side distance retrieval.

Regression coverage added/updated: production `applicant_id`/`cover_note` row mapping, supported application actions and Guardian read-only affordance, and source-level assertions that Quick Accept and client distance lookup are absent. Focused results are recorded below after the current full-suite rerun.

### Safety-contract completion status

- **Application submission / lifecycle:** Production has `job_applications` and `mort_application_status` (`submitted`, `withdrawn`, `shortlisted`, `accepted`, `rejected`, `cancelled`). Existing `submit_job_application` and `update_my_job_application_status` are the active contracts. The submit flow's eligibility check and underlying submit function have a stale-state window: under-lock revalidation does not cover every eligibility condition (including current publishing/open/expiry and Guardian state). This remains a database blocker; no production DDL was run.
- **Guardian application approval:** Not implemented. The live schema has no Guardian decision RPC or application statuses for Guardian approval. Client UI no longer implies the Guardian can approve/reject through a supported production path. A secure additive design still requires isolated schema validation and integration tests before migration review.
- **Private job location:** Not implemented. Current job saving leaves `jobs.exact_address` null and exposes no save/read/release RPC or private location relation. Exact addresses remain unavailable to anon/authenticated clients. No coordinates are requested or exposed by this Flutter change.
- **Server-side job distance:** Not implemented. Production has no distance RPC and no coordinate columns in the inspected `jobs` schema. Flutter now fails closed by omitting distance and does not calculate it from client coordinates.
- **Blocking:** The checked-in additive proposal adds block/unblock RPCs and rejects blocked message inserts, but the trigger has no shared pair lock with block creation. Concurrent block/message serialization is unproven. The proposal is not production-applied and its pgTAP suite has not run against an isolated production-equivalent database.

### Verification and environment limits

- The production project remains `jxbnrkasktbhtiujkhay`; only read-only catalog, RPC, advisor, and feature-control inspection was performed. No production data, release control, or migration history was changed.
- The production migration history has 69 entries and ends at `20261101002805_safety_reports_server_only_idempotent`; this branch's local migration chain differs. A direct connection from the local DB container could not reach the active project (`Network is unreachable`), and a supported isolated Supabase branch is unavailable on the current plan. Therefore a faithful local clone and independent two-session concurrency test are not available.
- Full Flutter suite: **617 passed, 2 skipped, 0 failed** (`flutter test --no-pub`). Focused changed-area suite: **29 passed, 0 failed**; it passed again after removing the two analyzer warnings. `flutter analyze --no-pub`: **No issues found**. `dart format` and `git diff --check` pass.
- No isolated integration tests have passed for application stale-state handling, Guardian consent/decision, private location authorization/release, server-side distance, or blocking races. These contracts are not complete or release-ready.
- Marketplace publishing, payment controls, document collection, and release controls were not changed. Read-only `get_runtime_feature_status()` on 2026-11-01 reported `public_marketplace_closed=true`, `new_job_publishing_disabled=true`, `payments_disabled=true`, and `real_document_collection=false` (`maintenance_mode=false`, `ai_provider_disabled=true`).

## Backend safety-contract continuation (2026-11-01)

Production inspection was read-only. Production lists 69 migrations through `20261101002805`; this checkout has 240 migrations with a divergent history. `supabase` CLI is unavailable, the local Docker DB does not reproduce production, and Supabase reports only the main branch (no isolated child). No paid environment was created. Database execution stopped at that boundary, as required.

The application race is confirmed: the authenticated submit RPC checks eligibility before entering the service-role-only insert RPC; the locked insert rechecks only a subset of release, job-window, active-poster and Guardian gates. A proposal now locks the job and relevant authorization rows before rerunning the existing eligibility function. It is not applied or integration-tested. The unique `(job_id, applicant_id)` constraint remains the duplicate guard.

The live message RPCs validate active conversation membership and block state, but have no shared transaction pair lock. The existing local safety proposal now locks the same canonical user pair for `user_blocks` writes and all message inserts, locks active conversation state, and preserves message history. Twenty-five pgTAP assertions and a two-connection QA harness using the authenticated block and message RPCs were added; neither was run because no production-equivalent isolated database is available.

The location relation and RPCs are absent in production. `jobs.exact_address` cannot be selected by authenticated clients, but read-only ACL inspection shows authenticated table INSERT and exact-address UPDATE privileges. The older repository migration targets a deleted legacy `applications` schema and exposes fine-grained distance output; it is not reusable. No location DDL was added. The proposed safe design and test matrix are in [MORT-FLUTTER-BACKEND-CONTRACT-DIFF.md](MORT-FLUTTER-BACKEND-CONTRACT-DIFF.md).

Current production controls were not changed. Marketplace/publishing/payments remain disabled, and real document collection remains false. Static checks completed: `flutter test --no-pub` passed (617 passed, 2 skipped, 0 failed), `flutter analyze --no-pub` reported no issues (ran in 597.1 seconds), `dart format --output=none --set-exit-if-changed lib test` formatted 310 files with 0 changes, PowerShell harness parsing passed, pgTAP assertion count matches its plan (25), and `git diff --check` passed. Database integration and migration-history reconciliation remain blocked; no PR was created.

## Backend security completion review (2026-11-01)

The following changes are local review proposals only. Production remained read-only, and the feature branch has not changed production schema, data, secrets, release controls, or deployments.

### Application, block/message, and exact-address contracts

- `supabase/proposals/marketplace_application_submission_race.sql` preserves the live submit signature, serializes on the job row, rejects inactive/non-teen callers, locks the relevant consent/verification/release state, and reruns `get_job_application_eligibility` inside the insert transaction. Existing applications return an idempotent replay only for live submitted/shortlisted/accepted states; terminal rows are not overwritten. Production and isolated behavior have not been tested; assess lock order against the live accept/status transition RPCs before applying.
- `supabase/proposals/production_safety_missing_contracts.sql` adds durable block-request idempotency and a canonical user-pair transaction lock shared by block mutations and message insertion. Message insertion checks active conversation membership and both-direction blocks. Existing message history is not changed. The independent two-session race test remains unrun.
- Live ACL inspection confirms authenticated users can INSERT `jobs` rows and UPDATE the `exact_address` column; they cannot SELECT that column. The website currently has a direct `jobs` insert path. `supabase/proposals/jobs_exact_address_privilege_reconciliation.sql` revokes direct authenticated job insertion/address writes only after the website has cut over to `save_job_draft_or_publish(uuid,uuid,jsonb,boolean)`. That website cutover is still required; applying this privilege change first would break legitimate job creation. No website code was changed in this mobile branch.
- `supabase/proposals/private_job_location_lifecycle.sql` proposes a private location relation, legacy address copy-and-verify before clearing public-row copies, an owner save contract, a trusted server-only geocoder callback, participant-only read after assignment and mutual current agreement, and server-side coarse distance bands. Exact coordinates and addresses are never returned by the distance contract. Address changes version the terms and require renewed agreement; location access also fails closed after relevant blocks, Guardian revocation where the job requires Guardian consent, cancellation, or completion. This file requires SQL review: the migration has not been compiled or tested, the existing agreement-confirmation flow must be wired to its versioning, and participant notifications/outbox behavior for re-consent must be specified. No exact-address authorization behavior has passed integration tests.
- Guardian application views remain read-only. No Guardian decision permission, RPC, or state transition was added.

### Verification and reviewer access

- Production identity/age verification cases already have distinct `verification_type` values (`age`, `identity`, `school_email`, `school_id`) and review statuses (`not_started`, `pending`, `verified`, `rejected`, `expired`, `needs_review`). Provider verification handlers are not deployed. No document-collection path was activated and nobody was marked verified.
- `supabase/proposals/verification_role_age_gate.sql` adds a server-stored 18+ DOB check to adult role-request approval and freezes verification rows while review consumes that evidence. The current live reviewer contract checks adult identity but not adult DOB; this is a role-escalation defect. The additive proposal and pgTAP test are unexecuted.
- First reviewer provisioning should remain an owner/DBA operation using an explicitly named, MFA-protected identity and an auditable approval record. The `private.user_roles` table has RLS and no client grants/policies; no staff access was granted. Production staff access still requires explicit authorization.
- Age, identity, and school verification remain separate evidence domains. The local identity-verification Edge Functions call RPCs absent from production, so provider session/webhook contracts, provider approval, and secret provisioning remain external blockers. No provider or credential was invented.

### Stripe and remaining security findings

- Production has five private Stripe tables (runtime controls, customers, connected accounts, payment intents, webhook events) and deployed assignment payment-intent, webhook, and runtime-status Edge Functions. There are no deployed transfer, payout, refund, or dispute lifecycle handlers/tables. All payment/onboarding/funding/transfer/refund/live/payout-approval controls inspected remain false. Local legacy Connect handlers are not production capability and must not be enabled.
- No teen payee/beneficial-owner model is approved. Stripe's current guidance requires an adult representative for under-18 account owners and its connected-account rules vary by account type and country; see [Stripe Services Agreement](https://stripe.com/legal/ssa) and [Stripe account age requirements](https://support.stripe.com/questions/age-requirement-to-create-a-stripe-account). Obtain Stripe and legal/product confirmation before implementing Connect transfers. No Stripe activation occurred.
- Adult role and adult job acceptance paths need a product decision on whether DOB >=18 is mandatory everywhere or only for teen-employer interactions; the role-review proposal closes the specific adult role escalation gate but does not settle all eligibility policy.
- Guardian consent is currently required per job only when `jobs.requires_guardian_approval=true`; it is not mandatory for every teen-eligible job in the live acceptance contract. Product/legal must approve whether that setting is sufficient. Revoking Guardian consent prevents future location reads for jobs requiring it; the live unlink path does not itself pause/cancel active assignments. Define the active assignment response and notifications before launch.
- Public `get_runtime_feature_status()` exposes only fail-closed booleans/message and timestamp (no secret or user data); the public status is intentional and should remain minimal. The three public no-policy tables and private no-policy tables have no authenticated grants, so they remain default-deny; do not add broad policies. Static SECURITY DEFINER review found no externally executable unguarded sensitive routine beyond the intentionally public feature-status getter; this heuristic is not a substitute for function-by-function review.
- Leaked-password protection is disabled according to the Supabase security advisory; a project owner must enable and verify it in Auth settings. This configuration was not changed. Performance advisor reported 19 unindexed FKs and 59 unused indexes (informational); no indexes were added or dropped without workload/retention evidence.

### Test and migration limits

- Supabase lists only production `main`; an isolated branch is unavailable on the current plan, and no free production-equivalent clone is present. No paid resource or upgrade was created. Per instruction, SQL/pgTAP execution stopped here; production was not substituted as a test DB.
- Production history is 69 migrations through `20261101002805_safety_reports_server_only_idempotent`; this checkout contains 240 migrations with zero matching migration versions. This divergence is unresolved. Do not replay the local chain.
- New application, role-age, exact-address ACL, location lifecycle, and block/message proposals must pass pgTAP plus an independent two-session test on a matching isolated DB before review/merge. Added local pgTAP files currently have assertion plans of 26 (block/message), 6 (application contract), 5 (role-age), 5 (exact-address ACL), and 13 (private-location grants/contracts); plans match their assertion counts, but none of these database suites have run. Website job creation must be cut over before exact-address privilege revocation. Final Flutter checks passed: `flutter analyze --no-pub` (no issues), `dart format --output=none --set-exit-if-changed lib test` (310 files, 0 changes), `flutter test --no-pub` (617 passed, 2 skipped, 0 failed).
- Marketplace/publishing/payments remain disabled, identity-document collection remains disabled, and draft PR #45 must remain draft pending database-dependent validation.

## Sequential readiness work — active contract follow-up (2026-11-01)

Priority 1 remains first. The application submission proposal's lock-order review found that live acceptance locks `job_applications` before `jobs`; replaying an existing application with `FOR UPDATE` after locking the job would invert that order. The proposal now uses a nonlocking read for replay after the job lock, since a replay makes no writes. The new catalog pgTAP suite has six assertions for the live RPC signature/ACL, internal routine privilege, unique `(job_id, applicant_id)` index, and closed publishing control. Job-close, age-expiry, Guardian-revoke, and accept/retry two-session cases still require a production-equivalent isolated DB.

An active Flutter canceled-application detail screen queried absent `job_management_requests`, while production records owner cancellation reason in staff audit data rather than a participant-readable contract. I removed the unsupported client read and now show a generic cancellation/support message. The test-first regression was observed failing (`managementEventsCalls` expected 0, observed 1), then the focused application detail suite passed **8 tests** after the fix. This does not expose staff-only reason data.

A refreshed literal-string source scan in `flutter_mort/lib` found 191 distinct direct RPC names (77 public production function names, 142 names absent) and 32 direct table names (43 public production relations, 17 absent). All 43 public relations have RLS enabled. The missing names span optional/pilot/finance, payment-disabled, location-absent, and admin/support paths; presence by name is not evidence of route reachability. This scan is not a complete field-level contract check: dynamic RPCs, embedded field payloads, and every selected/filtered database column still need route-aware verification. Database tests remain stopped because neither the only Supabase production branch nor local Docker databases match the production migration history.

Latest Flutter verification after that UI change: full suite **618 passed, 2 skipped, 0 failed**; `flutter analyze --no-pub` **no issues**; `dart format --output=none --set-exit-if-changed lib test` **310 files, 0 changes**. `job_management_requests` and `listManagementEvents` no longer appear in Flutter source/tests.

## Sequential launch checklist progress (2026-11-01)

### 1. Backend and database safety — still blocked from completion

- Read-only Supabase branch inspection still returns only the production `main` branch (`jxbnrkasktbhtiujkhay`); there is no isolated branch. Production history still contains 69 entries through `20261101002805`. No paid resource, production write, migration, or deployment was performed.
- The application-race, exact-address ACL, private-location, role-age, and pair-lock proposals remain local proposals. The required exact-schema pgTAP/RLS suite and independent two-session tests have not run. Do not treat their presence or local fixture smoke checks as completion.
- Live global status was re-read on 2026-11-01: `public_marketplace_closed=true`, `new_job_publishing_disabled=true`, `payments_disabled=true`, `real_document_collection=false`; `maintenance_mode=false`, `ai_provider_disabled=true`. No release controls changed.

### 2. Website integration and build validation

Read-only validation ran in `repos/mort-web` while preserving that checkout's pre-existing uncommitted changes. `npm run typecheck` exited 0; `npm run build` exited 0, including its prebuild gates: production-config/legal/pet-preference Node tests **7/7 passed**, legal publication snapshot versions and hashes verified, Next.js production compilation succeeded, and all 16 static pages generated. No code in the website checkout was edited by this validation. This proves build readiness only; authenticated teen/adult/Guardian/admin isolation and full browser end-to-end flows remain unverified.

### 3. Identity and trust

The production Edge Function inventory still contains only `stripe-create-assignment-payment-intent`, `stripe-assignment-webhook`, and `stripe-runtime-status`; neither identity-provider handler is deployed. The production feature status continues to report `real_document_collection=false`. No person was verified, no documents were collected, and no provider credential or staff authorization was added. Identity-provider approval, provider credentials, real-user verification flow tests, and secure first-reviewer provisioning remain external/isolated-QA gates.

An aggregate-only, read-only production snapshot (no IDs, emails, or document data returned) found 2 Auth users and 2 profiles, one pending age-verification case, no Guardian-link rows, and no Storage objects. This establishes that there is currently no active Guardian relationship or uploaded identity evidence to exercise; it does not justify creating QA accounts against production.

### 4. Production operations and security

- A fresh Supabase security-advisor read at 2026-11-01 13:28 UTC reported 18 RLS-enabled/no-policy informational findings, 1 public `get_runtime_feature_status()` SECURITY DEFINER warning, 46 authenticated SECURITY DEFINER warnings, and leaked-password protection disabled. The no-policy tables were previously confirmed to have no client grants; no broad policies or privilege changes were made.
- The website lint gate `npm run lint` exited 0. Website build/typecheck/lint were run against its existing worktree; the worktree's pre-existing edits remain untouched.
- Leaked-password protection is not enabled yet. The action-time confirmation required for changing this production Auth setting is pending; the security setting remains unchanged. A complete database/Auth plus Storage-byte backup, isolated restore destination, encrypted artifact destination, and proven restore are still unavailable. No backup was claimed or created.
- Retired the legacy plaintext backup exporter that hard-coded the deleted Supabase project and added a target guard so the metadata exporter must be explicitly bound to the authoritative project before opening a database connection. Fixed its row-count query to use live production relations. The focused guard/query suite passed **4/4**. This is not a full backup: the current scheduled workflow stores only schema/metadata and still uses AES-CBC without authentication; no user rows, Auth records, Storage object bytes, or restore have been backed up or verified.
- The target guard defaults to `jxbnrkasktbhtiujkhay` and rejects any explicit different ref, so the scheduled workflow needs no file change. The earlier attempt to add an explicit workflow variable was dropped after GitHub denied the workflow-file push for missing OAuth `workflow` scope; no workflow-file change was pushed. The backup guard, exporter retirement, and report updates were pushed in commit `eb711ed`.
- Flutter has Sentry crash-reporting code with privacy-sanitizer tests, but the production Android release builder previously omitted its existing `SENTRY_DSN` define. The release helper now passes a configured HTTPS DSN only when crash reporting is enabled and fails closed if it is absent or malformed. The focused PowerShell contract test passed **5/5** cases; existing release-mode and network-security QA scripts exited 0. The local `SENTRY_DSN` is missing (value was not displayed), so live event delivery and production monitoring remain unverified and a protected provider DSN is still required.
- The offline production profile validator reports that the public profile would enable marketplace and identity flags, but `productionActivationApproved=false`; no public build was attempted. Read-only live `get_release_mode_status()` returns `release_mode=production_public`, `public_marketplace_enabled=false`, and `real_document_collection=false`, so the server-side release gate would reject a public production artifact. Payments remain disabled. No artifact was built or deployed.

### Final Flutter verification at `015a262` (2026-11-01)

- `flutter test --no-pub`: **618 passed, 2 skipped, 0 failed**.
- `flutter analyze --no-pub`: **No issues found** (188.0 seconds).
- `dart format --output=none --set-exit-if-changed lib test`: **310 files, 0 changed**.
- `flutter pub get --offline` resolved the existing lockfile from the local cache; `pubspec.lock` did not change. No Dart source changed after the backend UI verification; this full rerun is recorded at the latest feature commit.
