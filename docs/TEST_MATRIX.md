# Four-Step Onboarding Test Matrix

| Area | Durable check | Current result |
| --- | --- | --- |
| Exact four-step model | `flutter_mort/test/onboarding_v2_model_test.dart` | Pass |
| Four-screen teen UI | `flutter_mort/test/compact_onboarding_test.dart` | Pass |
| Shipping-copy exclusions | Review-screen assertions in `compact_onboarding_test.dart` | Pass |
| Notification OS truth labels | `flutter_mort/test/onboarding_production_copy_test.dart` | Pass |
| Review-screen native permission state | `compact_onboarding_test.dart` | Pass |
| DOB immutable-save confirmation | `compact_onboarding_test.dart` | Pass |
| Legal handoff to v2 completion | `safety_rules_legal_acceptance_test.dart` | Pass |
| Expo production exclusion | `pnpm qa:production-client` | Pass |
| Migration syntax against hosted schema | Apply inside `BEGIN`, then `ROLLBACK` | Pass |
| Canonical server resume and saves | `pnpm qa:onboarding-v2:transaction` | Pass |
| Same-payload replay / changed-payload rejection | Rollback-only backend harness | Pass |
| Malformed completion session | Rollback-only backend harness | Denied as required |
| Direct completion UPDATE/UPSERT guard | Rollback-only backend harness | Denied as required |
| Authenticated PostgREST UPDATE/UPSERT | Deployed `pnpm qa:onboarding-v2` | Denied as required before suite stop |
| Two-device resume / concurrent Finish | Deployed `pnpm qa:onboarding-v2` | Resume passed; Finish failed closed on unavailable legal versions, so successful completion concurrency remains unverified |
| Existing completed-user compatibility | Hosted canonical evaluator audit | Fail: 24 historical completed profiles reopen; 7 are non-test profiles |
| Migration reconciliation parity | `pnpm qa:migration-reconciliation-parity` plus final CLI dry run | Pass: 193 local/hosted timestamps match; remote up to date |
| Current legal versions | Rollback-only backend harness | Completion correctly blocked: 10 required teen policy versions unpublished |
| Full Flutter suite | `flutter test` | Pass: 424 tests, 2 skipped |
| Flutter analyzer | `flutter analyze --no-pub` | Pass: no issues found |
| Debug Android compilation | `flutter build apk --debug` | Pass |
| Physical Samsung QA | Physical-device checklist | Not run; no physical-pass claim |

The rollback-only database harness creates isolated QA users, applies the migration in one database transaction, exercises the RPCs, rolls back all migration and profile changes, and removes only its own QA users.
