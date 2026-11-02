# MORT P production migration workdir

**Authoritative project:** `jxbnrkasktbhtiujkhay`  
**Postgres:** 17  
**Export date:** 2026-11-01  
**Export method:** read-only reconstruction from `supabase_migrations.schema_migrations` in the active production database.

## Recovered history

This directory contains the exact SQL statements recorded by the active production database for all **71 applied migrations**. Every migration row had a non-empty SQL statement array; each currently contains one statement. The reconstructed files are named `<version>_<name>.sql`. `migration-history.json` records the source version, name, and SHA-256 of each SQL payload.

No production SQL, data, Auth settings, Storage objects, release controls, or deployment settings were changed during this export. The SQL was scanned for common live Stripe/webhook secret markers, JWT-like literals, and password literals; none were found.

## Which migration directory to use

The repository's root `supabase/migrations` directory is a legacy migration chain and does **not** match the current MORT P production history. Do not link that workdir to the current production project or use it for production `db push` operations.

Use this dedicated workdir for migration-history checks:

```powershell
supabase --workdir supabase-production link --project-ref jxbnrkasktbhtiujkhay
supabase --workdir supabase-production migration list --linked
supabase --workdir supabase-production db push --linked --dry-run
```

The link command writes local CLI state under `.temp/`; do not commit that state or credentials.

## Strict safety gate

The three commands above are for local linking and read-only migration inspection, except the final command is explicitly dry-run. **Do not run a non-dry `db push`, `migration repair`, `db reset`, `config push`, or any hosted migration mutation** until all 71 versions show as applied, the 71-file chain has been replayed successfully against an isolated production-equivalent PostgreSQL 17 database, the security and concurrency suites pass, and the owner approves the exact change set.

Supabase's CLI compares migration timestamps between the local migration folder and the remote history table. A matching list does not by itself prove the SQL files are identical; use the SHA-256 manifest as an additional integrity check. The proposal files under `proposals/` are intentionally outside `migrations/` so they cannot be applied by an ordinary `db push` from this workdir.

## Recovery status

This is a migration-source recovery, **not a disaster-recovery backup**. It does not contain production table rows, Auth users, Storage object bytes, database passwords, or provider secrets. The active organization is on Supabase Free, which does not include automatic daily backups or database branching. A full encrypted database/Auth/Storage backup and an isolated restore drill remain required before production launch.
