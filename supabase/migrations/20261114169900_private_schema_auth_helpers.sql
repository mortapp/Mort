-- Create the production-only auth helper objects that newer migrations depend on.
--
-- These definitions exist in production (and in
-- supabase/production-baseline-recovery/production-baseline-2026-11-12.sql) but were
-- never represented in the generic local migration chain. Migrations that create
-- functions referencing public.mort_role, private.current_role(), or
-- private.is_active_user() fail on a fresh local database with SQLSTATE 42704/42883
-- ("type public.mort_role does not exist", "function private.is_active_user()
-- does not exist"). This restores local/production parity for those objects.
--
-- Definition source: production-baseline-2026-11-12.sql lines 95-102, 969-974, 1771-1782.
-- The enum must match production exactly ('pending','teen','adult','admin','moderator','guardian').

create type public.mort_role as enum (
  'pending',
  'teen',
  'adult',
  'admin',
  'moderator',
  'guardian'
);

create schema if not exists private;

create function private.current_role() returns public.mort_role
  language sql
  stable
  security definer
  set search_path = ''
as $$
  select p.role from public.profiles p where p.id = (select auth.uid());
$$;

create function private.is_active_user() returns boolean
  language sql
  stable
  security definer
  set search_path = ''
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid())
      and p.account_status = 'active'
      and p.role in ('teen','adult','admin','moderator')
  );
$$;
