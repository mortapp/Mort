# Local Supabase QA

Use local Supabase to prove migrations, RLS, Storage, onboarding, and app flows before touching a remote project.

## Actual Backend QA Execution - 2026-07-08

Preflight on this Windows machine:

- `node -v`: `v24.12.0`
- `pnpm -v`: `11.7.0`
- `docker --version`: `Docker version 29.1.5, build 0e6fee6`
- `docker info`: Docker Desktop daemon running on WSL2
- `pnpm exec supabase --version`: `2.109.0`

Local Supabase:

- `pnpm exec supabase start`: first image-pull attempt exited nonzero while downloading images; rerun succeeded after images were present.
- API URL: `http://127.0.0.1:54321`
- DB URL: `postgresql://postgres:postgres@127.0.0.1:54322/postgres`
- Studio URL: `http://127.0.0.1:54323`
- Local anon/service keys were read from `supabase status` only and were not committed.
- Supabase CLI reported `v2.109.1` is available; this project remains pinned to `2.109.0`.

Database and Storage verification:

- `.\scripts\local-supabase-reset.ps1`: succeeded after migration fixes.
- Applied migration: `202607070001_initial_mort.sql`
- Public RLS tables: `23/23`
- Public functions: `28`
- Public triggers: `30`
- Required private buckets: `3/3`
- Storage policies: `3`
- Service-role table grants: verified for local QA/PostgREST checks.

Local QA results:

- `.\scripts\generate-supabase-types.ps1`: generated `types\supabase.generated.ts`
- `pnpm check`: passed
- `pnpm lint`: passed
- `.\scripts\qa-smoke.ps1`: passed
- `node scripts/create-local-test-users.mjs`: passed
- `.\scripts\qa-rls.ps1`: passed
- `pnpm build`: passed
- `npx expo export --platform web`: passed
- `npx expo-doctor`: `20/20 checks passed`
- `npx expo start --localhost --port 8081`: Metro started at `http://localhost:8081` and was stopped cleanly

Current Docker note: DB/Auth/Storage/REST/Realtime/Kong/Studio were running; `supabase_vector_mort-mobile` was restarting. MORT does not use vector search.

## Bugs Found And Fixed

- `supabase db query --local --file supabase/storage_setup.sql` failed because the CLI path attempted a prepared statement with multiple SQL commands. Added `scripts/apply-local-storage.ps1`, which applies the file through local Docker `psql`.
- Supabase type generation wrote CLI/Docker progress into `types\supabase.generated.ts`. Updated `scripts/generate-supabase-types.ps1` to capture stdout/stderr separately and preserve the generated `Json` and `Database` exports only.
- Local service-role PostgREST checks returned `403` because the migration granted table access to `authenticated` but not `service_role`. Added explicit service-role grants.
- `sync_conversation_for_thread()` used a PL/pgSQL variable named `conversation_id`, which conflicted with a column name during trigger execution. Renamed it to `v_conversation_id`.
- Local QA seed was not repeatable for the active guardian connection unique index. Updated `scripts/create-local-test-users.mjs` to reuse the existing active teen/guardian pair.

## Commands

Start local Supabase:

```powershell
cd "$env:USERPROFILE\Mort"
.\scripts\local-supabase-start.ps1
```

Reset local Supabase:

```powershell
$env:MORT_LOCAL_SUPABASE_CONFIRM="LOCAL_ONLY"
.\scripts\local-supabase-reset.ps1
```

Apply Storage setup locally:

```powershell
.\scripts\apply-local-storage.ps1
```

Generate types:

```powershell
.\scripts\generate-supabase-types.ps1
```

Run smoke/RLS with local service role in process env only:

```powershell
$env:MORT_QA_TARGET="local"
$env:MORT_QA_ALLOW_SERVICE_ROLE="LOCAL_OR_STAGING_ONLY"
$env:SUPABASE_SERVICE_ROLE_KEY (server-side only placeholder)"<local-service-role-key-from-supabase-status>"
.\scripts\qa-smoke.ps1 -LoadEnvLocal
.\scripts\qa-rls.ps1 -LoadEnvLocal
```

Do not commit `.env.local`, local keys, service-role keys, Supabase status output, logs, or Docker data.

