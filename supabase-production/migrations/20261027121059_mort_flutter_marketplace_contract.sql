-- Additive compatibility layer for the current Flutter marketplace loop.
-- The deployed schema remains the source of truth; no data is copied or made up.

alter table public.jobs
  add column if not exists summary text,
  add column if not exists location_text text,
  add column if not exists adult_job_amount_cents integer,
  add column if not exists mort_service_fee_cents integer,
  add column if not exists pay_amount_cents integer,
  add column if not exists pay_label text,
  add column if not exists schedule_type text not null default 'flexible',
  add column if not exists payment_type text not null default 'fixed',
  add column if not exists payment_method text not null default 'flexible',
  add column if not exists payment_timing text not null default 'after_completion',
  add column if not exists verification_requirement text not null default 'none',
  add column if not exists work_environment text not null default 'unspecified',
  add column if not exists location_type text not null default 'unspecified',
  add column if not exists experience_level text not null default 'any',
  add column if not exists estimated_duration_minutes integer,
  add column if not exists workers_needed integer not null default 1,
  add column if not exists skills_needed text[] not null default '{}',
  add column if not exists physical_requirements text[] not null default '{}',
  add column if not exists equipment_provided text,
  add column if not exists equipment_worker_brings text,
  add column if not exists special_instructions text,
  add column if not exists safety_notes text,
  add column if not exists proof_expected boolean not null default false,
  add column if not exists adult_supervision_present boolean not null default false,
  add column if not exists tip_allowed boolean not null default false,
  add column if not exists applications_open boolean not null default true,
  add column if not exists deadline_at timestamptz,
  add column if not exists expires_at timestamptz,
  add column if not exists recurring boolean not null default false,
  add column if not exists recurrence_rule text,
  add column if not exists timezone text not null default 'America/Indiana/Indianapolis',
  add column if not exists urgency text not null default 'normal',
  add column if not exists neighborhood text,
  add column if not exists zip_code text,
  add column if not exists travel_radius_miles integer,
  add column if not exists acceptable_transportation_methods text[] not null
    default array['walking','bicycle','car','public_transit','rideshare','other']::text[],
  add column if not exists transportation_considerations text,
  add column if not exists teen_min_age integer not null default 13,
  add column if not exists teen_max_age integer not null default 17,
  add column if not exists requires_guardian_approval boolean not null default false,
  add column if not exists quick_accept_eligible boolean not null default false;

alter table public.jobs
  add constraint jobs_estimated_duration_minutes_check
    check (estimated_duration_minutes is null or estimated_duration_minutes between 5 and 1440) not valid,
  add constraint jobs_workers_needed_check
    check (workers_needed between 1 and 100) not valid,
  add constraint jobs_teen_age_range_check
    check (teen_min_age between 13 and 17 and teen_max_age between teen_min_age and 17) not valid,
  add constraint jobs_service_fee_nonnegative_check
    check (mort_service_fee_cents is null or mort_service_fee_cents >= 0) not valid;

create index if not exists jobs_public_feed_newest_idx
  on public.jobs (published_at desc, id desc)
  where status = 'open' and safety_review_status = 'approved';
create index if not exists jobs_public_feed_pay_idx
  on public.jobs (pay_amount desc, id desc)
  where status = 'open' and safety_review_status = 'approved';

alter table public.job_applications
  add column if not exists availability_confirmed boolean not null default false,
  add column if not exists guardian_id uuid references public.profiles(id) on delete set null,
  add column if not exists viewed_at timestamptz,
  add column if not exists withdrawn_at timestamptz;

create or replace function public.list_open_jobs_page(
  p_keyword text default '',
  p_category text default null,
  p_minimum_pay_cents integer default null,
  p_payment_type text default null,
  p_schedule_type text default null,
  p_verification_requirement text default null,
  p_requires_guardian_approval boolean default null,
  p_work_environment text default null,
  p_city text default null,
  p_state text default null,
  p_transportation_methods text[] default null,
  p_sort text default 'newest',
  p_cursor_value text default null,
  p_cursor_id uuid default null,
  p_limit integer default 20
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_profile public.profiles%rowtype;
  v_release public.mort_release_control%rowtype;
  v_job record;
  v_items jsonb := '[]'::jsonb;
  v_cursor jsonb;
  v_has_more boolean := false;
  v_count integer := 0;
  v_limit integer := greatest(1, least(coalesce(p_limit, 20), 50));
  v_age integer;
  v_cursor_time timestamptz;
  v_cursor_pay numeric;
  v_keyword text := lower(btrim(coalesce(p_keyword, '')));
  v_category text := nullif(lower(replace(btrim(coalesce(p_category, '')), ' ', '_')), '');
begin
  p_sort := coalesce(p_sort, 'newest');
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  select * into v_profile from public.profiles where id = auth.uid();
  if not found or v_profile.role <> 'teen'::public.mort_role or v_profile.account_status <> 'active' then
    return jsonb_build_object('ok', false, 'code', 'active_teen_account_required');
  end if;
  select * into v_release from public.mort_release_control where is_primary;
  if not found or v_release.maintenance_mode then
    return jsonb_build_object('ok', false, 'code', 'maintenance_mode_active');
  end if;
  if not v_release.public_marketplace_enabled then
    return jsonb_build_object('ok', false, 'code', 'public_marketplace_disabled');
  end if;
  if coalesce(p_sort, 'newest') not in ('newest', 'highest_pay', 'soonest_start') then
    return jsonb_build_object('ok', false, 'code', 'invalid_job_sort');
  end if;
  if p_cursor_value is not null and p_cursor_id is not null then
    if p_sort in ('newest', 'soonest_start') then
      begin
        v_cursor_time := p_cursor_value::timestamptz;
      exception when others then
        return jsonb_build_object('ok', false, 'code', 'invalid_job_cursor');
      end;
    else
      begin
        v_cursor_pay := p_cursor_value::numeric;
      exception when others then
        return jsonb_build_object('ok', false, 'code', 'invalid_job_cursor');
      end;
    end if;
  end if;
  if v_profile.date_of_birth is not null then
    v_age := extract(year from age(current_date, v_profile.date_of_birth))::integer;
  end if;

  for v_job in
    select j.*,
      p.display_name as poster_display_name,
      p.avatar_path as poster_avatar_path,
      case when exists (
        select 1 from public.verification_cases vc
        where vc.user_id = p.id and vc.verification_type = 'identity'
          and vc.status = 'verified'::public.mort_verification_status
          and (vc.expires_at is null or vc.expires_at > now())
      ) then 'approved' else 'pending' end as poster_verification_status,
      coalesce(j.published_at, j.created_at) as feed_published_at,
      coalesce(j.starts_at, 'infinity'::timestamptz) as feed_start_at
    from public.jobs j
    join public.profiles p on p.id = j.poster_id
    where j.status = 'open'::public.mort_job_status
      and j.safety_review_status = 'approved'
      and j.applications_open
      and (j.expires_at is null or j.expires_at > now())
      and (v_age is null or (j.age_min <= v_age and j.age_max >= v_age))
      and (v_keyword = '' or lower(j.title || ' ' || j.description || ' ' || coalesce(j.summary, '')) like '%' || v_keyword || '%')
      and (v_category is null or j.category = v_category)
      and (p_minimum_pay_cents is null or round(j.pay_amount * 100)::integer >= p_minimum_pay_cents)
      and (p_payment_type is null or p_payment_type in ('any', '') or j.pay_type = p_payment_type)
      and (p_schedule_type is null or p_schedule_type in ('any', '') or j.schedule_type = p_schedule_type)
      and (p_requires_guardian_approval is null or j.requires_guardian_approval = p_requires_guardian_approval)
      and (p_work_environment is null or p_work_environment in ('any', '') or j.work_environment = p_work_environment)
      and (p_city is null or btrim(p_city) = '' or lower(j.city) = lower(btrim(p_city)))
      and (p_state is null or btrim(p_state) = '' or lower(j.region) = lower(btrim(p_state)))
      and (p_transportation_methods is null or cardinality(p_transportation_methods) = 0
        or j.acceptable_transportation_methods && p_transportation_methods)
      and (p_verification_requirement is null or p_verification_requirement in ('any', '')
        or (p_verification_requirement = 'required' and exists (
          select 1 from public.verification_cases vc
          where vc.user_id = p.id and vc.verification_type = 'identity'
            and vc.status = 'verified'::public.mort_verification_status
            and (vc.expires_at is null or vc.expires_at > now())
        )))
      and (p_cursor_id is null or p_cursor_value is null
        or (p_sort = 'newest' and (
          coalesce(j.published_at, j.created_at) < v_cursor_time
          or (coalesce(j.published_at, j.created_at) = v_cursor_time and j.id > p_cursor_id)
        ))
        or (p_sort = 'soonest_start' and (
          coalesce(j.starts_at, 'infinity'::timestamptz) > v_cursor_time
          or (coalesce(j.starts_at, 'infinity'::timestamptz) = v_cursor_time and j.id > p_cursor_id)
        ))
        or (p_sort = 'highest_pay' and (
          j.pay_amount < v_cursor_pay
          or (j.pay_amount = v_cursor_pay and j.id > p_cursor_id)
        )))
    order by
      case when p_sort = 'newest' then coalesce(j.published_at, j.created_at) end desc nulls last,
      case when p_sort = 'highest_pay' then j.pay_amount end desc nulls last,
      case when p_sort = 'soonest_start' then coalesce(j.starts_at, 'infinity'::timestamptz) end asc nulls last,
      j.id asc
    limit v_limit + 1
  loop
    if v_count >= v_limit then
      v_has_more := true;
      exit;
    end if;
    v_count := v_count + 1;
    v_cursor := jsonb_build_object(
      'value', case p_sort
        when 'highest_pay' then v_job.pay_amount::text
        when 'soonest_start' then v_job.feed_start_at::text
        else v_job.feed_published_at::text
      end,
      'id', v_job.id
    );
    v_items := v_items || jsonb_build_array(jsonb_build_object(
      'id', v_job.id,
      'poster_id', v_job.poster_id,
      'title', v_job.title,
      'summary', v_job.summary,
      'description', v_job.description,
      'category', v_job.category,
      'location_text', case when v_job.remote_allowed then 'Remote' else concat_ws(', ', v_job.city, v_job.region) end,
      'city', v_job.city,
      'state', v_job.region,
      'status', v_job.status::text,
      'requires_guardian_approval', v_job.requires_guardian_approval,
      'adult_job_amount_cents', round(v_job.pay_amount * 100)::integer,
      'mort_service_fee_cents', v_job.mort_service_fee_cents,
      'pay_amount_cents', round(v_job.pay_amount * 100)::integer,
      'pay_label', null,
      'starts_at', v_job.starts_at,
      'ends_at', v_job.ends_at,
      'deadline_at', v_job.deadline_at,
      'expires_at', v_job.expires_at,
      'published_at', v_job.published_at,
      'updated_at', v_job.updated_at,
      'profiles', jsonb_build_object(
        'display_name', v_job.poster_display_name,
        'verification_status', v_job.poster_verification_status,
        'avatar_path', v_job.poster_avatar_path
      ),
      'schedule_type', v_job.schedule_type,
      'payment_type', v_job.pay_type,
      'payment_method', v_job.payment_method,
      'payment_timing', v_job.payment_timing,
      'verification_requirement', v_job.verification_requirement,
      'work_environment', v_job.work_environment,
      'location_type', v_job.location_type,
      'experience_level', v_job.experience_level,
      'estimated_duration_minutes', v_job.estimated_duration_minutes,
      'workers_needed', v_job.workers_needed,
      'skills_needed', to_jsonb(v_job.skills_needed),
      'physical_requirements', to_jsonb(v_job.physical_requirements),
      'equipment_provided', v_job.equipment_provided,
      'equipment_worker_brings', v_job.equipment_worker_brings,
      'special_instructions', v_job.special_instructions,
      'safety_notes', v_job.safety_notes,
      'proof_expected', v_job.proof_expected,
      'adult_supervision_present', v_job.adult_supervision_present,
      'tip_allowed', v_job.tip_allowed,
      'applications_open', v_job.applications_open,
      'is_test', false,
      'recurring', v_job.recurring,
      'recurrence_rule', v_job.recurrence_rule,
      'timezone', v_job.timezone,
      'urgency', v_job.urgency,
      'neighborhood', null,
      'zip_code', null,
      'travel_radius_miles', null,
      'acceptable_transportation_methods', to_jsonb(v_job.acceptable_transportation_methods),
      'transportation_considerations', null,
      'teen_min_age', v_job.age_min,
      'teen_max_age', v_job.age_max,
      'distance_status', 'unavailable',
      'transportation_match', null,
      'match_explanation', null,
      'quick_accept_eligible', v_job.quick_accept_eligible
    ));
  end loop;

  return jsonb_build_object(
    'ok', true,
    'items', v_items,
    'has_more', v_has_more,
    'next_cursor', case when v_has_more then v_cursor else null end
  );
end;
$$;
revoke all on function public.list_open_jobs_page(text,text,integer,text,text,text,boolean,text,text,text,text[],text,text,uuid,integer) from public, anon;
grant execute on function public.list_open_jobs_page(text,text,integer,text,text,text,boolean,text,text,text,text[],text,text,uuid,integer) to authenticated;

create or replace function public.get_job_application_eligibility(p_job_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_profile public.profiles%rowtype;
  v_job public.jobs%rowtype;
  v_release public.mort_release_control%rowtype;
  v_age integer;
  v_guardian_linked boolean;
  v_profile_found boolean := false;
  v_job_found boolean := false;
  v_release_found boolean := false;
  v_code text := 'eligible';
  v_message text := 'You can apply to this job.';
begin
  if auth.uid() is null then
    return jsonb_build_object('eligible', false, 'code', 'authentication_required', 'message', 'Sign in to apply.', 'guardian_required_for_this_job', false, 'guardian_linked', false);
  end if;
  select * into v_profile from public.profiles where id = auth.uid();
  v_profile_found := found;
  select * into v_job from public.jobs where id = p_job_id;
  v_job_found := found;
  select * into v_release from public.mort_release_control where is_primary;
  v_release_found := found;
  select exists (
    select 1 from public.guardian_links gl
    where gl.teen_user_id = auth.uid() and gl.status = 'active'
      and gl.teen_consent_at is not null and gl.guardian_consent_at is not null
  ) into v_guardian_linked;
  if not v_profile_found or v_profile.role <> 'teen'::public.mort_role or v_profile.account_status <> 'active' then
    v_code := 'active_teen_account_required'; v_message := 'An active teen account is required.';
  elsif not v_release_found or v_release.maintenance_mode then
    v_code := 'maintenance_mode_active'; v_message := 'The marketplace is temporarily unavailable.';
  elsif not v_release.public_marketplace_enabled then
    v_code := 'public_marketplace_disabled'; v_message := 'The marketplace is not accepting public applications yet.';
  elsif not v_job_found or v_job.status <> 'open'::public.mort_job_status or v_job.safety_review_status <> 'approved' or not v_job.applications_open or (v_job.expires_at is not null and v_job.expires_at <= now()) then
    v_code := 'job_not_available'; v_message := 'This job is not accepting applications.';
  elsif v_profile.date_of_birth is null then
    v_code := 'date_of_birth_required'; v_message := 'Complete age verification before applying.';
  else
    v_age := extract(year from age(current_date, v_profile.date_of_birth))::integer;
    if v_age < v_job.age_min or v_age > v_job.age_max then
      v_code := 'applicant_age_not_allowed'; v_message := 'Your age does not match this job’s requirements.';
    elsif not exists (
      select 1 from public.verification_cases vc
      where vc.user_id = auth.uid() and vc.verification_type = 'age'
        and vc.status = 'verified'::public.mort_verification_status
        and (vc.expires_at is null or vc.expires_at > now())
    ) then
      v_code := 'age_verification_required'; v_message := 'Complete age verification before applying.';
    elsif v_job.requires_guardian_approval and not v_guardian_linked then
      v_code := 'guardian_approval_required'; v_message := 'Link a guardian before applying to this job.';
    elsif exists (
      select 1 from public.user_blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = v_job.poster_id)
        or (b.blocker_id = v_job.poster_id and b.blocked_id = auth.uid())
    ) then
      v_code := 'interaction_unavailable'; v_message := 'This interaction is unavailable.';
    end if;
  end if;
  return jsonb_build_object(
    'eligible', v_code = 'eligible', 'code', v_code, 'message', v_message,
    'guardian_required_for_this_job', coalesce(v_job.requires_guardian_approval, false),
    'guardian_linked', v_guardian_linked,
    'verification_requirement', coalesce(v_job.verification_requirement, 'none'),
    'schedule_type', coalesce(v_job.schedule_type, 'flexible')
  );
end;
$$;
revoke all on function public.get_job_application_eligibility(uuid) from public, anon;
grant execute on function public.get_job_application_eligibility(uuid) to authenticated;

create or replace function public.submit_job_application(
  p_job_id uuid,
  p_note text default null,
  p_availability_confirmed boolean default false,
  p_portfolio_ids uuid[] default '{}'::uuid[]
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job public.jobs%rowtype;
  v_eligibility jsonb;
  v_application_id uuid;
  v_application public.job_applications%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_note is not null and char_length(btrim(p_note)) > 1000 then
    return jsonb_build_object('ok', false, 'code', 'application_note_too_long');
  end if;
  if coalesce(cardinality(p_portfolio_ids), 0) > 0 then
    return jsonb_build_object('ok', false, 'code', 'portfolio_evidence_not_supported');
  end if;
  select * into v_job from public.jobs where id = p_job_id;
  if not found then return jsonb_build_object('ok', false, 'code', 'job_not_available'); end if;
  if v_job.starts_at is not null and not p_availability_confirmed then
    return jsonb_build_object('ok', false, 'code', 'availability_confirmation_required');
  end if;
  v_eligibility := public.get_job_application_eligibility(p_job_id);
  if v_eligibility->>'eligible' <> 'true' then
    return jsonb_build_object('ok', false, 'code', v_eligibility->>'code', 'message', v_eligibility->>'message');
  end if;
  v_application_id := public.mort_submit_job_application(p_job_id, p_note);
  update public.job_applications set availability_confirmed = p_availability_confirmed
  where id = v_application_id
  returning * into v_application;
  return jsonb_build_object(
    'ok', true,
    'application', jsonb_build_object(
      'id', v_application.id,
      'job_id', v_application.job_id,
      'teen_id', v_application.applicant_id,
      'status', v_application.status::text,
      'note', v_application.cover_note,
      'guardian_id', v_application.guardian_id,
      'availability_confirmed', v_application.availability_confirmed,
      'created_at', v_application.created_at,
      'updated_at', v_application.updated_at
    )
  );
end;
$$;
revoke all on function public.submit_job_application(uuid,text,boolean,uuid[]) from public, anon;
grant execute on function public.submit_job_application(uuid,text,boolean,uuid[]) to authenticated;

-- Route authenticated clients through the release-gated compatibility RPC.
-- The definer-owned wrapper can still call the underlying implementation.
revoke all on function public.mort_submit_job_application(uuid,text) from public, anon, authenticated;
grant execute on function public.mort_submit_job_application(uuid,text) to service_role;

comment on function public.list_open_jobs_page(text,text,integer,text,text,text,boolean,text,text,text,text[],text,text,uuid,integer) is
  'Authenticated teen marketplace feed. Requires production public-marketplace activation and never returns exact addresses.';
comment on function public.submit_job_application(uuid,text,boolean,uuid[]) is
  'Compatibility RPC for the Flutter application flow; delegates age, role, and job checks to server-side guards.';

