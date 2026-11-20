# Stripe Job Funding

Funding may be quoted only for the adult party to an accepted, current contract with a valid payment obligation. The server derives base pay from that obligation and calculates the total; clients cannot supply the payable amount. Quote, PaymentIntent, and database idempotency prevent duplicate funding, while verified provider webhooks—not PaymentSheet completion—establish payment state.

## Fee model

MORT's product requirement is one flat service fee per completed gig, not a percentage, minimum/maximum percentage band, or teen subscription. The fee must be an owner-approved fixed cent amount; no launch amount is approved in this migration. The test policy is explicitly zero-fee only and does not establish a commercial price. Legacy or unpriced policies fail closed rather than falling back to basis-point math.

The current PaymentIntent creation omits `capture_method`, so it uses Stripe's default automatic capture when the customer confirms. The fixed fee is included in the funding quote at that point. The fee's treatment when work is cancelled, partially completed, refunded, or disputed still requires approved product/legal economics; do not enable funding until those terms and the exact fee are approved.

## Launch boundary

In the inspected test project, payment, funding, onboarding, transfer, refund, live-mode, and provider-QA controls remain false. The test fee is zero. No provider calls, test charges, transfers, refunds, connected accounts, or webhook events were created during this review. See `MORT_STRIPE_LIVE_READINESS.md` for the remaining owner, provider, legal, tax, privacy, accounting, operations, and device gates.


The unused legacy direct-preparation RPC that calculated a percentage fee has been disabled in the test project and retained only as a fail-closed compatibility stub. Its dependent legacy record RPC fails before writing; the supported path is the quote-bound flow described above.
