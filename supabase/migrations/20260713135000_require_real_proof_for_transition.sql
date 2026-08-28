create or replace function public.update_application_status_v2(
  p_application_id uuid,
  p_action text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_application public.applications%rowtype;
  v_job public.jobs%rowtype;
  v_action text := lower(btrim(p_action));
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;

  select * into v_application
  from public.applications
  where id = p_application_id
  for update;
  if v_application.id is null then
    return jsonb_build_object('ok', false, 'code', 'application_not_found');
  end if;

  select * into v_job
  from public.jobs
  where id = v_application.job_id
  for update;

  if v_action in ('adult_review', 'guardian_rejected')
     and v_application.guardian_id = auth.uid()
     and v_application.status = 'guardian_pending'
     and public.guardian_is_connected_to_teen(v_application.teen_id, auth.uid()) then
    update public.applications
    set status = v_action::public.application_status
    where id = p_application_id
    returning * into v_application;
  elsif v_action = 'viewed'
     and v_job.poster_id = auth.uid()
     and v_application.status in ('submitted', 'adult_review') then
    update public.applications
    set status = 'viewed', viewed_at = now()
    where id = p_application_id
    returning * into v_application;
  elsif v_action = 'accepted'
     and v_job.poster_id = auth.uid()
     and v_application.status in ('submitted', 'adult_review', 'viewed')
     and v_job.status = 'open'
     and v_job.applications_open then
    update public.applications
    set status = 'accepted'
    where id = p_application_id
    returning * into v_application;
    update public.applications
    set status = 'rejected'
    where job_id = v_job.id
      and id <> p_application_id
      and status in ('submitted', 'adult_review', 'viewed');
    update public.jobs
    set status = 'assigned', applications_open = false
    where id = v_job.id
    returning * into v_job;
  elsif v_action = 'rejected'
     and v_job.poster_id = auth.uid()
     and v_application.status in ('submitted', 'adult_review', 'viewed') then
    update public.applications
    set status = 'rejected'
    where id = p_application_id
    returning * into v_application;
  elsif v_action = 'withdrawn'
     and v_application.teen_id = auth.uid()
     and v_application.status in ('submitted', 'guardian_pending', 'adult_review', 'viewed') then
    update public.applications
    set status = 'withdrawn', withdrawn_at = now()
    where id = p_application_id
    returning * into v_application;
  elsif v_action = 'in_progress'
     and v_application.teen_id = auth.uid()
     and v_application.status = 'accepted'
     and v_job.status = 'assigned' then
    update public.applications
    set status = 'in_progress'
    where id = p_application_id
    returning * into v_application;
    update public.jobs
    set status = 'in_progress'
    where id = v_job.id
    returning * into v_job;
  elsif v_action = 'completed'
     and v_job.poster_id = auth.uid()
     and v_application.status in ('in_progress', 'proof_submitted')
     and v_job.status in ('in_progress', 'proof_submitted') then
    update public.applications
    set status = 'completed'
    where id = p_application_id
    returning * into v_application;
    update public.jobs
    set status = 'completed'
    where id = v_job.id
    returning * into v_job;
  else
    return jsonb_build_object('ok', false, 'code', 'invalid_application_transition');
  end if;

  return jsonb_build_object(
    'ok', true,
    'application', to_jsonb(v_application),
    'job', to_jsonb(v_job)
  );
end;
$$;

revoke execute on function public.update_application_status_v2(uuid, text)
from public, anon;
grant execute on function public.update_application_status_v2(uuid, text)
to authenticated, service_role;
