-- General teen transportation preferences for matching. These fields must never
-- contain an exact address or imply that transportation is guaranteed.

alter table public.profiles
  add column if not exists transportation_methods text[] not null default array[]::text[],
  add column if not exists max_travel_distance_miles integer,
  add column if not exists max_travel_minutes integer,
  add column if not exists walking_distance_only boolean not null default false,
  add column if not exists guardian_transportation_possible boolean not null default false;

alter table public.profiles
  drop constraint if exists profiles_transportation_methods_allowed,
  add constraint profiles_transportation_methods_allowed check (
    cardinality(transportation_methods) <= 6
    and transportation_methods <@ array[
      'walking', 'bicycle', 'car', 'public_transit', 'rideshare', 'other'
    ]::text[]
  ),
  drop constraint if exists profiles_max_travel_distance_range,
  add constraint profiles_max_travel_distance_range check (
    max_travel_distance_miles is null
    or max_travel_distance_miles between 1 and 50
  ),
  drop constraint if exists profiles_max_travel_minutes_range,
  add constraint profiles_max_travel_minutes_range check (
    max_travel_minutes is null
    or max_travel_minutes between 5 and 180
  ),
  drop constraint if exists profiles_walking_distance_consistent,
  add constraint profiles_walking_distance_consistent check (
    not walking_distance_only or 'walking' = any(transportation_methods)
  );

comment on column public.profiles.transportation_methods is
  'General, non-guaranteed transportation methods used for teen job matching.';
comment on column public.profiles.max_travel_distance_miles is
  'Maximum comfortable general travel distance. Never an exact location.';
comment on column public.profiles.max_travel_minutes is
  'Maximum comfortable general travel time. Never guaranteed availability.';

create or replace function public.save_my_transportation_preferences(
  p_methods text[],
  p_max_distance_miles integer default null,
  p_max_travel_minutes integer default null,
  p_walking_distance_only boolean default false,
  p_guardian_transportation_possible boolean default false,
  p_client_request_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_profile public.profiles%rowtype;
  v_methods text[];
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;

  if p_client_request_id is not null and exists (
    select 1
    from public.profile_update_audit_events event
    where event.actor_id = v_user_id
      and event.client_request_id = p_client_request_id
  ) then
    select * into v_profile from public.profiles where id = v_user_id;
    return jsonb_build_object(
      'ok', true,
      'replayed', true,
      'profile', to_jsonb(v_profile)
    );
  end if;

  select coalesce(array_agg(method order by method), array[]::text[])
  into v_methods
  from (
    select distinct lower(btrim(value)) as method
    from unnest(coalesce(p_methods, array[]::text[])) as supplied(value)
    where btrim(value) <> ''
  ) normalized;

  if cardinality(v_methods) = 0 or cardinality(v_methods) > 6
     or exists (
       select 1
       from unnest(v_methods) method
       where method not in (
         'walking', 'bicycle', 'car', 'public_transit', 'rideshare', 'other'
       )
     ) then
    return jsonb_build_object(
      'ok', false,
      'code', 'transportation_methods_invalid'
    );
  end if;

  if p_max_distance_miles is not null
     and p_max_distance_miles not between 1 and 50 then
    return jsonb_build_object(
      'ok', false,
      'code', 'max_travel_distance_invalid'
    );
  end if;

  if p_max_travel_minutes is not null
     and p_max_travel_minutes not between 5 and 180 then
    return jsonb_build_object(
      'ok', false,
      'code', 'max_travel_minutes_invalid'
    );
  end if;

  if coalesce(p_walking_distance_only, false)
     and not ('walking' = any(v_methods)) then
    return jsonb_build_object(
      'ok', false,
      'code', 'walking_method_required'
    );
  end if;

  select * into v_profile
  from public.profiles
  where id = v_user_id
  for update;

  if v_profile.id is null then
    return jsonb_build_object('ok', false, 'code', 'profile_not_found');
  end if;
  if v_profile.role <> 'teen'::public.user_role then
    return jsonb_build_object('ok', false, 'code', 'teen_profile_required');
  end if;

  update public.profiles
  set transportation_methods = v_methods,
      max_travel_distance_miles = p_max_distance_miles,
      max_travel_minutes = p_max_travel_minutes,
      walking_distance_only = coalesce(p_walking_distance_only, false),
      guardian_transportation_possible =
        coalesce(p_guardian_transportation_possible, false),
      updated_at = now()
  where id = v_user_id
  returning * into v_profile;

  insert into public.profile_update_audit_events (
    user_id,
    actor_id,
    operation,
    updated_fields,
    client_request_id
  ) values (
    v_user_id,
    v_user_id,
    'profile_updated',
    array[
      'transportation_methods',
      'max_travel_distance_miles',
      'max_travel_minutes',
      'walking_distance_only',
      'guardian_transportation_possible'
    ],
    p_client_request_id
  );

  return jsonb_build_object(
    'ok', true,
    'replayed', false,
    'profile', to_jsonb(v_profile)
  );
exception
  when unique_violation then
    if p_client_request_id is not null and exists (
      select 1
      from public.profile_update_audit_events event
      where event.actor_id = v_user_id
        and event.client_request_id = p_client_request_id
    ) then
      select * into v_profile from public.profiles where id = v_user_id;
      return jsonb_build_object(
        'ok', true,
        'replayed', true,
        'profile', to_jsonb(v_profile)
      );
    end if;
    raise;
end;
$$;

revoke execute on function public.save_my_transportation_preferences(
  text[], integer, integer, boolean, boolean, uuid
) from public, anon;
grant execute on function public.save_my_transportation_preferences(
  text[], integer, integer, boolean, boolean, uuid
) to authenticated, service_role;
