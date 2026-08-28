# Funded Job Release Model

MORT does not claim escrow. A funded provider state is a server-reconciled status bound to the accepted contract obligation.

Start PIN generation requires confirmed funding state. Completion creates a permanent execution event, but payout release still requires provider-confirmed capture, eligible connected account, no active dispute/refund block, and server-owned idempotency. Provider webhooks reconcile state. Flutter never marks a job paid or chooses a destination.

The model is implemented in sandbox architecture only. Money-moving switches are off.
