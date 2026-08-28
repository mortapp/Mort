# MORT Feature Expansion Backup Report

Backup date: 2026-07-17

Remote project: `rakjydmgwwgtdislanbt`

## Pre-Change Backups

Before migration `20260717082454_feature_expansion_unread_proof_review.sql` was applied, two secret-free local backup manifests were created in `C:\Users\micha\Mort\backups`. The backup directory is intentionally excluded from every deliverable archive.

| Backup | Result |
| --- | --- |
| Schema, migration, policy, function, and storage metadata | `remote-feature-schema-rakjydmgwwgtdislanbt-2026-07-17T08-23-15-860Z.json`, 884,415 bytes; 74 relations, 142 policies, 75 functions, and 39 applied migrations captured |
| Public and storage data | `remote-feature-data-rakjydmgwwgtdislanbt-2026-07-17T08-24-40-280Z.json`, 317,602 bytes; 64 tables and 661 rows captured, including storage bucket/object rows |
| Data-backup SHA-256 | `62102991B28F0D5152C84E2CD46E4394562197717C7FC0AF41C5EC7F7037050E` |

## Tooling Result

The standard Supabase CLI database dump route could not run because the local Docker daemon was unavailable. No successful CLI dump was claimed, and zero-byte failed dump files were removed. `scripts/backup-feature-schema.mjs` and `scripts/backup-feature-data.mjs` then completed read-only PostgreSQL backups using current environment credentials without printing or persisting secrets.

## Change Safety

- No table was dropped or truncated.
- No existing migration history was rewritten.
- The new migration was preflighted in remote transactions that rolled back before the actual apply.
- QA used isolated accounts and removed those users and private proof objects after completion.
- Backups contain remote data and must stay access-controlled, outside source archives, and outside public version control.

This is a recovery aid, not a substitute for managed point-in-time recovery or a tested restore procedure.

## Pre-Index Refresh

Before the follow-up foreign-key index migration, the backup was refreshed:

- Schema snapshot: `remote-feature-schema-rakjydmgwwgtdislanbt-2026-07-17T09-22-27-619Z.json`; 75 relations, 143 policies, 81 functions, 40 migrations.
- Data snapshot: `remote-feature-data-rakjydmgwwgtdislanbt-2026-07-17T09-22-29-687Z.json`; 65 tables, 665 rows; SHA-256 `DC77B6F21E23874ADFB2980E02059103D2395EA5A65251692CC5FDF2FC31BE40`.

Migration `20260717092233_feature_expansion_proof_review_fk_index.sql` was then dry-run, applied, and aligned remotely. The advisor no longer reports `proof_uploads_reviewed_by_fkey` as unindexed.
