# RevenueCat Paywall Review Checklist

Date: 2026-07-10

Use this before TestFlight and App Store review.

## Required Ethics

- Safety tools stay free.
- Basic job applying stays free.
- Basic Guardian Mode stays free.
- Report, block, and Safety Ping stay free.
- No fake urgency.
- No fake discounts.
- No fake purchase success.
- No fake ad success.
- No "pay to be safe" copy.
- No "pay to get hired" promise.

## RevenueCat Configuration

- Products exist for monthly, yearly, lifetime, ad-free, username token, profile style, adult pro, guardian plus, and job boost.
- Entitlements are attached to the correct products.
- Offerings/packages exist for default, teen perks, adult pro, guardian plus, ad-free, username change, and job boost.
- Hosted paywalls use optional language.
- Webhook grants backend credits/entitlements only after trusted RevenueCat events.

## Flutter UI

- Package prices use `storeProduct.priceString`.
- Empty offerings show a setup/empty state, not fake prices.
- Native paywall launch is disabled on web.
- Restore purchases is visible.
- Manage subscription is visible.
- Purchase cancellation leaves free app access intact.
- Active entitlements are read from RevenueCat/backend confirmation.

## App Store Review Notes

- MORT is a teen-safe marketplace with optional perks only.
- Purchases do not unlock safety.
- Purchases do not unlock basic job applying.
- Boosts do not bypass moderation.
- Username tokens do not affect account access.
- Guardian Plus does not replace basic Guardian Mode.

## TestFlight Checks Still Needed

- Real iPhone purchase flow.
- Sandbox monthly/yearly/lifetime purchases.
- Restore purchases.
- Manage subscription.
- Cancellation/expired subscription handling.
- Webhook entitlement sync.
- Username token grant and consumption.
- Job boost credit grant and consumption.
