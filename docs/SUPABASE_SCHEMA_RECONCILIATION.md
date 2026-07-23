# Supabase Schema Reconciliation

The local MORT MVP expects the schema in `supabase/migrations/202607070001_initial_mort.sql`.

## Local MVP Schema Expects

- Auth-backed `profiles` with role, DOB, city/state, onboarding completion, account status, verification status, and payment preference.
- Role profile tables: `teen_profiles`, `adult_profiles`, `guardian_profiles`.
- Marketplace tables: `jobs`, `applications`, `message_threads`, `conversations`, `conversation_participants`, `messages`.
- Safety tables: `reports`, `blocks`, `safety_pings`, `admin_action_logs`.
- Verification/proof/support tables: `business_verifications`, `proof_uploads`, `support_tickets`, `support_ticket_messages`.
- Notifications: `notifications`, `notification_events`, `push_tokens`.
- Private Storage buckets: `proof-uploads`, `verification-uploads`, `report-uploads`.
- RLS on every public table, security-invoker compatibility views, and RPCs for safe messaging and guardian invites.

## Old Project Rebuild Status - 2026-07-08

The old project ref `rakjydmgwwgtdislanbt` was intentionally rebuilt after explicit destructive-risk confirmation.

See `docs/OLD_PROJECT_REBUILD_REPORT.md` for the completed backup, audit, rebuild, storage, Edge Function, QA seed, smoke, RLS, Expo, and warning details.

Current verified remote state:

- `23` public tables
- `23` RLS-enabled public tables
- `28` public functions
- `25` non-internal public triggers
- private `proof-uploads`, `report-uploads`, and `verification-uploads` buckets
- one migration history row: `202607070001 initial_mort`
- old incompatible public tables and the old public `profile-avatars` bucket are absent

This confirms the old project has been rebuilt into the current MORT backend baseline. It does not mean iPhone manual testing, TestFlight, App Store, legal, privacy, teen-safety, or real-user launch readiness is complete.

## Why The Original Live Mismatch Mattered

Read-only inspection of the current live project found older `profiles`, `jobs`, and `notification_events` tables with different columns, and several MVP tables were missing. If `supabase db push` is run blindly against a mismatched, data-bearing project, the CLI may apply changes that conflict with old table shapes or require manual migration of existing data.

## Safe Option A: Fresh Supabase Project

This is safest while MORT is pre-production.

```powershell
supabase login
supabase link --project-ref <fresh-project-ref>
supabase db push
supabase functions deploy send-push
supabase secrets set SUPABASE_URL=https://<fresh-project-ref>.supabase.co
supabase secrets set SUPABASE_SERVICE_ROLE_KEY (server-side only placeholder)<service-role-key-from-dashboard>
supabase secrets set SEND_PUSH_INVOKE_SECRET (server-side only placeholder)<long-random-invocation-secret>
```

Then set `.env.local`:

```powershell
EXPO_PUBLIC_SUPABASE_URL=https://<fresh-project-ref>.supabase.co
EXPO_PUBLIC_SUPABASE_ANON_KEY=<anon-or-publishable-key>
```

## Safe Option B: Manually Reconcile Existing Project

Use this only if the current project must be preserved.

1. Export a schema/data backup from Supabase.
2. Create a Supabase branch or staging clone.
3. Compare existing tables against `supabase/migrations/202607070001_initial_mort.sql`.
4. Write a reviewed migration that renames or transforms old columns into the MVP schema.
5. Run Supabase advisors on staging.
6. Test the app against staging.
7. Apply the reviewed migration to production during a maintenance window.

## Recommendation

For future environments, use a fresh clean Supabase project unless you explicitly confirm the target can be wiped or migrated. The old project was already rebuilt intentionally, but fresh staging remains safer for future QA and release rehearsals.

## Do Not Run

Do not run these against any data-bearing project without a fresh backup and an explicit destructive-risk confirmation:

```powershell
supabase db reset
supabase db push
drop schema public cascade;
truncate table public.profiles cascade;
```

Do not paste service-role keys into Expo/mobile code. Service-role belongs only in Supabase Edge Function secrets or trusted server tooling.

