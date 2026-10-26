# Flutter Supabase Setup

MORT's supported production client is the Flutter app in `flutter_mort`. Configure its public Supabase values as `SUPABASE_URL` and `SUPABASE_ANON_KEY`; the Android build scripts also accept `MORT_EXPECTED_SUPABASE_PROJECT_REF` to verify the URL points at the intended project.

## Create and initialize a new project

Create the new Supabase project and leave its database empty for the initial migration. Before applying migrations, verify the project reference in the Supabase dashboard. Do not point this process at the previous live project or any project containing data.

Install the repository's pinned CLI and authenticate:

```powershell
pnpm install --frozen-lockfile
pnpm exec supabase login
```

Set the new project's reference and matching confirmation in the same PowerShell session, then run the guarded bootstrap:

```powershell
$env:MORT_SUPABASE_PROJECT_REF = '<new-project-ref>'
$env:MORT_CONFIRM_PROJECT_REF = '<new-project-ref>'
$env:MORT_CONFIRM_FRESH_SUPABASE = 'YES_FRESH_PROJECT'
./scripts/apply-fresh-supabase.ps1
```

The script links the requested project, runs `supabase db push --dry-run`, stops if the preview fails, and only then applies the migrations with `supabase db push`. Review the dry-run output and confirm it lists the expected migrations before proceeding. The script does not run `db reset` or delete project data.

After the push, verify migration history and database security advisors:

```powershell
pnpm exec supabase migration list --linked
pnpm exec supabase db advisors
```

Resolve schema, RLS, and advisor findings before configuring the app. Recheck that every table in exposed schemas has RLS enabled and that policies restrict access to the intended user or service role.

## Client and server credentials

Use the new project's HTTPS URL and public anon or publishable key for Flutter builds:

```powershell
$env:SUPABASE_URL = 'https://<new-project-ref>.supabase.co'
$env:SUPABASE_ANON_KEY = '<public-anon-or-publishable-key>'
$env:MORT_EXPECTED_SUPABASE_PROJECT_REF = '<new-project-ref>'
```

The public key is embedded in the mobile app and is not a secret. Never put a service-role or secret API key in Flutter, a mobile build, or a public repository. Store privileged values only as Supabase Edge Function secrets or in a trusted server environment. Generate a fresh random `SEND_PUSH_INVOKE_SECRET` for the new project; do not reuse old-project secrets.

Before deploying Edge Functions, reconcile the function inventory with current Flutter calls, database triggers, and scheduled jobs. Deploy the required functions and configure their server-side secrets for the new project. Then verify function health and authenticated/unauthenticated behavior before pointing a public app build at it.

## Release

Do not use the previous project's hard-coded release build wrapper. The supported public artifact entry point is `scripts/build-production-public-aab.ps1`; it validates the configured project and production release gates and must pass before an AAB can be produced. The existing Google Play upload key is stored outside the repository and must not be replaced.

See [Supabase Schema Reconciliation](SUPABASE_SCHEMA_RECONCILIATION.md) for the historical schema mismatch and backup requirements. That document describes the previous project; it does not establish the new project's state.
