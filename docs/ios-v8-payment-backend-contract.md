# iOS V8 Payment Backend Contract

This contract is platform-neutral because the native SwiftUI V8 source is not
present in this repository. iOS must use the same server-authoritative
contracts as Flutter and must not implement a parallel payment system.

## Authentication

- Authenticate with the existing MORT Supabase session.
- Send only opaque identifiers and request IDs from the client.
- Never send authoritative cents, service fees, compensation, receipt facts,
  provider outcomes, or connected-account details as client authority.

## Funding

1. Call `stripe-create-job-funding-quote` with the eligible contract ID and a
   client request ID.
2. Treat the returned quote ID, cents, currency, policy version, and expiry as
   display data only.
3. Call `stripe-create-job-payment-intent` with the quote ID and a new request
   ID.
4. Configure the native Stripe PaymentSheet from the returned sandbox
   publishable key, PaymentIntent client secret, customer ID, and ephemeral
   key. Accept only `pk_test_` while sandbox completion is active.
5. PaymentSheet completion is not funding confirmation. Re-read backend payment
   state and show the job as funded only after normalized provider-confirmed
   success.

The app must remain fail-closed when the quote, provider configuration,
PaymentIntent, webhook reconciliation, or payment-state read is unavailable.

## Settlement, transfers, and refunds

- Settlement is an operations-authorized server workflow after authoritative
  job outcome.
- The client never selects compensated base cents.
- A transfer amount is exactly the server-computed compensated base amount.
- Refund amounts are server-computed from settlement components.
- Transfer success is not bank payout success.
- Original documents are immutable; refunds, adjustments, reversals, tips, and
  payout status are separate linked records.

## Tips

- Tips use a separate post-work PaymentIntent and separate transfer.
- The server enforces policy, assigns 100% of the tip principal to the teen,
  charges zero MORT percentage fee, and excludes tips from Fair Pay.
- A failed or cancelled tip does not mutate base settlement.

## History and receipts

- Use authenticated, role-isolated history and receipt lookup contracts.
- Display only privacy-safe usernames and masked provider references.
- Never construct receipt IDs, order numbers, or financial documents on-device.
- Receipt access is authorized by ownership, not by guessing a receipt or order
  number.

## Release boundary

Public marketplace/payment activation remains disabled. No live provider
credentials or live money movement may be enabled by this contract.
