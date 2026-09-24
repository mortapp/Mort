-- Minimal production-contract baseline for disposable PostgreSQL execution.
-- This is not a product migration. It supplies only the pre-existing objects
-- referenced by 20260920235334_mort_progression_v1.sql.

do $$ begin
  if not exists (select 1 from pg_catalog.pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_catalog.pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
  if not exists (select 1 from pg_catalog.pg_roles where rolname = 'service_role') then
    create role service_role nologin bypassrls;
  end if;
end $$;

create schema auth;
create schema private;

create function auth.uid()
returns uuid
language sql
stable
set search_path = ''
as $$
  select nullif(pg_catalog.current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;

create table public.profiles (
  id uuid primary key,
  role text not null check (role in ('teen','adult','guardian','admin')),
  username text,
  avatar_path text,
  account_status text not null default 'active',
  is_test_account boolean not null default false,
  leaderboard_opt_out boolean not null default false,
  updated_at timestamptz not null default now()
);

create function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin' and account_status = 'active'
  );
$$;

create table public.jobs (
  id uuid primary key,
  category text not null
);

create table public.applications (
  id uuid primary key,
  -- Account deletion retains historical applications after removing the user ID.
  teen_id uuid references public.profiles(id),
  job_id uuid not null references public.jobs(id),
  status text not null,
  updated_at timestamptz not null default now()
);

create table public.application_status_events (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references public.applications(id),
  to_status text not null,
  created_at timestamptz not null default now()
);

create table public.job_checkins (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references public.applications(id),
  user_id uuid not null references public.profiles(id),
  checkin_type text not null check (checkin_type in ('pre_meeting','arrival','cadence','departure')),
  status text not null check (status in ('pending','completed','missed','canceled'))
);

create table public.reviews (
  id uuid primary key,
  job_id uuid not null references public.jobs(id),
  reviewer_id uuid not null references public.profiles(id),
  subject_id uuid not null references public.profiles(id),
  rating integer not null check (rating between 1 and 5),
  moderation_status text not null default 'approved',
  revealed_at timestamptz,
  created_at timestamptz not null default now()
);

create function private.leaderboard_tier(p_score integer)
returns text
language sql
immutable
set search_path = ''
as $$
  select case when p_score >= 500 then 'established'
    when p_score >= 100 then 'active' else 'starting' end;
$$;

grant usage on schema public, auth to anon, authenticated, service_role;
grant select on public.profiles to authenticated;
grant execute on function auth.uid(), public.is_admin() to authenticated, service_role;

create function public.set_leaderboard_opt_out_v1(p_opt_out boolean)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    return pg_catalog.jsonb_build_object('ok',false,'code','authentication_required');
  end if;
  update public.profiles set leaderboard_opt_out = p_opt_out, updated_at = now()
  where id = auth.uid() and role = 'teen';
  if not found then
    return pg_catalog.jsonb_build_object('ok',false,'code','user_role_not_allowed');
  end if;
  return pg_catalog.jsonb_build_object('ok',true,'leaderboard_opt_out',p_opt_out);
end;
$$;
revoke all on function public.set_leaderboard_opt_out_v1(boolean) from public,anon;
grant execute on function public.set_leaderboard_opt_out_v1(boolean) to authenticated;

-- Existing visible teen used to verify the migration's one-time privacy reset.
insert into public.profiles(id,role,username,leaderboard_opt_out)
values ('00000000-0000-0000-0000-0000000000e5','teen','prior_visible',false);

-- A retained completion with a deleted account must never receive progression.
insert into public.jobs(id,category)
values ('10000000-0000-0000-0000-0000000000ff','lawn care');
insert into public.applications(id,teen_id,job_id,status)
values ('20000000-0000-0000-0000-0000000000ff',null,
  '10000000-0000-0000-0000-0000000000ff','completed');
insert into public.application_status_events(application_id,to_status)
values ('20000000-0000-0000-0000-0000000000ff','completed');
