# MORT Public-Production Completion Board

Tracks the public-production master run (78-section directive, 2026-08-18
onward). Status values: NOT_STARTED, IN_PROGRESS, PASS, BLOCKED_EXTERNAL.
Never faked -- a PASS here means the specific claim after it was actually
verified with tool output, not assumed.

TIMELINE: August 21, 2026 is a target, not a deadline. There is no
session time limit and no artificial stop condition. Work continues
across however many sessions it takes until every engineering-controlled
requirement below is implemented, tested, security-verified, device-
verified where possible, and documented. This board (plus
`docs/CLAUDE_DIVINE_COMPLETION_PROGRESS.md` and git history) is the
recovery mechanism if a session is interrupted -- checkpoint frequently,
never leave more than one atomic unit of work uncommitted.

LOCATION ARCHITECTURE (current, corrected 2026-08-18):
PRECISE ON-DEMAND LOCATION REQUIRED for location-dependent marketplace
functionality (both Adult job-site capture and Teen nearby-job/Quick-
Accept/navigation use). JOB SITE CAPTURED PRIVATELY via the Adult's own
precise device location at job-creation time (not free-form address
text). NAVIGATION AUTHORIZED TEMPORARILY -- only while an authorized,
active job relationship justifies it, revoked on completion/cancellation/
block/serious safety restriction. NO CONTINUOUS BACKGROUND TRACKING of
either party. NO PERSISTENT TEEN-VISIBLE EXACT ADDRESS at any stage --
Teens get distance/area/transportation pre-acceptance and turn-by-
turn-style navigation (not a copyable street address) post-authorization.
See the EXACT_LOCATION / JOB_SITE_CAPTURE / NAVIGATION rows below for
current implementation status.

| AREA | STATUS | NOTE |
|---|---|---|
| PRODUCT | IN_PROGRESS | See per-area rows below. |
| UI_UX | IN_PROGRESS | Dashboard + bottom nav done (see DASHBOARD row). Job cards redesigned: MortGlassCard, real distance, duration, full hierarchy (pay/title/category/distance/area/when/duration/transportation/trust/Quick Accept), no exact address anywhere. |
| AUTH | NOT_STARTED | Google auth (Section 14-17) not in tonight's queue. |
| GOOGLE_AUTH | NOT_STARTED | Same as above. |
| DASHBOARD | PASS | Teen Dashboard is now the primary bottom-nav destination (index 0), reusing the existing role-aware `RoleHomeScreen`, enriched with real active/upcoming-job, nearby-work-preview, and safety sections. 5 destinations total (Dashboard, Jobs, Safety, Messages, Profile), no duplicate tabs. `flutter analyze`/`format` clean, full suite green throughout. Physical smoke: fresh profile build (with all location/nav changes) installed and boots clean on the Galaxy A14, zero FATAL/crash lines, reaches Welcome screen. Deeper authenticated screens (Dashboard/Jobs feed/job creation content itself) remain HARNESS_VERIFIED only -- same standing policy against injecting real credentials via `adb shell input text`. |
| EXACT_LOCATION | PASS (backend + UI, interim navigation shipped) | Corrected architecture implemented end-to-end: Adult job-site capture takes precise GPS coordinates directly, `get_nearby_job_distances_v1` computes real server-side distance for Teens pre-acceptance (zero raw-coordinate leakage), `get_released_job_location` releases coordinates only once genuinely authorized (block-check added). 18-check live adversarial suite, 0 findings. Flutter UI: Adult "Job site" capture section, Teen job-feed real distance, and an interim "Navigate to job site" action on the active-job screen (launches the device's default maps app via the same lifecycle-gated RPC -- see `docs/MORT_NAVIGATION_SDK_RESEARCH.md`). Full in-app turn-by-turn (Google `google_navigation_flutter`, researched and recommended) deferred pending the owner's Google Cloud billing/API-key decision. Physical smoke: profile build boots clean, 0 crashes, twice this session. Authenticated-screen verification remains HARNESS_VERIFIED only (standing credential-injection policy). |
| LEADERBOARD | NOT_STARTED | Not scoped into tonight's queue. |
| QUICK_ACCEPT | PASS (backend + UI) | Both migrations applied to production, owner-authorized. Live 25-simultaneous-claimant concurrency test: exactly 1 success, 24 clean `offer_taken` denials, 0 transport errors. `QuickAcceptButton` implements the full AVAILABLE/CLAIMING/ACCEPTED/OFFER_TAKEN/NOT_ELIGIBLE/EXPIRED/NETWORK_ERROR state machine, integrated into both job feed cards and job detail. 6 widget tests, all pass. |
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

- No P0, no P1 currently open. Quick Accept's opt-in migration was
  owner-authorized and applied; the 25-simultaneous-claimant concurrency
  test passed live (exactly 1 success, 24 clean denials). The location
  architecture's backend is fully implemented and adversarially tested.
- Remaining external/owner-decision gates (not P0/P1 engineering
  blockers -- explicit product/business decisions): in-app routing/
  navigation SDK provider choice (Google Maps Platform vs Mapbox vs
  other -- pricing/ToS/API-key-security research still needed before
  picking one); AdMob account setup requiring adult publisher
  attestation; any Play/legal step requiring the owner's own identity or
  payment action.

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

Items 1-3 of the owner's "IMMEDIATE ORDER" (job cards, Quick Accept UI,
post-authorized navigation) are DONE -- see JOBS/QUICK_ACCEPT/
EXACT_LOCATION rows. Physical smoke-verified twice on the Galaxy A14
(clean boot, 0 crashes) across all changes so far.

1. **Leaderboard** (item 4): server-authoritative scoring inside
   Dashboard (not a 6th tab), safe inputs only (verified completions,
   reliability, reputation, badges -- never exact earnings/location/
   addresses), anti-cheat tests for fake completions/duplicate events/
   self-review manipulation/client-side score forging.
2. **Transportation end-to-end** (item 5): job cards already show it;
   remaining piece is Teen profile/preference-based eligibility signal.
3. **Google Login + Google Sign-Up** (item 6): Supabase Auth + Google
   OAuth + PKCE, canonical callback `com.mortapp.mobile://app/auth-callback`,
   full new/existing-user + error-state handling.
4. Then continue in order: onboarding polish, messaging, safety,
   support, profile/settings, guardian, ads/AdMob, legal/Play production,
   iOS source parity, final Android QA, final AAB/APK.
5. Owner decisions still pending (not engineering blockers): navigation
   SDK billing/API-key setup (Google Cloud), AdMob account setup.
