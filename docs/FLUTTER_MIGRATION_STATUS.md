# Flutter Migration Status

## Completed

- Flutter app scaffolded in `flutter_mort/`.
- iOS bundle id set to `com.mortapp.mobile`.
- Android package set to `com.mortapp.mobile`.
- App label set to `MORT`.
- iOS camera/photo/notification permission strings added.
- iOS AdMob app id added to `Info.plist`.
- `.env.example` created with placeholders and public AdMob IDs only.
- `web/app-ads.txt` created.
- Supabase Flutter initialization added with Dart defines.
- Riverpod providers added.
- GoRouter route map and role guards added.
- Dark MORT design system added.
- Core screens and Coming Later states added.
- Flutter analyze passed.
- Flutter test passed.
- Flutter web build passed.

## Not Completed

- iPhone manual testing.
- TestFlight.
- App Store/legal/privacy/teen-safety review.
- RevenueCat dashboard setup and sandbox validation.
- AdMob dashboard/app-ads website verification.
- Native iOS notification permission testing.
- Native iOS photo/camera picker QA.
- Native purchase restore/purchase flows.

## Expo Status

The Expo app remains in the repo as reference and fallback until Flutter reaches full parity.
