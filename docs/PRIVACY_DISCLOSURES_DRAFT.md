# Privacy Disclosures Draft

This is a draft for review by legal/privacy counsel. It is not final policy language.

## Data Categories MORT May Collect

- Account identifiers: Supabase auth user id, email handled by Supabase Auth.
- Profile data: display name, role, DOB, city/state, onboarding status.
- Location data: approximate/manual area for matching and optional temporary
  foreground precise location during an authorized active-job safety flow. No
  background location collection is intended.
- Teen safety data: guardian links, pause status, safety pings.
- Marketplace data: jobs, applications, proof metadata, messages.
- Uploads: proof images and report attachments. Real identity-document uploads
  are disabled and provider-hosted capture would require separate approval.
- Moderation data: reports, blocks, admin action logs, support tickets.
- Notifications: push tokens, notification rows, notification events.
- Diagnostics and analytics: local/redacted diagnostics and disabled
  provider-neutral crash/product analytics architecture. Provider activation
  requires new consent, retention, SDK, and store-disclosure review.
- Payment agreement/status metadata: offered amount, immutable obligation,
  completion/dispute state, and disabled provider-state architecture. MORT does
  not accept payment handles in this release.
- Monetization data is not collected by the distributed build because native
  billing and advertising SDKs are not compiled in. Server-side historical
  entitlement architecture remains disabled and separately retained.

## Data MORT Must Not Collect In This MVP

- Credit card numbers.
- Bank account numbers.
- Job payment custody or escrow data.
- Cash App tags, Square links, card numbers, bank credentials, or payout
  destinations in MORT profiles, chat, proof, or support.
- Service-role keys in the app.
- RevenueCat secret keys in the app.
- Exact home addresses in chat.
- Off-platform contact details in chat.

## Ads

AdMob may involve device identifiers and ad-related signals after consent/legal setup. MORT delays ad measurement initialization and blocks ads until consent readiness in app logic.

## Children/Teens

Under-13 users are blocked. Teen users 13-17 require careful privacy, guardian, and labor-law review before launch.

Guardian Mode is optional and bounded. It does not provide universal legal
consent, continuous monitoring, access to all messages/evidence, or guaranteed
emergency response.

## Support And AI

The current Support assistant is deterministic and can hand off to restricted
human queues. External generative AI remains disabled. Any third-party AI
activation requires a new limited-use, disclosure, consent, retention,
processor, safety, and Google Play Data Safety review.

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
