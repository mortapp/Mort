# Stripe Incident Response

1. Triage provider outage, credential exposure, forged/replayed webhook, unauthorized financial access, amount mismatch, duplicate transfer, refund/dispute spike, or data exposure.
2. Disable the narrow runtime gates first; for uncertain integrity, disable all Stripe payment/onboarding/transfer/refund operations while keeping MORT safety and account access available.
3. Revoke/rotate affected server secrets, redeploy, and confirm old credentials fail. Never paste values into tickets or chat.
4. Preserve audit/reconciliation evidence and provider IDs without raw payment or identity data.
5. Reconcile every in-flight object and place holds where outcome is uncertain. Do not retry transfers blindly.
6. Notify Stripe, internal owners, users, regulators, or law enforcement according to reviewed policy and deadlines.
7. Restore in sandbox first, then staged live gates after two-person approval. Publish a post-incident record with root cause, impact, recovery, and prevention.
