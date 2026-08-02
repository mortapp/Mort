# MORT Phase 10 Report

Updated: 2026-07-30

## Result

The code-controlled privacy observability foundation is implemented and hosted.
Sentry and product analytics remain disabled; external dashboards, recipients,
privacy approval, and real provider events are not claimed.

## Applied Migrations

1. `20260730100000_privacy_observability_foundation.sql`

The migration passed a hosted transaction rollback test before application.
All 153 local migrations align with hosted history through
`20260730101000`; post-apply dry run reports the database up to date.

## Verified Behavior

- Analytics defaults to opt-out and writes nothing before consent.
- Opt-in and opt-out are server-owned, versioned, and timestamped.
- Product and operational taxonomies reject free-form or unknown values.
- Idempotent retries are payload-bound.
- Raw rows are service-only and contain no prohibited content columns.
- Sentry sanitization removes exception details and non-MORT breadcrumbs.
- Route analytics collapse paths to fixed surfaces.
- Push activation remains false.

## Verification

| Gate | Result |
|---|---|
| Hosted observability QA | PASS |
| Canonical hosted regression | PASS, 43/43 scripts in 437.8 seconds |
| Flutter format | PASS, 196 files / 0 changed |
| Flutter analyze | PASS, no issues |
| Flutter test | PASS, 256 passed / 2 expected skips / 0 failed |
| Migration parity | PASS, 153 aligned / 0 mismatches |
| Database lint | Actionable push warning repaired; disabled identity stub warnings remain for Phase 11 |
| Source secret scan | PASS |
| Sensitive-file scan | PASS, 1,759 files / 52 media / 10 protected values |

## Bugs Found And Fixed

1. The dependency resolver selected an older Sentry major; the current tested
   `9.25.0` release is now explicit.
2. Unsupported GoRouter listener methods were replaced with the router delegate.
3. Reading the router state before the first route match crashed bootstrap
   widget tests; the listener now waits for a non-empty configuration.
4. A rate-limit counter could overflow after sustained future use; saturation
   was added before migration application.
5. The legacy Edge observability contract expected provider error text; it now
   enforces the privacy-minimized code-only completion event.
6. The canonical runner had no per-suite timeout and its first aggregate run
   timed out without naming a stalled child. Each suite now has a configurable
   three-minute deadline and explicit exit code 124. The clean rerun passed all
   43 suites.

## External Gates

- Sentry organization, DSN, retention, access, and alert recipients.
- Privacy, legal, child-safety, store-disclosure, and analytics-consent review.
- Synthetic provider event and notification drill.
- Physical Android/iPhone validation for native crash capture.

