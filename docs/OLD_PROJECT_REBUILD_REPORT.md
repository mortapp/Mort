# Old Project Rebuild Report

Date: `2026-07-08`

Project ref: `rakjydmgwwgtdislanbt`

Project URL: `https://rakjydmgwwgtdislanbt.supabase.co`

Status: old project rebuilt and remote backend verified for the current MORT app baseline. This is not production-ready and has not been iPhone, TestFlight, App Store, legal, privacy, or teen-safety reviewed.

## Environment Gate

The destructive-risk rebuild guard was confirmed before destructive work:

- `MORT_REUSE_OLD_PROJECT_REF=rakjydmgwwgtdislanbt`
- `MORT_CONFIRM_OLD_PROJECT_REF=rakjydmgwwgtdislanbt`
- `MORT_CONFIRM_RISKY_REBUILD=YES_REBUILD_OLD_PROJECT`
- `MORT_CONFIRM_DATA_LOSS=I_UNDERSTAND_THIS_CAN_DELETE_OLD_DATA`
- `MORT_QA_TARGET=old-project-rebuild`
- `MORT_QA_ALLOW_SERVICE_ROLE=LOCAL_OR_STAGING_ONLY`
- `SUPABASE_ACCESS_TOKEN`, `SUPABASE_DB_PASSWORD`, `SUPABASE_SERVICE_ROLE_KEY`, `SEND_PUSH_INVOKE_SECRET`, and the Expo public Supabase env values were present in User-scope environment variables.

No secret values are documented here.

## Expo Env

`.env.local` contains only:

- `EXPO_PUBLIC_SUPABASE_URL`
- `EXPO_PUBLIC_SUPABASE_ANON_KEY`
- `EXPO_PUBLIC_APP_ENV=old-project-rebuild`

`SUPABASE_SERVICE_ROLE_KEY` is not in `.env.local`.

## Backup

Backup folder:

```text
backups/supabase-rakjydmgwwgtdislanbt-20260708-094033/
```

Backup files created before destructive work:

- `BACKUP_TIMESTAMP.txt`
- `remote_schema.sql`
- `remote_roles.sql`
- `remote_data_public_storage.sql`
- `remote_migration_history.txt`
- `remote_audit_query.sql`
- `remote_audit_snapshot.txt`

Raw dump files may contain old project data. They are local backup artifacts only and must not be committed, placed in the final zip, or shared publicly.

## Old Schema Audit Summary

Before rebuild, the old project had:

- `37` public tables
- `4` public functions
- `126` public RLS policies
- `11` public triggers
- `8` storage policies
- `1` storage bucket: public `profile-avatars`
- `5` old remote migration history rows

The old schema included incompatible tables such as `job_applications`, `guardian_links`, `blocked_users`, `payment_records`, `ad_impressions`, `job_proofs`, and `verification_requests`.

## Local Migration Cleanup

No incompatible local migrations were present. The verified MORT migration was kept:

```text
supabase/migrations/202607070001_initial_mort.sql
```

No local migration files were archived.

## Rebuild Actions

Actions taken against `rakjydmgwwgtdislanbt`:

- Linked Supabase CLI to project ref `rakjydmgwwgtdislanbt`.
- Backed up remote schema, roles, public/storage data, migration history, and remote catalog state.
- Audited the old remote schema and wrote the audit docs.
- Removed the old public schema objects.
- Cleared incompatible remote migration history.
- Removed the old public `profile-avatars` bucket through the Storage API after direct SQL deletion was blocked by Supabase.
- Applied the verified MORT migration `202607070001_initial_mort.sql`.
- Applied private Storage setup.
- Deployed `send-push`.
- Set server-side `SEND_PUSH_INVOKE_SECRET` in Supabase secrets. Supabase-managed `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` were available at runtime and verified by function invocation.
- Created old-project rebuild QA users and fixture data.

## Bugs Found And Fixed

- `.env.local` initially had encoding/content that Supabase CLI could not parse. It was rewritten as UTF-8 without BOM and limited to Expo public values.
- PowerShell `Set-Content -Encoding utf8NoBOM` is not supported on this machine. The rewrite was redone using `[System.IO.File]::WriteAllLines` with `UTF8Encoding(false)`.
- Direct SQL deletion from `storage.objects`/`storage.buckets` is blocked by Supabase. Storage cleanup was moved to `scripts/delete-old-project-storage.mjs` using the Storage API.
- The old-project QA seeder initially printed the QA password. It now reports that the QA password is local and does not print it.
- Existing local QA scripts correctly refused the old project. Separate old-project scripts were added instead of weakening local/staging guards.
- A direct `.cmd` spawn for Expo start hit a Windows `spawn EINVAL`. Metro start verification was rerun through `cmd.exe`, polled at `/status`, and stopped.

## Remote Backend Verified

Post-rebuild remote state:

- Public tables: `23`
- RLS-enabled public tables: `23`
- Public functions: `28`
- Non-internal public triggers: `25`
- Storage policies: `3`
- Buckets: private `proof-uploads`, private `report-uploads`, private `verification-uploads`
- Remote migration history: `202607070001 initial_mort`
- Old incompatible public tables checked by QA: none remaining
- Old `profile-avatars` bucket: absent

## QA Status

Remote smoke passed with:

```powershell
pnpm run qa:old-project-smoke
```

Remote RLS passed with:

```powershell
pnpm run qa:old-project-rls
```

The smoke test verified schema exposure, private buckets, no service-role references in mobile source, `.env.local` key limits, old table/bucket absence, migration history, and `send-push` unauthorized/authorized invocation.

The RLS test verified profile isolation, admin queue protection, job ownership, guardian boundaries, conversation participant access, verification approval restrictions, notification ownership, private proof storage, signed proof preview, and admin queue access.

## Expo And Build Checks

Passed:

- `pnpm install`
- `pnpm check`
- `pnpm lint`
- `pnpm build`
- `npx expo export --platform web`
- `npx expo-doctor`
- `.\scripts\secret-scan.ps1`
- `.\scripts\windows-check.ps1`
- `npx expo start --port 8099 --localhost` via wrapper: Metro reached `Waiting on http://localhost:8099`, then was stopped; port `8099` was unreachable after stop.

Expo web export reported the expected web warning that `expo-notifications` push-token listener changes have no effect on web.

## Not Done

- iPhone real-device manual testing has not been done.
- TestFlight has not been done.
- App Store review has not been done.
- Legal/privacy/teen-safety review has not been done.
- Real user launch readiness has not been approved.

## Warnings Before Real Users

- Do not onboard real teens/adults until legal, privacy, teen labor, UGC moderation, support, incident response, and jurisdiction-specific safety review are complete.
- Do not treat the QA users/data as production users.
- Rotate any test credentials before inviting non-QA users.
- Configure Auth redirect URLs, EAS project identity, Apple signing, monitoring, backups, support workflows, and moderation staffing before launch.
- Verify push notifications on a real iPhone EAS preview/TestFlight build; web export and Metro start do not prove iOS push delivery.
