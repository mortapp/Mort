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
-- Definition source: production-baseline-2026-11-12.sql lines 95-102, 969-974, 1588-1599, 1771-1782, 2237-2246, 9071-9077.
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

-- Staff role grants are operator-managed in production; the table carries
-- admin/moderator rows and a check constraint matching production exactly.
create table private.user_roles (
  user_id uuid not null,
  role public.mort_role not null,
  granted_by uuid,
  granted_at timestamptz default now() not null,
  constraint user_roles_role_check
    check (role = any (array['admin'::public.mort_role, 'moderator'::public.mort_role]))
);

-- Replay/idempotency store for job mutation requests; the 20261115000000
-- migration reads and writes this table.
create table private.mort_job_mutation_requests (
  user_id uuid not null,
  client_request_id uuid not null,
  operation text not null,
  request_hash text not null,
  response jsonb,
  created_at timestamptz default now() not null
);

create function private.has_staff_role(required_roles public.mort_role[]) returns boolean
  language sql
  stable
  security definer
  set search_path = ''
as $$
  select exists (
    select 1
    from private.user_roles ur
    where ur.user_id = (select auth.uid())
      and ur.role = any(required_roles)
  );
$$;

create function private.mort_age_years(p_date_of_birth date) returns integer
  language sql
  stable
  set search_path = ''
as $$
  select case when p_date_of_birth is null then null
    else extract(year from age(current_date, p_date_of_birth))::integer
  end;
$$;
