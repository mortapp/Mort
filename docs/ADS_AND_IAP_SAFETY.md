# Ads And IAP Safety

MORT includes teens, so monetization must be safer than a generic marketplace.

Current implementation:

- RevenueCat SDK integrated with web/native guards.
- AdMob app ID and iOS banner/rewarded IDs configured.
- Ads disabled by default with `EXPO_PUBLIC_ADS_ENABLED=false`.
- Test ads enabled by default with `EXPO_PUBLIC_USE_TEST_ADS=true`.
- Interstitial/native IDs are intentionally blank.
- Purchase/ad success is never faked.

## Hard Rules

- Under 13 remains blocked.
- Teens 13-17 can use MORT without paying.
- Safety features are never paywalled.
- No dark patterns.
- No manipulative countdowns.
- No pay-to-be-safe copy.
- No rewarded ads to unlock safety.
- No ads on safety-critical screens.
- No real payment processing, escrow, or card storage.

## Teen Ad Defaults

The app defaults teen/unknown ad handling to:

- conservative ad request configuration
- non-personalized ads
- age-restricted treatment where supported
- no rewarded ads for teens pending legal review
- no ads before consent readiness

## Guardian Guidance

Teen purchase screens include guidance to involve a guardian. Guardian Mode remains free.

## Purchase Honesty

The app only shows real RevenueCat packages if offerings are returned. Missing keys/products/offering produce setup-required states.

Purchases and restore flows report cancel/error states separately. They do not claim success unless RevenueCat returns updated customer info.

## Required Reviews

Before real users:

- legal review
- teen labor review
- privacy review
- App Store IAP review
- App Store ads/privacy disclosure review
- support and refund workflow review
- abuse and moderation workflow review

## Flutter Rebuild Update

- `google_mobile_ads` and `purchases_flutter` are installed.
- Ads default to off with `ADS_ENABLED=false`.
- IAP defaults to off with `IAP_ENABLED=false`.
- Ad widgets are guarded away from sensitive screens and web.
- RevenueCat does not fake purchase success.
