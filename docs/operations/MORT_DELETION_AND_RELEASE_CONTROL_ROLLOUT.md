# MORT deletion and release-control rollout

Status: HOLD. This is an approval packet, not authorization or evidence of a production change. No production database, feature control, scheduler, website deployment, or user record should be changed by a reviewer following the verification steps.

## Production preflight and order

1. The database owner verifies the migration ledger, signatures, owners, grants, RLS policies, and live definitions on `jxbnrkasktbhtiujkhay` using read-only catalog access. Compare the production and isolated QA definitions; do not deploy a schema export. Capture exact rollback definitions before any change. The known replica baseline is dated 2026-11-16, not proof of today's hosted parity.
2. The privacy and operations owners approve the data disposition matrix and exceptions below. They assign the queue owner and reviewer, confirm support fallback is staffed, validate the restore path, and verify that the production web project binds to the correct Supabase project.
3. With scheduling paused, apply the relevant reviewed prerequisites in the explicit replica order in `PENDING_PRODUCTION_APPROVAL.txt`. The deletion sequence is `20261122150000` (active staff), `20261119100000` (production queue port), `20261122151000` (lease/identity/receipt), then `20261122152000` (unapproved cascades held). Do not sort these filenames to infer dependency order. `20261122153000` is separate document-intake hardening. `20261122154000` is only the service-only support probe, not the full support rollout.
4. The backend owner stages the matching worker and independently verifies its authorization and health with the scheduler still off. Confirm the production edge gateway supports the chosen service authorization and the separate `x-mort-deletion-secret` binding. Do not reuse a browser credential or log either secret. In disposable QA, verify GoTrue identity and refresh-token absence and Storage byte absence before using its completed result as evidence.
5. The Auth/email owner checks the actual hosted callback allowlist for `https://mortapp.org/account-deletion/confirm`, same-origin PKCE exchange, confirmation requirement, SMTP delivery and anti-enumeration controls. Verify MFA and OAuth-only accounts used by MORT. Verify magic-link success, expiration, reuse rejection, wrong browser/no verifier, and password sign-in. Receipt codes must remain out of URLs, referrers, and telemetry.
6. The release owner approves a limited production window separately. Enable a single monitored scheduler only after the worker, private Auth/Storage credentials, alert routing and staff retention handoff are verified. Then deploy the exact reviewed web revision and check the canonical URL and linked routes. Verify mobile in-app initiation on both release candidates before relying on either store declaration.

## Scheduler design and rollback

- Proposed scheduler: start with one authenticated invocation about every two minutes, request body `{}`, at most one eligible claim per invocation. A 100-second app deadline and per-call network timeouts are not a substitute for the database lease. Confirm actual runtime timeout, retry and backoff behavior and measure throughput on QA. Multiple requests may be queued; alert on repeated authorization/provider errors, failed or expired leases, backlog age, and unmanned retention review. Log correlation ID and outcome only; omit user data, receipt secrets, or raw provider payloads.
- Functional gate: in staging, observe grace period/cancellation, repeated invocations, stale lease rejection, ambiguous provider result, retry, held records, and idempotent completion. A health check or successfully accepting a job does not prove completion. Correlate Auth `user_not_found`, refresh denial, object GET failure and terminal receipt for the same controlled fixture.
- Incident response: pause scheduling and stop new intake first while preserving existing status/receipts. Do not downgrade to an earlier worker that can mark an unconfirmed identity absent. Reconcile each in-flight request and its lease/retention/byte-deletion state before resuming with a reviewed forward fix. Never drop queue state or attempt to re-create an already deleted identity. If a migration fails before activation, stop and use the captured pre-change definitions and owner-approved reversal, preserving all rows and existing evidence. For `20261122153000`, retain the fail-closed guard while on HOLD unless an independently reviewed equivalent block is active; reverting the guard alone reopens writes.

## Data disposition gates

| Records | Safe default while no written retention approval exists |
| --- | --- |
| Auth, sessions and user-owned private Storage | Delete only after authority, retention checks and lease validation. Confirm the identity and bytes are absent independently. |
| Guardian relationships and household settings | Revoke active access immediately as applicable. Review which legal/consent proof must remain; never preserve a live link for convenience. |
| Messages, jobs, applications and check-ins | Preserve any held investigation evidence. Approve row-by-row deidentification and assess other participants' access and audit value. |
| Reports, moderation evidence, disputes and safety records | Hold for the authorized privacy/safety decision. Specify purpose, access control, review date, and expiry. |
| Financial records, subscriptions and provider-held data | Finance and counsel must confirm retention, required reconciliation, lawful provider deletion and what is outside MORT's direct control. No production billing is authorized. |

## HOLD release-control recommendations

This assessment uses the recovered catalog and versioned schema. Reconfirm against the hosted catalog before any write.

| Control | Recorded | Recommendation and reason |
| --- | --- | --- |
| `public_marketplace_enabled` | `true` | Set `false` after approval. `list_open_jobs_page`, `get_job_application_eligibility`, `manage_job_v2` and `save_job_draft_or_publish` use the switch for discovery, eligibility or publication; account/role gates are still required. Verify already published jobs, alternate team-hustle paths and public feeds separately before relying on it. |
| `real_document_collection` | `true` | Set `false` after approval and apply a verified server-side intake guard. `get_first_party_trust_status` and `get_runtime_feature_status` advertise the setting, whereas the recovered Storage insert policy and submission implementation do not enforce it. A flag change alone is not containment. Check service-role paths independently. |
| `maintenance_mode` | `false` | Keep `false` as the normal hold posture if targeted holds demonstrably close marketplace publication and document intake, so that recovery, deletion, support and safety can stay available. If alternate paths cannot be contained, consider a time-boxed `true` only after the operations owner verifies essential paths remain available. Maintenance is not a substitute for RLS or case authorization. |
