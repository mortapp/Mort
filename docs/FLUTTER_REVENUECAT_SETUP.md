# Flutter RevenueCat Setup

## SDK Install

Installed in `flutter_mort/`:

```powershell
flutter pub add purchases_flutter purchases_ui_flutter
```

Installed packages:

- `purchases_flutter`
- `purchases_ui_flutter`

## Development API Key

RevenueCat development public SDK key from the setup screen:

```text
REVENUECAT_FLUTTER_IOS_SDK_KEY (value supplied from protected environment)
```

This key is documented for local development. It is not hardcoded in Dart source and is not placed in `.env.example` as a real value.

Run with Dart defines:

```powershell
flutter run `
  --dart-define=SUPABASE_URL=... `
  --dart-define=SUPABASE_ANON_KEY=... `
  --dart-define=REVENUECAT_FLUTTER_IOS_SDK_KEY=REVENUECAT_FLUTTER_IOS_SDK_KEY (value supplied from protected environment) `
  --dart-define=IAP_ENABLED=true
```

Production/staging public SDK keys must be configured later through build settings or CI.

## Files

- `flutter_mort/lib/features/monetization/data/revenuecat_service.dart`
- `flutter_mort/lib/features/monetization/providers/revenuecat_providers.dart`
- `flutter_mort/lib/features/monetization/domain/feature_access.dart`
- `flutter_mort/lib/features/monetization/screens/*`
- `flutter_mort/lib/features/monetization/widgets/*`
- Paywall routes under `/monetization/*`
- Settings subscription route under `/settings/subscription`

## Environment

Use Dart defines or CI build variables:

- `REVENUECAT_FLUTTER_IOS_SDK_KEY`
- `REVENUECAT_FLUTTER_ANDROID_SDK_KEY`
- `REVENUECAT_IOS_API_KEY` (legacy fallback)
- `REVENUECAT_ANDROID_API_KEY` (legacy fallback)
- `IAP_ENABLED`
- `REVENUECAT_ENTITLEMENT_PLUS`
- `REVENUECAT_ENTITLEMENT_AD_FREE`
- `REVENUECAT_ENTITLEMENT_ADULT_PRO`
- `REVENUECAT_ENTITLEMENT_GUARDIAN_PLUS`
- `REVENUECAT_ENTITLEMENT_USERNAME_TOKEN`
- `REVENUECAT_ENTITLEMENT_JOB_BOOST`

Do not put RevenueCat private webhook secrets in Flutter.

## Entitlements

- `mort_plus`
- `mort_ad_free`
- `mort_adult_pro`
- `mort_guardian_plus`
- `mort_username_change_token`
- `mort_job_boost`
- `mort_profile_style_pack`

## Product IDs To Configure

- `mort_plus_monthly`
- `mort_plus_yearly`
- `mort_plus_lifetime`
- `mort_ad_free_lifetime`
- `mort_username_change_token_1`
- `mort_profile_style_pack`
- `mort_adult_pro_monthly`
- `mort_guardian_plus_monthly`
- `mort_job_boost_1`

## Current Flutter Behavior

- Initializes RevenueCat only when `IAP_ENABLED=true`.
- Does not crash on web or missing key.
- Uses Supabase user id as RevenueCat `appUserID`.
- Loads CustomerInfo as entitlement source of truth.
- Loads RevenueCat offerings and package price strings.
- Purchases packages through `Purchases.purchasePackage`.
- Handles cancelled purchases separately.
- Restores purchases through `Purchases.restorePurchases`.
- Shows Customer Center through `RevenueCatUI.presentCustomerCenter` where supported.
- Does not fake purchase success.
- Does not fake active entitlements.

## Required External Setup

- Create products in App Store Connect.
- Create matching products, entitlements, and offerings in RevenueCat.
- Configure sandbox testers.
- Configure webhook handling server-side if purchase events should update Supabase entitlement cache.
- Validate purchase, cancel, restore, and Customer Center on a real iPhone/TestFlight build.

Current status: iPhone purchase testing is not done, TestFlight is not done, and App Store/legal/privacy review is not done.
# 2026-07-09 Dashboard/API Update

- Preferred iOS Dart define: `REVENUECAT_FLUTTER_IOS_SDK_KEY`.
- Legacy fallback still supported: `REVENUECAT_IOS_API_KEY`.
- RevenueCat entitlements and webhook integration were created by API.
- Product, offering, package, and full paywall setup is blocked until the RevenueCat v2 secret key has Product Configuration permissions, starting with `project_configuration:products:read`.
- Real iPhone/TestFlight purchase testing is still not done.
