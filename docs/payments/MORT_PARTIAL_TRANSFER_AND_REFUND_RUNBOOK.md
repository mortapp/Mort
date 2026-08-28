# Partial Transfer and Refund Runbook

1. Confirm accepted obligation and captured amount in server/provider records.
2. Confirm human review, policy basis, participant evidence, and no unresolved provider dispute.
3. Reviewer records bounded cents; a separate operator confirms execution.
4. The Edge Function loads amount, currency, source charge, and destination from private server state.
5. Use server idempotency keys for transfer/refund calls.
6. Reject negative, zero, excessive, duplicate, wrong-environment, or live-disabled operations.
7. If a transfer already occurred, require reversal review before refund.
8. Reconcile verified webhook totals and preserve provider result/audit events.

Do not run this against live Stripe until all live gates and qualified reviews are complete.
