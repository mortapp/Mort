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
