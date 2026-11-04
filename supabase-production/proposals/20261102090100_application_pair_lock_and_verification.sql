-- PROPOSAL ONLY — do not place in supabase-production/migrations or apply to production.
-- Adds the existing block/message participant-pair lock to acceptance and
-- rechecks all role-required current verification tracks at both gates.
begin;
do $guard$
begin
  if md5(pg_get_functiondef('public.get_job_application_eligibility(uuid)'::regprocedure))
     <> '401d64ec19cf1fa1ab072709266fe4a7' then
    raise exception 'proposal_source_mismatch:get_job_application_eligibility';
  end if;
  if md5(pg_get_functiondef('public.mort_accept_job_application(uuid)'::regprocedure))
     <> 'a44e036f16579106d9ae615d2a54235f' then
    raise exception 'proposal_source_mismatch:mort_accept_job_application';
  end if;
  if md5(pg_get_functiondef('public.update_my_job_application_status(uuid,text,timestamp with time zone)'::regprocedure))
     <> '783f373cd4ad853ee690eae22abc6289' then
    raise exception 'proposal_source_mismatch:update_my_job_application_status';
  end if;
end;
$guard$;

CREATE OR REPLACE FUNCTION public.get_job_application_eligibility(p_job_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_profile public.profiles%rowtype;
  v_job public.jobs%rowtype;
  v_release public.mort_release_control%rowtype;
  v_age integer;
  v_now timestamptz;
  v_guardian_linked boolean;
  v_poster_active boolean := false;
  v_poster_identity_verified boolean := false;
  v_profile_found boolean := false;
  v_job_found boolean := false;
  v_release_found boolean := false;
  v_code text := 'eligible';
  v_message text := 'You can apply to this job.';
begin
  if auth.uid() is null then
    return jsonb_build_object('eligible', false, 'code', 'authentication_required', 'message', 'Sign in to apply.', 'guardian_required_for_this_job', false, 'guardian_linked', false);
  end if;
  select * into v_job from public.jobs job where job.id = p_job_id for share;
  v_job_found := found;
  if v_job_found then
    -- Serialize application eligibility with a concurrent block of the same
    -- teen/poster pair, using the lock key shared by block and message RPCs.
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(
        least(auth.uid(), v_job.poster_id)::text || ':' || greatest(auth.uid(), v_job.poster_id)::text,
        0
      )
    );
    select (poster.account_status = 'active') into v_poster_active
    from public.profiles poster
    where poster.id = v_job.poster_id
    for share;
    v_poster_active := coalesce(v_poster_active, false);
    perform verification.id
    from public.verification_cases verification
    where verification.user_id = v_job.poster_id
      and verification.verification_type = 'identity'
      and verification.status = 'verified'::public.mort_verification_status
    for share;
  end if;
  -- Guardian unlink and consent-revocation workflows lock link rows before
  -- profile rows. Preserve that order here to avoid link/profile deadlocks.
  perform gl.id
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
    and guardian_auth.email_confirmed_at is not null
  order by gl.guardian_user_id, gl.id
  for share of gl, guardian_profile, guardian_auth;
  -- Match acceptance's job -> pair -> Guardian link/identity -> teen profile
  -- order. Locking the teen profile before a Guardian link can deadlock with
  -- unlink, which locks the link before updating the profile.
  select * into v_profile from public.profiles profile where profile.id = auth.uid() for share;
  v_profile_found := found;
  select * into v_release from public.mort_release_control release where release.is_primary for share;
  v_release_found := found;
  -- Lock every age-verification row in the eligible state, including expired
  -- rows, then evaluate expiry against the post-lock wall clock.
  perform verification.id
  from public.verification_cases verification
  where verification.user_id = auth.uid()
    and verification.verification_type in ('age', 'school_id', 'school_email')
    and verification.status = 'verified'::public.mort_verification_status
  for share;
  v_now := clock_timestamp();
  if v_job_found then
    select exists (
      select 1 from public.verification_cases vc
      where vc.user_id = v_job.poster_id
        and vc.verification_type = 'identity'
        and vc.status = 'verified'::public.mort_verification_status
        and (vc.expires_at is null or vc.expires_at > v_now)
    ) into v_poster_identity_verified;
  end if;
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
      and extract(year from age(v_now::date, guardian_profile.date_of_birth)) >= 18
      and guardian_auth.email_confirmed_at is not null
  ) into v_guardian_linked;
  v_guardian_linked := coalesce(v_guardian_linked, false);
  if not v_profile_found or v_profile.role <> 'teen'::public.mort_role or v_profile.account_status <> 'active' then
    v_code := 'active_teen_account_required'; v_message := 'An active teen account is required.';
  elsif not v_release_found or v_release.maintenance_mode then
    v_code := 'maintenance_mode_active'; v_message := 'The marketplace is temporarily unavailable.';
  elsif not v_release.public_marketplace_enabled then
    v_code := 'public_marketplace_disabled'; v_message := 'The marketplace is not accepting public applications yet.';
  elsif not v_job_found or v_job.status <> 'open'::public.mort_job_status or v_job.safety_review_status <> 'approved' or not v_job.applications_open or (v_job.expires_at is not null and v_job.expires_at <= v_now) then
    v_code := 'job_not_available'; v_message := 'This job is not accepting applications.';
  elsif not v_poster_active or not v_poster_identity_verified then
    v_code := 'job_not_available'; v_message := 'This job is not accepting applications.';
  elsif exists (
    select 1 from public.job_applications application
    where application.job_id = p_job_id
      and application.applicant_id = auth.uid()
      and application.status not in ('withdrawn'::public.mort_application_status, 'rejected'::public.mort_application_status, 'cancelled'::public.mort_application_status)
  ) then
    v_code := 'application_already_exists'; v_message := 'You already have an application for this job.';
  elsif v_profile.date_of_birth is null then
    v_code := 'date_of_birth_required'; v_message := 'Complete age verification before applying.';
  else
    v_age := extract(year from age(v_now::date, v_profile.date_of_birth))::integer;
    if v_age < v_job.age_min or v_age > v_job.age_max then
      v_code := 'applicant_age_not_allowed'; v_message := 'Your age does not match this job’s requirements.';
    elsif not exists (
      select 1 from public.verification_cases vc
      where vc.user_id = auth.uid() and vc.verification_type = 'age'
        and vc.status = 'verified'::public.mort_verification_status
        and (vc.expires_at is null or vc.expires_at > v_now)
    ) then
      v_code := 'age_verification_required'; v_message := 'Complete age verification before applying.';
    elsif not exists (
      select 1 from public.verification_cases vc
      where vc.user_id = auth.uid() and vc.verification_type = 'school_id'
        and vc.status = 'verified'::public.mort_verification_status
        and (vc.expires_at is null or vc.expires_at > v_now)
    ) then
      v_code := 'school_id_verification_required'; v_message := 'Current school verification is required before applying.';
    elsif not exists (
      select 1 from public.verification_cases vc
      where vc.user_id = auth.uid() and vc.verification_type = 'school_email'
        and vc.status = 'verified'::public.mort_verification_status
        and (vc.expires_at is null or vc.expires_at > v_now)
    ) then
      v_code := 'school_email_verification_required'; v_message := 'Current school email verification is required before applying.';
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
$function$;


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
  v_job_id uuid;
  v_applicant_id uuid;
  v_assignment uuid;
  v_conversation uuid;
  v_date_of_birth date;
  v_applicant_age integer;
  v_now timestamptz;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if not private.is_active_user()
     or private.current_role() <> 'adult'::public.mort_role then
    raise exception 'An active adult account is required';
  end if;

  -- Resolve the target without locking the application. The ownership-scoped
  -- job lock is the first row lock, so a non-owner cannot hold another
  -- poster's application while failing authorization.
  select application.job_id, application.applicant_id
    into v_job_id, v_applicant_id
  from public.job_applications application
  where application.id = p_application_id;
  if not found then raise exception 'Application not found'; end if;

  select * into v_job
  from public.jobs
  where id = v_job_id
    and poster_id = v_user
  for update;
  if not found then raise exception 'Application not found'; end if;

  -- Keep the caller authorized for the duration of acceptance. Job ownership
  -- is protected by the job-row lock above; this profile lock serializes
  -- account suspension or role revocation with the transaction.
  perform profile.id
  from public.profiles profile
  where profile.id = v_user
    and profile.role = 'adult'::public.mort_role
    and profile.account_status = 'active'
  for share;
  if not found then raise exception 'An active adult account is required'; end if;

  -- Match the deterministic participant-pair lock shared by block and
  -- message operations before taking the application-row lock.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      least(v_user, v_applicant_id)::text || ':' || greatest(v_user, v_applicant_id)::text,
      0
    )
  );

  select * into v_app
  from public.job_applications
  where id = p_application_id
    and job_id = v_job.id
  for update;
  if not found then raise exception 'Application not found'; end if;
  if v_app.applicant_id <> v_applicant_id then
    raise exception 'Application changed; refresh and try again';
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

  -- Unlink/revocation locks Guardian links before updating teen profiles.
  -- Lock matching active consent rows and Guardian identity records first so
  -- the final eligibility predicate cannot race a revocation.
  if v_job.requires_guardian_approval then
    perform gl.id
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
      and guardian_auth.email_confirmed_at is not null
    order by gl.guardian_user_id, gl.id
    for share of gl, guardian_profile, guardian_auth;
  end if;

  select profile.date_of_birth into v_date_of_birth
  from public.profiles profile
  where profile.id = v_app.applicant_id
    and profile.role = 'teen'::public.mort_role
    and profile.account_status = 'active'
  for share;
  if not found or v_date_of_birth is null then
    raise exception 'Teen age verification must be current';
  end if;

  perform verification.id
  from public.verification_cases verification
  where (verification.user_id = v_user and verification.verification_type = 'identity')
     or (verification.user_id = v_app.applicant_id
         and verification.verification_type in ('age', 'school_id', 'school_email'))
  for share;
  v_now := clock_timestamp();

  if not exists (
    select 1 from public.verification_cases vc
    where vc.user_id = v_user
      and vc.verification_type = 'identity'
      and vc.status = 'verified'::public.mort_verification_status
      and (vc.expires_at is null or vc.expires_at > v_now)
  ) then
    raise exception 'Adult identity verification must be completed';
  end if;

  if not exists (
    select 1 from public.verification_cases vc
    where vc.user_id = v_app.applicant_id
      and vc.verification_type = 'age'
      and vc.status = 'verified'::public.mort_verification_status
      and (vc.expires_at is null or vc.expires_at > v_now)
  ) then
    raise exception 'Teen age verification must be current';
  end if;
  if not exists (
    select 1 from public.verification_cases vc
    where vc.user_id = v_app.applicant_id
      and vc.verification_type = 'school_id'
      and vc.status = 'verified'::public.mort_verification_status
      and (vc.expires_at is null or vc.expires_at > v_now)
  ) then
    raise exception 'Current teen school ID verification is required';
  end if;
  if not exists (
    select 1 from public.verification_cases vc
    where vc.user_id = v_app.applicant_id
      and vc.verification_type = 'school_email'
      and vc.status = 'verified'::public.mort_verification_status
      and (vc.expires_at is null or vc.expires_at > v_now)
  ) then
    raise exception 'Current teen school email verification is required';
  end if;

  v_applicant_age := extract(year from age(v_now::date, v_date_of_birth))::integer;
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
      and extract(year from age(v_now::date, guardian_profile.date_of_birth)) >= 18
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
$function$;

CREATE OR REPLACE FUNCTION public.update_my_job_application_status(
  p_application_id uuid,
  p_action text,
  p_expected_updated_at timestamp with time zone DEFAULT NULL::timestamp with time zone
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
declare
  v_user uuid := auth.uid();
  v_role public.mort_role := private.current_role();
  v_app public.job_applications%rowtype;
  v_job public.jobs%rowtype;
  v_target_job_id uuid;
  v_target_applicant_id uuid;
  v_assignment uuid;
  v_recipient uuid;
  v_title text;
  v_body text;
  v_updated jsonb;
begin
  if v_user is null or not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;

  -- This lookup is caller-scoped but intentionally unlocked. Acceptance takes
  -- locks in job -> active poster profile -> participant pair -> application
  -- order, matching mort_accept_job_application and application submission.
  select ja.job_id, ja.applicant_id
    into v_target_job_id, v_target_applicant_id
  from public.job_applications ja
  where ja.id = p_application_id
    and (
      ja.applicant_id = v_user
      or exists (
        select 1 from public.jobs j
        where j.id = ja.job_id and j.poster_id = v_user
      )
    );
  if not found then
    return jsonb_build_object('ok', false, 'code', 'application_not_available');
  end if;

  if p_action = 'accepted' then
    if v_role <> 'adult'::public.mort_role or v_target_applicant_id = v_user then
      return jsonb_build_object('ok', false, 'code', 'application_action_not_allowed');
    end if;

    select * into v_job
    from public.jobs
    where id = v_target_job_id and poster_id = v_user
    for update;
    if not found then
      return jsonb_build_object('ok', false, 'code', 'application_not_available');
    end if;

    perform profile.id
    from public.profiles profile
    where profile.id = v_user
      and profile.role = 'adult'::public.mort_role
      and profile.account_status = 'active'
    for share;
    if not found then
      return jsonb_build_object('ok', false, 'code', 'active_account_required');
    end if;

    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(
        least(v_user, v_target_applicant_id)::text || ':' || greatest(v_user, v_target_applicant_id)::text,
        0
      )
    );

    select ja.* into v_app
    from public.job_applications ja
    where ja.id = p_application_id and ja.job_id = v_job.id
    for update;
    if not found or v_app.applicant_id <> v_target_applicant_id then
      return jsonb_build_object('ok', false, 'code', 'application_not_available');
    end if;
    if p_expected_updated_at is not null and v_app.updated_at <> p_expected_updated_at then
      return jsonb_build_object('ok', false, 'code', 'application_changed_refresh');
    end if;

    v_assignment := public.mort_accept_job_application(v_app.id);
    v_updated := public.get_my_job_applications(v_app.id)->'items'->0;
    return jsonb_build_object('ok', true, 'application', v_updated, 'assignment_id', v_assignment);
  end if;

  select ja.* into v_app
  from public.job_applications ja
  where ja.id = p_application_id
    and (
      ja.applicant_id = v_user
      or exists (
        select 1 from public.jobs j
        where j.id = ja.job_id and j.poster_id = v_user
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
  if p_action in ('shortlisted', 'rejected', 'viewed')
     and v_role = 'adult'::public.mort_role
     and v_job.poster_id = v_user
     and v_app.status in ('submitted'::public.mort_application_status, 'shortlisted'::public.mort_application_status) then
    if p_action = 'viewed' then
      update public.job_applications set viewed_at = coalesce(viewed_at, now()) where id = v_app.id;
    else
      update public.job_applications set status = p_action::public.mort_application_status where id = v_app.id;
      v_recipient := v_app.applicant_id;
      v_title := case when p_action = 'shortlisted' then 'Application shortlisted' else 'Application update' end;
      v_body := case when p_action = 'shortlisted' then 'Your application was shortlisted.' else 'Your application was declined.' end;
    end if;
  elsif p_action = 'withdrawn'
        and v_role = 'teen'::public.mort_role
        and v_app.applicant_id = v_user
        and v_app.status in ('submitted'::public.mort_application_status, 'shortlisted'::public.mort_application_status) then
    update public.job_applications
    set status = 'withdrawn'::public.mort_application_status, withdrawn_at = now()
    where id = v_app.id;
    v_recipient := v_job.poster_id;
    v_title := 'Application withdrawn';
    v_body := 'A teen withdrew their application.';
  else
    return jsonb_build_object('ok', false, 'code', 'application_action_not_allowed');
  end if;

  if v_recipient is not null then
    insert into public.notifications(user_id, notification_type, title, body, data)
    values (
      v_recipient,
      'application_status',
      v_title,
      v_body,
      jsonb_build_object('application_id', v_app.id, 'job_id', v_app.job_id)
    );
  end if;
  v_updated := public.get_my_job_applications(v_app.id)->'items'->0;
  return jsonb_build_object('ok', true, 'application', v_updated, 'assignment_id', v_assignment);
end;
$function$;

commit;

