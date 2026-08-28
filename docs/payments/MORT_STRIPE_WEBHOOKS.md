# Stripe Webhooks

Endpoint: Supabase `stripe-webhook`, configured with `verify_jwt=false` because Stripe does not send a Supabase JWT. Security comes from exact raw-body verification using the environment-specific `whsec_` secret, a 512 KiB body cap, live/test match, provider event uniqueness, payload SHA-256, and atomic claim/completion RPCs.

Handled families: `payment_intent.*`, `account.updated`, `charge.dispute.*`, `transfer.*`, `payout.*`, and refund events. Unsupported events are recorded as ignored. Duplicate event IDs return success without reapplying state. Processing failure is recorded with a safe code and a non-2xx response allows Stripe retry.

Webhook order is not trusted. Handlers use provider object state and idempotent transitions. Never log raw payloads, signatures, client secrets, payment methods, bank data, or identity material.
