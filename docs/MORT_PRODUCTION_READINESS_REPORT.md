# MORT Production Readiness Report

Recorded: 2026-07-28 (America/Indianapolis)

## Verdict

**SIGNED CLOSED-TEST BUILD AND API 36 LAUNCH SMOKE VERIFIED; END-TO-END NATIVE QA BLOCKED-EXTERNAL**

- Closed-test Android AAB/APK: PASS for build, signing, package identity, release configuration, manifest policy, and static verification.
- Android API 36 launch smoke: PASS on the available headless emulator after changing to the supported `auto-no-window` graphics backend. This is not a full journey or device-matrix pass.
- Remote backend: PASS for linked migration alignment, account-deletion worker QA, zero-fee/payments-disabled QA, and the 31-script Supabase regression.
- Production pilot: BLOCKED-EXTERNAL on real Flutter remote push, real crash monitoring, native-device journeys, and operator evidence.
- Public production: BLOCKED-EXTERNAL. The public marketplace remains closed.
- iPhone/TestFlight/App Store: not tested or approved in this pass.

This report is not approval to publish to production or admit real teen/adult marketplace users.

## Scope and identity

| Item | Evidence |
|---|---|
| Branch | `production-readiness-0.9.7` |
| Starting commit | `f566885453786f1fbdea08291b1b646a5cabe1bc` |
| Authoritative client | `flutter_mort` |
| Version | `0.9.7+97` |
| Android package | `com.mortapp.mobile` |
| Supabase project | `rakjydmgwwgtdislanbt` |
| Upload certificate SHA-256 | `04:42:C2:21:38:B0:D6:23:F9:A6:F4:78:1A:44:2B:F4:A9:33:27:8F:AB:8E:85:76:74:4D:C1:FD:7C:33:4D:EF` |
| Baseline archive | 5,770,740 bytes; SHA-256 `9C94E44BD4C51BB7F609C9FF526B94F67C212949A4DC15B43CC651D1D7BB06B8` |

The tree contained attributed pre-existing design, reviewer, and reference-client changes. No unrelated work was reset.

## Audit remediation matrix

| Audit finding | Status | Evidence/result |
|---|---|---|
| Missing R8 rules | PASS | `flutter_mort/android/app/proguard-rules.pro`; release shrink builds pass |
| Signing environment mismatch | PASS | All release paths use `MORT_UPLOAD_*` through `android-signing-common.ps1` |
| Missing production profiles | PASS / gated | Separate closed, pilot, and public scripts; unavailable profiles fail closed |
| Public launch prevented | PASS safety control | Kill switch retained; public script is BLOCKED-EXTERNAL |
| Crash sink absent | BLOCKED-EXTERNAL | Production pilot refuses to build without a real provider |
| Flutter remote push absent | BLOCKED-EXTERNAL | Production pilot refuses to build without a real token/provider implementation |
| Identity verification disabled | BLOCKED-EXTERNAL | Public interaction remains closed; real ID collection disabled |
| Legal documents are drafts | BLOCKED-EXTERNAL | Lawyer-approved versions and clickwrap review are still required |
| Deletion was request-only | PASS for technical processor | Idempotent service-only Edge Function, retries, session revocation, storage deletion, Auth deletion, and QA added |
| No native E2E QA | BLOCKED-EXTERNAL | API 36 cold-launch smoke passed; full journeys, other API levels, physical device, and Play pre-launch report remain untested |
| Billing present while disabled | PASS | Billing packages/permission removed |
| Contradictory payment UX | PASS for launch boundary | Zero platform fee; payment handles removed; Stripe native SDK/routes hidden; payments disabled server-side |
| False distance matching | PASS for honest fallback | No radius-to-radius comparison; UI states that MORT does not calculate distance |
| Feed refetches on rebuild | PASS | Riverpod async family, immutable filters, refresh, and incremental pagination |
| Opaque adaptive icon | PASS static | Transparent adaptive foreground and Android 13 monochrome asset generated; device mask QA remains external |
| Reviewer compiled into production | PASS build boundary | Reviewer routes compile-gated; production verifier scans for reviewer identifier |
| Google sign-in promised while off | PASS | Disabled control hidden; production claims must remain absent |
| Weak release flags | PASS | Startup validation and explicit profile defines fail closed |
| Three client stacks ambiguous | PASS documentation | Root README names Flutter authoritative; Expo/Swift are reference only |
| Non-atomic payment preference | NOT-APPLICABLE | Personal payment preference collection/write flow removed |
| Missing operations evidence | BLOCKED-EXTERNAL | Runbooks exist; actual staffing, paging, provider telemetry, and exercises do not |
| Version code consumed | PASS | Increased from 96 to 97 |

## Backend changes and evidence

Four additive migrations were backed up, dry-run, applied, and remotely verified:

- `20260728220236_mort_payments_disabled_zero_fee.sql`
- `20260728221118_fix_payment_disabled_transportation_wrapper.sql`
- `20260728222202_account_deletion_processor_state_machine.sql`
- `20260728223111_account_deletion_storage_listing_rpc.sql`

Backup evidence is under the excluded local `backups` directory. The final pre-migration snapshot contained 258 relations, 288 policies, 414 functions, 115 migrations, and 2,880 rows; its data SHA-256 is `A50D...` in the local backup report metadata. Backups are intentionally excluded from Git and release archives.

Remote results:

- Migration alignment: PASS; 116 local and remote entries aligned.
- Database lint: completed with no error-level findings. Existing warnings remain for disabled identity-provider stubs and two explicit `text[]` initializer casts in the RevenueCat function. RevenueCat/IAP is absent from this launch build, and its atomic QA passed in the full regression.
- Payments-disabled QA: PASS, including forged fee rejection and wrapper regression.
- Account deletion QA: PASS, including unauthorized rejection, session revocation, owned-storage deletion, profile/Auth removal, and completed state.
- Final Supabase regression: PASS, 31 scripts in 415.8 seconds.
- Multi-user isolation: PASS, 30/30 cases.
- Public unrestricted policy: false.
- Production identity document collection: false.
- Guardian Mode: optional.

The remote project still contains 11 older QA accounts dated July 8-20. They were not deleted automatically because ownership and preservation intent require review before removal.

## Android artifacts

| Artifact | Size | SHA-256 | Result |
|---|---:|---|---|
| `build/play/mort-closed-test.aab` | 47,811,530 bytes | `6557251E1E55CA372357865CEB4D241BC7E3E95B2723224B14DF24626DDD1C95` | PASS |
| `build/play/mort-closed-test.apk` | 61,224,372 bytes | `B0F005D1DC80A56B770A42F80B3CA21953933C994FA06D5E99B7D0EC7028570A` | PASS |

The AAB verifier confirmed the upload certificate, package, version, min/target SDK, forbidden-permission absence, and exported-component allowlist. The APK passed signed-package QA and `zipalign -c -P 16 -v 4` for native-library 16 KB alignment. Obfuscation symbols are outside the repo at `%USERPROFILE%\MortSymbols\android\0.9.7+97`.

## Limited native launch evidence

- Device: generic `Medium_Phone_API_36.1` headless emulator.
- Install: signed closed-test APK installed successfully.
- Launch: cold launch reached `com.mortapp.mobile/.MainActivity`.
- Fatal scan: no AndroidRuntime or Flutter fatal entries during the successful probe.
- Screenshot: `artifacts/native-qa/mort-api36-launch.png`, 450,840 bytes.
- Screenshot SHA-256: `35A9DFC922AD29D82E79CEB58A7F6CD5FECEDDD0D99A086CA5345B9664C34466`.

Two preceding `swiftshader_indirect` attempts installed and started the app but the AVD transport closed before screenshot capture. The QA script was fixed so cleanup no longer masks the primary failure. The alternate `auto-no-window` backend produced the verified evidence. See `MORT_ANDROID_API36_LAUNCH_EVIDENCE_0_9_7.md`.

## Deferred plan-limited enhancement

Supabase leaked-password protection is **DEFERRED - PLAN-LIMITED SECURITY ENHANCEMENT**, not an unresolved code security bug. The Free plan does not expose the HaveIBeenPwned control.

Current mitigations are strong minimum password length, required complexity, Auth rate limiting, email verification, RLS, account restriction logic, and secure password reset.

Future task: **When Supabase is upgraded to Pro, enable leaked-password protection immediately and rerun Auth security advisors.** Do not spend money or change plan solely for this pass.

## Command ledger

| Command | Result |
|---|---|
| `flutter pub get` | PASS; removed Flutter Stripe and its four transitive packages after Billing packages had already been removed |
| `dart format --output=none --set-exit-if-changed lib test` | Initial FAIL on one new test wrap; formatted; final PASS across 167 files with 0 changes |
| `flutter analyze` | PASS; no issues in 188.4 seconds |
| `flutter test` | PASS; all 180 tests in final run |
| `flutter build web --release --dart-define=WEB_PREVIEW_MODE=true --dart-define=IAP_ENABLED=false --dart-define=ADS_ENABLED=false --dart-define=USE_TEST_ADS=true` | PASS; web build and Wasm dry run completed |
| `pnpm install` | PASS; lockfile already current |
| `pnpm check` | PASS |
| `pnpm lint` | PASS |
| `pnpm build` | PASS; Expo reference exported 48 static routes |
| `npx expo-doctor` | PASS; 20/20 checks |
| `pnpm audit --prod` | PASS; no known vulnerabilities |
| `flutter pub outdated` | PASS informational; 10 compatible upgrades are lockfile-held and several major/transitive updates need a separate regression pass |
| `npx supabase migration list --linked` | PASS; 116 local/remote migrations aligned |
| `npx supabase db lint --linked --level warning` | PASS with warnings; no error-level findings |
| `npx supabase db push --linked --dry-run` | PASS; remote database up to date, nothing pushed |
| `.\scripts\run-final-supabase-regression.ps1` | PASS; 31 scripts in 415.8 seconds |
| `node scripts/qa-redesign-backend.mjs` | PASS after transportation wrapper repair |
| `node scripts/qa-account-deletion-processor.mjs` | PASS after fixture/bucket/storage-listing repairs |
| `.\scripts\build-closed-test-aab.ps1` | PASS; signed, shrunk, obfuscated, verified AAB |
| `.\scripts\build-closed-test-apk.ps1` | PASS; signed, verified APK |
| `zipalign -c -P 16 -v 4 build\play\mort-closed-test.apk` | PASS; every native library aligned |
| `.\scripts\build-production-pilot-aab.ps1` | Expected FAIL/BLOCKED-EXTERNAL; no real push/crash providers |
| `.\scripts\build-production-public-aab.ps1` | Expected FAIL/BLOCKED-EXTERNAL; identity/legal/moderation/native/provider gates incomplete |
| `.\scripts\secret-scan.ps1` | PASS |
| `.\scripts\sensitive-file-scan.ps1` | Initial FAIL on new reviewed icon; exact-hash allowlist added; final PASS for 1,610 files, 49 media, 10 secret values |
| `.\scripts\windows-check.ps1` | PASS, including check/lint/build/Expo Doctor |
| `.\scripts\qa-android-api36-launch.ps1 -GpuMode auto-no-window` | LIMITED PASS; signed APK cold-launched, no fatal scan finding, screenshot captured |
| `.\scripts\package-production-readiness-0.9.7.ps1` | PASS; source ZIP and archive secret/privacy audit completed |

## Defects found and fixed

| Defect | Fix |
|---|---|
| `flutter_stripe` exported `StripeConnectDeepLinkInterceptorActivity` in a payments-disabled build | Removed the native SDK, compile-gated routes/buttons, and made the service fail closed |
| AAB verifier rejected AndroidX `ProfileInstallReceiver` without considering its signature-level `android.permission.DUMP` protection | Added an exact component-plus-permission allowlist; unknown exports remain fatal |
| AAB and APK release manifests used the same filename | Added artifact-kind-specific manifest names |
| Payments-disabled migration wrapper still allowed an obsolete transportation path | Added and applied a forward-only wrapper repair; remote QA passed |
| Deletion QA used the wrong bucket/MIME and could not list the private storage schema through Data API | Corrected fixture, added service-only listing RPC, redeployed worker, and passed actual deletion QA |
| Account deletion was only a request queue | Added service-only claim/complete/fail state machine, session revocation, storage/Auth deletion, retries, and redacted errors |
| New adaptive icon assets were not recognized by the privacy scanner | Added exact source hashes and narrow generated-icon patterns |
| API 36 QA cleanup masked the primary AVD disconnect | Made cleanup non-fatal and added explicit failure reporting/GPU selection |
| Root README identified legacy Expo as authoritative and described obsolete payment handles | Replaced it with the Flutter release boundary and current hosted-backend workflow |
| One new Dart test file was not formatter-clean | Applied `dart format`; immutable final format gate passed |

Earlier in the pass, two tests failed because they still expected the disabled Google control and enabled Stripe capability; the implementation was correct and the stale assertions were updated. The first long AAB wrapper invocation exceeded the command window, so its late artifact was independently inspected rather than claimed as a pass.

## External gates before real users

- Complete native journeys on API 24, 29/30, 35, and 36 plus a physical Android device and Play pre-launch report.
- Connect privacy-safe remote push and crash providers; verify token rotation, delivery, deep links, and alert routing.
- Contract an approved adult/identity verification process and review age/guardian rules.
- Obtain lawyer approval for terms, privacy, youth labor, tax, screening, consent, deletion, and emergency policies.
- Staff and train moderation with separation of duties, escalation coverage, appeals, and incident exercises.
- Reconcile exact AAB behavior with Play Data safety, target audience, app access, UGC, financial features, permissions, and account deletion declarations.
- Resolve or review old QA accounts before any real-user onboarding.

## Honest release boundary

The old project has been rebuilt and the remote backend has been verified. The signed closed-test Android artifacts and one API 36 launch smoke are verified. Native Android end-to-end/user-flow testing, the required API/device matrix, iPhone manual testing, TestFlight, App Store review, legal approval, teen-safety approval, identity-provider readiness, production push/crash telemetry, and staffed operations are not complete.


---

# Live production-readiness recheck — 2026-11-23

This addendum supersedes older status statements where the connected production/QA catalog or current GitHub/Vercel evidence differs. It is based on read-only checks of production Supabase project `jxbnrkasktbhtiujkhay`, hosted QA project `ckcxakhxqlkhppsxxjhv`, GitHub Actions, current PRs, and the Vercel `mort-web` project. No production writes, migrations, deployments, financial operations, signing, or store actions were performed.

## Current release verdict

**HOLD for Android, iOS, backend, website operations, and overall production release.**

## Production release controls and Stripe

Fresh repeated read-only checks of the single primary `public.mort_release_control` row show:

| Control | Current production value |
|---|---|
| Release mode | `production_public` |
| Maintenance mode | `false` |
| Public marketplace enabled | `true` |
| Real document collection enabled | `true` |
| Last updated | 2026-11-11 03:28:12 UTC |

The private Stripe runtime control row shows mode `disabled`; payments, connected onboarding, job funding, transfers, refunds, live mode, owner approval, connected-account approval, and payouts are all `false`.

**Owner decision required:** the public marketplace and real document collection flags are enabled despite the prior readiness report describing them as disabled. Do not assume the older report is current. No control was changed in this recheck.

## Production versus hosted-QA schema

Read-only `information_schema.columns` comparison for `public` and `private` found:

| Measure | Production | Hosted QA |
|---|---:|---:|
| Tables represented by columns | 70 | 118 |
| Columns | 797 | 1,369 |

The exact schema/table/column comparison found 572 columns present in QA but not production and zero production-only columns. QA has 48 tables not present in production. Important QA-only tables include account-deletion request/retention structures, job-payment obligations and payment-attempt/intent/settlement/transfer ledgers, financial documents, password attestation, RevenueCat, Play billing, and related audit/control tables.

Migration histories report 114 applied production migrations (latest version `20261115005234`) and 190 hosted-QA migrations (latest version `20261122153202`). Migration versions and some names were ported/renamed between environments, so raw version-count subtraction is not a promotion list. Use the actual schema diff and source-level migration mapping; do not blindly replay all QA migrations into production.

## Account deletion — confirmed production blocker

The production `account-deletion-processor` Edge Function is ACTIVE version 1, SHA-256 `ff4e25dbc8f29789cb136c3b42bed2f080fee8506353176f4f57c3ca73356963`. Hosted QA has version 2, SHA-256 `80cc24fc5a185b84ab6ba5d731828c43b174a0463a3780b2519c54297e18d8f9`.

The production worker source calls `service_claim_account_deletion_request`, `service_complete_account_deletion_request`, and related service RPCs. Read-only catalog checks confirm that production has no `public.account_deletion_requests` table and none of the required deletion service RPCs. Hosted QA has the request table and the service RPCs. Therefore the deployed production worker cannot complete its first claim call against the current production schema.

Additional gaps:
- Production worker v1 throws during module initialization if required secrets are missing; PR #125 changes this to a fail-closed configuration response.
- No production `cron` schema, `pg_cron`, or `pg_net` extension was found.
- No account-deletion scheduler declaration was found in the connected repositories.
- The default-branch QA processor harness still contains a hard-coded production project reference. The PR #125 branch pins the harness to isolated QA; do not run the default-branch harness.
- The public account-deletion page is a manual email path, not an automated deletion processor.

**Verdict: account deletion is not operational in production.** Do not invoke the production worker. The database contract, worker package, protected secrets, scheduler, retention policy, and hosted-QA lifecycle must be validated and promoted together under separate authorization.

## Guardian consent and teen activation

Production code inspection of `public.admin_set_account_status_v2` and `public.mort_review_role_request` found staff-role checks but no reference to the proposed mandatory teen guardian-consent table or new consent RPCs. The latter delegates to `private.mort_is_eligible_for_role_activation`, which is not the proposed mandatory consent gate.

- PR #126: 28 consent-specific disposable-replica assertions passed; draft only, not deployed.
- PR #129: read-only status display in an internal replica-test configuration; no consent actions or activation enforcement.
- Production guardian activation remains unintegrated with the proposed mandatory consent flow.

Product/legal approval, guardian-authority proof/lifecycle decisions, server enforcement, Flutter integration, and isolated hosted-QA validation remain required.

## Database authorization inventory

Fresh production catalog inspection found 132 SECURITY DEFINER functions in `public` and `private`: 79 public and 53 private. All 132 have `search_path = ''`. Seventy public SECURITY DEFINER functions are executable by `authenticated`, exactly matching the Supabase security-advisor warning count; zero public SECURITY DEFINER functions are executable by `anon`.

Two private helpers retain default PUBLIC EXECUTE ACLs, but `anon` has no USAGE on schema `private`; this is a least-privilege hardening candidate, not evidence of current anonymous reachability. Individual authorization behavior still requires review. Do not label all 70 advisor warnings as vulnerabilities.

PR #125 contains the live catalog reconciliation. PR #124/#128 staff-role work remains unmerged and hosted-QA validation is separate.

## Edge Functions and Stripe deployment parity

- Production: 30 ACTIVE Edge Functions.
- Hosted QA: 20 ACTIVE Edge Functions.
- Production currently has three Stripe functions: assignment payment intent, assignment webhook, and runtime status.
- Hosted QA has 13 Stripe functions for job funding, refunds, transfers, connected-account onboarding, financial history, payment status, documents, resolution, and webhook processing; these are not deployed in production under the same function names.

Stripe production controls remain disabled. CI contract and local regression checks pass, but hosted provider E2E and hosted Stripe regression were skipped. No live charge, transfer, refund, or payout was performed. Do not enable payments until schema/function promotion, provider sandbox E2E, webhook/reconciliation tests, legal review, and owner approval are complete.

## Website

The latest `mort-web` Vercel production deployment is marked READY on commit `0e75129094d7dbe1354d9d69c3242c869304c439`, with the account-deletion route present in the deployed source. A direct HTTP 200 response was not independently confirmed in this session.

The public page currently uses `mortapp.help@gmail.com`. Draft website PR #41 changes it to the designated `privacy@mortapp.org` mailbox and updates the production-mode smoke test. PR #41 is not merged or deployed. The page remains a manual email request path; it does not make the deletion worker operational.

## Android and iOS

- PR #123 remains open/draft. The original Play AAB was not available for read-only inspection and remains untouched.
- Recent Android CI launch attempts still lose ADB before stable foreground verification; the ARM64 hosted runner reports no KVM. These are inconclusive infrastructure/device results, not a MORT launch pass.
- PR #127 unsigned iOS archive and simulator build steps passed. Its Android startup matrix failed on ADB transport loss and ARM64 KVM absence. No signed IPA, Apple distribution profile, APNs entitlement proof, or physical iPhone journey was verified.
- PR #128 staff-role replica CI passed 114 authorization and 53 journey assertions; hosted QA is still separate.
- PR #129 Flutter analysis/tests passed, but its CI run failed in the unrelated Ramus x64 APK ABI-verification job. A diagnostic update now prints detected ABI folders and uploads the QA APK even on failure; the new run is pending.

The iOS BrowserStack workflow is manual and expects GitHub Actions repository secrets `BROWSERSTACK_USERNAME` and `BROWSERSTACK_ACCESS_KEY`. BrowserStack can re-sign an uploaded iOS IPA, but that process removes or changes entitlements; it cannot substitute for Apple distribution signing or validate APNs/Associated Domains in the re-signed session.

## Work performed during this recheck

- Created draft website PR #41 to correct the public deletion contact and smoke test.
- Updated PR #125's security review with live production catalog counts and the guardian activation finding.
- Updated PR #125's deletion runbook with the production/QA worker, missing database contract, and scheduler findings.
- Updated PR #129's QA workflow to print the Ramus APK ABI mismatch and preserve the diagnostic artifact on failure.
- No production data, schema, release controls, Edge Functions, secrets, payments, or store artifacts were modified.

## Immediate release blockers

1. Resolve the owner decision on currently enabled public marketplace and real document collection controls.
2. Approve and implement mandatory guardian consent before teen activation; integrate Flutter only after policy approval.
3. Reconcile production/QA schema and promote only reviewed migrations; production account deletion is currently missing its backing table and service RPCs.
4. Complete Android original-AAB/Play-split and real 16 KB ARM64 testing.
5. Obtain Apple distribution signing and physical iPhone verification; run BrowserStack UI testing with protected GitHub secrets if approved.
6. Complete Stripe sandbox provider E2E and reconcile QA-only financial schema/functions before any production enablement.
7. Complete remaining authorization, privacy, retention, backup/restore, and staffed operations evidence.

**No production-ready claim is supported by this recheck.**


### Stripe runtime-control schema gap

A direct column comparison of `private.stripe_runtime_controls` shows 14 columns in production versus 24 in hosted QA. QA-only columns include:

- `adult_service_fee_bps`
- `adult_service_fee_fixed_cents`
- `stripe_payments_enabled`
- `stripe_connected_onboarding_enabled`
- `stripe_job_funding_enabled`
- `stripe_transfers_enabled`
- `stripe_refunds_enabled`
- `stripe_live_mode_enabled`
- `updated_by`
- `sandbox_provider_qa_approved`

The production table lacks the explicit sandbox-provider approval field and the newer fee/runtime-control contract. This is another reason not to enable production payments based on the existing three production Stripe Edge Functions. Reconcile the schema and corresponding RPC/Edge Function contracts before any financial-control change.


### Follow-up CI evidence — 2026-11-23 11:38 ET

- MORT PR #125 head `627eb0fa3442e58db769e89309e547c848bce9d1`: GitHub Actions run #971 (`45201829407`) completed successfully. Flutter authoritative, production-replica acceptance, Android APK build artifacts, Stripe contracts/local regression/security freeze, and public-site smoke passed. Stripe provider E2E and hosted Stripe regression were skipped; this does not clear payments.
- MORT PR #129 head `10ac829832cc247684c005637f4d96cb4018589b`: the failed jobs from run #967 were re-run. At this update, the Ramus x64 artifact build/ABI diagnostic and both Android 4 KB/16 KB emulator launch jobs were still in progress. Other CI jobs passed, including Flutter authoritative, unsigned iOS archive, and replica acceptance.
- The new iOS unsigned archive artifact from run #967 has SHA-256 digest `4907ef5106d094b59559670a46ceb5548c2239adb25269fe6dd3855e24331188` at the GitHub artifact-package level. It is not an IPA signing or real-device pass.
- BrowserStack secrets have been added by the owner, but the manual `MORT iOS BrowserStack QA` workflow has not yet been dispatched. The connected GitHub action interface available for this run supports reading jobs and rerunning failed jobs, but does not expose workflow-dispatch. Trigger the workflow manually from GitHub Actions using branch `qa/guardian-consent-flutter-draft`; then verify the upload step actually receives both secrets and complete the real-device matrix. Never print either secret in logs.


### BrowserStack integration correction — 2026-11-23

Reviewing the real-device Appium client against BrowserStack's current App Automate documentation found a concrete configuration defect: the iOS test client used `hub.browserstack.com`. The documented App Automate remote endpoint is `hub-cloud.browserstack.com/wd/hub`. PR #129 now uses `hub-cloud.browserstack.com` with `/wd/hub` as its path and adds a regression assertion. The latest code change has not yet completed CI or a live BrowserStack session.

BrowserStack's iOS App Automate workflow uploads a device-built IPA and re-signs it for its own device sessions by default. That changes/removes entitlements, so this validates app launch/UI flows but cannot verify APNs, Associated Domains, or the final Apple-distribution signing profile. A successful BrowserStack UI run must not be represented as signed-release validation.


### Mobile QA follow-up — 2026-11-23 12:30 ET

- PR #125 latest head `b17900cac86b9dcd678560020676031148439b60` completed GitHub Actions run #980 (`45220267484`) successfully for all executed jobs. Stripe hosted regression and provider E2E were skipped; this does not clear Stripe.
- Static inspection of the QA-only x86_64 APK artifact `mort-android-ramus-x64-qa` from run #967 (`45189290825`) passed 16 KB native packaging checks. APK SHA-256: `57d036a7b3fd3a2d49a8c837faf2e7d24d6b7e683d7eaacc07d43d314e0241f2`. The APK contains the x86_64 Flutter engine; all nine x86_64 native libraries have ELF PT_LOAD minimum alignment >= 16 KB, and all nine uncompressed library payload offsets are 16 KB aligned. This is a static QA-APK result, not a 16 KB emulator or ARM64 hardware pass.
- The Android launch smoke gate was corrected on PR #123, PR #129, and the isolated exact-APK replay branch: no blocking `am start -W`, bounded ADB command timeouts, one window-manager dump per sample, three consecutive foreground observations, and preservation of a successful launch result if ADB disconnects only after the pass criteria. Debug-only exact-APK replay run #984 (`45227332980`) completed with no pass: the 2.5 GB 16 KB image repeatedly restarted the debug app with Android `ApplicationExitInfo reason=LOW_MEMORY`; the 4 GB 4 KB and 16 KB images reached resumed/focused MORT for two observations, then lost ADB transport before the third. These are not production-AOT results. The authoritative R8/AOT startup matrix (3 GB and 4 GB, x86_64 4 KB/16 KB plus ARM64 16 KB) is running under the separate mobile QA release workflow, now with actual splash-to-welcome, sign-in, and create-account UI assertions.
- PR #123 mobile QA evidence run #985 (`45227330444`) has passed its iOS release-verifier tests; its iOS simulator-entry and Android QA bundle jobs remain in progress. PR #123 CI and PR #129 CI have new runs in progress/queued after the launch-gate correction.
- Ramus accepted the QA x86_64 artifact and launched MORT to its Flutter secure-startup screen (`Secure startup`, `MORT`, `Restoring your session...`). The Ramus device then ended with an explicit provider-side failure stating the device stopped unexpectedly because of a problem on Ramus's side, not the app. This is not a completed UI journey or device-test pass. Ramus recognizes PR #129 but returns `no_build`; automatic PR previews must be enabled for `mortapp/Mort` in the Ramus repository settings before PR builds appear.
- The BrowserStack Appium endpoint correction remains in PR #129. The manual iOS BrowserStack workflow has not been dispatched; the connected GitHub action interface available in this run does not expose workflow dispatch. No signed IPA, physical iPhone test, APNs validation, or Apple distribution-signing proof exists.
- The original Play AAB was not accessed or changed. No production data, schema, release controls, functions, payments, signing credentials, or store artifacts were modified.
