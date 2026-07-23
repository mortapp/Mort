# Exact Changed Files for 0.9.2+92

This inventory covers the profile repair, Stripe sandbox foundation, MORT Guide, Google Play Billing, Android release, QA, and operator-documentation pass.

## Supabase

```text
supabase/config.toml
supabase/migrations/20260722031037_canonical_profile_write_path.sql
supabase/migrations/20260722032907_stripe_connect_sandbox_foundation.sql
supabase/migrations/20260722034445_stripe_webhook_completion_rpc.sql
supabase/migrations/20260722042500_mort_guide_foundation.sql
supabase/migrations/20260722043000_google_play_billing_foundation.sql
supabase/migrations/20260722050500_fix_ad_eligibility_security_context.sql
supabase/functions/_shared/google_play.ts
supabase/functions/_shared/stripe.ts
supabase/functions/ai-safety/index.ts
supabase/functions/ai-support/index.ts
supabase/functions/google-play-rtdn/index.ts
supabase/functions/google-play-verify-purchase/index.ts
supabase/functions/stripe-config/index.ts
supabase/functions/stripe-create-connected-account/index.ts
supabase/functions/stripe-create-job-payment-intent/index.ts
supabase/functions/stripe-create-job-refund/index.ts
supabase/functions/stripe-create-job-transfer/index.ts
supabase/functions/stripe-create-onboarding-link/index.ts
supabase/functions/stripe-get-connected-account-status/index.ts
supabase/functions/stripe-webhook/index.ts
```

## Flutter and Android

```text
flutter_mort/pubspec.yaml
flutter_mort/pubspec.lock
flutter_mort/android/app/src/main/AndroidManifest.xml
flutter_mort/lib/main.dart
flutter_mort/lib/core/config/app_config.dart
flutter_mort/lib/core/routing/app_router.dart
flutter_mort/lib/data/models/profile.dart
flutter_mort/lib/data/repositories/mort_guide_repository.dart
flutter_mort/lib/data/repositories/profile_repository.dart
flutter_mort/lib/data/repositories/providers.dart
flutter_mort/lib/data/repositories/stripe_marketplace_repository.dart
flutter_mort/lib/features/guide/mort_guide_screens.dart
flutter_mort/lib/features/legal/contract_payment_screens.dart
flutter_mort/lib/features/monetization/data/google_play_billing.dart
flutter_mort/lib/features/monetization/screens/google_play_billing_screens.dart
flutter_mort/lib/features/mort_screens.dart
flutter_mort/lib/features/payments/stripe_marketplace_screens.dart
flutter_mort/lib/features/payments/stripe_payment_sheet_service.dart
flutter_mort/lib/features/trust/teen_verification_screens.dart
flutter_mort/test/android_native_parity_test.dart
flutter_mort/test/google_play_billing_contract_test.dart
flutter_mort/test/mort_guide_contract_test.dart
flutter_mort/test/profile_persistence_contract_test.dart
flutter_mort/test/release_candidate_policy_test.dart
flutter_mort/test/stripe_marketplace_contract_test.dart
```

## QA and Packaging

```text
scripts/ai-billing-qa-suites.mjs
scripts/package-profile-ai-billing-stripe.ps1
scripts/profile-qa-suites.mjs
scripts/qa-admob-disabled-mode.mjs
scripts/qa-admob-test-mode.mjs
scripts/qa-ai-cost-limits.mjs
scripts/qa-ai-input-output-moderation.mjs
scripts/qa-ai-minor-consent-gate.mjs
scripts/qa-ai-mode-gating.mjs
scripts/qa-ai-no-high-stakes-decisions.mjs
scripts/qa-ai-private-data-boundary.mjs
scripts/qa-android-apk.ps1
scripts/qa-android-permission-minimization.mjs
scripts/qa-auth-session-lifecycle.mjs
scripts/qa-billing-entitlement-forgery.mjs
scripts/qa-billing-free-core.mjs
scripts/qa-billing-review-entitlement.mjs
scripts/qa-billing-token-replay.mjs
scripts/qa-camera-contextual-permission.mjs
scripts/qa-dob-age-eligibility.mjs
scripts/qa-paywall-disclosures.mjs
scripts/qa-profile-avatar-storage.mjs
scripts/qa-profile-cross-user-isolation.mjs
scripts/qa-profile-duplicate-row.mjs
scripts/qa-profile-protected-fields.mjs
scripts/qa-profile-public-private-projection.mjs
scripts/qa-profile-update-forgery.mjs
scripts/qa-profile-update-persistence.mjs
scripts/qa-real-id-remains-disabled.mjs
scripts/qa-role-forgery.mjs
scripts/qa-sensitive-ad-placement.mjs
scripts/qa-stripe-cashapp-boundary.mjs
scripts/qa-stripe-connected-account-isolation.mjs
scripts/qa-stripe-dispute-hold.mjs
scripts/qa-stripe-google-play-billing-boundary.mjs
scripts/qa-stripe-job-funding.mjs
scripts/qa-stripe-minor-guardian-status.mjs
scripts/qa-stripe-mode-isolation.mjs
scripts/qa-stripe-onboarding-link-security.mjs
scripts/qa-stripe-payment-amount-forgery.mjs
scripts/qa-stripe-payment-idempotency.mjs
scripts/qa-stripe-payment-sheet-contract.mjs
scripts/qa-stripe-payout-status.mjs
scripts/qa-stripe-public-profile-privacy.mjs
scripts/qa-stripe-refund.mjs
scripts/qa-stripe-secret-boundary.mjs
scripts/qa-stripe-transfer-duplication.mjs
scripts/qa-stripe-transfer-eligibility.mjs
scripts/qa-stripe-transfer-reversal.mjs
scripts/qa-stripe-webhook-idempotency.mjs
scripts/qa-stripe-webhook-replay.mjs
scripts/qa-stripe-webhook-signature.mjs
scripts/qa-teen-ad-treatment.mjs
scripts/qa-teen-verification-alternatives.mjs
scripts/qa-teen-verification-options.mjs
scripts/stripe-check-config.ps1
scripts/stripe-listen-test.ps1
scripts/stripe-qa-suites.mjs
scripts/stripe-trigger-test-events.ps1
```

## Documentation

```text
docs/android/MORT_ANDROID_FINAL_PERMISSION_MATRIX.md
docs/defects/MORT_PROFILE_FIELD_MATRIX.md
docs/defects/MORT_PROFILE_PERSISTENCE_FIX.md
docs/defects/MORT_PROFILE_PERSISTENCE_ROOT_CAUSE.md
docs/payments/MORT_GUARDIAN_MODE_VS_STRIPE_GUARDIAN.md
docs/payments/MORT_NEGATIVE_BALANCE_RISK.md
docs/payments/MORT_PAYMENT_SYSTEM_BOUNDARY.md
docs/payments/MORT_STRIPE_ARCHITECTURE_REVIEW.md
docs/payments/MORT_STRIPE_CASH_APP_LIMITATIONS.md
docs/payments/MORT_STRIPE_CLI_TESTING.md
docs/payments/MORT_STRIPE_CONNECT_ARCHITECTURE.md
docs/payments/MORT_STRIPE_CONNECTED_ONBOARDING.md
docs/payments/MORT_STRIPE_DISPUTE_RUNBOOK.md
docs/payments/MORT_STRIPE_DISPUTES.md
docs/payments/MORT_STRIPE_EXISTING_CODE_AUDIT.md
docs/payments/MORT_STRIPE_GOOGLE_PLAY_BOUNDARY.md
docs/payments/MORT_STRIPE_IMPLEMENTATION_RESULTS.md
docs/payments/MORT_STRIPE_INCIDENT_RESPONSE.md
docs/payments/MORT_STRIPE_JOB_FUNDING.md
docs/payments/MORT_STRIPE_LIVE_READINESS.md
docs/payments/MORT_STRIPE_LIVE_SETUP.md
docs/payments/MORT_STRIPE_MANUAL_DASHBOARD_STEPS.md
docs/payments/MORT_STRIPE_MINOR_ONBOARDING.md
docs/payments/MORT_STRIPE_MINOR_PAYOUTS.md
docs/payments/MORT_STRIPE_MONITORING.md
docs/payments/MORT_STRIPE_PAYMENT_SHEET.md
docs/payments/MORT_STRIPE_RECONCILIATION.md
docs/payments/MORT_STRIPE_REFUNDS.md
docs/payments/MORT_STRIPE_SANDBOX_SETUP.md
docs/payments/MORT_STRIPE_SUPABASE_SECRETS.md
docs/payments/MORT_STRIPE_TRANSFERS.md
docs/payments/MORT_STRIPE_VIDEO_ADAPTATION_NOTES.md
docs/payments/MORT_STRIPE_WEBHOOKS.md
docs/play-final/MORT_ADMOB_FUTURE_SETUP.md
docs/play-final/MORT_ADVISOR_REVIEW_0_9_2.md
docs/play-final/MORT_AI_PROVIDER_SETUP.md
docs/play-final/MORT_BILLING_PRODUCT_SETUP.md
docs/play-final/MORT_COMMAND_RESULTS_0_9_2.md
docs/play-final/MORT_FINAL_CHANGED_FILES_0_9_2.md
docs/play-final/MORT_FOUNDER_MANAGER_PERMISSIONS.md
docs/play-final/MORT_LICENSE_TESTER_SETUP.md
docs/play-final/MORT_OWNER_CONSOLE_SETUP.md
docs/play-final/MORT_PROFILE_AI_BILLING_RELEASE_RESULTS.md
```

Generated evidence and requested archives live under `build/evidence` and the repository root; they are outputs, not source edits.
