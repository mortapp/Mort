# Stripe Video Adaptation Notes

Any external tutorial or video is a conceptual reference only. MORT does not copy client-side amount calculation, direct destination charges, secret keys in mobile code, webhook trust without signature verification, synchronous payout assumptions, or adult-only account assumptions.

MORT adapts the useful sequence: create connected account, open Stripe-hosted onboarding, synchronize capability state, create a PaymentIntent server-side, present PaymentSheet, wait for verified webhook state, confirm job completion, create one idempotent transfer, and reconcile payouts/refunds/disputes. Current Stripe API behavior and MORT's server contracts take precedence over video UI or code.
