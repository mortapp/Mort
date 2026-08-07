# MORT Back Navigation Report

- source checkpoint commit: `0d42023`
- version: `0.9.14+104`
- package: `com.mortapp.mobile`
- APK path: `C:\Users\micha\Mort\artifacts\back-navigation-qa\mort-closed-test-0.9.14.apk`
- APK size: `68465722` bytes
- SHA-256: `01D2C5D73170FFC0CF6A57595F475BA8B5E879A713A79CACCEF810B711D3E923`
- build type: signed closed-test APK
- signing pipeline: `scripts/build-standard-closed-test-apk.ps1`
- minSdk: `24`
- targetSdk: `36`
- Samsung device connection and physical installation: completed via wireless ADB

## Verification

- Signed APK hash verified against the canonical QA artifact.
- Wireless ADB reconnection succeeded to Samsung SM-A146U using the recovered TLS service.
- Flutter installed the rebuilt APK to the device and the package metadata reported:
  - `versionName=0.9.14`
  - `versionCode=104`
  - `package=com.mortapp.mobile`
  - `debuggable` not present in the filtered installed metadata output (release build expected).
- The app process launched successfully on the handset and remained active under the MORT package.

## Physical QA results

- Connection restored: `adb-R9TWA0WQRVM-gKWVJ6._adb-tls-connect._tcp`
- Device verified: Samsung `SM-A146U`, Android `15`
- Launch succeeded and the app reached the live auth/browser session for the installed build.
- The device-side activity dump showed the app running under `com.mortapp.mobile/.MainActivity` after install, with the auth redirect flow still active rather than a crash.
- The previously reproduced defect was traced to the shared `MortBackNavigation.fallbackRoute` mapping, which returned generic `/account-status` or auth routes for adult/guardian/admin child screens.
- Fix implemented in `flutter_mort/lib/core/widgets/mort_widgets.dart`: adult child routes now fall back to `/adult/home`, guardian child routes to `/guardian/home`, and admin child routes to `/admin/home`.
- Regression coverage added in `flutter_mort/test/mort_back_navigation_test.dart` for these role-based fallback routes.
- The release APK is now ready for the next device pass once the live authenticated role dashboard session is available for direct UI interaction.

## Notes

- The device install completed successfully and the app was launched from the rebuilt artifact.
- The current handset environment remained at the auth/browser boundary, so direct UI retest of the Post job/My jobs screens was not possible from this session.
- No pairing code or credential material was recorded.

## Next task

- Continue the authenticated Tier 1 QA pass on the Samsung device once a human-authenticated role session is available.
