# MORT Payment Owner Setup Guide

Updated: 2026-07-30

Status: architecture only. Provider operations and live payments are disabled.

## Before Provider Setup

1. Obtain written Stripe approval for the physical-services marketplace model,
   separate charges/transfers, countries, adult payers, connected accounts, and
   any provider-approved representative flow involving a teen worker.
2. Obtain qualified legal, privacy, tax, worker-classification, refunds,
   disputes, retention, receipts, and negative-balance review.
3. Name trained financial operations and on-call owners. Do not claim 24/7
   coverage until people have accepted and exercised it.
4. Approve a versioned partial-compensation policy and customer-facing terms.

## Sandbox Setup

1. Create a dedicated Stripe test environment with Connect enabled for the
   approved model.
2. In Supabase Edge Function secrets, set only the test secret key, test
   publishable key, test webhook secret, operations secret, allowed redirect
   origins, and `MORT_STRIPE_MODE=sandbox`. Never place them in Flutter,
   `.env.local`, screenshots, logs, docs, or archives.
3. Confirm all nine `stripe-*` functions are ACTIVE. Keep `stripe-webhook` JWT
   verification off because it authenticates the raw Stripe signature; keep JWT
   verification on for authenticated client entry points.
4. Register the exact webhook endpoint and only the events listed in
   `docs/payments/MORT_STRIPE_WEBHOOKS.md`.
5. Rerun unauthorized probes and all Stripe/payment QA while every operation
   flag remains false.
6. Record provider approval evidence through a reviewed forward migration.
   Only then may a controlled sandbox window set
   `sandbox_provider_qa_approved=true` and enable the minimum tested operation.
7. Use dedicated adult QA accounts, approved provider test identities, test
   methods, and synthetic MORT jobs. Do not use a minor's real identity or card.
8. Reconcile every test charge, refund, transfer, reversal, dispute, payout,
   incident, and webhook against provider truth, then turn sandbox operations
   off again.

## Production Boundary

Production activation must be a separately reviewed forward migration after
every item in `MORT_PAYMENT_PRODUCTION_ACTIVATION_CHECKLIST.md` is complete.
Never update the control row ad hoc and never activate live secrets or flags as
part of ordinary app deployment.
