# Local Test Users

Use this only against the local Docker Supabase stack.

## Requirements

- `EXPO_PUBLIC_SUPABASE_URL` points to `http://127.0.0.1:54321` or `http://localhost:54321`
- `SUPABASE_SERVICE_ROLE_KEY` is the local service-role key from `supabase status`
- `SUPABASE_DB_URL` is the local DB URL from `supabase status`
- `MORT_QA_TARGET=local`
- `MORT_LOCAL_TEST_PASSWORD` is a temporary local-only QA password with at least 12 characters

Do not use this script against staging or production.

## Actual Backend QA Execution - 2026-07-08

`node scripts/create-local-test-users.mjs` ran successfully against local Docker Supabase.

Created or reused local-only auth users:

- `teen.local@mort.test`
- `teen2.local@mort.test`
- `adult.local@mort.test`
- `adult2.local@mort.test`
- `guardian.local@mort.test`
- `admin.local@mort.test`

The QA password was supplied through `MORT_LOCAL_TEST_PASSWORD` and was not printed by the seeder.

## Run

```powershell
cd "$env:USERPROFILE\Mort"
$env:MORT_QA_TARGET="local"
$env:SUPABASE_SERVICE_ROLE_KEY (server-side only placeholder)"<local-service-role-key>"
$env:SUPABASE_DB_URL="<local-db-url>"
$env:MORT_LOCAL_TEST_PASSWORD="<temporary-local-qa-password>"
node scripts/create-local-test-users.mjs
```

## Seeded Data

The script creates:

- completed teen/adult/guardian/admin profiles
- second teen and second adult for RLS outsider tests
- local admin promotion through DB/service-role context only
- approved adult verification
- pending second-adult verification
- adult-owned open job
- second-adult open job
- accepted teen application
- active guardian connection
- message thread, conversation, participants, and safe sample message
- private proof upload metadata plus a matching private Storage object
- report
- safety ping
- notification and notification event
- admin action log

Repeated local runs reuse auth users and the active guardian connection, then add a fresh fixture batch for jobs/applications/reports/notifications.

