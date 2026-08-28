# Dev And Staging Test Data

Use dev/staging only. Do not insert fake production users from app code and do not bypass RLS in production.

## Auth Users

Supabase Auth users should be created through the app, Supabase Dashboard, or Supabase Auth API. After real local/staging Auth users exist, copy their IDs from `auth.users`.

Then use:

```sql
supabase/dev_seed_example.sql
```

Replace every placeholder UUID first. The file is intentionally a template, not production seed data.

## Test Users

Create:

- teen test user, age 13-17
- adult test user, age 18+
- guardian test user, age 18+
- admin test user, age 18+, promoted externally through `docs/ADMIN_SETUP.md`

## Flow Data To Create

- approved adult verification
- sample job
- teen application
- guardian approval state
- adult accepted state
- message thread
- report
- notification event
- proof upload record
- safety ping

## Correct Admin Promotion

Use a real local/staging user ID:

```sql
begin;
select set_config('mort.internal_update', 'true', true);

update public.profiles
set role = 'admin'
where id = '<real-auth-user-id>';

commit;
```

Do not hardcode an admin ID in Expo/mobile source.
