#!/usr/bin/env bash
# Unsigned iOS simulator check. Does not use a server or Apple account.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)/flutter_mort"
test "$(xcodebuild -version | sed -n '1p')" = 'Xcode 26.6'
runtime=com.apple.CoreSimulator.SimRuntime.iOS-26-6
device="$(xcrun simctl list devices available --json | jq -er --arg runtime "$runtime" '
  .devices[$runtime] | map(select(.isAvailable == true and (.name | startswith("iPhone")))) |
  .[0].udid')"
printf 'Simulator runtime: %s\n' "$runtime"
trap 'xcrun simctl shutdown "$device" >/dev/null 2>&1 || true' EXIT
xcrun simctl boot "$device"
xcrun simctl bootstatus "$device" -b
xcodebuild -version
xcrun simctl list devices "$runtime" booted
flutter config --no-enable-swift-package-manager
flutter pub get --enforce-lockfile
flutter test --no-pub -d "$device" integration_test/native_release_entry_test.dart \
  --dart-define=MORT_RELEASE_STAGE=development \
  --dart-define=MORT_REMOTE_PUSH_ENABLED=false \
  --dart-define=MORT_PRODUCT_ANALYTICS_ENABLED=false \
  --dart-define=MORT_CRASH_REPORTING_ENABLED=false \
  --dart-define=ADS_ENABLED=false
