# Old Project Backup Report

Project ref: `rakjydmgwwgtdislanbt`

Backup timestamp: `20260708-094033`

Backup folder:

```text
backups/supabase-rakjydmgwwgtdislanbt-20260708-094033/
```

## Files Created

- `BACKUP_TIMESTAMP.txt`
- `remote_schema.sql`
- `remote_roles.sql`
- `remote_data_public_storage.sql`
- `remote_migration_history.txt`
- `remote_audit_query.sql`
- `remote_audit_snapshot.txt`

## What Was Backed Up

- Remote schema dump through `supabase db dump --linked`
- Remote role dump through `supabase db dump --linked --role-only`
- Remote public/storage data dump through `supabase db dump --linked --data-only --use-copy --schema public,storage`
- Remote migration history through `supabase migration list --linked`
- Remote table/function/trigger/policy/storage bucket catalog through `supabase db query --linked`

## What Was Not Backed Up

- Auth user secrets/passwords were not exported.
- Storage object binary contents were not downloaded.
- Supabase internal service configuration was not exported.

## Warning

The old-project rebuild is destructive-risk work. It can delete or replace old public schema objects, policies, migration history, and app-owned data in `rakjydmgwwgtdislanbt`.

Raw dump files may contain old project data. They must not be committed, placed in the final zip, or shared publicly.

## Rebuild Result

The rebuild completed after this backup. See `docs/OLD_PROJECT_REBUILD_REPORT.md` for the remote schema, storage, Edge Function, QA seed, smoke, RLS, Expo check, and remaining launch-gate results.
