# Stripe Sandbox Setup

1. Use a Stripe test-mode account and confirm Connect is available for the intended platform model and country.
2. Set `MORT_STRIPE_MODE=sandbox`, `STRIPE_TEST_SECRET_KEY`, `STRIPE_TEST_PUBLISHABLE_KEY`, `STRIPE_TEST_WEBHOOK_SECRET`, `MORT_STRIPE_OPERATIONS_SECRET`, and `MORT_STRIPE_ALLOWED_REDIRECT_ORIGINS` only in Supabase Edge Function secrets.
3. Deploy all `stripe-*` functions to project `rakjydmgwwgtdislanbt`; keep `stripe-webhook` JWT verification disabled because it verifies Stripe signatures itself.
4. Register the deployed webhook endpoint and subscribe to the event list in `MORT_STRIPE_WEBHOOKS.md`.
5. Keep all database enablement flags false, run configuration and unauthorized probes, then enable sandbox onboarding/funding in a controlled QA window.
6. Use Stripe test identities, test payment methods, synthetic job records, and dedicated QA users only.
7. Run every `qa-stripe-*.mjs` test plus real provider flows and reconcile the resulting objects.

Never put test secrets in `.env.local`, Flutter dart-defines, screenshots, shell history, docs, or archives.


## Ordered pre-provider gate

Before any Stripe test-mode mutation, run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/stripe-pre-provider-test-gate.ps1 -WhatIf
```

The gate is read-only and evaluates, in order: TEST secret-key name present; TEST publishable-key name present; the deployed `stripe-webhook` endpoint matches `https://rakjydmgwwgtdislanbt.supabase.co/functions/v1/stripe-webhook`; TEST webhook-secret name present; linked project and runtime mode are sandbox with no live Stripe secret names; and all sandbox provider-mutation runtime flags are explicitly enabled while live flags remain off.

The gate writes only booleans, timestamps, the project ref, and safe status labels to `artifacts/stripe/pre-provider-gate.json`. It rejects credential-like output and never calls Stripe. A failing gate is expected while MORT's provider-operation flags remain disabled; the gate does not enable them.

For an operator run, keep `MORT_SUPABASE_PROJECT_REF=rakjydmgwwgtdislanbt`, `MORT_STRIPE_MODE=sandbox`, and the non-secret `MORT_STRIPE_TEST_WEBHOOK_URL` in the protected shell. `SUPABASE_ACCESS_TOKEN` and `SUPABASE_DB_PASSWORD` are operator credentials used only for Supabase/DB reads and must never be committed or printed.
