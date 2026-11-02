# Backend proposal review notes

These notes reflect a read-only review of the active production database and the proposal files in this directory. They are not a statement that the proposals have passed integration or concurrency testing.

## 1. Application submission and private location

Already present in production:
- Application eligibility takes transaction-level locks and rechecks the relevant eligibility state in the submission transaction.
- Private exact-location release is server-gated by assignment state and the required safety agreement.
- Block and message operations use a shared participant-pair lock.

Still required:
- Two-session tests proving submit-vs-block, message-vs-block, and guardian-preference-vs-submit serialization.
- A complete test of the exact-location release lifecycle, including assignment cancellation and safety-agreement version changes.

## 2. Guardian application approval

The current production schema has no per-application Guardian decision status or decision RPC. A linked Guardian is not equivalent to approval of a specific application.

The proposals add a pending/approved/rejected decision flow and restrict poster visibility until approval. Apply the direct-read privacy proposal **after** the Guardian visibility proposal: row-level security controls which rows a poster can read, not which columns of an allowed row are visible. Without the direct-read restriction, a poster with table-level SELECT can read `guardian_id` and the new Guardian decision metadata on an approved row.

The Flutter repository's supported application reader is `get_my_job_applications(uuid)`; do not restore direct client SELECT on `job_applications` without a column-level privacy design.

## 3. Distance bands

The current production feed RPC `list_open_jobs_page` returns `distance_status = 'unavailable'`. The proposed `get_job_distance_v1` is a separate per-job RPC; it does not itself change the feed response. The client must submit a user location and call the distance RPC, and the poster flow must populate an approximate job-location center.

The proposed rate limit is 30 lookups per minute. Before integrating it into a multi-card feed, prefer a batch RPC or a feed-level distance calculation to avoid an N+1 request pattern. Only coarse distance bands should leave the server; exact coordinates must remain private.

## 4. Safety-report moderation

The moderation proposal adds staff-authorized status transitions and audit entries. It does not by itself provide an on-call paging system, critical-incident notification delivery, staffing coverage, or 24/7 human monitoring. Those are separate operational requirements.

## 5. Validation boundary

No proposal in this folder has been applied to production or tested against an isolated production-equivalent database. Static inspection is not a substitute for pgTAP, RLS tests, authorization tests, and two-session concurrency tests.
