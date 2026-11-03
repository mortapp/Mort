# Stripe Sandbox Setup — Production Project Safety

**Current production Supabase project:** `jxbnrkasktbhtiujkhay`  
**Deleted project:** `rakjydmgwwgtdislanbt` — never use.  
**Current payment release state:** disabled.

This runbook describes prerequisites; it does not authorize enabling payment operations in the production project.

1. Use the dedicated Stripe test-mode account and confirm Connect eligibility for the intended platform model and country.
2. Keep all payment, onboarding, transfer, payout, refund, and live-mode controls disabled while preparing and validating the integration.
3. Map every webhook event to a deployed handler and database transition. The handler must exist in the target project before a Stripe endpoint is pointed at it.
4. Use separate endpoint-specific signing secrets for the platform and Connect endpoints. Store them only in Supabase Edge Function secrets through a secure operator path.
5. Use synthetic QA records only in an isolated test database. Do not create synthetic users, jobs, assignments, or payment records in the live production database.
6. Run signature, replay, idempotency, concurrency, ordering, failure-retry, reconciliation, and state-transition tests.
7. Complete legal/provider eligibility review for minors, connected-account ownership, guardian involvement, payout routing, refunds, disputes, and tax responsibilities.

Never put test secrets in `.env.local`, Flutter dart-defines, screenshots, shell history, docs, or archives. Never mix test and live credentials.

## Pre-provider gate

The read-only pre-provider gate is:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/stripe-pre-provider-test-gate.ps1 -WhatIf
```

The gate's default project ref must be `jxbnrkasktbhtiujkhay`. It verifies secret *names* only, deployed function presence, configured endpoint URL, runtime mode, and control state. A failed gate is expected while required handlers, secrets, and test controls are not configured. Do not turn on production provider-operation flags just to make this gate pass.

The expected platform webhook URL, once the matching handler is deployed and reviewed, is:

`https://jxbnrkasktbhtiujkhay.supabase.co/functions/v1/stripe-webhook`

This URL is a target contract, not a claim that the function is currently deployed or that the Stripe endpoint has been redirected.

## Separate Connect endpoint

The Connect endpoint must use a handler that explicitly processes the connected-account event allowlist, including the account and payout events required by MORT. Do not reuse the platform PaymentIntent webhook secret. Do not redirect the existing Stripe sandbox Connect endpoint until the handler, database dependencies, signing secret, and end-to-end tests are verified.

## Release prohibition

No instruction in this document authorizes enabling payments, onboarding, transfers, payouts, or live mode. Those require a separate release decision after all payment gates pass.
