#!/usr/bin/env bash
# Requires a disposable emulator and a QA-only APK.
set -euo pipefail
apk="${1:?path to the QA-only APK}"
package=com.mortapp.mobile
test -f "$apk"
page_size="$(adb shell getconf PAGE_SIZE | tr -d '\r')"
echo "PAGE_SIZE=$page_size"
test "$page_size" = 16384
adb shell setprop bionic.linker.16kb.app_compat.enabled false
adb shell setprop pm.16kb.app_compat.disabled true
test "$(adb shell getprop pm.16kb.app_compat.disabled | tr -d '\r')" = true
test "$(adb shell getprop bionic.linker.16kb.app_compat.enabled | tr -d '\r')" = false
adb install "$apk"
component="$(adb shell cmd package resolve-activity --brief "$package" | tail -1 | tr -d '\r')"
case "$component" in "$package"/*) ;; *) exit 1 ;; esac

# A successful Activity Manager intent does not imply MORT is alive or visible.
# Collect only bounded crash and matching lifecycle messages on this fresh emulator.
adb logcat -b crash -c
diagnose() {
  local code=$?
  if (( code != 0 )); then
    echo 'MORT launch not verified. Emulator crash buffer and MORT process events:' >&2
    adb logcat -b crash -d -t 120 -v brief >&2 || true
    adb logcat -b events -d -t 300 -v brief -s am_crash am_proc_died am_kill |
      grep -F "$package" >&2 || true
  fi
  exit "$code"
}
trap diagnose EXIT
launch="$(adb shell am start -W -n "$component" | tr -d '\r')"
printf '%s\n' "$launch"
grep -Eq '^Status: ok' <<< "$launch"

previous_pid=
for (( i=0; i<12; i++ )); do
  pid="$(adb shell pidof "$package" | tr -d '\r' || true)"
  activity="$(adb shell dumpsys activity activities | tr -d '\r' |
    awk -v pkg="$package/" '/[Tt]opResumedActivity|[Mm]ResumedActivity/ && index($0,pkg) { if (!found++) print }' || true)"
  if [[ "$pid" =~ ^[0-9]+$ && -n "$activity" ]]; then
    if [[ "$pid" == "$previous_pid" ]]; then
      printf 'MORT process %s remained alive and resumed: %s\n' "$pid" "$activity"
      exit 0
    fi
    previous_pid="$pid"
  else
    previous_pid=
  fi
  sleep 1
done
exit 1
