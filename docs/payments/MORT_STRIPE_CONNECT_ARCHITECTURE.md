# Stripe Connect Architecture

Environment-specific provider IDs are stored in `private` tables with forced RLS. One user may have one connected-account record per environment. Account creation and Account Link generation occur in authenticated Edge Functions; return and refresh origins must match a server allowlist.

Job funding is implemented around separate charges and transfers:

1. An accepted immutable contract version creates a payment obligation.
2. The server derives base pay and the owner-approved flat service fee per completed gig, then binds total, currency, transfer group, policy version, and idempotency key. Percentage-based pricing is not permitted; the current test policy remains zero until pricing approval.
3. The adult presents Stripe PaymentSheet. The current PaymentIntent uses default automatic capture; it is not a delayed authorization hold.
4. A correctly signed webhook marks funding state.
5. Completion, cancellation, refund, and dispute gates determine whether settlement may proceed.
6. The server creates at most one transfer to the eligible connected account.
7. Webhooks and reconciliation synchronize transfer, payout, refund, and dispute state.

Because separate charges and transfers place the platform in the fund-flow path, the legal entity, account type, connected-account owner, guardian/minor eligibility, provider fee payer, refunds, disputes, negative balances, and payout responsibility require written provider and qualified legal/finance approval. A functional API or hosted onboarding link is not that approval.

Live mode requires all runtime flags plus dated owner approval. Sandbox and live records cannot share provider references. Test and production projects, secrets, and webhook endpoints remain separate; no production deployment or live financial activity was performed for this review.
