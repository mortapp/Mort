# Paywall Video-Inspired Upgrades

Date: 2026-07-10

## Principles Applied

- Give useful free value before asking for payment.
- Show what stays free before paid perks.
- Present price strings from RevenueCat/App Store/Test Store, not hardcoded copy.
- Disable native purchase CTAs on web/unsupported platforms.
- Avoid fake urgency, fake discounts, shame, or safety pressure.

## Default / MORT Plus

Header remains:

```text
Make MORT yours.
```

Subheader remains:

```text
Free stays useful. Plus just gives you extra style, control, and convenience.
```

Perks framed as optional:

- Premium profile themes
- Extra portfolio room
- Saved folders
- Advanced filters
- Profile insights
- Goal analytics
- Premium badge
- Early access perks

## Ad-Free

- Hides eligible ads on safe browsing screens.
- Does not hide safety education.
- Does not affect reports, blocks, Safety Ping, proof, messages, or moderation.

## Username Token

- Three username changes remain free first.
- Token is optional after free changes are used.
- Backend credits must exist before a username token can be consumed.

## Job Boost

- Adult/business-only visibility credit.
- Never bypasses verification, moderation, or safety review.
- Backend boost credits must be granted before use.

## Web Handling

- RevenueCat native purchase launch is disabled on web and unsupported platforms.
- The web preview can show paywall copy and status, but cannot validate native purchases.
- Restore/manage remains present, but native App Store management still needs real-device testing.

## Implemented

- Paywall status card now disables the native RevenueCat paywall button when unavailable.
- RevenueCat status now reports web/unsupported before generic IAP-disabled messaging.
- Package cards remind users that free MORT stays usable.
- Package cards remind users that entitlements unlock only after RevenueCat/backend confirmation.
- Offering copy says prices come from RevenueCat/App Store/Test Store package data.
