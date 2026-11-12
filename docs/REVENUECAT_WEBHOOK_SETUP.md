# RevenueCat Webhook Setup

Updated: 2026-11-04

## Current status

The historical RevenueCat webhook deployment and QA evidence referred to the retired/deleted Supabase project `rakjydmgwwgtdislanbt`. That project is gone; its deployment, secrets, and test records are not available to the current environment.

Current project inventory:
- Production Supabase: `jxbnrkasktbhtiujkhay` — no `revenuecat-webhook` Edge Function is currently deployed.
- QA Supabase: `ckcxakhxqlkhppsxxjhv` — no Edge Functions are currently deployed.
- No current production RevenueCat webhook endpoint is active or verified.

Do not treat the historical July 2026 QA results as evidence of a working current integration.

## QA-only implementation

After QA credentials and a RevenueCat sandbox/test project are provisioned:

1. Review `supabase/functions/revenuecat-webhook/index.ts` and confirm its authorization-header validation and idempotency behavior.
2. Deploy the function to QA only:
   ```powershell
   pnpm exec supabase functions deploy revenuecat-webhook --project-ref ckcxakhxqlkhppsxxjhv --no-verify-jwt --use-api
   ```
3. Set `REVENUECAT_WEBHOOK_AUTH_HEADER` in QA Edge Function secrets. Use only the QA runtime's built-in Supabase service-role configuration; never expose a service-role key in client code.
4. Configure the RevenueCat test webhook to:
   `https://ckcxakhxqlkhppsxxjhv.supabase.co/functions/v1/revenuecat-webhook`
5. Verify missing/invalid authorization returns 401, valid QA events are accepted, duplicate event IDs do not grant twice, and entitlement/credit changes are limited to the correct QA user.
6. Confirm logs contain no production project requests or credential values.

## Secret boundary

Never place RevenueCat v2 secret API keys, webhook authorization headers, Supabase service-role keys, Supabase access tokens, or database passwords in Flutter/mobile code, `.env.local`, screenshots, shell history, docs, or archives.

## Production gate

Do not deploy the RevenueCat function or configure production webhooks until QA tests pass, the production migration/schema contract is reviewed, backup/restore evidence exists, and the release owner explicitly approves production deployment. No entitlement, ad-free, Plus, Adult Pro, or Guardian Plus access should be granted based on unverified provider events.

## Event mapping

The source currently defines mappings for:
- `mort_username_change_token_1`
- `mort_job_boost_1`
- `mort_ad_free_lifetime`
- `mort_plus_monthly`, `mort_plus_yearly`, and `mort_plus_lifetime`
- `mort_adult_pro_monthly`
- `mort_guardian_plus_monthly`
- `mort_profile_style_pack`

Revalidate product IDs, entitlements, and current business rules in QA before enabling any mapping in production.
