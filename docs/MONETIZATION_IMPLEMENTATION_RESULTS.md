# MORT Monetization + 590-Feature Pass Results

Date: 2026-07-08

Project path: `C:\Users\micha\Mort`

Supabase project ref: `rakjydmgwwgtdislanbt`

Supabase URL: `https://rakjydmgwwgtdislanbt.supabase.co`

This pass was additive. It did not restart or rebuild the app from scratch, did not place service-role secrets in Expo/mobile source, and did not put `SUPABASE_SERVICE_ROLE_KEY` in `.env.local`.

## Implemented

- Added RevenueCat dependencies and guarded client integration.
- Added AdMob dependency, iOS app ID, iOS banner/rewarded unit IDs, `react-native-google-mobile-ads` config plugin, delayed app-measurement initialization, and `public/app-ads.txt`.
- Added a public Google Android test app ID fallback so accidental Android native builds do not crash before real Android ad IDs exist.
- Added a monetization provider linked to the Supabase Auth user id.
- Added monetization screens for hub, paywall, ad-free, restore, manage, and RevenueCat debug.
- Added settings screens for subscription and ad preferences.
- Added guarded ad components, plan cards, restore/manage controls, teen/guardian safety notices, and design-system components.
- Added role-screen entry points for teen, adult, guardian, and admin navigation.
- Added a 600-item feature registry in `docs/MORT_590_FEATURE_REGISTRY.md`.
- Added a 197-item improvements report in `docs/120_IMPROVEMENTS_REPORT.md`.
- Added monetization docs for AdMob, RevenueCat, safety, privacy disclosures, App Store review, and competitive product notes.

## Backend Applied

Remote backup folder:

`backups\supabase-rakjydmgwwgtdislanbt-monetization-20260708-112117`

Applied additive migrations:

- `supabase/migrations/20260708151850_add_monetization_tables.sql`
- `supabase/migrations/20260708152332_add_monetization_service_role_grants.sql`

Remote backend now includes 36 public tables, 36 RLS-enabled public tables, 34 public functions, and 31 triggers according to the old-project smoke test.

New monetization backend objects include entitlement cache, RevenueCat event intake storage, subscription status, ad preferences, ad impression/click/frequency state, purchase audit logs, premium feature usage, boosted jobs, boost impressions, monetization experiments, paywall events, and RPCs for user/admin monetization checks.

## Verification Results

- `pnpm install`: passed; already up to date.
- `pnpm check`: passed.
- `pnpm lint`: passed.
- `pnpm build`: passed; exported 44 static web routes.
- `npx expo export --platform web`: passed; exported 44 static web routes.
- `npx expo-doctor`: passed 20/20 checks.
- `.\scripts\secret-scan.ps1`: passed.
- `.\scripts\windows-check.ps1`: passed.
- `node scripts/create-old-project-test-users.mjs`: passed after setting the required old-project safety markers.
- `pnpm run qa:old-project-smoke`: passed.
- `pnpm run qa:old-project-rls`: passed.
- `npx expo start --port 8099 --localhost`: Metro reached `packager-status:running`, then was stopped; port `8099` closed afterward.

## Bugs Found And Fixed

- Expo web export initially failed because `react-native-google-mobile-ads` was imported too eagerly on web. Fixed with native/web mobile ads bridge files.
- Initial remote smoke testing failed because trusted server QA needed explicit service-role grants for the new monetization tables and RPCs. Fixed with a second additive grant migration.
- The old-project smoke test initially flagged `ad_impressions` as an old incompatible table, but it is now an intentional monetization table. Fixed the smoke test expectation.
- Expo Router warned that `settings` had no nested layout. Fixed by adding `app/settings/_layout.tsx`.
- Google Mobile Ads warned that Android had no app ID. Fixed by adding a public Google Android test app ID fallback while keeping iOS as the monetized priority.
- The first QA user command hit the local-only script guard; reran with the old-project QA script and explicit old-project safety markers.
- The Metro start wrapper timed out before cleanup output because it waited too long around a background process. Metro was then verified through `/status` and stopped manually.
- Old-project and local QA scripts contained hardcoded fallback QA passwords. Removed the defaults, require env-supplied temporary QA passwords, and rotated the old-project QA users to a generated process-only password that was not printed or stored.

## Not Done

- iPhone real-device manual testing is not done.
- EAS Build and TestFlight submission are not done.
- Real RevenueCat products/entitlements are not configured in RevenueCat or App Store Connect.
- Real AdMob app approval and live ad validation are not done.
- ATT, App Store privacy labels, legal review, teen-safety review, moderation staffing, and incident-response review are not done.
- A real consent/preference system for live personalized/non-personalized ads is not done; ad components remain conservative and disabled by default.

## Warnings Before Real Users

- Do not enable live ads or IAP for teens until App Store, COPPA/state teen-safety, guardian-consent, privacy, and ad-policy review are complete.
- Do not treat entitlement state as final until RevenueCat webhooks are implemented server-side and replay/idempotency behavior is tested.
- Do not use real payments for job completion, escrow, or marketplace settlement; MORT still only stores payment preferences.
- Do not invite real users until iPhone device testing, EAS preview/internal builds, notification testing, upload testing, and moderation workflow testing are complete.
