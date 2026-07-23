# MORT Final Production-Pilot Changed Files

This inventory covers the final Google Play production-pilot technical pass. Generated build caches and temporary staging directories are not source changes.

## Flutter source and tests

- `flutter_mort/lib/data/models/job.dart`
- `flutter_mort/lib/data/repositories/jobs_repository.dart`
- `flutter_mort/lib/data/repositories/legal_contract_repository.dart`
- `flutter_mort/lib/features/legal/contract_payment_screens.dart`
- `flutter_mort/test/release_candidate_policy_test.dart`

## Root configuration

- `tsconfig.json`

## Scripts

- `scripts/build-final-production-pilot-readiness.mjs`
- `scripts/build-public-legal-site.mjs`
- `scripts/capture-final-play-assets.ps1`
- `scripts/create-play-review-fixtures.mjs`
- `scripts/package-final-play-production-pilot.ps1`
- `scripts/qa-account-deletion-enumeration.mjs`
- `scripts/qa-data-safety-inventory.mjs`
- `scripts/qa-job-lifecycle.mjs`
- `scripts/qa-old-project-smoke.mjs`
- `scripts/qa-saved-jobs.mjs`
- `scripts/run-final-supabase-regression.ps1`
- `scripts/sensitive-file-scan.ps1`
- `scripts/validate-final-play-assets.mjs`
- `scripts/validate-public-legal-site.mjs`
- `scripts/verification-mode-qa-suites.mjs`

## Supabase migrations

- `supabase/migrations/20260721215000_fix_identity_reviewer_policy_execution.sql`
- `supabase/migrations/20260721220500_preserve_closed_job_application_state.sql`
- `supabase/migrations/20260721223000_restore_saved_job_history_visibility.sql`
- `supabase/migrations/20260721224500_restore_saved_job_embed_policy.sql`
- `supabase/migrations/20260721230000_add_owner_scoped_saved_jobs_rpc.sql`
- `supabase/migrations/20260721233000_fix_job_safety_array_initialization.sql`
- `supabase/migrations/20260721234500_correct_message_safety_volatility.sql`

## Generated and maintained Play documentation

- `docs/release/MORT_FRONTEND_COMPLETION_MATRIX.md`
- `docs/play/MORT_PLAY_SDK_DATA_INVENTORY.csv`
- `docs/play-final/MORT_ACCOUNT_DELETION_DECLARATION.md`
- `docs/play-final/MORT_ADS_DECLARATION_FINAL.md`
- `docs/play-final/MORT_APP_ACCESS_COPY_PASTE.md`
- `docs/play-final/MORT_APP_ACCESS_FINAL.md`
- `docs/play-final/MORT_APP_CONTENT_ANSWERS.md`
- `docs/play-final/MORT_CHILD_SAFETY_DECLARATION.md`
- `docs/play-final/MORT_CLOSED_TEST_RELEASE_NOTES.txt`
- `docs/play-final/MORT_CONTENT_RATING_FINAL_WORKBOOK.md`
- `docs/play-final/MORT_DATA_SAFETY_FINAL_WORKBOOK.md`
- `docs/play-final/MORT_FINAL_ASSET_MANIFEST.md`
- `docs/play-final/MORT_FINAL_CHANGED_FILES.md`
- `docs/play-final/MORT_FINAL_TECHNICAL_HANDOFF.md`
- `docs/play-final/MORT_FINANCIAL_FEATURES_DECLARATION_FINAL.md`
- `docs/play-final/MORT_FULL_DESCRIPTION_FINAL.txt`
- `docs/play-final/MORT_NETLIFY_LEGAL_DEPLOYMENT.md`
- `docs/play-final/MORT_PERMISSION_DECLARATION_FINAL.md`
- `docs/play-final/MORT_PLAY_CONSOLE_MASTER_CHECKLIST.md`
- `docs/play-final/MORT_PRODUCTION_ACCESS_APPLICATION_DRAFT.md`
- `docs/play-final/MORT_PRODUCTION_PILOT_RELEASE_NOTES.txt`
- `docs/play-final/MORT_REVIEW_ACCOUNT_MAINTENANCE.md`
- `docs/play-final/MORT_REVIEW_FEATURE_MAP.md`
- `docs/play-final/MORT_REVIEWER_WALKTHROUGH.md`
- `docs/play-final/MORT_SHORT_DESCRIPTION_FINAL.txt`
- `docs/play-final/MORT_STORE_CONTACT_FIELDS.md`
- `docs/play-final/MORT_STORE_LISTING_FINAL.md`
- `docs/play-final/MORT_TARGET_AUDIENCE_FINAL_WORKBOOK.md`

## Physical-device and closed-test operations documents

- `docs/device-test/MORT_CRASH_REPORT_TEMPLATE.md`
- `docs/device-test/MORT_DEVICE_RESULT_TEMPLATE.csv`
- `docs/device-test/MORT_DEVICE_TESTER_INSTRUCTIONS.md`
- `docs/device-test/MORT_PHYSICAL_ANDROID_TEST_MATRIX.md`
- `docs/device-test/MORT_RELEASE_BLOCKER_RULES.md`
- `docs/closed-test/MORT_14_DAY_CALENDAR.md`
- `docs/closed-test/MORT_DAILY_SCENARIOS.md`
- `docs/closed-test/MORT_DEFECT_TRIAGE_PROCESS.md`
- `docs/closed-test/MORT_PRODUCTION_ACCESS_RESPONSES.md`
- `docs/closed-test/MORT_TESTER_FEEDBACK_FORM.md`
- `docs/closed-test/MORT_TESTER_GOOGLE_GROUP_SETUP.md`
- `docs/closed-test/MORT_TESTER_OPT_IN_GUIDE.md`
- `docs/closed-test/MORT_TESTER_RETENTION_TRACKER.csv`

## Generated legal/support site

- `web/public/_headers`
- `web/public/_redirects`
- `web/public/accessibility/index.html`
- `web/public/account-deletion/index.html`
- `web/public/assets/account-deletion.js`
- `web/public/assets/public-config.js`
- `web/public/assets/site.css`
- `web/public/child-safety-standards/index.html`
- `web/public/community-guidelines/index.html`
- `web/public/contact/index.html`
- `web/public/index.html`
- `web/public/payment-disputes/index.html`
- `web/public/privacy/index.html`
- `web/public/prohibited-jobs/index.html`
- `web/public/release-status.json`
- `web/public/safety/index.html`
- `web/public/support/index.html`
- `web/public/terms/index.html`
- `web/public/terms-of-use/index.html`

## Final generated evidence and deliverables

- `build/play/final-production-pilot-readiness.json`
- `build/play/reports/aab-verification.txt`
- `build/play/reports/final-production-pilot-artifacts.json`
- `build/play/reports/legal-site-validation.json`
- `build/play/reports/store-asset-validation.txt`
- `build/play/store-assets/**`
- `mort-play-production-pilot-final.aab`
- `mort-play-production-pilot-final-qa.apk`
- `mort-play-production-pilot-final-source-clean.zip`
- `mort-play-final-console-answer-package.zip`
- `mort-play-final-store-assets.zip`
- `mort-play-final-review-package.zip`
- `mort-play-final-legal-support-site.zip`
- `mort-play-final-closed-test-operations.zip`
