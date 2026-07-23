# Guardian Optional and Job Flow Audit

Audit date: 2026-07-13

Project ref: `rakjydmgwwgtdislanbt`

Status: implemented and remotely verified. This is not a production-readiness declaration. Physical iPhone, TestFlight, legal, privacy, and teen-safety review remain outside this audit.

## Product behavior

Guardian Mode is optional by default. The jurisdiction policy layer returns these defaults when no reviewed jurisdiction rule overrides them:

- `guardian_link_required = false`
- `guardian_approval_required_for_application = false`
- `guardian_approval_required_for_job = false`

A teen can skip Guardian Mode without losing onboarding completion, account access, job browsing, normal applications, messaging after acceptance, report/block, or Safety Ping. A specific job can still request guardian approval. That job returns a structured guardian requirement instead of applying a global restriction.

## Original application failure

The original generic permission error was not caused by age, job state, role, verification, or Guardian Mode. Remote logs and a controlled insert showed that those eligibility conditions passed.

The Flutter repository used one PostgREST statement equivalent to `insert ... returning` by chaining `.insert(...).select('*, jobs(*)')`. The applications SELECT policy called `is_application_participant`, which was marked `STABLE`. Under that statement snapshot, the helper could not see the newly inserted row, so the RETURNING read failed RLS and rolled back the insert with a generic 403.

The fix:

- `submit_job_application` performs validation and insertion in a security-definer RPC with explicit auth, role, account, age, job, verification, guardian, duplicate, and rate-limit checks.
- Direct application inserts are closed to normal authenticated users.
- `is_application_participant` is `VOLATILE` where same-statement visibility is required.
- Flutter translates structured codes such as `application_already_exists`, `job_not_open`, and `guardian_link_required` into specific copy.
- Normal jobs no longer display or enforce a guardian requirement when the stored value is false or absent.

## Guardian implementation

Teen onboarding includes `Add a guardian? Optional.` before the safety acknowledgement. It supports invite creation, optional email, using a code, and skip-for-now. Skipping persists `guardian_setup_status = skipped` and continues onboarding.

Settings route `/settings/guardian-mode` and guardian route `/guardian/linked-teens` provide:

- no-link, pending, and active states
- hashed, expiring invite codes
- resend and cancel
- guardian code acceptance
- linked profile name/avatar and linked date
- unlink confirmation that preserves the teen account and safety tools
- teen-controlled Safety Ping, check-in, accepted-job, safety warning, weekly digest, and optional job-approval preferences
- explicit notice that private message contents are not shared by default

Guardian Safety Ping delivery now derives recipients from active connections and the teen-controlled `safety_ping_alerts` setting. The guardian screen uses participant RLS, not an admin queue.

## Job and application implementation

The adult job wizard persists real drafts and published jobs through `save_job_draft_or_publish`. Its eight sections cover basics, work details, schedule, location, payment, safety/requirements, preview, and publish.

Server validation covers title, summary, description, approved category, public location fields, positive payment, age range, dates, schedule order, prohibited content, verification, rate limits, and client request idempotency. Guardian approval defaults false.

Supported owner lifecycle actions include draft, publish, edit, pause, resume, close applications, cancel, duplicate to a safe draft, and applicant review. Applications support eligibility, submit, viewed, accepted/rejected, withdraw, in-progress, real proof submission, completion, timeline, messaging route, and two-sided review.

Proof submission is not a status-only shortcut. `submit_application_proof` requires an owner-prefixed private JPEG object, locks the application/job rows, creates one proof record, and updates both states transactionally. Client-selected proof IDs make ambiguous network retries idempotent. Attached proof cannot be deleted by the uploader; only unattached orphan objects can be cleaned up.

## QA isolation

`jobs.is_test` and `profiles.is_test_account` isolate QA jobs. Normal users cannot read test jobs. Isolated QA accounts can read only test fixtures needed by the test suite. A security-definer `current_profile_is_test()` helper avoids recursive profiles/jobs RLS evaluation.

## Remote verification

The following isolated remote suites passed and removed only users they created:

- `qa-guardian-optional.mjs`: optional defaults, skip, normal apply, hashed invite, unrelated denial, teen-only preferences, Safety Ping preference delivery, unlink, and specific job requirement.
- `qa-job-lifecycle.mjs`: idempotent draft, publish, flexible schedule, QA isolation, owner RLS, safe duplicate, and history.
- `qa-job-applications.mjs`: direct insert denial, original permission fix, ownership, real private proof, idempotent retry, evidence retention, full timeline, and closed-job rejection.
- `qa-saved-jobs.mjs`: persistence, idempotency, RLS isolation, unavailable state, and removal.
- `qa-reviews.mjs`: completion requirement, moderation, participant visibility, one review per side, and reporting.
- `qa-rate-limits.mjs`: self allowance, helper denial, admin denial, and support limit.
- `qa-business-verification.mjs`: private idempotent request, status sync, evidence retention, and unrelated denial.
- `qa-old-project-smoke.mjs`: required tables, private buckets, migration history, source secret boundary, and send-push authorization.

## Remaining risk

The final Supabase Advisor rerun reports 38 security WARN findings, 0 performance WARN findings, and 28 performance INFO findings. Thirty-seven security rows are intentional authenticated security-definer lint warnings with documented authorization coverage. The remaining Auth row is **DEFERRED — PLAN-LIMITED SECURITY ENHANCEMENT** because HaveIBeenPwned leaked-password protection requires Supabase Pro or above; it is not an unresolved MORT code security bug. The seven unindexed-FK and 21 unused-index INFO findings remain documented for measurement against representative traffic.

The previously blocked credentialed QA scripts were run with temporary/dedicated QA credentials without printing or packaging them, and all required suites passed.
