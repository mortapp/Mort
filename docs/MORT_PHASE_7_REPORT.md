# MORT Phase 7 Report

Updated: 2026-07-29

## Result

Phase 7 is `100% VERIFIED` for its code-controlled closed-pilot scope. Safety
actions, active-job check-ins, optional Guardian Mode, deterministic urgent
triage, evidence preservation, and staff-alert creation are deployed and
verified remotely. Human safety staffing and physical intervention are not
claimed and remain external gates.

## Delivered

- Request-idempotent report, block, unblock, and Safety Ping RPCs.
- Separate routine and urgent safety rate limits.
- Configuration-driven US/Indiana emergency guidance with explicit no-dispatch
  language.
- Active-job check-in scheduling, completion, missed escalation, and worker.
- Optional Guardian invitation, acceptance, narrow preferences, unlinking,
  audit trail, and age-18 visibility cutoff.
- Four-band deterministic safety triage covering the Phase 7 risk categories.
- Evidence-preserving message reports and privacy-minimized staff alerts.
- Service-only `pilot_job_reviews` boundary verified at grants and RLS.
- Flutter Safety Center, urgent Support route, emergency-call action, job-linked
  check-ins, immediate Safety Ping, reporting, and blocked-account management.

## Applied Migrations

1. `20260730070000_safety_actions_checkins_and_triage.sql`
2. `20260730071000_guardian_age_audit_and_pilot_review_boundary.sql`
3. `20260730072000_support_safety_triage_bands.sql`
4. `20260730073000_default_active_job_checkin_cadence.sql`
5. `20260730074000_guardian_minor_policy_helper_execute.sql`
6. `20260730075000_contextual_weapon_triage_coverage.sql`
7. `20260730076000_fix_guardian_profile_policy_recursion.sql`

All 147 local migrations match hosted history. A final dry run reported the
remote database up to date.

## Verification

| Gate | Result |
|---|---|
| Flutter format | PASS, 185 files / 0 changed |
| Flutter analyze | PASS, no issues |
| Flutter test | PASS, 246 passed / 2 expected skips / 0 failed |
| Hosted Supabase regression | PASS, 40/40 scripts in 466.8 seconds |
| Support safety evaluation | PASS, 158/158 |
| Migration parity | PASS, 147 aligned |
| Migration dry run | PASS, remote up to date |
| Database lint | PASS with only disabled identity-provider stub parameter warnings reserved for Phase 11 |
| Source secret scan | PASS |
| Sensitive-file scan | PASS, 1,733 files / 52 known media / 10 protected values |

## Bugs Found And Fixed

1. Jobs with a null cadence scheduled no check-ins. Start confirmation now uses
   a bounded 60-minute default.
2. Authenticated Guardian policies could not execute the private minor-age
   predicate. A narrow execute grant now permits the policy helper without
   exposing DOB.
3. The profile visibility policy selected from `profiles` inside its own policy
   and triggered infinite recursion. It now uses the private age predicate
   without a self-join.
4. Context-free weapon matching missed credible active-danger phrases while
   risking benign tool false positives. Contextual rules now cover both sides.
5. Several QA clients still called retired direct report, block, or ping paths.
   They now use the same v2 RPCs as Flutter.
6. One incident-manager fixture was inserted into the wrong suite and one alert
   assertion omitted its recipient filter. Both tests were corrected.
7. A one-second signed-URL expiry test raced hosted network latency. The test
   now uses a five-second URL and verifies rejection after six seconds without
   changing production expiry policy.

## External Boundaries

- MORT does not dispatch emergency services or guarantee a human response.
- Named trained safety staff, on-call ownership, response commitments, and
  legal escalation policy remain external requirements.
- Physical Android and iPhone execution of these exact flows remains for later
  device phases.
- Public marketplace access and real identity-document collection remain
  closed.

