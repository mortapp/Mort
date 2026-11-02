# MORT Backend, Recovery, and Website Verification

Updated: 2026-11-01 UTC  
Production Supabase project: `jxbnrkasktbhtiujkhay`  
Production website: `https://mortapp.org`

This is an evidence report from read-only production inspection. The SQL files in this branch are proposals; none were applied to production.

## Production backend findings

- Production has **71 recorded migrations**. The latest applied migrations are `20261102003713_atomic_application_and_guardian_resend_contract` and `20261102003741_private_location_and_block_message_contract`.
- Atomic application submission and Guardian resend contracts are present in production. Both the public submission wrapper and its lower-level insertion function lock the job row. This still needs a production-equivalent concurrency test before it is treated as fully verified.
- Private job-location release is present through `get_released_job_location`. The function uses the block-pair lock and checks the application/assignment/safety-agreement release conditions.
- `block_user_v2` and `send_safe_message_v2` both use the canonical advisory pair lock. The two-session race test has not been run against an isolated production-schema clone.
- **Server-side distance is still absent from production.** The candidate distance-band migration is on the parent proposal branch, not applied to production.
- **Guardian application decisions are absent from production.** The current acceptance path checks for an active Guardian link; it does not record an approval/rejection. The saved `guardian_preferences.optional_job_approval_enabled` value is not wired into the application eligibility/submission path. The public safety page therefore overstates the current approval workflow until the proposal is validated and integrated.
- Safety-report submission is server-only and idempotent. **Staff moderation/triage/assignment/resolution RPC is absent from production.**

## Proposed backend changes in this branch

1. `20261102010200_safety_report_moderation_rpc.sql`
   - Adds staff-only triage, investigate, assign/unassign, resolve, dismiss, and reopen actions.
   - Requires an active admin/moderator, validates new assignees against active staff roles, uses an expected-`updated_at` guard, and writes an audit event for every successful action.
   - Includes a pgTAP integration test and a static source-contract test.

2. `20261102010300_guardian_application_decision_schema_rpc.sql`
   - Adds a separate Guardian decision state, a private immutable decision-event table, and an authenticated Guardian decision RPC.
   - Requires an active, adult (18+), email-confirmed Guardian with an active, dual-consented link.
   - Guardian revocation invalidates prior decisions and returns still-open applications to pending.

3. `20261102010400_guardian_application_visibility_contract.sql`
   - Wires the teen's optional Guardian approval preference and job-level approval requirement into eligibility and submission.
   - Hides pending/rejected applications from posters through both the application reader and RLS; poster acceptance requires a real approval and a still-active approving Guardian link.
   - Keeps Guardian identity and rejection reason out of the poster's application payload.
   - Serializes preference changes against application eligibility to avoid an opt-in race.

The new migrations are deliberately not applied. The migration patch fragments were checked against the live production function definitions and all expected fragments were found. Static contract checks passed **26/26**. The Node test suite and pgTAP integration test have not been run against a database clone. Do not merge/apply until the repository migration-history reconciliation and isolated database validation are complete.

## Security advisor and RLS review

Latest Supabase security advisor results:

- 51 authenticated-executable `SECURITY DEFINER` function findings. These require routine-by-routine review; blanket revocation would break legitimate server-side workflows.
- 1 anonymous-executable `SECURITY DEFINER` finding: `get_runtime_feature_status`. Its current return payload contains public runtime/release booleans and a maintenance message, not user records, credentials, or private evidence. Keep it only if the public status contract is intentional.
- 23 RLS-enabled/no-policy findings: 20 are in the non-exposed `private` schema; the other 3 are public tables (`job_safety_cancellations`, `legal_acceptance_audit_events`, `legal_role_requirements`) with no anon/authenticated SELECT, INSERT, or UPDATE grants. These are default-deny, not evidence of public table access.
- Leaked-password protection is disabled in Supabase Auth. The available Supabase connector exposes no Auth security-settings update action, so this remains a dashboard-level action.

No broad permission revocations or production security-setting changes were made.

## Backup and disaster recovery

The current backup report remains a **NO-GO** for recovery:

- No complete current database/Auth backup.
- No Storage object-byte backup.
- No isolated restore destination.
- No restore test and no measured RPO/RTO.
- The scheduled GitHub workflow is metadata-only; it is not a data backup. The current workflow uses AES-256-CBC, and the proposed AES-GCM workflow change is not remotely committed because the connected GitHub app lacks the required workflow scope.
- The active Supabase organization/project is on the Free plan; automatic daily backups and Supabase branching are unavailable.

To complete recovery, the owner must configure protected GitHub environment secrets for the active project's database password, a narrowly scoped Storage export credential, and a high-entropy archive-encryption secret; provision an isolated restore target; then run a full encrypted database/Auth/Storage backup and independently verify a restore. Never use the deleted project ref `rakjydmgwwgtdislanbt`.

## Production website verification

The current `mortapp.org` production deployment is recorded as READY. Direct production-route checks returned HTTP 200 for:

- `/`
- `/safety`
- `/login`
- `/signup`
- `/legal/terms`
- `/legal/privacy`
- `/legal/safety`

This verifies route delivery, not successful signup, OAuth, form submission, or every authenticated user flow. Those require controlled end-to-end testing.

A separate website branch, `codex/mort-website-verification-20261101`, removes the unsupported claim that Guardians can currently approve applications before posters see them. It has not been deployed. The separate `legal.mortapp.org` host was not changed.

## Change boundary

No production database writes, migration applications, Auth setting changes, backup jobs, DNS changes, Vercel deployments, release-control changes, marketplace activation, or payment activation were performed.
