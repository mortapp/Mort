#!/usr/bin/env bash
# Builds only a QA-host-bound, AOT/R8 artifact with an ephemeral signer.
set -euo pipefail
root="$(git rev-parse --show-toplevel)"
cd "$root"
out="${1:?unused absolute evidence directory}"
jar="${2:?absolute path to the pinned bundletool jar}"
[[ "$out" == /* && ! -e "$out" && "$jar" == /* && -f "$jar" ]]
sdk="${ANDROID_SDK_ROOT:-${ANDROID_HOME:?Android SDK is required}}"
bin="$sdk/build-tools/36.0.0"
for tool in apksigner zipalign aapt; do test -x "$bin/$tool"; done
test ! -e flutter_mort/android/key.properties
for var in MORT_UPLOAD_KEYSTORE_PATH MORT_UPLOAD_STORE_PASSWORD MORT_UPLOAD_KEY_ALIAS MORT_UPLOAD_KEY_PASSWORD; do
  if [[ -v "$var" ]]; then
    echo 'Refusing inherited signing configuration for a QA build.' >&2
    exit 2
  fi
done
sha256sum -c --status <<< "a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29  $jar"
mkdir -m 700 -- "$out"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
umask 077
fixture_password='qa-fixture-not-a-store-key'
printf '%s\n' "$fixture_password" > "$tmp/key-pass"
keytool -genkeypair -noprompt -storetype PKCS12 -keystore "$tmp/mort-ephemeral-qa.p12" \
  -storepass:file "$tmp/key-pass" -alias mort-ephemeral-qa \
  -keyalg RSA -keysize 2048 -validity 30 -dname 'CN=MORT Ephemeral QA, O=Not for Distribution'
env MORT_UPLOAD_KEYSTORE_PATH="$tmp/mort-ephemeral-qa.p12" \
  MORT_UPLOAD_STORE_PASSWORD="$fixture_password" MORT_UPLOAD_KEY_PASSWORD="$fixture_password" \
  MORT_UPLOAD_KEY_ALIAS=mort-ephemeral-qa \
  pwsh -NoProfile -File scripts/build-android-device-test-apk.ps1 -ReleaseBundle \
    -OutputPath "$out/mort-android-qa.aab"

bundle() { java -jar "$jar" "$@"; }
aab="$out/mort-android-qa.aab"
bundle validate --bundle="$aab"
bundle dump config --bundle="$aab" > "$out/bundle-config.txt"
grep -Fq PAGE_ALIGNMENT_16K "$out/bundle-config.txt"
bundle dump manifest --bundle="$aab" --module=base > "$out/bundle-base-manifest.xml"
jarsigner -verify "$aab" > "$out/aab-jar-signature.txt"
grep -Fq 'jar verified.' "$out/aab-jar-signature.txt"

for mode in default universal; do
  bundle build-apks --bundle="$aab" --mode="$mode" --output="$tmp/$mode.apks" \
    --ks="$tmp/mort-ephemeral-qa.p12" --ks-key-alias=mort-ephemeral-qa \
    --ks-pass="file:$tmp/key-pass" --key-pass="file:$tmp/key-pass"
done
mv -- "$tmp/default.apks" "$out/mort-android-qa-splits.apks"
unzip -p "$tmp/universal.apks" universal.apk > "$out/mort-android-qa-universal.apk"
mkdir "$tmp/splits"
unzip -q "$out/mort-android-qa-splits.apks" '*.apk' -d "$tmp/splits"

apk="$out/mort-android-qa-universal.apk"
"$bin/aapt" dump badging "$apk" > "$out/apk-badging.txt"
grep -Eq "^package: name='com\.mortapp\.mobile' versionCode='111' versionName='0\.9\.16'.*compileSdkVersion='36'" "$out/apk-badging.txt"
grep -Fxq "sdkVersion:'24'" "$out/apk-badging.txt"
grep -Fxq "targetSdkVersion:'36'" "$out/apk-badging.txt"
if grep -Fxq 'application-debuggable' "$out/apk-badging.txt"; then exit 1; fi
"$bin/aapt" dump permissions "$apk" > "$out/apk-permissions.txt"
"$bin/aapt" dump xmltree "$apk" AndroidManifest.xml > "$out/apk-manifest.txt"
if grep -E 'MobileAdsInitProvider|com\.google\.android\.gms\.ads\.AdActivity|AD_SERVICES_CONFIG|com\.google\.android\.gms\.ads\.APPLICATION_ID' "$out/apk-manifest.txt"; then
  echo 'Unexpected native ads startup entries in the no-ads QA artifact.' >&2
  exit 1
fi
"$bin/apksigner" verify --print-certs "$apk" > "$out/apk-signature.txt"

{
  printf '%s\n' 'Universal APK 16 KB ZIP check:'
  "$bin/zipalign" -c -P 16 4 "$apk"
  printf '%s\n' 'Split APK signature, ZIP and effective manifest checks:'
  while IFS= read -r -d '' split; do
    printf '\n[%s]\n' "${split#"$tmp/splits/"}"
    "$bin/apksigner" verify "$split"
    "$bin/zipalign" -c -P 16 4 "$split"
    "$bin/aapt" dump xmltree "$split" AndroidManifest.xml
  done < <(find "$tmp/splits" -type f -name '*.apk' -print0 | sort -z)
} > "$out/split-and-zip-inspection.txt"
grep -Fq '[splits/base-master.apk]' "$out/split-and-zip-inspection.txt"

mkdir "$tmp/libs"
unzip -q "$apk" 'lib/*/*.so' -d "$tmp/libs"
for abi in armeabi-v7a arm64-v8a x86_64; do
  for engine in libflutter.so libapp.so; do test -f "$tmp/libs/lib/$abi/$engine"; done
done
{
  while IFS= read -r -d '' lib; do
    printf '\n[%s]\n' "${lib#"$tmp/libs/"}"
    case "$lib" in
      */arm64-v8a/*|*/x86_64/*)
        segments="$(readelf -lW "$lib" | awk '$1=="LOAD"')"
        test -n "$segments"
        printf '%s\n' "$segments"
        while read -r alignment; do
          [[ "$alignment" =~ ^0x[0-9a-fA-F]+$ ]] && (( alignment >= 16384 )) || exit 1
        done < <(awk '{print $NF}' <<< "$segments")
        ;;
      *) readelf -lW "$lib" | awk '$1=="LOAD"' ;;
    esac
  done < <(find "$tmp/libs" -type f -name '*.so' -print0 | sort -z)
} > "$out/elf-alignment.txt"

{
  printf 'Checkout: %s\n' "$(git rev-parse HEAD)"
  printf '%s\n' 'Flavor: QA Supabase / internal_test / automated_test / Flutter Release AOT + R8'
  printf '%s\n' 'Signing: ephemeral QA, never for production or upload to a store'
  flutter --version
  java -version 2>&1
  bundle version
  printf '%s\n' 'Android command line tools: build-tools/36.0.0; app compile SDK 36'
} > "$out/provenance.txt"
(cd "$out"; sha256sum mort-android-qa.aab mort-android-qa-splits.apks mort-android-qa-universal.apk | tee SHA256SUMS)
