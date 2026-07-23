# MORT Android Artifact Status

This bundle is for compile validation and controlled QA. It is not a Play-distributable release and is not a production-readiness claim.

## Included APKs

- `app-release-unsigned.apk` is the optimized Flutter release output. It is intentionally unsigned because the four `MORT_ANDROID_KEYSTORE_*` variables were not available.
- `app-release-qa-debug-signed.apk` contains the same optimized app code but is signed with the local Android debug key solely so it can be installed for emulator or controlled-device QA.

The debug keystore and all release signing material are excluded. Do not upload the QA-signed APK to Google Play.

## Build Mode

- Package: `com.mortapp.mobile`
- Minimum SDK: 24
- Target SDK: 36
- Hosted Supabase public URL/key: compiled from public mobile configuration
- Supabase service role, access token, and database password: not passed to Flutter
- Ads: disabled
- In-app purchases: disabled
- Background location: absent

## Verified

- Flutter analysis and 83 unit/widget tests passed.
- One Android 16 emulator native-plugin integration test passed.
- The optimized APK launched and rendered MORT on the Android 16 emulator.
- The custom `mort://app/auth-callback` scheme reached the app without a fatal error.
- The merged APK permission audit passed with 11 declared permissions and no background location, billing, advertising ID, or Android Ad Services permissions.

## Not Verified

- No physical Android device was tested.
- Biometric prompts, camera capture, Android Photo Picker, notification permission, and foreground-location choices still need physical-device QA.
- No signed AAB was created.
- Play App Signing, internal testing, Play policy review, and public release were not performed.
- iPhone, Xcode, TestFlight, App Store, legal, privacy, youth-work, and teen-safety review remain separate unfinished work.
- Production identity verification is not connected, real ID collection remains disabled, and the public marketplace must remain closed.
