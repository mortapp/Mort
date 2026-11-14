-- A guardian link can remain active after the guardian account is suspended.
-- Do not treat stale links as valid approval for a job that explicitly requires it.

CREATE OR REPLACE FUNCTION public.get_job_application_eligibility(p_job_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
    select 1
    from public.guardian_links gl
    join public.profiles guardian_profile on guardian_profile.id = gl.guardian_user_id
    join auth.users guardian_auth on guardian_auth.id = gl.guardian_user_id
    where gl.teen_user_id = auth.uid()
      and gl.status = 'active'
      and gl.teen_consent_at is not null
      and gl.guardian_consent_at is not null
      and guardian_profile.role = 'guardian'::public.mort_role
      and guardian_profile.account_status = 'active'
      and guardian_profile.date_of_birth is not null
      and extract(year from age(current_date, guardian_profile.date_of_birth)) >= 18
      and guardian_auth.email_confirmed_at is not null
  ) into v_guardian_linked;
  if not v_profile_found or v_profile.role <> 'teen'::public.mort_role or v_profile.account_status <> 'active' then
    v_code := 'active_teen_account_required'; v_message := 'An active teen account is required.';
  elsif not v_release_found or v_release.maintenance_mode then
    v_code := 'maintenance_mode_active'; v_message := 'The marketplace is temporarily unavailable.';
  elsif not v_release.public_marketplace_enabled then
    v_code := 'public_marketplace_disabled'; v_message := 'The marketplace is not accepting public applications yet.';
  elsif not v_job_found or v_job.status <> 'open'::public.mort_job_status or v_job.safety_review_status <> 'approved' or not v_job.applications_open or (v_job.expires_at is not null and v_job.expires_at <= now()) then
    v_code := 'job_not_available'; v_message := 'This job is not accepting applications.';
  elsif not exists (
    select 1 from public.profiles poster
    where poster.id = v_job.poster_id and poster.account_status = 'active'
  ) then
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
$function$
;

CREATE OR REPLACE FUNCTION public.mort_accept_job_application(p_application_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
    join public.profiles guardian_profile on guardian_profile.id = gl.guardian_user_id
    join auth.users guardian_auth on guardian_auth.id = gl.guardian_user_id
    where gl.teen_user_id = v_app.applicant_id
      and gl.status = 'active'
      and gl.teen_consent_at is not null
      and gl.guardian_consent_at is not null
      and (v_app.guardian_id is null or gl.guardian_user_id = v_app.guardian_id)
      and guardian_profile.role = 'guardian'::public.mort_role
      and guardian_profile.account_status = 'active'
      and guardian_profile.date_of_birth is not null
      and extract(year from age(current_date, guardian_profile.date_of_birth)) >= 18
      and guardian_auth.email_confirmed_at is not null
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
$function$
;
