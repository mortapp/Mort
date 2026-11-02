
-- MORT production workflow RPCs. All actions are authenticated, transactional and fail closed.
-- These functions are architecture primitives; provider integrations remain separate.

create or replace function public.mort_submit_job_application(
  p_job_id uuid,
  p_cover_note text default null
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_application uuid;
  v_job public.jobs%rowtype;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if not private.is_active_user() or private.current_role() <> 'teen'::public.mort_role then
    raise exception 'An active teen account is required';
  end if;
  if p_cover_note is not null and char_length(p_cover_note) > 1000 then
    raise exception 'Cover note exceeds 1000 characters';
  end if;

  select * into v_job from public.jobs where id = p_job_id for update;
  if not found or v_job.status <> 'open'::public.mort_job_status
     or v_job.safety_review_status <> 'approved' then
    raise exception 'Job is not available';
  end if;
  if v_job.poster_id = v_user then raise exception 'Cannot apply to your own job'; end if;
  if exists (
    select 1 from public.user_blocks b
    where (b.blocker_id = v_user and b.blocked_id = v_job.poster_id)
       or (b.blocker_id = v_job.poster_id and b.blocked_id = v_user)
  ) then raise exception 'This interaction is unavailable'; end if;
  if not exists (
    select 1 from public.verification_cases vc
    where vc.user_id = v_user and vc.verification_type = 'age'
      and vc.status = 'verified'::public.mort_verification_status
      and (vc.expires_at is null or vc.expires_at > now())
  ) then raise exception 'Age verification must be completed before applying'; end if;

  insert into public.job_applications(job_id, applicant_id, cover_note)
  values (p_job_id, v_user, nullif(btrim(p_cover_note), ''))
  returning id into v_application;
  return v_application;
end;
$$;

create or replace function public.mort_accept_job_application(
  p_application_id uuid
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_app public.job_applications%rowtype;
  v_job public.jobs%rowtype;
  v_assignment uuid;
  v_conversation uuid;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if not private.is_active_user() or private.current_role() <> 'adult'::public.mort_role then
    raise exception 'An active adult account is required';
  end if;

  select * into v_app from public.job_applications
  where id = p_application_id for update;
  if not found then raise exception 'Application not found'; end if;

  select * into v_job from public.jobs where id = v_app.job_id for update;
  if not found or v_job.poster_id <> v_user then raise exception 'Application not found'; end if;
  if v_job.status <> 'open'::public.mort_job_status
     or v_job.safety_review_status <> 'approved'
     or v_app.status not in ('submitted'::public.mort_application_status,
                             'shortlisted'::public.mort_application_status) then
    raise exception 'Application is not eligible for acceptance';
  end if;
  if exists (
    select 1 from public.user_blocks b
    where (b.blocker_id = v_user and b.blocked_id = v_app.applicant_id)
       or (b.blocker_id = v_app.applicant_id and b.blocked_id = v_user)
  ) then raise exception 'This interaction is unavailable'; end if;
  if not exists (
    select 1 from public.verification_cases vc
    where vc.user_id = v_user and vc.verification_type = 'identity'
      and vc.status = 'verified'::public.mort_verification_status
      and (vc.expires_at is null or vc.expires_at > now())
  ) then raise exception 'Adult identity verification must be completed'; end if;
  if not exists (
    select 1 from public.verification_cases vc
    where vc.user_id = v_app.applicant_id and vc.verification_type = 'age'
      and vc.status = 'verified'::public.mort_verification_status
      and (vc.expires_at is null or vc.expires_at > now())
  ) then raise exception 'Teen age verification must be current'; end if;

  insert into public.job_assignments(job_id, application_id, teen_user_id, adult_user_id, agreed_amount)
  values (v_job.id, v_app.id, v_app.applicant_id, v_user, v_job.pay_amount)
  returning id into v_assignment;

  update public.job_applications
  set status = 'accepted'::public.mort_application_status, updated_at = now()
  where id = v_app.id;

  update public.job_applications
  set status = 'rejected'::public.mort_application_status, updated_at = now()
  where job_id = v_job.id and id <> v_app.id
    and status in ('submitted'::public.mort_application_status,
                   'shortlisted'::public.mort_application_status);

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
$$;

create or replace function public.mort_set_guardian_consent(
  p_link_id uuid,
  p_accept boolean
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_link public.guardian_links%rowtype;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  select * into v_link from public.guardian_links where id = p_link_id for update;
  if not found or v_link.status <> 'pending' then raise exception 'Pending guardian link not found'; end if;

  if v_user = v_link.teen_user_id then
    if not p_accept then
      update public.guardian_links set status='rejected', updated_at=now() where id=p_link_id;
    else
      update public.guardian_links
      set teen_consent_at=coalesce(teen_consent_at,now()),
          status=case when guardian_consent_at is not null then 'active' else 'pending' end,
          updated_at=now()
      where id=p_link_id;
    end if;
  elsif v_user = v_link.guardian_user_id then
    if not private.is_active_user() or private.current_role() <> 'adult'::public.mort_role then
      raise exception 'An active adult guardian account is required';
    end if;
    if not p_accept then
      update public.guardian_links set status='rejected', updated_at=now() where id=p_link_id;
    else
      update public.guardian_links
      set guardian_consent_at=coalesce(guardian_consent_at,now()),
          status=case when teen_consent_at is not null then 'active' else 'pending' end,
          updated_at=now()
      where id=p_link_id;
    end if;
  else
    raise exception 'Guardian link not found';
  end if;
  return p_link_id;
end;
$$;

create or replace function public.mort_review_job(
  p_job_id uuid,
  p_approve boolean,
  p_reason text default null
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_job public.jobs%rowtype;
begin
  if v_user is null or not private.has_staff_role(array['admin','moderator']::public.mort_role[]) then
    raise exception 'Authorized moderation role required';
  end if;
  select * into v_job from public.jobs where id=p_job_id for update;
  if not found then raise exception 'Job not found'; end if;
  if p_approve then
    update public.jobs set safety_review_status='approved',
      status='open'::public.mort_job_status,
      published_at=coalesce(published_at,now()), updated_at=now()
    where id=p_job_id;
  else
    update public.jobs set safety_review_status='rejected',
      status='under_review'::public.mort_job_status, updated_at=now()
    where id=p_job_id;
  end if;
  insert into public.admin_audit_log(actor_id,action,target_type,target_id,reason,metadata)
  values (v_user, case when p_approve then 'job_approved' else 'job_rejected' end,
          'job',p_job_id::text,nullif(btrim(p_reason),''),
          jsonb_build_object('previous_status',v_job.status,'approved',p_approve));
  return p_job_id;
end;
$$;

revoke all on function public.mort_submit_job_application(uuid,text) from public, anon;
revoke all on function public.mort_accept_job_application(uuid) from public, anon;
revoke all on function public.mort_set_guardian_consent(uuid,boolean) from public, anon;
revoke all on function public.mort_review_job(uuid,boolean,text) from public, anon;
grant execute on function public.mort_submit_job_application(uuid,text) to authenticated;
grant execute on function public.mort_accept_job_application(uuid) to authenticated;
grant execute on function public.mort_set_guardian_consent(uuid,boolean) to authenticated;
grant execute on function public.mort_review_job(uuid,boolean,text) to authenticated;
