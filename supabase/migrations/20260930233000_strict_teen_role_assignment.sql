-- The age RPC remains unchanged. Teen role assignment now requires an exact
-- current school-email binding before a MORT teen profile can be created.
create or replace function public.save_my_onboarding_role(
  p_role text,
  p_client_request_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile public.profiles%rowtype;
  v_role public.user_role;
  v_age integer;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if lower(btrim(coalesce(p_role, ''))) not in ('teen', 'adult', 'guardian') then
    return jsonb_build_object('ok', false, 'code', 'role_not_allowed');
  end if;
  v_role := lower(btrim(p_role))::public.user_role;
  if p_client_request_id is not null and exists (
    select 1 from public.onboarding_progress_events event
    where event.user_id = auth.uid() and event.client_request_id = p_client_request_id
  ) then
    return public.get_my_onboarding_progress();
  end if;

  select * into v_profile from public.profiles where id = auth.uid() for update;
  if v_profile.id is null or v_profile.dob is null then
    return jsonb_build_object('ok', false, 'code', 'saved_dob_required');
  end if;
  if v_profile.onboarding_completed then
    return jsonb_build_object('ok', false, 'code', 'onboarding_already_completed');
  end if;
  if v_profile.role is not null and v_profile.role <> v_role then
    return jsonb_build_object('ok', false, 'code', 'role_immutable');
  end if;
  v_age := extract(year from age(current_date, v_profile.dob))::integer;
  if v_role = 'teen' and v_age not between 13 and 17 then
    return jsonb_build_object('ok', false, 'code', 'teen_role_age_mismatch');
  end if;
  if v_role in ('adult', 'guardian') and v_age < 18 then
    return jsonb_build_object('ok', false, 'code', 'adult_role_age_mismatch');
  end if;

  if v_role = 'teen'
     and not private.has_current_teen_school_email(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'verified_school_email_required');
  end if;

  update public.profiles set role = coalesce(role, v_role), updated_at = now()
  where id = auth.uid();
  if v_role = 'teen' then
    insert into public.teen_profiles(user_id) values (auth.uid()) on conflict do nothing;
  elsif v_role = 'adult' then
    insert into public.adult_profiles(user_id) values (auth.uid()) on conflict do nothing;
  else
    insert into public.guardian_profiles(user_id) values (auth.uid()) on conflict do nothing;
  end if;
  insert into public.onboarding_progress(user_id, current_step, completed_steps)
  values (auth.uid(), 'profile', array['age', 'role'])
  on conflict (user_id) do update set
    current_step = case
      when array_position(
        array['age', 'role', 'profile', 'skills', 'availability', 'transportation',
              'payment', 'guardian', 'preferences', 'safety', 'review', 'complete']::text[],
        public.onboarding_progress.current_step
      ) > 3 then public.onboarding_progress.current_step
      else 'profile'
    end,
    completed_steps = array(
      select distinct value
      from unnest(public.onboarding_progress.completed_steps || array['age', 'role']) value
      order by value
    ),
    updated_at = now();
  insert into public.onboarding_progress_events(
    user_id, event_type, step, changed_fields, client_request_id
  ) values (auth.uid(), 'role_saved', 'role', array['role'], p_client_request_id);
  return public.get_my_onboarding_progress();
exception when unique_violation then
  return public.get_my_onboarding_progress();
end;
$$;
