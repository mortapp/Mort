# MORT Back Navigation Report

- source checkpoint commit: `d884855`
- version: `0.9.14+104`
- package: `com.mortapp.mobile`
- APK path: `C:\Users\micha\Mort\artifacts\back-navigation-qa\mort-closed-test-0.9.14.apk`
- APK size: `68465722` bytes
- SHA-256: `3BD098FAC49CCE066F57B4688EC444132DF1D49AEACDB4A723F4648470B6B12D`
- previous/pre-fix APK hash (superseded): `01D2C5D73170FFC0CF6A57595F475BA8B5E879A713A79CACCEF810B711D3E923`
- build type: signed closed-test APK
- signing pipeline: `scripts/build-standard-closed-test-apk.ps1`
- minSdk: `24`
- targetSdk: `36`
- Samsung device connection and physical installation: completed via wireless ADB

## Verification

- Fresh APK built from commit `d884855` using the standard release script.
- Build manifest recorded `gitCommit=d884855c597dc69dfee810c662f8fb4486bc2211` and `gitDirty=false`.
- The rebuilt APK hash is `3BD098FAC49CCE066F57B4688EC444132DF1D49AEACDB4A723F4648470B6B12D`, which is distinct from the superseded pre-fix hash.
- Wireless ADB reconnection succeeded to Samsung SM-A146U using the recovered TLS service.
- The rebuilt APK installed successfully via `adb install -r` and the package metadata reported:
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
- Physical post-fix retest of the Adult dashboard/Post job/My jobs flows is still blocked in this session because the handset remained at the auth/browser boundary rather than the authenticated Adult dashboard.

## Notes

- The device install completed successfully and the app launched from the rebuilt artifact.
- The current handset environment remained at the auth/browser boundary, so direct UI retest of the Post job/My jobs screens was not possible from this session.
- No pairing code or credential material was recorded.

## Next task

- Continue the authenticated Tier 1 QA pass on the Samsung device once a human-authenticated Adult dashboard session is available.
