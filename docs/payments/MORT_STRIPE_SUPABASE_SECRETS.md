# Stripe Supabase Secrets

Server-only secret names:

- `MORT_STRIPE_MODE`
- `STRIPE_TEST_SECRET_KEY`
- `STRIPE_TEST_PUBLISHABLE_KEY`
- `STRIPE_TEST_WEBHOOK_SECRET`
- `STRIPE_TEST_CONNECT_WEBHOOK_SECRET`
- `STRIPE_LIVE_SECRET_KEY`
- `STRIPE_LIVE_PUBLISHABLE_KEY`
- `STRIPE_LIVE_WEBHOOK_SECRET`
- `STRIPE_LIVE_CONNECT_WEBHOOK_SECRET`
- `MORT_STRIPE_OPERATIONS_SECRET`
- `MORT_STRIPE_ALLOWED_REDIRECT_ORIGINS`

Set with `npx supabase secrets set --project-ref rakjydmgwwgtdislanbt NAME` from a protected interactive shell or secret manager. Publishable keys are delivered to authenticated clients by `stripe-config`; secret and webhook keys never leave Edge Functions. Do not use `.env.local`, Flutter source, dart-defines, committed files, CI logs, or release archives for these values.

After rotation, redeploy affected functions, run unauthorized/config probes, send a signed sandbox event, confirm old credentials fail, and document the rotation without recording values.


## Pre-provider gate handling

The pre-provider gate discovers remote **names only** with `supabase secrets list`; it never prints raw command output and aborts if output resembles a Stripe credential or JWT. The gate also confirms the deployed `stripe-webhook` function before accepting the platform webhook signing path as configured. Task 31 additionally requires the TEST Connect webhook signing-secret name before account or payout scenarios can run.

Non-secret operator metadata:

- `MORT_SUPABASE_PROJECT_REF=rakjydmgwwgtdislanbt`
- `MORT_STRIPE_MODE=sandbox`
- `MORT_STRIPE_TEST_WEBHOOK_URL=https://rakjydmgwwgtdislanbt.supabase.co/functions/v1/stripe-webhook`

Local operator credentials used for read-only gate checks, not Edge Function secrets:

- `SUPABASE_ACCESS_TOKEN`
- `SUPABASE_DB_PASSWORD`

Keep those credentials only in a protected shell/secret manager. The gate evidence records no credential values, digests, database password, access token, client secret, PaymentIntent secret, card data, or provider payload.
