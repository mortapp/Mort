# Windows Local Run

## Verified On 2026-07-08

- Node: `v24.12.0`
- pnpm: `11.7.0`
- Docker: `29.1.5`
- Supabase CLI: project-local `2.109.0`
- Expo Doctor: `20/20 checks passed`
- Metro: started at `http://localhost:8081` and stopped cleanly

## Standard Check

```powershell
cd "$env:USERPROFILE\Mort"
pnpm install
pnpm check
pnpm lint
pnpm build
npx expo export --platform web
npx expo-doctor
npx expo start
```

Or run the safe check script:

```powershell
.\scripts\windows-check.ps1
```

## Local Supabase

```powershell
.\scripts\local-supabase-start.ps1
.\scripts\local-supabase-status.ps1
```

If no global `supabase` command is installed, the scripts use the project-local Supabase CLI installed in `node_modules`.

Local reset requires an explicit local-only flag:

```powershell
$env:MORT_LOCAL_SUPABASE_CONFIRM="LOCAL_ONLY"
.\scripts\local-supabase-reset.ps1
```

Apply or repair local Storage setup:

```powershell
.\scripts\apply-local-storage.ps1
```

Generate local Supabase types:

```powershell
.\scripts\generate-supabase-types.ps1
```

## Local QA

```powershell
$env:MORT_QA_TARGET="local"
$env:MORT_QA_ALLOW_SERVICE_ROLE="LOCAL_OR_STAGING_ONLY"
$env:SUPABASE_SERVICE_ROLE_KEY (server-side only placeholder)"<local-service-role-key>"
.\scripts\qa-smoke.ps1 -LoadEnvLocal
.\scripts\qa-rls.ps1 -LoadEnvLocal
```

Seed local users/data:

```powershell
$env:SUPABASE_DB_URL="<local-db-url>"
node scripts/create-local-test-users.mjs
```

## Environment

Put local values in:

```powershell
C:\Users\micha\Mort\.env.local
```

Do not commit `.env.local`.

## Clear Expo Cache

```powershell
npx expo start -c
```

## Port 8081 Stuck

Find and stop the process:

```powershell
Get-NetTCPConnection -LocalPort 8081 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess
Stop-Process -Id <process-id>
```

Then restart:

```powershell
npx expo start
```

## Web Export

```powershell
npx expo export --platform web
```

`dist/` is generated output and should not be committed.

## Avoid Committing Secrets

```powershell
.\scripts\secret-scan.ps1
```

The scan excludes `.env.local`, generated outputs, local Supabase temp data, and binary assets. It checks Expo/mobile source for JWT-like keys and service-role references.

