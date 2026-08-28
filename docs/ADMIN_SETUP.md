# Admin Setup

MORT does not create a default admin in app code. Admin cannot be self-selected in onboarding.

## Promote First Admin

1. Create a real user through Supabase Auth.
2. Complete onboarding with an adult DOB.
3. In Supabase Dashboard SQL editor, promote that trusted user:

```sql
begin;
select set_config('mort.internal_update', 'true', true);

update public.profiles
set role = 'admin'
where id = '<real-auth-user-id>';

commit;
```

Use a real user ID copied from Supabase Auth. Do not use fake IDs or seed a production admin from app code.

## Verify Admin Access

Sign in as that user. The route guard should send the profile to the admin tabs. Verify admin queues load:

- reports
- users
- jobs
- verification
- support

## Demote Admin

From trusted SQL/dashboard:

```sql
begin;
select set_config('mort.internal_update', 'true', true);

update public.profiles
set role = 'adult'
where id = '<real-auth-user-id>';

commit;
```

Choose `adult` or another appropriate role only after confirming the account's DOB satisfies the role age rule.

## Admin Action Logs

Status updates for reports, jobs, and business verification records create `admin_action_logs` rows when performed by an authenticated admin. Review logs before launch to confirm moderation accountability.
