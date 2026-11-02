-- Restore the Flutter authentication/profile contract for the new Supabase
-- project. New Auth users remain pending until onboarding is completed.

create or replace function private.ensure_my_profile()
returns setof public.profiles
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
begin
  if v_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'authentication_required';
  end if;

  if not exists (
    select 1 from auth.users as auth_user where auth_user.id = v_user_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'authentication_required';
  end if;

  -- Only fill a missing row. Never overwrite role, account status, or user data.
  insert into public.profiles (id)
  values (v_user_id)
  on conflict (id) do nothing;

  if not exists (
    select 1 from public.profiles as profile where profile.id = v_user_id
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'profile_bootstrap_failed';
  end if;

  return query
  select profile.*
  from public.profiles as profile
  where profile.id = v_user_id;
end;
$$;

create or replace function public.ensure_my_profile()
returns setof public.profiles
language sql
volatile
security definer
set search_path = ''
as $$
  select * from private.ensure_my_profile();
$$;

create or replace function public.get_my_profile()
returns setof public.profiles
language sql
stable
security definer
set search_path = ''
as $$
  select profile.*
  from public.profiles as profile
  where profile.id = (select auth.uid());
$$;

create or replace function public.get_my_onboarding_progress()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'ok', true,
    'current_step', 'account',
    'resume_path', '/onboarding',
    'completed_steps', pg_catalog.jsonb_build_array()
  )
  from public.profiles as profile
  where profile.id = (select auth.uid())
    and profile.onboarding_completed_at is null;
$$;

create or replace function public.get_my_onboarding_progress_v2()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'completed', profile.onboarding_completed_at is not null,
    'active_step', case
      when profile.onboarding_completed_at is not null then 'complete'
      else 'account'
    end,
    'primary_steps', pg_catalog.jsonb_build_array(
      'account', 'work_preferences', 'safety_support', 'review'
    ),
    'completed_steps', case
      when profile.onboarding_completed_at is not null then pg_catalog.jsonb_build_array(
        'account', 'work_preferences', 'safety_support', 'review'
      )
      else pg_catalog.jsonb_build_array()
    end,
    'missing_requirements', case
      when profile.onboarding_completed_at is not null then pg_catalog.jsonb_build_array()
      else pg_catalog.jsonb_build_array('account')
    end,
    'role', profile.role::text,
    'revision', profile.updated_at,
    'replayed', false
  )
  from public.profiles as profile
  where profile.id = (select auth.uid());
$$;

revoke all on function private.ensure_my_profile()
from public, anon, authenticated;
grant execute on function private.ensure_my_profile()
to service_role;

revoke all on function public.ensure_my_profile()
from public, anon;
grant execute on function public.ensure_my_profile()
to authenticated, service_role;

revoke all on function public.get_my_profile()
from public, anon;
grant execute on function public.get_my_profile()
to authenticated, service_role;

revoke all on function public.get_my_onboarding_progress()
from public, anon;
grant execute on function public.get_my_onboarding_progress()
to authenticated, service_role;

revoke all on function public.get_my_onboarding_progress_v2()
from public, anon;
grant execute on function public.get_my_onboarding_progress_v2()
to authenticated, service_role;

comment on function public.ensure_my_profile() is
'Returns only the authenticated caller profile and creates a missing row without assigning a role or changing account status.';

comment on function public.get_my_profile() is
'Returns only the authenticated caller profile.';

comment on function public.get_my_onboarding_progress_v2() is
'Returns the initial account step until resumable onboarding writes are installed.';

