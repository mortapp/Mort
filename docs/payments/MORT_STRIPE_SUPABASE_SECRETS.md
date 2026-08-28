# Stripe Supabase Secrets

Server-only secret names:

- `MORT_STRIPE_MODE`
- `STRIPE_TEST_SECRET_KEY`
- `STRIPE_TEST_PUBLISHABLE_KEY`
- `STRIPE_TEST_WEBHOOK_SECRET`
- `STRIPE_LIVE_SECRET_KEY`
- `STRIPE_LIVE_PUBLISHABLE_KEY`
- `STRIPE_LIVE_WEBHOOK_SECRET`
- `MORT_STRIPE_OPERATIONS_SECRET`
- `MORT_STRIPE_ALLOWED_REDIRECT_ORIGINS`

Set with `npx supabase secrets set --project-ref rakjydmgwwgtdislanbt NAME` from a protected interactive shell or secret manager. Publishable keys are delivered to authenticated clients by `stripe-config`; secret and webhook keys never leave Edge Functions. Do not use `.env.local`, Flutter source, dart-defines, committed files, CI logs, or release archives for these values.

After rotation, redeploy affected functions, run unauthorized/config probes, send a signed sandbox event, confirm old credentials fail, and document the rotation without recording values.
