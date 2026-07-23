# Privacy Disclosures Draft

This is a draft for review by legal/privacy counsel. It is not final policy language.

## Data Categories MORT May Collect

- Account identifiers: Supabase auth user id, email handled by Supabase Auth.
- Profile data: display name, role, DOB, city/state, onboarding status.
- Teen safety data: guardian links, pause status, safety pings.
- Marketplace data: jobs, applications, proof metadata, messages.
- Uploads: proof images, verification images, report attachments.
- Moderation data: reports, blocks, admin action logs, support tickets.
- Notifications: push tokens, notification rows, notification events.
- Payment preference metadata: cash/Cash App/Square preference text only.
- Monetization data: RevenueCat app user id, entitlements, paywall events, ad preferences, ad impressions.

## Data MORT Must Not Collect In This MVP

- Credit card numbers.
- Bank account numbers.
- Job payment custody or escrow data.
- Service-role keys in the app.
- RevenueCat secret keys in the app.
- Exact home addresses in chat.
- Off-platform contact details in chat.

## Ads

AdMob may involve device identifiers and ad-related signals after consent/legal setup. MORT delays ad measurement initialization and blocks ads until consent readiness in app logic.

## Children/Teens

Under-13 users are blocked. Teen users 13-17 require careful privacy, guardian, and labor-law review before launch.

## App Store Review

Prepare disclosures for:

- user-generated content and moderation
- teen safety
- location/city-state marketplace use
- purchases/subscriptions
- ads and tracking/ATT if enabled
- photo/camera uploads
- push notifications

## Monetization Additions To Review

- RevenueCat purchase/customer identifiers linked to Supabase user id as appUserID.
- AdMob ad requests on safe screens only after consent/legal readiness.
- Username history and moderation flags.
- Paywall/ad/feature usage analytics stored in Supabase.
- `app-ads.txt` website hosting requirement.
