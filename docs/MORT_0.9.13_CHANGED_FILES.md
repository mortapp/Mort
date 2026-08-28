# MORT 0.9.13+103 Changed Files

## Application and Tests

- `flutter_mort/android/app/src/main/AndroidManifest.xml`
- `flutter_mort/pubspec.yaml`
- `flutter_mort/integration_test/android_native_smoke_test.dart`
- `flutter_mort/test_driver/integration_test.dart`
- `flutter_mort/lib/core/errors/mort_error.dart`
- `flutter_mort/lib/core/errors/user_facing_error.dart`
- `flutter_mort/lib/core/widgets/date_of_birth_field.dart`
- `flutter_mort/lib/core/widgets/mort_widgets.dart`
- `flutter_mort/lib/data/models/job.dart`
- `flutter_mort/lib/data/repositories/avatar_repository.dart`
- `flutter_mort/lib/data/repositories/jobs_repository.dart`
- `flutter_mort/lib/data/repositories/profile_repository.dart`
- `flutter_mort/lib/data/repositories/providers.dart`
- `flutter_mort/lib/data/services/secure_draft_storage.dart`
- `flutter_mort/lib/features/jobs/job_creation_flow.dart`
- `flutter_mort/lib/features/jobs/job_screens.dart`
- `flutter_mort/lib/features/mort_screens.dart`
- `flutter_mort/lib/features/profile/profile_avatar_widgets.dart`
- `flutter_mort/test/mort_0_9_3_security_contract_test.dart`
- `flutter_mort/test/profile_persistence_contract_test.dart`
- `flutter_mort/test/secure_draft_storage_test.dart`
- `flutter_mort/test/video_profile_job_hardening_test.dart`

## Backend and Tooling

- `supabase/migrations/20260802062226_video_profile_job_hardening.sql`
- `scripts/qa-video-profile-job-hardening.mjs`
- `scripts/generate-release-sbom.mjs`
- `scripts/package-supreme-release.ps1`
- `scripts/qa-android-16kb-alignment.ps1`
- `scripts/qa-android-permission-minimization.mjs`
- `scripts/run-android-native-integration.ps1`
- `scripts/sensitive-file-scan.ps1`
- `scripts/verify-play-aab.ps1`

## Generated Evidence and Registry Corrections

- `docs/release/MORT_ROUTE_ACTION_INVENTORY_0_9_13_103.{md,csv,json}`
- `docs/MORT_1891_FEATURE_REGISTRY.{md,csv,json}`
- `docs/MORT_FEATURE_IMPLEMENTATION_AUDIT.md`
- `docs/MORT_FEATURE_IMPLEMENTATION_WAVES.md`
- `docs/MORT_FEATURE_PRIORITY_SCORECARD.md`
- `docs/MORT_FEATURE_VALIDATION_REPORT.md`
- `docs/WEB_BUILD_CONFIG_STATUS.md`
- `docs/android/MORT_ANDROID_FINAL_PERMISSION_MATRIX.md`
- `docs/mobile/MORT_ANDROID_PERMISSION_RELEASE_AUDIT.md`
- `docs/ios/MORT_APP_STORE_SUBMISSION_PACKET.md`
- `docs/ios/MORT_MAC_BUILD_AND_TEST_TASK.md`
- `docs/ios/MORT_TESTFLIGHT_RELEASE_CHECKLIST.md`
- all fourteen `0.9.13` reports required by the video-readiness directive;
- `docs/MORT_SUPREME_PROGRESS_LEDGER.md`.

Private ignored recordings, generated build directories, local environment
files, signing material, and secret values are not source changes.
