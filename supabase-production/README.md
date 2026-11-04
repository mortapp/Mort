# MORT P production migration workdir

**Authoritative project:** `jxbnrkasktbhtiujkhay`
**Postgres:** 17
**Export date:** 2026-11-02 (migration-ledger reconciliation)
**Export method:** read-only reconstruction from `supabase_migrations.schema_migrations` in the active production database.

## Recovered history

This directory contains **73 ordered migration files** for the 73 versions in the active production ledger through `20261102113314`. Every ledger row had a non-empty SQL statement array; each contains one statement. `migration-history.json` records the production version, name, and SHA-256 of each exact server SQL payload.

The two versions recovered on 2026-11-02 were verified against their recorded server statements. `20261102113314_guardian_id_response_mask_production.sql` is the exact recorded statement and hashes to `96ad143a1c066d3496ca492774c810a9bc196e629f2c7fa2bf908459c4392efa`. The pre-existing `20261102040639_restrict_job_application_direct_select.sql` was left untouched; its executable SQL body matches the production statement after removing editorial comments and normalizing whitespace. The exact 474-byte ledger payload and its SHA-256 (`d816da845f1c71643a0d577b9629b98b3e8db9c0ed4c3667e8a4e7db7a60cf6d`) are preserved under `recovered-ledger-sources/` for byte-for-byte provenance.

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

The three commands above are for local linking and read-only migration inspection, except the final command is explicitly dry-run. **Do not run a non-dry `db push`, `migration repair`, `db reset`, `config push`, or any hosted migration mutation** until all 73 versions show as applied, the 73-file chain has been replayed successfully against an isolated production-equivalent PostgreSQL 17 database, the security and concurrency suites pass, and the owner approves the exact change set.

Supabase's CLI compares migration timestamps between the local migration folder and the remote history table. A matching list does not by itself prove the SQL files are identical; use the SHA-256 manifest as an additional integrity check. The proposal files under `proposals/` are intentionally outside `migrations/` so they cannot be applied by an ordinary `db push` from this workdir.

## Recovery status

This is a migration-source recovery, **not a disaster-recovery backup**. It does not contain production table rows, Auth users, Storage object bytes, database passwords, or provider secrets. The active organization is on Supabase Free, which does not include automatic daily backups or database branching. A full encrypted database/Auth/Storage backup and an isolated restore drill remain required before production launch.
