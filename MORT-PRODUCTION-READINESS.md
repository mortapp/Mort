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
