# QA Findings — 2026-11-19/20

Severity: P0 = blocks release or a core flow; P1 = security, compliance or financial risk; P2 = defect; P3 = minor.
Scope: the QA project `ckcxakhxqlkhppsxxjhv`, plus **read-only** checks of production `jxbnrkasktbhtiujkhay`. Nothing in production was changed.

| ID | Sev | Area | Finding | Evidence | Recommended action / decision needed |
|---|---|---|---|---|---|
| F-01 | P0 | iOS (PR #109) | Commit `9237e094` truncated `ios/MORTIOSV8/Services/LiveRepositories.swift` from 1,944 to 292 lines (−1,634), removing all live repositories. No live recovery-session or `updatePassword` path is left, and the file is still truncated at head `fff15e5`. CI does not compile iOS on this branch: the iOS workflows trigger only on `codex/ios-v8-integration` or tags. | `IOS_RECOVERY_COMPATIBILITY_REVIEW_2026-11-19.md`; `git diff --numstat` | Restore the file from the parent commit and re-apply only the intended changes. Get an iOS compile run (needs separate approval). **Blocks merging #109.** |
| F-02 | P0 | Jobs / completion (production too) | `private.job_execution_gate` requires `profiles.verification_status = 'approved'`, but `mort_review_verification_case` only ever sets `'verified'`, and nothing sets `'approved'`. No verified user can start or finish a job. The function body is identical in QA and production (same md5), and production teens are all `verified` or `rejected`. The gate also requires a live Stripe payment intent. | jobs.jsonl `ASG-GATE`; matrix `CMP-01` (BLOCKED) | Align the gate with the `'verified'` status, or have reviews set `'approved'`, in a reviewed migration. The Stripe dependency is the owner's. No fake completion rows were inserted. |
| F-03 | P1 | Activation (production lineage) | D2–D6 reproduced in QA before `20261116120000`: <ul><li>admin activation ignores onboarding and legal completion (TEEN2 activated with `onboarding_completed_at` null, FX-TEEN2-07/08);</li><li>guardians could not be activated, so `accept_guardian_invite` was unreachable;</li><li>a pending teen could not skip guardian setup.</li></ul>`20261116120000` fixes these in QA. | fixtures.jsonl, guardian.jsonl | Approve `20261116120000` for production (pending). Production has one active guardian activated by an unknown path, which needs an audit. |
| F-04 | P1 | RevenueCat | The `environment` field is ignored: a SANDBOX event granted `mort_adult_pro`. | RC-ENV | Persist `environment`, and reject or segregate non-production events in production. |
| F-05 | P1 | Google Play RTDN | Real Pub/Sub push (OIDC JWT) cannot send `x-mort-rtdn-secret`, so production RTDN would always 401. The duplicate check is racy and the insert is unchecked. | GP-03; source | Verify the Pub/Sub OIDC token, and add a unique constraint with `ON CONFLICT`. |
| F-06 | P1 | Production schema gaps | Production lacks `request_account_deletion` (and the other client deletion RPCs), `process_revenuecat_provider_event`, and `process_identity_verification_provider_event_v2`. The corresponding Edge Functions would fail in production. | read-only production query 2026-11-20 | Review the three QA port migrations for production, and decide on identity v2 versus retiring the legacy webhook. |
| F-07 | P1 | Account deletion / legal | More than 50 RESTRICT FKs mean most onboarded accounts go to `retention_review`. There is no defined de-identification or retention matrix. | DEL-RUN, DEL-DB | Legal or product decision on the retention matrix. |
| F-08 | P2 | Identity (legacy webhook) | It targets a v2 RPC that does not exist anywhere, and accepts only `environment:"production"`. | IDV-01/07 (BLOCKED), IDV-06 | Port identity v2 or retire the function. |
| F-09 | P2 | Auth / email | QA's built-in mailer allows 2 emails per hour, and raising it requires custom SMTP. In this run: <ul><li>4 of 6 guarded signups hit 429;</li><li>admin magiclink confirmation of an **unconfirmed** signup cleared `encrypted_password` (GoTrue behaviour, not the triggers);</li><li>invite verification returned 500.</li></ul> | fixtures.jsonl | Configure QA SMTP for realistic signup testing, and confirm production SMTP limits. |
| F-10 | P2 | Messaging / guardian | Thread `guardian_id` is null, and the linked guardian (GUARDIAN1) cannot see TEEN1's thread with ADULT1. | messaging.jsonl | Product decision: should guardians have read access to teen threads? If so, populate `guardian_id`. |
| F-11 | P2 | Onboarding (QA-only RPC) | `request_my_role_activation_v1` returns `role_not_set` for guardians. | FX-GUARDIAN1-RQ | Fix or remove the QA-only RPC. |
| F-12 | P3 | password-guard | Signup checks only the DOB format, so a future DOB passes to GoTrue. Age is enforced later in onboarding. | PW-22-NOTE | Add a plausibility check (not in the future; age 13 or older). |
| F-13 | P3 | account-deletion-processor | A malformed body returns 500 `deletion_claim_failed` instead of 400. No state change. | DEL-04 | Map parse errors to 400. |
| F-14 | P3 | Auth UX | Bypass attempts surface from GoTrue as a generic 500. This is fail-closed and acceptable. | PW-01… | None required. |
| F-15 | Info | QA parity | QA was missing legal documents and versions, the release-control row, and school email domains. These were added as QA fixtures (see the change log). | — | Keep the QA seed in sync with production configuration. |

## Not tested / blocked

- **Stripe** (payments, transfers, payouts): owned by the user and excluded by instruction.
- **Job start/complete:** blocked by F-02 and the Stripe dependency.
- **Google Play valid RTDN:** needs `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`.
- **Identity valid-event processing:** blocked by F-08.
- **Server-side log inspection:** the QA logs API returned no rows, so redaction was verified by source review only.
