# Payment System Boundary

| System | Permitted purpose | Not permitted |
| --- | --- | --- |
| Google Play Billing | Optional Android digital perks and consumable digital credits | Job funding, wages, payouts, refunds for physical work |
| RevenueCat | Cross-platform optional entitlement coordination where configured | Marketplace money movement or worker payouts |
| Stripe Connect | Adult-funded local job obligations, connected-account transfers, refunds, disputes, payouts | Android digital subscriptions or profile perks |
| Payment preference | Record an agreed external payment preference | Processing, escrow, custody, or proof of payment |

MORT does not call job funding escrow. A Stripe PaymentIntent is a provider payment flow, and availability/reversal risks remain. Payment status is server-owned; mobile callbacks are never final financial truth.
