# MORT Dispute and Evidence System

Status: private evidence, participant disputes, staff queues, and role-separated resolution are implemented for closed testing.

- Participants can open job/payment/support-linked cases and submit factual statements.
- Evidence objects are private, owner-prefixed, MIME/size constrained, hashed, and registered through caller-authorized functions.
- Signed evidence previews are short-lived, assignment-authorized, and rate-limited.
- Unrelated users and ordinary admins cannot read evidence or payment operation queues.
- Evidence manifests and access events preserve auditability without exposing provider or financial identifiers.
- AI may summarize approved material but cannot decide outcomes.
- A payment reviewer records a substantive recommendation. A different payment operator must explicitly confirm execution.
- Provider disputes and unsafe state block financial execution.
- Resolution operations are single-claim and provider-idempotent.

Real provider evidence submission, chargeback handling, money movement, and staffed appeals have not been exercised against a live Stripe account.
