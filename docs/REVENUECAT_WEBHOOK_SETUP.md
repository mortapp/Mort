# RevenueCat Webhook Setup

Updated: 2026-07-09

## Current Status

- Supabase project: `rakjydmgwwgtdislanbt`
- Function URL: `https://rakjydmgwwgtdislanbt.supabase.co/functions/v1/revenuecat-webhook`
- Function deployed: yes
- JWT verification: disabled for this function so RevenueCat can call it directly
- RevenueCat webhook integration: created by API
- Webhook authorization header: generated in command scope and set as a Supabase Edge Function secret only
- Secrets printed or committed: no

## Server Secrets

Configured in Supabase/server environment only:

- `REVENUECAT_WEBHOOK_AUTH_HEADER`
- `SUPABASE_SERVICE_ROLE_KEY` is required by the function runtime. The Supabase CLI skipped setting a `SUPABASE_`-prefixed secret directly, but the deployed function read the runtime service role value successfully during QA.

Not allowed in Flutter/mobile:

- RevenueCat v2 secret API key
- RevenueCat webhook authorization header
- Supabase service role key
- Supabase access token
- Supabase DB password

## Deploy Command

```powershell
pnpm exec supabase functions deploy revenuecat-webhook --project-ref rakjydmgwwgtdislanbt --no-verify-jwt --use-api
```

## Secret Command Shape

Secrets were set from a temporary file under `%TEMP%`, then that file was deleted. Do not put the values in `.env.local` or source.

```powershell
pnpm exec supabase secrets set --project-ref rakjydmgwwgtdislanbt --env-file <temp-secret-file>
```

## Event Mapping

- `mort_username_change_token_1` grants one username token credit.
- `mort_job_boost_1` grants one job boost credit.
- `mort_ad_free_lifetime` grants ad-free.
- `mort_plus_monthly`, `mort_plus_yearly`, and `mort_plus_lifetime` grant Plus and ad-free behavior.
- `mort_adult_pro_monthly` grants Adult Pro.
- `mort_guardian_plus_monthly` grants Guardian Plus.
- `mort_profile_style_pack` grants profile style unlock.

## QA Results

- Missing authorization rejected with `401`.
- Invalid authorization rejected with `401`.
- Authorized QA webhook accepted with `200`.
- QA event wrote `revenuecat_events`.
- QA username token event granted exactly one credit to a Rebuild QA profile.
- Duplicate event returned `duplicate_event` and did not grant twice.

## Manual RevenueCat Dashboard Step

The RevenueCat webhook integration was created by API. After product/offering setup is completed, manually confirm in RevenueCat dashboard that the integration is enabled for the expected app/environment and that event deliveries show `200` responses.
