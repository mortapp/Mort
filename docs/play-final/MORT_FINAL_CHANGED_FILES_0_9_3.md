# MORT 0.9.3 Changed Files

Branch: `mort-0.9.3-support-pins-evidence-payments`

The local repository had zero commits and no baseline tree, so every existing file appears untracked. This list is taken from this sprint's edit/deployment record; generated build caches and local configuration are excluded.

## Flutter

- `flutter_mort/pubspec.yaml`
- `flutter_mort/pubspec.lock`
- `flutter_mort/android/app/src/main/AndroidManifest.xml`
- `flutter_mort/lib/core/routing/app_router.dart`
- `flutter_mort/lib/data/models/profile.dart`
- `flutter_mort/lib/data/repositories/avatar_repository.dart`
- `flutter_mort/lib/data/repositories/job_execution_repository.dart`
- `flutter_mort/lib/data/repositories/providers.dart`
- `flutter_mort/lib/data/repositories/stripe_marketplace_repository.dart`
- `flutter_mort/lib/data/repositories/support_repository.dart`
- `flutter_mort/lib/features/jobs/job_progress_screen.dart`
- `flutter_mort/lib/features/mort_screens.dart`
- `flutter_mort/lib/features/payments/admin_payment_operations_screen.dart`
- `flutter_mort/lib/features/payments/stripe_marketplace_screens.dart`
- `flutter_mort/lib/features/profile/profile_avatar_widgets.dart`
- `flutter_mort/lib/features/support/support_screens.dart`
- `flutter_mort/test/job_progress_widget_test.dart`
- `flutter_mort/test/mort_0_9_3_security_contract_test.dart`
- `flutter_mort/test/support_chat_widget_test.dart`

## Supabase Functions and Configuration

- `supabase/config.toml`
- `supabase/functions/ai-support/index.ts`
- `supabase/functions/avatar-url/index.ts`
- `supabase/functions/stripe-create-job-payment-intent/index.ts`
- `supabase/functions/stripe-resolve-job-payment/index.ts`
- `supabase/functions/stripe-webhook/index.ts`
- `supabase/functions/support-evidence-url/index.ts`

## Migrations

- `supabase/migrations/20260722202139_mort_0_9_3_support_execution_evidence_payments.sql`
- `supabase/migrations/20260722202142_mort_0_9_3_legal_draft_catalog.sql`
- `supabase/migrations/20260722202206_mort_0_9_3_job_execution_pins.sql`
- `supabase/migrations/20260722202208_mort_0_9_3_payment_resolution.sql`
- `supabase/migrations/20260722212441_mort_0_9_3_abandonment_decision_safety.sql`
- `supabase/migrations/20260722213243_mort_0_9_3_refund_webhook_reconciliation.sql`
- `supabase/migrations/20260722213502_mort_0_9_3_support_staff_queue.sql`
- `supabase/migrations/20260722214515_mort_0_9_3_evidence_draft_removal.sql`
- `supabase/migrations/20260722215041_mort_0_9_3_support_case_number_default.sql`
- `supabase/migrations/20260722215459_mort_0_9_3_support_rls_helper_permissions.sql`
- `supabase/migrations/20260722215544_mort_0_9_3_support_message_rls_permission.sql`
- `supabase/migrations/20260722220314_fix_profile_avatar_filename_policy.sql`
- `supabase/migrations/20260722222534_mort_0_9_3_ai_and_signed_media_rate_limits.sql`
- `supabase/migrations/20260722223231_mort_0_9_3_payment_operations_queue.sql`
- `supabase/migrations/20260722225742_fix_adult_job_cancellation_enum_cast.sql`

## QA, Build, and Packaging

- `scripts/feature-qa-helpers.mjs`
- `scripts/android-lint-release.ps1`
- `scripts/build-closed-test-apk.ps1`
- `scripts/build-play-aab.ps1`
- `scripts/mutual-trust-qa-suites.mjs`
- `scripts/package-mort-0.9.3.ps1`
- `scripts/qa-abandonment-safety-cooldown.mjs`
- `scripts/qa-ai-cost-prompt-boundary.mjs`
- `scripts/qa-avatar-storage.mjs`
- `scripts/qa-complete-multi-user-isolation.mjs`
- `scripts/qa-evidence-isolation.mjs`
- `scripts/qa-job-pin-replay-lock.mjs`
- `scripts/qa-job-start-funding-gate.mjs`
- `scripts/qa-payment-operations-queue-boundary.mjs`
- `scripts/qa-payment-resolution-boundary.mjs`
- `scripts/qa-rate-limits.mjs`
- `scripts/qa-signed-media-rate-limits.mjs`
- `scripts/qa-stripe-refund-webhook-reconciliation.mjs`
- `scripts/qa-stripe-resolution-idempotency.mjs`
- `scripts/qa-stripe-resolution-role-separation.mjs`
- `scripts/qa-stripe-saved-payment-consent.mjs`
- `scripts/qa-support-cross-user-isolation.mjs`
- `scripts/qa-support-email-fallback-contract.mjs`
- `scripts/qa-support-staff-forgery.mjs`
- `scripts/run-final-supabase-regression.ps1`
- `scripts/sensitive-file-scan.ps1`
- `scripts/stripe-qa-suites.mjs`
- `scripts/support-execution-payment-qa-suites.mjs`

## Root Dependency and Ignore Files

- `.gitignore`
- `package.json`
- `pnpm-lock.yaml`

## Documentation

- Eight `0_9_3` legal drafts under `docs/legal`
- All `docs/MORT_*` architecture, audit, score, test, risk, readiness, and tracker files dated 2026-07-22
- Five 0.9.3 runbooks under `docs/operations`
- Two payment runbooks under `docs/payments`
- Two 0.9.3 threat models under `docs/security`
- `docs/MORT_1891_FEATURE_REGISTRY.md` audit disclaimer
- 0.9.3 handoff files under `docs/play-final`

## Final Android Lint Correction

- Removed obsolete manifest-merger removal stubs that referenced absent Google Mobile Ads classes while ads remain intentionally disabled and the SDK is not packaged.
- Added `scripts/android-lint-release.ps1` to normalize generated Windows property paths and run the MORT application module's release lint with protected external signing.
- Kept the upstream `flutter_local_notifications` dependency unmodified. Root Gradle `lintRelease` still invokes the package's own lint task and reports its upstream `MissingPermission` findings; MORT's supported `:app:lintRelease` gate passes.
