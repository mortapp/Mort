# MORT Feature Expansion QA Report

QA date: 2026-07-17

## Passed Existing QA Scripts

Seventeen applicable scripts completed successfully:

1. `qa-avatar-storage.mjs`
2. `qa-business-verification.mjs`
3. `qa-complete-multi-user-isolation.mjs` - 30/30 isolation checks
4. `qa-feature-expansion.mjs` - 15/15 unread/proof checks and 25 concurrent reads in 272 ms on the final run
5. `qa-flutter-auth-persistence.mjs` - static startup/session contract; real relaunch remains manual
6. `qa-flutter-data-isolation.mjs` - isolated 30-check hosted contract wrapper
7. `qa-guardian-optional.mjs`
8. `qa-job-applications.mjs`
9. `qa-job-lifecycle.mjs`
10. `qa-monetization-rls.mjs`
11. `qa-old-project-smoke.mjs`
12. `qa-rate-limits.mjs`
13. `qa-revenuecat-api.mjs`
14. `qa-revenuecat-config.mjs`
15. `qa-reviews.mjs`
16. `qa-saved-jobs.mjs`
17. `qa-username-credits.mjs`

The isolated scripts created random temporary credentials, set explicit test-account profiles, ran cross-user checks, and removed only users created by that run. They did not use real-user accounts.

## Not Applicable In This Pass

- `qa-rls.mjs`: guarded for localhost-only legacy fixtures; no local Supabase/Docker target was used.
- `qa-smoke.mjs`: intentionally refuses project `rakjydmgwwgtdislanbt`; `qa-old-project-smoke.mjs` is the matching hosted-project check and passed.
- `qa-old-project-rls.mjs`: tied to persistent rebuild emails and `MORT_REBUILD_TEST_PASSWORD`, which is absent; isolated 30-check QA supersedes this fixture without resetting account passwords.
- `qa-revenuecat-webhook.mjs`: authorized delivery requires `REVENUECAT_WEBHOOK_AUTH_HEADER`, which is correctly absent from the local client environment. Negative auth and integration inventory were covered elsewhere, but an authorized webhook event was not rerun in this pass.

## Failures Fixed During QA

- The proof fixture initially used a `.png` path even though the hardened contract requires canonical JPEG. The fixture now uses real JPEG bytes and a `.jpg` path.
- The converted monetization/username isolated tests initially read nonexistent `saveJob().jobId`; the shared helper's actual contract is `saveJob().result.job.id`. Both scripts were corrected and passed on rerun.

No authorization rule was weakened to make a test pass.
