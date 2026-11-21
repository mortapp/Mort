# Production-baseline-only migrations

SQL in this directory targets the recovered production migration baseline. It is intentionally outside `supabase/migrations`, which is the separate generic/local chain used by the Stripe and application regression suite.

`20261104182914_issue_70_guardian_application_reader_scope.sql` depends on the exact production `get_my_job_applications(uuid)` definition introduced in production migration `20261028034447_flutter_application_backend_contract`. The archived source is SHA-256 verified by `supabase-production/migration-history.json` in pinned archive commit `05325088dcbb117e5d144828bc613fef5b47777f`.

The baseline archive's SQL file for `20261102040639_restrict_job_application_direct_select` does not match its manifest hash. A read-only query of the production migration ledger recovered its exact `statements` payload: its MD5 is `806bed46eb996e0fed98e87ea9a03f3c`, and the recovered source SHA-256 `d816da845f1c71643a0d577b9629b98b3e8db9c0ed4c3667e8a4e7db7a60cf6d` matches the original manifest. The mismatched archived file and manifest remain untouched. A provenance record and recovered source are in `supabase/production-baseline-recovery/`; the test runner uses the recovered payload only for that version.

Run `scripts/run-issue-70-production-baseline.ps1` to construct a disposable local PostgreSQL baseline from those 73 source migrations, verify every source hash, run a clean migration replay, and then run the focused 33-assertion rollback-only test. The existing `scripts/run-mort-stripe-regression.ps1` CI path invokes this baseline before starting its generic local stack, avoiding port conflicts and keeping the divergent migration chains isolated. It requires Docker. The runner uses no hosted database credentials and never connects to Supabase production or hosted QA. Authenticated PostgREST sessions are not covered by this SQL regression.

Do not move these files into the generic migration chain or apply them to a hosted database without independent review and explicit deployment approval.


## Production message safety and Realtime — 2026-11-14

The launch migrations are recorded in order:
- `20261114160000_message_safety_scanner_launch.sql`
- `20261114160100_message_safety_normalization_and_moderation_queue.sql`
- `20261114160200_message_safety_private_rls.sql`
- `20261114160300_publish_messaging_realtime.sql`

These migrations were applied to the authoritative production Supabase project on 2026-11-14 and verified against the live catalog. The isolated regression contracts are in `supabase/production-baseline-tests/message_safety_scanner.test.sql` and `message_safety_normalization.test.sql`. Keep these files in the production-baseline chain; do not move them into the generic local migration chain.

- `20261114160400_message_notifications_and_preferences.sql`
- `20261114160500_expand_message_safety_rules.sql`

The notification migration adds the message-recipient notification trigger, the preference RPC contract used by Flutter, and an explicit disabled/unverified remote-push status. Approved messages create generic in-app notifications only for active conversation participants who have message notifications enabled; held or blocked messages do not notify recipients. The Flutter notification repository now queries the production `notifications.user_id` column. The safety expansion adds high-confidence threat, coercion, sensitive-information, exact-address, payment-pressure, and harassment rules.

- `20261114160600_harden_additional_message_safety_patterns.sql` — corrects regex boundary handling for PII requests, payment pressure, and harassment.

## Chat attachment authorization and private-table deny-all — 2026-11-14 (relocated 2026-11-14)

- `20261114170000_chat_attachment_authorization.sql`
- `20261114171000_private_tables_explicit_deny_all.sql`

These were originally merged into `supabase/migrations/` by #100. That placement broke the generic local chain: both files reference objects that exist only in the production baseline (for example `private.is_active_user()`, `public.conversation_members`, and the private tables that were never part of the generic chain), so `supabase db reset` failed with `function private.is_active_user() does not exist` and the `stripe-local-regression` CI job failed on every pull request.

They are production-baseline changes — the chat-attachment storage policies and the private-table deny-all policies are live in production — and are now recorded here per the convention above. Do not move them back into the generic migration chain.

## Onboarding activation and staff review boundaries — 2026-11-16 (NOT applied to production)

- `20261116120000_onboarding_activation_and_staff_review_boundaries.sql`

Pending explicit production approval (listed in `PENDING_PRODUCTION_APPROVAL.txt`). Fixes defects reproduced through the public API on the local production replica (`scripts/qa/replica/build-and-test.sh`): pending teens could not skip guardian setup; staff activation did not require completed onboarding or current legal acceptance; guardians could never be activated (so `accept_guardian_invite` was unreachable); `profiles.guardian_setup_status` was client-writable; staff could review their own verification evidence and role requests. Each function is the exact live production body plus a minimal change. Rollback: re-apply the previous bodies from `supabase/production-baseline-recovery/` (ledger + 2026-11-12 baseline), restore `grant update (guardian_setup_status) on public.profiles to authenticated`, and restore the two-value `role_requests_requested_role_check` (only after confirming no `guardian` role requests exist).


## Job execution verification-state gate — 2026-11-21 (NOT applied to production)

- `20261121170000_job_execution_gate_accepts_verified_status.sql` restores the exact production `private.job_execution_gate(uuid,text)` definition to the production-baseline migration chain. The function depends on `public.job_assignments` and other recovered production objects that are deliberately absent from the generic `supabase/migrations` chain.
- It accepts the reviewer-written `verified` state and legacy `approved` for both participants, rejects NULL/other states, preserves every existing execution, contract, safety, incident, dispute, start-window, and funding check, and retains the owner-only SECURITY DEFINER ACL.
- The migration is listed in `PENDING_PRODUCTION_APPROVAL.txt` so the isolated production-replica runner applies it after catalog parity. This is test-only; production deployment still requires separate approval.
- Regression contract: `supabase/production-baseline-tests/job_execution_gate_verified_status.test.sql`.
- Deployment preflight: verify the exact project identity independently and compare the installed `pg_proc.prosrc` SHA-256 (using `encode(sha256(convert_to(prosrc, 'UTF8')), 'hex')`) with the approved-only preimage `1c6cf0fc9b8eaf072cbe54e9f2e37be75b3342128d879a2b01f669fd025ce30a`. Verify owner `postgres`, `STABLE SECURITY DEFINER`, `search_path=""`, and ACL `{postgres=X/postgres}`. Stop on any drift. After explicit production authorization, apply only this SQL file in one transaction and verify the new body SHA-256 `99e3d5aa07796bc230ae672b7a5ba86f072359ad6e5e1c0e7ab9484f9e204cac`, the same security metadata, and the actual recorded migration-ledger entry. Do not apply the entire pending list to production.
- Recovery: `supabase/production-baseline-recovery/20261121170000_job_execution_gate.rollback.sql` is a manually invoked, fail-closed rollback. If separately authorized, execute it transactionally against the independently confirmed project and verify the preimage and ACL after commit. It restores the prior approved-only behavior (including its limitation for verified accounts) and does not remove migration history or change payment controls. The replica runner rehearses forward, regression, rollback, and reapplication before its API tests.

## MORT password guard rollout (not applied to production)

- `20261121200000_password_guard_signup_quota_stage.sql` prepares the service-only signup quota without changing Auth password writes.
- `20261121200100_server_enforced_password_attestation.sql` is a separate activation migration. Do not apply it until the staged Flutter client, legacy compatibility and hosted QA are verified and the owner separately authorizes production enforcement. Both files are listed for the disposable replica, not as a production batch.
- The earlier QA migration remains historic; these use new versions. See [the phased Flutter rollout](../../docs/security/PASSWORD_PROTECTION_2026-11-16.md) for mode transitions, prerequisites and rollback order.
