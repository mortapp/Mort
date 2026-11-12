# Production baseline recovery

Authoritative, restorable definition of the mort p production database
schema (`jxbnrkasktbhtiujkhay`), independent of the `supabase/migrations`
history (which is the full repo lineage, a superset of production).

- `production-baseline-2026-11-12.sql` — full schema-only dump of the
  public and private schemas taken 2026-11-12 via `pg_dump --schema-only`
  through the IPv4 session pooler. No user data.
- `storage-policies-2026-11-12.sql` — storage RLS policies and bucket
  definitions, generated from the live production catalog.
- `20261102040639_restrict_job_application_direct_select.*` — earlier
  recovery pair kept for history.

## Restore procedure (isolated environment only)

1. On the target project, drop and recreate the `public` and `private`
   schemas, and drop existing `storage` policies.
2. Apply `production-baseline-2026-11-12.sql` end to end.
3. Apply `storage-policies-2026-11-12.sql`.
4. Platform-managed objects (auth/storage catalogs, default privileges
   owned by `supabase_admin`) are provided by the Supabase platform and
   are intentionally not included.

The 2026-11-12 restore validation against the isolated QA project
matched production exactly, except for the platform's own storage
lifecycle tables which ship with the platform version.

Never restore over production.
