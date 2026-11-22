#!/usr/bin/env bash
# Compare a built-in control launch and the MORT launcher after a verified boot.
# Run only on a fresh disposable emulator with no personal data.
set -euo pipefail
apk="${1:?APK path}"
page="${2:?expected page size}"
min_kb="${3:?minimum guest memory}"
abi="${4:-x86_64}"
test -f "$apk"
adb_short() { timeout --kill-after=2s 10s adb "$@"; }
device() { adb_short shell "$*" | tr -d '\r'; }

host_memory() {
  printf '\nHost memory and resource events, elapsed %s s:\n' "$SECONDS"
  awk '/^(MemTotal|MemAvailable|SwapTotal|SwapFree):/' /proc/meminfo
  for f in memory.current memory.max memory.events; do
    if [[ -f "/sys/fs/cgroup/$f" ]]; then
      printf '%s\n' "$f"
      sed -n '1,10p' "/sys/fs/cgroup/$f"
    fi
  done
  ps -eo comm,rss --sort=-rss | awk 'NR==1 || /qemu|emulator|adb/ {print}'
}
trap host_memory EXIT
host_memory
printf 'Controlled boot: Android %s, SDK %s, ABI %s, page %s\n' \
  "$(device getprop ro.build.version.release)" "$(device getprop ro.build.version.sdk)" \
  "$(device getprop ro.product.cpu.abi)" "$(device getconf PAGE_SIZE)"
test "$(device getconf PAGE_SIZE)" = "$page"
test "$(device getprop ro.product.cpu.abi)" = "$abi"
test "$(device getprop sys.boot_completed)" = 1
device 'cat /proc/meminfo | head -5'

device 'am start -a android.settings.SETTINGS'
control=0
for ((i=0; i<15; i++)); do
  if device dumpsys window | awk '/mCurrentFocus=.*com\.android\.settings\// {matched=1} END {exit !matched}'; then
    control=1
    break
  fi
  sleep 1
done
if [[ "$control" != 1 ]]; then
  echo 'INCONCLUSIVE: the control Settings process did not reach foreground; MORT was not started.' >&2
  exit 75
fi
echo 'Control activity acquired focus; starting MORT.'
device 'am force-stop com.android.settings'
status=0
bash "$(dirname "$0")/android-16kb-smoke.sh" "$apk" "$page" "$min_kb" || status=$?
if [[ "$status" != 0 ]] && [[ "$(adb_short get-state 2>/dev/null || true)" != device ]]; then
  echo 'INCONCLUSIVE: ADB transport was lost; this is not a MORT launch verdict.' >&2
  exit 75
fi
exit "$status"
