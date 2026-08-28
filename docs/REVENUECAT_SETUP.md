# RevenueCat Setup

MORT uses RevenueCat for app premium features only. It does not use RevenueCat for job payments, escrow, payouts, split payments, or guarantees.

Official docs used:

- Expo install and development build: https://www.revenuecat.com/docs/getting-started/installation/expo
- Expo IAP guide: https://docs.expo.dev/guides/in-app-purchases/
- Making purchases: https://www.revenuecat.com/docs/getting-started/making-purchases

## Public SDK Keys

Set only public SDK keys in Expo environment variables:

```text
EXPO_PUBLIC_REVENUECAT_IOS_API_KEY=
EXPO_PUBLIC_REVENUECAT_ANDROID_API_KEY=
```

Do not put RevenueCat secret keys, App Store private keys, Supabase service-role keys, or webhook secrets in Expo/mobile code.

## Entitlements

Create these RevenueCat entitlements:

- `mort_plus`
- `mort_ad_free`
- `mort_adult_pro`
- `mort_guardian_plus`
- `mort_lifetime`
- `mort_profile_style_pack`
- `mort_username_change_token`
- `mort_job_boost`

The app checks entitlements returned by RevenueCat customer info. It does not fake active entitlements.

## Products And Offerings

Suggested products:

- `mort_plus_monthly`
- `mort_plus_yearly`
- `mort_plus_lifetime`
- `mort_ad_free_lifetime`
- `mort_username_change_token_1`
- `mort_profile_style_pack`
- `mort_adult_pro_monthly`
- `mort_guardian_plus_monthly`
- `mort_job_boost_1`

Create RevenueCat Offerings: `default`, `teen_perks`, `adult_pro`, `guardian_plus`, `ad_free`, `username_change`, and `job_boost`. Attach packages to the proper entitlements.

If RevenueCat returns no offerings, MORT shows a setup-required state instead of fake plans.

## Restore And Manage

MORT includes:

- restore purchases screen
- manage subscription screen
- Apple subscription settings link

RevenueCat Customer Center is not wired yet. Add it after dashboard setup and EAS testing if the plan supports it.

## Native Build Requirement

RevenueCat purchases require an EAS development/preview build for real purchase testing. RevenueCat docs note Expo Go can preview flows but cannot fully test native in-app purchases.

Do not claim purchases work until sandbox/TestFlight purchase flows are tested on a real iPhone.

## Webhook Status

No RevenueCat webhook is deployed in this pass. The app uses RevenueCat SDK customer info as the purchase source of truth.

The Supabase monetization tables can cache webhook data later. If a webhook is added:

- create a server-only Edge Function
- verify a webhook secret
- store normalized events in `revenuecat_events`
- update entitlement cache server-side
- never expose the webhook secret to Expo/mobile

RevenueCat dashboard and App Store Connect setup are still required unless these products, entitlements, and offerings already exist.
