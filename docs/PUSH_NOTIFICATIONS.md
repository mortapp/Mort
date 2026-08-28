# Push Notifications

MORT uses Expo push tokens on-device and a Supabase Edge Function for delivery. The Expo/mobile app never contains a service-role key.

## Client Registration

`lib/notifications.ts` requests iOS notification permission on a real device, reads the EAS project id, gets an Expo push token, and stores it in:

- `push_tokens`
- `profiles.expo_push_token` as a fallback compatibility field

Logout marks the user's push tokens inactive.

## Queue Creation

Database triggers create both `notifications` rows and `notification_events` rows for application updates, guardian approvals, proof uploads, safety pings, verification decisions, and reports.

Push text should stay generic. Do not include exact addresses, phone numbers, payment handles, report details, or sensitive minor information in push bodies.

## Edge Function

`supabase/functions/send-push/index.ts`:

- processes pending `notification_events`
- can process one notification id for staging tests
- sends through Expo's server push API
- marks events `sent` or `failed`
- deactivates `DeviceNotRegistered` tokens
- sanitizes direct test push title/body for phone/email patterns
- uses `SUPABASE_SERVICE_ROLE_KEY` only inside the Edge Function runtime
- requires `x-mort-push-secret` to match `SEND_PUSH_INVOKE_SECRET`

## Deploy

```powershell
supabase functions deploy send-push
supabase secrets set SUPABASE_URL=https://<project-ref>.supabase.co
supabase secrets set SUPABASE_SERVICE_ROLE_KEY (server-side only placeholder)<service-role-key-from-dashboard>
supabase secrets set SEND_PUSH_INVOKE_SECRET (server-side only placeholder)<long-random-invocation-secret>
```

## Test Safely

Use a staging notification row first:

```sql
insert into public.notification_events (recipient_id, title, body, data)
values ('<real-test-user-id>', 'MORT test', 'Open MORT for details.', '{"type":"staging-test"}');
```

Then invoke the queue:

```powershell
$env:SUPABASE_URL="https://<project-ref>.supabase.co"
$env:SUPABASE_FUNCTION_JWT="<temporary-function-jwt-or-anon-key-for-staging>"
$env:SEND_PUSH_INVOKE_SECRET (server-side only placeholder)"<same-secret-set-on-edge-function>"
.\scripts\invoke-send-push.ps1 -BatchSize 25
```

The script can also use a full function URL:

```powershell
$env:SUPABASE_FUNCTION_URL="https://<project-ref>.supabase.co/functions/v1/send-push"
.\scripts\invoke-send-push.ps1 -BatchSize 25
```

## Check Results

Inspect pending/sent/failed events in staging:

```sql
select id, recipient_id, title, status, last_error, created_at, sent_at
from public.notification_events
order by created_at desc
limit 25;
```

Check push token errors:

```sql
select user_id, platform, is_active, last_error, updated_at
from public.push_tokens
order by updated_at desc
limit 25;
```

`DeviceNotRegistered` means Expo reports the device token is no longer valid. The Edge Function marks those tokens inactive.

## Debug Checklist

- Confirm the user registered a push token on a real iPhone or EAS build.
- Confirm `EXPO_PUBLIC_PROJECT_ID` matches the EAS project id.
- Confirm `SEND_PUSH_INVOKE_SECRET` in the request header matches the Edge Function secret.
- Confirm the Edge Function has `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, and `SEND_PUSH_INVOKE_SECRET`.
- Confirm push body text does not contain sensitive personal data.

For scheduled delivery, configure Supabase Cron or an external scheduler to invoke the function periodically with the same secret header. Do not put service-role keys in mobile, web, GitHub, or this script.

