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
| QUICK_ACCEPT | IN_PROGRESS | RPC + migration written and reviewed (`quick_accept_job_v1`, `20260818200000_quick_accept_job_v1.sql`); concurrency test written (`scripts/qa-quick-accept-concurrency.mjs`). BLOCKED: migration application denied by the harness's own production-DDL auto-mode classifier -- needs the owner's explicit tool-permission action, not just chat authorization. Test cannot run until applied. |
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

- **P1** `QUICK_ACCEPT_MIGRATION_BLOCKED`: `supabase/migrations/20260818200000_quick_accept_job_v1.sql`
  cannot be applied -- denied by the Claude Code auto-mode classifier
  ("Blocked by classifier... requires explicit user authorization"). The
  file is written, reviewed, and forward-only (adds one nullable-safe
  column with a default, one new function, standard revoke/grant -- does
  not touch any existing table row or previously-applied migration). The
  owner needs to either apply it directly or grant the specific tool
  permission this session is missing. `scripts/qa-quick-accept-concurrency.mjs`
  is written and ready to run the instant it's live.
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
