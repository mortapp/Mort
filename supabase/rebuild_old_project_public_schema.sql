-- Destructive-risk old project rebuild prep.
-- Run only after backups are created and explicit confirmation variables are present.
-- This intentionally removes app-owned public schema objects and old Storage policies.
-- It does not drop Supabase internal schemas and does not delete auth.users.

begin;

drop schema if exists public cascade;
create schema public;

grant usage on schema public to postgres, anon, authenticated, service_role;
grant all on schema public to postgres, service_role;

do $$
declare
  storage_policy record;
begin
  for storage_policy in
    select policyname
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
  loop
    execute format('drop policy if exists %I on storage.objects', storage_policy.policyname);
  end loop;
end $$;

do $$
begin
  if to_regclass('supabase_migrations.schema_migrations') is not null then
    truncate table supabase_migrations.schema_migrations;
  end if;
end $$;

commit;
