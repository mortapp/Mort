# MORT Mission Pilot Advisor Report

Advisor rerun: 2026-07-19 on `rakjydmgwwgtdislanbt` after migration `20260719031115`.

## Security advisor

- ERROR: 0
- WARN: 126; 125 authenticated `SECURITY DEFINER` executable notices and one leaked-password notice
- INFO: 11 RLS-enabled/no-policy notices

Mission RPCs use an empty explicit `search_path`, derive the actor from `auth.uid()`, enforce specialized roles or self scope, and were exercised by forgery and isolation QA. Direct mission table writes are RLS constrained. The service-only vault grant exchange is not executable by authenticated or anonymous roles.

The 11 no-policy notices are deliberate deny-by-default tables: six private policy/vault tables plus public private-location/arrival state and `pilot_job_reviews`. Access is through checked RPCs or server operations.

Leaked-password protection is **DEFERRED - PLAN-LIMITED SECURITY ENHANCEMENT**. Supabase Free cannot enable the HaveIBeenPwned control. Current mitigations are strong password minimum length and complexity, auth rate limiting, email verification, RLS, account restriction logic, and secure reset. When Supabase is upgraded to Pro, enable leaked-password protection immediately and rerun Auth security advisors. No plan upgrade or spending was performed.

## Performance advisor

The first mission rerun reported 34 unindexed foreign keys, 49 unused indexes, and one overlapping permissive Support Circle policy warning. Migration `20260719030922_mission_pilot_advisor_fixes.sql` split Support Circle read/write policies and added six missing mission foreign-key indexes.

Final result: 81 INFO, zero WARN. It contains 28 older unindexed foreign-key findings and 53 unused-index findings. New indexes can appear unused immediately because there is no representative traffic; reassess only after a controlled pilot.

## Database linter

The linter initially found implicit empty-array casts in two mission functions. Migration `20260719031115_mission_pilot_lint_fixes.sql` replaced them with explicit `text[]` values, and both mission warnings disappeared. Remaining linter output belongs to older identity and message-classifier functions and is not represented as fixed by this pass.
