# Flutter Remaining Limitations

## Native Testing Not Done

- iPhone manual testing is not done.
- TestFlight is not done.
- App Store/legal/privacy/teen-safety review is not done.

## Partial Or Coming Later

- Portfolio item CRUD UI.
- Skill multi-select UI.
- Availability slot editor.
- Saved job folder UI.
- Adult job edit/close/duplicate UI.
- Detailed guardian approval decision screen.
- Admin evidence timeline and admin-note UX.
- Native image picker integration on proof and verification screens.
- Native AdMob rendering after test device setup.
- RevenueCat dashboard products, offerings, sandbox purchases, restore, and Customer Center still require real iPhone/TestFlight validation. Entitlements and webhook integration were created by API on 2026-07-09.
- Support ticket compose UI.
- Reviews, badges, goals, emergency contacts, and advanced analytics.

## RevenueCat Dashboard/API - 2026-07-09

- RevenueCat entitlements and webhook integration are configured.
- Products, offerings, packages, and full paywall designs remain blocked by RevenueCat API permissions/manual dashboard work.
- The Flutter app now reads `REVENUECAT_FLUTTER_IOS_SDK_KEY` as the preferred iOS Dart define, with the older `REVENUECAT_IOS_API_KEY` retained as fallback.

## Web Build Warning

`flutter build web` succeeded, but Flutter reported a WASM dry-run incompatibility from `file_picker` using `dart:html`. This does not block the normal web build, but it should be addressed before targeting Flutter WASM.
