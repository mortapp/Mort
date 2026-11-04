-- Apply Guardian opt-in at submission, and hide unapproved applications
-- from job posters across RPC and direct RLS paths.
begin;

-- Serialize preference changes with eligibility. The Guardian-link row is the
-- shared lock, so an opt-in cannot race an application insert.
do $migration$
declare
  v_def text;
  v_old text := $old$
  if not exists (
    select 1
    from public.guardian_links link
    where link.id = p_link_id
      and link.teen_user_id = user_id
      and link.status = 'active'
  ) then
    return jsonb_build_object('ok', false, 'code', 'active_guardian_link_not_found');
  end if;
$old$;
  v_new text := $new$
  perform link.id
  from public.guardian_links link
  where link.id = p_link_id
    and link.teen_user_id = user_id
    and link.status = 'active'
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'active_guardian_link_not_found');
  end if;
$new$;
begin
  v_def := pg_get_functiondef('public.set_guardian_alert_preferences(uuid,boolean,boolean,boolean,boolean,boolean,boolean)'::regprocedure);
  if position(v_old in v_def)=0 then raise exception 'guardian_preference_lock_patch_failed'; end if;
  v_def := replace(v_def,v_old,v_new);
  execute v_def;
end;
$migration$;

-- Add the effective Guardian approval requirement to the existing eligibility
-- RPC, retaining all current age, verification, block and job-state checks.
do $migration$
declare
  v_def text;
  v_before text;
  v_old text;
  v_new text;
begin
  v_def := pg_get_functiondef('public.get_job_application_eligibility(uuid)'::regprocedure);

  v_old := $old$  v_guardian_linked boolean;$old$;
  v_new := $new$  v_guardian_linked boolean;
  v_guardian_approval_required boolean := false;$new$;
  v_before := v_def;
  v_def := replace(v_def,v_old,v_new);
  if v_def=v_before then raise exception 'guardian_eligibility_variable_patch_failed'; end if;

  v_old := $old$  v_now := clock_timestamp();$old$;
  v_new := $new$  perform preference.link_id
  from public.guardian_links gl
  join public.guardian_preferences preference on preference.link_id=gl.id
  where gl.teen_user_id=auth.uid()
    and gl.status='active'
    and gl.teen_consent_at is not null
    and gl.guardian_consent_at is not null
  for share of preference;
  v_now := clock_timestamp();$new$;
  v_before := v_def;
  v_def := replace(v_def,v_old,v_new);
  if v_def=v_before then raise exception 'guardian_preference_read_lock_patch_failed'; end if;

  v_old := $old$  v_guardian_linked := coalesce(v_guardian_linked, false);$old$;
  v_new := $new$  v_guardian_linked := coalesce(v_guardian_linked, false);
  select
    coalesce(v_job.requires_guardian_approval,false)
    or exists (
      select 1
      from public.guardian_links gl
      join public.guardian_preferences preference on preference.link_id=gl.id
      where gl.teen_user_id=auth.uid()
        and gl.status='active'
        and gl.teen_consent_at is not null
        and gl.guardian_consent_at is not null
        and preference.optional_job_approval_enabled
    )
  into v_guardian_approval_required;$new$;
  v_before := v_def;
  v_def := replace(v_def,v_old,v_new);
  if v_def=v_before then raise exception 'guardian_preference_policy_patch_failed'; end if;

  v_old := $old$  elsif v_job.requires_guardian_approval and not v_guardian_linked then$old$;
  v_new := $new$  elsif v_guardian_approval_required and not v_guardian_linked then$new$;
  v_before := v_def;
  v_def := replace(v_def,v_old,v_new);
  if v_def=v_before then raise exception 'guardian_eligibility_gate_patch_failed'; end if;

  v_old := $old$'guardian_required_for_this_job', coalesce(v_job.requires_guardian_approval, false),$old$;
  v_new := $new$'guardian_required_for_this_job', coalesce(v_job.requires_guardian_approval, false),
    'guardian_approval_required', v_guardian_approval_required,$new$;
  v_before := v_def;
  v_def := replace(v_def,v_old,v_new);
  if v_def=v_before then raise exception 'guardian_eligibility_response_patch_failed'; end if;

  execute v_def;
end;
$migration$;

-- Set pending at the single privileged insertion point. Direct table INSERT is
-- not granted to authenticated clients.
do $migration$
declare
  v_def text;
  v_old text := $old$  insert into public.job_applications(job_id, applicant_id, cover_note)
  values (p_job_id, v_user_id, nullif(btrim(p_cover_note), ''))
  returning id into v_application_id;$old$;
  v_new text := $new$  insert into public.job_applications(job_id, applicant_id, cover_note, guardian_decision_status)
  values (
    p_job_id,
    v_user_id,
    nullif(btrim(p_cover_note), ''),
    case
      when coalesce((v_eligibility->>'guardian_approval_required')::boolean,false)
        then 'pending'
      else 'not_required'
    end
  )
  returning id into v_application_id;$new$;
begin
  v_def := pg_get_functiondef('public.mort_submit_job_application(uuid,text)'::regprocedure);
  if position(v_old in v_def)=0 then raise exception 'guardian_submission_insert_patch_failed'; end if;
  v_def := replace(v_def,v_old,v_new);
  execute v_def;
end;
$migration$;

-- Guardian users must be allowed through this reader; poster visibility is
-- conditional on approval. Guardian IDs and rejection reasons stay private.
do $migration$
declare
  v_def text;
  v_old text;
  v_new text;
  v_before text;
begin
  v_def := pg_get_functiondef('public.get_my_job_applications(uuid)'::regprocedure);

  v_old := $old$if v_user is null or not private.is_active_user() then$old$;
  v_new := $new$if v_user is null or not exists (
    select 1 from public.profiles current_profile
    where current_profile.id=v_user
      and current_profile.account_status='active'
      and current_profile.role in ('teen'::public.mort_role,'adult'::public.mort_role,'guardian'::public.mort_role,'admin'::public.mort_role,'moderator'::public.mort_role)
  ) then$new$;
  v_before := v_def;
  v_def := replace(v_def,v_old,v_new);
  if v_def=v_before then raise exception 'guardian_application_reader_role_patch_failed'; end if;

  v_old := $old$'guardian_id',ja.guardian_id,'availability_confirmed'$old$;
  v_new := $new$'guardian_id',case when ja.applicant_id=v_user or exists(
    select 1 from public.guardian_links gl
    where gl.teen_user_id=ja.applicant_id and gl.guardian_user_id=v_user
      and gl.status='active' and gl.teen_consent_at is not null and gl.guardian_consent_at is not null
  ) then ja.guardian_id else null end,
  'guardian_decision_status',ja.guardian_decision_status,
  'guardian_decided_at',ja.guardian_decided_at,
  'guardian_decision_reason',case when ja.applicant_id=v_user or exists(
    select 1 from public.guardian_links gl
    where gl.teen_user_id=ja.applicant_id and gl.guardian_user_id=v_user
      and gl.status='active' and gl.teen_consent_at is not null and gl.guardian_consent_at is not null
  ) then ja.guardian_decision_reason else null end,
  'availability_confirmed'$new$;
  v_before := v_def;
  v_def := replace(v_def,v_old,v_new);
  if v_def=v_before then raise exception 'guardian_application_reader_payload_patch_failed'; end if;

  v_old := $old$and (ja.applicant_id=v_user or j.poster_id=v_user or exists(select 1 from public.guardian_links gl where gl.teen_user_id=ja.applicant_id and gl.guardian_user_id=v_user and gl.status='active' and gl.teen_consent_at is not null and gl.guardian_consent_at is not null));$old$;
  v_new := $new$and (
    ja.applicant_id=v_user
    or (
      j.poster_id=v_user
      and (
        (not j.requires_guardian_approval and ja.guardian_decision_status='not_required')
        or (
          ja.guardian_decision_status='approved'
          and exists (
            select 1
            from public.guardian_links gl
            join public.profiles guardian_profile on guardian_profile.id=gl.guardian_user_id
            join auth.users guardian_auth on guardian_auth.id=gl.guardian_user_id
            where gl.teen_user_id=ja.applicant_id
              and gl.guardian_user_id=ja.guardian_decided_by
              and gl.status='active'
              and gl.teen_consent_at is not null
              and gl.guardian_consent_at is not null
              and guardian_profile.role='guardian'::public.mort_role
              and guardian_profile.account_status='active'
              and guardian_profile.date_of_birth is not null
              and extract(year from age(current_date,guardian_profile.date_of_birth))>=18
              and guardian_auth.email_confirmed_at is not null
          )
        )
      )
    )
    or exists(
      select 1
      from public.guardian_links gl
      join public.profiles guardian_profile on guardian_profile.id=gl.guardian_user_id
      join auth.users guardian_auth on guardian_auth.id=gl.guardian_user_id
      where gl.teen_user_id=ja.applicant_id
        and gl.guardian_user_id=v_user
        and gl.status='active'
        and gl.teen_consent_at is not null
        and gl.guardian_consent_at is not null
        and guardian_profile.role='guardian'::public.mort_role
        and guardian_profile.account_status='active'
        and guardian_profile.date_of_birth is not null
        and extract(year from age(current_date,guardian_profile.date_of_birth))>=18
        and guardian_auth.email_confirmed_at is not null
    )
  );$new$;
  v_before := v_def;
  v_def := replace(v_def,v_old,v_new);
  if v_def=v_before then raise exception 'guardian_application_visibility_patch_failed'; end if;

  execute v_def;
end;
$migration$;

-- Posters cannot mutate applications that are still awaiting Guardian review.
do $migration$
declare
  v_def text;
  v_old text := $old$where ja.id=p_application_id and (ja.applicant_id=v_user or exists(select 1 from public.jobs j where j.id=ja.job_id and j.poster_id=v_user)) for update;$old$;
  v_new text := $new$where ja.id=p_application_id and (
    ja.applicant_id=v_user
    or exists(
      select 1
      from public.jobs j
      where j.id=ja.job_id and j.poster_id=v_user
        and (
          (not j.requires_guardian_approval and ja.guardian_decision_status='not_required')
          or (
            ja.guardian_decision_status='approved'
            and exists(
              select 1
              from public.guardian_links gl
              join public.profiles guardian_profile on guardian_profile.id=gl.guardian_user_id
              join auth.users guardian_auth on guardian_auth.id=gl.guardian_user_id
              where gl.teen_user_id=ja.applicant_id
                and gl.guardian_user_id=ja.guardian_decided_by
                and gl.status='active'
                and gl.teen_consent_at is not null
                and gl.guardian_consent_at is not null
                and guardian_profile.role='guardian'::public.mort_role
                and guardian_profile.account_status='active'
                and guardian_profile.date_of_birth is not null
                and extract(year from age(current_date,guardian_profile.date_of_birth))>=18
                and guardian_auth.email_confirmed_at is not null
            )
          )
        )
    )
  ) for update;$new$;
begin
  v_def := pg_get_functiondef('public.update_my_job_application_status(uuid,text,timestamptz)'::regprocedure);
  if position(v_old in v_def)=0 then raise exception 'guardian_application_status_access_patch_failed'; end if;
  v_def := replace(v_def,v_old,v_new);
  execute v_def;
end;
$migration$;

-- Acceptance requires an actual approval, not merely an active Guardian link.
do $migration$
declare
  v_def text;
  v_old text := $old$  if v_job.requires_guardian_approval and not exists (
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
  end if;$old$;
  v_new text := $new$  if (v_job.requires_guardian_approval or v_app.guardian_decision_status <> 'not_required')
     and (
       v_app.guardian_decision_status <> 'approved'
       or v_app.guardian_decided_by is null
       or v_app.guardian_id is distinct from v_app.guardian_decided_by
       or not exists (
         select 1
         from public.guardian_links gl
         join public.profiles guardian_profile on guardian_profile.id = gl.guardian_user_id
         join auth.users guardian_auth on guardian_auth.id = gl.guardian_user_id
         where gl.teen_user_id = v_app.applicant_id
           and gl.guardian_user_id = v_app.guardian_decided_by
           and gl.status = 'active'
           and gl.teen_consent_at is not null
           and gl.guardian_consent_at is not null
           and guardian_profile.role = 'guardian'::public.mort_role
           and guardian_profile.account_status = 'active'
           and guardian_profile.date_of_birth is not null
           and extract(year from age(current_date, guardian_profile.date_of_birth)) >= 18
           and guardian_auth.email_confirmed_at is not null
       )
     ) then
    raise exception 'guardian_approval_required';
  end if;$new$;
begin
  v_def := pg_get_functiondef('public.mort_accept_job_application(uuid)'::regprocedure);
  if position(v_old in v_def)=0 then raise exception 'guardian_acceptance_gate_patch_failed'; end if;
  v_def := replace(v_def,v_old,v_new);
  execute v_def;
end;
$migration$;

-- Return Guardian state from the teen's submission RPC response.
do $migration$
declare
  v_def text;
  v_old text := $old$
      'guardian_id', v_application.guardian_id,
      'availability_confirmed', v_application.availability_confirmed,
$old$;
  v_new text := $new$
      'guardian_id', v_application.guardian_id,
      'guardian_decision_status', v_application.guardian_decision_status,
      'guardian_decided_at', v_application.guardian_decided_at,
      'guardian_decision_reason', v_application.guardian_decision_reason,
      'availability_confirmed', v_application.availability_confirmed,
$new$;
begin
  v_def := pg_get_functiondef('public.submit_job_application(uuid,text,boolean,uuid[])'::regprocedure);
  if position(v_old in v_def)=0 then raise exception 'guardian_submission_response_patch_failed'; end if;
  v_def := replace(v_def,v_old,v_new);
  execute v_def;
end;
$migration$;

drop policy if exists applications_select_parties on public.job_applications;
create policy applications_select_parties
on public.job_applications
for select
to authenticated
using (
  applicant_id=(select auth.uid())
  or exists (
    select 1
    from public.jobs j
    where j.id=job_applications.job_id
      and j.poster_id=(select auth.uid())
      and (
        (not j.requires_guardian_approval and job_applications.guardian_decision_status='not_required')
        or (
          job_applications.guardian_decision_status='approved'
          and exists (
            select 1
            from public.guardian_links gl
            join public.profiles guardian_profile on guardian_profile.id=gl.guardian_user_id
            join auth.users guardian_auth on guardian_auth.id=gl.guardian_user_id
            where gl.teen_user_id=job_applications.applicant_id
              and gl.guardian_user_id=job_applications.guardian_decided_by
              and gl.status='active'
              and gl.teen_consent_at is not null
              and gl.guardian_consent_at is not null
              and guardian_profile.role='guardian'::public.mort_role
              and guardian_profile.account_status='active'
              and guardian_profile.date_of_birth is not null
              and extract(year from age(current_date,guardian_profile.date_of_birth))>=18
              and guardian_auth.email_confirmed_at is not null
          )
        )
      )
  )
  or private.has_staff_role(array['admin'::public.mort_role,'moderator'::public.mort_role])
);

commit;
