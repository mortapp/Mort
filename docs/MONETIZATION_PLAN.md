# Monetization Plan

MORT monetization must be clear, teen-safe, and non-deceptive.

Stage update: voluntary paywalls are designed around cheap optional perks, not forced access. The app includes RevenueCat SDK integration, guarded paywall screens, username-token UI, profile style pack UI, job boost UI, and AdMob safe-screen guards. RevenueCat products/offerings still need dashboard/App Store setup before real purchases can be tested.

## RevenueCat Dashboard/API Update - 2026-07-09

- RevenueCat project/app resolved by API using the public/test Flutter SDK key match.
- RevenueCat entitlements were created by API.
- The Supabase `revenuecat-webhook` function was deployed and the RevenueCat webhook integration was created by API.
- Product, offering, package, and full paywall setup is blocked until the v2 API key has Product Configuration read/write permissions, starting with `project_configuration:products:read`.
- No real purchase, iPhone, TestFlight, or App Store review testing has been completed.

## Free Forever

These stay free:

- sign up/sign in
- basic job feed
- basic applications
- Guardian Mode basics
- report/block
- Safety Ping
- safe messaging scanner
- payment preference disclaimer
- basic proof upload
- basic notifications
- admin moderation

## Premium And Ad-Free

Premium can include:

- ad-free experience
- advanced job filters
- saved job collections
- advanced profile analytics
- portfolio extras
- profile themes
- goal analytics
- early access features
- Adult Pro job templates
- Adult Pro applicant sorting
- Business Pro analytics
- Guardian Plus weekly report
- Guardian Plus activity digest

Premium must not:

- paywall safety
- paywall basic applications
- make teen earnings dependent on purchases
- imply users are safer only if they pay
- use manipulative countdowns

## Ads

Ads are allowed only in low-risk placements:

- teen job feed between cards
- adult dashboard lower area
- non-sensitive settings bottom
- Hustle Academy lesson end
- general profile browse
- job search results
- saved jobs page

Ads are blocked on safety, reports, chat, proof, verification, guardian approval, admin, payment, paywall, onboarding, auth, and account-restriction screens.

## Boosted Jobs

The backend now supports `boosted_jobs` and `boost_impressions`, but boost purchase flow is not enabled. Boosts need:

- App Store review
- RevenueCat product setup
- legal review
- admin moderation
- non-deceptive ranking disclosure

## Source Of Truth

RevenueCat is the source of truth for purchases. Supabase stores optional cache/audit data only.

MORT does not process payments for jobs.

See also `docs/MONETIZATION_PRICING_PLAN.md` and `docs/PAYWALL_ETHICS.md`.
# Flutter RevenueCat Integration Update

- Flutter now installs `purchases_flutter` and `purchases_ui_flutter`.
- RevenueCat service uses real SDK calls for initialize, identify, logout, CustomerInfo, offerings, package purchase, restore, entitlement checks, paywall presentation, and Customer Center presentation.
- Purchases are enabled only when `IAP_ENABLED=true` and a platform public SDK key is supplied by Dart define.
- RevenueCat package prices come from offerings when configured.
- No premium UI is unlocked unless CustomerInfo reports an active entitlement.
- Real iPhone/TestFlight purchase testing is still not done.
