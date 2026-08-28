# MORT Supreme Performance Report

## Verified Build Metrics

| Metric | Result |
|---|---|
| Final APK | 68,170,626 bytes; under 80 MB target |
| Final AAB | 51,704,746 bytes; under 60 MB target |
| Android release optimization | R8/resource shrink, obfuscation, tree-shaken fonts |
| Native alignment | ZIP `-P 16` passed; 18/18 ELF libraries passed 16 KB LOAD alignment |
| Flutter web | Release build passed; WASM dry-run passed |
| Expo reference web | 48 routes exported |
| Flutter analyzer | No issues across full project |

Feed keyset pagination, bounded retries, deduplicated append, scoped
subscriptions, file limits, and absence of an unsafe offline write queue are
code verified. Hosted functional/rate-limit tests passed.

## Manual Measurements Required

No trustworthy physical-device cold/warm launch, frame-time, jank, memory,
battery, thermal, CDN transfer, or poor-network percentile was captured. The
only API 36 AVD repeatedly lost ADB after launch and is not a valid performance
reference. Thresholds and capture commands are in
`docs/qa/MORT_PERFORMANCE_BASELINES.md`.

Status: `CODE-COMPLETE / MANUAL VERIFICATION REQUIRED`.

