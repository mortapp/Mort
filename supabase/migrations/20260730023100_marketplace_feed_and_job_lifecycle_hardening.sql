-- Server-authoritative marketplace pagination, approximate-location safety,
-- and idempotent adult job management.

create index if not exists jobs_open_newest_page_idx
on public.jobs (created_at desc, id desc)
where status = 'open' and applications_open;

create index if not exists jobs_open_pay_page_idx
on public.jobs (pay_amount_cents desc, id desc)
where status = 'open' and applications_open;

create index if not exists jobs_open_start_page_idx
on public.jobs (starts_at, id)
where status = 'open' and applications_open;

create table if not exists public.job_management_requests (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles(id) on delete set null,
  client_request_id uuid not null,
  job_id uuid not null,
  action text not null,
  reason text,
  expected_updated_at timestamptz,
  from_status text,
  to_status text,
  succeeded boolean,
  response jsonb,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  constraint job_management_requests_action_check check (
    action in (
      'pause', 'resume', 'close_applications', 'reopen_applications',
      'cancel', 'delete_draft', 'duplicate'
    )
  ),
  constraint job_management_requests_reason_check check (
    reason is null or char_length(reason) between 10 and 500
  ),
  unique (actor_id, client_request_id)
);

create index if not exists job_management_requests_job_created_idx
on public.job_management_requests (job_id, created_at desc);

alter table public.job_management_requests enable row level security;
alter table public.job_management_requests force row level security;

drop policy if exists job_management_requests_participant_select
on public.job_management_requests;
create policy job_management_requests_participant_select
on public.job_management_requests for select to authenticated
using (
  actor_id = auth.uid()
  or public.is_admin()
  or exists (
    select 1
    from public.jobs job
    where job.id = job_id
      and job.poster_id = auth.uid()
  )
  or exists (
    select 1
    from public.applications application
    where application.job_id = job_id
      and auth.uid() in (
        application.teen_id,
        coalesce(application.guardian_id, application.teen_id)
      )
  )
);

revoke all on public.job_management_requests from public, anon, authenticated;
grant select on public.job_management_requests to authenticated;
grant all on public.job_management_requests to service_role;

create or replace function private.contains_probable_exact_address(p_value text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select lower(coalesce(p_value, '')) ~
    '(\m[0-9]{1,6}\M[[:space:]]+[a-z0-9.''-]+([[:space:]]+[a-z0-9.''-]+){0,4}[[:space:]]+(street|st|avenue|ave|road|rd|drive|dr|lane|ln|court|ct|boulevard|blvd|parkway|pkwy|place|pl|terrace|ter|circle|cir)\M)';
$$;

revoke all on function private.contains_probable_exact_address(text)
from public, anon, authenticated;

create or replace function private.enforce_approximate_job_location()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'open'
     and private.contains_probable_exact_address(concat_ws(
       ' ',
       new.location_text,
       new.neighborhood,
       new.description,
       new.special_instructions,
       new.safety_notes,
       new.transportation_considerations
     )) then
    raise exception using
      errcode = '22023',
      message = 'exact_address_not_allowed';
  end if;
  return new;
end;
$$;

revoke all on function private.enforce_approximate_job_location()
from public, anon, authenticated;

drop trigger if exists jobs_enforce_approximate_location on public.jobs;
create trigger jobs_enforce_approximate_location
before insert or update of status, location_text, neighborhood, description,
  special_instructions, safety_notes, transportation_considerations
on public.jobs
for each row execute function private.enforce_approximate_job_location();

create or replace function private.marketplace_job_matches_filters(
  p_job public.jobs,
  p_keyword text,
  p_category text,
  p_minimum_pay_cents integer,
  p_payment_type text,
  p_schedule_type text,
  p_verification_requirement text,
  p_requires_guardian_approval boolean,
  p_work_environment text,
  p_city text,
  p_state text,
  p_transportation_methods text[]
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_job.status = 'open'
    and p_job.applications_open
    and (p_job.expires_at is null or p_job.expires_at > now())
    and (
      p_job.schedule_type <> 'exact'
      or p_job.starts_at is null
      or p_job.starts_at > now()
    )
    and private.can_view_marketplace_job(p_job.id)
    and (
      p_keyword = ''
      or position(
        p_keyword in lower(concat_ws(
          ' ', p_job.title, p_job.summary, p_job.description, p_job.category
        ))
      ) > 0
    )
    and (p_category is null or lower(p_job.category) = p_category)
    and (
      p_minimum_pay_cents is null
      or p_job.pay_amount_cents >= p_minimum_pay_cents
    )
    and (p_payment_type is null or p_job.payment_type = p_payment_type)
    and (p_schedule_type is null or p_job.schedule_type = p_schedule_type)
    and (
      p_verification_requirement is null
      or p_job.verification_requirement = p_verification_requirement
    )
    and (
      p_requires_guardian_approval is null
      or p_job.requires_guardian_approval = p_requires_guardian_approval
    )
    and (
      p_work_environment is null
      or p_job.work_environment = p_work_environment
    )
    and (p_city is null or lower(p_job.city) = p_city)
    and (p_state is null or p_job.state = p_state)
    and (
      p_transportation_methods is null
      or p_job.acceptable_transportation_methods && p_transportation_methods
    );
$$;

revoke all on function private.marketplace_job_matches_filters(
  public.jobs, text, text, integer, text, text, text, boolean, text, text,
  text, text[]
) from public, anon, authenticated;

create or replace function private.marketplace_job_feed_item(
  p_job public.jobs,
  p_poster public.profiles,
  p_viewer public.profiles
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select (
    to_jsonb(p_job)
    - 'client_request_id'
    - 'zip_code'
    - 'special_instructions'
    - 'safety_scan_reasons'
  ) || jsonb_build_object(
    'profiles', jsonb_build_object(
      'display_name', p_poster.display_name,
      'verification_status', p_poster.verification_status,
      'avatar_path', p_poster.avatar_path
    ),
    'distance_status', 'unavailable',
    'transportation_match', case
      when cardinality(p_viewer.transportation_methods) = 0 then null
      else p_job.acceptable_transportation_methods
        && p_viewer.transportation_methods
    end,
    'match_explanation', case
      when cardinality(p_viewer.transportation_methods) = 0 then
        'Distance is not calculated. Review the general area and travel options before applying.'
      when p_job.acceptable_transportation_methods
        && p_viewer.transportation_methods then
        'A saved travel method matches. Distance is not calculated; compare the general area with your travel limits.'
      else
        'No saved travel method matches. Distance is not calculated.'
    end
  );
$$;

revoke all on function private.marketplace_job_feed_item(
  public.jobs, public.profiles, public.profiles
) from public, anon, authenticated;

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
  v_user_id uuid := auth.uid();
  v_profile public.profiles%rowtype;
  v_keyword text := lower(btrim(coalesce(p_keyword, '')));
  v_category text := nullif(lower(btrim(coalesce(p_category, ''))), '');
  v_payment_type text := nullif(lower(btrim(coalesce(p_payment_type, ''))), '');
  v_schedule_type text := nullif(lower(btrim(coalesce(p_schedule_type, ''))), '');
  v_verification text := nullif(lower(btrim(coalesce(p_verification_requirement, ''))), '');
  v_environment text := nullif(lower(btrim(coalesce(p_work_environment, ''))), '');
  v_city text := nullif(lower(btrim(coalesce(p_city, ''))), '');
  v_state text := nullif(upper(btrim(coalesce(p_state, ''))), '');
  v_methods text[];
  v_sort text := lower(btrim(coalesce(p_sort, 'newest')));
  v_limit integer := least(greatest(coalesce(p_limit, 20), 1), 50);
  v_cursor_time timestamptz;
  v_cursor_pay integer;
  v_items jsonb := '[]'::jsonb;
  v_has_more boolean := false;
  v_last jsonb;
  v_next_cursor jsonb;
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;

  select * into v_profile
  from public.profiles profile
  where profile.id = v_user_id;
  if v_profile.id is null or v_profile.account_status <> 'active' then
    return jsonb_build_object('ok', false, 'code', 'user_account_restricted');
  end if;

  if v_sort not in ('newest', 'highest_pay', 'soonest_start')
     or (v_payment_type is not null and v_payment_type not in ('fixed', 'hourly'))
     or (v_schedule_type is not null and v_schedule_type not in ('flexible', 'exact'))
     or (v_verification is not null and v_verification not in ('none', 'preferred', 'required'))
     or (v_environment is not null and v_environment not in ('indoor', 'outdoor', 'both', 'unspecified'))
     or (v_state is not null and v_state !~ '^[A-Z]{2}$')
     or (p_minimum_pay_cents is not null and p_minimum_pay_cents < 0)
     or ((p_cursor_value is null) <> (p_cursor_id is null)) then
    return jsonb_build_object('ok', false, 'code', 'invalid_job_feed_filters');
  end if;

  if p_transportation_methods is not null then
    select coalesce(array_agg(method order by method), array[]::text[])
    into v_methods
    from (
      select distinct lower(btrim(value)) as method
      from unnest(p_transportation_methods) supplied(value)
      where btrim(value) <> ''
    ) normalized;
    if cardinality(v_methods) = 0
       or cardinality(v_methods) > 6
       or exists (
         select 1 from unnest(v_methods) method
         where method not in (
           'walking', 'bicycle', 'car', 'public_transit', 'rideshare', 'other'
         )
       ) then
      return jsonb_build_object('ok', false, 'code', 'invalid_job_feed_filters');
    end if;
  end if;

  if p_cursor_value is not null then
    begin
      if v_sort in ('newest', 'soonest_start') then
        v_cursor_time := p_cursor_value::timestamptz;
      else
        v_cursor_pay := p_cursor_value::integer;
      end if;
    exception when others then
      return jsonb_build_object('ok', false, 'code', 'invalid_job_feed_cursor');
    end;
  end if;

  if v_sort = 'newest' then
    select coalesce(jsonb_agg(page.item), '[]'::jsonb)
    into v_items
    from (
      select private.marketplace_job_feed_item(job, poster, v_profile) as item
      from public.jobs job
      join public.profiles poster on poster.id = job.poster_id
      where private.marketplace_job_matches_filters(
        job, v_keyword, v_category, p_minimum_pay_cents, v_payment_type,
        v_schedule_type, v_verification, p_requires_guardian_approval,
        v_environment, v_city, v_state, v_methods
      )
        and (
          p_cursor_id is null
          or (job.created_at, job.id) < (v_cursor_time, p_cursor_id)
        )
      order by job.created_at desc, job.id desc
      limit v_limit + 1
    ) page;
  elsif v_sort = 'highest_pay' then
    select coalesce(jsonb_agg(page.item), '[]'::jsonb)
    into v_items
    from (
      select private.marketplace_job_feed_item(job, poster, v_profile) as item
      from public.jobs job
      join public.profiles poster on poster.id = job.poster_id
      where private.marketplace_job_matches_filters(
        job, v_keyword, v_category, p_minimum_pay_cents, v_payment_type,
        v_schedule_type, v_verification, p_requires_guardian_approval,
        v_environment, v_city, v_state, v_methods
      )
        and (
          p_cursor_id is null
          or (coalesce(job.pay_amount_cents, -1), job.id)
            < (v_cursor_pay, p_cursor_id)
        )
      order by coalesce(job.pay_amount_cents, -1) desc, job.id desc
      limit v_limit + 1
    ) page;
  else
    select coalesce(jsonb_agg(page.item), '[]'::jsonb)
    into v_items
    from (
      select private.marketplace_job_feed_item(job, poster, v_profile) as item
      from public.jobs job
      join public.profiles poster on poster.id = job.poster_id
      where private.marketplace_job_matches_filters(
        job, v_keyword, v_category, p_minimum_pay_cents, v_payment_type,
        v_schedule_type, v_verification, p_requires_guardian_approval,
        v_environment, v_city, v_state, v_methods
      )
        and (
          p_cursor_id is null
          or (coalesce(job.starts_at, 'infinity'::timestamptz), job.id)
            > (v_cursor_time, p_cursor_id)
        )
      order by coalesce(job.starts_at, 'infinity'::timestamptz), job.id
      limit v_limit + 1
    ) page;
  end if;

  v_has_more := jsonb_array_length(v_items) > v_limit;
  if v_has_more then
    v_items := v_items - v_limit;
  end if;

  if v_has_more and jsonb_array_length(v_items) > 0 then
    v_last := v_items -> (jsonb_array_length(v_items) - 1);
    v_next_cursor := jsonb_build_object(
      'value', case v_sort
        when 'newest' then v_last->>'created_at'
        when 'highest_pay' then v_last->>'pay_amount_cents'
        else coalesce(v_last->>'starts_at', 'infinity')
      end,
      'id', v_last->>'id'
    );
  end if;

  return jsonb_build_object(
    'ok', true,
    'items', v_items,
    'has_more', v_has_more,
    'next_cursor', v_next_cursor,
    'distance_calculated', false,
    'location_precision', 'general_area_only'
  );
end;
$$;

revoke all on function public.list_open_jobs_page(
  text, text, integer, text, text, text, boolean, text, text, text, text[],
  text, text, uuid, integer
) from public, anon;
grant execute on function public.list_open_jobs_page(
  text, text, integer, text, text, text, boolean, text, text, text, text[],
  text, text, uuid, integer
) to authenticated, service_role;

create or replace function public.manage_job_v2(
  p_job_id uuid,
  p_action text,
  p_reason text,
  p_client_request_id uuid,
  p_expected_updated_at timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_profile public.profiles%rowtype;
  v_job public.jobs%rowtype;
  v_copy public.jobs%rowtype;
  v_request public.job_management_requests%rowtype;
  v_action text := lower(btrim(coalesce(p_action, '')));
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
  v_from_status text;
  v_to_status text;
  v_response jsonb;
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;

  select * into v_profile
  from public.profiles profile
  where profile.id = v_user_id;
  if v_profile.id is null or v_profile.account_status <> 'active' then
    return jsonb_build_object('ok', false, 'code', 'user_account_restricted');
  end if;
  if p_job_id is null or p_client_request_id is null
     or v_action not in (
       'pause', 'resume', 'close_applications', 'reopen_applications',
       'cancel', 'delete_draft', 'duplicate'
     ) then
    return jsonb_build_object('ok', false, 'code', 'invalid_job_management_request');
  end if;
  if v_action = 'cancel' and (
    v_reason is null
    or char_length(v_reason) not between 10 and 500
    or lower(v_reason) ~* '([a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}|\+?[0-9][0-9() .\-]{8,}[0-9]|@[a-z0-9_]{2,}|\$[a-z][a-z0-9_]*)'
  ) then
    return jsonb_build_object('ok', false, 'code', 'job_cancellation_reason_required');
  end if;
  if v_action <> 'cancel' then
    v_reason := null;
  end if;

  insert into public.job_management_requests (
    actor_id, client_request_id, job_id, action, reason, expected_updated_at
  ) values (
    v_user_id, p_client_request_id, p_job_id, v_action, v_reason,
    p_expected_updated_at
  )
  on conflict (actor_id, client_request_id) do nothing
  returning * into v_request;

  if v_request.id is null then
    select * into v_request
    from public.job_management_requests request
    where request.actor_id = v_user_id
      and request.client_request_id = p_client_request_id;
    if v_request.job_id <> p_job_id or v_request.action <> v_action then
      return jsonb_build_object('ok', false, 'code', 'client_request_conflict');
    end if;
    return coalesce(
      v_request.response || jsonb_build_object('replayed', true),
      jsonb_build_object('ok', false, 'code', 'request_in_progress')
    );
  end if;

  <<transition>>
  begin
    select * into v_job
    from public.jobs job
    where job.id = p_job_id
    for update;
    if v_job.id is null then
      v_response := jsonb_build_object('ok', false, 'code', 'job_not_found');
      exit transition;
    end if;
    if v_job.poster_id <> v_user_id and v_profile.role <> 'admin' then
      v_response := jsonb_build_object(
        'ok', false, 'code', 'unknown_permission_failure'
      );
      exit transition;
    end if;
    if p_expected_updated_at is not null
       and v_job.updated_at is distinct from p_expected_updated_at then
      v_response := jsonb_build_object('ok', false, 'code', 'stale_job_state');
      exit transition;
    end if;

    v_from_status := v_job.status::text;
    if v_action = 'pause' and v_job.status = 'open' then
      update public.jobs
      set status = 'paused', applications_open = false
      where id = p_job_id returning * into v_job;
    elsif v_action = 'resume' and v_job.status = 'paused' then
      update public.jobs
      set status = 'open', applications_open = true
      where id = p_job_id returning * into v_job;
    elsif v_action = 'close_applications'
          and v_job.status = 'open' and v_job.applications_open then
      update public.jobs
      set applications_open = false
      where id = p_job_id returning * into v_job;
    elsif v_action = 'reopen_applications'
          and v_job.status = 'open' and not v_job.applications_open then
      update public.jobs
      set applications_open = true
      where id = p_job_id returning * into v_job;
    elsif v_action = 'cancel'
          and v_job.status in ('open', 'paused', 'assigned') then
      update public.applications
      set status = case
        when status = 'accepted' then 'canceled'::public.application_status
        else 'rejected'::public.application_status
      end
      where job_id = p_job_id
        and status in (
          'submitted', 'guardian_pending', 'adult_review', 'viewed', 'accepted'
        );
      update public.jobs
      set status = 'canceled', applications_open = false
      where id = p_job_id returning * into v_job;
    elsif v_action = 'delete_draft' and v_job.status = 'draft' then
      delete from public.jobs where id = p_job_id;
      v_to_status := null;
      v_response := jsonb_build_object(
        'ok', true,
        'deleted', true,
        'job_id', p_job_id,
        'management_request_id', v_request.id
      );
      exit transition;
    elsif v_action = 'duplicate' then
      insert into public.jobs (
        poster_id, title, summary, description, category, location_text, city,
        state, pay_amount_cents, pay_label, teen_min_age, teen_max_age,
        requires_guardian_approval, guardian_requirement_explicit, status,
        estimated_duration_minutes, workers_needed, experience_level,
        skills_needed, equipment_provided, equipment_worker_brings,
        physical_requirements, proof_expected, special_instructions,
        schedule_type, recurring, timezone, urgency, neighborhood, zip_code,
        travel_radius_miles, work_environment, location_type, payment_type,
        payment_method, payment_timing, tip_allowed,
        adult_supervision_present, verification_requirement, safety_notes,
        is_test, created_by_qa, environment_tag, client_request_id,
        adult_job_amount_cents, mort_service_fee_cents,
        acceptable_transportation_methods, transportation_considerations
      ) values (
        v_job.poster_id, left(v_job.title || ' copy', 80), v_job.summary,
        v_job.description, v_job.category, v_job.location_text, v_job.city,
        v_job.state, v_job.pay_amount_cents, v_job.pay_label,
        v_job.teen_min_age, v_job.teen_max_age, false, false, 'draft',
        v_job.estimated_duration_minutes, v_job.workers_needed,
        v_job.experience_level, v_job.skills_needed, v_job.equipment_provided,
        v_job.equipment_worker_brings, v_job.physical_requirements,
        v_job.proof_expected, v_job.special_instructions, 'flexible', false,
        v_job.timezone, 'normal', v_job.neighborhood, v_job.zip_code,
        v_job.travel_radius_miles, v_job.work_environment,
        v_job.location_type, v_job.payment_type, v_job.payment_method,
        v_job.payment_timing, v_job.tip_allowed,
        v_job.adult_supervision_present, v_job.verification_requirement,
        v_job.safety_notes, v_job.is_test, v_job.created_by_qa,
        v_job.environment_tag, gen_random_uuid(),
        v_job.adult_job_amount_cents, 0,
        v_job.acceptable_transportation_methods,
        v_job.transportation_considerations
      ) returning * into v_copy;
      v_to_status := v_copy.status::text;
      v_response := jsonb_build_object(
        'ok', true,
        'job', to_jsonb(v_copy),
        'management_request_id', v_request.id
      );
      exit transition;
    else
      v_response := jsonb_build_object(
        'ok', false,
        'code', case
          when v_action = 'cancel' and v_job.status = 'in_progress'
            then 'job_in_progress_requires_dispute'
          else 'invalid_job_transition'
        end
      );
      exit transition;
    end if;

    v_to_status := v_job.status::text;
    v_response := jsonb_build_object(
      'ok', true,
      'job', to_jsonb(v_job),
      'management_request_id', v_request.id
    );
  end transition;

  update public.job_management_requests
  set from_status = v_from_status,
      to_status = v_to_status,
      succeeded = coalesce((v_response->>'ok')::boolean, false),
      response = v_response,
      completed_at = now()
  where id = v_request.id;

  return v_response;
end;
$$;

revoke all on function public.manage_job_v2(
  uuid, text, text, uuid, timestamptz
) from public, anon;
grant execute on function public.manage_job_v2(
  uuid, text, text, uuid, timestamptz
) to authenticated, service_role;

-- Old clients must not retain the reasonless and non-idempotent mutation path.
revoke execute on function public.manage_job(uuid, text) from authenticated;
grant execute on function public.manage_job(uuid, text) to service_role;
