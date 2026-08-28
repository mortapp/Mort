-- Keep the verified job safety behavior while making the empty reasons array
-- unambiguous to PostgreSQL's function checker.
create or replace function public.save_job_draft_or_publish(
  p_job_id uuid,
  p_client_request_id uuid,
  p_payload jsonb,
  p_publish boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile public.profiles%rowtype;
  v_job public.jobs%rowtype;
  v_title text := btrim(coalesce(p_payload->>'title', ''));
  v_summary text := btrim(coalesce(p_payload->>'summary', ''));
  v_description text := btrim(coalesce(p_payload->>'description', ''));
  v_category text := lower(btrim(coalesce(p_payload->>'category', '')));
  v_area text := btrim(coalesce(p_payload->>'location_text', ''));
  v_city text := btrim(coalesce(p_payload->>'city', ''));
  v_state text := upper(btrim(coalesce(p_payload->>'state', '')));
  v_schedule_type text := lower(coalesce(nullif(p_payload->>'schedule_type', ''), 'flexible'));
  v_starts_at timestamptz;
  v_ends_at timestamptz;
  v_deadline_at timestamptz;
  v_expires_at timestamptz;
  v_pay integer;
  v_guardian_explicit boolean := coalesce((p_payload->>'requires_guardian_approval')::boolean, false);
  v_guardian_policy boolean := false;
  v_is_new boolean := false;
  v_was_published boolean := false;
  v_content text;
  v_blocked_terms text[] := array[]::text[];
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;

  select * into v_profile from public.profiles where id = auth.uid();
  if v_profile.id is null or v_profile.role not in ('adult', 'admin') then
    return jsonb_build_object('ok', false, 'code', 'user_role_not_allowed');
  end if;
  if not public.is_profile_active(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'user_account_restricted');
  end if;
  if p_job_id is null and p_client_request_id is null then
    return jsonb_build_object('ok', false, 'code', 'invalid_client_request');
  end if;

  begin
    v_starts_at := nullif(p_payload->>'starts_at', '')::timestamptz;
    v_ends_at := nullif(p_payload->>'ends_at', '')::timestamptz;
    v_deadline_at := nullif(p_payload->>'deadline_at', '')::timestamptz;
    v_expires_at := nullif(p_payload->>'expires_at', '')::timestamptz;
    v_pay := nullif(p_payload->>'pay_amount_cents', '')::integer;
  exception when others then
    return jsonb_build_object('ok', false, 'code', 'invalid_job_values');
  end;

  if p_job_id is not null then
    select * into v_job from public.jobs where id = p_job_id;
    if v_job.id is null then
      return jsonb_build_object('ok', false, 'code', 'job_not_found');
    end if;
    if v_job.poster_id <> auth.uid() and not public.is_admin() then
      return jsonb_build_object('ok', false, 'code', 'unknown_permission_failure');
    end if;
    if v_job.status not in ('draft', 'open', 'paused') then
      return jsonb_build_object('ok', false, 'code', 'job_not_editable');
    end if;
    v_was_published := v_job.published_at is not null;
  elsif p_client_request_id is not null then
    select * into v_job
    from public.jobs
    where poster_id = auth.uid() and client_request_id = p_client_request_id;
  end if;

  if p_publish then
    if v_profile.verification_status <> 'approved' and not public.is_admin() then
      return jsonb_build_object('ok', false, 'code', 'poster_verification_required');
    end if;
    if char_length(v_title) not between 5 and 80 then
      return jsonb_build_object('ok', false, 'code', 'invalid_job_title');
    end if;
    if char_length(v_summary) not between 10 and 240 then
      return jsonb_build_object('ok', false, 'code', 'invalid_job_summary');
    end if;
    if char_length(v_description) not between 20 and 4000 then
      return jsonb_build_object('ok', false, 'code', 'invalid_job_description');
    end if;
    if v_category not in (
      'cleaning', 'lawn care', 'dog walking', 'pet care', 'snow removal',
      'trash and recycling', 'moving/light lifting', 'tutoring',
      'technology help', 'organization', 'errands', 'event setup',
      'car washing', 'painting/light maintenance',
      'delivery where legally appropriate', 'other safe local work'
    ) then
      return jsonb_build_object('ok', false, 'code', 'unsafe_job_category');
    end if;
    if v_city = '' or v_state !~ '^[A-Z]{2}$' or v_area = '' then
      return jsonb_build_object('ok', false, 'code', 'invalid_job_location');
    end if;
    if v_pay is null or v_pay <= 0 then
      return jsonb_build_object('ok', false, 'code', 'invalid_job_payment');
    end if;
    if v_schedule_type = 'exact' and v_starts_at is null then
      return jsonb_build_object('ok', false, 'code', 'invalid_job_schedule');
    end if;
    if v_starts_at is not null and v_starts_at <= now() then
      return jsonb_build_object('ok', false, 'code', 'job_start_time_passed');
    end if;
    if v_ends_at is not null and (v_starts_at is null or v_ends_at <= v_starts_at) then
      return jsonb_build_object('ok', false, 'code', 'invalid_job_schedule');
    end if;
    if v_deadline_at is not null and v_deadline_at <= now() then
      return jsonb_build_object('ok', false, 'code', 'job_expired');
    end if;

    v_content := lower(v_title || ' ' || v_summary || ' ' || v_description || ' ' || coalesce(p_payload->>'special_instructions', ''));
    if v_content ~ '(\mroof\M|firearm|\mgun\M|hazardous chemical|adult entertainment|gift card|cryptocurrency|crypto payment|illegal activity|overnight work|alcohol handling|drug handling)' then
      v_blocked_terms := array['prohibited_or_high_risk_work'];
    end if;
    if v_content ~* '([a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}|\+?[0-9][0-9() .\-]{8,}[0-9]|@[a-z0-9_]{2,}|\$[a-z][a-z0-9_]*)' then
      v_blocked_terms := array_append(v_blocked_terms, 'private_contact_or_payment_handle');
    end if;
    if cardinality(v_blocked_terms) > 0 then
      insert into public.ai_moderation_events (
        user_id, resource_type, resource_id, content, detected_flags,
        fallback_used, status
      ) values (
        auth.uid(), 'job_draft', coalesce(v_job.id::text, p_client_request_id::text),
        left(v_content, 4000), v_blocked_terms, true, 'blocked'
      );
      return jsonb_build_object('ok', false, 'code', 'unsafe_job_content', 'reasons', v_blocked_terms);
    end if;

    if not v_was_published and not public.is_action_allowed('job_post_create') then
      return jsonb_build_object('ok', false, 'code', 'application_limit_reached');
    end if;

    select coalesce(jgp.guardian_approval_required_for_job, false)
    into v_guardian_policy
    from public.jurisdiction_guardian_policies jgp
    where jgp.enabled
      and jgp.country_code = 'US'
      and (jgp.region_code = v_state or jgp.region_code is null)
      and jgp.effective_from <= now()
      and (jgp.effective_until is null or jgp.effective_until > now())
    order by (jgp.region_code is not null) desc, jgp.effective_from desc
    limit 1;
  end if;

  if v_job.id is null then
    v_is_new := true;
    insert into public.jobs (
      poster_id, title, summary, description, category, location_text, city, state,
      pay_amount_cents, pay_label, teen_min_age, teen_max_age,
      requires_guardian_approval, guardian_requirement_explicit, status,
      estimated_duration_minutes, workers_needed, experience_level, skills_needed,
      equipment_provided, equipment_worker_brings, physical_requirements,
      proof_expected, special_instructions, schedule_type, starts_at, ends_at,
      deadline_at, recurring, recurrence_rule, timezone, urgency, neighborhood,
      zip_code, travel_radius_miles, work_environment, location_type, payment_type,
      payment_method, payment_timing, tip_allowed, adult_supervision_present,
      verification_requirement, safety_notes, safety_scan_status,
      safety_scan_reasons, applications_open, is_test, created_by_qa,
      environment_tag, client_request_id, published_at, expires_at
    ) values (
      auth.uid(), coalesce(nullif(v_title, ''), 'Untitled draft'),
      nullif(v_summary, ''), coalesce(nullif(v_description, ''), 'Draft details not completed.'),
      coalesce(nullif(v_category, ''), 'other safe local work'),
      coalesce(nullif(v_area, ''), 'General area'),
      coalesce(nullif(v_city, ''), coalesce(v_profile.city, 'Draft city')),
      case when v_state ~ '^[A-Z]{2}$' then v_state else coalesce(v_profile.state, 'IN') end,
      v_pay, p_payload->>'pay_label',
      coalesce((p_payload->>'teen_min_age')::integer, 13),
      coalesce((p_payload->>'teen_max_age')::integer, 17),
      case when p_publish then v_guardian_explicit or v_guardian_policy else v_guardian_explicit end,
      v_guardian_explicit,
      case when p_publish then 'open'::public.job_status else 'draft'::public.job_status end,
      nullif(p_payload->>'estimated_duration_minutes', '')::integer,
      coalesce((p_payload->>'workers_needed')::integer, 1),
      coalesce(nullif(p_payload->>'experience_level', ''), 'any'),
      array(select jsonb_array_elements_text(coalesce(p_payload->'skills_needed', '[]'::jsonb))),
      nullif(p_payload->>'equipment_provided', ''),
      nullif(p_payload->>'equipment_worker_brings', ''),
      array(select jsonb_array_elements_text(coalesce(p_payload->'physical_requirements', '[]'::jsonb))),
      coalesce((p_payload->>'proof_expected')::boolean, false),
      nullif(p_payload->>'special_instructions', ''), v_schedule_type,
      v_starts_at, v_ends_at, v_deadline_at,
      coalesce((p_payload->>'recurring')::boolean, false),
      nullif(p_payload->>'recurrence_rule', ''),
      coalesce(nullif(p_payload->>'timezone', ''), 'America/Indianapolis'),
      coalesce(nullif(p_payload->>'urgency', ''), 'normal'),
      nullif(p_payload->>'neighborhood', ''), nullif(p_payload->>'zip_code', ''),
      nullif(p_payload->>'travel_radius_miles', '')::integer,
      coalesce(nullif(p_payload->>'work_environment', ''), 'unspecified'),
      coalesce(nullif(p_payload->>'location_type', ''), 'unspecified'),
      coalesce(nullif(p_payload->>'payment_type', ''), 'fixed'),
      coalesce(nullif(p_payload->>'payment_method', ''), 'flexible'),
      coalesce(nullif(p_payload->>'payment_timing', ''), 'after_completion'),
      coalesce((p_payload->>'tip_allowed')::boolean, false),
      coalesce((p_payload->>'adult_supervision_present')::boolean, false),
      coalesce(nullif(p_payload->>'verification_requirement', ''), 'none'),
      nullif(p_payload->>'safety_notes', ''), 'clean', '{}', p_publish,
      v_profile.is_test_account, v_profile.is_test_account,
      case when v_profile.is_test_account then 'qa' else 'production' end,
      p_client_request_id,
      case when p_publish then now() else null end,
      v_expires_at
    ) returning * into v_job;
  else
    update public.jobs
    set title = coalesce(nullif(v_title, ''), title),
        summary = nullif(v_summary, ''),
        description = coalesce(nullif(v_description, ''), description),
        category = coalesce(nullif(v_category, ''), category),
        location_text = coalesce(nullif(v_area, ''), location_text),
        city = coalesce(nullif(v_city, ''), city),
        state = case when v_state ~ '^[A-Z]{2}$' then v_state else state end,
        pay_amount_cents = v_pay,
        pay_label = nullif(p_payload->>'pay_label', ''),
        teen_min_age = coalesce((p_payload->>'teen_min_age')::integer, teen_min_age),
        teen_max_age = coalesce((p_payload->>'teen_max_age')::integer, teen_max_age),
        requires_guardian_approval = case when p_publish then v_guardian_explicit or v_guardian_policy else v_guardian_explicit end,
        guardian_requirement_explicit = v_guardian_explicit,
        status = case when p_publish then 'open'::public.job_status else status end,
        estimated_duration_minutes = nullif(p_payload->>'estimated_duration_minutes', '')::integer,
        workers_needed = coalesce((p_payload->>'workers_needed')::integer, workers_needed),
        experience_level = coalesce(nullif(p_payload->>'experience_level', ''), experience_level),
        skills_needed = array(select jsonb_array_elements_text(coalesce(p_payload->'skills_needed', '[]'::jsonb))),
        equipment_provided = nullif(p_payload->>'equipment_provided', ''),
        equipment_worker_brings = nullif(p_payload->>'equipment_worker_brings', ''),
        physical_requirements = array(select jsonb_array_elements_text(coalesce(p_payload->'physical_requirements', '[]'::jsonb))),
        proof_expected = coalesce((p_payload->>'proof_expected')::boolean, proof_expected),
        special_instructions = nullif(p_payload->>'special_instructions', ''),
        schedule_type = v_schedule_type, starts_at = v_starts_at, ends_at = v_ends_at,
        deadline_at = v_deadline_at,
        recurring = coalesce((p_payload->>'recurring')::boolean, recurring),
        recurrence_rule = nullif(p_payload->>'recurrence_rule', ''),
        timezone = coalesce(nullif(p_payload->>'timezone', ''), timezone),
        urgency = coalesce(nullif(p_payload->>'urgency', ''), urgency),
        neighborhood = nullif(p_payload->>'neighborhood', ''),
        zip_code = nullif(p_payload->>'zip_code', ''),
        travel_radius_miles = nullif(p_payload->>'travel_radius_miles', '')::integer,
        work_environment = coalesce(nullif(p_payload->>'work_environment', ''), work_environment),
        location_type = coalesce(nullif(p_payload->>'location_type', ''), location_type),
        payment_type = coalesce(nullif(p_payload->>'payment_type', ''), payment_type),
        payment_method = coalesce(nullif(p_payload->>'payment_method', ''), payment_method),
        payment_timing = coalesce(nullif(p_payload->>'payment_timing', ''), payment_timing),
        tip_allowed = coalesce((p_payload->>'tip_allowed')::boolean, tip_allowed),
        adult_supervision_present = coalesce((p_payload->>'adult_supervision_present')::boolean, adult_supervision_present),
        verification_requirement = coalesce(nullif(p_payload->>'verification_requirement', ''), verification_requirement),
        safety_notes = nullif(p_payload->>'safety_notes', ''),
        safety_scan_status = 'clean', safety_scan_reasons = '{}',
        applications_open = case when p_publish then true else applications_open end,
        published_at = case when p_publish then coalesce(published_at, now()) else published_at end,
        expires_at = v_expires_at,
        updated_at = now()
    where id = v_job.id
    returning * into v_job;
  end if;

  if p_publish and not v_was_published then
    perform public.record_rate_limit_event('job_post_create');
  end if;

  return jsonb_build_object(
    'ok', true,
    'created', v_is_new,
    'published', p_publish,
    'job', to_jsonb(v_job)
  );
exception when unique_violation then
  select * into v_job
  from public.jobs
  where poster_id = auth.uid() and client_request_id = p_client_request_id;
  return jsonb_build_object('ok', true, 'created', false, 'published', v_job.status = 'open', 'job', to_jsonb(v_job));
end;
$$;
