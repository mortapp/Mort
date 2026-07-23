# MORT Payment Architecture Decision

Decision date: 2026-07-22

MORT uses Stripe for real-world job payment architecture and Google Play Billing for optional Android digital goods. RevenueCat and AdMob are not active in the Flutter closed-test release.

MORT is not an escrow provider and does not claim escrow. Job funding, capture, transfer, refund, and dispute state are provider-reconciled server records. Client callbacks are never payment truth.

The current environment is closed-test sandbox with payment, onboarding, funding, transfers, refunds, live mode, and owner live approval all disabled. This permits authorization and state-machine QA without creating charges. Enabling any provider operation requires owner-controlled server configuration, Stripe account/capability approval, legal and tax review, webhook verification, monitoring, and explicit release approval.
