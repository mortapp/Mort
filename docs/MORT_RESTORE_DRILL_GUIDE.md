# MORT Restore Drill Guide

This is a preparation guide. No restore drill was performed in the 0.9.4 sprint.

## Preconditions

1. Obtain written owner approval and select an isolated nonproduction Supabase
   project. Never overwrite the active project for a drill.
2. Confirm the backup timestamp, checksum, Supabase/Postgres version, migration
   head, Storage inventory, Auth handling plan, and retention authorization.
3. Keep service-role, access-token, database-password, signing, and provider
   secrets in approved server/operator secret storage only.
4. Set maintenance mode, payments disabled, AI disabled, publishing disabled,
   and public marketplace closed in the drill environment.

## Procedure

1. Record drill ID, operators, approvals, source backup checksum, and target ref.
2. Restore schema/data using the approved Supabase recovery method for the plan.
3. Apply only migrations later than the backup after reviewing order and hashes.
4. Recreate private buckets and policies from migration-controlled definitions.
5. Deploy Edge Functions without enabling provider operations.
6. Set target-specific server secrets; never reuse or print production secrets.
7. Validate migration parity and run schema error lint.
8. Run 30-check multi-user isolation, Storage isolation, moderation authorization,
   account deletion, runtime controls, rate limits, and send-push auth smoke.
9. Compare aggregate row counts and sampled non-sensitive state. Do not open raw
   teen evidence merely to prove a restore.
10. Verify all emergency controls remain fail closed, then destroy or lock the
    drill environment under the approved retention decision.

## Acceptance evidence

- restore start/end time and recovery-time objective result
- source and target checksums where supported
- migration list and schema-lint result
- private bucket configuration and policy count
- QA script names and real pass/fail output
- row-count reconciliation with no user identifiers
- incident log for every deviation
- signed owner, security, privacy, and data-owner review

## Abort conditions

Abort immediately for wrong project ref, missing approval, checksum mismatch,
unexpected live provider mode, public bucket exposure, real-user email/SMS/push,
secret output, migration divergence, or evidence-access uncertainty. Preserve
logs, keep the marketplace closed, and escalate through the incident runbook.
