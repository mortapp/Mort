#!/usr/bin/env bash
# Exercise both public welcome actions on a fresh QA-only emulator.
# No credentials are entered and no account is created.
set -euo pipefail

adb_short() { timeout --kill-after=2s 15s adb "$@"; }
device() { adb_short shell "$*" | tr -d '\r'; }

ui_dump() {
  device 'uiautomator dump /sdcard/mort-welcome-ui.xml >/dev/null 2>&1 && cat /sdcard/mort-welcome-ui.xml'
}

wait_for_label() {
  local label="$1"
  local xml=""
  for ((i=0; i<20; i++)); do
    if xml="$(ui_dump 2>/dev/null)" && grep -Fq "$label" <<< "$xml"; then
      printf '%s' "$xml"
      return 0
    fi
    sleep 1
  done
  printf 'Required UI label did not appear: %s\n' "$label" >&2
  return 1
}

tap_label() {
  local label="$1"
  local xml point x y
  xml="$(wait_for_label "$label")"
  point="$(python3 -c '
import re, sys, xml.etree.ElementTree as ET
label = sys.argv[1]
root = ET.fromstring(sys.stdin.read())
candidates = []
for node in root.iter("node"):
    attrs = node.attrib
    if label not in attrs.get("text", "") and label not in attrs.get("content-desc", ""):
        continue
    match = re.fullmatch(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", attrs.get("bounds", ""))
    if not match:
        continue
    x1, y1, x2, y2 = map(int, match.groups())
    candidates.append(((x2 - x1) * (y2 - y1), (x1 + x2) // 2, (y1 + y2) // 2))
if candidates:
    _, x, y = min(candidates)
    print(x, y)
' "$label" <<< "$xml")"
  if [[ -z "$point" ]]; then
    printf 'Could not locate tappable UI bounds for: %s\n' "$label" >&2
    return 1
  fi
  read -r x y <<< "$point"
  device "input tap $x $y"
  sleep 1
}

echo 'Waiting for the MORT splash screen.'
wait_for_label 'Enter MORT' >/dev/null
tap_label 'Enter MORT'

echo 'Verifying the welcome screen and both account actions.'
welcome="$(wait_for_label 'Welcome to MORT')"
grep -Fq 'Create account' <<< "$welcome"
grep -Fq 'I already have an account' <<< "$welcome"
tap_label 'I already have an account'

echo 'Verifying the sign-in action.'
signin="$(wait_for_label 'Welcome back')"
grep -Fq 'Access MORT' <<< "$signin"
grep -Fq 'Sign in' <<< "$signin"

device 'input keyevent 4'
echo 'Verifying the create-account action.'
wait_for_label 'Welcome to MORT' >/dev/null
tap_label 'Create account'
signup="$(wait_for_label 'Date of birth (MM/DD/YYYY)')"
grep -Fq 'Age-gated' <<< "$signup"
grep -Fq 'Access MORT' <<< "$signup"

echo 'PASS: splash-to-welcome, sign-in, and create-account actions are visible and navigable.'
