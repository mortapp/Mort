# Flutter iOS Build And TestFlight

Windows cannot locally build and run the native iPhone app. Use a Mac or cloud CI for archive/signing/TestFlight.

## Required Configuration

- Bundle ID: `com.mortapp.mobile`
- Apple signing: configure team, certificates, profiles, and App Store Connect app record.
- Capabilities: In-App Purchase, Push Notifications, Camera/Photo permissions as used by the app.
- AdMob iOS App ID: `ca-app-pub-9412242686563958~6217664808`
- RevenueCat iOS SDK public key: pass via Dart define `REVENUECAT_FLUTTER_IOS_SDK_KEY`.
- Supabase: pass `SUPABASE_URL` and `SUPABASE_ANON_KEY` via Dart defines.
- Enable purchases only for native test builds with `IAP_ENABLED`.
- Enable ads only for real-device test builds with `ADS_ENABLED`, keeping `USE_TEST_ADS` true until AdMob approval.

## Build Flow

1. On Mac or CI, run `flutter pub get`.
2. Confirm iOS signing and bundle ID.
3. Build/archive for iOS.
4. Upload to TestFlight.
5. Install on a real iPhone with a sandbox tester.
6. Run `docs/IPHONE_MANUAL_TEST_PLAN.md`.
7. Run `docs/REVENUECAT_SANDBOX_TEST_PLAN.md`.

Do not mark iPhone testing complete until it is run on a real iPhone or TestFlight build.
