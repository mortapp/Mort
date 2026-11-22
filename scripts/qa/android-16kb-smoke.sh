#!/usr/bin/env bash
# Requires one disposable emulator and a QA-only APK.
set -euo pipefail
apk="${1:?path to the QA-only APK}"
expected_page="${2:-16384}"
minimum_guest_kb="${3:-0}"
[[ "$expected_page" == 4096 || "$expected_page" == 16384 ]]
[[ "$minimum_guest_kb" =~ ^[0-9]+$ ]]
package=com.mortapp.mobile
test -f "$apk"

shell() { adb shell "$@" | tr -d '\r'; }

# These filters retain system startup diagnostics, not Dart application payloads.
engine_logs() {
  adb logcat -b main -b system -b crash -d -t 2500 -v brief \
    -s ActivityManager ActivityTaskManager AndroidRuntime linker nativeloader \
    FlutterJNI FlutterLoader flutterEngine FlutterActivityAndFragmentDelegate libc DEBUG lmkd lowmemorykiller |
    awk -v pkg="$package" \
      'index($0,pkg) || /FlutterJNI|FlutterLoader|flutterEngine|FlutterActivityAndFragmentDelegate|libflutter[.]so|dlopen failed/ {print}' |
    sed -E 's#(https?://)[^[:space:]<>"]+#\1[redacted]#g' |
    tail -100
}

activity_rows() {
  awk '/[Tt]opResumedActivity|[Mm]ResumedActivity|ResumedActivity:|topRunningActivity/'
}

memory_rows() {
  shell cat /proc/meminfo | awk '/^(MemTotal|MemAvailable|SwapTotal|SwapFree):/'
}

window_rows() {
  awk '/mCurrentFocus=|mFocusedApp=/'
}

focused_windows() {
  shell dumpsys window displays | window_rows
  shell dumpsys window windows | window_rows
}

diagnose() {
  local code=$?
  trap - EXIT
  printf 'MORT launch gate exit=%s; final Android diagnostics:\n' "$code" >&2
  shell dumpsys activity activities | activity_rows >&2 || true
  focused_windows >&2 || true
  memory_rows >&2 || true
  shell ps -A -o PID,NAME | awk -v pkg="$package" '$2==pkg || index($2,pkg ":")==1' >&2 || true
  shell dumpsys activity exit-info "$package" |
    awk '/ApplicationExitInfo|reason=|status=|subreason=|No process exit/' | tail -25 >&2 || true
  adb logcat -b events -d -t 1200 -v brief \
    -s am_proc_start am_proc_bound am_proc_died am_kill am_crash am_anr \
       wm_on_create_called wm_on_resume_called wm_on_paused_called wm_activity_launch_time |
    grep -F "$package" | tail -65 >&2 || true
  engine_logs >&2 || true
  exit "$code"
}

printf 'APK '; sha256sum "$apk"
page_size="$(shell getconf PAGE_SIZE)"
printf 'PAGE_SIZE=%s EXPECTED_PAGE_SIZE=%s ABI=%s SDK=%s BOOT_COMPLETE=%s\n' \
  "$page_size" "$expected_page" "$(shell getprop ro.product.cpu.abi)" \
  "$(shell getprop ro.build.version.sdk)" "$(shell getprop sys.boot_completed)"
test "$page_size" = "$expected_page"
test "$(shell getprop sys.boot_completed)" = 1
printf 'Android image: %s\n' "$(shell getprop ro.build.fingerprint)"
memory_rows
guest_kb="$(memory_rows | awk '$1=="MemTotal:" { print $2 }')"
[[ "$guest_kb" =~ ^[0-9]+$ ]] && (( guest_kb >= minimum_guest_kb ))
if [[ "$expected_page" == 16384 ]]; then
  shell setprop bionic.linker.16kb.app_compat.enabled false
  shell setprop pm.16kb.app_compat.disabled true
  test "$(shell getprop pm.16kb.app_compat.disabled)" = true
  test "$(shell getprop bionic.linker.16kb.app_compat.enabled)" = false
  echo '16 KB app compatibility mode disabled and verified'
fi
adb install "$apk"
# Re-resolve for the current user with the actual launcher intent, not a
# component-only intent that does not represent an app-icon launch.
component="$(shell cmd package resolve-activity --brief --user current \
  -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -p "$package" | tail -1)"
case "$component" in "$package"/*) ;; *) printf 'No MORT launcher component: %s\n' "$component" >&2; exit 1 ;; esac

# These buffers are on a fresh disposable emulator, never a shared device.
adb logcat -b main -b system -b crash -b events -c
trap diagnose EXIT
launch="$(shell am start -W -S --user current -a android.intent.action.MAIN \
  -c android.intent.category.LAUNCHER -n "$component")"
printf '%s\n' "$launch"
grep -Eq '^Status: ok' <<< "$launch"

previous_pid=
local_samples=0
for (( i=1; i<=30; i++ )); do
  reported_pid="$(shell pidof "$package" || true)"
  ps_pid="$(shell ps -A -o PID,NAME | awk -v pkg="$package" '$2==pkg {print $1; exit}' || true)"
  activities="$(shell dumpsys activity activities | activity_rows || true)"
  windows="$(focused_windows || true)"
  resumed="$(awk -v pkg="$package/" 'tolower($0) ~ /resumedactivity/ && index($0,pkg)' <<< "$activities")"
  focused="$(awk -v pkg="$package/" '/mCurrentFocus=/ && index($0,pkg)' <<< "$windows")"
  printf 'sample=%02d pidof=%s ps=%s resumed=%s focused=%s\n' \
    "$i" "${reported_pid:-none}" "${ps_pid:-none}" \
    "$(if [[ -n "$resumed" ]]; then echo yes; else echo no; fi)" \
    "$(if [[ -n "$focused" ]]; then echo yes; else echo no; fi)"
  if [[ "$ps_pid" =~ ^[0-9]+$ && "$reported_pid" == "$ps_pid" &&
        -n "$resumed" && -n "$focused" && "$windows" != *"${package}/"*Splash* ]]; then
    if [[ "$ps_pid" == "$previous_pid" ]]; then
      (( local_samples += 1 ))
    else
      local_samples=1
    fi
    previous_pid="$ps_pid"
    if (( local_samples >= 8 )); then
      printf 'MORT process %s remained alive, resumed and focused for %s samples.\n%s\n%s\n' \
        "$ps_pid" "$local_samples" "$resumed" "$focused"
      native_maps="$(shell run-as "$package" cat "/proc/$ps_pid/maps" 2>/dev/null |
        awk '/libflutter[.]so|libapp[.]so/ {n=split($NF,a,"/"); print a[n]}' | sort -u || true)"
      printf 'Relevant mapped libraries: %s\n' "${native_maps:-unavailable (see linker diagnostics)}"
      shell dumpsys meminfo "$package" | awk '/TOTAL PSS|TOTAL RSS|TOTAL SWAP|Native Heap|Graphics/' || true
      exit 0
    fi
  else
    previous_pid=
    local_samples=0
  fi
  sleep 1
done
exit 1
