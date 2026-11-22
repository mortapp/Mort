#!/usr/bin/env bash
# Requires a disposable emulator and a QA-only APK.
set -euo pipefail
apk="${1:?path to the QA-only APK}"
test -f "$apk"
page_size="$(adb shell getconf PAGE_SIZE | tr -d '\r')"
echo "PAGE_SIZE=$page_size"
test "$page_size" = 16384
adb shell setprop bionic.linker.16kb.app_compat.enabled false
adb shell setprop pm.16kb.app_compat.disabled true
test "$(adb shell getprop pm.16kb.app_compat.disabled | tr -d '\r')" = true
test "$(adb shell getprop bionic.linker.16kb.app_compat.enabled | tr -d '\r')" = false
adb install "$apk"
component="$(adb shell cmd package resolve-activity --brief com.mortapp.mobile | tail -1 | tr -d '\r')"
case "$component" in com.mortapp.mobile/*) ;; *) exit 1 ;; esac
launch="$(adb shell am start -W -n "$component" | tr -d '\r')"
printf '%s\n' "$launch"
grep -Eq '^Status: ok' <<< "$launch"
adb shell pidof com.mortapp.mobile
