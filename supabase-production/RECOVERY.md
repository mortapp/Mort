# MORT P production backup and recovery runbook

**Target:** `jxbnrkasktbhtiujkhay`  
**Current plan observed:** Supabase Free  
**Status:** Runbook only. No backup was created and no restore was attempted.

## Current recovery gap

The recovered 71-file migration history in this workdir is a schema-change record, **not a data backup**. It does not contain production rows, Auth credentials, Storage object bytes, Edge Function secrets, OAuth provider settings, or Vercel secrets.

Supabase Free does not include managed daily database backups or database branching. Supabase recommends regular CLI exports and off-site backups for Free projects. A Pro subscription includes daily database backups with 7-day retention, but database backups do not include Storage object bytes; those must be backed up separately.

## Manual backup path while remaining on Free

Run this from a trusted machine with the Supabase CLI installed. Do not paste database URLs, passwords, service-role keys, OAuth secrets, or encryption keys into chat or commit them to Git.

1. Create a private backup directory outside the repository. Restrict filesystem permissions.
2. Supply the current database connection URL through a local environment variable such as `SUPABASE_DB_URL`. Keep the URL out of command history and logs.
3. Export custom roles, schema, and data separately using the Supabase CLI:

   ```powershell
   supabase --workdir supabase-production db dump --db-url $env:SUPABASE_DB_URL --role-only -f "$env:MORT_BACKUP_DIR/roles.sql"
   supabase --workdir supabase-production db dump --db-url $env:SUPABASE_DB_URL -f "$env:MORT_BACKUP_DIR/schema.sql"
   supabase --workdir supabase-production db dump --db-url $env:SUPABASE_DB_URL --data-only --use-copy -f "$env:MORT_BACKUP_DIR/data.sql"
   ```

4. Treat the CLI dump as the database portion only. Confirm which managed schemas are included by the installed CLI version. Do not assume the default dump includes Auth configuration or Storage object bytes.
5. Separately export Storage object bytes from every private bucket using the supported Storage API/S3-compatible interface. Record bucket names, object paths, content types, sizes, and checksums. The database stores Storage metadata, not the object bytes.
6. Capture non-database configuration in a separate secrets manager: Auth provider configuration and redirect allowlist, SMTP/Resend configuration, Edge Function secret names, Vercel Production variable names, DNS records, and service ownership. Store secret values only in the secrets manager.
7. Encrypt every backup artifact before transfer. Store the encryption key separately from the backup. Keep at least one encrypted copy in storage independent of Supabase and the GitHub repository.
8. Record the export timestamp, project ref, CLI version, database version, artifact sizes, and SHA-256 checksums. Alert on missing or unexpectedly empty artifacts.

## Restore drill — required before production approval

1. Restore only into a disposable isolated PostgreSQL 17/Supabase environment, never into the live project.
2. Restore roles, schema, and data in the documented order. Restore Auth data/configuration using a method verified for the current Supabase version.
3. Restore Storage buckets and object bytes separately; verify object counts and checksums.
4. Verify legal documents and acceptance records, profile/account state, RLS policies, grants, functions, triggers, extensions, and release-control rows.
5. Run pgTAP, RLS authorization, RPC contract, and two-session concurrency tests.
6. Record actual restore duration and data-loss window. Do not claim recovery readiness until a restore has succeeded.

## Paid-plan alternative

Supabase Pro currently starts at $25/month for the first project and includes daily database backups retained for 7 days. This is a billing decision for the account owner. Even on Pro, keep a separate Storage-object backup and perform a restore drill. Point-in-Time Recovery is a separate paid add-on and is not included in the $25 base plan.

## Hard safety rules

- Never write production data backups to a public GitHub repository.
- Never use the deleted Supabase project ref `rakjydmgwwgtdislanbt`.
- Never run `db reset --linked` against production.
- Never use `migration repair` or a non-dry `db push` to make migration lists look aligned.
- Do not restore over the live project without an explicit, reviewed recovery plan and owner approval.

## Official references

- [Supabase database backups](https://supabase.com/docs/guides/platform/backups)
- [Supabase automated backup workflow](https://supabase.com/docs/guides/deployment/ci/backups)
- [Supabase CLI reference](https://supabase.com/docs/reference/cli/global-flags)
- [Supabase restore guidance](https://supabase.com/docs/guides/local-development/restoring-downloaded-backup)
