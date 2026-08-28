-- Quick Accept: an opt-in, self-serve claim path for single-worker jobs.
-- Posters must explicitly opt a job into quick_accept_eligible; ordinary
-- jobs are unaffected. The RPC re-verifies every eligibility condition
-- itself under a job-row lock (the same "lock parent job first" pattern
-- update_application_status_v2 already uses for the adult-accept path),
-- so concurrent claims on the same job serialize and exactly one can win.

alter table public.jobs
  add column if not exists quick_accept_eligible boolean not null default false;

create or replace function public.quick_accept_job_v1(
  p_job_id uuid,
  p_client_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_profile public.profiles%rowtype;
  v_job public.jobs%rowtype;
  v_application public.applications%rowtype;
  v_age integer;
  v_guardian_id uuid;
  v_policy jsonb;
  v_guardian_required boolean := false;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_job_id is null or p_client_request_id is null then
    return jsonb_build_object('ok', false, 'code', 'invalid_quick_accept_request');
  end if;

  select * into v_profile from public.profiles where id = auth.uid();
  if v_profile.id is null or v_profile.role <> 'teen' then
    return jsonb_build_object('ok', false, 'code', 'user_role_not_allowed');
  end if;
  if not public.is_profile_active(auth.uid()) or public.teen_is_paused(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'user_account_restricted');
  end if;
  if not private.has_marketplace_identity(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'applicant_verification_required');
  end if;

  -- Lock the job row first, exactly like update_application_status_v2's
  -- accept branch: this is what makes concurrent claims safe. Every other
  -- simultaneous caller blocks here until this transaction commits or
  -- rolls back, then re-reads the now-committed state.
  select * into v_job from public.jobs where id = p_job_id for update;

  if v_job.id is null then
    return jsonb_build_object('ok', false, 'code', 'job_not_found');
  end if;
  if not v_job.quick_accept_eligible then
    return jsonb_build_object('ok', false, 'code', 'not_quick_accept_eligible');
  end if;
  if v_job.status <> 'open' or not v_job.applications_open then
    return jsonb_build_object('ok', false, 'code', 'offer_taken');
  end if;
  if v_job.is_test and not v_profile.is_test_account then
    return jsonb_build_object('ok', false, 'code', 'job_not_open');
  end if;
  if v_job.poster_id = auth.uid() then
    return jsonb_build_object('ok', false, 'code', 'applicant_is_job_owner');
  end if;
  if v_job.expires_at is not null and v_job.expires_at <= now() then
    return jsonb_build_object('ok', false, 'code', 'job_expired');
  end if;
  if v_job.schedule_type = 'exact' and v_job.starts_at is not null and v_job.starts_at <= now() then
    return jsonb_build_object('ok', false, 'code', 'job_start_time_passed');
  end if;
  if not private.has_marketplace_identity(v_job.poster_id) then
    return jsonb_build_object('ok', false, 'code', 'poster_verification_required');
  end if;

  v_age := date_part('year', age(current_date, v_profile.dob));
  if v_age < v_job.teen_min_age or v_age > v_job.teen_max_age then
    return jsonb_build_object('ok', false, 'code', 'applicant_age_not_allowed');
  end if;
  if (
    select count(*) from public.applications
    where teen_id = auth.uid()
      and status in ('submitted', 'guardian_pending', 'adult_review', 'viewed', 'accepted', 'in_progress', 'proof_submitted')
  ) >= 20 then
    return jsonb_build_object('ok', false, 'code', 'application_limit_reached');
  end if;

  v_policy := public.get_guardian_policy_for_user(auth.uid());
  v_guardian_required := v_job.requires_guardian_approval
    or coalesce((v_policy->>'guardian_link_required')::boolean, false)
    or coalesce((v_policy->>'guardian_approval_required_for_application')::boolean, false);

  select guardian_id into v_guardian_id
  from public.guardian_connections
  where teen_id = auth.uid() and status = 'active' and guardian_id is not null
  order by accepted_at desc nulls last
  limit 1;

  if v_guardian_required and v_guardian_id is null then
    return jsonb_build_object('ok', false, 'code', 'guardian_link_required');
  end if;

  begin
    insert into public.applications (
      job_id, teen_id, status, guardian_id, availability_confirmed
    ) values (
      p_job_id, auth.uid(), 'accepted', v_guardian_id, true
    )
    returning * into v_application;
  exception
    when unique_violation then
      -- Same teen retried the same request (client_request_id is not
      -- persisted on this table; the natural (job_id, teen_id) uniqueness
      -- already makes a same-teen retry safe to replay rather than error).
      select * into v_application
      from public.applications
      where job_id = p_job_id and teen_id = auth.uid();
      if v_application.status = 'accepted' then
        return jsonb_build_object(
          'ok', true, 'replayed', true,
          'application', to_jsonb(v_application), 'job', to_jsonb(v_job)
        );
      end if;
      return jsonb_build_object('ok', false, 'code', 'application_already_exists');
  end;

  update public.jobs
  set status = 'assigned', applications_open = false
  where id = p_job_id
  returning * into v_job;

  return jsonb_build_object(
    'ok', true,
    'application', to_jsonb(v_application),
    'job', to_jsonb(v_job)
  );
end;
$$;

revoke all on function public.quick_accept_job_v1(uuid, uuid) from public, anon;
grant execute on function public.quick_accept_job_v1(uuid, uuid) to authenticated;
