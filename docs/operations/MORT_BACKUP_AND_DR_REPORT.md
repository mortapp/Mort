# MORT Backup And Disaster-Recovery Status

Updated: 2026-11-01 UTC

## Verified state

| Scope | Status |
|---|---|
| Authoritative target | `mort p` / `jxbnrkasktbhtiujkhay` only |
| Production DDL or data modified | No |
| Current complete database/Auth backup | Not available |
| Current Storage object-byte backup | Not available |
| Isolated restore environment | Not available |
| Restore test | Not performed |
| Verified RPO / RTO | None established |

An older metadata snapshot in repository history targets the deleted project
`rakjydmgwwgtdislanbt`. It is historical evidence only and must not be used,
restored, or treated as a current backup. Its previous report incorrectly
described backup creation and recovery as verified; that claim is withdrawn.

The existing GitHub Actions workflow is metadata-only. The local metadata
exporter reads catalog/schema, migrations and bucket/object counts; it does not
capture table rows, Auth records, or Storage bytes. It is not a disaster-recovery
backup. The schema exporter now requires the exact approved project ref before
constructing a database client. The legacy plaintext feature-data exporter has
been retired because it targeted the deleted project and wrote user data to
unencrypted local JSON. Tests cover both safeguards.

On 2026-11-01 the metadata count query was aligned to the active production
relations (`profiles`, `guardian_links`, `jobs`, `job_applications`, and
`notifications`); it no longer queries legacy `teen_profiles`,
`guardian_connections`, or `applications`. The backup guard regression suite
passed 4/4 tests. This is code-safety evidence only: the metadata workflow has
not been run against production and is not a user-data backup. Its current
AES-256-CBC encryption step is not authenticated encryption and must be replaced
and tested before any artifact can be treated as tamper-resistant recovery
material.

## Required secure workflow

The production backup process is not runnable yet. It needs protected GitHub
environment configuration for the current production database password, a
Storage-capable service credential, a high-entropy archive encryption secret,
and an approval-gated artifact destination/retention policy. The workflow must
be amended to capture a complete PostgreSQL dump (including `auth`, `storage`
metadata, legal records, and release-control records) plus every Storage object
byte; then encrypt using authenticated encryption; verify archive and per-object
checksums; and upload only encrypted artifacts. Credentials must be supplied
through GitHub protected secrets, never repository files or command output.

Before claiming completion, restore into a separately authorized isolated
Supabase/PostgreSQL and Storage target, compare schema/migration history, table
counts, Auth counts, legal/release-control rows, bucket/object paths, byte sizes
and checksums, and record the observed elapsed time. No isolated target is
currently available. Production has no isolated QA database, and a prior
database-password attempt failed with SQLSTATE `28P01`. Do not use a production
reset, replay migrations against production, or connect to the deleted project.

## Owner setup still required

- Put a valid password for the active Supabase project into the protected
  `backend-operations` GitHub environment secret store; do not send it in chat.
- Set the exact `MORT_BACKUP_PROJECT_REF=jxbnrkasktbhtiujkhay` workflow environment
  value. Until a workflow maintainer with GitHub `workflow` scope adds it, the
  target guard will stop the metadata exporter before any database connection.
- Put a narrowly scoped service credential capable of listing/downloading all
  production Storage objects into the same protected environment.
- Create a high-entropy archive encryption secret and maintain an offline
  recovery copy under separate access control.
- Provision an isolated restore destination and its temporary credentials.
- Set environment reviewers, least-privilege repository access, artifact
  retention, and an independent encrypted offsite copy.
- Approve the backup workflow run only after code review and secret setup.
- After the first verified restore, choose operational RPO/RTO targets and name
  the restore owner/on-call coverage; those objectives are not presently proven.

No paid Supabase resource was created. No production control, legal/release
record, or user data was changed.
