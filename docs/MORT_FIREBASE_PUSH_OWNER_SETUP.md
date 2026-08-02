# MORT Firebase Push Owner Setup

Updated: 2026-07-30

No credential is included in this document or in mobile source.

## Owner Actions

1. In Firebase, create or select a project approved for MORT production use.
2. Register Android package `com.mortapp.mobile` and the matching iOS bundle.
3. For iOS, upload an approved APNs authentication key and confirm the Apple
   team and key identifiers.
4. Create a least-privilege server credential able to send FCM messages. Store
   its project ID, service-account email, and private key only as Supabase Edge
   Function secrets named `FCM_PROJECT_ID`, `FCM_SERVICE_ACCOUNT_EMAIL`, and
   `FCM_SERVICE_ACCOUNT_PRIVATE_KEY`.
5. Keep `SEND_PUSH_INVOKE_SECRET` server-only. Rotate it if its custody is ever
   uncertain.
6. Supply Firebase public client values to the release build using the
   `MORT_FIREBASE_*` Dart defines documented in `AppConfig`; do not commit a
   generated configuration file containing environment-specific values.
7. Set the hosted remote-push runtime flag only after the credential and device
   checks below pass.

## Required Device Verification

- Android 13+ permission allow and deny paths.
- iPhone permission allow and deny paths.
- Foreground behavior without duplicate banners.
- Background and terminated delivery.
- Generic lock-screen copy for every category.
- Valid and malformed deep links.
- Token refresh and reinstall.
- Same-device account switch.
- Local logout and global logout revocation.
- Quiet hours in multiple IANA zones, including a daylight-saving boundary.
- Invalid-token cleanup and bounded provider retry.

## Current Hosted State

- `send-push`: ACTIVE, JWT verification enabled.
- Server invoke secret: present.
- FCM provider secrets: absent.
- Database and client remote-push flags: false.
- Real FCM delivery: not verified.

