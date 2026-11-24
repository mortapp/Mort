# Stripe Sandbox Setup

## Project and access boundary

Use only test Supabase project `ckcxakhxqlkhppsxxjhv` for this assignment. Do not use the deleted project `rakjydmgwwgtdislanbt` or any production project. Keep `MORT_STRIPE_MODE=sandbox`; never configure or use live Stripe credentials, enable live payments/payouts, subscriptions, or tips as part of this work.

## Authorized administrator setup

1. An authorized administrator configures the Stripe **test-mode** account and test-only Edge Function secrets in the Supabase secret manager: `MORT_STRIPE_MODE=sandbox`, `STRIPE_TEST_SECRET_KEY`, `STRIPE_TEST_PUBLISHABLE_KEY`, `STRIPE_TEST_WEBHOOK_SECRET`, `STRIPE_TEST_CONNECT_WEBHOOK_SECRET`, `MORT_STRIPE_OPERATIONS_SECRET`, and `MORT_STRIPE_ALLOWED_REDIRECT_ORIGINS`. Do not copy secret values into source, local `.env` files, shell history, logs, screenshots, or this runbook.
2. Deploy the Stripe Edge Functions only to `ckcxakhxqlkhppsxxjhv`. Keep JWT verification enabled for user-facing functions. The signed webhook endpoint is `https://ckcxakhxqlkhppsxxjhv.supabase.co/functions/v1/stripe-webhook`; configure its JWT behavior according to the signature-verification endpoint contract.
3. Before test-provider calls, verify the Supabase project ref, `mode=sandbox`, Stripe test-key prefix, Stripe account identity, webhook endpoint/signature configuration, and that no live key names or live gates are enabled.
4. Verify **all 13 deployed Edge Functions** by slug, source/version, configuration, and exact RPC dependencies. Confirm all required RPCs exist in the target project and the migration ledger agrees with tracked migrations. Do not treat source files or deployment status alone as integration evidence.
5. Keep provider mutation gates closed until the authorized owner approves a bounded sandbox QA window. A provider test requires the pre-provider and Connect webhook gates to pass; do not bypass disabled gates.
6. Use synthetic QA identities and test payment methods only. Record actual Stripe object/event IDs, expected and observed result, and cleanup/reconciliation status. Never test with real cards or real people.
7. Run automated, database, and per-platform client checks. Then run the provider success/decline/3DS/cancel/retry, Connect, transfer/reversal, refund, webhook/recovery, dispute, reconciliation, and settlement matrix. Report provider scenarios as **not run** until backed by actual test-mode Stripe evidence.

## Forward-only database recovery note

The deployed financial-history Edge Function calls `get_my_financial_history_v2`. The November 18 test audit found that RPC missing from this project even though its source implementation existed. A tracked forward migration, `20261118144900_stripe_financial_history_cursor_v2_test_only.sql`, restores the authenticated, owner-bound RPC; the exact RPC was exercised with a synthetic non-existent user and returned an empty result. This does not validate the full cross-user integration suite or provider flows. Do not replay migrations already recorded in the target project.

## Pre-provider gate

Before any Stripe test-mode mutation, run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/stripe-pre-provider-test-gate.ps1 -WhatIf
```

The gate is read-only: it checks the test-key and signing-secret **names**, the authorized project ref and sandbox mode, the webhook endpoint, and explicit provider-operation gates; it never calls Stripe or opens a gate. A failing gate is expected while test-provider operation flags are disabled.

Keep non-secret project/configuration references in the protected operator shell only. `SUPABASE_ACCESS_TOKEN`, database credentials, Stripe API keys, and webhook signing secrets must never be committed, printed, or supplied to this runbook. Test-only provider object IDs and the expected status/cleanup outcome may be recorded in the protected QA evidence report.
