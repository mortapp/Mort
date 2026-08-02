# MORT Performance Baselines

These are release gates for representative physical devices. They are not
claimed as measured physical-device results in this Windows run.

| Metric | Closed-test target | Current evidence |
|---|---:|---|
| Android cold launch to usable UI | p95 <= 3.0 s | Manual measurement required; API 36 AVD instrumentation timed out |
| Warm launch | p95 <= 1.5 s | Manual measurement required |
| Flutter build/raster frames | >= 95% within 16.7 ms on 60 Hz device | Manual profile build required |
| Severe jank | < 1% frames over 100 ms | Manual profile build required |
| Idle app memory | <= 250 MB PSS after five minutes | Manual `dumpsys meminfo` required |
| Job-feed page | p95 <= 1.5 s on normal LTE/Wi-Fi | Keyset paging/code verified; network measurement required |
| Message send acknowledgment | p95 <= 1.5 s | Hosted functional QA passed; load measurement required |
| Safety Ping server acceptance | p95 <= 1.0 s | Functional/rate-limit QA passed; load measurement required |
| APK download size | <= 80 MB | Passed: 68,170,626 bytes |
| AAB upload size | <= 60 MB | Passed: 51,704,746 bytes |
| Web initial compressed transfer | <= 5 MB target | Build passed; CDN-compressed measurement required |

## Implemented Controls

- Server-owned keyset pagination avoids refetching the full feed.
- Riverpod state appends deduplicated pages and retains bounded session cache.
- Image uploads enforce file-size and MIME limits before private Storage use.
- Animations respect reduced-motion preferences.
- Release Android uses R8, resource shrinking, tree-shaken fonts, and obfuscated
  Dart symbols stored outside the source artifact.
- Realtime subscriptions are scoped and disposed by repository/controller
  ownership; unsafe offline write queues are not implemented.

## Database Advisor Snapshot

Supabase advisors returned no error-level findings. Performance had 218
findings: 213 info and 5 warnings. The two legal/payment foundation foreign-key
items surfaced by the audit are informational, not an observed outage. Review
all 124 unindexed-FK recommendations against query plans before adding indexes;
do not add speculative indexes to a live schema without workload evidence.

## Required Follow-Up

Use a release/profile build on physical low- and mid-range Android hardware.
Capture Flutter DevTools frame timelines, `adb shell am start -W`,
`dumpsys gfxinfo`, `dumpsys meminfo`, feed/message/ping timings, and CDN web
transfer sizes. Redact identifiers and message/location content before storing
evidence.
