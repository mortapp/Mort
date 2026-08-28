# Staging Supabase Deployment Plan

Use this after creating a fresh Supabase project for staging. The old project `rakjydmgwwgtdislanbt` was intentionally rebuilt on 2026-07-08 and is documented in `docs/OLD_PROJECT_REBUILD_REPORT.md`, but fresh staging remains the safer rehearsal path for future releases.

## Local Backend Baseline - 2026-07-08

Local Docker Supabase verification passed:

- migration reset passed
- Storage setup passed
- generated types passed `pnpm check`
- smoke passed
- local seed passed
- RLS QA passed
- Expo export and Doctor passed

This means the project is staging-ready from a local backend standpoint, but staging has not been created or verified yet.

## Old Project Rebuild Baseline - 2026-07-08

The old project rebuild completed with:

- backup and schema audit completed first
- MORT migration applied
- private Storage setup applied
- `send-push` deployed and invoked
- QA users/data created
- `pnpm run qa:old-project-smoke` passed
- `pnpm run qa:old-project-rls` passed

This verifies the rebuilt remote backend baseline only. It does not replace fresh staging, iPhone manual testing, TestFlight, App Store, legal, privacy, or teen-safety review.

## Create Fresh Staging Project

1. Create a new Supabase project in the dashboard.
2. Copy its project ref.
3. Copy its Project URL and anon/publishable key.
4. Do not copy service-role keys into Expo/mobile files.

## Local Env For Staging App Test

Update local `.env.local` only:

```text
EXPO_PUBLIC_SUPABASE_URL=https://<fresh-staging-ref>.supabase.co
EXPO_PUBLIC_SUPABASE_ANON_KEY=<staging-anon-or-publishable-key>
EXPO_PUBLIC_APP_ENV=staging
EXPO_PUBLIC_PROJECT_ID=<eas-project-id-or-placeholder>
```

## Apply Schema To Fresh Staging

```powershell
cd "$env:USERPROFILE\Mort"
$env:MORT_CONFIRM_FRESH_SUPABASE="YES_FRESH_PROJECT"
$env:MORT_SUPABASE_PROJECT_REF="<fresh-staging-ref>"
$env:MORT_CONFIRM_PROJECT_REF="<fresh-staging-ref>"
.\scripts\apply-fresh-supabase.ps1
```

The script requires explicit confirmation and runs `supabase db push` only after that. It never runs `db reset`.

## Deploy Push Function

```powershell
pnpm exec supabase functions deploy send-push
pnpm exec supabase secrets set SUPABASE_URL=https://<fresh-staging-ref>.supabase.co
pnpm exec supabase secrets set SUPABASE_SERVICE_ROLE_KEY (server-side only placeholder)<staging-service-role-key>
pnpm exec supabase secrets set SEND_PUSH_INVOKE_SECRET (server-side only placeholder)<long-random-invocation-secret>
```

Keep service-role and function secrets in shell/Supabase secrets only, never in Expo files.

## Run Staging Smoke

```powershell
$env:MORT_QA_TARGET="staging"
$env:SUPABASE_SERVICE_ROLE_KEY (server-side only placeholder)"<staging-service-role-key>"
$env:MORT_QA_ALLOW_SERVICE_ROLE="LOCAL_OR_STAGING_ONLY"
.\scripts\qa-smoke.ps1 -LoadEnvLocal
```

`scripts/qa-rls.ps1` currently requires local seeded users and refuses non-local URLs. For staging RLS, create staging-only QA users first or adapt the script with an explicit staging fixture guard.

## Test App On iPhone

1. Run `npx expo start` for Expo Go testing.
2. Use EAS preview build for push-token and permission testing.
3. Follow `docs/IPHONE_TEST_PLAN.md`.
4. Record bugs with role, screen, exact steps, actual result, expected result, and Supabase error if visible.

## Do Not Run

Do not run these against the existing mismatched live project:

```powershell
supabase db reset
supabase db push
drop schema public cascade;
truncate table public.profiles cascade;
```

