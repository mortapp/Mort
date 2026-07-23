# Stripe Transfers

A transfer is created only after a funded PaymentIntent and an approved completion path: mutual completion, reviewed completion, approved no-code completion, approved partial completion, or authorized safety-exit payment. The server rechecks account environment, transfer capability, payout status, restrictions, disputes, amount, source charge, and runtime gates.

The database permits only one transfer per payment intent and one provider/idempotency reference per environment. Duplicate requests return the existing operation. Webhooks synchronize created/paid/reversed states. A transfer is not the same as a bank payout, and UI copy must preserve that distinction.
