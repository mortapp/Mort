# Stripe Webhooks

Endpoint: Supabase `stripe-webhook`, configured with `verify_jwt=false` because Stripe does not send a Supabase JWT. Security comes from exact raw-body verification using the environment-specific `whsec_` secret, a 512 KiB body cap, live/test match, provider event uniqueness, payload SHA-256, and atomic claim/completion RPCs.

The QA sandbox uses two distinct enabled destinations that both point to the QA `stripe-webhook` function:

- Platform snapshots use `STRIPE_TEST_WEBHOOK_SECRET` and subscribe to PaymentIntent, dispute, transfer, and refund events.
- Connected-account snapshots use `STRIPE_TEST_CONNECT_WEBHOOK_SECRET` and subscribe to `account.updated`, `payout.created`, `payout.updated`, `payout.paid`, `payout.failed`, and `payout.canceled`.

The Connect destination must be configured for **Connected accounts** and **Snapshot** events. Do not create a duplicate destination when the existing QA Connect destination is already enabled. Production uses the separate project `jxbnrkasktbhtiujkhay` and live signing secrets; do not mix environments.

Handled families: `payment_intent.*`, `account.updated`, `charge.dispute.*`, `transfer.*`, `payout.*`, and refund events. Unsupported events are recorded as ignored. Duplicate event IDs return success without reapplying state. Processing failure is recorded with a safe code and a non-2xx response allows Stripe retry.

Webhook order is not trusted. Handlers use provider object state and idempotent transitions. Never log raw payloads, signatures, client secrets, payment methods, bank data, or identity material.
