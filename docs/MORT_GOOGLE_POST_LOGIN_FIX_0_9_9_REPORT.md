# MORT Google Post-Login Fix 0.9.9 Report

Date: 2026-07-29  
Project root: `C:\Users\micha\Mort`  
Flutter app: `C:\Users\micha\Mort\flutter_mort`  
Supabase project: `rakjydmgwwgtdislanbt`  
Version: `0.9.9+99`

## Status

- Remote profile-bootstrap repair: **applied and verified**.
- Remote RLS/backend regression: **passed**.
- Signed Android APK/AAB: **built and verified**.
- Android emulator app launch: **passed**.
- Post-fix physical-device Google account selection/callback/routing: **not performed**.
- iPhone/TestFlight: **not performed**.
- Public marketplace, real identity verification, marketplace payments, IAP, ads, remote push, crash reporting, and public activation remain disabled in the closed-test artifacts.
- This report does not classify MORT as production-ready.

## Root Cause

The affected account was an older email-provider `auth.users` row. Supabase later linked one Google identity to that existing Auth user, so no new `auth.users` insert occurred and `on_auth_user_created` did not run again. The historical user therefore still had no matching `public.profiles` row.

After PKCE returned a valid Supabase session, Flutter called `get_my_profile()`. The empty result reached a broad exception handler that presented a generic Google authentication failure even though Google consent, the Supabase callback, and the PKCE token exchange had succeeded.

Two related client-state defects were also present:

- the auth listener handled `signedIn` and `userUpdated`, but not `initialSession`;
- the callback screen checked only the immediate return from `handleOAuthCallback()` and did not navigate when a delayed auth event completed later.

MORT did not read `session.providerToken` or `providerRefreshToken`. The fix preserves that boundary and adds an explicit contract test proving provider token nullability cannot gate a valid Supabase session.

## Backend Fix

Migration: `supabase/migrations/20260729050735_mort_0_9_9_google_profile_bootstrap.sql`

- Added `private.safe_auth_display_name(jsonb)` with display-name/full-name priority, control-character removal, trimming, and an 80-character limit.
- Updated `public.handle_new_auth_user()` to use the same sanitizer while preserving the existing provider-agnostic Auth trigger.
- Added a guarded trigger-existence repair without dropping or replacing the live trigger.
- Added parameterless `private.ensure_my_profile()` as a locked-search-path `SECURITY DEFINER` function.
- Added parameterless `public.ensure_my_profile()` as a `SECURITY INVOKER` API wrapper.
- Required `auth.uid()` and inserted only the authenticated caller's user ID.
- Accepted no client-selected user ID, role, verification, admin, account, payment, or onboarding fields.
- Used `INSERT ... ON CONFLICT (id) DO NOTHING` and returned the persisted row.
- Revoked anonymous/public execution and granted only authenticated/server execution.
- Recorded only a safe repair category and generated correlation ID for repaired rows; no code, token, query string, or email is stored.
- Backfilled only missing Auth profiles. Existing profiles were not updated.

The implementation follows Supabase's current guidance for auth-driven profile triggers and locked `SECURITY DEFINER` search paths:

- <https://supabase.com/docs/guides/auth/managing-user-data>
- <https://supabase.com/docs/guides/database/functions>

## Remote Before/After

| Aggregate | Before | After |
| --- | ---: | ---: |
| Auth users | 19 | 19 |
| Profiles | 16 | 19 |
| Missing profiles | 3 | 0 |
| Google-linked users | 1 | 1 |
| Google-linked users missing a profile | 1 | 0 |
| Users with duplicate Google identities | 0 | 0 |
| Profiles with admin role | 1 | 1 |
| `on_auth_user_created` triggers | 1 | 1 |
| `ensure_my_profile()` functions in exposed API | 0 | 1 |
| Profile repair audit events | 0 | 3 |

All three repaired profiles have:

- role assigned: 0;
- onboarding completed: 0;
- verification above `not_started`: 0;
- account status other than `active`: 0.

The affected Google-linked Auth user now has exactly one profile, still has exactly one Google identity, and received no role or privilege. Auth user count did not increase.

## Flutter Fix

- Auth success now requires a current Supabase session, a current Supabase user, and matching user IDs.
- Provider tokens are neither read nor required.
- PKCE completion listens for `initialSession`, `signedIn`, and `userUpdated` and also checks the current session immediately.
- Auth stream errors have a non-logging `onError` handler, preventing offline refresh errors from becoming unhandled zone exceptions.
- Completion is single-flight so simultaneous callback/auth events cannot bootstrap or route twice.
- A valid session calls `ensure_my_profile()` before account-status checks and routing.
- Suspended/banned and deletion-pending accounts remain blocked.
- Incomplete profiles route through account status to onboarding; completed profiles retain existing role routing.
- A failed audit write no longer turns a valid sign-in/profile into a false OAuth failure. Identity-link changes still fail closed if their security record cannot be verified.
- The callback screen subscribes to delayed completion and navigates after warm or cold-start callback processing.
- User-facing failures now distinguish cancellation, browser launch, provider/callback, session exchange, profile bootstrap, restricted/deletion-pending account, and network failures.
- Removed the reported provider-token wording from user-visible source.

Supabase documents `initialSession` and requires an auth-stream `onError` handler:
<https://supabase.com/docs/reference/dart/auth-onauthstatechange>

## Verification

### Flutter

- `flutter pub get`: passed; dependencies resolved.
- `dart format lib test`: passed; 168 files checked, one final test file formatted.
- `flutter analyze`: passed; no issues found.
- Focused auth/routing suite: passed, 28 tests; 2 Google-define-gated tests skipped in the default environment.
- Full Flutter suite: passed, 192 tests; 2 Google-define-gated tests skipped in the default environment.

Covered contracts include provider-token null independence, matching session/user readiness, exact callback validation, single-flight completion, delayed/cold/warm callback handling, caller-bound/idempotent profile repair, no-overwrite behavior, provider-agnostic Auth trigger behavior, onboarding routing, completed-role routing, suspended rejection, and deletion-pending rejection.

### Remote Supabase

- Migration dry run: exactly one pending migration.
- Migration push: passed.
- Public/private schema lint: passed with zero errors.
- Dedicated Google/profile QA: passed caller binding, replay idempotency, existing-profile no-overwrite, server-owned audit, cross-user isolation, and missing-profile non-privileged repair.
- Final hosted-backend regression: passed all 31 scripts.
- Multi-user isolation: two complete 30-check runs passed.
- Final aggregate audit: 19 Auth users, 19 profiles, zero missing profiles, one Google-linked user, zero duplicate Google identities, and zero repaired profiles with role/onboarding/verification/account elevation.

### Signed Android Artifacts

APK: `C:\Users\micha\Mort\build\play\mort-closed-test-0.9.9.apk`

- Size: `62,436,792` bytes
- SHA-256: `3FFDA974B327A7F39AEA4094004AF01646E2907ABD2F0C4C39EB980247B333A6`
- Package/version: `com.mortapp.mobile`, `0.9.9+99`
- Minimum/target SDK: 24/36
- Signed release verification: passed

AAB: `C:\Users\micha\Mort\build\play\mort-closed-test-0.9.9.aab`

- Size: `48,297,044` bytes
- SHA-256: `292B08E6EB8758C35033BF02297491B560D4702711CF62785250B39DB470453B`
- Upload certificate match: passed
- Debug certificate rejection: passed
- Manifest/package/version/SDK verification: passed

Binary checks:

- Google Auth release manifests match the approved closed-test profile.
- AAB/APK scan checked 915 extracted entries against available sensitive environment values and Google client-secret markers: passed.
- Billing, background/media/ad/wake-lock permissions, and AdMob auto-start remain absent.
- Source secret scan: passed.
- Sensitive-file scan: passed.

### Emulator

API 36 signed-APK smoke test:

- streamed install: passed;
- package clear/relaunch: passed;
- MORT process remained present (`APP_PROCESS_ID=2717` during the run);
- `MainActivity` was the top resumed activity;
- fatal Android/Flutter log scan: passed;
- screenshot evidence was unavailable after ADB disconnected during capture.

The Google browser-launch UI automation was attempted twice. Both attempts lost the emulator UI hierarchy when ADB disconnected. The harness was corrected so an unavailable hierarchy is no longer falsely reported as a missing Google button. Account selection, callback, and session routing were not verified by this emulator run.

## Bugs Fixed

1. Historical Auth users could remain without profiles after identity linking.
2. Missing profiles were mislabeled as Google OAuth failures.
3. `initialSession` callback completion was ignored.
4. Delayed callback success did not navigate from the callback screen.
5. Concurrent callback/auth events could enter completion more than once.
6. Auth stream errors lacked the required crash-safe handler.
7. Identity audit write failure could mask a valid sign-in.
8. Release verification and emulator scripts contained hardcoded `0.9.8` paths/version checks.
9. Emulator screenshot disconnects caused false QA failures.
10. Empty emulator UI hierarchy was mislabeled as a missing Google button.

## Commands Run

Sensitive values were read from protected environment variables and were not printed or written into source.

```powershell
npx --yes supabase --help
npx --yes supabase migration new --help
npx --yes supabase migration list --help
npx --yes supabase db push --help
npx --yes supabase link --help
npx --yes supabase db --help
npx --yes supabase db query --help
npx --yes supabase db lint --help
npx --yes supabase link --project-ref rakjydmgwwgtdislanbt --password $db --yes
npx --yes supabase migration list --linked --password $db
npx --yes supabase migration new mort_0_9_9_google_profile_bootstrap
npx --yes supabase db query --linked --file supabase/snippets/google_profile_bootstrap_audit.sql
npx --yes supabase db push --linked --password $db --dry-run
npx --yes supabase db push --linked --password $db --yes
npx --yes supabase db query --linked --file supabase/snippets/google_profile_bootstrap_audit.sql
npx --yes supabase db lint --linked --schema public,private --level error --fail-on error
node scripts/qa-google-auth-controls.mjs
.\scripts\run-final-supabase-regression.ps1

cd C:\Users\micha\Mort\flutter_mort
flutter pub get
dart format lib test
flutter analyze
flutter test test/oauth_flow_test.dart test/google_auth_contract_test.dart test/google_auth_activation_test.dart test/route_access_test.dart
flutter test

cd C:\Users\micha\Mort
.\scripts\build-final-play-release.ps1
.\scripts\verify-google-auth-release.ps1
node .\scripts\qa-aab-secret-scan.mjs
node .\scripts\qa-aab-signing.mjs
node .\scripts\qa-android-permission-minimization.mjs
.\scripts\secret-scan.ps1
.\scripts\sensitive-file-scan.ps1
.\scripts\qa-android-api36-launch.ps1 -ApkPath 'C:\Users\micha\Mort\build\play\mort-closed-test-0.9.9.apk'
.\scripts\qa-google-oauth-browser-launch.ps1 -ApkPath 'C:\Users\micha\Mort\build\play\mort-closed-test-0.9.9.apk'
```

## Changed Files

- `flutter_mort/lib/core/auth/oauth_flow.dart`
- `flutter_mort/lib/data/repositories/auth_repository.dart`
- `flutter_mort/lib/features/auth/google_auth_screens.dart`
- `flutter_mort/pubspec.yaml`
- `flutter_mort/test/google_auth_contract_test.dart`
- `flutter_mort/test/oauth_flow_test.dart`
- `scripts/qa-android-api36-launch.ps1`
- `scripts/qa-google-auth-controls.mjs`
- `scripts/qa-google-oauth-browser-launch.ps1`
- `scripts/verify-google-auth-release.ps1`
- `scripts/verify-play-aab.ps1`
- `supabase/migrations/20260729050735_mort_0_9_9_google_profile_bootstrap.sql`
- `supabase/snippets/google_profile_bootstrap_audit.sql`
- `docs/MORT_GOOGLE_POST_LOGIN_FIX_0_9_9_REPORT.md`

Build outputs and build manifests were regenerated under `build/play`; obfuscation symbols were written outside the repository under `C:\Users\micha\MortSymbols\android\0.9.9+99`.

## Remaining Manual Verification

On a physical Android device, install the 0.9.9 APK and repeat the affected account flow:

`Continue with Google -> account selection -> Supabase callback -> PKCE session -> ensured profile -> onboarding or correct role destination`

Also verify:

- affected older email-plus-Google account retains all prior profile/application/job/message data;
- warm-start and killed-app cold-start callbacks both route correctly;
- canceled consent, offline callback, suspended account, and deletion-pending account show their specific safe messages;
- no duplicate profile or identity appears after repeated sign-ins.

Post-fix physical-device Google completion was not performed in this environment. iPhone, TestFlight, and App Store review were not performed. Public access, real verification, payments, advertising, and privileged-role activation must remain closed until their separate provider, legal, safety, store, and real-device reviews are complete.
