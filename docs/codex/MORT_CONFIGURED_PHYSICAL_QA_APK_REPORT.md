# MORT Configured Physical QA APK Report

Date: 2026-08-02
Branch: `codex/physical-rendering-fix-0.9.14`
Fix commit: `7b57126605e76df90ee03b9841fef90f601e751a`

## Scope

This bounded pass produced one configured QA APK containing commit `7b57126`
using the repository-approved protected closed-test Android build path.

No version bump was performed. Immutable `0.9.13+103` release artifacts were not
overwritten.

## Build Mechanism Used

Used:

`scripts/build-standard-closed-test-apk.ps1`

That script delegates to `scripts/android-release-profile-common.ps1` with:

- `ReleaseProfile = closed_test`
- `ReleaseStage = closed_test`
- `OperationalMode = closed_pilot`
- `GoogleAuthEnabled = true`
- `PlayReviewModeEnabled = false`
- `PublicMarketplaceEnabled = false`
- `IdentityVerificationEnabled = false`
- `RemotePushEnabled = false`
- `CrashReportingEnabled = false`
- `PublicActivationApproved = false`

The build path loads public client configuration through
`Get-MortPublicConfigValue`, writes temporary dart-defines to a temp file, checks
for forbidden secret-like define keys and values, builds the APK, removes the
temporary define file, and verifies the APK.

Only public Supabase client configuration was used. No service-role key,
Supabase access token, database password, client secret, private key, or webhook
secret was used in Flutter or written into this report.

## Changed Files

Created:

- `docs/codex/MORT_CONFIGURED_PHYSICAL_QA_APK_REPORT.md`

The rendering fix itself was already committed before this pass:

- `flutter_mort/android/app/src/main/AndroidManifest.xml`
- `flutter_mort/lib/core/widgets/mort_brand.dart`
- `flutter_mort/lib/features/onboarding/transportation_screen.dart`
- `flutter_mort/test/android_native_parity_test.dart`
- `flutter_mort/test/physical_rendering_regression_test.dart`

## Commands And Exit Codes

`git branch --show-current; git rev-parse --short HEAD; git status --short`

- Exit code: `0`
- Result: branch `codex/physical-rendering-fix-0.9.14`, HEAD `7b57126`, clean
  at the start of this pass.

`node scripts/read-mobile-version.mjs --json`

- Exit code: `0`
- Result: `0.9.13+103`.

`node scripts/validate-release-profile.mjs --profile closed_test`

- Exit code: `0`
- Result: closed-test profile was valid.

PowerShell configuration validation using
`scripts/android-signing-common.ps1`, `Get-MortPublicConfigValue`, and
`node scripts/validate-release-profile-server.mjs closed_test`

- Exit code: `0`
- Result: server gate passed for `profile=closed_test`,
  `server_stage=closed_test`, `public=false`.
- No configuration values were printed.

`flutter analyze --no-pub`

- Exit code: `0`
- Result: `No issues found! (ran in 158.8s)`.

`flutter test --no-pub test\physical_rendering_regression_test.dart test\android_native_parity_test.dart`

- Exit code: `0`
- Result: all focused tests passed.

`.\scripts\build-standard-closed-test-apk.ps1`

- Exit code: `0`
- Result: configured signed closed-test APK built and verified.
- Script verification reported package `com.mortapp.mobile`,
  version `0.9.13+103`, min SDK `24`, target SDK `36`, permissions `11`,
  signed `True`, size `68301502`, SHA-256
  `8FB68F1BF31B12B984870139A34C9858CBCFE774464458BDD3647FF5440B6BF2`.

Copy configured APK and manifest into
`artifacts\physical-qa-rendering-fix`

- Exit code: `0`
- Result: copied APK and build manifest into the requested artifact folder.

`.\scripts\qa-android-apk.ps1 -ApkPath artifacts\physical-qa-rendering-fix\mort-rendering-fix-0.9.13+103-7b57126-configured.apk -RequireSigned`

- Exit code: `0`
- Result: package/version/SDK/permission/signing/hash verification passed.

`apkanalyzer manifest application-id/version-name/version-code`

- Exit code: `0`
- Result: package `com.mortapp.mobile`, version name `0.9.13`, version code
  `103`.

`adb devices -l`

- Initial result: the Samsung `SM_A146U` device was visible.
- Later result: the device disappeared before APK installation.

`adb install -r artifacts\physical-qa-rendering-fix\mort-rendering-fix-0.9.13+103-7b57126-configured.apk`

- Exit code: `1`
- Result: `adb.exe: no devices/emulators found`.

`adb kill-server; adb start-server; adb devices -l; adb mdns services`

- Exit code: `0`
- Result: ADB restarted, but no device and no mDNS wireless debugging service
  were visible.

## APK Path

`C:\Users\micha\Mort\artifacts\physical-qa-rendering-fix\mort-rendering-fix-0.9.13+103-7b57126-configured.apk`

Build manifest copy:

`C:\Users\micha\Mort\artifacts\physical-qa-rendering-fix\mort-rendering-fix-0.9.13+103-7b57126-configured-build-manifest.json`

## APK Metadata

- Package: `com.mortapp.mobile`
- Version name: `0.9.13`
- Version code: `103`
- Size: `68,301,502` bytes
- SHA-256:
  `8FB68F1BF31B12B984870139A34C9858CBCFE774464458BDD3647FF5440B6BF2`
- Commit included:
  `7b57126605e76df90ee03b9841fef90f601e751a`
- Release profile: `closed_test`
- Release stage: `closed_test`
- Operational mode: `closed_pilot`
- Google Auth: enabled
- Auth flow: Supabase Google OAuth with PKCE
- Native callback: `com.mortapp.mobile://app/auth-callback`
- Project ref: `rakjydmgwwgtdislanbt`

## Signing Status

The configured APK is signed with the repository's protected Android upload
certificate path. The repo's APK QA script verified the APK as signed.

The debug APK was not used because a plain debug build does not include the
configured public Supabase dart-defines and may not match the approved Google
OAuth Android signing configuration.

## Secure Startup Result

Host-side configuration validation passed:

- Closed-test release profile validation passed.
- Server-authoritative release gate passed.
- The build manifest records the approved project ref, Google OAuth flag, and
  callback configuration.
- `MortBootstrap` calls `AppConfig.assertValidReleaseConfiguration()` before
  Supabase initialization, and this configured build was produced through the
  release path that supplies those dart-defines.

Physical secure-startup validation is blocked:

- The Samsung `SM_A146U` was initially visible over ADB.
- It disappeared before `adb install -r` could install the configured APK.
- `adb kill-server`, `adb start-server`, `adb devices -l`, and
  `adb mdns services` did not recover the device.

Because the exact copied APK was not installed after the device dropped offline,
this pass does not claim that the physical phone reached authentication, launched
Google OAuth, completed OAuth, returned through the callback, or exercised the
fixed account-status loading animation.

## External Blocker

Physical validation requires the phone to be visible again through ADB USB or
Wireless Debugging. Once ADB connectivity is restored, install this exact APK
path and repeat secure startup, Google OAuth, callback, account-status loading,
and logcat checks.

Do not use the plain debug APK for that retest.
