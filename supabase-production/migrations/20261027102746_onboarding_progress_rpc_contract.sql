-- Match the Flutter onboarding-v2 response contract. This migration does not
-- advance onboarding; the write RPCs remain unavailable until their backend
-- requirements and legal-document dependencies are implemented.

create or replace function public.get_my_onboarding_progress_v2()
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_profile public.profiles%rowtype;
begin
  if (select auth.uid()) is null then
    return pg_catalog.jsonb_build_object(
      'ok', false,
      'code', 'authentication_required'
    );
  end if;

  select profile.*
  into v_profile
  from public.profiles as profile
  where profile.id = (select auth.uid());

  if not found then
    return pg_catalog.jsonb_build_object(
      'ok', false,
      'code', 'profile_not_found'
    );
  end if;

  return pg_catalog.jsonb_build_object(
    'ok', true,
    'completed', v_profile.onboarding_completed_at is not null,
    'active_step', case
      when v_profile.onboarding_completed_at is not null then 'complete'
      else 'account'
    end,
    'primary_steps', pg_catalog.jsonb_build_array(
      'account', 'work_preferences', 'safety_support', 'review'
    ),
    'completed_steps', case
      when v_profile.onboarding_completed_at is not null then
        pg_catalog.jsonb_build_array(
          'account', 'work_preferences', 'safety_support', 'review'
        )
      else pg_catalog.jsonb_build_array()
    end,
    'missing_requirements', case
      when v_profile.onboarding_completed_at is not null then
        pg_catalog.jsonb_build_array()
      else pg_catalog.jsonb_build_array('account')
    end,
    'role', v_profile.role::text,
    'revision', v_profile.updated_at,
    'replayed', false
  );
end;
$$;

revoke all on function public.get_my_onboarding_progress_v2()
from public, anon;
grant execute on function public.get_my_onboarding_progress_v2()
to authenticated, service_role;

