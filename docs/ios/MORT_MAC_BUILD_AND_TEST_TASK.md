# MORT macOS Build And Test Task

## Inputs

- Repository: this exact clean source artifact
- Flutter app: `flutter_mort`
- Version: `0.9.12+102`
- Bundle ID: `com.mortapp.mobile`
- Current deployment target: iOS 13.0
- Release profile: closed test only
- Backend ref: `rakjydmgwwgtdislanbt`

The Windows audit verified the Xcode project, bundle identifier, URL scheme,
camera/photo usage descriptions, and removal of the stale AdMob application ID.
It did not compile or run iOS.

## Mac Commands

```bash
cd /path/to/Mort/flutter_mort
flutter doctor -v
flutter pub get
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze --no-pub
flutter test --no-pub
cd ios
pod repo update
pod install
cd ..
flutter build ios --release --no-codesign \
  --dart-define-from-file=/secure/path/closed-test-defines.json
open ios/Runner.xcworkspace
```

The define file may contain only public mobile configuration and closed-test
flags. Never include a Supabase service-role key, database password, access
token, OAuth client secret, signing password, webhook secret, or provider
server secret.

## Xcode Checks

1. Select the owner Team and confirm automatic signing for
   `com.mortapp.mobile`.
2. Confirm the Release scheme and version `0.9.12 (102)`.
3. Add Push Notifications and Background Modes only after the real APNs/FCM
   integration is approved and tested. The current closed-test build keeps
   remote push disabled and has no `aps-environment` entitlement.
4. Confirm universal/custom callback handling for
   `com.mortapp.mobile://app/auth-callback`.
5. Archive, inspect privacy manifests/reasons, validate the archive, and retain
   dSYM/symbol artifacts outside source control.

## Simulator And Device Matrix

Run current iOS plus the minimum supported version where available. On a
physical iPhone test cold/warm launch, Google and password sign-in, session
restore/revocation, DOB/onboarding, every role, camera/photo denial and success,
large text, VoiceOver, reduced motion, low-data/offline recovery, background
resume, memory pressure, account deletion, and provider-disabled screens.

## Acceptance

- Zero analyzer/test/build failures.
- No crash, hang, blank screen, clipped critical action, or secret in logs.
- Role and account restrictions remain server authoritative.
- Native permissions appear only at point of use with accurate copy.
- No public marketplace activation and no real provider claims.

