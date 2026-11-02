# MORT Supabase-only notifications and local restore status

Updated: 2026-11-01

## Firebase / remote push

Firebase source and Flutter packages are retained as dormant code, per the
product instruction to disable Firebase without removing it. The app always
selects `DisabledRemotePushProvider`; `AppConfig.remotePushEnabled` is a
compile-time `false`; the notification coordinator makes no remote calls; and
notification preferences force push off while leaving the Supabase-backed
in-app inbox available.

All six release profiles set `remotePushEnabled=false`, the profile validator
rejects any profile that sets it true, and both Android release-script layers
reject an enable request. The Android app manifest removes Firebase's init
provider, FCM receiver/service components, and `POST_NOTIFICATIONS` from the
merged app. The iOS permission-purpose string claiming device notifications
were sent has been removed. The local `send-push` Edge Function source also
returns `remote_push_disabled` before reading or delivering payloads; it is
not deployed to production. These repository changes do not modify Supabase's
hosted configuration or publish a new mobile release.

## Database / Auth / Storage restore

Production was inspected read-only through the Supabase connector. The active
project is `jxbnrkasktbhtiujkhay`; it has six private Storage buckets and zero
Storage objects, and two Auth users. No production rows, auth settings, release
controls, or provider configuration were changed.

Docker is available and local Supabase Auth and Storage health endpoints
responded HTTP 200. The reusable local schema-test container is not a pristine
production snapshot: its private schema already contains candidate
private-location objects that are absent in the current production catalog.
An attempted schema replay into a disposable database therefore stopped on an
existing-object conflict. Those disposable databases were removed; no result
from that mutated snapshot is counted as production-clone validation.

A direct read-only `pg_dump` from production could not run from this host:
the database hostname resolved to IPv6, the Docker network reported no IPv6
route, and the host returned no A record. The connected Supabase tool supports
catalog queries but not export/restore. No complete database/Auth backup or
Storage-byte backup was present in the searched local backup locations. As a
result, no production data/Auth restore was attempted or claimed. A complete
data restore still requires a secure production dump path plus an isolated
restore target; production is not a test database.

## Google OAuth owner setup

The credential JSON already in the local secure credential directory was
checked without printing its client ID or secret. It contains a web OAuth
client pair and the Google-side Supabase redirect URI below.

1. In Google Cloud Console, select the OAuth client for MORT and ensure its
   type is **Web application**. Under **Authorized redirect URIs**, add exactly
   `https://jxbnrkasktbhtiujkhay.supabase.co/auth/v1/callback`. Save and retain
   the client ID/secret in the local secure credential directory.
2. In the Supabase dashboard, open project `jxbnrkasktbhtiujkhay` →
   **Authentication → Sign In / Providers → Google**. Enable Google and enter
   that same client ID and secret. Save.
3. Under **Authentication → URL Configuration → Redirect URLs**, allow
   `com.mortapp.mobile://app/auth-callback` and
   `https://mortapp.org/auth-callback`.
4. Test with an owner-controlled account on Android and the website. Confirm
   the callback returns to MORT and the resulting Supabase session belongs to
   the test account. Do not use production teen accounts for this test.

Provider configuration and a real production login remain unverified; no
dashboard change was made.

## Verification evidence for the app changes

- Focused final suites: **23 passed, 0 failed** across push contract and
  BrowserStack QA permission tests.
- Full Flutter suite after the final source and test changes:
  **624 passed, 2 skipped, 0 failed** (`flutter test --no-pub`).
- Release-profile validation passed for **6** safe profiles; the pilot AAB
  preflight test passed; the PowerShell release-push configuration check
  passed; and `dart format --output=none --set-exit-if-changed lib test`
  reported **311 files, 0 changes**.
- The Android merged debug manifest was generated and searched. None of the
  Firebase initialization/service/receiver/provider component names or
  `POST_NOTIFICATIONS` remained in the merged manifest. This verifies manifest
  removal, not a completed APK/AAB build; the debug build did not finish.
- `flutter analyze --no-pub`: **No issues found** (547.3 seconds in this
  Windows environment).
- Firebase packages and provider implementation remain in the repository;
  no application entry point initializes or subscribes to them.
- Marketplace publishing, payments, and real identity-document collection
  were left disabled.
