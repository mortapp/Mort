-- Recording-grounded hardening for atomic profile setup/editing and the job
-- draft/publish boundary. Existing marketplace and identity gates remain in
-- force; this migration does not activate a provider or public access.

create table if not exists private.profile_setup_requests (
  actor_id uuid not null references auth.users(id) on delete cascade,
  client_request_id uuid not null,
  payload_hash text not null check (payload_hash ~ '^[0-9a-f]{64}$'),
  response jsonb,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  primary key (actor_id, client_request_id)
);

revoke all on table private.profile_setup_requests
from public, anon, authenticated;
grant select, insert, update, delete on table private.profile_setup_requests
to service_role;

create or replace function public.save_my_profile_setup_v2(
  p_payload jsonb,
  p_client_request_id uuid,
  p_edit_existing boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_payload_hash text;
  v_prior private.profile_setup_requests%rowtype;
  v_existing public.profiles%rowtype;
  v_profile public.profiles%rowtype;
  v_progress jsonb;
  v_age jsonb;
  v_age_value integer;
  v_role public.user_role;
  v_role_text text := lower(btrim(coalesce(p_payload->>'role', '')));
  v_name text := nullif(btrim(p_payload->>'display_name'), '');
  v_username text := public.normalize_username(p_payload->>'username');
  v_username_reason text;
  v_dob date;
  v_city text := nullif(btrim(p_payload->>'city'), '');
  v_state text := nullif(upper(btrim(p_payload->>'state')), '');
  v_mode text := lower(btrim(coalesce(p_payload->>'location_setup_mode', 'city_state')));
  v_bio text := nullif(btrim(p_payload->>'bio'), '');
  v_availability text := nullif(btrim(p_payload->>'availability'), '');
  v_area text := nullif(btrim(p_payload->>'approximate_area'), '');
  v_goals text := nullif(btrim(p_payload->>'goals'), '');
  v_categories text[] := array[]::text[];
  v_account_type text := nullif(lower(btrim(p_payload->>'adult_account_type')), '');
  v_business_name text := nullif(btrim(p_payload->>'business_name'), '');
  v_preferences jsonb := '{}'::jsonb;
  v_response jsonb;
  v_failure_code text;
  v_failure_field text;
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object'
     or p_client_request_id is null then
    return jsonb_build_object('ok', false, 'code', 'profile_setup_request_invalid');
  end if;

  v_payload_hash := encode(
    extensions.digest(convert_to(p_payload::text, 'utf8'), 'sha256'),
    'hex'
  );
  select * into v_prior
  from private.profile_setup_requests request
  where request.actor_id = v_user_id
    and request.client_request_id = p_client_request_id;
  if v_prior.actor_id is not null then
    if v_prior.payload_hash <> v_payload_hash then
      return jsonb_build_object(
        'ok', false,
        'code', 'profile_setup_request_payload_mismatch'
      );
    end if;
    if v_prior.response is not null then
      return v_prior.response || jsonb_build_object('replayed', true);
    end if;
  end if;

  if v_role_text not in ('teen', 'adult', 'guardian') then
    return jsonb_build_object(
      'ok', false, 'code', 'role_not_allowed', 'field', 'role'
    );
  end if;
  v_role := v_role_text::public.user_role;
  if v_name is null or char_length(v_name) not between 2 and 80
     or v_name ~ '[[:cntrl:]]' then
    return jsonb_build_object(
      'ok', false, 'code', 'display_name_invalid', 'field', 'display_name'
    );
  end if;
  v_username_reason := public.validate_username(v_username);
  if v_username_reason is not null then
    return jsonb_build_object(
      'ok', false, 'code', 'username_invalid', 'field', 'username'
    );
  end if;
  if exists (
    select 1 from public.profiles profile
    where lower(profile.username) = v_username
      and profile.id <> v_user_id
  ) then
    return jsonb_build_object(
      'ok', false, 'code', 'username_taken', 'field', 'username'
    );
  end if;

  begin
    v_dob := (p_payload->>'dob')::date;
  exception when others then
    return jsonb_build_object(
      'ok', false, 'code', 'dob_invalid', 'field', 'dob'
    );
  end;
  v_age := public.derive_age_eligibility(v_dob);
  if not coalesce((v_age->>'ok')::boolean, false) then
    return v_age || jsonb_build_object('field', 'dob');
  end if;
  v_age_value := (v_age->>'age')::integer;
  if v_age_value < 13 then
    return jsonb_build_object(
      'ok', false, 'code', 'under_13_not_eligible', 'field', 'dob'
    );
  end if;
  if v_role = 'teen' and v_age_value not between 13 and 17 then
    return jsonb_build_object(
      'ok', false, 'code', 'teen_role_age_mismatch', 'field', 'dob'
    );
  end if;
  if v_role in ('adult', 'guardian') and v_age_value < 18 then
    return jsonb_build_object(
      'ok', false, 'code', 'adult_role_age_mismatch', 'field', 'dob'
    );
  end if;
  if v_mode not in ('city_state', 'partner_supported', 'location_deferred')
     or (v_role <> 'teen' and v_mode <> 'city_state') then
    return jsonb_build_object(
      'ok', false,
      'code', 'location_setup_mode_role_mismatch',
      'field', 'location_setup_mode'
    );
  end if;
  if v_mode = 'city_state'
     and (v_city is null or char_length(v_city) > 120
          or v_state !~ '^[A-Z]{2}$') then
    return jsonb_build_object(
      'ok', false, 'code', 'city_state_required', 'field', 'city_state'
    );
  end if;
  if v_bio is not null and char_length(v_bio) > 500 then
    return jsonb_build_object(
      'ok', false, 'code', 'bio_invalid', 'field', 'bio'
    );
  end if;
  if v_availability is not null and char_length(v_availability) > 240 then
    return jsonb_build_object(
      'ok', false, 'code', 'availability_invalid', 'field', 'availability'
    );
  end if;
  if v_area is not null and char_length(v_area) > 120 then
    return jsonb_build_object(
      'ok', false,
      'code', 'approximate_area_invalid',
      'field', 'approximate_area'
    );
  end if;
  if v_goals is not null and char_length(v_goals) > 500 then
    return jsonb_build_object(
      'ok', false, 'code', 'goals_invalid', 'field', 'goals'
    );
  end if;
  if jsonb_typeof(coalesce(p_payload->'preferred_job_categories', '[]'::jsonb)) <> 'array'
     or jsonb_array_length(coalesce(p_payload->'preferred_job_categories', '[]'::jsonb)) > 12
     or exists (
       select 1
       from jsonb_array_elements(
         coalesce(p_payload->'preferred_job_categories', '[]'::jsonb)
       ) item
       where jsonb_typeof(item) <> 'string'
         or char_length(btrim(item #>> '{}')) not between 2 and 50
     ) then
    return jsonb_build_object(
      'ok', false,
      'code', 'preferred_job_categories_invalid',
      'field', 'preferred_job_categories'
    );
  end if;
  select coalesce(array_agg(value order by value), array[]::text[])
  into v_categories
  from (
    select distinct lower(btrim(item #>> '{}')) value
    from jsonb_array_elements(
      coalesce(p_payload->'preferred_job_categories', '[]'::jsonb)
    ) item
  ) normalized;

  if v_role = 'adult' then
    if v_account_type not in ('individual', 'business') then
      return jsonb_build_object(
        'ok', false,
        'code', 'adult_account_type_invalid',
        'field', 'adult_account_type'
      );
    end if;
    if v_account_type = 'business'
       and (v_business_name is null
            or char_length(v_business_name) not between 2 and 120) then
      return jsonb_build_object(
        'ok', false,
        'code', 'business_name_invalid',
        'field', 'business_name'
      );
    end if;
    v_preferences := jsonb_build_object(
      'adult_account_type', v_account_type,
      'business_name', case
        when v_account_type = 'business' then v_business_name
        else null
      end
    );
  else
    v_account_type := null;
    v_business_name := null;
  end if;

  if v_role <> 'teen' then
    v_categories := array[]::text[];
    v_goals := null;
  end if;
  if v_role = 'guardian' then
    v_availability := null;
    v_area := null;
  end if;

  begin
    insert into private.profile_setup_requests (
      actor_id, client_request_id, payload_hash
    ) values (
      v_user_id, p_client_request_id, v_payload_hash
    ) on conflict (actor_id, client_request_id) do nothing;

    select * into v_existing
    from public.profiles profile
    where profile.id = v_user_id
    for update;

    if p_edit_existing and v_existing.id is null then
      v_failure_code := 'profile_not_found';
      raise exception 'mort_profile_setup_abort';
    end if;
    if not p_edit_existing and v_existing.onboarding_completed then
      v_failure_code := 'onboarding_already_completed';
      raise exception 'mort_profile_setup_abort';
    end if;
    if v_existing.role is not null and v_existing.role <> v_role then
      v_failure_code := 'role_immutable';
      v_failure_field := 'role';
      raise exception 'mort_profile_setup_abort';
    end if;
    if v_existing.dob is not null and v_existing.dob <> v_dob then
      v_failure_code := 'dob_immutable';
      v_failure_field := 'dob';
      raise exception 'mort_profile_setup_abort';
    end if;

    if v_existing.id is null then
      insert into public.profiles (
        id, role, display_name, dob, city, state, location_setup_mode,
        payment_preference, onboarding_completed, bio, availability,
        preferred_job_categories, approximate_area, goals
      ) values (
        v_user_id, v_role, v_name, v_dob,
        case when v_mode = 'city_state' then v_city else null end,
        case when v_mode = 'city_state' then v_state else null end,
        v_mode, 'none', false, v_bio, v_availability, v_categories, v_area,
        v_goals
      ) returning * into v_profile;
    else
      update public.profiles
      set role = coalesce(role, v_role),
          display_name = v_name,
          dob = coalesce(dob, v_dob),
          city = case when v_mode = 'city_state' then v_city else null end,
          state = case when v_mode = 'city_state' then v_state else null end,
          location_setup_mode = v_mode,
          bio = v_bio,
          availability = v_availability,
          preferred_job_categories = v_categories,
          approximate_area = v_area,
          goals = v_goals,
          updated_at = now()
      where id = v_user_id
      returning * into v_profile;
    end if;

    if v_role = 'teen' then
      insert into public.teen_profiles(user_id)
      values (v_user_id) on conflict (user_id) do nothing;
    elsif v_role = 'adult' then
      insert into public.adult_profiles(user_id)
      values (v_user_id) on conflict (user_id) do nothing;
    else
      insert into public.guardian_profiles(user_id)
      values (v_user_id) on conflict (user_id) do nothing;
    end if;

    if v_existing.username is distinct from v_username then
      perform public.request_username_change(v_username);
    end if;

    if not p_edit_existing then
      v_progress := public.save_my_onboarding_progress(
        'profile', v_preferences, gen_random_uuid()
      );
      if coalesce((v_progress->>'ok')::boolean, false) is not true then
        v_failure_code := coalesce(
          v_progress->>'code', 'onboarding_update_failed'
        );
        raise exception 'mort_profile_setup_abort';
      end if;
    end if;

    insert into public.profile_update_audit_events (
      user_id, actor_id, operation, updated_fields, client_request_id
    ) values (
      v_user_id,
      v_user_id,
      case when p_edit_existing then 'profile_updated' else 'onboarding_saved' end,
      array[
        'display_name', 'username', 'city', 'state', 'location_setup_mode',
        'bio', 'availability', 'preferred_job_categories',
        'approximate_area', 'goals'
      ],
      p_client_request_id
    );

    select * into v_profile
    from public.profiles profile
    where profile.id = v_user_id;
    v_response := jsonb_build_object(
      'ok', true,
      'replayed', false,
      'editing', p_edit_existing,
      'profile', to_jsonb(v_profile),
      'onboarding_progress', v_progress
    );
    update private.profile_setup_requests
    set response = v_response, completed_at = now()
    where actor_id = v_user_id
      and client_request_id = p_client_request_id;
    return v_response;
  exception when others then
    if sqlerrm <> 'mort_profile_setup_abort' then
      if sqlerrm ilike '%already taken%' then
        v_failure_code := 'username_taken';
        v_failure_field := 'username';
      elsif sqlerrm ilike '%username%' then
        v_failure_code := 'username_change_unavailable';
        v_failure_field := 'username';
      else
        v_failure_code := 'profile_setup_failed';
      end if;
    end if;
    return jsonb_strip_nulls(jsonb_build_object(
      'ok', false,
      'code', coalesce(v_failure_code, 'profile_setup_failed'),
      'field', v_failure_field
    ));
  end;
end;
$$;

revoke all on function public.save_my_profile_setup_v2(jsonb, uuid, boolean)
from public, anon;
grant execute on function public.save_my_profile_setup_v2(jsonb, uuid, boolean)
to authenticated, service_role;

comment on function public.save_my_profile_setup_v2(jsonb, uuid, boolean) is
'Caller-bound atomic profile setup/settings write. Role and DOB remain immutable; role-specific fields are normalized server-side.';

-- Add coded preflight validation before the already verified job write path.
-- The closed-pilot trigger remains authoritative and may convert an attempted
-- open publication into pending_review with applications closed.
create or replace function public.save_job_draft_or_publish(
  p_job_id uuid,
  p_client_request_id uuid,
  p_payload jsonb,
  p_publish boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_offered_amount integer;
  v_duration integer;
  v_workers integer;
  v_radius integer;
  v_min_age integer;
  v_max_age integer;
  v_zip text;
  v_environment text;
  v_location_type text;
  v_special_instructions text;
  v_proof_expected boolean;
  v_result jsonb;
  v_job_id uuid;
  v_job public.jobs%rowtype;
  v_transportation_methods text[];
  v_transportation_notes text;
  v_physical_requirements text[];
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object'
     or (p_job_id is null and p_client_request_id is null) then
    return jsonb_build_object('ok', false, 'code', 'invalid_job_values');
  end if;

  begin
    v_offered_amount := nullif(p_payload->>'adult_job_amount_cents', '')::integer;
    v_duration := nullif(p_payload->>'estimated_duration_minutes', '')::integer;
    v_workers := coalesce(nullif(p_payload->>'workers_needed', '')::integer, 1);
    v_radius := nullif(p_payload->>'travel_radius_miles', '')::integer;
    v_min_age := coalesce(nullif(p_payload->>'teen_min_age', '')::integer, 13);
    v_max_age := coalesce(nullif(p_payload->>'teen_max_age', '')::integer, 17);
    v_proof_expected := coalesce((p_payload->>'proof_expected')::boolean, false);
  exception when others then
    return jsonb_build_object('ok', false, 'code', 'invalid_job_values');
  end;

  if (v_duration is not null and v_duration not between 15 and 1440)
     or (p_publish and v_duration is null) then
    return jsonb_build_object(
      'ok', false, 'code', 'invalid_job_duration',
      'field', 'estimated_duration_minutes'
    );
  end if;
  if v_workers not between 1 and 10 then
    return jsonb_build_object(
      'ok', false, 'code', 'invalid_job_workers', 'field', 'workers_needed'
    );
  end if;
  if v_radius is not null and v_radius not between 1 and 100 then
    return jsonb_build_object(
      'ok', false, 'code', 'invalid_job_travel_radius',
      'field', 'travel_radius_miles'
    );
  end if;
  if v_min_age not between 13 and 17
     or v_max_age not between v_min_age and 17 then
    return jsonb_build_object(
      'ok', false, 'code', 'invalid_job_age_range',
      'field', 'teen_min_age'
    );
  end if;

  v_zip := nullif(btrim(p_payload->>'zip_code'), '');
  if v_zip is not null and v_zip !~ '^[0-9]{5}(-[0-9]{4})?$' then
    return jsonb_build_object(
      'ok', false, 'code', 'invalid_job_zip', 'field', 'zip_code'
    );
  end if;
  v_environment := lower(coalesce(nullif(btrim(p_payload->>'work_environment'), ''), 'unspecified'));
  if v_environment not in ('indoor', 'outdoor', 'both', 'unspecified') then
    return jsonb_build_object(
      'ok', false, 'code', 'invalid_job_environment',
      'field', 'work_environment'
    );
  end if;
  v_location_type := lower(coalesce(nullif(btrim(p_payload->>'location_type'), ''), 'unspecified'));
  if v_location_type not in ('public', 'private_residence', 'business', 'unspecified') then
    return jsonb_build_object(
      'ok', false, 'code', 'invalid_job_location_type',
      'field', 'location_type'
    );
  end if;

  if jsonb_typeof(coalesce(p_payload->'physical_requirements', '[]'::jsonb)) <> 'array'
     or jsonb_array_length(coalesce(p_payload->'physical_requirements', '[]'::jsonb)) > 6 then
    return jsonb_build_object(
      'ok', false, 'code', 'invalid_job_physical_requirements',
      'field', 'physical_requirements'
    );
  end if;
  select coalesce(array_agg(requirement order by requirement), array[]::text[])
  into v_physical_requirements
  from (
    select distinct lower(btrim(item #>> '{}')) requirement
    from jsonb_array_elements(
      coalesce(p_payload->'physical_requirements', '[]'::jsonb)
    ) item
    where jsonb_typeof(item) = 'string'
  ) normalized;
  if exists (
       select 1 from unnest(v_physical_requirements) requirement
       where requirement not in (
         'light lifting', 'standing', 'outdoor work', 'stairs', 'bending',
         'no physical requirement'
       )
     )
     or (
       'no physical requirement' = any(v_physical_requirements)
       and cardinality(v_physical_requirements) > 1
     ) then
    return jsonb_build_object(
      'ok', false, 'code', 'invalid_job_physical_requirements',
      'field', 'physical_requirements'
    );
  end if;
  v_special_instructions := nullif(btrim(p_payload->>'special_instructions'), '');
  if v_proof_expected
     and (v_special_instructions is null
          or char_length(v_special_instructions) < 10) then
    return jsonb_build_object(
      'ok', false, 'code', 'job_proof_instructions_required',
      'field', 'special_instructions'
    );
  end if;

  if v_offered_amount is not null then
    if v_offered_amount <= 0 or v_offered_amount > 10000000 then
      return jsonb_build_object(
        'ok', false, 'code', 'invalid_job_payment',
        'field', 'adult_job_amount_cents'
      );
    end if;
  elsif p_publish then
    return jsonb_build_object(
      'ok', false, 'code', 'invalid_job_payment',
      'field', 'adult_job_amount_cents'
    );
  end if;

  if p_payload ? 'acceptable_transportation_methods' then
    if jsonb_typeof(p_payload->'acceptable_transportation_methods') <> 'array'
       or jsonb_array_length(p_payload->'acceptable_transportation_methods')
          not between 1 and 6 then
      return jsonb_build_object(
        'ok', false, 'code', 'job_transportation_invalid',
        'field', 'acceptable_transportation_methods'
      );
    end if;
    select coalesce(array_agg(method order by method), array[]::text[])
    into v_transportation_methods
    from (
      select distinct lower(btrim(item #>> '{}')) method
      from jsonb_array_elements(
        p_payload->'acceptable_transportation_methods'
      ) item
      where jsonb_typeof(item) = 'string'
        and btrim(item #>> '{}') <> ''
    ) normalized;
  else
    v_transportation_methods := array[
      'walking', 'bicycle', 'car', 'public_transit', 'rideshare', 'other'
    ]::text[];
  end if;

  if cardinality(v_transportation_methods) not between 1 and 6
     or exists (
       select 1 from unnest(v_transportation_methods) method
       where method not in (
         'walking', 'bicycle', 'car', 'public_transit', 'rideshare', 'other'
       )
     ) then
    return jsonb_build_object(
      'ok', false, 'code', 'job_transportation_invalid',
      'field', 'acceptable_transportation_methods'
    );
  end if;

  v_transportation_notes := nullif(
    btrim(p_payload->>'transportation_considerations'), ''
  );
  if v_transportation_notes is not null and (
    char_length(v_transportation_notes) > 500
    or lower(v_transportation_notes) ~* '([a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}|\+?[0-9][0-9() .\-]{8,}[0-9]|@[a-z0-9_]{2,}|\$[a-z][a-z0-9_]*)'
  ) then
    return jsonb_build_object(
      'ok', false, 'code', 'job_transportation_invalid',
      'field', 'transportation_considerations'
    );
  end if;

  p_payload := (
    p_payload
    - 'pay_amount_cents'
    - 'mort_service_fee_cents'
  ) || jsonb_build_object(
    'pay_amount_cents', v_offered_amount,
    'physical_requirements', to_jsonb(v_physical_requirements)
  );

  v_result := public.save_job_draft_or_publish_without_fee_v1(
    p_job_id, p_client_request_id, p_payload, p_publish
  );
  if coalesce((v_result->>'ok')::boolean, false) is not true then
    return v_result;
  end if;

  begin
    v_job_id := (v_result#>>'{job,id}')::uuid;
  exception when others then
    return jsonb_build_object('ok', false, 'code', 'invalid_job_response');
  end;

  update public.jobs
  set adult_job_amount_cents = v_offered_amount,
      mort_service_fee_cents = case
        when v_offered_amount is null then null
        else 0
      end,
      pay_amount_cents = v_offered_amount,
      acceptable_transportation_methods = v_transportation_methods,
      transportation_considerations = v_transportation_notes,
      updated_at = now()
  where id = v_job_id
    and (poster_id = auth.uid() or public.is_admin())
  returning * into v_job;

  if v_job.id is null then
    return jsonb_build_object('ok', false, 'code', 'unknown_permission_failure');
  end if;

  return (v_result - 'job') || jsonb_build_object(
    'job', to_jsonb(v_job),
    'publication_state', case
      when not p_publish then 'draft'
      when v_job.status = 'open' and v_job.applications_open then 'open'
      when v_job.status = 'pending_review' then 'pending_review'
      else 'not_open'
    end
  );
end;
$$;

revoke all on function public.save_job_draft_or_publish(
  uuid, uuid, jsonb, boolean
) from public, anon;
grant execute on function public.save_job_draft_or_publish(
  uuid, uuid, jsonb, boolean
) to authenticated, service_role;

comment on function public.save_job_draft_or_publish(uuid, uuid, jsonb, boolean)
is 'Idempotent caller-bound job draft/publish RPC with coded preflight validation and closed-pilot fail-closed publication state.';
