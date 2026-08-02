# MORT Marketplace Core Report

Date: 2026-07-29

Phase 5 is complete for the code-controlled closed marketplace core. Public
marketplace launch is not enabled and this report does not call MORT
production-ready.

## Implemented

- Server-authoritative keyset-paginated teen job feed.
- Server filters for keyword, category, amount, payment type, schedule,
  verification preference, guardian request, environment, city/state, and
  compatible travel method.
- Honest no-coordinate matching copy and current-session read fallback.
- Probable exact-street-address rejection before publication.
- Idempotent, optimistic-concurrency-controlled adult job management.
- Required participant-visible cancellation reasons.
- Consistent assigned-job/application cancellation.
- Idempotent, optimistic-concurrency-controlled application transitions.
- Legacy authenticated mutation endpoints revoked.
- Duplicate draft repair for offered amount and transportation fields.
- Flutter cancellation dialog, reopen action, stale-state errors, paging retry,
  and cancellation reason display.

## Defects Repaired

1. Load more increased the query limit and refetched every prior row. It now
   uses stable server cursors and accumulates unique pages.
2. Direct feed filtering depended on a client-side QA flag query. The server
   now owns isolation and strips internal fields.
3. Duplicate jobs dropped `adult_job_amount_cents` and transportation fields.
4. Reasonless cancellation could leave an accepted application attached to a
   canceled job.
5. Job and application retries were not idempotent and stale screens could
   mutate newer state.
6. Probable exact street addresses were not rejected by the job publication
   boundary.
7. Adult job screens refetched from newly-created futures on every rebuild and
   had no explicit cancellation-reason capture.

## Verification

- Hosted Supabase regression: 33/33 scripts passed.
- Marketplace state-machine QA: passed all checks.
- Flutter analyzer: no issues.
- Flutter tests: 244 passed, 2 expected skips.
- Migration parity: 134 local and remote, no pending migration.
- Database lint: no new finding; only previously classified disabled-provider
  and compatibility unused-parameter warnings remain.

## External Gates

- Actual production identity provider is not connected.
- Real ID collection remains disabled.
- Marketplace remains closed to the public.
- No payment processing, escrow, payout, or payment guarantee exists.
- iPhone manual testing, TestFlight, Play closed-track testing, legal review,
  child-safety review, moderation staffing, and launch approval remain external.
