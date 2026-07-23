# Flutter Changed Files

This repo is not a Git repository, so this file records the concrete RevenueCat, Flutter monetization, Supabase webhook, QA, and documentation files touched for the dashboard-ready pass. Build outputs, caches, `.env.local`, backups, `node_modules`, and secret-bearing temp files are excluded.

## Flutter

- `flutter_mort/.env.example`
- `flutter_mort/lib/core/config/app_config.dart`
- `flutter_mort/lib/data/repositories/monetization_repository.dart`
- `flutter_mort/lib/data/repositories/profile_repository.dart`
- `flutter_mort/lib/features/monetization/data/revenuecat_service.dart`
- `flutter_mort/lib/features/monetization/providers/revenuecat_providers.dart`
- `flutter_mort/lib/features/monetization/screens/paywall_screen.dart`
- `flutter_mort/pubspec.lock`
- `flutter_mort/pubspec.yaml`

## Supabase

- `supabase/functions/revenuecat-webhook/index.ts`
- `supabase/migrations/20260709030114_add_revenuecat_webhook_job_boost_credits.sql`
- `supabase/migrations/20260709031832_fix_consume_username_credit_ambiguity.sql`
- `supabase/migrations/20260709032711_harden_monetization_rpc_grants.sql`
- `supabase/migrations/20260709032858_set_search_path_on_public_rpcs.sql`
- `supabase/migrations/20260709040300_add_rate_limiting.sql`
- `supabase/migrations/20260709040500_add_ai_safety.sql`

## QA And Automation Scripts

- `scripts/qa-monetization-rls.mjs`
- `scripts/qa-old-project-rls.mjs`
- `scripts/qa-old-project-smoke.mjs`
- `scripts/qa-revenuecat-api.mjs`
- `scripts/qa-revenuecat-config.mjs`
- `scripts/qa-revenuecat-webhook.mjs`
- `scripts/qa-username-credits.mjs`
- `scripts/revenuecat-common.mjs`
- `scripts/revenuecat-setup.mjs`
- `scripts/revenuecat-setup.ps1`

## Documentation

- `docs/APP_STORE_MONETIZATION_CHECKLIST.md`
- `docs/APP_STORE_CONNECT_IAP_SETUP.md`
- `docs/APP_STORE_CONNECT_PRODUCT_MATRIX.md`
- `docs/ADMOB_FINAL_SETUP.md`
- `docs/APP_ADS_TXT_HOSTING.md`
- `docs/ENTITLEMENT_SYNC_MODEL.md`
- `docs/FINAL_MONETIZATION_RELEASE_AUDIT.md`
- `docs/FLUTTER_CHANGED_FILES.md`
- `docs/FLUTTER_IOS_BUILD_AND_TESTFLIGHT.md`
- `docs/FLUTTER_REMAINING_LIMITATIONS.md`
- `docs/FLUTTER_REVENUECAT_SETUP.md`
- `docs/IPHONE_MANUAL_TEST_PLAN.md`
- `docs/MONETIZATION_PLAN.md`
- `docs/MONETIZATION_PRICING_PLAN.md`
- `docs/PAYWALL_ETHICS.md`
- `docs/REVENUECAT_DASHBOARD_SETUP_REPORT.md`
- `docs/REVENUECAT_MANUAL_ACTIONS_LEFT.md`
- `docs/REVENUECAT_OFFERINGS_AND_PAYWALLS.md`
- `docs/REVENUECAT_PAYWALL_BUILDER_PROMPTS.md`
- `docs/REVENUECAT_PRODUCTS_AND_ENTITLEMENTS.md`
- `docs/REVENUECAT_SANDBOX_TEST_PLAN.md`
- `docs/REVENUECAT_TESTING_PLAN.md`
- `docs/REVENUECAT_WEBHOOK_SETUP.md`
