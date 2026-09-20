# MORT iOS Native Source Audit

Static review of the actual native iOS project (no macOS available to build/run this
session — real verification will come from `.github/workflows/mort-ios-browserstack.yml`
once pushed and triggered).

## Verified sound, no change needed

- **Bundle ID / deployment target**: `com.mortapp.mobile`, iOS 15.0 — matches the
  documented floor, not silently raised.
- **AppDelegate.swift privacy shield**: implements the iOS equivalent of Android's
  `FLAG_SECURE` over the *same* `mort/native_security` method channel name — when a
  Dart-side `SensitiveScreenProtection` widget is active AND the app is
  backgrounded/inactive OR `UIScreen.capturedDidChangeNotification` fires (screen
  recording detected), it overlays a branded blank shield hiding real content. This is
  the correct, standard iOS approach (no direct FLAG_SECURE equivalent exists on iOS)
  and confirms cross-platform parity for a safety-relevant feature, not just an
  Android-only control.
- **OAuth mechanism**: both Google and Apple sign-in go through Supabase's generic
  `signInWithOAuth`/`linkIdentity` with `authScreenLaunchMode: LaunchMode.
  externalApplication` (system browser, not an in-app webview or native SDK) —
  `CFBundleURLTypes` in Info.plist correctly registers the `com.mortapp.mobile` custom
  scheme for the redirect callback.
- **Firebase without committed config files**: `firebase_messaging` is initialized via
  fully programmatic `FirebaseOptions` built from `AppConfig.firebase*` values
  (`lib/services/push/remote_push_provider.dart:99`), not `GoogleService-Info.plist`.
  Deliberate, valid choice — initially suspected this was a gap, verified it wasn't
  before touching anything.
- **Info.plist usage-description strings**: all four (`NSCameraUsageDescription`,
  `NSFaceIDUsageDescription`, `NSLocationWhenInUseUsageDescription`,
  `NSPhotoLibraryUsageDescription`) plus `NSUserNotificationsUsageDescription`
  accurately describe the actual features they gate — no generic placeholder text, no
  over-broad "always" location usage.
- **ATS stays strict**: no `NSAllowsArbitraryLoads`/`NSExceptionDomains`.

## Store-parity capability update — 2026-09-20

The earlier fail-closed decision to omit APNs capabilities was correct while no App Store signing/release path existed. That premise changed when the owner requested iOS release parity with Android.

Current Flutter iOS now includes:

- `Runner.release.entitlements` with production APNs, wired to Runner Release/Profile only;
- `UIBackgroundModes = remote-notification`, with no background-location or audio mode;
- `PrivacyInfo.xcprivacy` bundled as a Runner resource;
- a normal macOS `ios-authoritative` CI job;
- a protected signed iOS closed-test workflow that rejects a provisioning profile unless it targets `com.mortapp.mobile`, matches the configured Apple team, and includes production APNs.

This is capability preparation, not provider activation. Runtime push remains fail-closed behind `MORT_REMOTE_PUSH_ENABLED` plus complete Firebase iOS configuration. Debug builds do not use the production APNs entitlement.

Apple OAuth remains the existing Supabase PKCE browser flow, so this pass does not fabricate the native `com.apple.developer.applesignin` entitlement.

## Not verified this session

- Universal Links / `com.apple.developer.associated-domains` — not present; the app
  appears to rely solely on the custom URL scheme for callbacks, consistent with the
  "no entitlements yet" posture above.
- Biometric (Face ID) native behavior beyond the usage-description string.
- Prohibited/unnecessary capabilities beyond what's visible in Info.plist/pbxproj (none
  found).
