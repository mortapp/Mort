# MORT Launch Readiness Audit — 2026-11-16

Read-only inspection of production `jxbnrkasktbhtiujkhay`, the repository, and
mortapp.org on 2026-11-16 (evening, America/Indianapolis). This document makes no
production changes. Related PRs: #108 (replica acceptance, authorization, onboarding
fixes), #109 (server-enforced passwords), #110 (disaster recovery).

**Assessment: Not ready.** Several production blockers are open. They are not
code-only: most need owner approval to apply prepared changes, or owner and human
action that no code change can supply.

## Production state verified today

| Item | Verified state |
| --- | --- |
| Plan | Free. No platform backups, no PITR, no native leaked-password protection. |
| Migrations | 114 in ledger, head `20261115005234`. None of the 2026-11-16 migrations are applied. |
| Auth users | 12, all email-confirmed; newest 2026-11-14. Providers: email, Google. Sign-up enabled. |
| Staff | `private.user_roles`: 3 × admin, **0 moderators**. |
| Edge Functions | **30 deployed.** 25 were created and 2 updated between 01:20:32 and 01:22:49 UTC on 2026-11-17 (20:20–20:23 local on 2026-11-16). This was **not** done by this session. The deployed source is byte-identical to `main` for every function compared (leaked-password-check, send-push, account-deletion-processor, verification-provider-event, avatar-url, identity-verification-webhook, document-vault-access). |
| RPC / schema contract | Many RPCs and tables that the deployed functions and the Flutter app call are **absent** in production. Examples: `support_internal_authorize`, `service_fail_account_deletion_request`, `request_document_vault_access`, `process_identity_verification_provider_event_v2`, `record_google_play_purchase_verification`, table `notification_events`. Production has 103 `public` functions. |
| iOS key | `ios/MORTIOSV8/Config.swift` ships `sb_publishable_Q4uD…` → **401** from production Auth. The production key `sb_publishable_DTbj…` → 200. |
| Website | `/`, `/legal/privacy`, `/legal/terms`, `/safety`, `/login`, `/signup` → 200. **No account-deletion page** (`/account-deletion`, `/legal/account-deletion`, `/delete` → 404). |
| Legal | Published: Terms V5 (2026-11-11), Privacy, Community, Safety (2026-10-29). The V5 counsel reference reads "operator-confirmed approval" for the V4/V5 revisions. Only V3's approval has a hashed evidence artifact. |

## P6 — Notifications, push, Android, iOS

| Area | Finding | Severity |
| --- | --- | --- |
| Push delivery | `send-push` is now deployed, but it writes `public.notification_events`, which does not exist in production, so every push call fails. The Flutter client uses `firebase_messaging`, and no FCM/APNs server credential was verifiable. **Push is not functional in production.** In-app `public.notifications` exists. | Blocker if push is a launch feature; otherwise document as unavailable. |
| Account deletion | `account-deletion-processor` is deployed but **crashes at boot** (HTTP 500 `WORKER_ERROR`): the worker secrets are not configured, and its RPC `service_fail_account_deletion_request` is missing. There is no public deletion URL. **Google Play's account-deletion requirement is not met.** | **Production blocker (Play policy).** |
| Unauthenticated endpoints | Probed with an empty POST and no credentials: `google-play-rtdn` 401, `revenuecat-webhook` 503 not configured, `identity-verification-webhook` 503 disabled, `account-deletion-processor` 500 (crash before processing). Code review shows each one requires a shared secret or signature compared in constant time, so they **fail closed**. | OK (fail closed) |
| Android | Flutter `0.9.16+111`, `com.mortapp.mobile`, minSdk 24, targetSdk 36, release signing via `signingConfigs.release`. No `google-services.json` committed (config injected at build time; not verified). **The AAB was not rebuilt or modified, and its contents were not inspected.** Any build from current `main` has the fail-open client password check and the D1 signup defect (every email signup fails `MORT_DOB_REQUIRED` against production) until a build including #109 ships. | **Blocker** (D1 breaks email signup for builds from `main`). |
| iOS (audit only) | The publishable key is rejected (401), so every Auth/API call from the iOS build fails. With #109's triggers applied, iOS password signups would also be blocked until the Swift client uses `password-guard`. **No Swift or signing change was made.** | **Blocker for iOS launch.** |
| School-domain rules | 2 school domains active (from the earlier audit). Teen signup works only for those domains. | Product decision |

## P7 — Legal and operations

| Area | Finding |
| --- | --- |
| Terms V5 | Published. The approval reference for V4/V5 is **operator-confirmed**, with no stored counsel artifact (unlike V3, which has a SHA-256 of the email screenshot). **Not independently evidenced.** The owner should store the counsel email for V4/V5, or have counsel re-confirm. |
| Privacy policy | Published (2026-10-29, counsel email evidence recorded). It covers deletion rights in general terms. No backup-retention statement was found; the DR runbook (#110) flags this for counsel. |
| Account-deletion URL | Missing (see P6). |
| Moderation staffing | **0 moderators** in production, and 3 admin accounts. There is no evidence of staffed review coverage (identity evidence, role requests, safety reports) or an on-call rota. The replica tests prove the staff workflows work, not that anyone is staffing them. |
| Support channel | The Terms name `support@mortapp.org`. Its monitoring was not verifiable. |
| Email delivery | Supabase default SMTP (low hourly limit). No custom SMTP was verifiable. A launch spike would exhaust confirmation and recovery email. |
| Backups | None that cover Auth, private tables or Storage until #110's job is enabled (Free plan). |
| Stripe / payments | Out of scope (owner-managed). Not inspected beyond confirming nothing here changes it. |

## Open PR triage (not merged; no stale stack merged blindly)

| PR | Status / recommendation |
| --- | --- |
| #108 → #109 → #110 | New stack. CI green on #108 and #109 at the time of writing; #110 CI pending. Review and merge in order. Production migrations need separate approval. |
| #107 | Superseded for DR by #110 (comment posted). |
| #106 | Verification-only; closed earlier; not merged. Its regression is covered in #108's authz suite. |
| #91 | Draft. HIBP parts superseded by #109; the credential-scanning parts remain reviewable. |
| #84, #69, #72, #73, #74, #54, #53, #52 | Drafts from 2026-11-04..13. Several target the deleted project or outdated stacks. Close or rebase individually; do not merge. |
| #34–#43 | Open since 2026-10-31/11-01 and written against the generic migration chain, not the production baseline. **Not individually re-triaged in this pass.** Each needs checking against production before it is closed or ported. |
| #17–#32, #45–#48 | Older drafts / stacked feature branches. Candidates to close. |

## Production blockers (summary)

1. **Email signup broken for Flutter builds from `main` (D1).** Fixed in #109; needs a release build.
2. **Account deletion non-functional, and no deletion URL** (Play policy).
3. **Schema/RPC contract gap.** Production lacks many RPCs and tables that `main` (app and functions) requires. The deployed functions fail at runtime.
4. **Leaked-password protection is not enforced.** #109 is ready; it needs approval for the Vault secret, function deploy and migration.
5. **No moderator, and no evidence of review staffing**, for a marketplace with minors.
6. **No usable backup of Auth, private data or Storage.** #110 is ready; it needs secrets and approval.
7. **iOS build ships a rejected API key** (iOS only).
8. **Onboarding and staff-boundary fixes D2–D6** (#108 migration `20261116120000`) need approval.

## External gates

- Counsel evidence for Terms V4/V5.
- Play Console: data-safety form, deletion URL, closed-test requirements.
- Apple review: after the iOS key fix.
- Moderator hiring or appointment.
- SMTP provider.
- Pro upgrade decision (native HIBP, daily backups, PITR).
- Stripe (owner).
