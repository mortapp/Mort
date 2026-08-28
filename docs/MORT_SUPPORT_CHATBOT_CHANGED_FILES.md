# MORT Support Chatbot Changed Files

This inventory covers Part B support-assistant work. Part A files are listed in
`MORT_SECURE_SESSION_PERSISTENCE_0_9_10_REPORT.md`.

## Flutter

- `flutter_mort/pubspec.yaml`
- `flutter_mort/pubspec.lock`
- `flutter_mort/lib/core/routing/app_router.dart`
- `flutter_mort/lib/data/repositories/providers.dart`
- `flutter_mort/lib/data/repositories/support_assistant_repository.dart`
- `flutter_mort/lib/features/support/support_assistant_screen.dart`
- `flutter_mort/lib/features/support/support_screens.dart`
- `flutter_mort/test/support_assistant_contract_test.dart`
- `flutter_mort/test/support_assistant_widget_test.dart`

## Supabase Configuration And Shared Runtime

- `supabase/config.toml`
- `supabase/functions/_shared/observability.ts`
- `supabase/functions/_shared/support_eval_cases.ts`
- `supabase/functions/_shared/support_runtime.ts`

## Edge Function Entrypoints

- `supabase/functions/support-chat/index.ts`
- `supabase/functions/support-intent-classify/index.ts`
- `supabase/functions/support-kb-search/index.ts`
- `supabase/functions/support-create-ticket/index.ts`
- `supabase/functions/support-escalate/index.ts`
- `supabase/functions/support-tool-execute/index.ts`
- `supabase/functions/support-upload-authorize/index.ts`
- `supabase/functions/support-feedback/index.ts`
- `supabase/functions/support-report-ai-response/index.ts`
- `supabase/functions/support-admin-copilot/index.ts`
- `supabase/functions/support-safety-triage/index.ts`
- `supabase/functions/support-retention-cleanup/index.ts`
- `supabase/functions/support-evaluation-runner/index.ts`

## Migrations

- `supabase/migrations/20260729195632_mort_support_chatbot_foundation.sql`
- `supabase/migrations/20260729201015_mort_support_chatbot_rpc_hardening.sql`
- `supabase/migrations/20260729211932_mort_support_provider_rate_limit.sql`
- `supabase/migrations/20260729212144_mort_support_internal_auth_probe.sql`
- `supabase/migrations/20260729212722_mort_support_safety_priority_hardening.sql`
- `supabase/migrations/20260729214636_mort_support_adversarial_triage.sql`
- `supabase/migrations/20260729215533_mort_support_evaluation_classifier_fixes.sql`
- `supabase/migrations/20260729215937_mort_support_postgres_word_boundaries.sql`
- `supabase/migrations/20260729224551_mort_support_global_provider_budget.sql`

## QA And Packaging

- `scripts/feature-qa-helpers.mjs`
- `scripts/qa-support-chatbot.mjs`
- `scripts/qa-support-global-budget.mjs`
- `scripts/audit-support-chatbot-remote.mjs`
- `scripts/audit-support-evaluation.mjs`
- `scripts/qa-android-api36-launch.ps1`
- `scripts/run-android-native-integration.ps1`
- `scripts/sensitive-file-scan.ps1`
- `scripts/package-support-chatbot-0.9.11.ps1`

## Documentation

- `docs/MORT_SUPPORT_CHATBOT_BASELINE.md`
- `docs/MORT_SUPPORT_CHATBOT_IMPLEMENTATION_REPORT.md`
- `docs/MORT_SUPPORT_CHATBOT_CHANGED_FILES.md`
- `docs/MORT_SUPPORT_CHATBOT_SECURITY_REVIEW.md`
- `docs/MORT_SUPPORT_CHATBOT_PRIVACY_REVIEW.md`
- `docs/MORT_SUPPORT_CHATBOT_AI_EVALUATION_REPORT.md`
- `docs/MORT_SUPPORT_CHATBOT_RELEASE_CHECKLIST.md`

