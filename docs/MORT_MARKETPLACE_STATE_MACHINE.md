# MORT Marketplace State Machines

Status: code-controlled Phase 5 behavior verified on the hosted Supabase
project `rakjydmgwwgtdislanbt` on 2026-07-29.

This document describes implemented behavior. It is not a claim that the
public marketplace is open. Production public access remains closed until a
real identity provider, legal approval, operational staffing, and the release
profile gates are in place.

## Marketplace Visibility

`private.can_view_marketplace_job(job_id)` is the authoritative visibility
gate. It requires an authenticated active profile. Owners, admins, and real
application participants retain history access. Open-feed access then requires:

- isolated QA accounts and jobs with current sandbox identity records; or
- non-test accounts and jobs after production identity readiness is enabled
  and both viewer and poster have current production identity records.

The current public-production branch fails closed because production identity
readiness is not enabled.

## Job State Machine

| From | Action | To | Server conditions |
|---|---|---|---|
| none | save draft | `draft` | Active adult/admin, caller-bound request ID |
| `draft` | publish | `open` | Verification, closed-pilot policy, content, amount, schedule, category, age, location, and rate-limit checks pass |
| `open` | pause | `paused` | Owner/admin, current row version |
| `paused` | resume | `open` | Owner/admin, current row version |
| `open` | close applications | `open` | `applications_open=false` |
| `open` | reopen applications | `open` | `applications_open=true` |
| `open`, `paused`, `assigned` | cancel with reason | `canceled` | Reason is 10-500 chars and contains no contact/payment handle |
| `draft` | delete | deleted | Owner/admin, current row version; management audit retained |
| any existing job | duplicate | new `draft` | Compensation and travel fields preserved; schedule, applicants, guardian request, publication state, and request ID reset |
| `open` | accept applicant | `assigned` | Exactly one eligible application accepted under a parent-job row lock |
| `assigned` | verified execution start | `in_progress` | Execution and safety checks described in Phase 6 contracts |
| `in_progress` | real proof submission | `proof_submitted` | Private object and canonical proof record verified |
| `in_progress`, `proof_submitted` | complete | `completed` | Poster authorization and proof requirement satisfied |

An in-progress job cannot use the simple cancellation action. It must enter the
support, safety-cancellation, or dispute path so completed work and evidence are
not erased by one party.

Legacy enum values remain for historical records and older subsystems. They are
not new client transition targets unless a dedicated server function documents
the path.

## Application State Machine

| From | Actor/action | To |
|---|---|---|
| none | Eligible teen submits | `guardian_pending` or `adult_review` |
| `guardian_pending` | Linked guardian approves | `adult_review` |
| `guardian_pending` | Linked guardian declines | `guardian_rejected` |
| `submitted`, `adult_review` | Poster views | `viewed` |
| `submitted`, `adult_review`, `viewed` | Poster accepts | `accepted` |
| `submitted`, `adult_review`, `viewed` | Poster declines | `rejected` |
| pre-accept review states | Teen withdraws | `withdrawn` |
| `accepted` | Job canceled before work | `canceled` |
| `accepted` | Verified execution starts | `in_progress` |
| `in_progress` | Real private proof is attached | `proof_submitted` |
| `in_progress`, `proof_submitted` | Poster completes | `completed` |

The proof state cannot be reached through the generic status RPC. It is reached
only by the proof-storage verification function. Proof-required jobs cannot be
completed from `in_progress` without submitted proof.

## Integrity Contracts

- `manage_job_v2` and `update_application_status_v3` use caller-bound request
  IDs and persist deterministic responses.
- Repeating the same actor/request ID returns the stored response with
  `replayed=true`; changing the resource or action returns
  `client_request_conflict`.
- Both contracts accept `expected_updated_at` and reject stale writes.
- Application acceptance locks the parent job before the application, so two
  applicants cannot be accepted concurrently.
- Job and application status triggers append participant-visible status events.
- Job cancellations append a forced-RLS management event with the reason.
- Direct client inserts/updates for protected jobs and applications remain
  blocked by RLS; authenticated execution of the legacy mutation RPCs is
  revoked.
- No marketplace transition creates, settles, or proves a payment. Amounts are
  listing/contract values only; MORT does not process, hold, guarantee, or mark
  them paid.

## Feed And Matching

`list_open_jobs_page` performs server-side filtering and keyset pagination.
Stable cursors are `(created_at,id)`, `(pay_amount_cents,id)`, or
`(starts_at,id)` depending on sort. Page size is clamped to 1-50.

The feed never fabricates distance. MORT currently has no job/viewer coordinate
pair, so every row returns `distance_status=unavailable` and a plain-language
fallback. Matching uses general city/state filters and intersection with saved
travel methods. Maximum distance and travel time remain user preferences for
manual comparison until a reviewed approximate geospatial design exists.

The feed strips request IDs, ZIP codes, special instructions, and internal
safety flags. A publication trigger rejects probable exact street addresses in
all public job text. Exact location release uses the separate private,
post-acceptance, two-sided confirmation workflow.

Flutter uses an auto-disposed Riverpod async family that accumulates cursor
pages, removes duplicate IDs, supports retry, and can show the last successful
page from the current signed-in session during a connectivity failure. Feed
cache is not persisted across repository/session recreation.

## Verification Evidence

- `scripts/qa-marketplace-state-machine.mjs`: pagination, filtering, malformed
  cursor, QA/production isolation, old-RPC revocation, ownership, reason
  validation, idempotent replay, stale writes, duplication, assigned
  cancellation, audit visibility, and exact-address rejection.
- `scripts/qa-job-lifecycle.mjs`: draft, resume, publish, pause, duplicate,
  delete, role isolation, schedule validation, and event history.
- `scripts/qa-job-applications.mjs`: eligibility, submission, review,
  acceptance, start, private proof, completion, and proof-required behavior.
- `scripts/qa-complete-multi-user-isolation.mjs`: 30 cross-role and cross-user
  isolation checks.
- Full hosted wrapper: 33/33 scripts passed in 165.9 seconds.
- Flutter: 244 passed, 2 expected compile-profile skips, 0 failed.

