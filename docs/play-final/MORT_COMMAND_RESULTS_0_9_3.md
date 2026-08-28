# MORT 0.9.3 Command Results

Run date: 2026-07-22

This is an evidence record, not a production-readiness claim. Secret values are intentionally omitted.

## Remote Supabase

| Exact command | Result |
|---|---|
| `npx supabase functions deploy avatar-url --project-ref rakjydmgwwgtdislanbt` | PASS after fixing the worker identifier collision. |
| `npx supabase db push --linked --dry-run --password $env:SUPABASE_DB_PASSWORD` | PASS for migration `20260722225742_fix_adult_job_cancellation_enum_cast.sql`. |
| `npx supabase db push --linked --password $env:SUPABASE_DB_PASSWORD` | PASS; migration applied to `rakjydmgwwgtdislanbt`. |
| `npx supabase migration list --linked` | PASS; local and remote history aligned through `20260722225742`. |
| `npx supabase db lint --linked --level error --fail-on error` | PASS; no error-level findings. |
| `.\scripts\run-final-supabase-regression.ps1` | PASS; 26/26 scripts in 556.5 seconds, including 30/30 multi-user isolation checks. |
| `. .\scripts\play-review-secrets-common.ps1; Set-MortPlayReviewEnvironment; $scripts=Get-ChildItem .\scripts\qa-stripe-*.mjs \| Sort-Object Name; foreach($script in $scripts){ node $script.FullName; if($LASTEXITCODE -ne 0){ throw "$($script.Name) failed." } }` | PASS; 25/25 boundary files in 18.5 seconds. Provider money movement remained disabled. |
| `. .\scripts\play-review-secrets-common.ps1; Set-MortPlayReviewEnvironment; $names=@('qa-support-cross-user-isolation.mjs','qa-support-staff-forgery.mjs','qa-evidence-isolation.mjs','qa-job-start-funding-gate.mjs','qa-job-pin-replay-lock.mjs','qa-abandonment-safety-cooldown.mjs','qa-payment-resolution-boundary.mjs','qa-support-email-fallback-contract.mjs'); foreach($name in $names){ node (Join-Path .\scripts $name); if($LASTEXITCODE -ne 0){ throw "$name failed." } }` | PASS; 8/8 focused files in 12.6 seconds. |
| `node scripts\audit-supabase-advisors.mjs` | PASS with no error-level findings; warning/info inventory remains documented. |

## Flutter and Expo

| Exact command | Result |
|---|---|
| `flutter pub get` | PASS. |
| `dart format --output=none --set-exit-if-changed lib test` | PASS; 141 files, zero changed. |
| `flutter analyze --no-fatal-infos --no-fatal-warnings` | PASS; no issues. |
| `flutter test` | PASS; 115/115 tests. |
| `flutter build web --release --dart-define=SUPABASE_URL=$env:EXPO_PUBLIC_SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$env:EXPO_PUBLIC_SUPABASE_ANON_KEY --dart-define=WEB_PREVIEW_MODE=true --dart-define=IAP_ENABLED=false --dart-define=ADS_ENABLED=false --dart-define=USE_TEST_ADS=true --dart-define=MORT_RELEASE_STAGE=closed_test --dart-define=MORT_OPERATIONAL_MODE=closed_pilot --dart-define=MORT_PUBLIC_MARKETPLACE_ENABLED=false --dart-define=MORT_IDENTITY_VERIFICATION_ENABLED=false` | PASS. |
| `pnpm install` | PASS. |
| `pnpm check` | PASS. |
| `pnpm lint` | PASS. |
| `pnpm build` | PASS. |
| `npx expo export --platform web` | PASS; 48 static routes. |
| `npx expo-doctor` | PASS; 20/20 checks. |

## Android Release

| Exact command | Result |
|---|---|
| `.\scripts\build-final-play-release.ps1` | PASS after warning-handling fix; lint-clean rebuild took 720.0 seconds. |
| `.\scripts\qa-android-apk.ps1 -ApkPath .\mort-android-0.9.3-final-qa.apk -RequireSigned` | PASS; package `com.mortapp.mobile`, version `0.9.3+93`, min SDK 24, target SDK 36, signed, 11 permissions. |
| `.\scripts\verify-play-aab.ps1 -BundlePath .\mort-android-0.9.3-closed-test.aab` | PASS; upload-certificate signature and manifest verified. |
| `.\scripts\android-lint-release.ps1` | PASS; 643 application-module tasks, zero lint errors. |
| Android 36 ADB clean install/launch/navigation/validation commands | PASS; APK installed, `MainActivity` foreground, Sign In opened, both validation errors visible, MORT process alive, zero MORT fatal/ANR lines. |

## Integrity

| Exact command | Result |
|---|---|
| `node scripts\qa-aab-secret-scan.mjs` | PASS; 2,601 binary entries checked against 4 available sensitive values. |
| `.\scripts\secret-scan.ps1` | PASS. |
| `.\scripts\sensitive-file-scan.ps1` | PASS; 1,442 files, 30 media files, 9 sensitive values checked. |
| `pnpm audit --prod --audit-level=moderate` | PASS; no known vulnerabilities. |
| `.\scripts\package-mort-0.9.3.ps1` | PASS; seven clean ZIP packages created. |
| `.\scripts\sensitive-file-scan.ps1 -ArchivePath <each-package>` | PASS for all seven ZIP packages; zero archive scan failures. |

## Failed Commands and Fixes

1. `npx supabase db lint --linked` initially found a text-to-`application_status` enum assignment in adult cancellation. Migration `20260722225742` added explicit casts; error lint and cancellation regression then passed.
2. `npx supabase functions deploy avatar-url ...` was followed by QA that exposed a worker compile failure from redeclaring `authorization`. The identifiers were separated, diagnostics improved, the function redeployed, and the full 26-script regression passed.
3. `flutter build` initially emitted successful Java warnings to stderr that PowerShell treated as terminating errors. The APK/AAB scripts now capture native exit status and throw only on nonzero exit.
4. Root `.\gradlew.bat lintRelease` failed in the latest upstream `flutter_local_notifications` package with three package-source `MissingPermission` findings. The package was not patched or hidden by a baseline. MORT now uses `.\gradlew.bat :app:lintRelease` through `scripts/android-lint-release.ps1`.
5. The first app-module lint found five absent AdMob class references and two generated Windows property-escape errors. Obsolete manifest stubs were removed, paths normalized, and app-module lint passed.
6. One combined APK/AAB verification command timed out after copying the files. APK and AAB verification were rerun separately and both passed.
7. The emulator displayed a `com.android.systemui` ANR after the heavy build. Window focus and accessibility hierarchy proved it was System UI; after dismissal, MORT launch/sign-in/validation/no-fatal checks passed.
8. A full remote rerun after the local evening cutoff failed because the arrival QA fixture scheduled a job five minutes from the current clock time; the closed-pilot safety trigger correctly blocked late work. The fixture now selects a synthetic daytime timezone for its near-term absolute window and asserts the post-publish job state. Arrival, person-mismatch, and the full 26-script regression then passed.

No iPhone, Xcode, TestFlight, Stripe live transaction, qualified legal review, production monitoring exercise, or physical Android test is claimed.
