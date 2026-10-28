create table if not exists public.application_status_events (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references public.job_applications(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  from_status public.mort_application_status,
  to_status public.mort_application_status not null,
  created_at timestamptz not null default now()
);

create index if not exists application_status_events_application_created_idx
  on public.application_status_events (application_id, created_at, id);

alter table public.application_status_events enable row level security;

drop policy if exists application_status_events_select_participant
  on public.application_status_events;
create policy application_status_events_select_participant
  on public.application_status_events
  for select to authenticated
  using (
    exists (
      select 1
      from public.job_applications ja
      join public.jobs j on j.id = ja.job_id
      where ja.id = application_id
        and (
          ja.applicant_id = (select auth.uid())
          or j.poster_id = (select auth.uid())
          or exists (
            select 1 from public.guardian_links gl
            where gl.teen_user_id = ja.applicant_id
              and gl.guardian_user_id = (select auth.uid())
              and gl.status = 'active'
              and gl.teen_consent_at is not null
              and gl.guardian_consent_at is not null
          )
        )
    )
  );

revoke all on public.application_status_events from anon, authenticated;
grant select on public.application_status_events to authenticated;

create or replace function private.capture_application_status_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if new.status is distinct from old.status then
    insert into public.application_status_events (
      application_id, actor_id, from_status, to_status
    ) values (
      new.id, auth.uid(), old.status, new.status
    );
  end if;
  return new;
end;
$function$;

drop trigger if exists job_applications_log_status_event
  on public.job_applications;
create trigger job_applications_log_status_event
  after update of status on public.job_applications
  for each row execute function private.capture_application_status_event();

create or replace function public.get_my_job_applications(
  p_application_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_user uuid := auth.uid();
  v_items jsonb;
begin
  if v_user is null or not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', ja.id,
      'job_id', ja.job_id,
      'teen_id', ja.applicant_id,
      'status', ja.status::text,
      'note', ja.cover_note,
      'guardian_id', ja.guardian_id,
      'availability_confirmed', ja.availability_confirmed,
      'created_at', ja.created_at,
      'updated_at', ja.updated_at,
      'viewed_at', ja.viewed_at,
      'withdrawn_at', ja.withdrawn_at,
      'teen', jsonb_build_object(
        'display_name', teen.display_name,
        'avatar_path', teen.avatar_path
      ),
      'jobs', jsonb_build_object(
        'id', j.id,
        'poster_id', j.poster_id,
        'title', j.title,
        'summary', j.summary,
        'description', j.description,
        'category', j.category,
        'location_text', case when j.remote_allowed then 'Remote' else concat_ws(', ', j.city, j.region) end,
        'city', j.city,
        'state', j.region,
        'status', j.status::text,
        'requires_guardian_approval', j.requires_guardian_approval,
        'adult_job_amount_cents', round(j.pay_amount * 100)::integer,
        'mort_service_fee_cents', j.mort_service_fee_cents,
        'pay_amount_cents', round(j.pay_amount * 100)::integer,
        'starts_at', j.starts_at,
        'ends_at', j.ends_at,
        'deadline_at', j.deadline_at,
        'expires_at', j.expires_at,
        'published_at', j.published_at,
        'updated_at', j.updated_at,
        'profiles', jsonb_build_object(
          'display_name', poster.display_name,
          'verification_status', poster.verification_status,
          'avatar_path', poster.avatar_path
        ),
        'schedule_type', j.schedule_type,
        'payment_type', j.pay_type,
        'payment_method', j.payment_method,
        'payment_timing', j.payment_timing,
        'verification_requirement', j.verification_requirement,
        'work_environment', j.work_environment,
        'location_type', j.location_type,
        'experience_level', j.experience_level,
        'estimated_duration_minutes', j.estimated_duration_minutes,
        'workers_needed', j.workers_needed,
        'skills_needed', to_jsonb(j.skills_needed),
        'physical_requirements', to_jsonb(j.physical_requirements),
        'equipment_provided', j.equipment_provided,
        'equipment_worker_brings', j.equipment_worker_brings,
        'special_instructions', j.special_instructions,
        'safety_notes', j.safety_notes,
        'proof_expected', j.proof_expected,
        'adult_supervision_present', j.adult_supervision_present,
        'tip_allowed', j.tip_allowed,
        'applications_open', j.applications_open,
        'is_test', false,
        'recurring', j.recurring,
        'recurrence_rule', j.recurrence_rule,
        'timezone', j.timezone,
        'urgency', j.urgency,
        'acceptable_transportation_methods', to_jsonb(j.acceptable_transportation_methods),
        'teen_min_age', j.age_min,
        'teen_max_age', j.age_max,
        'quick_accept_eligible', false
      )
    ) order by ja.created_at desc, ja.id desc
  ), '[]'::jsonb)
  into v_items
  from public.job_applications ja
  join public.jobs j on j.id = ja.job_id
  join public.profiles teen on teen.id = ja.applicant_id
  join public.profiles poster on poster.id = j.poster_id
  where (p_application_id is null or ja.id = p_application_id)
    and (
      ja.applicant_id = v_user
      or j.poster_id = v_user
      or exists (
        select 1 from public.guardian_links gl
        where gl.teen_user_id = ja.applicant_id
          and gl.guardian_user_id = v_user
          and gl.status = 'active'
          and gl.teen_consent_at is not null
          and gl.guardian_consent_at is not null
      )
    );

  return jsonb_build_object('ok', true, 'items', v_items);
end;
$function$;

create or replace function public.update_my_job_application_status(
  p_application_id uuid,
  p_action text,
  p_expected_updated_at timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user uuid := auth.uid();
  v_role public.mort_role := private.current_role();
  v_app public.job_applications%rowtype;
  v_job public.jobs%rowtype;
  v_assignment uuid;
  v_recipient uuid;
  v_title text;
  v_body text;
  v_updated jsonb;
begin
  if v_user is null or not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;

  select ja.* into v_app
  from public.job_applications ja
  where ja.id = p_application_id
    and (
      ja.applicant_id = v_user
      or exists (
        select 1 from public.jobs j where j.id = ja.job_id and j.poster_id = v_user
      )
    )
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'application_not_available');
  end if;
  if p_expected_updated_at is not null and v_app.updated_at <> p_expected_updated_at then
    return jsonb_build_object('ok', false, 'code', 'application_changed_refresh');
  end if;

  select * into v_job from public.jobs where id = v_app.job_id;

  if p_action = 'accepted'
     and v_role = 'adult'::public.mort_role
     and v_job.poster_id = v_user then
    v_assignment := public.mort_accept_job_application(v_app.id);
  elsif p_action in ('shortlisted', 'rejected', 'viewed')
    and v_role = 'adult'::public.mort_role
    and v_job.poster_id = v_user
    and v_app.status in (
      'submitted'::public.mort_application_status,
      'shortlisted'::public.mort_application_status
    ) then
    if p_action = 'viewed' then
      update public.job_applications set viewed_at = coalesce(viewed_at, now())
      where id = v_app.id;
    else
      update public.job_applications
      set status = p_action::public.mort_application_status
      where id = v_app.id;
      v_recipient := v_app.applicant_id;
      v_title := case when p_action = 'shortlisted' then 'Application shortlisted' else 'Application update' end;
      v_body := case when p_action = 'shortlisted' then 'Your application was shortlisted.' else 'Your application was declined.' end;
    end if;
  elsif p_action = 'withdrawn'
    and v_role = 'teen'::public.mort_role
    and v_app.applicant_id = v_user
    and v_app.status in (
      'submitted'::public.mort_application_status,
      'shortlisted'::public.mort_application_status
    ) then
    update public.job_applications
    set status = 'withdrawn'::public.mort_application_status,
        withdrawn_at = now()
    where id = v_app.id;
    v_recipient := v_job.poster_id;
    v_title := 'Application withdrawn';
    v_body := 'A teen withdrew their application.';
  else
    return jsonb_build_object('ok', false, 'code', 'application_action_not_allowed');
  end if;

  if v_recipient is not null then
    insert into public.notifications (user_id, notification_type, title, body, data)
    values (
      v_recipient,
      'application_status',
      v_title,
      v_body,
      jsonb_build_object('application_id', v_app.id, 'job_id', v_app.job_id)
    );
  end if;

  v_updated := public.get_my_job_applications(v_app.id)->'items'->0;
  return jsonb_build_object(
    'ok', true,
    'application', v_updated,
    'assignment_id', v_assignment
  );
end;
$function$;

revoke all on function public.get_my_job_applications(uuid) from public, anon;
grant execute on function public.get_my_job_applications(uuid) to authenticated;
revoke all on function public.update_my_job_application_status(uuid, text, timestamptz) from public, anon;
grant execute on function public.update_my_job_application_status(uuid, text, timestamptz) to authenticated;

comment on function public.get_my_job_applications(uuid) is
  'Returns minimal application and job details only for the applicant, job poster, or actively linked guardian.';
comment on function public.update_my_job_application_status(uuid, text, timestamptz) is
  'Applies allowlisted application transitions for the current active teen or adult; acceptance delegates to the verified assignment flow.';
