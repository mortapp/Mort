# MORT 0.9.4 Changed Files

Baseline: `33013561adf3f163616dcd9ab73d86509df3edcf`

## Documentation and evidence

- `docs/MORT_0_9_4_GAP_MATRIX.md`
- `docs/MORT_ANDROID_EMULATOR_EVIDENCE_0_9_4.md`
- `docs/MORT_COMPLETION_SCORE.md`
- `docs/MORT_INCIDENT_EXERCISE_TEMPLATE.md`
- `docs/MORT_OPERATIONAL_RUNBOOKS_0_9_4.md`
- `docs/MORT_REPOSITORY_RECOVERY_REPORT_0_9_4.md`
- `docs/MORT_RESTORE_DRILL_GUIDE.md`
- `docs/MORT_SECURITY_DELTA_0_9_3_TO_0_9_4.md`
- `docs/MORT_STRIPE_TESTMODE_END_TO_END_0_9_4.md`
- `docs/play-final/MORT_COMMAND_RESULTS_0_9_4.md`
- `docs/play-final/MORT_FINAL_CHANGED_FILES_0_9_4.md`
- `docs/play-final/MORT_FINAL_STATUS_0_9_4.md`
- `docs/release/MORT_ROUTE_ACTION_INVENTORY_0_9_4.csv`
- `docs/release/MORT_ROUTE_ACTION_INVENTORY_0_9_4.json`
- `docs/release/MORT_ROUTE_ACTION_INVENTORY_0_9_4.md`

## Flutter application

- `flutter_mort/lib/core/observability/crash_reporting.dart`
- `flutter_mort/lib/core/routing/app_router.dart`
- `flutter_mort/lib/core/routing/notification_destination.dart`
- `flutter_mort/lib/core/utils/safe_uri.dart`
- `flutter_mort/lib/data/repositories/admin_repository.dart`
- `flutter_mort/lib/data/repositories/avatar_repository.dart`
- `flutter_mort/lib/data/repositories/mission_pilot_repository.dart`
- `flutter_mort/lib/data/repositories/repository_base.dart`
- `flutter_mort/lib/data/repositories/support_repository.dart`
- `flutter_mort/lib/data/repositories/uploads_repository.dart`
- `flutter_mort/lib/features/admin/admin_moderation_detail_screen.dart`
- `flutter_mort/lib/features/admin/admin_operational_alerts_screen.dart`
- `flutter_mort/lib/features/guide/mort_guide_screens.dart`
- `flutter_mort/lib/features/mission/mission_pilot_screens.dart`
- `flutter_mort/lib/features/mort_screens.dart`
- `flutter_mort/lib/features/notifications/notification_center_screen.dart`
- `flutter_mort/lib/features/payments/stripe_marketplace_screens.dart`
- `flutter_mort/lib/main.dart`
- `flutter_mort/pubspec.lock`
- `flutter_mort/pubspec.yaml`

## Flutter tests

- `flutter_mort/test/android_native_parity_test.dart`
- `flutter_mort/test/crash_reporting_test.dart`
- `flutter_mort/test/edge_observability_contract_test.dart`
- `flutter_mort/test/mort_0_9_4_admin_moderation_contract_test.dart`
- `flutter_mort/test/notification_destination_test.dart`
- `flutter_mort/test/operational_controls_contract_test.dart`
- `flutter_mort/test/safe_uri_test.dart`

## QA, audit, and packaging scripts

- `scripts/audit-historical-qa-accounts-0.9.4.mjs`
- `scripts/audit-stale-feature-qa-references-0.9.4.mjs`
- `scripts/build-route-action-inventory.mjs`
- `scripts/cleanup-stale-feature-qa-users.mjs`
- `scripts/feature-qa-helpers.mjs`
- `scripts/package-mort-0.9.4.ps1`
- `scripts/qa-account-deletion-conversation-cascade.mjs`
- `scripts/qa-android-permission-minimization.mjs`
- `scripts/qa-mort-0.9.4-operational-controls.mjs`
- `scripts/qa-send-push-observability.mjs`
- `scripts/secret-scan-git-history.mjs`

## Supabase Edge Functions

- `supabase/functions/_shared/observability.ts`
- `supabase/functions/_shared/stripe.ts`
- `supabase/functions/send-push/index.ts`

## Supabase migrations

- `supabase/migrations/20260722233000_mort_0_9_4_admin_moderation_controls.sql`
- `supabase/migrations/20260722234500_mort_0_9_4_operational_controls.sql`
- `supabase/migrations/20260723030622_fix_account_deletion_conversation_sync_race.sql`

Generated archives, APK/AAB files, checksums, logs, backups, caches, `.env.local`,
and signing material are intentionally not tracked. Their final names, sizes,
file counts, and hashes are recorded in `artifacts/MORT_0_9_4_ARTIFACT_INVENTORY.*`.
