# Stripe Sandbox Setup

Updated: 2026-11-04

## Current environment status

- Production Supabase: `jxbnrkasktbhtiujkhay`.
- QA Supabase: `ckcxakhxqlkhppsxxjhv`.
- Retired/deleted Supabase project: `rakjydmgwwgtdislanbt` — never use it.
- Production Edge Functions currently active:
  - `stripe-create-assignment-payment-intent` (JWT verification enabled).
  - `stripe-assignment-webhook` (JWT verification disabled because the handler validates Stripe signatures).
  - `stripe-runtime-status` (JWT verification enabled).
- Production Stripe runtime controls are disabled: payments, payouts, transfers, onboarding, and live mode are false.
- QA project currently has no deployed Edge Functions. Hosted Stripe regression and provider E2E remain skipped until QA-only credentials are provisioned and QA functions are deployed.
- Do not enable production payments, payouts, transfers, connected-account onboarding, or provider mutations as part of a sandbox test.

## QA-only setup

Use a Stripe test-mode account and QA project only. Provision the following in a protected QA GitHub Actions/Supabase environment:

- `STRIPE_TEST_SECRET_KEY`
- `STRIPE_TEST_PUBLISHABLE_KEY`
- `STRIPE_TEST_WEBHOOK_SECRET`
- `STRIPE_TEST_CONNECT_WEBHOOK_SECRET`
- `MORT_STRIPE_OPERATIONS_SECRET`
- `MORT_STRIPE_ALLOWED_REDIRECT_ORIGINS`
- QA-only Supabase service-role, database, and access-token credentials.

Never reuse production service-role keys, database passwords, Supabase access tokens, or live Stripe credentials in QA.

The QA webhook endpoint, after the function is deployed and verified, is:

`https://ckcxakhxqlkhppsxxjhv.supabase.co/functions/v1/stripe-assignment-webhook`

Keep the webhook's JWT verification disabled only because the webhook handler validates Stripe's signature itself. Do not disable JWT verification on authenticated payment functions.

## Ordered pre-provider gate

Before any Stripe test-mode mutation, run the read-only gate against QA:

```powershell
$env:MORT_SUPABASE_PROJECT_REF = 'ckcxakhxqlkhppsxxjhv'
$env:MORT_STRIPE_MODE = 'sandbox'
$env:MORT_STRIPE_TEST_WEBHOOK_URL = 'https://ckcxakhxqlkhppsxxjhv.supabase.co/functions/v1/stripe-assignment-webhook'
powershell -ExecutionPolicy Bypass -File scripts/stripe-pre-provider-test-gate.ps1 -WhatIf
```

The gate must confirm the QA project, sandbox mode, test-key names, test webhook secret, and explicitly configured QA sandbox flags. It must reject production project refs and any live Stripe secret names.

A failing gate is expected while QA provider-mutation flags remain disabled. The gate does not enable them. Never bypass a failed gate.

## Test procedure

1. Deploy only the required Stripe functions to QA after the QA secrets are provisioned.
2. Run contract, unauthorized, signature, replay, idempotency, and webhook-event tests.
3. Use Stripe test identities, test payment methods, synthetic job records, and dedicated QA users only.
4. Reconcile all test objects and confirm no production requests occurred.
5. Keep production runtime controls disabled after the test.

No production payment activation or live provider mutation is authorized by this setup guide.
