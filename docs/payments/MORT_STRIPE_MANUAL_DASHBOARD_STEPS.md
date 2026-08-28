# Stripe Dashboard Steps

1. Confirm the Stripe legal entity, support contacts, statement descriptor, bank account, tax settings, and Connect platform profile.
2. Ask Stripe to confirm the supported connected-account model, countries, age/minor representative requirements, capabilities, and separate-charges-and-transfers eligibility.
3. In test mode, obtain restricted server credentials where possible and record them only in the server secret manager.
4. Register the deployed Supabase webhook URL and subscribe to payment intent, account, transfer, payout, refund, and dispute events. Copy its signing secret directly to Supabase secrets.
5. Configure branding and Stripe-hosted onboarding return/refresh domains from the reviewed allowlist.
6. Test account onboarding, required information, capability restriction, PaymentSheet authentication, success/failure, transfer, reversal, refund, dispute, and payout events.
7. Compare Dashboard objects to MORT reconciliation output and close every mismatch.
8. Keep live mode disabled until `MORT_STRIPE_LIVE_READINESS.md` has owner, legal, safety, finance, and engineering sign-off.
