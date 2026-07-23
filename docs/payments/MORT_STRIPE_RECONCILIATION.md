# Stripe Reconciliation

Reconciliation compares private MORT records with Stripe test/live objects by environment and provider ID for payments, connected accounts, transfers, payouts, refunds, disputes, and stale webhook claims. It never accepts Flutter state as provider truth.

Run after webhook downtime, deployment, credential rotation, provider incident, unexpected state, and on a scheduled cadence before live launch. Classify each item as matched, corrected, needs review, or failed; write only safe result codes. Missing money movement, amount/currency mismatch, environment mismatch, duplicate references, or stale disputed states trigger a financial hold and two-person review.
