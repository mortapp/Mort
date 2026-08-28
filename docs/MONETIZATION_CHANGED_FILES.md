# Monetization Pass Changed Files

The folder `C:\Users\micha\Mort` is not a Git repository, so this file records the exact source/config/docs/backend files changed or added during the monetization and 590-feature pass based on the tracked work in this session.

Generated `dist` files and local `backups` folders were produced during verification but are intentionally excluded from the final zip.

## Config, Environment, Package

- `.env.example`
- `app.config.ts`
- `package.json`
- `pnpm-lock.yaml`

## Voluntary Paywalls Continuation

- `app/monetization/job-boost.tsx`
- `app/monetization/profile-style-pack.tsx`
- `app/monetization/username-change.tsx`
- `app/settings/username.tsx`
- `components/UsernameChange.tsx`
- `components/ads/AdBannerSlot.tsx`
- `components/ads/AdFreeGate.tsx`
- `components/ads/AdSafetyGate.tsx`
- `components/ads/RewardedAdButton.tsx`
- `components/ads/TestAdModeBadge.tsx`
- `components/monetization/AdFreeBadge.tsx`
- `components/monetization/BoostPaywall.tsx`
- `components/monetization/EntitlementBadge.tsx`
- `components/monetization/FeatureLockCard.tsx`
- `components/monetization/GuardianPurchaseNotice.tsx`
- `components/monetization/ManageSubscriptionButton.tsx`
- `components/monetization/MonetizationDisclaimer.tsx`
- `components/monetization/PaywallCard.tsx`
- `components/monetization/PerkRow.tsx`
- `components/monetization/PlanCard.tsx`
- `components/monetization/PremiumBadge.tsx`
- `components/monetization/RestorePurchasesButton.tsx`
- `components/monetization/TeenMonetizationSafetyNotice.tsx`
- `components/monetization/UsernameChangePaywall.tsx`
- `hooks/useAds.ts`
- `hooks/useEntitlements.ts`
- `hooks/useFeatureAccess.ts`
- `hooks/useRevenueCat.ts`
- `lib/featureAccess.ts`

## Public Web Assets

- `public/app-ads.txt`

## App Routes

- `app/_layout.tsx`
- `app/admin/index.tsx`
- `app/adult/dashboard.tsx`
- `app/adult/profile.tsx`
- `app/guardian/profile.tsx`
- `app/guardian/teens.tsx`
- `app/monetization/ad-free.tsx`
- `app/monetization/index.tsx`
- `app/monetization/manage.tsx`
- `app/monetization/paywall.tsx`
- `app/monetization/restore.tsx`
- `app/monetization/revenuecat-debug.tsx`
- `app/notifications.tsx`
- `app/settings/_layout.tsx`
- `app/settings/ad-preferences.tsx`
- `app/settings/subscription.tsx`
- `app/teen/feed.tsx`
- `app/teen/profile.tsx`

## Components And Providers

- `components/DesignSystem.tsx`
- `components/Monetization.tsx`
- `providers/AuthProvider.tsx`
- `providers/MonetizationProvider.tsx`

## Libraries And Types

- `lib/ads.ts`
- `lib/data.ts`
- `lib/env.ts`
- `lib/mobileAdsBridge.native.tsx`
- `lib/mobileAdsBridge.tsx`
- `lib/revenuecat.ts`
- `types/supabase.generated.ts`

## Supabase

- `supabase/migrations/20260708151850_add_monetization_tables.sql`
- `supabase/migrations/20260708152332_add_monetization_service_role_grants.sql`
- `supabase/migrations/20260708163330_add_voluntary_paywall_perks.sql`
- `supabase/migrations/20260708210558_fix_username_change_rpc_ambiguity.sql`

## QA Scripts

- `scripts/create-local-test-users.mjs`
- `scripts/create-old-project-test-users.mjs`
- `scripts/qa-old-project-rls.mjs`
- `scripts/qa-old-project-smoke.mjs`
- `scripts/qa-rls.mjs`

## Docs

- `README.md`
- `docs/120_IMPROVEMENTS_REPORT.md`
- `docs/ADMOB_SETUP.md`
- `docs/ADS_AND_IAP_SAFETY.md`
- `docs/APP_STORE_MONETIZATION_CHECKLIST.md`
- `docs/COMPETITIVE_PRODUCT_NOTES.md`
- `docs/EXTERNAL_SETUP.md`
- `docs/FRONTEND_REMAINING_LIMITATIONS.md`
- `docs/IPHONE_TEST_PLAN.md`
- `docs/LOCAL_TEST_USERS.md`
- `docs/MONETIZATION_BACKEND_REPORT.md`
- `docs/MONETIZATION_CHANGED_FILES.md`
- `docs/MONETIZATION_IMPLEMENTATION_RESULTS.md`
- `docs/MONETIZATION_PLAN.md`
- `docs/MORT_590_FEATURE_REGISTRY.md`
- `docs/PRIVACY_DISCLOSURES_DRAFT.md`
- `docs/QA_SMOKE_TESTS.md`
- `docs/REVENUECAT_SETUP.md`
- `docs/DESIGN_SYSTEM.md`
- `docs/FRONTEND_COMPLETION_REPORT.md`
- `docs/FRONTEND_FEATURE_AUDIT.md`
- `docs/LEGAL_AND_TEEN_SAFETY_NOTES.md`
- `docs/MONETIZATION_PRICING_PLAN.md`
- `docs/PAYWALL_ETHICS.md`
- `docs/SCREEN_MAP.md`
- `docs/USER_FLOWS.md`
- `docs/VOLUNTARY_PAYWALLS_IMPLEMENTATION_RESULTS.md`
