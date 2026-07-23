# Supabase Deployment

## Schema

Apply the schema in `supabase/migrations/202607070001_initial_mort.sql` with the Supabase CLI:

```bash
supabase link --project-ref your-project-ref
supabase db push
```

The migration creates enum types, RLS-protected marketplace tables, storage buckets, storage policies, helper functions, admin action logging, in-app notifications, support tickets, and the `send_safe_message` RPC.

Core tables include `profiles`, role profile tables, guardian links, jobs, applications, conversations, messages, reports, blocks, adult verification, proof uploads, payment preferences, push tokens, notifications, support tickets, admin logs, and safety pings. The app currently uses `applications`, `guardian_connections`, `message_threads`, `blocks`, and `business_verifications`; security-invoker compatibility views expose `job_applications`, `guardian_links`, `blocked_users`, and `adult_verifications`.

## Auth

Enable email/password sign-in. The app creates the initial auth user through Supabase Auth and then writes profile/onboarding data through anon-key RLS policies.

## Admins

There are no hardcoded admin ids. Promote an admin from a trusted backend context:

```sql
begin;
select set_config('mort.internal_update', 'true', true);

update public.profiles
set role = 'admin'
where id = 'auth-user-id-from-supabase-auth';

commit;
```

Only existing admins can read admin moderation queues from the app.

Admin role changes are intentionally not available from the Expo app. The database trigger blocks self-assigned admin role changes and requires adult, guardian, and admin profiles with a date of birth to be 18+.

## Edge Function

Deploy push notification delivery:

```bash
supabase functions deploy send-push
supabase secrets set SEND_PUSH_INVOKE_SECRET (server-side only placeholder)long-random-invocation-secret
```

On hosted Supabase Edge Functions, `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are runtime-managed environment variables. The CLI refuses to set names beginning with `SUPABASE_`; the old-project rebuild verified those runtime values by invoking `send-push` successfully.

The service-role key lives only in Supabase/server runtime or trusted local tooling, never in the Expo app, `.env.local`, commits, or release zips.

