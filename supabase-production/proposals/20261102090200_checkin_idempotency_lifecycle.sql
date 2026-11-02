-- PROPOSAL ONLY — do not place in supabase-production/migrations or apply to production.
-- Additive, nullable fields preserve existing check-in rows; row locks use the
-- assignment -> job -> check-in order used by the safety-cancellation workflow.
begin;
do $guard$
begin
  if md5(pg_get_functiondef('public.schedule_active_job_checkin(uuid,integer,uuid)'::regprocedure))
     <> '68ddb42187ef290145bda12d93a7b00b' then
    raise exception 'proposal_source_mismatch:schedule_active_job_checkin';
  end if;
  if md5(pg_get_functiondef('public.complete_active_job_checkin(uuid,uuid)'::regprocedure))
     <> '7a7b9ea9824a47e14e783b79aefac098' then
    raise exception 'proposal_source_mismatch:complete_active_job_checkin';
  end if;
end;
$guard$;

alter table public.job_safety_checkins
  add column if not exists request_interval_minutes integer,
  add column if not exists completion_request_id uuid;

do $constraint$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.job_safety_checkins'::regclass
      and conname = 'job_safety_checkins_request_interval_check'
  ) then
    alter table public.job_safety_checkins
      add constraint job_safety_checkins_request_interval_check
      check (request_interval_minutes is null or request_interval_minutes between 5 and 240)
      not valid;
  end if;
end;
$constraint$;

create unique index if not exists job_safety_checkins_teen_completion_request_uidx
  on public.job_safety_checkins (teen_user_id, completion_request_id)
  where completion_request_id is not null;

CREATE OR REPLACE FUNCTION public.schedule_active_job_checkin(p_application_id uuid, p_minutes_from_now integer, p_client_request_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  user_id uuid := auth.uid();
  assignment public.job_assignments%rowtype;
  job public.jobs%rowtype;
  existing_checkin public.job_safety_checkins%rowtype;
  checkin_id uuid;
  expected_at_value timestamptz;
begin
  if user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if private.current_role() <> 'teen'::public.mort_role or not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_teen_account_required');
  end if;
  if p_client_request_id is null then
    return jsonb_build_object('ok', false, 'code', 'client_request_id_required');
  end if;
  if p_minutes_from_now is null or p_minutes_from_now not between 5 and 240 then
    return jsonb_build_object('ok', false, 'code', 'checkin_interval_invalid');
  end if;

  select * into assignment
  from public.job_assignments
  where application_id = p_application_id
    and teen_user_id = user_id
  for update;
  if not found or assignment.status not in ('accepted', 'in_progress') then
    return jsonb_build_object('ok', false, 'code', 'active_assignment_required');
  end if;

  select * into job
  from public.jobs
  where id = assignment.job_id
  for update;
  if not found
     or job.poster_id <> assignment.adult_user_id
     or job.status not in ('filled', 'in_progress')
     or not exists (
       select 1 from public.job_applications application
       where application.id = assignment.application_id
         and application.job_id = assignment.job_id
         and application.applicant_id = assignment.teen_user_id
         and application.status = 'accepted'::public.mort_application_status
     ) then
    return jsonb_build_object('ok', false, 'code', 'active_assignment_required');
  end if;

  expected_at_value := clock_timestamp() + make_interval(mins => p_minutes_from_now);
  insert into public.job_safety_checkins (
    application_id, job_id, teen_user_id, adult_user_id,
    expected_at, client_request_id, request_interval_minutes
  ) values (
    assignment.application_id, assignment.job_id, assignment.teen_user_id,
    assignment.adult_user_id, expected_at_value, p_client_request_id, p_minutes_from_now
  )
  on conflict (teen_user_id, client_request_id) do nothing
  returning id, expected_at into checkin_id, expected_at_value;

  if checkin_id is null then
    select * into existing_checkin
    from public.job_safety_checkins
    where teen_user_id = user_id and client_request_id = p_client_request_id
    for update;
    if not found then
      return jsonb_build_object('ok', false, 'code', 'idempotency_result_unavailable');
    end if;
    if existing_checkin.application_id <> p_application_id then
      return jsonb_build_object('ok', false, 'code', 'idempotency_key_reused');
    end if;
    -- Old rows have no recorded interval. Preserve the previous successful
    -- same-application retry behavior without claiming payload equivalence.
    if existing_checkin.request_interval_minutes is null then
      return jsonb_build_object(
        'ok', true, 'replayed', true, 'payload_verified', false,
        'checkin_id', existing_checkin.id, 'expected_at', existing_checkin.expected_at
      );
    end if;
    if existing_checkin.request_interval_minutes <> p_minutes_from_now then
      return jsonb_build_object('ok', false, 'code', 'idempotency_key_reused');
    end if;
    checkin_id := existing_checkin.id;
    expected_at_value := existing_checkin.expected_at;
    return jsonb_build_object(
      'ok', true, 'replayed', true, 'checkin_id', checkin_id, 'expected_at', expected_at_value
    );
  end if;
  return jsonb_build_object(
    'ok', true, 'replayed', false, 'checkin_id', checkin_id, 'expected_at', expected_at_value
  );
end;
$function$;


CREATE OR REPLACE FUNCTION public.complete_active_job_checkin(p_checkin_id uuid, p_client_request_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  user_id uuid := auth.uid();
  completed_id uuid;
  completed_at_value timestamptz;
  checkin public.job_safety_checkins%rowtype;
  assignment public.job_assignments%rowtype;
  job public.jobs%rowtype;
  prior_request_checkin_id uuid;
begin
  if user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if private.current_role() <> 'teen'::public.mort_role or not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_teen_account_required');
  end if;
  if p_client_request_id is null then
    return jsonb_build_object('ok', false, 'code', 'client_request_id_required');
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'job-checkin-complete:' || user_id::text || ':' || p_client_request_id::text,
      0
    )
  );
  select checkin_row.* into checkin
  from public.job_safety_checkins checkin_row
  where checkin_row.id = p_checkin_id
    and checkin_row.teen_user_id = user_id;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'active_checkin_not_found');
  end if;

  select assignment_row.* into assignment
  from public.job_assignments assignment_row
  where assignment_row.application_id = checkin.application_id
    and assignment_row.job_id = checkin.job_id
    and assignment_row.teen_user_id = user_id
    and assignment_row.adult_user_id = checkin.adult_user_id
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'active_checkin_not_found');
  end if;

  select job_row.* into job
  from public.jobs job_row
  where job_row.id = assignment.job_id
    and job_row.poster_id = assignment.adult_user_id
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'active_checkin_not_found');
  end if;

  select checkin_row.* into checkin
  from public.job_safety_checkins checkin_row
  where checkin_row.id = p_checkin_id
    and checkin_row.teen_user_id = user_id
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'active_checkin_not_found');
  end if;

  select checkin_row.id into prior_request_checkin_id
  from public.job_safety_checkins checkin_row
  where checkin_row.teen_user_id = user_id
    and checkin_row.completion_request_id = p_client_request_id;
  if found and prior_request_checkin_id <> p_checkin_id then
    return jsonb_build_object('ok', false, 'code', 'idempotency_key_reused');
  end if;

  if checkin.status = 'completed' then
    if checkin.completion_request_id = p_client_request_id then
      return jsonb_build_object(
        'ok', true, 'replayed', true, 'payload_verified', true,
        'checkin_id', checkin.id, 'completed_at', checkin.completed_at
      );
    end if;
    if checkin.completion_request_id is not null then
      return jsonb_build_object('ok', false, 'code', 'idempotency_key_reused');
    end if;
    -- Before request IDs were persisted, completed rows were idempotent
    -- success responses for the authorized teen. Keep that safe no-op contract
    -- for legacy and already-completed rows without binding a new request ID.
    return jsonb_build_object(
      'ok', true, 'replayed', true, 'payload_verified', false,
      'checkin_id', checkin.id, 'completed_at', checkin.completed_at
    );
  end if;

  if checkin.status <> 'scheduled'
     or assignment.status not in ('accepted', 'in_progress')
     or job.status not in ('filled', 'in_progress')
     or not exists (
       select 1 from public.job_applications application
       where application.id = assignment.application_id
         and application.job_id = assignment.job_id
         and application.applicant_id = assignment.teen_user_id
         and application.status = 'accepted'::public.mort_application_status
     ) then
    return jsonb_build_object('ok', false, 'code', 'active_checkin_not_found');
  end if;

  update public.job_safety_checkins
  set status = 'completed',
      completed_at = clock_timestamp(),
      completion_request_id = p_client_request_id
  where id = p_checkin_id
    and teen_user_id = user_id
    and status = 'scheduled'
  returning id, completed_at into completed_id, completed_at_value;

  if completed_id is null then
    return jsonb_build_object('ok', false, 'code', 'active_checkin_not_found');
  end if;
  return jsonb_build_object(
    'ok', true, 'replayed', false, 'payload_verified', true,
    'checkin_id', completed_id, 'completed_at', completed_at_value
  );
end;
$function$;

commit;

