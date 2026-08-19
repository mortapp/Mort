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
| UI_UX | IN_PROGRESS | Dashboard + bottom nav done (see DASHBOARD row). Job-card redesign not started. |
| AUTH | NOT_STARTED | Google auth (Section 14-17) not in tonight's queue. |
| GOOGLE_AUTH | NOT_STARTED | Same as above. |
| DASHBOARD | PASS | Teen Dashboard is now the primary bottom-nav destination (index 0), reusing the existing role-aware `RoleHomeScreen`, enriched with real active/upcoming-job, nearby-work-preview, and safety sections. 5 destinations total (Dashboard, Jobs, Safety, Messages, Profile), no duplicate tabs. `flutter analyze`/`format` clean, full suite 379/0/2 unchanged. Physical device verification pending (wireless ADB unreachable this session). |
| EXACT_LOCATION | PASS (client) / BLOCKED_EXTERNAL (backend) | Client-side on-demand precise-location service + UI gate built and fully tested (13 new tests: granted/approximate-only/denied/permanently-denied/services-disabled/timeout/stale/error/retry/settings). Backend distance/matching genuinely blocked: `job_private_locations` stores addresses as raw text, no coordinates anywhere in the schema -- real distance computation needs a geocoding provider (external API, cost, privacy review), a product/vendor decision, not engineering. Not built with a crude shortcut. |
| LEADERBOARD | NOT_STARTED | Not scoped into tonight's queue. |
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
  suite, 30/30 PASS, zero regressions. Plus 2 new adversarial checks
  (`job_private_locations` direct access, `get_released_job_location`
  leakage to non-participants) -- 0 findings.
- `quick_accept_job_v1` (atomic, job-row-locked, self-serve single-worker
  claim RPC) applied to production, owner-authorized. First concurrency
  run surfaced a real gap (jobs has zero UPDATE RLS policies -- no way to
  set the opt-in column); fixed via a second migration extending
  `save_job_draft_or_publish`, currently pending the owner's apply action.
- Dashboard made the primary Teen bottom-nav destination, reusing the
  existing `RoleHomeScreen`, enriched with real active-job/nearby-work/
  safety sections. 5-destination nav (Dashboard, Jobs, Safety, Messages,
  Profile), no duplicate tabs. Found and fixed one genuine pre-existing
  test coupling this surfaced (verified as real, not a flake, by isolating
  the one-line change). Full suite green throughout.
- Precise on-demand location: full client-side service + UI gate built,
  13 new tests covering every requested scenario. Backend distance/
  matching found to be genuinely blocked on a real architectural gap (no
  coordinates anywhere in the schema -- needs a geocoding provider, a
  product/vendor decision) rather than built with a shortcut.

## NEXT_AUTOMATIC_PHASE

1. Owner applies (or grants permission to apply)
   `20260818210000_quick_accept_job_opt_in.sql`, then run
   `scripts/qa-quick-accept-concurrency.mjs` for live proof of "exactly one
   winner."
2. Owner decision needed on backend distance/matching: which geocoding
   provider (cost + privacy review of sending job addresses to a third
   party), before that piece can be built at all.
3. Job-card redesign (pay/distance/transportation/poster-trust hierarchy),
   reusing canonical components.
4. Physical device verification of tonight's Dashboard/nav changes via
   wireless ADB (unreachable both attempts this session -- retry).
5. Flutter-side Quick Accept UI (offer card + Accept button + clean
   "offer taken" state) once the RPC's opt-in path is confirmed live.
