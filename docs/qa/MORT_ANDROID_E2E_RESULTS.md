# MORT Android E2E Results

## Verdict

The first signed `0.9.12+102` closed-test APK installed and launched on Android
API 36. Its process survived startup, became the top resumed activity, and
emitted no fatal Android or Flutter log entries. A later permission-hardening
change removed `WAKE_LOCK` and produced the final APK hash; the only installed
AVD timed out before returning install/launch evidence for that exact hash.
Final-artifact and extended lifecycle automation are therefore
`CODE-COMPLETE / MANUAL VERIFICATION REQUIRED`.

## Runs

| Run | Real result |
|---|---|
| Initial signed APK build | Passed in 1,046.5 seconds; 68,170,650 bytes |
| Final signed APK build | Passed in 123.5 seconds; 68,170,626 bytes; `WAKE_LOCK` absent |
| First launch harness | Timed out after AVD boot; no app verdict recorded |
| Native integration attempt 1 | Test 1 passed; AVD went offline during test 2 |
| Hardware-GPU retry | AVD did not complete boot within five minutes |
| Constrained software retry | AVD booted, but an unbounded child command exceeded the harness timeout |
| Direct signed install | Initial update rejected because debug and release signatures differ; debug package uninstalled; release install passed |
| Direct signed launch | `Status: timeout` from slow AVD instrumentation, but PID `6666` was alive and `MainActivity` was top resumed |
| Fatal scan | Passed; no `AndroidRuntime:E` or `flutter:E` entries |
| Screenshot | Blocked when AVD dropped offline; no screenshot artifact claimed |
| Exact final APK emulator retry | Timed out after 904 seconds without a device verdict |

## Harness Repair

`scripts/run-android-native-integration.ps1` now resets ADB, constrains the AVD
to two cores/2 GB, disables Vulkan and animation scales, keeps the device awake,
accepts an explicit GPU mode, cleans up its emulator process, and writes a
secret-free machine-readable result file. A future stable AVD/device must rerun
the two unchanged integration tests and replace the current `running` result
artifact with an explicit `pass` result.

## Offline And Failure Behavior

- Auth refresh retries are bounded and preserve a valid saved session offline.
- Revoked sessions fail closed and clear local private access.
- Profile/network failure shows an offline state instead of inventing fresh data.
- The job-feed session cache is bounded, deduplicated, and visibly marked stale.
- Job publication, application transitions, messages, PIN actions, reports,
  blocks, pings, and evidence registration are never queued as unsafe offline
  writes.
- Provider-disabled capabilities explain their state and do not crash on web or
  native fallback paths.

## Remaining Manual Android Work

Repeat the blocked rows in `MORT_ANDROID_EMULATOR_MATRIX.md` on a stable API 36
emulator and at least one physical low/mid-range Android device. Capture
screenshots, TalkBack traversal, large text/display size, camera/photo denial,
network loss/recovery, notification permission denial, background/foreground,
process death, and `dumpsys gfxinfo`/memory baselines without user content in
logs.
