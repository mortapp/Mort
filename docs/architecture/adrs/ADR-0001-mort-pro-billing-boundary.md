ID: ADR-0001
Scope: Flutter billing, RevenueCat entitlement cache, Stripe marketplace, AdMob, progression
Time_Frame: MORT monetization/payment convergence
Relevancy: High
Links: flutter_mort/lib/features/monetization/, supabase/functions/revenuecat-webhook/, supabase/migrations/20260723061421_mort_0_9_5_atomic_revenuecat_fulfillment.sql, docs/MORT_PAYMENT_ARCHITECTURE_DECISION.md

# MORT Pro billing and authority boundary

## Context

The Flutter client currently contains a disabled RevenueCat facade, while the backend already has a webhook, idempotent event ledger, product states, and an entitlement cache for legacy products. The new `mort_pro` offer needs native purchases without changing the finished UI or granting paid progression or safety advantages. Version 112 is already in use and must remain intact.

## Decision

- RevenueCat handles digital MORT Pro purchases. `mort_pro` is the canonical new entitlement; `mort_plus` remains a temporary compatible alias for existing owners. The active Play products are `mort_pro:weekly`, `mort_pro:monthly`, `mort_pro:annual`, and the one-time `lifetime` product. The inactive `mort_pro:yearly` base plan must never enter the Offering. Do not delete legacy catalog entries.
- The RevenueCat App User ID is the authenticated Supabase user UUID. The Flutter SDK's `CustomerInfo` is the client's entitlement view. Auth changes clear prior client state before identifying the next user. The RevenueCat authenticated webhook is the sole writer of server product states and cache; server authorization uses that cache and its RLS policies, never a client assertion.
- Test Store keys are for development only. Android and iOS release billing require their matching platform public SDK key, configured store products, and a verified offering. Missing or wrong keys fail closed. Web does not initialize the native paywall path.
- Stripe marketplace/Connect handles real-world jobs, tips, transfers, refunds, and disputes in a separate ledger. Stripe transactions never unlock MORT Pro. RevenueCat purchases never fund jobs. Live Stripe mutations remain disabled until documented provider, legal, minor/representative, tax, operations, and owner gates are proven.
- Ads use the native AdMob widgets and a server placement allowlist. `mort_pro`, legacy `mort_plus`, and `mort_ad_free` suppress ordinary ads. Rewarded MORT Spark grants require a Google signed server callback, a configured ad unit, a unique transaction, and a service role only database function. The old client grant RPC is revoked. The rewarded control stays disabled until the server callback is configured. Purchases, ads, and Stripe payments do not grant XP, Motion Tokens, rank, trust, verification, job priority, or payout priority.

## Consequences

Native RevenueCat dependencies change the Android/iOS binary, requiring version code 113 or later, fresh device/CI certification, and privacy disclosure review. The webhook needs an additive database migration for the four new products and `mort_pro`. The existing release profiles must validate the correct key/profile pairing instead of forbidding the SDK outright. Provider dashboard setup and real store tests remain external gates when matching credentials or store approvals are unavailable.
