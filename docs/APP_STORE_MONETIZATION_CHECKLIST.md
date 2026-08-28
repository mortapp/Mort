# App Store Monetization Checklist

This checklist is not legal advice and does not guarantee approval.

## Apple / EAS

- Create or confirm EAS project id.
- Configure Apple signing.
- Build an EAS development build for RevenueCat/AdMob native modules.
- Build an EAS preview build for real-device QA.
- Test on a real iPhone.
- Do not claim Expo Go fully tests purchases or ads.

## RevenueCat

- Create RevenueCat project.
- Connect App Store app.
- Add public iOS SDK key to EAS/Expo public env.
- Create products in App Store Connect.
- Import products into RevenueCat.
- Create entitlements: `mort_plus`, `mort_ad_free`, `mort_adult_pro`, `mort_guardian_plus`, `mort_lifetime`, `mort_profile_style_pack`, `mort_username_change_token`, `mort_job_boost`.
- Configure products: `mort_plus_monthly`, `mort_plus_yearly`, `mort_plus_lifetime`, `mort_ad_free_lifetime`, `mort_username_change_token_1`, `mort_profile_style_pack`, `mort_adult_pro_monthly`, `mort_guardian_plus_monthly`, `mort_job_boost_1`.
- Create Offering and packages.
- Test sandbox purchase.
- Test restore purchase.
- Confirm RevenueCat customer info shows entitlements.

## AdMob

- Confirm iOS app id: `ca-app-pub-9412242686563958~6217664808`.
- Confirm banner unit: `ca-app-pub-9412242686563958/2438237282`.
- Confirm rewarded unit: `ca-app-pub-9412242686563958/1223146979`.
- Create missing interstitial/native units if used.
- Configure app-ads.txt on developer website root.
- Use test ads during development.
- Configure consent/UMP.
- Decide whether ATT is needed.
- Complete App Store privacy disclosures.

## Teen Safety

- Confirm no safety feature is paid.
- Confirm no ads on safety/report/chat/proof/verification/admin/payment screens.
- Confirm teen ad treatment is conservative.
- Confirm purchase copy tells teens to involve a guardian.
- Confirm legal review covers teen labor and parental consent/privacy.

## Final Launch Gates

- iPhone manual QA complete.
- TestFlight QA complete.
- RevenueCat sandbox/live validation complete.
- AdMob test/live validation complete.
- App Store privacy nutrition labels complete.
- Terms/Privacy/Community Rules final.
- Moderation/support staffing ready.

Current status: iPhone manual testing is not done, TestFlight is not done, and App Store/legal/privacy/teen-safety review is not done.

## Flutter Rebuild Update

- iOS bundle id placeholder is `com.mortapp.mobile`.
- iOS AdMob app id is present in Flutter `Info.plist`.
- iOS camera, photo library, and notification usage descriptions are present.
- RevenueCat Flutter SDK and Customer Center package are installed.
- RevenueCat dashboard setup and native sandbox/TestFlight validation are still required.
- AdMob website app-ads hosting and review are still required.

## 2026-07-09 Update

- RevenueCat entitlements were created by API.
- Supabase RevenueCat webhook was deployed and direct webhook QA passed.
- RevenueCat products/offerings/packages/paywalls are not complete because the current v2 API key lacks product configuration permissions.
- App Store Connect IAP products, iPhone sandbox purchases, TestFlight, and App Store review are still not done.
