# Guardian, Private Job Location, and Distance Contracts

**Status:** implementation specification based on a read-only inspection of production Supabase project `jxbnrkasktbhtiujkhay` and the Flutter source on `codex/mort-production-reference-architecture`, 2026-10-31.

**Environment boundary:** this document does not authorize a production schema change. The marketplace, publishing, and payments remain disabled. Implement and verify against a disposable database cloned from the current production schema before proposing any production migration.

## 1. Verified current-state findings

### Guardian approval

The current production schema contains:

- `public.guardian_links`, with teen/guardian IDs, pending/active/revoked/rejected status, and bilateral consent timestamps.
- `public.guardian_preferences.optional_job_approval_enabled`.
- `public.job_applications.guardian_id`.
- `public.jobs.requires_guardian_approval`.

The active `public.submit_job_application(uuid,text,boolean,uuid[])` RPC delegates to `mort_submit_job_application`, which inserts a normal application and does not persist a per-application Guardian decision. `get_job_application_eligibility(uuid)` checks for an active, bilaterally consented Guardian link when the job requires approval, but it does not establish that the Guardian approved that application. The inspected `mort_accept_job_application(uuid)` checks for an active Guardian link, but does not check a recorded approval decision for the specific application.

The application status enum currently contains `submitted`, `withdrawn`, `shortlisted`, `accepted`, `rejected`, and `cancelled`; it does not contain `guardian_pending` or `guardian_rejected`. Do not assume the older state-machine documentation or older schema is the hosted contract.

### Private job location

The active production schema inspection did not find `public.job_private_locations` or location lifecycle RPCs. The Flutter job repository calls `get_nearby_job_distances_v1`, but that RPC is not present in the active project. The historical migration `20260819000000_job_site_precise_location_and_distance.sql` is not safe to apply as written: it assumes `public.applications` and `teen_id`, while the active schema uses `public.job_applications` and `applicant_id`. It also assumes a location table that is absent from the inspected production schema.

The active `jobs` table contains an `exact_address` column. Ordinary feed/detail payloads must never expose that field. Treat it as legacy sensitive data and verify the active RLS and RPC projections before any use.

### Distance

The active Flutter repository sends the teen's current coordinates to `get_nearby_job_distances_v1` and expects rounded miles keyed by job ID. The RPC is absent from production. A previous draft computes distance from arbitrary caller-supplied coordinates and returns one-decimal precision. That design is vulnerable to repeated coordinate probing and must not be carried forward without abuse controls and a privacy review.

## 2. Guardian approval contract

Guardian Mode remains voluntary and scoped. A Guardian link is not a blanket permission to inspect a teen's account, messages, applications, identity evidence, or location.

For a job with `requires_guardian_approval = false`:
- An eligible teen may apply without a Guardian link.
- No Guardian decision is created or required.
- The teen's optional Guardian preferences do not become a global application restriction.

For a job with `requires_guardian_approval = true`:
- Eligibility requires an active Guardian link with both consent timestamps.
- Application submission creates a distinct, pending, application-specific approval record bound to the teen, Guardian, job, and application.
- The Guardian can see only the minimum application/job summary needed to decide; no unrelated teen profile or private data is returned.
- Only the Guardian on the active link bound to that application may approve or decline.
- Approval/decline is a dedicated authenticated RPC, not a direct table update. It locks the application and approval row, validates the current link and both consents, checks that the application is still pending and the job remains eligible, then records actor, decision, timestamp, and bounded optional reason.
- The adult poster cannot accept the application until the application-specific decision is approved.
- Decline prevents acceptance and is visible to the teen as a clear status.
- Link revocation, application withdrawal, job cancellation/closure, or a material application/job change invalidates a pending decision. Re-linking must not silently revive an old approval.
- All state transitions are atomic and idempotent; retries cannot create duplicate approvals or overwrite a terminal decision.
- The teen can withdraw at any time. The Guardian cannot withdraw the teen's application or impersonate the teen.

Implementation shape to evaluate against the existing schema:
- Prefer a dedicated `private.job_application_guardian_approvals` record with a unique application key, immutable teen/Guardian/job binding, status (`pending`, `approved`, `declined`, `invalidated`), decision actor/time, timestamps, and a bounded reason.
- Keep direct client table access denied. Expose narrowly scoped Guardian queue/detail and decision RPCs.
- Bind the Guardian identity server-side from the active `guardian_links` relationship; never trust a client-supplied Guardian ID.
- Update eligibility, application submission, and adult acceptance as one contract set. Do not rely on the old `mort_accept_job_application` Guardian-link-only check.
- Confirm whether the active app's `update_application_status_v3` call is deployed; it was not present in the inspected production function inventory. Reconcile the client call to the current canonical transition RPC before changing application states.

## 3. Private job-location contract

Use one canonical restricted location record per job. Do not duplicate exact address/coordinates into public job rows, feed JSON, logs, analytics, notifications, or ordinary application payloads.

Capture:
- Adult/business poster's explicit, one-time job-site location capture, preferably device GPS with permission and a clear manual fallback.
- Latitude and longitude validated as a pair and within geographic bounds.
- Accuracy and capture timestamp; never silently claim an inaccurate location is verified.
- Optional arrival/access instructions, length-limited and treated as sensitive.
- Version number and verified state.

Access:
- Poster may manage their own job's restricted location through a caller-bound RPC.
- Unrelated users, other teens, other adults, and Guardians receive no exact address or coordinates.
- An assigned teen receives exact navigation coordinates/address only after the application is accepted, the job has an active assignment, both parties have confirmed the current version of the job safety agreement, and neither party has blocked the other.
- Check current assignment/application/job states on every read. Do not trust cached client role, old acceptance state, or an old agreement confirmation.
- Location changes increment the version and invalidate both parties' prior agreement confirmations; the exact location remains withheld until both reconfirm.
- Completed, cancelled, withdrawn, rejected, revoked, blocked, or otherwise inactive relationships deny release.
- Log each sensitive read/write in the restricted access audit trail, without copying the address or coordinates into the audit reason.
- Direct table SELECT/INSERT/UPDATE/DELETE from client roles is denied. Use RLS as defense in depth and explicit grants.

## 4. Server-side distance contract

The server may calculate a coarse distance from the teen's current, explicitly permissioned, on-demand location to private job coordinates. It must not persist the teen's precise coordinates.

Required safeguards:
- Authenticated active teen only; reject adult, Guardian, anonymous, and service misuse from the public RPC.
- Maximum 50 job IDs per call; deduplicate IDs and return only open, approved, application-enabled jobs.
- Validate coordinate ranges and reject null, non-finite, or malformed inputs.
- Return coarse distance bands (not raw coordinates or high-precision distances). Do not use one-decimal-mile output as the default because repeated chosen-coordinate queries can triangulate a job site.
- Apply per-user rate limits and query budgets; return a stable throttling code. Do not make the RPC an unrestricted location oracle.
- Never reveal whether an arbitrary non-open/private job has a location record.
- No location result is a valid outcome; missing job coordinates must not trigger public address fallback or client-side geocoding.
- Use a deterministic distance implementation and tests for bounds, antimeridian, poles, rounding/banding, and empty/mixed job sets.
- The client must treat distance as approximate and optional. Denial, timeout, permission refusal, or missing coordinates must not block job browsing or application.

A product/privacy decision is still required for the exact distance bands, rate-limit window, and location-retention policy. Do not silently choose a precision level that enables home/workplace inference.

## 5. Required tests before production proposal

### Guardian
- No Guardian link + job does not require approval: application succeeds if all other gates pass.
- No Guardian link + job requires approval: eligibility fails with a stable Guardian-required code.
- Active link + required job: application is created pending Guardian decision and cannot be accepted by poster.
- Correct linked Guardian approves: state becomes approved and poster acceptance becomes eligible.
- Wrong Guardian, unrelated Guardian, unrelated adult, teen self-approval, or poster decision attempt: denied.
- Guardian declines: poster acceptance denied; teen sees declined state.
- Link revoked/replaced, job closed/cancelled, application withdrawn, or relevant terms changed: pending approval invalidated.
- Concurrent duplicate decisions and retry/replay: one deterministic terminal result, no duplicate records.
- Guardian sees only the specific application summary; no identity evidence, messages, unrelated applications, or precise location.

### Private location
- Direct client table reads/writes denied for anon/authenticated.
- Public job/feed/detail/notification payloads contain neither exact address nor coordinates.
- Poster can save/read own location; other posters cannot.
- Unaccepted applicant, unrelated teen, unrelated adult, and Guardian denied.
- Assigned teen denied before both current safety confirmations.
- Exact location allowed only to current assigned teen after mutual confirmation.
- Block, revocation, cancellation, completion, withdrawal, and material location change deny release.
- Every sensitive access is audited; audit output contains no location value.

### Distance
- Active teen receives only coarse bands for eligible open jobs.
- Adult/Guardian/anonymous callers denied.
- Raw job coordinates never returned.
- Arbitrary coordinate probing is rate-limited and bounded.
- More than 50 IDs rejected; duplicates normalized; closed/unapproved/no-coordinate jobs omitted without existence leakage.
- Permission denied/offline/no location leaves feed usable.
- Tests prove no teen coordinate is stored.

## 6. Implementation and release sequence

1. Reconcile current production schema, deployed RPC signatures, RLS, grants, and Flutter call sites. Treat live inspection as read-only.
2. Create a disposable database from the current production schema and apply only the new minimal migration there.
3. Implement Guardian approval table/RPCs and update the current submit/eligibility/acceptance contracts together.
4. Implement restricted job-location storage and lifecycle RPCs against `job_applications`, `job_assignments`, and `job_safety_agreements` (not the stale `applications` schema).
5. Implement a coarse, rate-limited distance RPC with adversarial probing tests.
6. Update Flutter repository/models/screens to match the final RPC contracts; keep distance optional and Guardian approval visibly application-specific.
7. Run SQL compilation, migration replay, grants/RLS tests, Flutter tests/analyze, and adversarial cross-role integration tests in isolation.
8. Produce a migration diff and evidence report for owner review. Production application requires a separate explicit approval and backup/restore readiness.

**Do not deploy this work to production, change production tables/functions, enable marketplace/publishing, or turn on payments as part of this implementation phase.**
