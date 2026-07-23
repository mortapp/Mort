# Stripe Live Setup

Live activation is a separate release decision, not a key swap.

Required before setting `MORT_STRIPE_MODE=live`: Stripe account/Connect approval; legal review for teen work, guardians, taxes, refunds, disputes, and payout eligibility; live privacy and terms; owner-approved fee schedule; verified support and financial-operations roles; webhook monitoring; incident and negative-balance funding plan; sandbox exit report; physical Android/iOS testing; and a rollback drill.

Create separate live secrets and a live webhook endpoint. Never reuse test object IDs. Enable database gates in stages: provider connectivity, onboarding, job funding, refunds, then transfers/payouts. `stripe_live_mode_enabled` and `live_owner_approved` must both be true, and connected-account/payout approval gates remain independent. Start with restricted pilot limits and public marketplace disabled.
