#!/usr/bin/env bash
# Run from flutter_mort on a disposable Android emulator, without hosted credentials.
set -euo pipefail
version="$(awk '/^version:[[:space:]]/ { print $2; exit }' pubspec.yaml)"
if [[ ! "$version" =~ ^([0-9]+(\.[0-9]+){2})\+([0-9]+)$ ]]; then
  echo 'Cannot determine the app version and build number.' >&2
  exit 1
fi
name="${BASH_REMATCH[1]}"
code="${BASH_REMATCH[3]}"
device="$(adb devices | awk '$1 ~ /^emulator-[0-9]+$/ && $2 == "device" { print $1 }')"
if [[ ! "$device" =~ ^emulator-[0-9]+$ ]]; then
  echo 'Expected exactly one Android emulator.' >&2
  exit 1
fi
flutter test --no-pub integration_test/android_native_smoke_test.dart -d "$device" \
  --dart-define=MORT_EXPECTED_VERSION_NAME="$name" \
  --dart-define=MORT_EXPECTED_VERSION_CODE="$code" \
  --dart-define=MORT_RELEASE_STAGE=internal_test \
  --dart-define=MORT_RELEASE_PROFILE=automated_test \
  --dart-define=MORT_OPERATIONAL_MODE=automated_test \
  --dart-define=ADS_ENABLED=false
