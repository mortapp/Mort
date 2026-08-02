# MORT Payment Architecture Decision

Decision date: 2026-07-30

MORT retains Stripe Connect separate charges and transfers as its technical
evaluation architecture for physical-service marketplace payments. Stripe has
not approved the use case and MORT has not selected or activated a production
payment provider. The distributed Flutter client contains no Stripe SDK,
RevenueCat SDK, Google Play Billing capability, or Android billing permission.

MORT is not an escrow provider and does not claim escrow. The modeled strategy
collects an adult-funded charge before a job starts and permits a separate
post-completion transfer only after server eligibility and human financial
review. Signed provider webhooks, not client callbacks, are payment truth. The
platform would bear provider fees, refunds, chargebacks, and negative-balance
risk under this model; those obligations remain unapproved external gates.

The hosted environment is sandbox mode with payment, onboarding, funding,
transfers, refunds, live mode, service fees, and production approval disabled.
MORT currently charges a server-enforced zero platform fee. No provider object
or money movement was created during Phase 12. Production requires provider
use-case approval, compliant minor/representative onboarding, legal/privacy/tax
review, retention and receipts decisions, reconciliation and on-call staffing,
physical-device QA, and an audited forward activation migration.

References reviewed on 2026-07-30:

- https://docs.stripe.com/connect/separate-charges-and-transfers
- https://docs.stripe.com/connect/charges
- https://support.google.com/googleplay/android-developer/answer/9858738
- https://support.google.com/googleplay/android-developer/answer/10281818
