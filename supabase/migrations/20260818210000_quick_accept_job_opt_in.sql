-- Fix: public.jobs has zero direct UPDATE RLS policies (writes are
-- RPC-mediated only, confirmed empirically -- a poster's own direct
-- .from('jobs').update(...) silently affects zero rows). There was
-- therefore no real way for a poster to opt a job into
-- quick_accept_eligible. Extend the existing save_job_draft_or_publish
-- RPC exactly the way it already handles acceptable_transportation_methods
-- -- validate the optional payload field, then persist it in the same
-- explicit-ownership-checked UPDATE it already performs.
--
-- quick_accept_job_v1's atomic-claim model only makes sense for a
-- single-worker job (it closes applications on the first winner), so
-- quick_accept_eligible is only allowed when workers_needed = 1.

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
  v_quick_accept_eligible boolean;
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
    v_quick_accept_eligible := coalesce((p_payload->>'quick_accept_eligible')::boolean, false);
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
  if v_quick_accept_eligible and v_workers <> 1 then
    return jsonb_build_object(
      'ok', false, 'code', 'quick_accept_requires_single_worker',
      'field', 'quick_accept_eligible'
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
      quick_accept_eligible = v_quick_accept_eligible,
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
