# MORT iOS V6 Forensic Integration Report

## Provenance and scope

- Post-V6 base SHA: `d7ad6f7893f717b020ebfd2d895491133610ba77`
- iOS V6 branch: `integration/mort-ios-v6`
- Rork transfer bundle: verified
- Expected source files from transfer bundle: 2
- Applied source files: 1 (`flutter_mort/test/ios_platform_parity_test.dart`)
- iOS project regenerated: no

## OAuth callback investigation

The proposed `ArgumentError` catch in `oauth_flow.dart` was independently tested before integration and was **not reproduced** with the installed Flutter/Dart runtime (Flutter 3.47.2, Dart 3.13.2).

- `Uri.parse('#%=')` canonicalizes the fragment to `%25=` before it reaches the policy; it is therefore not an observable raw malformed percent escape at the policy boundary.
- A representable malformed UTF-8 callback fragment (`#%E0%80`) reaches `Uri.splitQueryString` and raises `FormatException`.
- The existing `on FormatException` policy branch rejects that callback without throwing. The OAuth tests remain green.

Result: the malformed callback fails closed, the claimed `ArgumentError` path was not confirmed, and no redundant shared-auth source change was applied. Valid PKCE behavior remains covered by the existing OAuth test suite.

## iOS contract audit

- Deployment target: iOS 15.0
- Bundle identifier: `com.mortapp.mobile`
- Custom URL scheme: `com.mortapp.mobile`
- Deep linking: Flutter deep linking enabled
- Permissions: Camera, Photos, Face ID, and When-In-Use Location only
- App Transport Security: strict; no broad arbitrary-load exception found
- Privacy shield: native secure-screen handling is wired
- Broad background modes / unexpected entitlements: not found
- APNs and production signing: external-environment blocked
- Universal Links: deferred; no associated-domains configuration was introduced

## Verification

| Gate | Result |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib test` | PASS |
| `flutter analyze --no-pub` | PASS |
| `flutter test --no-pub test/ios_platform_parity_test.dart` | PASS — 19 passed, 0 failed |
| `flutter test --no-pub test/oauth_flow_test.dart` | PASS — 8 passed, 0 failed |
| `flutter test --no-pub test/mort_haptics_microinteraction_test.dart` | PASS — 4 passed, 0 failed |
| `flutter test --no-pub` | PASS — 448 passed, 2 skipped, 0 failed |

## Environment limits

- iOS build: not performed; Windows host cannot run Xcode/iOS build tooling.
- Physical iPhone validation: not performed.
- TestFlight validation: not performed.

## Security regression conclusion

No Android authentication regression was introduced: shared auth source is unchanged and the OAuth tests pass. No iOS native project files were changed. The added parity suite locks the audited iOS platform and privacy contracts into the Flutter test suite.
