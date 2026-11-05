# MORT Backup And Disaster-Recovery Report

## Historical metadata snapshot

The artifact below is a historical metadata-only snapshot, not a current
production backup and not a recoverable database or Storage backup. It must not
be used as a restore source.

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

## Current backup tooling coverage

PR #69 adds an AES-256-GCM authenticated envelope, SHA-256 reporting, TLS
certificate validation, an authoritative-project target guard, an approval
environment gate, and database export code. The data export covers rows in
`public` tables and `storage.buckets`/`storage.objects` metadata. The schema
export captures selected schema, policies, grants, functions, triggers,
migrations, and bucket metadata.

This does **not** back up `auth.users` or recoverable Auth identity state,
Storage object bytes, Edge Function source/configuration, or all project/Auth
configuration. A PostgreSQL query of `storage.objects` is metadata only. The
scripts have not been run against production and no isolated restore has been
performed. No backup file from the new workflow is evidence of a successful
backup until its approved operator run succeeds and its artifact integrity is
checked.

The exporter requests POSIX directory/file modes (`0700`/`0600`). Those modes
do not establish restrictive Windows DACLs. The current scripts do not verify
Windows ACLs; on Windows, a backup destination must not be used until a
restricted external destination has been prepared and its ACL independently
checked. Key custody/rotation is operator-managed via an environment value;
the code does not integrate a KMS or prove recovery of that key.

## Recovery Status

**INCOMPLETE / NOT VERIFIED.** No new production snapshot was created, and no
restore drill has run. The current toolset is a partial encrypted export, not a
complete disaster-recovery system. Do not claim backup creation or recovery is
verified. Do not assume the current Supabase plan provides point-in-time
recovery.

## Recovery Objectives

Proposed, not contractually staffed:

| Scope | RPO | RTO |
|---|---:|---:|
| Schema/migrations/functions | Proposed 24 hours | Proposed 4 hours; untested |
| Critical configuration metadata | Incomplete coverage | Unverified |
| User and Auth data | No complete backup | Unverified |
| Storage bucket metadata | Included in partial export | Unverified |
| Storage object bytes | Not included | Unverified |
| Edge Functions and Auth configuration | Not included | Unverified |

No real users should be admitted until the owner chooses a data-backup plan,
runs a restore drill, signs the reconciliation evidence, and assigns recovery
owners.

