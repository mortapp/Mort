# MORT Disaster-Recovery Runbook

**Status:** Planning and tooling review only. A full backup and restore have **not** been demonstrated. This document does not authorize a production backup export or a restore.

## Current evidence and limits

- Production Postgres is `17.11.0.003`; production migration ledger contains 73 rows through `20261102113314`.
- Isolated QA Postgres is `17.11.0.011`; current read-only aggregate counts are zero for Auth users, profiles, Guardian links, jobs, applications, and Storage objects. It is not evidence of a production restore.
- PR [#69](https://github.com/mortapp/Mort/pull/69) adds encrypted feature data/schema snapshot tooling with path, approval, and encryption-key guards. Its own scope states that it excludes Auth internals and Storage object bytes; no backup was run and no restore was performed.
- Current code/tests establish snapshot-envelope properties, not database recovery. Do not describe the project as recoverable until this drill passes.
- Existing legacy operation notes on the default branch need reconciliation with PR #69 before being used; do not use stale target or stale signing instructions.

## Required approvals before a full-content drill

1. Written release-owner approval identifying source, target, operator, allowed record categories, retention, and destruction date.
2. Legal/privacy approval for copying any teen personal data, Auth identities, private messages, verification evidence, or object contents. If this is not approved, use synthetic fixtures and mark the full-data restore unproven.
3. An isolated nonproduction target with explicit billing approval if needed. Preserve existing QA data; never reset/rebase/delete it to make the test easier.
4. Provider-supported export/restore method and authorized access to backup/restore controls. Never export or place service-role keys, passwords, or signing material in the archive.
5. A separate secure path for target-only secrets; preserve references and rotation instructions, not secret values.

## Backup acceptance scope

Record a signed manifest and encrypted checksums for each authorized component:

| Component | Required coverage and verification |
|---|---|
| Database | Full required schema and data, extension/config prerequisites, migration ledger, views, functions, triggers, grants, policies, and sequences. Record source project/version and snapshot time. |
| Auth | Provider-supported Auth users and identity metadata needed for recovery. Preserve password hashes only through supported provider backup; never export plaintext credentials or active session tokens. Record counts only in the report. |
| Storage metadata | Buckets, visibility, policies, object metadata, MIME types, and relationships. |
| Storage bytes | Every approved object byte stream with object key, size, MIME type, and cryptographic checksum. Metadata counts alone are insufficient. |
| Configuration | Auth URL/redirect settings, OAuth client references, SMTP sender settings, Edge Function names/versions, nonsecret release-control values, Vercel project/environment scopes, and secret names/owners. Store secret values only in provider secret stores. |
| Legal/release controls | Preserve legal version identifiers, consent records, moderation/audit records, and release-control state. Validate before and after restoration. |

The PR #69 encrypted feature snapshot is not a substitute for this coverage.

## Controlled restore sequence

1. Record approvals, source snapshot hash, source migration head, PostgreSQL version, backup time, target project identity, operator, and a no-production-write assertion.
2. Confirm the isolated target is not production and is not the deleted project. Capture its current schema/count fingerprint. Do not reset it.
3. If target is not empty, stop and obtain a separate preservation/reconciliation plan. Do not overwrite existing QA work.
4. Restore database schema/data using provider-supported tooling into an isolated target; restore only reviewed migrations newer than the snapshot if needed. Never rewrite ledger history to fit the restore.
5. Restore Auth data with provider-supported tooling only after legal approval. Test sessions, email confirmation, recovery, and role linkage with approved synthetic accounts; revoke any imported sessions that must not survive.
6. Recreate Storage buckets and policies, restore bytes, verify checksums, and prove authorized read/write plus cross-user denial.
7. Configure only target-scoped secrets through the provider vault. Keep marketplace, document collection, payments, and Stripe disabled.
8. Run migration parity, RLS/pgTAP, RPC authorization, role isolation, Storage authorization, account deletion, and app/website API smoke tests.
9. Compare approved aggregate table counts, Auth counts, bucket/object counts, foreign-key/relationship checks, legal records, migration head, and sampled object checksums. Do not open private teen content to validate it.
10. Measure restore duration and the recovered snapshot age as observed RTO/RPO. Do not invent service commitments.
11. Record all differences and obtain owner sign-off. Keep the isolated target available for review or destroy it only through a separately approved action.

## Rollback and abort conditions

- Never run a restore against production as an experiment.
- Abort on unexpected target identity, existing QA data without an approved preservation plan, checksum mismatch, missing approval, public bucket/policy, live provider/payment control, untracked migration, secret in output/archive, unexplained count divergence, or real-user notification.
- For failed isolated restore, stop clients, preserve logs and evidence, and do not attempt a second destructive restore on the same target. Design a separate disposable target after review.
- A rollback of production schema is not a blind down migration. Close the feature, preserve evidence, make an additive reviewed repair, then use a separately approved change window.

## Current disposition

**BLOCKED:** complete DB/Auth/Storage backup, isolated full restore, legal/data-copy approval, and measured recovery objectives are absent. The current QA project's zero aggregate rows make authenticated restore acceptance impossible today.
