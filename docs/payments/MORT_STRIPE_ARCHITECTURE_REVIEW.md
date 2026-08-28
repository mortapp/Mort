# Stripe Architecture Review

Status: sandbox architecture implemented; provider connection not configured or network-tested.

MORT uses Stripe Connect separate charges and transfers for marketplace job payments. Adults fund a server-calculated job obligation on the platform account. Funds are transferred only after an eligible completion path and only to an eligible connected account. Flutter receives a short-lived PaymentSheet client secret but never a Stripe secret key.

The implementation has private, forced-RLS financial tables; authenticated caller-bound Edge Functions; service-role-only provider RPCs; idempotency keys; amount/currency/environment checks; signed webhook claim and replay protection; transfer uniqueness; refund/dispute holds; reconciliation records; and a live-mode multi-gate. Runtime defaults keep all Stripe operations disabled.

Remaining gates are Stripe account approval, sandbox credentials, deployed functions, webhook delivery, real sandbox PaymentSheet tests, connected-account onboarding tests, legal review of minors and payouts, dispute/negative-balance ownership, monitoring, physical-device QA, and live approval. See Stripe's [separate charges and transfers](https://docs.stripe.com/connect/separate-charges-and-transfers) and [marketplace tasks](https://docs.stripe.com/connect/marketplace/essential-tasks).
