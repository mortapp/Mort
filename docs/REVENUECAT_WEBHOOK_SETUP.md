# RevenueCat Webhook Setup

Updated: 2026-11-22

## Current Status

- Isolated QA project: `ckcxakhxqlkhppsxxjhv`
- Production project: `jxbnrkasktbhtiujkhay`
- Function URL (QA): `https://ckcxakhxqlkhppsxxjhv.supabase.co/functions/v1/revenuecat-webhook`
- Historical deployment records naming `rakjydmgwwgtdislanbt` are retired and must not be used.
- Current QA/provider deployment status: not verified in this session; owner-controlled RevenueCat and QA secrets are required.
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

## QA Deploy Command — prepared, not executed

```powershell
pnpm exec supabase functions deploy revenuecat-webhook --project-ref ckcxakhxqlkhppsxxjhv --no-verify-jwt --use-api
```

## Secret Command Shape

Secrets were set from a temporary file under `%TEMP%`, then that file was deleted. Do not put the values in `.env.local` or source.

```powershell
pnpm exec supabase secrets set --project-ref ckcxakhxqlkhppsxxjhv --env-file <temp-secret-file>
```

The QA operator must use a protected temporary secret file and owner-controlled provider credentials. Do not execute this command without authorization, and do not put secret values in source, shell history, or the repository.

## Production promotion — prepared, not executed

After QA webhook signature, replay, duplicate-event, entitlement, and reconciliation evidence is approved, the separately authorized production deployment command is:

```powershell
pnpm exec supabase functions deploy revenuecat-webhook --project-ref jxbnrkasktbhtiujkhay --no-verify-jwt --use-api
```

No production deployment, RevenueCat activation, product/offering change, or payment entitlement change was performed in this session.

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
