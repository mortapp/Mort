# MORT Google Sign-In 0.9.8 Report

Generated: 2026-07-28 (America/Indianapolis)

## Release Identity

- Flutter version: `0.9.8+98`
- Android package: `com.mortapp.mobile`
- Supabase project: `rakjydmgwwgtdislanbt`
- Release stage: `closed_test`
- Operational mode: `closed_pilot`
- Git commit at build time: `f566885453786f1fbdea08291b1b646a5cabe1bc`
- Worktree at build time: dirty; existing 0.9.7 work was preserved.
- This release is not production-ready.

## Google Auth Configuration

- `GOOGLE_AUTH_ENABLED=true`
- `MORT_AUTH_REDIRECT_URL=com.mortapp.mobile://app/auth-callback`
- Provider: Supabase Auth Google OAuth
- Client flow: PKCE
- Scopes: `openid email profile`
- Browser mode: external application
- Supabase provider status: enabled
- Supabase nonce bypass: disabled
- Remote authorize check: HTTP 302 to `accounts.google.com`

The Flutter app contains no Google client secret, Supabase service-role key,
Firebase Auth configuration, `google-services.json`, or second Google auth SDK.
The supplied Google credential JSON remained outside the repository and was not
read, copied, logged, or packaged. MORT does not persist Google provider access
or refresh tokens.

The supplied Google Console screenshot says OAuth access is restricted to test
users. Only accounts listed on that consent screen can complete sign-in until
Google Console access is changed. The client secret visible in the supplied
screenshot/chat must be rotated and the replacement saved only in Supabase's
Google provider configuration before further account testing.

Architecture reference: [Supabase Google Auth documentation](https://supabase.com/docs/guides/auth/social-login/auth-google).

## Security And Routing

- `Supabase.initialize` retains `AuthFlowType.pkce`.
- Native sessions remain in `MortSecureSessionStorage`.
- OAuth callbacks accept only scheme `com.mortapp.mobile`, host `app`, and path
  `/auth-callback`; callback URLs containing bearer tokens are rejected.
- Duplicate launches remain blocked by `OAuthLaunchGate`.
- Canceled and malformed callbacks return safe states.
- Auth completion requires an actual Supabase session or signed-in auth event.
- The Auth user trigger inserts one profile keyed by `auth.users.id`, uses
  `on conflict (id) do nothing`, and does not assign a role.
- Missing or incomplete profiles enter onboarding.
- Complete profiles resolve to teen, adult, guardian, or admin destinations.
- Suspended and deletion-pending accounts remain blocked.
- Reviewer mode remains isolated and email/password auth remains available.
- Public marketplace, identity verification, payments, ads, IAP, remote push,
  crash reporting, and public activation remain disabled in these builds.
- OAuth callback values, authorization codes, provider tokens, and sessions are
  not printed by the auth implementation or included in crash envelopes.

## Artifacts

| Artifact | Size | SHA-256 |
| --- | ---: | --- |
| `C:\Users\micha\Mort\build\play\mort-closed-test-0.9.8.apk` | 62,436,792 bytes | `575B310C3CCB291F11BAA80366D663576D303F6ADCD31B911F7751B9AE05A817` |
| `C:\Users\micha\Mort\build\play\mort-closed-test-0.9.8.aab` | 48,297,097 bytes | `6E9DBDB5FD07FC86E4D0C56E78C6EA0EA9A61A80BFE23B3E54A14214FC20F75A` |

Upload certificate SHA-256:
`04:42:C2:21:38:B0:D6:23:F9:A6:F4:78:1A:44:2B:F4:A9:33:27:8F:AB:8E:85:76:74:4D:C1:FD:7C:33:4D:EF`

The APK verifier confirmed package, version, min/target SDK 24/36, permissions,
and release signing. `zipalign -c -P 16 -v 4` passed. The AAB verifier confirmed
the upload certificate, package, version, SDKs, forbidden-permission absence,
and exported-component allowlist. Android release builds retain R8 minification,
resource shrinking, obfuscation, and external debug symbols.

## Commands And Results

| Command | Result |
| --- | --- |
| `flutter pub get` | PASS; dependencies resolved |
| `dart format lib test integration_test` | PASS; 169 files checked, three formatted on first pass |
| `flutter analyze` | TOOL TIMEOUT after 184.1 seconds; no result claimed |
| `flutter analyze --no-pub` | PASS; no issues found in 259.6 seconds |
| `flutter test --no-pub` (first run) | FAIL; activation-only tests were incorrectly active in the default profile; other 186 tests passed |
| `flutter test --no-pub` (after harness fix) | PASS; 186 passed, two activation-profile tests skipped by design |
| `flutter test test\google_auth_activation_test.dart ...` with exact closed-test defines | PASS; two passed, Google button visible and enabled |
| `node scripts\qa-release-deep-links.mjs` | PASS; exact native OAuth callback and route guard verified |
| Supabase Management Auth config GET | PASS; project matched and Google provider enabled |
| Supabase `/auth/v1/authorize` PKCE request | PASS; HTTP 302 to `accounts.google.com` |
| `.\scripts\build-closed-test-apk.ps1` | PASS; signed versioned APK built and verified |
| `.\scripts\build-play-aab.ps1` | PASS; signed versioned AAB built and verified |
| `.\scripts\verify-google-auth-release.ps1` | PASS; artifact hashes and approved Google-auth profile matched both manifests |
| `.\scripts\secret-scan.ps1` | PASS |
| `node scripts\qa-aab-secret-scan.mjs ...` | PASS; 915 extracted entries checked against five available sensitive values and Google client-secret markers |
| `zipalign -c -P 16 -v 4 ...apk` | PASS; verification successful |
| PowerShell parser check | PASS; 11 edited release/QA scripts parsed |
| `git diff --check` | PASS; line-ending warnings only, no whitespace errors |

The first API 36 smoke attempt exited before install evidence because the
default emulator GPU mode was unreliable. The explicit SwiftShader run installed
the APK, kept process `5320` alive, reported `MainActivity` top-resumed, and
passed the fatal-log scan; the command then failed when ADB went offline during
screenshot pull. The harness now uses explicit SwiftShader and treats screenshot
capture as separate evidence.

The installed Google-button browser automation did not pass. Multiple bounded
retries were blocked by an unstable headless emulator accessibility root. This
does not count as a manually completed Google login or as a verified installed
button tap.

## Bugs Fixed

1. Closed-test release profiles forced `GOOGLE_AUTH_ENABLED=false`.
2. Release builds did not pass the exact Google callback dart define.
3. Android output names overwrote or reused unversioned 0.9.7 paths.
4. Artifact scanners still targeted stale unversioned artifacts.
5. Deep-link QA incorrectly expected the obsolete `mort://` scheme.
6. Release validation did not reject a mismatched Google callback.
7. The activation test initially ran in the default-off suite instead of only
   under its explicit release-profile define.
8. The new release verifier initially traversed large archive trees and timed
   out; it now uses a scoped `rg --files` credential check.
9. Android smoke defaulted to an unreliable emulator GPU mode and treated a
   screenshot transport failure as if app launch itself had failed.

## Changed Files

- `flutter_mort/.env.example`
- `flutter_mort/lib/core/config/app_config.dart`
- `flutter_mort/pubspec.yaml`
- `flutter_mort/test/google_auth_activation_test.dart`
- `flutter_mort/test/google_auth_contract_test.dart`
- `flutter_mort/test/production_readiness_contract_test.dart`
- `flutter_mort/test/release_candidate_policy_test.dart`
- `flutter_mort/test/route_access_test.dart`
- `scripts/android-release-profile-common.ps1`
- `scripts/build-closed-test-aab.ps1`
- `scripts/build-closed-test-apk.ps1`
- `scripts/build-final-play-release.ps1`
- `scripts/build-production-pilot-aab.ps1`
- `scripts/package-google-sign-in-0.9.8.ps1`
- `scripts/qa-aab-secret-scan.mjs`
- `scripts/qa-aab-signing.mjs`
- `scripts/qa-android-api36-launch.ps1`
- `scripts/qa-google-oauth-browser-launch.ps1`
- `scripts/qa-release-deep-links.mjs`
- `scripts/run-play-release-qa.ps1`
- `scripts/verify-google-auth-release.ps1`
- `scripts/verify-play-aab.ps1`
- `docs/MORT_GOOGLE_SIGN_IN_0_9_8_REPORT.md`

`scripts/build-play-aab.ps1` and `scripts/build-android-release.ps1` were also
inspected; both already delegate to the updated closed-test build scripts, so no
additional edit was required.

## Verification Boundary

### A. Code And Build Activation Verified

Verified: Supabase Google OAuth + PKCE architecture, exact callback, enabled
closed-test compile flag, enabled button widget, provider enabled state, real
Supabase-to-Google redirect, versioned signed artifacts, release flags, routing
contracts, session persistence contract, profile idempotency, blocked-account
checks, secret boundaries, and artifact integrity.

### B. Real Google Login Manually Verified On Installed Android Build

Not verified. The following must be completed after rotating the exposed client
secret and adding the tester account in Google Console:

1. Install `mort-closed-test-0.9.8.apk` on a physical Android device or stable
   Google APIs emulator.
2. Open MORT and tap `Sign in`, then `Continue with Google`.
3. Confirm the real Google account chooser opens.
4. Complete consent with a listed Google test user.
5. Confirm the callback returns through
   `com.mortapp.mobile://app/auth-callback`.
6. Confirm a Supabase session exists after process restart.
7. For a new account, confirm onboarding begins and no role is preassigned.
8. For existing teen, adult, guardian, and admin accounts, confirm the correct
   destination.
9. Confirm suspended and deletion-pending accounts remain blocked.
10. Cancel once and retry once to confirm safe recovery and no duplicate browser
    launch.

Do not upload this build to a broader tester group until the exposed Google
client secret is rotated and the Google consent-screen audience is intentionally
configured.
