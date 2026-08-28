# MORT Monetization Pricing Plan

MORT monetization is voluntary. Safety, basic applications, Guardian Mode basics, report/block, Safety Ping, proof basics, notifications, payment preferences, and message scanning stay free.

Prices below are suggested setup targets for RevenueCat/App Store Connect. The app must show RevenueCat/App Store product prices at checkout.

## Free

- 3 lifetime username changes
- basic profile and portfolio
- job feed, applications, accepted-job messaging, proof upload, notifications
- basic Guardian Mode, report/block, Safety Ping
- payment preference-only flow
- ads only on safe, low-risk screens

## MORT Plus

- Suggested: `$0.99/month`, `$7.99/year`, `$14.99 lifetime founding one-time`
- Entitlements: `mort_plus`, optionally `mort_ad_free`, `mort_lifetime`
- 1 extra username change per month
- premium profile themes, badge, extra portfolio slots, saved folders, advanced filters, goals, insights, early access

## Ad-Free

- Suggested: `$1.99 one-time`
- Entitlement: `mort_ad_free`
- Removes ads only. It does not unlock every premium perk.

## Username Change Token

- Suggested: `$1.99 one-time`
- Entitlement/product credit: `mort_username_change_token`
- Extra username changes still pass moderation.

## Profile Style Pack

- Suggested: `$0.99 one-time`
- Entitlement: `mort_profile_style_pack`
- Cosmetic-only borders, accents, and patterns.

## Adult Pro

- Suggested: `$2.99/month`
- Entitlement: `mort_adult_pro`
- Applicant sorting, templates, repost/duplicate job, business extras, job analytics, proof review improvements.

## Job Boost

- Suggested: `$1.99 one-time`
- Entitlement/product credit: `mort_job_boost`
- Adults/businesses only. 24-48 hour visibility boost; visible label required; never bypasses moderation.

## Guardian Plus

- Suggested: `$1.99/month`
- Entitlement: `mort_guardian_plus`
- Weekly digest, advanced permission presets, multi-teen overview, richer timeline, emergency contact bundle. Basic Guardian Mode remains free.

## Flutter Rebuild Update

- Flutter paywall routes are mapped under `/monetization/*` and `/settings/subscription`.
- RevenueCat public SDK keys remain placeholders.
- IAP defaults to `IAP_ENABLED=false`.
- Product prices remain suggestions until configured and verified in App Store Connect and RevenueCat.

## RevenueCat SDK Update

- Flutter now uses RevenueCat offering package `priceString` values when available.
- Suggested prices in this document are planning targets only, not hardcoded final app prices.
- The development key `REVENUECAT_FLUTTER_IOS_SDK_KEY (value supplied from protected environment)` is documented for local Dart defines only.

## RevenueCat API Update - 2026-07-09

- Products, entitlements, product-entitlement attachments, offerings, and packages were verified by RevenueCat API.
- Hosted RevenueCat paywall shells were created by API using RevenueCat's offering template shortcut. Finish visual copy/layout review in the Dashboard.
- Runtime prices must still come from RevenueCat/App Store products after dashboard/App Store Connect setup is finished.

## Final Dirt-Cheap Target Matrix

These prices are planning targets only. RevenueCat/App Store returned price strings are the app runtime source of truth.

| Product | Product ID | Target |
| --- | --- | --- |
| MORT Plus Monthly | `mort_plus_monthly` | $0.99/month |
| MORT Plus Yearly | `mort_plus_yearly` | $7.99/year |
| MORT Lifetime | `mort_plus_lifetime` | $14.99 one-time |
| Ad-Free | `mort_ad_free_lifetime` | $1.99 one-time |
| Username Change Token | `mort_username_change_token_1` | $1.99 |
| Profile Style Pack | `mort_profile_style_pack` | $0.99 |
| Adult Pro | `mort_adult_pro_monthly` | $2.99/month |
| Guardian Plus | `mort_guardian_plus_monthly` | $1.99/month |
| Job Boost | `mort_job_boost_1` | $1.99 |

## Runtime Price Rule

The Flutter paywall cards display `StoreProduct.priceString` from RevenueCat package data. Do not hardcode these target prices in runtime paywall UI as final truth.
