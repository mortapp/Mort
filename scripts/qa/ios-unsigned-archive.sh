#!/usr/bin/env bash
# Run from flutter_mort on macOS. No provider secrets and no signing/export.
set -euo pipefail
out="${1:?absolute evidence directory}"
[[ "$out" == /* ]]
[[ ! -e "$out" ]]
mkdir -m 700 "$out"

flutter config --no-enable-swift-package-manager
test "$(xcodebuild -version | sed -n '1p')" = 'Xcode 26.6'
flutter pub get --enforce-lockfile
flutter build ipa --release --no-codesign \
  --dart-define=MORT_RELEASE_STAGE=internal_test \
  --dart-define=MORT_RELEASE_PROFILE=automated_test \
  --dart-define=MORT_OPERATIONAL_MODE=automated_test \
  --dart-define=MORT_PUBLIC_MARKETPLACE_ENABLED=false \
  --dart-define=MORT_IDENTITY_VERIFICATION_ENABLED=false \
  --dart-define=MORT_MARKETPLACE_PAYMENTS_ENABLED=false \
  --dart-define=MORT_REMOTE_PUSH_ENABLED=false \
  --dart-define=ADS_ENABLED=false \
  --dart-define=IAP_ENABLED=false

archive=build/ios/archive/Runner.xcarchive
app="$archive/Products/Applications/Runner.app"
plist="$app/Info.plist"
test -f "$plist"
test ! -e "$app/embedded.mobileprovision"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist")" = com.mortapp.mobile
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")" = 0.9.16
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist")" = 111
test "$(/usr/libexec/PlistBuddy -c 'Print :FirebaseMessagingAutoInitEnabled' "$plist")" = false
test "$(/usr/libexec/PlistBuddy -c 'Print :GADDelayAppMeasurementInit' "$plist")" = true
test -f ios/Podfile.lock
cp ios/Podfile.lock "$out/Podfile.lock"
if git ls-files --error-unmatch ios/Podfile.lock >/dev/null 2>&1; then
  git diff --exit-code -- ios/Podfile.lock
fi
archs="$(xcrun lipo -archs "$app/Runner")"
test "$archs" = arm64
{
  printf 'Git checkout: %s\n' "$(git rev-parse HEAD)"
  printf 'Configuration: Release / internal_test / automated_test / unsigned / not exported\n'
  xcodebuild -version
  printf 'iPhoneOS SDK: '; xcrun --sdk iphoneos --show-sdk-version
  flutter --version
  printf 'CocoaPods: '; pod --version
  printf 'Architecture: %s\n' "$archs"
  for key in CFBundleIdentifier CFBundleShortVersionString CFBundleVersion MinimumOSVersion \
      CFBundleURLTypes GADApplicationIdentifier GADDelayAppMeasurementInit \
      FirebaseMessagingAutoInitEnabled NSCameraUsageDescription \
      NSPhotoLibraryUsageDescription NSLocationWhenInUseUsageDescription \
      NSFaceIDUsageDescription NSUserTrackingUsageDescription; do
    printf '%s: ' "$key"
    /usr/libexec/PlistBuddy -c "Print :$key" "$plist" 2>/dev/null || echo '(absent)'
  done
  printf '\nFrameworks:\n'
  (cd "$app" && find Frameworks -maxdepth 1 -name '*.framework' -print | sort)
  printf '\nPrivacy manifests in device archive (not the distribution privacy report):\n'
  (cd "$app" && find . -name PrivacyInfo.xcprivacy -print | sort)
  find "$app" -name PrivacyInfo.xcprivacy -exec plutil -lint {} +
  if [[ -f "$app/PrivacyInfo.xcprivacy" ]]; then
    echo 'App-root privacy manifest present; reconcile declarations with observed behavior.'
  else
    echo 'No app-root privacy manifest; assess app-owned data declarations and required-reason APIs.'
  fi
  printf '\nCode signature diagnostic (absence of a distribution identity is expected):\n'
  codesign --display --verbose=2 "$app" 2>&1 || true
  printf '\nEmbedded entitlement diagnostic (cannot establish effective distribution entitlements):\n'
  codesign --display --entitlements :- "$app" 2>&1 || true
} | tee "$out/archive-inspection.txt"

ditto -c -k --keepParent "$archive" "$out/MORT-ios-unsigned.xcarchive.zip"
(cd "$out" && shasum -a 256 MORT-ios-unsigned.xcarchive.zip Podfile.lock | tee SHA256SUMS)
