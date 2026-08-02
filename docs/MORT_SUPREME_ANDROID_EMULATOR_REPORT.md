# MORT Supreme Android Emulator Report

The installed API 36.1 x86_64 AVD booted and the pre-permission-hardening
`0.9.12+102` signed APK installed, launched, stayed alive, became top resumed,
and produced no fatal Android/Flutter log entries. The final APK differs by one
permission-hardening manifest change (`WAKE_LOCK` removal); its exact-hash
emulator retry timed out without returning a device verdict.

The native integration run completed its plugin/secure-storage test, then ADB
dropped offline during the large-text journey. Hardware-GPU boot also failed;
constrained software runs continued to expose host AVD instability. No
screenshot, extended lifecycle, physical Android, or performance result is
claimed.

Status: `CODE-COMPLETE / MANUAL VERIFICATION REQUIRED`.

Detailed environment, 50 journeys, failures, and remaining device work are in:

- `docs/qa/MORT_ANDROID_EMULATOR_MATRIX.md`
- `docs/qa/MORT_ANDROID_E2E_RESULTS.md`
- `docs/qa/MORT_PERFORMANCE_BASELINES.md`

