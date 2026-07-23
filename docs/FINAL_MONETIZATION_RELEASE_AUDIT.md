# Final Monetization Release Audit

Generated for the final monetization and release-prep pass.

## Current Truth

- Flutter app exists at `flutter_mort`.
- Flutter reads Supabase from Dart defines: `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
- Production runtime does not depend on Docker or this PC; it uses hosted Supabase, RevenueCat, Apple, and AdMob services.
- RevenueCat Flutter SDK packages are installed: `purchases_flutter` and `purchases_ui_flutter`.
- RevenueCat service, providers, fallback paywall screens, restore, manage subscription, CustomerInfo, and entitlement checks are wired.
- Custom Flutter paywall fallback loads RevenueCat offerings and route-specific packages; it displays RevenueCat/App Store/Test Store price strings when available.
- AdMob IDs exist in config, iOS Info.plist, and docs.
- `app-ads.txt` exists with `google.com, pub-9412242686563958, DIRECT, f08c47fec0942fa0`.
- `revenuecat-webhook` is deployed to Supabase and webhook QA has passed.
- Monetization, RevenueCat, rate-limit, and AI safety tables exist in the rebuilt old Supabase project.
- Clean zip rules exclude env files, build outputs, logs, node_modules, caches, old zips, backups, and secrets.

## Done By Codex

- RevenueCat products verified for all requested MORT product identifiers.
- RevenueCat entitlements verified and product attachments checked.
- RevenueCat offerings and packages verified.
- Supabase RevenueCat webhook deployed and verified with signed test events.
- Backend RLS, smoke, monetization, username credit, job boost credit, and rate-limit QA passed.
- Flutter analyze/test/build web passed.
- Secret scan passed.
- App Store Connect, RevenueCat paywall builder, AdMob hosting, TestFlight, sandbox purchase, and legal review docs are in place.

## Still Missing

- RevenueCat hosted paywall shells were created by API. Dashboard visual copy/layout review and publish confirmation are still manual.
- App Store Connect IAP products still need to be created/approved and linked to the real iOS app.
- Real iPhone/TestFlight purchase, restore, webhook, and ad tests are not done.
- App Store privacy, legal, COPPA/teen-safety, ad-safety, and monetization review are not done.

## Manual Account Work

- RevenueCat Dashboard: review/publish hosted paywalls for each offering using `docs/REVENUECAT_PAYWALL_BUILDER_PROMPTS.md`.
- App Store Connect: create product IDs and subscription group, attach screenshots/metadata, submit for review.
- AdMob: confirm app review, test devices, and host `app-ads.txt` at the developer website root.

## Warnings

- Do not enable real purchases or ads for real users before iPhone sandbox/TestFlight testing passes.
- Do not rely on target prices in docs as runtime truth; the app should show store-returned price strings.
- Do not call this production-ready until external reviews and real-device tests are complete.
