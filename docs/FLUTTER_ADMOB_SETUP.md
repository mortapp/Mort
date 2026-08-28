# Flutter AdMob Setup

MORT uses `google_mobile_ads` for Flutter.

## Configuration
- **iOS App ID**: `ca-app-pub-9412242686563958~6217664808` is set in `ios/Runner/Info.plist` and `app_config.dart`.
- **Banner Ad Unit**: `ca-app-pub-9412242686563958/2438237282` is set in `app_config.dart`.
- **Rewarded Ad Unit**: `ca-app-pub-9412242686563958/1223146979` is set in `app_config.dart`.
- Interstitial and Native ad units are omitted intentionally per design and missing IDs.

## Constraints
- Ads default to OFF unless explicitly allowed by the backend (which checks user consent, age, and subscription status).
- Ad-free / Plus users never see ads.
- Ads are suppressed on all sensitive screens (safety, reports, payments, verification, chat).
- Real testing requires a physical device. Test mode is used in simulators.
