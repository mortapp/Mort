# MORT 0.9.13+103 Test Report

Only commands with final exit code 0 are marked pass.

## Required Commands

| Command | Result |
| --- | --- |
| `flutter pub get` | PASS, 9.5 s; 51 newer incompatible versions reported |
| `dart format lib test integration_test` | PASS, 206 files, 0 changed, 1.8 s |
| `flutter analyze --no-pub` | PASS, no issues, 143.7 s |
| `flutter test --no-pub` | PASS, 276 passed, 2 skipped, 48.4 s |
| `.\scripts\build-web-preview.ps1 -SkipTests` | PASS, release web and WASM dry run, 152.3 s |
| `pnpm install --frozen-lockfile` | PASS, up to date, 3.1 s |
| `pnpm check` | PASS, 15.8 s |
| `pnpm lint` | PASS, 16.0 s |
| `pnpm build` | PASS, Expo static export, 48 routes, 20.4 s |
| `npx expo-doctor` | PASS, 20/20, 36.9 s |
| `.\scripts\windows-check.ps1` | PASS, 51.4 s |
| `npx supabase migration list --linked` | PASS; local/remote include `20260802062226` |
| `npx supabase db lint --linked --level error` | PASS, no schema errors |
| `npx supabase db push --linked --dry-run` | PASS, remote up to date |
| `.\scripts\run-final-supabase-regression.ps1` | PASS, 45 scripts, 334.7 s |
| `pnpm audit --prod` | PASS, no known vulnerabilities |
| `.\scripts\secret-scan.ps1` | PASS |

## Focused and Release Commands

| Command | Result |
| --- | --- |
| `node scripts/qa-video-profile-job-hardening.mjs` | PASS; profile/job security, truthfulness, cleanup |
| Focused hosted profile/onboarding/job scripts | PASS, 6 scripts |
| `flutter test --no-pub test/mort_redesign_test.dart test/accessibility_localization_reliability_test.dart` | PASS, 7 tests, 16.7 s |
| `node scripts/qa-design-navigation.mjs` | PASS, 152 files, 0 unresolved builders |
| `node scripts/audit-feature-implementation.mjs` after correction | PASS, 93 retained claims |
| `node scripts/validate-1891-feature-registry.mjs` | PASS, 1,891 accepted, 93 proven claims |
| `.\scripts\build-standard-closed-test-apk.ps1` | PASS, 274.2 s |
| `.\scripts\qa-android-apk.ps1 ... -RequireSigned` | PASS, 8.0 s |
| `.\scripts\build-standard-closed-test-aab.ps1` | PASS, 49.3 s |
| `.\scripts\verify-play-aab.ps1 ...` | PASS, 3.7 s |
| `.\scripts\qa-android-16kb-alignment.ps1 ...` | PASS, 18 libraries |
| `node scripts/qa-android-permission-minimization.mjs` | PASS |
| `.\scripts\run-android-native-integration.ps1 ...` using driver | PASS, 2 tests, 295.4 s |
| `.\scripts\sensitive-file-scan.ps1` before final packaging | PASS, 1,867 files, 54 known media, 10 secret values checked |

## Emulator Commands

`adb kill-server`, `adb start-server`, `adb devices -l`, `flutter devices`,
`flutter emulators`, exact APK install, `am start -W`, `dumpsys`, UI Automator,
logcat, screenshots, Google handoff/cancel, and final reinstall were run against
`emulator-5554`. Final launch was cold in 6,585 ms and had zero MORT fatal/error
matches after 15 seconds.

## Failures Found and Repaired

1. A combined targeted format/analyze command exceeded its 124.031 s capture
   bound. Separate rerun passed; the interrupted command is not counted.
2. Supabase CLI rejected unsupported `db lint --password`; rerun with supported
   linked syntax passed.
3. Avatar source test assumed one-line formatting; assertion was made
   whitespace-tolerant and 25 tests passed.
4. Full Flutter suite found the manifest removed Firebase Messaging `WAKE_LOCK`.
   The compiled dependency permission was restored and release verifiers aligned;
   final suite passed 276 with 2 skips.
5. One Flutter test was mistakenly invoked from the repository root and failed
   with `No pubspec.yaml file found`; correct directory rerun passed 7 tests.
6. Sensitive scan stopped on reviewed private video contact sheets. The exact
   ignored `qa/recordings` directory was excluded while release archives remain
   scanned; rerun passed.
7. Feature audit downgraded six claims whose source symbols were absent. Registry
   now truthfully retains 93 implementation claims; rerun passed.
8. First native listener run failed in Flutter finalization with a missing temp
   listener path after an ADB protocol fault. A dedicated integration driver was
   added; retry passed both tests.
9. Native integration still expected build 102. It now asserts build 103.
10. Two early AVD sessions disconnected. Clean emulator-only state, bounded core
    count, snapshot disablement, and host GPU produced stable final verification.
