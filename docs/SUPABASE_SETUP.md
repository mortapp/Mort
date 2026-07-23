# Supabase Setup

Current mismatched live project URL: `https://rakjydmgwwgtdislanbt.supabase.co`

Use the anon key only as `EXPO_PUBLIC_SUPABASE_ANON_KEY` in `.env.local` or an EAS environment. Never put a service-role key in Expo/mobile code.

## Apply Schema

Important: the live project currently has an older/different MORT schema. Read-only inspection found `profiles`, `jobs`, and `notification_events`, but several MVP tables such as `applications`, `guardian_connections`, `push_tokens`, `proof_uploads`, and `support_tickets` were not present. Existing `profiles` and `jobs` columns also differ from this app schema.

Do not run destructive commands to force alignment. Use a Supabase branch, staging project, or reviewed SQL migration to reconcile the existing schema with `supabase/migrations/202607070001_initial_mort.sql`.

For a clean/new project or reviewed branch:

```bash
supabase login
supabase link --project-ref <fresh-staging-project-ref>
supabase db push
```

Do not run `supabase db push` or `supabase db reset` on the current mismatched live project. The migration creates RLS-protected app tables, private storage buckets, helper RPCs, auth profile trigger, notification queue triggers, support tables, admin logs, and signed-preview-compatible storage policies.

For the full live-project decision tree, read `docs/SUPABASE_SCHEMA_RECONCILIATION.md` before running Supabase commands.

Deploy `send-push` only with server-side Edge Function secrets:

```bash
supabase functions deploy send-push
supabase secrets set SUPABASE_URL=https://<project-ref>.supabase.co
supabase secrets set SUPABASE_SERVICE_ROLE_KEY (server-side only placeholder)<service-role-key-from-dashboard>
supabase secrets set SEND_PUSH_INVOKE_SECRET (server-side only placeholder)<long-random-invocation-secret>
```

## First Admin

Create a real user through Supabase Auth, finish profile setup with an adult DOB, then promote from trusted SQL/dashboard only:

```sql
begin;
select set_config('mort.internal_update', 'true', true);

update public.profiles
set role = 'admin'
where id = 'auth-user-id-from-supabase-auth';

commit;
```

Admin cannot be self-selected in onboarding and cannot be assigned by the Expo app.

## Advisors

The final live advisor rerun returned 38 security WARN findings, 0 performance WARN findings, and 28 performance INFO findings. Thirty-seven security rows are intentional authenticated security-definer lint warnings with reviewed authorization and grants. The remaining Auth row is **DEFERRED — PLAN-LIMITED SECURITY ENHANCEMENT**: the Free-plan dashboard confirmed that HaveIBeenPwned leaked-password protection requires Supabase Pro or above, so it is not an unresolved MORT code security bug. Current mitigations and the future upgrade task are documented in `docs/ENABLE_LEAKED_PASSWORD_PROTECTION.md`. The private `profile-avatars` bucket has no public listing policy, and remote QA confirmed unrelated users cannot list or directly download it.

