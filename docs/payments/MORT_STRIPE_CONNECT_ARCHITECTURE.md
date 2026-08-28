# Stripe Connect Architecture

Environment-specific provider IDs are stored in `private` tables with forced RLS. One user may have one connected-account record per environment. Account creation and Account Link generation occur in authenticated Edge Functions; return and refresh origins must match a server allowlist.

Job funding uses separate charges and transfers:

1. Accepted immutable contract version creates a payment obligation.
2. Server computes earnings, service fee, total, currency, transfer group, and idempotency key.
3. Adult presents Stripe PaymentSheet.
4. Signed webhook marks funding state.
5. Completion and dispute gates determine transfer eligibility.
6. Server creates at most one transfer for the payment intent.
7. Webhooks and reconciliation synchronize transfer/payout/refund/dispute state.

Live mode requires all runtime flags plus owner approval; sandbox and live records cannot share provider references.
