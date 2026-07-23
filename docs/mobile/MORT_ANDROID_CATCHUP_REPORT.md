# MORT Android Catch-Up Report

## Status

Android shared-feature source parity is implemented, the unsigned release APK compiles, and an Android 16 emulator ran both the optimized app and a native-plugin integration smoke. Physical Android-device testing, signed AAB creation, Play Console testing, and public release are not done. This is not a production-readiness claim.

## Gaps found and fixed

1. The manifest resolved `.MainActivity` as `com.mortapp.mobile.MainActivity`, but Kotlin declared `com.mortapp.flutter_mort`. The activity now uses the real package and `FlutterFragmentActivity` required by `local_auth`.
2. The release manifest lacked Internet access. Hosted Supabase HTTPS access is now declared.
3. Flutter told native users to use SwiftUI for device authentication. Shared Flutter now uses OS-backed face/fingerprint/PIN/pattern/passcode authentication and never receives biometric material.
4. Native Supabase sessions previously used default shared preferences. Native session persistence now uses `flutter_secure_storage`; web retains browser storage.
5. App lock existed only in SwiftUI. Flutter now stores an encrypted opt-in setting, locks after 1-240 minutes in the background, covers app-switcher content, and supports immediate lock.
6. Sensitive Android messages, reports, proof, safety cases, sessions, and evidence exports now set `FLAG_SECURE` while visible.
7. Android had no release camera, notification, biometric, or foreground-location declarations. They are now explicit, with camera/location hardware optional and no background location.
8. Job search now supports city/state fallback and one-shot native area resolution. Raw coordinates are discarded and never sent to Supabase by this flow.
9. Android custom deep links and the Supabase PKCE callback route are configured with `mort://app/auth-callback`.
10. Release builds silently used the debug key. Release signing now reads four environment variables and otherwise emits an unsigned compile-validation APK. Signed AAB creation is blocked when they are absent.
11. Gradle and Kotlin could each reserve 8 GB on a 15.45 GB machine. Heaps/workers were reduced to avoid memory pressure.
12. `flutter_local_notifications` failed release AAR validation because desugaring was missing. Java 17 desugaring 2.1.4 and multidex are now enabled.
13. Disabled monetization plugins merged billing, advertising ID, Ad Services, and foreground-service permissions. Those permissions are removed from the current ads/IAP-disabled Android manifest.
14. A plugin made camera hardware required. The merged release manifest now treats camera capture as optional.
15. Native session restoration and app-lock settings opened two separate Android keystores. They now share one encrypted namespace, session reads are cached after initialization, and app-lock settings load in one native read.
16. First-launch initialization could begin before Flutter painted its startup state. Initialization now begins after the first Flutter frame, while authenticated content remains covered until app-lock settings are restored.
17. The Windows regression script did not stop when an intermediate command returned a nonzero exit code. It now checks and propagates every typecheck, lint, build, and Expo Doctor failure.

## Verified build evidence

- Flutter 3.41.2, Dart 3.11.0
- Android SDK 36.1.0, compile/target SDK 36, min SDK 24
- Package and launch activity: `com.mortapp.mobile`
- `flutter analyze`: no issues
- `flutter test`: 83 tests passed
- Android 16 emulator integration test: 1 native-plugin test passed
- Optimized emulator launch: MORT welcome and sign-in screens rendered; custom-scheme cold start reached the app; no Dart/native fatal or missing-plugin errors were found
- Cleared first launch: the headless AVD held the native splash while Flutter/plugin registration took about 20 seconds, then rendered MORT; one expected secure-storage cipher initialization completed
- Subsequent cold launch: Android `am start -W` reported 5,475 ms; no secure-storage migration warning and no Dart/native fatal error
- APK: `flutter_mort/build/app/outputs/flutter-apk/app-release.apk`
- APK size: 70,529,106 bytes
- APK SHA-256: `9E3FCBA29925B1DDB0556C8D7EA6D9B65F76D02337A47947A0DABBB7EB8E3393`
- Signing audit: unsigned (`DOES NOT VERIFY`); not a distributable Play release
- Emulator runtime copy: signed only with the local Android debug key for QA; not a Play release
- AAB: not created because release signing variables are absent
- `flutter build web --release` against hosted Supabase: passed with ads/IAP disabled, confirming the Android additions did not break shared web compilation
- Source secret scan: passed
- Clean source/archive sensitive-file scan: passed for 1,023 files
- Android artifact/archive sensitive-file scan: passed for 9 files
- Mobile parity QA: 34 records passed without physical-device or iOS overclaims
- Denied-location QA: passed with manual city/state fallback and no background permission
- Feature-count integrity QA: passed with no million-scale implementation claim
- Preserved Expo reference: `pnpm check`, `pnpm lint`, 48-route web export, and Expo Doctor 20/20 passed after clean package staging was removed

## Device work still required

- Install a release-signed QA build on an API 24 device and at least one current physical Android device.
- Test biometric and device-credential fallback, lockout, cancellation, lifecycle timeout, process death, and account switching.
- Test approximate versus precise permission, denied and permanently denied location, disabled services, geocoder failure, and manual area fallback.
- Test camera and Android Photo Picker with rotation, large files, cancellation, and permission denial.
- Test notification permission and lock-screen privacy. FCM delivery is not connected.
- Test deep-link cold start, warm start, email confirmation, and password recovery after adding the redirect URL in Supabase.
- Run TalkBack, large text, display scaling, keyboard, low-memory, offline, and background/restore checks.

## Release blockers

- Stable release keystore and all `MORT_ANDROID_KEYSTORE_*` environment variables
- Signed AAB and Play App Signing setup
- Android RevenueCat public SDK key and Play products if optional purchases are enabled
- Android AdMob app/ad-unit IDs and child/teen-safe policy review if ads are enabled
- FCM/APNs-compatible push-token backend contract and provider deployment
- Verified App Links domain and `assetlinks.json`
- Privacy, App Store/Play, legal, youth-work, teen-safety, and jurisdiction review
- Production verification provider; public marketplace remains closed

## Emulator evidence boundary

The emulator pass proves that the package launches and that secure storage, permission status, local-auth capability detection, and the secure-screen MethodChannel are registered. It does not prove camera capture, biometric prompts, notification prompts, precise/approximate location choices, low-memory behavior, or real-device performance. The headless AVD was unusually slow during a cleared first launch, so its timing is not a physical-device performance result.
