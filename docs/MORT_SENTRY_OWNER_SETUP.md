# MORT Sentry Owner Setup

Updated: 2026-07-30

## Owner Actions

1. Create or select a Sentry organization and Flutter project approved for MORT
   teen data and the selected regions.
2. Review the configured retention, data residency, subprocessors, DPA, member
   access, MFA/SSO, and issue-notification recipients.
3. Obtain the public project DSN. Supply it to signed builds using the
   `SENTRY_DSN` Dart define; do not commit it to source or `.env.local`.
4. Enable `MORT_CRASH_REPORTING_ENABLED=true` only in an approved release
   profile after privacy and teen-safety review.
5. Keep `MORT_PRODUCT_ANALYTICS_ENABLED=false` until the analytics purpose,
   consent copy, retention, deletion handling, and App Store/Play disclosures
   are approved.

## Dashboard And Alerts

- Create release-health views grouped by release and environment.
- Alert on new fatal issues, significant crash-free-session regression, and a
  repeated sanitized category. Do not alert on message content or user text.
- Restrict issue access to specifically assigned engineering/safety staff.
- Run a synthetic non-sensitive crash in a non-production release and prove the
  issue, release tag, redaction, notification, and deletion workflow.

## Current State

- Sentry SDK and sanitizer: implemented and unit-tested.
- Sentry DSN: absent.
- Crash reporting build flag: false.
- Product analytics build flag: false.
- Real Sentry event and alert drill: not run.

