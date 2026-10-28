-- Revalidate a job's guardian requirement at the acceptance boundary. An
-- application can remain open after the linked guardian has withdrawn consent.
create or replace function public.mort_accept_job_application(p_application_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user uuid := auth.uid();
  v_app public.job_applications%rowtype;
  v_job public.jobs%rowtype;
  v_assignment uuid;
  v_conversation uuid;
  v_date_of_birth date;
  v_applicant_age integer;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if not private.is_active_user()
     or private.current_role() <> 'adult'::public.mort_role then
    raise exception 'An active adult account is required';
  end if;

  select * into v_app
  from public.job_applications
  where id = p_application_id
  for update;
  if not found then raise exception 'Application not found'; end if;

  select * into v_job
  from public.jobs
  where id = v_app.job_id
  for update;
  if not found or v_job.poster_id <> v_user then
    raise exception 'Application not found';
  end if;
  if v_job.status <> 'open'::public.mort_job_status
     or v_job.safety_review_status <> 'approved'
     or v_app.status not in (
       'submitted'::public.mort_application_status,
       'shortlisted'::public.mort_application_status
     ) then
    raise exception 'Application is not eligible for acceptance';
  end if;
  if exists (
    select 1 from public.user_blocks b
    where (b.blocker_id = v_user and b.blocked_id = v_app.applicant_id)
       or (b.blocker_id = v_app.applicant_id and b.blocked_id = v_user)
  ) then
    raise exception 'This interaction is unavailable';
  end if;
  if not exists (
    select 1 from public.verification_cases vc
    where vc.user_id = v_user
      and vc.verification_type = 'identity'
      and vc.status = 'verified'::public.mort_verification_status
      and (vc.expires_at is null or vc.expires_at > now())
  ) then
    raise exception 'Adult identity verification must be completed';
  end if;

  select p.date_of_birth into v_date_of_birth
  from public.profiles p
  where p.id = v_app.applicant_id
    and p.role = 'teen'::public.mort_role
    and p.account_status = 'active';
  if not found or v_date_of_birth is null then
    raise exception 'Teen age verification must be current';
  end if;
  if not exists (
    select 1 from public.verification_cases vc
    where vc.user_id = v_app.applicant_id
      and vc.verification_type = 'age'
      and vc.status = 'verified'::public.mort_verification_status
      and (vc.expires_at is null or vc.expires_at > now())
  ) then
    raise exception 'Teen age verification must be current';
  end if;

  v_applicant_age := extract(year from age(current_date, v_date_of_birth))::integer;
  if v_applicant_age < v_job.age_min or v_applicant_age > v_job.age_max then
    raise exception 'Applicant age is outside the job requirements';
  end if;

  if v_job.requires_guardian_approval and not exists (
    select 1
    from public.guardian_links gl
    where gl.teen_user_id = v_app.applicant_id
      and gl.status = 'active'
      and gl.teen_consent_at is not null
      and gl.guardian_consent_at is not null
      and (v_app.guardian_id is null or gl.guardian_user_id = v_app.guardian_id)
  ) then
    raise exception 'guardian_approval_required';
  end if;

  insert into public.job_assignments(
    job_id, application_id, teen_user_id, adult_user_id, agreed_amount
  ) values (
    v_job.id, v_app.id, v_app.applicant_id, v_user, v_job.pay_amount
  ) returning id into v_assignment;

  update public.job_applications
  set status = 'accepted'::public.mort_application_status, updated_at = now()
  where id = v_app.id;

  update public.job_applications
  set status = 'rejected'::public.mort_application_status, updated_at = now()
  where job_id = v_job.id
    and id <> v_app.id
    and status in (
      'submitted'::public.mort_application_status,
      'shortlisted'::public.mort_application_status
    );

  update public.jobs
  set status = 'filled'::public.mort_job_status, updated_at = now()
  where id = v_job.id;

  insert into public.conversations(job_id, assignment_id, conversation_type, status)
  values (v_job.id, v_assignment, 'job', 'active')
  returning id into v_conversation;

  insert into public.conversation_members(conversation_id, user_id)
  values (v_conversation, v_user), (v_conversation, v_app.applicant_id);

  return v_assignment;
end;
$function$;

comment on function public.mort_accept_job_application(uuid) is
  'Accepts an eligible application and rechecks current teen age, adult identity, block, and required guardian consent before creating an assignment.';
