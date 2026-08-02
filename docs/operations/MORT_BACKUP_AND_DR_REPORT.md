# MORT Backup And Disaster-Recovery Report

## Current Backup

| Item | Result |
|---|---|
| Project | `rakjydmgwwgtdislanbt` |
| Snapshot UTC | `2026-08-02T02:16:44.328Z` |
| File | `backups/remote-feature-schema-rakjydmgwwgtdislanbt-2026-08-02T02-16-44-328Z.json` |
| User rows | Excluded |
| Relations | 302 |
| Policies | 296 |
| Functions | 545 |
| Migrations | 158 |
| Storage | Nine private buckets; aggregate object counts only |

The snapshot includes schema metadata, grants, policy/function definitions,
migration history, bucket configuration, and aggregate counts. It does not
contain Auth records, user row contents, object paths, object contents, service
keys, database passwords, access tokens, or provider secrets.

## Automation

`.github/workflows/mort-backup-metadata.yml` creates the same metadata-only
snapshot, adds migration/function/config source, encrypts the archive with
AES-256-CBC/PBKDF2, hashes it, and uploads only the encrypted artifact. It is
approval-gated by the `backend-operations` environment. Repository owners must
configure retention, environment reviewers, passphrase rotation, and an
independent encrypted offsite copy.

## Recovery Status

Backup creation is `100% VERIFIED`. A real restore is
`CODE-COMPLETE / MANUAL VERIFICATION REQUIRED`: no restore was executed because
that requires owner approval and an isolated nonproduction target. The current
Supabase Free plan must not be assumed to provide point-in-time recovery.

## Recovery Objectives

Proposed, not contractually staffed:

| Scope | RPO | RTO |
|---|---:|---:|
| Schema/migrations/functions | 24 hours | 4 hours |
| Critical configuration metadata | 24 hours | 4 hours |
| User data | Depends on approved Supabase backup plan | Depends on approved Supabase backup plan |
| Storage objects | Depends on approved object backup process | Depends on volume and provider restore |

No real users should be admitted until the owner chooses a data-backup plan,
runs a restore drill, signs the reconciliation evidence, and assigns recovery
owners.

