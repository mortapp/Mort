# GitHub Setup

`C:\Users\micha\Mort` is source-ready, but this folder is not initialized as a git repo yet.

## Initialize Git

```powershell
cd "$env:USERPROFILE\Mort"
git init
git status --short
.\scripts\secret-scan.ps1
git status --short
git add .
git status --short
git commit -m "Initial MORT Expo Supabase app"
```

## Create GitHub Repo

Create an empty private GitHub repository first. Do not add a README, license, or gitignore in GitHub if you are pushing this existing project.

```powershell
git branch -M main
git remote add origin https://github.com/<your-org-or-user>/<repo-name>.git
git push -u origin main
```

## Never Commit

- `.env`, `.env.local`, `.env.production`, or any `.env.*.local`
- Supabase `service_role` keys or secret keys
- Real anon key values if they appear outside local env files
- Apple credentials, EAS tokens, App Store Connect API keys, certificates, provisioning profiles
- `node_modules`, `.expo`, `dist`, `ios`, `android`, build outputs, logs, or generated archives

## Secret Scan Before Push

Run:

```powershell
cd "$env:USERPROFILE\Mort"
.\scripts\secret-scan.ps1
git status --short
```

Also inspect staged changes before the first push:

```powershell
git diff --cached --name-only
git diff --cached
```

The script scans for JWT-shaped Supabase keys in source files and service-role references in Expo/mobile app source. It intentionally allows server-only variable names in docs and `supabase/functions`.
