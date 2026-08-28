# MORT Payment State Machine

Payment truth is held in private server-owned records and reconciled by verified provider events.

Core progression: obligation created -> payment setup required -> authorization pending -> authorized/funded -> capture pending -> captured -> transfer pending -> payout in transit -> paid. Failure branches include authentication required, authorization expired, payment failed, disputed, refund pending, partially refunded, refunded, transfer reversal review, reversed, and closed.

Rules:

- Amount and currency come from the accepted contract obligation.
- Provider IDs and destination accounts are never selected by Flutter.
- Idempotency keys protect PaymentIntent, transfer, refund, resolution, and webhook operations.
- A verified webhook, not a client callback, changes provider-confirmed state.
- Active disputes block transfer.
- Post-transfer refunds require reversal review.
- Payment review and payment execution require separate expiring roles.
- Live and money-moving controls remain off in this deployment.
