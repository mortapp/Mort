# MORT Firebase Push Owner Setup

Updated: 2026-10-25

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
6. After applying `mort_push_delivery_scheduler` through the approved hosted
   migration process, add these values to Supabase Vault:
   - `mort_supabase_url`: the MORT project URL from Supabase API settings.
   - `mort_supabase_anon_key`: the current legacy anon JWT from Supabase API
     settings. Do not use a service-role key for the scheduled invocation.
   - `mort_send_push_invoke_secret`: the same protected value already used for
     the `SEND_PUSH_INVOKE_SECRET` Edge Function secret.
7. Supply Firebase public client values to the release build using the
   `MORT_FIREBASE_*` Dart defines documented in `AppConfig`; do not commit a
   generated configuration file containing environment-specific values.
8. Set the hosted remote-push runtime flag only after the credential and device
   checks below pass.

Use the Supabase Dashboard SQL Editor with the protected values sourced from
their approved settings; never place values in this repository or runbook:

```sql
select vault.create_secret('<MORT project URL>', 'mort_supabase_url');
select vault.create_secret('<current MORT legacy anon JWT>', 'mort_supabase_anon_key');
select vault.create_secret('<existing SEND_PUSH_INVOKE_SECRET value>', 'mort_send_push_invoke_secret');
```

The scheduler calls the active `send-push` Edge Function only when both backend
push gates are on, all three Vault entries are present, and the URL matches
MORT's Supabase project. Its Cron job runs once per minute. Do not enable the
runtime flag until the FCM Edge Function secrets are installed and device
delivery checks pass.

To verify the schedule without reading secret values or request headers:

```sql
select jobname, schedule, active
from cron.job
where jobname = 'mort-send-push';

select created, status_code, error_msg
from net._http_response
order by created desc
limit 20;
```

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

- Google Play production access/public availability is separate from Supabase's
  internal release policy and push-delivery flags. This runbook describes the
  backend delivery controls, not the Play release track.
- `send-push`: ACTIVE, JWT verification enabled.
- Server invoke secret: present.
- FCM provider secrets: absent.
- Database and client remote-push flags: false.
- Real FCM delivery: not verified.
- `pg_cron` is enabled; `pg_net` is disabled.
- No scheduled invocation of `send-push` is configured.
- The repository contains a fail-closed scheduler migration, but it has not been
  applied to the hosted database. Hosted migration history must be reconciled
  through the approved owner process before any migration is applied.

