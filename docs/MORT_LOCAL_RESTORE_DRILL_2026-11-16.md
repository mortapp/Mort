# MORT Local Backup Restore Drill — 2026-11-16

Local, disposable drill of the feature-data backup path. No production data,
credentials or project were touched. This does not replace the owner-approved
isolated-project drill in `MORT_RESTORE_DRILL_GUIDE.md`.

## What it runs

`scripts/restore-drill-local.mjs` (also the `backup-restore-drill` CI job):

1. Start local Supabase and apply the full generic migration chain (247 migrations on main at `4028a9b`).
2. Seed the six local QA users (`scripts/create-local-test-users.mjs`).
3. `snapshot`: capture data with the same code the production backup uses
   (`scripts/backup-feature-snapshot.mjs`, now shared with `backup-feature-data.mjs`),
   record per-table row counts and content hashes, and seal everything in the production
   AES-256-GCM envelope (`scripts/backup-envelope.mjs`). Confirms that a tampered
   ciphertext and a wrong key are both rejected.
4. `supabase db reset --local --no-seed`: fresh target built from the migration chain.
5. `restore`: decrypt, load every table with triggers suspended, advance sequences, then
   recompute hashes and check every foreign key in `public` and `storage`.

The script refuses non-local hosts and prints only table names, counts and hashes.

## Result

| Check | Result |
| --- | --- |
| Tables in snapshot scope | 256 (`public.*`, `storage.buckets`, `storage.objects`) |
| Rows restored | 488 (pass 1), 501 (pass 2) |
| Per-table content hash mismatches | 0 |
| Envelope tamper / wrong key | both rejected |
| Restore time | under 0.5 s locally |

Everything in scope restores exactly.

## Gaps found

The feature-data snapshot does not cover data a working restore needs:

| Not captured | Effect after restore |
| --- | --- |
| `auth.users`, `auth.identities` | Every `public.profiles` row is orphaned (`profiles_id_fkey`); no restored user can sign in. |
| `private.*` (58 tables) | Runtime changes are lost. Pass 2 granted one staff role in `private.user_roles`; it was missing after restore. Migration-seeded control rows only come back at their migration defaults, not their live values. |
| `storage` object bytes | Only `storage.objects` metadata is captured; file contents are not. |

Recommended follow-up before relying on this backup for recovery: add `private` to the
snapshot scope, and decide on an Auth recovery path (Supabase PITR/daily backups or an
approved encrypted `auth` export). Once that's done, enable `MORT_RESTORE_DRILL_STRICT=1`
in CI so that any orphaned key or out-of-scope loss fails the job.
