-- Bind an idempotency key to the application for which it was first used.
-- Reusing a teen's request ID for a different active assignment must not return
-- the previously-created check-in as though it belonged to the new application.

create or replace function public.schedule_active_job_checkin(
  p_application_id uuid,
  p_minutes_from_now integer,
  p_client_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  user_id uuid := auth.uid();
  assignment public.job_assignments%rowtype;
  checkin_id uuid;
  expected_at_value timestamptz;
  existing_application_id uuid;
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
    and status in ('accepted', 'in_progress');
  if not found then
    return jsonb_build_object('ok', false, 'code', 'active_assignment_required');
  end if;

  expected_at_value := now() + make_interval(mins => p_minutes_from_now);
  insert into public.job_safety_checkins (
    application_id, job_id, teen_user_id, adult_user_id,
    expected_at, client_request_id
  ) values (
    assignment.application_id, assignment.job_id, assignment.teen_user_id,
    assignment.adult_user_id, expected_at_value, p_client_request_id
  )
  on conflict (teen_user_id, client_request_id) do nothing
  returning id, expected_at into checkin_id, expected_at_value;

  if checkin_id is null then
    select id, expected_at, application_id
    into checkin_id, expected_at_value, existing_application_id
    from public.job_safety_checkins
    where teen_user_id = user_id
      and client_request_id = p_client_request_id;

    if not found or existing_application_id is distinct from p_application_id then
      return jsonb_build_object('ok', false, 'code', 'client_request_id_conflict');
    end if;
  end if;

  return jsonb_build_object(
    'ok', true, 'checkin_id', checkin_id, 'expected_at', expected_at_value
  );
end;
$function$;
