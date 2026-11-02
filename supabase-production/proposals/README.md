# Production backend proposals — NOT APPLIED

These files are review candidates only. They are deliberately stored outside `../migrations/` and must not be moved into the applied chain until an isolated production-equivalent PostgreSQL 17 clone is available and the full SQL, pgTAP, and two-session concurrency suites pass.

The distance-band, safety-report moderation, and Guardian application-decision proposals were copied from `codex/mort-backend-guardian-moderation-20261101`. They have not been applied to production. The Guardian visibility proposal needs the additional direct-table privilege protection in `20261102010500_restrict_job_application_direct_select.sql`: row-level policies do not hide individual columns, and the current table-level SELECT grant otherwise exposes `guardian_id` to posters of visible applications.

Do not run these SQL files in production from the Supabase SQL editor or CLI.

## Guardian identifier response mask — stale proposal

`20261102080000_guardian_id_response_mask.sql` is stale and must not be applied. The latest read-only production inspection found that `public.get_my_job_applications(uuid)` already masks the Guardian ID and the old unmasked replacement anchor occurs zero times. Applying this file should fail its exact-source assertion. This agent made no production change.

The isolated API role matrix remains separately blocked by missing supported onboarding, legal versions, verification provider, staff authorization, and synthetic application fixtures. Current source inspection does not replace that runtime coverage.

## Current focused security proposals

- `20261102090000_verification_evidence_gate.sql`: provider-backed, case-type-matched verification evidence gate. It seeds no providers and keeps verification fail-closed until a reviewed provider integration exists.
- `20261102090100_application_pair_lock_and_verification.sql`: shared participant-pair lock during application acceptance and current teen age/school verification rechecks at eligibility and acceptance.
- `20261102090200_checkin_idempotency_lifecycle.sql`: payload-bound schedule retry keys, completion request binding, assignment/job lifecycle checks and fixed lock order.
- `MORT_BACKEND_SECURITY_REMEDIATION_BACKLOG_2026-11-02.md`: severity, exploitability, precise behavior, remediation, regression tests and prerequisites for each priority.

These files are guarded proposals, not deployed production behavior. Their source-hash guards bind them to the production definitions observed read-only on 2026-11-02. Do not apply them to production; isolated SQL compilation and concurrency tests are still required.

../../scripts/qa-guardian-id-rpc-privacy.mjs is an API-level regression harness for synthetic isolated accounts. It requires test-only credentials and fixture IDs through environment variables and refuses production or deleted-project URLs. The harness currently requires pre-provisioned isolated Auth accounts and an application fixture; those QA_* values are not configured. The workstation QA helper is wired to production and an older schema, so it cannot safely provision these fixtures for the isolated project. Direct fixture attempts hit the isolated DOB and three-track verification guards and rolled back. The harness fails closed before network access when these inputs are absent. Separate isolated RPC role-matrix execution is recorded in the MORT 2.0 execution checklist. Production still exposes the identifier and is not fixed.
