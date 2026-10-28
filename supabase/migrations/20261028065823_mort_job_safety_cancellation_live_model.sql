
-- Record safety cancellations against the current job_applications and
-- job_assignments model. This table is an internal audit record; callers use
-- the authenticated RPC and never receive direct table access.
create table public.job_safety_cancellations (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references public.job_applications(id) on delete restrict,
  assignment_id uuid not null references public.job_assignments(id) on delete restrict,
  job_id uuid not null references public.jobs(id) on delete restrict,
  actor_id uuid not null references public.profiles(id) on delete restrict,
  reported_user_id uuid not null references public.profiles(id) on delete restrict,
  reason text not null,
  details text not null,
  is_safety_related boolean not null default true,
  reputation_penalty_applied boolean not null default false,
  safety_report_id uuid references public.safety_reports(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint job_safety_cancellations_reason_check check (
    reason in (
      'unsafe_condition', 'person_mismatch', 'harassment',
      'location_changed', 'scope_changed', 'emergency'
    )
  ),
  constraint job_safety_cancellations_details_length check (
    char_length(btrim(details)) between 10 and 3000
  ),
  constraint job_safety_cancellations_no_automatic_penalty check (
    is_safety_related and not reputation_penalty_applied
  ),
  constraint job_safety_cancellations_participant_pair check (actor_id <> reported_user_id),
  constraint job_safety_cancellations_application_actor_key unique (application_id, actor_id)
);

alter table public.job_safety_cancellations enable row level security;
revoke all on table public.job_safety_cancellations from public, anon, authenticated;
grant all on table public.job_safety_cancellations to service_role;

create or replace function private.submit_safety_cancellation_internal(
  p_application_id uuid,
  p_reason text,
  p_details text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_assignment public.job_assignments%rowtype;
  v_application public.job_applications%rowtype;
  v_job public.jobs%rowtype;
  v_existing public.job_safety_cancellations%rowtype;
  v_cancellation public.job_safety_cancellations%rowtype;
  v_reason text := lower(btrim(coalesce(p_reason, '')));
  v_details text := btrim(coalesce(p_details, ''));
  v_target_user_id uuid;
  v_report jsonb;
  v_category text;
  v_severity text;
  v_immediate_danger boolean;
begin
  if v_user_id is null or not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;
  if p_application_id is null
     or not private.is_job_safety_participant(p_application_id, v_user_id) then
    return jsonb_build_object('ok', false, 'code', 'job_participant_required');
  end if;
  if v_reason not in (
    'unsafe_condition', 'person_mismatch', 'harassment',
    'location_changed', 'scope_changed', 'emergency'
  ) then
    return jsonb_build_object('ok', false, 'code', 'invalid_cancellation_reason');
  end if;
  if char_length(v_details) not between 10 and 3000 then
    return jsonb_build_object('ok', false, 'code', 'safety_cancellation_details_required');
  end if;

  select assignment.* into v_assignment
  from public.job_assignments as assignment
  where assignment.application_id = p_application_id
    and v_user_id in (assignment.teen_user_id, assignment.adult_user_id)
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'job_participant_required');
  end if;

  select application.* into v_application
  from public.job_applications as application
  where application.id = v_assignment.application_id
    and application.job_id = v_assignment.job_id
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'accepted_job_required');
  end if;

  select job.* into v_job
  from public.jobs as job
  where job.id = v_assignment.job_id
    and job.poster_id = v_assignment.adult_user_id
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'accepted_job_required');
  end if;
  if v_application.status <> 'accepted'::public.mort_application_status
     or v_assignment.status not in ('accepted', 'in_progress')
     or v_job.status not in ('filled', 'in_progress') then
    return jsonb_build_object('ok', false, 'code', 'active_job_required');
  end if;

  select cancellation.* into v_existing
  from public.job_safety_cancellations as cancellation
  where cancellation.application_id = p_application_id
    and cancellation.actor_id = v_user_id;
  if found then
    if v_existing.reason = v_reason and v_existing.details = v_details then
      return jsonb_build_object(
        'ok', true,
        'replayed', true,
        'cancellation_id', v_existing.id,
        'safety_report_id', v_existing.safety_report_id,
        'safety_related', true,
        'reputation_penalty_applied', false
      );
    end if;
    return jsonb_build_object('ok', false, 'code', 'safety_cancellation_already_submitted');
  end if;

  v_target_user_id := case
    when v_user_id = v_assignment.teen_user_id then v_assignment.adult_user_id
    else v_assignment.teen_user_id
  end;
  v_category := case
    when v_reason = 'harassment' then 'harassment'
    else 'unsafe_meeting'
  end;
  v_immediate_danger := v_reason = 'emergency';
  v_severity := case
    when v_immediate_danger then 'critical'
    when v_reason in ('person_mismatch', 'harassment') then 'high'
    else 'normal'
  end;

  v_report := public.submit_safety_report_v2(
    v_target_user_id,
    v_job.id,
    null,
    null,
    p_application_id,
    v_category,
    v_severity,
    v_immediate_danger,
    v_details,
    now(),
    v_job.location_type,
    'End the job safely and prevent retaliation.',
    true,
    gen_random_uuid()
  );
  if coalesce((v_report->>'ok')::boolean, false) is not true then
    return jsonb_build_object(
      'ok', false,
      'code', coalesce(v_report->>'code', 'safety_report_failed')
    );
  end if;

  insert into public.job_safety_cancellations (
    application_id, assignment_id, job_id, actor_id, reported_user_id,
    reason, details, safety_report_id
  ) values (
    p_application_id, v_assignment.id, v_job.id, v_user_id, v_target_user_id,
    v_reason, left(v_details, 3000), nullif(v_report->>'report_id', '')::uuid
  ) returning * into v_cancellation;

  -- Stop job execution while the cancellation is reviewed. Keep the accepted
  -- application row in its current enum state; the live model uses assignment
  -- status for execution lifecycle.
  update public.job_assignments
  set status = 'disputed', closed_at = coalesce(closed_at, now())
  where id = v_assignment.id;
  update public.jobs
  set status = 'paused', applications_open = false, updated_at = now()
  where id = v_job.id;

  return jsonb_build_object(
    'ok', true,
    'replayed', false,
    'cancellation_id', v_cancellation.id,
    'safety_report_id', v_cancellation.safety_report_id,
    'safety_related', true,
    'reputation_penalty_applied', false
  );
end;
$function$;

revoke all on function private.submit_safety_cancellation_internal(uuid, text, text)
  from public, anon, authenticated;
grant execute on function private.submit_safety_cancellation_internal(uuid, text, text)
  to authenticated;

create or replace function public.submit_safety_cancellation(
  p_application_id uuid,
  p_reason text,
  p_details text default null
)
returns jsonb
language sql
security invoker
set search_path = ''
as $function$
  select private.submit_safety_cancellation_internal(
    p_application_id,
    p_reason,
    p_details
  );
$function$;

revoke all on function public.submit_safety_cancellation(uuid, text, text)
  from public, anon;
grant execute on function public.submit_safety_cancellation(uuid, text, text)
  to authenticated;

comment on table public.job_safety_cancellations is
  'Private audit of a participant safety cancellation; no automatic reputation penalty is applied.';
comment on function public.submit_safety_cancellation(uuid, text, text) is
  'Authenticated participant-only safety cancellation RPC for the current job_assignments model.';
