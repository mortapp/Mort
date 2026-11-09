# MORT Production Readiness

**Assessment date:** 2026-11-08
**Production target:** Supabase `jxbnrkasktbhtiujkhay`; website `https://mortapp.org`; Android `com.mortapp.mobile`
**Decision:** **NOT READY for public production.** A signed Android prelaunch AAB exists; legal, backup/restore, Guardian authorization, authenticated QA, provider, device, and operational gates remain open.

This report distinguishes source/CI evidence from hosted authenticated behavior. Production has only been inspected read-only during this execution. Do not treat a proposed migration, local pgTAP result, mocked API test, or CI device-test APK as hosted acceptance.

## Current verified state

- Production Supabase project metadata: ACTIVE_HEALTHY; Postgres `17.11.0.003`.
- Production migration ledger: 73 rows, latest `20261102113314`.
- Read-only `get_release_mode_status()`: `production_public`, maintenance `false`, real document collection `false`, public marketplace `false`.
- Isolated QA project: ACTIVE_HEALTHY; Postgres `17.11.0.011`. Read-only aggregate counts: 0 Auth users, profiles, Guardian links, applications, jobs, and Storage objects.
- Protected QA worktree `codex/qa-target-guard-20261104` remains unchanged with 24 dirty paths.
- No production DDL, user data, Auth setting, RLS, provider setting, release control, deployment, or merge was changed.

## Steps 1–12

| Step | Status | Evidence and next action |
|---|---|---|
| 1. PR #69 backup and recovery review | **IN PROGRESS** | PR [#69](https://github.com/mortapp/Mort/pull/69), head `0fbe67a4f98401c705253faea03f4910f1d0270d`, remains draft. Its encrypted feature schema/data snapshots are partial: no complete Auth export or Storage object bytes, and no restore has run. CI passed seven non-provider jobs; two provider jobs skipped. Next: independent review, then an approved complete backup/restore drill. See [Disaster Recovery Runbook](DISASTER_RECOVERY_RUNBOOK.md). |
| 2. Guardian authorization/privacy | **IN PROGRESS** | PR [#71](https://github.com/mortapp/Mort/pull/71), head `2b1a7571ac56b63ab88d9e8e7528c2514c58f124`, remains draft/unmerged. It narrows the outer application-row predicate to match Guardian disclosure eligibility. Current CI passed seven jobs; provider jobs skipped. Local production-baseline pgTAP evidence is 49/49. Hosted authenticated coverage is blocked: isolated QA has no personas or fixtures. Next: independent security review and authorized isolated authenticated cases before any merge. |
| 3. Android release / PR #72 | **IN PROGRESS** | Draft [PR #72](https://github.com/mortapp/Mort/pull/72), head `941d5324011ad48b9afb011047142d5b5f1701c5`, is stacked on #69. CI run [42535222096](https://github.com/mortapp/Mort/actions/runs/42535222096): seven jobs passed, two provider jobs skipped. Signed prelaunch AAB was rebuilt and verified; no Play upload or device acceptance occurred. Play Console upload/App Signing certificate relationship remains unverified. Details: [Mobile Release Acceptance](MOBILE_RELEASE_ACCEPTANCE.md). |
| 4. Supabase Auth SMTP / Resend | **IN PROGRESS** | Owner reports Resend credential rotation is already handled; no repeat rotation requested or performed. Prior read-only account check found `mortapp.org` sending-enabled. Active tracked app/Edge Function code has no Resend call site; a Vercel `RESEND_API_KEY` variable was previously observed but is not consumed by tracked code. Supabase Auth SMTP and delivery remain unverified because available Supabase access does not expose Auth SMTP settings and QA has no authorized email persona. Next: owner checks Auth → SMTP settings, then runs authorized signup, confirmation, and recovery email tests. |
| 5. Website/mobile auth and role isolation | **BLOCKED** | Static mobile production callback is PKCE `com.mortapp.mobile://app/auth-callback`; prelaunch build disables Google auth. Isolated QA has no accounts. No authenticated teen/adult/Guardian/admin, session-revocation, suspension, or cross-account tests were run. Next: provision legally approved synthetic personas through normal workflows and validate backend authorization. Website work is separate; handoff is in [External Release Gates](EXTERNAL_RELEASE_GATES.md). |
| 6. Physical Android acceptance | **BLOCKED** | `adb devices` returned no attached device. CI packaged a device-test APK; that is not physical-device testing. Next: authorized Android device and full acceptance matrix in [Mobile Release Acceptance](MOBILE_RELEASE_ACCEPTANCE.md). |
| 7. iOS readiness | **BLOCKED** | Static config uses bundle ID `com.mortapp.mobile` and deployment target iOS 18.0. No macOS/Xcode host or Apple signing credentials are available here; no archive or device test exists. Next: authorized Mac/Xcode and Apple Developer signing operator. |
| 8. Backup and disaster recovery | **BLOCKED** | No full database/Auth/Storage backup or successful isolated restore was demonstrated. PR #69 expressly describes its snapshot as partial and says no backup was run. Next: owner-approved backup coverage and isolated restore with integrity evidence. |
| 9. OAuth, identity, and teen verification | **BLOCKED** | Production-targeted prelaunch AAB has Google auth, identity verification, and real document collection off. Google client/callback dashboard configuration and real login are unverified. No approved provider sandbox, reviewer, or evidence fixtures are available. Next: verify OAuth in provider dashboards and obtain approved provider/legal/staff setup. |
| 10. Legal, trust, and safety | **BLOCKED** | The AAB records Terms, Privacy, Community Guidelines, and Safety Rules as `draft-2026-07`. Business/legal approval, Guardian terms, support/moderation staffing, and incident readiness are not evidenced. Next: authorized legal approval and operational sign-off; do not substitute engineering approval. |
| 11. Security and production acceptance | **IN PROGRESS** | Existing 59-function review is preserved; Issue #70 has a focused proposed fix and local/CI pgTAP evidence. CI secret/security checks pass on #72, but hosted authorization, SMTP, recovery, device, and provider tests remain absent. A previously exposed production database password has no independently verified rotation record; treat as compromised until the owner confirms rotation. Findings are ranked in [Production Security Audit](PRODUCTION_SECURITY_AUDIT.md). |
| 12. Controlled launch preparation | **BLOCKED** | Production controls remain closed and no release was activated. Public rollout cannot proceed until mandatory safety, legal, backup, authenticated, platform, and operations gates pass. Next: close the blockers in [External Release Gates](EXTERNAL_RELEASE_GATES.md), then perform final change-controlled verification. |

## Test evidence

- PR #72 CI: public site, Flutter authoritative (format, analyzer, payment integration test, full Flutter suite, provider-disabled web build, secret scan), Expo reference, Stripe contracts, Android device-test APK packaging, local Stripe regression, and Stripe security freeze passed. Stripe hosted regression and provider E2E were skipped.
- Full Flutter suite on the release branch: **617 passed, 2 skipped, 0 failed**.
- AAB project verifier: passed signer match to protected local upload certificate, package ID, version, min/target SDK, forbidden permission, unexpected exported component, and signed-artifact checks.
- AAB values independently rechecked: 84,049,810 bytes; SHA-256 `0EC6E2EFD4A6FF5BAC98AD33C7F73E40F169BF6740786556075467B9648808B7`.
- PR #69 CI: seven non-provider jobs passed; hosted/provider jobs skipped. PR #71 CI: seven jobs passed; hosted/provider jobs skipped. PR #15 in `mort-web`: its `validate` check passed.
- No iOS build, physical-device run, authenticated hosted QA, Resend delivery, or complete restore drill is claimed.

## PRs and website handoff

- [PR #69](https://github.com/mortapp/Mort/pull/69): production target and guarded operator/backup tooling; draft, review and complete restore evidence outstanding.
- [PR #71](https://github.com/mortapp/Mort/pull/71): Guardian application-reader authorization; draft, security review and authenticated QA outstanding.
- [PR #72](https://github.com/mortapp/Mort/pull/72): signed prelaunch AAB gate; draft, stacked on #69, CI green with provider jobs skipped.
- [mort-web PR #15](https://github.com/mortapp/mort-web/pull/15): prelaunch login/signup claims; draft, scoped validation passed, not deployed. Website integration must remain coordinated with VS Code Desktop.
- Current Vercel project metadata reports its latest production deployment as `READY`; no deployment was created or promoted here.

## Decision

**NOT READY for public production.** The code/CI work can be reviewed. No activation is approved by this report. Keep marketplace publishing, document collection, payments, and Stripe disabled until the corresponding gates are reviewed and explicitly approved.
