-- Keep the public RPC surface invoker-scoped. Only the private caller-bound
-- insert helper runs with elevated privileges.

grant usage on schema private to authenticated, service_role;
grant execute on function private.ensure_my_profile()
to authenticated, service_role;

create or replace function public.ensure_my_profile()
returns setof public.profiles
language sql
volatile
security invoker
set search_path = ''
as $$
  select * from private.ensure_my_profile();
$$;

create or replace function public.get_my_profile()
returns setof public.profiles
language sql
stable
security invoker
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
security invoker
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
security invoker
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

revoke all on function public.ensure_my_profile()
from public, anon;
revoke all on function public.get_my_profile()
from public, anon;
revoke all on function public.get_my_onboarding_progress()
from public, anon;
revoke all on function public.get_my_onboarding_progress_v2()
from public, anon;

grant execute on function public.ensure_my_profile()
to authenticated, service_role;
grant execute on function public.get_my_profile()
to authenticated, service_role;
grant execute on function public.get_my_onboarding_progress()
to authenticated, service_role;
grant execute on function public.get_my_onboarding_progress_v2()
to authenticated, service_role;

