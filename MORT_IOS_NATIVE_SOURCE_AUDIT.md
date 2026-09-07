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

## A mistake made and caught by the existing test suite (not committed)

Initially treated the complete absence of an entitlements file
(`grep -rn "CODE_SIGN_ENTITLEMENTS|entitlements" Runner.xcodeproj/project.pbxproj`
returned nothing) as a gap, reasoning that `firebase_messaging` is a real dependency
and remote push needs `aps-environment` to register an APNs token on a real device.
Added `Runner.entitlements` + wired `CODE_SIGN_ENTITLEMENTS` into all three build
configurations + added `UIBackgroundModes` to `Info.plist`.

**`flutter test` immediately caught this as wrong**: `test/ios_platform_parity_test.dart`
already has an explicit contract test for exactly this, with the reasoning inline —

```
test('fabricates no capabilities it cannot back', () {
  expect(pbxproj, isNot(contains('CODE_SIGN_ENTITLEMENTS')),
    reason: 'no APNs or Sign in with Apple entitlement until provider '
            'configuration and legal gates actually exist');
  ...
test('never requests background location or background modes', () {
  ...
  expect(infoPlist, isNot(contains('UIBackgroundModes')));
```

This is a **deliberate, already-tested architectural decision**, not an oversight:
declaring an entitlement capability in the Xcode project without the App ID actually
being provisioned for that capability in the Apple Developer portal causes real
provisioning-profile validation failures at archive/distribution time — i.e., adding
this prematurely would *break* a real signed build, not fix one. It follows the exact
same "don't claim a capability we can't back" fail-closed philosophy verified
everywhere else in this codebase (Stripe live-mode gate, identity verification
provider config, etc.), just expressed as an Xcode-project-level contract test instead
of a database constraint.

**Reverted all three changes** (`project.pbxproj`, `Info.plist`, deleted
`Runner.entitlements`) before committing anything. Full `flutter test` regression
confirmed clean again afterward (452 passed / 2 skipped / 0 failed). Recording this
plainly rather than quietly dropping it: it's a real example of "focused verify → full
regression" catching a wrong fix before it shipped, and it confirms the existing test
suite's `ios_platform_parity_test.dart` is doing real, load-bearing work — not
decorative coverage.

Wiring APNs entitlements + background modes correctly remains real future work, but
it belongs together with the actual Apple Developer Program provisioning
(`MORT_EXTERNAL_RELEASE_GATES.md`), at the point the App ID is registered for Push
Notifications capability — not before.

## Not verified this session

- Universal Links / `com.apple.developer.associated-domains` — not present; the app
  appears to rely solely on the custom URL scheme for callbacks, consistent with the
  "no entitlements yet" posture above.
- Biometric (Face ID) native behavior beyond the usage-description string.
- Prohibited/unnecessary capabilities beyond what's visible in Info.plist/pbxproj (none
  found).
