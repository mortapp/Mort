# MORT Production Readiness — Flutter Backend Integration

**Updated:** 2026-10-31 (workspace local date)  
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
