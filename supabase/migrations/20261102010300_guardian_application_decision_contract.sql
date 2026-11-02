-- Guardian application decisions are optional unless the job or a linked
-- Guardian's saved preference requires approval. Poster access is withheld
-- until approval. All changes are proposal-only pending isolated DB validation.
begin;

alter table public.job_applications
  add column guardian_decision_status text not null default 'not_required',
  add column guardian_decided_by uuid references public.profiles(id) on delete set null,
  add column guardian_decided_at timestamptz,
  add column guardian_decision_reason text;

alter table public.job_applications
  add constraint job_applications_guardian_decision_status_check
  check (guardian_decision_status in ('not_required','pending','approved','rejected'));

alter table public.job_applications
  add constraint job_applications_guardian_decision_reason_length
  check (guardian_decision_reason is null or char_length(guardian_decision_reason) <= 500);

create table private.guardian_application_decision_events (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references public.job_applications(id) on delete cascade,
  teen_user_id uuid not null references public.profiles(id) on delete restrict,
  guardian_user_id uuid not null references public.profiles(id) on delete restrict,
  action text not null check (action in ('approved','rejected','revoked')),
  reason text,
  created_at timestamptz not null default now()
);
alter table private.guardian_application_decision_events enable row level security;
alter table private.guardian_application_decision_events force row level security;
revoke all on private.guardian_application_decision_events from public, anon, authenticated, service_role;

-- Extend the existing eligibility RPC without replacing unrelated age, job,
-- verification, block, or release-control checks. Fail closed if the expected
-- live function shape has drifted.
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
  v_def := replace(v_def, v_old, v_new);
  if v_def = v_before then raise exception 'guardian_eligibility_variable_patch_failed'; end if;

  v_old := $old$  v_now := clock_timestamp();$old$;
  v_new := $new$  -- Lock the preference row so an approval toggle cannot race submission.
  perform preference.link_id
  from public.guardian_links gl
  join public.guardian_preferences preference on preference.link_id = gl.id
  where gl.teen_user_id = auth.uid()
    and gl.status = 'active'
    and gl.teen_consent_at is not null
    and gl.guardian_consent_at is not null
  for share of preference;
  v_now := clock_timestamp();$new$;
  v_before := v_def;
  v_def := replace(v_def, v_old, v_new);
  if v_def = v_before then raise exception 'guardian_preference_lock_patch_failed'; end if;

  v_old := $old$  v_guardian_linked := coalesce(v_guardian_linked, false);$old$;
  v_new := $new$  v_guardian_linked := coalesce(v_guardian_linked, false);
  select
    coalesce(v_job.requires_guardian_approval, false)
    or exists (
      select 1
      from public.guardian_links gl
      join public.guardian_preferences preference on preference.link_id = gl.id
      where gl.teen_user_id = auth.uid()
        and gl.status = 'active'
        and gl.teen_consent_at is not null
        and gl.guardian_consent_at is not null
        and preference.optional_job_approval_enabled
    )
  into v_guardian_approval_required;$new$;
  v_before := v_def;
  v_def := replace(v_def, v_old, v_new);
  if v_def = v_before then raise exception 'guardian_preference_policy_patch_failed'; end if;

  v_old := $old$  elsif v_job.requires_guardian_approval and not v_guardian_linked then$old$;
  v_new := $new$  elsif v_guardian_approval_required and not v_guardian_linked then$new$;
  v_before := v_def;
  v_def := replace(v_def, v_old, v_new);
  if v_def = v_before then raise exception 'guardian_eligibility_gate_patch_failed'; end if;

  v_old := $old$'guardian_required_for_this_job', coalesce(v_job.requires_guardian_approval, false),$old$;
  v_new := $new$'guardian_required_for_this_job', coalesce(v_job.requires_guardian_approval, false),
    'guardian_approval_required', v_guardian_approval_required,$new$;
  v_before := v_def;
  v_def := replace(v_def, v_old, v_new);
  if v_def = v_before then raise exception 'guardian_eligibility_response_patch_failed'; end if;

  execute v_def;
end;
$migration$;

-- Serialize preference changes with application eligibility. The Guardian
-- link row is the shared lock so an opt-in cannot race an application insert.
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

-- Store a pending decision at submission time whenever the job or a linked
-- Guardian preference requires it.
do $migration$
declare
  v_def text;
  v_old text;
  v_new text;
begin
  v_def := pg_get_functiondef('public.mort_submit_job_application(uuid,text)'::regprocedure);
  v_old := $old$  insert into public.job_applications(job_id, applicant_id, cover_note)
  values (p_job_id, v_user_id, nullif(btrim(p_cover_note), ''))
  returning id into v_application_id;$old$;
  v_new := $new$  insert into public.job_applications(job_id, applicant_id, cover_note, guardian_decision_status)
  values (
    p_job_id,
    v_user_id,
    nullif(btrim(p_cover_note), ''),
    case
      when coalesce((v_eligibility->>'guardian_approval_required')::boolean, false)
        then 'pending'
      else 'not_required'
    end
  )
  returning id into v_application_id;$new$;
  if position(v_old in v_def) = 0 then raise exception 'guardian_submission_insert_patch_failed'; end if;
  v_def := replace(v_def, v_old, v_new);
  execute v_def;
end;
$migration$;

-- Permit a verified adult Guardian to read only applications for teens with
-- whom they have an active, dual-consented Guardian link. Hide pending/rejected
-- Guardian-gated applications from the job poster.
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
    where current_profile.id = v_user
      and current_profile.account_status = 'active'
      and current_profile.role in ('teen'::public.mort_role, 'adult'::public.mort_role, 'guardian'::public.mort_role, 'admin'::public.mort_role, 'moderator'::public.mort_role)
  ) then$new$;
  v_before := v_def;
  v_def := replace(v_def, v_old, v_new);
  if v_def = v_before then raise exception 'guardian_application_reader_role_patch_failed'; end if;

  v_old := $old$'guardian_id',ja.guardian_id,'availability_confirmed'$old$;
  v_new := $new
  v_before := v_def;
  v_def := replace(v_def, v_old, v_new);
  if v_def = v_before then raise exception 'guardian_application_reader_payload_patch_failed'; end if;

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
  v_def := replace(v_def, v_old, v_new);
  if v_def = v_before then raise exception 'guardian_application_visibility_patch_failed'; end if;

  execute v_def;
end;
$migration$;

-- A poster cannot mutate or accept an application until any required Guardian
-- decision is approved and the approving Guardian link remains active.
do $migration$
declare
  v_def text;
  v_old text;
  v_new text;
begin
  v_def := pg_get_functiondef('public.update_my_job_application_status(uuid,text,timestamptz)'::regprocedure);
  v_old := $old$where ja.id=p_application_id and (ja.applicant_id=v_user or exists(select 1 from public.jobs j where j.id=ja.job_id and j.poster_id=v_user)) for update;$old$;
  v_new := $new$where ja.id=p_application_id and (
    ja.applicant_id=v_user
    or exists(
      select 1 from public.jobs j
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
  if position(v_old in v_def)=0 then raise exception 'guardian_application_status_access_patch_failed'; end if;
  v_def := replace(v_def,v_old,v_new);
  execute v_def;
end;
$migration$;

do $migration$
declare
  v_def text;
  v_old text;
  v_new text;
begin
  v_def := pg_get_functiondef('public.mort_accept_job_application(uuid)'::regprocedure);
  v_old := $old$  if v_job.requires_guardian_approval and not exists (
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
  v_new := $new$  if (v_job.requires_guardian_approval or v_app.guardian_decision_status <> 'not_required')
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
  if position(v_old in v_def)=0 then raise exception 'guardian_acceptance_gate_patch_failed'; end if;
  v_def := replace(v_def,v_old,v_new);
  execute v_def;
end;
$migration$;

-- Return the new Guardian state immediately after submission so the teen
-- client can show the pending decision without reading another user's data.
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
      'guardian_decided_by', v_application.guardian_decided_by,
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

create or replace function public.guardian_decide_job_application(
  p_application_id uuid,
  p_decision text,
  p_reason text default null,
  p_expected_updated_at timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user uuid := auth.uid();
  v_app public.job_applications%rowtype;
  v_job public.jobs%rowtype;
  v_now timestamptz := clock_timestamp();
begin
  if v_user is null then
    return jsonb_build_object('ok',false,'code','authentication_required');
  end if;
  if p_application_id is null
     or p_decision is null
     or p_decision not in ('approved','rejected')
     or p_expected_updated_at is null
     or char_length(coalesce(p_reason,'')) > 500
     or (p_decision='rejected' and char_length(btrim(coalesce(p_reason,''))) < 10) then
    return jsonb_build_object('ok',false,'code','invalid_guardian_decision');
  end if;

  select * into v_app
  from public.job_applications application
  where application.id=p_application_id
  for update;
  if not found
     or v_app.status not in ('submitted'::public.mort_application_status,'shortlisted'::public.mort_application_status)
     or v_app.guardian_decision_status <> 'pending' then
    return jsonb_build_object('ok',false,'code','guardian_decision_not_available');
  end if;

  if v_app.updated_at is distinct from p_expected_updated_at then
    return jsonb_build_object('ok',false,'code','application_changed_refresh');
  end if;

  select * into v_job
  from public.jobs job
  where job.id=v_app.job_id
  for share;
  if not found
     or v_job.status <> 'open'::public.mort_job_status
     or v_job.safety_review_status <> 'approved'
     or not v_job.applications_open then
    return jsonb_build_object('ok',false,'code','job_not_available');
  end if;

  perform gl.id
  from public.guardian_links gl
  join public.profiles guardian_profile on guardian_profile.id=gl.guardian_user_id
  join auth.users guardian_auth on guardian_auth.id=gl.guardian_user_id
  where gl.teen_user_id=v_app.applicant_id
    and gl.guardian_user_id=v_user
    and gl.status='active'
    and gl.teen_consent_at is not null
    and gl.guardian_consent_at is not null
    and guardian_profile.role='guardian'::public.mort_role
    and guardian_profile.account_status='active'
    and guardian_profile.date_of_birth is not null
    and extract(year from age(v_now::date,guardian_profile.date_of_birth))>=18
    and guardian_auth.email_confirmed_at is not null
  for share of gl,guardian_profile,guardian_auth;

  if not found then
    return jsonb_build_object('ok',false,'code','active_guardian_required');
  end if;

  update public.job_applications
  set guardian_decision_status=p_decision,
      guardian_id=v_user,
      guardian_decided_by=v_user,
      guardian_decided_at=v_now,
      guardian_decision_reason=nullif(btrim(coalesce(p_reason,'')),''),
      updated_at=v_now
  where id=v_app.id;

  insert into private.guardian_application_decision_events(
    application_id,teen_user_id,guardian_user_id,action,reason
  ) values (
    v_app.id,v_app.applicant_id,v_user,p_decision,nullif(btrim(coalesce(p_reason,'')),'')
  );

  insert into public.notifications(user_id,notification_type,title,body,data)
  values (
    v_app.applicant_id,
    'guardian_application_decision',
    case when p_decision='approved' then 'Guardian approved your application' else 'Guardian did not approve this application' end,
    case when p_decision='approved' then 'Your application can now be reviewed by the job poster.' else 'Your Guardian did not approve this application. You can talk with them directly if you have questions.' end,
    jsonb_build_object('application_id',v_app.id,'job_id',v_app.job_id,'decision',p_decision)
  );

  if p_decision='approved' then
    insert into public.notifications(user_id,notification_type,title,body,data)
    values (
      v_job.poster_id,
      'new_application',
      'New application ready for review',
      'A teen application has completed its required Guardian approval and is ready for your review.',
      jsonb_build_object('application_id',v_app.id,'job_id',v_app.job_id)
    );
  end if;

  return jsonb_build_object(
    'ok',true,
    'application_id',v_app.id,
    'decision',p_decision,
    'updated_at',v_now
  );
end;
$function$;

revoke all on function public.guardian_decide_job_application(uuid,text,text,timestamptz)
  from public,anon,authenticated;
grant execute on function public.guardian_decide_job_application(uuid,text,text,timestamptz)
  to authenticated;

-- A revoked Guardian cannot leave an old approval in force. The application
-- returns to pending and is hidden from the poster until another active,
-- eligible linked Guardian approves it.
create or replace function private.reset_guardian_application_decisions_on_revocation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_app record;
begin
  if old.status='active'
     and new.status<>'active'
     and old.guardian_user_id is not null then
    for v_app in
      update public.job_applications
      set guardian_decision_status='pending',
          guardian_id=null,
          guardian_decided_by=null,
          guardian_decided_at=null,
          guardian_decision_reason=null,
          updated_at=clock_timestamp()
      where applicant_id=old.teen_user_id
        and guardian_id=old.guardian_user_id
        and guardian_decision_status in ('approved','rejected')
        and status in ('submitted'::public.mort_application_status,'shortlisted'::public.mort_application_status)
      returning id,applicant_id
    loop
      insert into private.guardian_application_decision_events(
        application_id,teen_user_id,guardian_user_id,action,reason
      ) values (
        v_app.id,v_app.applicant_id,old.guardian_user_id,'revoked','Guardian link was revoked; prior decision invalidated.'
      );
      insert into public.notifications(user_id,notification_type,title,body,data)
      values (
        v_app.applicant_id,
        'guardian_application_decision_reset',
        'Guardian approval needs review',
        'Your Guardian link changed, so the prior application approval is no longer active.',
        jsonb_build_object('application_id',v_app.id)
      );
    end loop;
  end if;
  return new;
end;
$function$;
revoke all on function private.reset_guardian_application_decisions_on_revocation()
  from public,anon,authenticated,service_role;

drop trigger if exists guardian_links_reset_application_decisions on public.guardian_links;
create trigger guardian_links_reset_application_decisions
after update of status on public.guardian_links
for each row execute function private.reset_guardian_application_decisions_on_revocation();

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
guardian_id',case when ja.applicant_id=v_user or exists(select 1 from public.guardian_links gl where gl.teen_user_id=ja.applicant_id and gl.guardian_user_id=v_user and gl.status='active' and gl.teen_consent_at is not null and gl.guardian_consent_at is not null) then ja.guardian_id else null end,'guardian_decision_status',ja.guardian_decision_status,'guardian_decided_at',ja.guardian_decided_at,'guardian_decision_reason',case when ja.applicant_id=v_user or exists(select 1 from public.guardian_links gl where gl.teen_user_id=ja.applicant_id and gl.guardian_user_id=v_user and gl.status='active' and gl.teen_consent_at is not null and gl.guardian_consent_at is not null) then ja.guardian_decision_reason else null end,'availability_confirmed'$new$;
  v_before := v_def;
  v_def := replace(v_def, v_old, v_new);
  if v_def = v_before then raise exception 'guardian_application_reader_payload_patch_failed'; end if;

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
  v_def := replace(v_def, v_old, v_new);
  if v_def = v_before then raise exception 'guardian_application_visibility_patch_failed'; end if;

  execute v_def;
end;
$migration$;

-- A poster cannot mutate or accept an application until any required Guardian
-- decision is approved and the approving Guardian link remains active.
do $migration$
declare
  v_def text;
  v_old text;
  v_new text;
begin
  v_def := pg_get_functiondef('public.update_my_job_application_status(uuid,text,timestamptz)'::regprocedure);
  v_old := $old$where ja.id=p_application_id and (ja.applicant_id=v_user or exists(select 1 from public.jobs j where j.id=ja.job_id and j.poster_id=v_user)) for update;$old$;
  v_new := $new$where ja.id=p_application_id and (
    ja.applicant_id=v_user
    or exists(
      select 1 from public.jobs j
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
  if position(v_old in v_def)=0 then raise exception 'guardian_application_status_access_patch_failed'; end if;
  v_def := replace(v_def,v_old,v_new);
  execute v_def;
end;
$migration$;

do $migration$
declare
  v_def text;
  v_old text;
  v_new text;
begin
  v_def := pg_get_functiondef('public.mort_accept_job_application(uuid)'::regprocedure);
  v_old := $old$  if v_job.requires_guardian_approval and not exists (
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
  v_new := $new$  if (v_job.requires_guardian_approval or v_app.guardian_decision_status <> 'not_required')
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
  if position(v_old in v_def)=0 then raise exception 'guardian_acceptance_gate_patch_failed'; end if;
  v_def := replace(v_def,v_old,v_new);
  execute v_def;
end;
$migration$;

-- Return the new Guardian state immediately after submission so the teen
-- client can show the pending decision without reading another user's data.
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
      'guardian_decided_by', v_application.guardian_decided_by,
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

create or replace function public.guardian_decide_job_application(
  p_application_id uuid,
  p_decision text,
  p_reason text default null,
  p_expected_updated_at timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user uuid := auth.uid();
  v_app public.job_applications%rowtype;
  v_job public.jobs%rowtype;
  v_now timestamptz := clock_timestamp();
begin
  if v_user is null then
    return jsonb_build_object('ok',false,'code','authentication_required');
  end if;
  if p_application_id is null
     or p_decision is null
     or p_decision not in ('approved','rejected')
     or p_expected_updated_at is null
     or char_length(coalesce(p_reason,'')) > 500
     or (p_decision='rejected' and char_length(btrim(coalesce(p_reason,''))) < 10) then
    return jsonb_build_object('ok',false,'code','invalid_guardian_decision');
  end if;

  select * into v_app
  from public.job_applications application
  where application.id=p_application_id
  for update;
  if not found
     or v_app.status not in ('submitted'::public.mort_application_status,'shortlisted'::public.mort_application_status)
     or v_app.guardian_decision_status <> 'pending' then
    return jsonb_build_object('ok',false,'code','guardian_decision_not_available');
  end if;

  if v_app.updated_at is distinct from p_expected_updated_at then
    return jsonb_build_object('ok',false,'code','application_changed_refresh');
  end if;

  select * into v_job
  from public.jobs job
  where job.id=v_app.job_id
  for share;
  if not found
     or v_job.status <> 'open'::public.mort_job_status
     or v_job.safety_review_status <> 'approved'
     or not v_job.applications_open then
    return jsonb_build_object('ok',false,'code','job_not_available');
  end if;

  perform gl.id
  from public.guardian_links gl
  join public.profiles guardian_profile on guardian_profile.id=gl.guardian_user_id
  join auth.users guardian_auth on guardian_auth.id=gl.guardian_user_id
  where gl.teen_user_id=v_app.applicant_id
    and gl.guardian_user_id=v_user
    and gl.status='active'
    and gl.teen_consent_at is not null
    and gl.guardian_consent_at is not null
    and guardian_profile.role='guardian'::public.mort_role
    and guardian_profile.account_status='active'
    and guardian_profile.date_of_birth is not null
    and extract(year from age(v_now::date,guardian_profile.date_of_birth))>=18
    and guardian_auth.email_confirmed_at is not null
  for share of gl,guardian_profile,guardian_auth;

  if not found then
    return jsonb_build_object('ok',false,'code','active_guardian_required');
  end if;

  update public.job_applications
  set guardian_decision_status=p_decision,
      guardian_id=v_user,
      guardian_decided_by=v_user,
      guardian_decided_at=v_now,
      guardian_decision_reason=nullif(btrim(coalesce(p_reason,'')),''),
      updated_at=v_now
  where id=v_app.id;

  insert into private.guardian_application_decision_events(
    application_id,teen_user_id,guardian_user_id,action,reason
  ) values (
    v_app.id,v_app.applicant_id,v_user,p_decision,nullif(btrim(coalesce(p_reason,'')),'')
  );

  insert into public.notifications(user_id,notification_type,title,body,data)
  values (
    v_app.applicant_id,
    'guardian_application_decision',
    case when p_decision='approved' then 'Guardian approved your application' else 'Guardian did not approve this application' end,
    case when p_decision='approved' then 'Your application can now be reviewed by the job poster.' else 'Your Guardian did not approve this application. You can talk with them directly if you have questions.' end,
    jsonb_build_object('application_id',v_app.id,'job_id',v_app.job_id,'decision',p_decision)
  );

  if p_decision='approved' then
    insert into public.notifications(user_id,notification_type,title,body,data)
    values (
      v_job.poster_id,
      'new_application',
      'New application ready for review',
      'A teen application has completed its required Guardian approval and is ready for your review.',
      jsonb_build_object('application_id',v_app.id,'job_id',v_app.job_id)
    );
  end if;

  return jsonb_build_object(
    'ok',true,
    'application_id',v_app.id,
    'decision',p_decision,
    'updated_at',v_now
  );
end;
$function$;

revoke all on function public.guardian_decide_job_application(uuid,text,text,timestamptz)
  from public,anon,authenticated;
grant execute on function public.guardian_decide_job_application(uuid,text,text,timestamptz)
  to authenticated;

-- A revoked Guardian cannot leave an old approval in force. The application
-- returns to pending and is hidden from the poster until another active,
-- eligible linked Guardian approves it.
create or replace function private.reset_guardian_application_decisions_on_revocation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_app record;
begin
  if old.status='active'
     and new.status<>'active'
     and old.guardian_user_id is not null then
    for v_app in
      update public.job_applications
      set guardian_decision_status='pending',
          guardian_id=null,
          guardian_decided_by=null,
          guardian_decided_at=null,
          guardian_decision_reason=null,
          updated_at=clock_timestamp()
      where applicant_id=old.teen_user_id
        and guardian_id=old.guardian_user_id
        and guardian_decision_status in ('approved','rejected')
        and status in ('submitted'::public.mort_application_status,'shortlisted'::public.mort_application_status)
      returning id,applicant_id
    loop
      insert into private.guardian_application_decision_events(
        application_id,teen_user_id,guardian_user_id,action,reason
      ) values (
        v_app.id,v_app.applicant_id,old.guardian_user_id,'revoked','Guardian link was revoked; prior decision invalidated.'
      );
      insert into public.notifications(user_id,notification_type,title,body,data)
      values (
        v_app.applicant_id,
        'guardian_application_decision_reset',
        'Guardian approval needs review',
        'Your Guardian link changed, so the prior application approval is no longer active.',
        jsonb_build_object('application_id',v_app.id)
      );
    end loop;
  end if;
  return new;
end;
$function$;
revoke all on function private.reset_guardian_application_decisions_on_revocation()
  from public,anon,authenticated,service_role;

drop trigger if exists guardian_links_reset_application_decisions on public.guardian_links;
create trigger guardian_links_reset_application_decisions
after update of status on public.guardian_links
for each row execute function private.reset_guardian_application_decisions_on_revocation();

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
