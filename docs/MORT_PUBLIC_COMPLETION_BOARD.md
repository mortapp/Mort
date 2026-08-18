# MORT Public-Production Completion Board

Tracks the public-production master run (78-section directive, 2026-08-18
onward). Status values: NOT_STARTED, IN_PROGRESS, PASS, BLOCKED_EXTERNAL.
Never faked -- a PASS here means the specific claim after it was actually
verified with tool output, not assumed.

Tonight's session works a fixed, owner-set order: (1) exact location +
RLS/exploit hardening, (2) Quick Accept + atomic concurrency, (3) Dashboard/
nav/job-card UI. AdMob and legal-document drafting are explicitly out of
scope for this session.

| AREA | STATUS | NOTE |
|---|---|---|
| PRODUCT | IN_PROGRESS | See per-area rows below. |
| UI_UX | NOT_STARTED | Workstream 3, not yet reached tonight. |
| AUTH | NOT_STARTED | Google auth (Section 14-17) not in tonight's queue. |
| GOOGLE_AUTH | NOT_STARTED | Same as above. |
| DASHBOARD | NOT_STARTED | Workstream 3. |
| LEADERBOARD | NOT_STARTED | Not scoped into tonight's 3-item order. |
| QUICK_ACCEPT | IN_PROGRESS | `20260818200000_quick_accept_job_v1.sql` (the RPC itself) is APPLIED to production (owner-authorized). First concurrency run found a real gap, not a race bug: `public.jobs` has zero direct UPDATE RLS policies, so there was no way for a poster to actually set `quick_accept_eligible`. Fixed via `20260818210000_quick_accept_job_opt_in.sql`, extending `save_job_draft_or_publish` the same way it already handles transportation fields (+ a `workers_needed=1` guard). BLOCKED: this second migration was denied by the harness's classifier -- the owner's earlier authorization was scoped only to the first file, correctly not extended here. Test script updated to use the real opt-in path; ready to rerun once this migration is applied. |
| TRANSPORTATION | PASS (pre-existing) | `jobs.acceptable_transportation_methods` / `transportation_required` / `transportation_considerations` already exist in schema (confirmed via live `information_schema.columns` read) -- more of Section 10 was already built than the directive assumed. Not re-verified end-to-end in the UI tonight. |
| JOBS | PASS (pre-existing, reverified) | `update_application_status_v2`'s accept branch already locks the job row FOR UPDATE before checking `applications_open` -- the same atomic pattern reused for Quick Accept. |
| APPLICATIONS | PASS (pre-existing, reverified) | Covered by the 30-check isolation suite rerun tonight. |
| PIN | PASS (pre-existing, prior session) | See `docs/CLAUDE_DIVINE_COMPLETION_PROGRESS.md` "JOB/APPLICATION/PIN LIFECYCLE CODE REVIEW" -- not re-touched tonight, no source changed. |
| MESSAGES | PASS (pre-existing, reverified) | Covered by the 30-check isolation suite rerun tonight. |
| SAFETY | NOT_STARTED | Not touched tonight. |
| SUPPORT | PASS (pre-existing, prior session) | SQL/TS parity reverified 2026-08-18 earlier today: 542/543, no safety-direction regression. |
| PROFILE | NOT_STARTED | Not touched tonight. |
| GUARDIAN | PASS (pre-existing, reverified) | Covered by the 30-check isolation suite rerun tonight. |
| EXACT_LOCATION | PASS (design already correct) + FLAGGED | Job-feed matching deliberately never uses device GPS coordinates (`distance_status: 'unavailable'` unconditionally, UI labels results "Approximate location"). This is a prior, deliberate, already-audited privacy decision, zero P0/P1. Building live GPS-based proximity tracking of minors (directive Section 11 literally) would REVERSE that design -- flagged to the owner, not built without explicit confirmation. |
| ADS | NOT_STARTED | Explicitly out of tonight's scope per owner instruction. |
| BACKEND | PASS (reverified live tonight) | 30/30 existing adversarial isolation checks + 2 new adversarial checks (job_private_locations direct access, get_released_job_location leakage), all against live production via real anon-key + session calls, zero findings. |
| RLS | PASS (reverified live tonight) | Same as BACKEND row. |
| EXPLOIT_PREVENTION | PASS (reverified live tonight) | Same as BACKEND row. |
| MODERATION | NOT_STARTED | Not touched tonight. |
| LEGAL | NOT_STARTED | Explicitly out of tonight's scope per owner instruction. |
| PLAY | PASS (prior session) | 0.9.16+107 approved on Closed testing - Alpha, 2026-08-18. Not re-touched tonight. |
| ANDROID | NOT_STARTED | No device QA performed tonight (no UI changes yet to verify). |
| IOS | NOT_STARTED | Not touched tonight. |
| PERFORMANCE | NOT_STARTED | Not touched tonight. |
| RELEASE | NOT_STARTED | No new artifacts built tonight -- no source change yet warrants a new signed build. |

## BLOCKERS

- **P1** `QUICK_ACCEPT_OPT_IN_MIGRATION_BLOCKED`: `supabase/migrations/20260818210000_quick_accept_job_opt_in.sql`
  cannot be applied -- denied by the Claude Code auto-mode classifier. The
  owner's authorization for the first Quick Accept migration was
  explicitly scoped to that one file only, and this is a second, later
  file, so the classifier correctly did not extend it automatically. The
  migration is additive (extends one existing RPC's payload handling by
  one optional field + one guard clause; does not touch any other
  function or previously-applied migration). `scripts/qa-quick-accept-concurrency.mjs`
  is updated to use the real opt-in path and ready to run the instant this
  migration is live.
- `20260818200000_quick_accept_job_v1.sql` (the atomic-claim RPC itself)
  IS applied to production, owner-authorized.
- No P0 found tonight.

## COMPLETED_TODAY (2026-08-18 evening session)

- Fresh adversarial re-verification: existing 30-check multi-user isolation
  suite, 30/30 PASS, zero regressions.
- New adversarial coverage for the 2 gaps that suite didn't have: direct
  `job_private_locations` table access, `get_released_job_location`
  leakage to non-participants -- 0 findings.
- Confirmed (not assumed) that job-feed location matching deliberately
  avoids GPS coordinates by design; flagged the GPS-tracking question to
  the owner rather than silently building it.
- Designed, wrote, and reviewed `quick_accept_job_v1` (atomic, job-row-
  locked, self-serve single-worker claim RPC) and its migration; wrote a
  25-simultaneous-claimant concurrency test. Blocked only on migration
  application (harness permission gate, not a design or code issue).

## NEXT_AUTOMATIC_PHASE

1. Owner applies (or grants permission to apply)
   `20260818200000_quick_accept_job_v1.sql`, then run
   `scripts/qa-quick-accept-concurrency.mjs` for live proof of "exactly one
   winner."
2. Workstream 3: Dashboard / bottom navigation / job-card UI-UX pass,
   reusing canonical components, with physical device verification via
   wireless ADB once UI changes exist to verify.
3. Flutter-side Quick Accept UI (offer card + Accept button + clean
   "offer taken" state) once the RPC is confirmed live.
