# MORT Stripe Connect Architecture

Status: sandbox architecture implemented; provider execution and live mode disabled.

- Flutter uses only Stripe publishable configuration and server-created Payment Sheet values.
- Stripe secret/restricted keys and webhook secrets exist only in Supabase server secrets.
- Adults cannot submit authoritative amount, currency, recipient, connected account, fee, or success state.
- Amounts are integer cents derived from accepted job obligations.
- Connected account IDs, customer IDs, bank details, and payment credentials are held in private schema records and excluded from public profile/queue responses.
- Connect onboarding uses single-use Stripe-hosted links and an HTTPS redirect allowlist.
- Teen/guardian provider requirements are represented separately from optional MORT Guardian Mode.
- Verified raw-body webhooks own provider state reconciliation and reject replay/idempotency collisions.

All money-moving runtime controls are off. No real charge, capture, transfer, refund, reversal, payout, or live Connect action is claimed.
