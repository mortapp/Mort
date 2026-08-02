# MORT Remote Push Architecture

Updated: 2026-07-30

## Status

The Firebase Cloud Messaging (FCM) architecture is implemented and hosted, but
remote push is disabled. No FCM project credentials are configured and no
physical-device delivery has been claimed.

## Trust Boundary

- Flutter receives only public Firebase client configuration through release
  Dart defines. It never receives a service-account private key.
- The hosted `send-push` Edge Function is the only FCM sender. It exchanges a
  server-side service-account assertion for an OAuth token and calls FCM HTTP
  v1.
- Raw registration tokens are stored in forced-RLS private data and are never
  returned by client RPCs.
- The mobile app receives a minimized registration receipt, notification
  preferences, and UUID-only navigation data.
- Notification events are normalized by the database before they enter the
  delivery queue. User text, message text, addresses, proof paths, and arbitrary
  URLs are not eligible push data.

## Device Lifecycle

1. The user grants notification permission.
2. Flutter obtains an FCM token and registers it with an installation UUID,
   platform, version, locale, IANA time zone, and release environment.
3. Token refresh updates the same device without exposing the token back to the
   client.
4. A token collision transfers the device safely to the currently authenticated
   owner.
5. Each account is limited to ten active devices.
6. Local logout revokes the current installation; global logout and account
   deletion revoke every active installation.

## Delivery And Privacy

- Supported categories: job updates, application updates, messages, Guardian
  activity, safety alerts, Support updates, reviews, account security, and
  general updates.
- Preferences and quiet hours are server-authoritative. Safety and account
  security notices bypass quiet hours.
- Lock-screen title and body are generic. The app reloads authenticated state
  after opening a notification.
- Deep links use an allowlist of first-party destinations and validated UUIDs.
- Workers claim queue rows atomically, retry bounded transient failures, and
  deactivate invalid registration tokens.
- Delivery events record provider status codes and bounded failure categories,
  not provider response bodies or tokens.

## Activation Gates

Remote push must remain false until all of these are complete:

- owner creates or selects the Firebase project;
- Android and iOS apps match the MORT package identifiers;
- APNs is configured for the iOS Firebase app;
- server-only FCM service-account values are installed in Supabase secrets;
- public client values are supplied to the signed release build;
- privacy and teen-safety notification copy is approved;
- Android and iPhone real-device foreground, background, terminated, denied,
  token-rotation, logout, and deep-link tests pass.

