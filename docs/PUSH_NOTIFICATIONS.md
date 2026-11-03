# Flutter Push Notifications

MORT's Android and iOS app uses Firebase Cloud Messaging (FCM) through the
Flutter `firebase_messaging` integration. Expo push tokens and the legacy
reference clients are not part of this delivery path.

## Delivery flow

1. `PushNotificationCoordinator` checks the server's public
   `get_push_delivery_availability()` RPC before requesting operating-system
   permission or registering a device token.
2. After permission is granted, the app registers the FCM token with
   `register_my_push_device_v2`. The server owns token persistence, device
   limits, account-switch handling, revocation, and idempotency.
3. Notification events are queued in `notification_events`. The authenticated
   `send-push` Edge Function claims eligible events, sends generic FCM copy,
   and records provider results.
4. `get_my_push_status_v2()` reports the user's preference separately from
   effective remote delivery. A preference alone does not mean a device can
   receive remote alerts.

Effective delivery requires both the active release policy's `remote_push`
flag and `push_delivery_runtime.remote_push_enabled`. The availability RPC,
the service runtime status, token registration, and the push-event sender all
enforce these server gates. The Flutter UI also fails closed when the status
RPC is unavailable. App-side Firebase configuration by itself cannot turn
delivery on.

## Production prerequisites

- Store `FCM_PROJECT_ID`, `FCM_SERVICE_ACCOUNT_EMAIL`, and
  `FCM_SERVICE_ACCOUNT_PRIVATE_KEY` as Supabase Edge Function secrets.
- Keep `SUPABASE_SERVICE_ROLE_KEY` and `SEND_PUSH_INVOKE_SECRET` server-side.
- Supply only Firebase's public client configuration through the documented
  `FIREBASE_*` Flutter Dart defines. Never embed a service-account credential
  or Supabase service-role key in the app.
- Configure Supabase Cron or an external scheduler to invoke `send-push` with
  the server-only invocation secret. A deployed Edge Function without a
  scheduler does not provide background delivery.
- Configure APNs for iOS and verify delivery on real Android and iOS devices,
  including permission denial, token refresh, reinstall, account switch,
  logout, background/terminated delivery, quiet hours, and invalid-token
  cleanup.
- Enable the backend release-policy and runtime flags only after the required
  credentials, schedule, privacy review, and real-device checks are complete.

Google Play production access or store availability does not change the
Supabase push policy. As last checked on 2026-10-25, the hosted backend's
release policy and runtime push flag were both off, `send-push` was deployed,
and no scheduled invocation was configured. Remote FCM delivery was therefore
not active or verified at that time. Recheck the live backend before relying
on remote alerts.

See [MORT Firebase Push Owner Setup](MORT_FIREBASE_PUSH_OWNER_SETUP.md) for the
credential names and device-verification checklist. Do not use this runbook to
manually insert real user tokens or message content into production tables.
