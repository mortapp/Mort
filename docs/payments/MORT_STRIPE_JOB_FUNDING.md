# Stripe Job Funding

Funding is available only to the adult party on an accepted, current contract version with a valid payment obligation. The server calculates `earnings_amount_cents`, configured service fee, `total_amount_cents`, currency, and deterministic transfer group. It locks environment and operation version and rejects amount forgery or duplicate idempotency keys.

States distinguish unfunded, payment-method required, action required, processing, funded, transfer pending/transferred, refund states, disputed/chargeback, failed, canceled, and closed. The job UI must not equate contract acceptance, PaymentSheet return, transfer creation, or payout creation with final receipt by the worker.
