# Paywall Ethics

MORT should feel closer to optional Discord Nitro-style perks than pressure-based subscription prompts.

## Rules

- Free users can still use MORT.
- Basic job applications, safety features, Guardian Mode, reports, blocks, Safety Ping, proof basics, and message scanning are never paywalled.
- No fake discounts, fake urgency, manipulative countdowns, or shame copy.
- No fake purchase success or fake ad success.
- Purchases use RevenueCat/App Store prices as source of truth.
- Teens see guardian purchase reminders.
- Adults/businesses can be monetized more than teens.
- Ads never appear on sensitive screens.

## Approved Copy

- Header: "Make MORT yours."
- Subheader: "Free stays useful. Plus just gives you extra style, control, and convenience."
- CTA: "Upgrade if you want"
- Secondary: "Keep using free"

## Forbidden Copy

- "You must upgrade"
- "Unlock safety"
- "Only premium users are protected"
- "Pay to get hired"
- "Pay or lose access"
- Any fake urgency or fake discount language

## Flutter Rebuild Update

- Flutter paywalls use optional language: "Upgrade if you want" and "Keep using free".
- Purchase buttons call RevenueCat only when `IAP_ENABLED=true`, a public SDK key is configured, and offerings are available.
- Safety, reports, blocking, Safety Ping, basic applying, and Guardian Mode basics stay free.
- MORT does not fake active purchases, fake prices, or fake entitlements.

## RevenueCat Dashboard Status - 2026-07-09

- Products, entitlements, product-entitlement attachments, offerings, packages, and webhook integration were verified by API.
- Hosted paywall shells were created by API; final copy/layout review still needs RevenueCat Dashboard work.
- Generated paywall prompts keep the same ethical rules: no fake urgency, no fake discounts, no pressure copy, and no "pay to be safe" framing.

## Final Release Rules

- Optional perks only.
- No forced upgrades.
- No fake urgency.
- No fake discounts.
- No "pay to be safe" language.
- No paywall for job applying.
- No paywall for basic Guardian Mode.
- No paywall for report, block, Safety Ping, messaging safety scanner, proof upload basics, or notification basics.
- Target prices are intentionally dirt-cheap, but the app must show RevenueCat/App Store returned prices when available.
- Purchase cancellation must leave all free functionality intact.

## Video-Inspired Ethics Update - 2026-07-10

- Smart defaults are allowed when they reduce confusion, not when they hide costs.
- Progress framing is allowed for onboarding completion, not for purchase pressure.
- Reciprocity is allowed as real free value, not as a bait-and-switch.
- Ownership/investment is allowed for profile setup, saved jobs, and preferences, not for trapping users.
- Loss-aversion framing is allowed only for safety education, never for monetization threats.
- Price anchoring is allowed only as honest value context using RevenueCat/App Store price strings.
