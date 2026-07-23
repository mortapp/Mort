# Stripe Refunds

Refunds are server-only financial operations. The requester must be an authorized participant or financial operator, the amount must be positive and cannot exceed refundable provider truth, and the environment/payment identifiers must match. Every request uses an idempotency key and reason code.

Do not refund through client-side API calls or mutate a job payment row to simulate a refund. Partial refunds preserve remaining balances and transfer implications. Completed transfers may require reversal or platform-funded recovery, so the operation must evaluate provider state first. Webhooks and reconciliation determine final status; support-facing errors use safe codes.
