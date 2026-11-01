-- PROPOSAL ONLY. Do not add to the executable migration chain or apply until
-- a clone matching production migration history has passed the integration
-- and concurrency tests. Depends on private.lock_user_pair(uuid,uuid) from
-- the production_safety_missing_contracts proposal.
--
-- This preserves the production RPC signature and response contract. The job
-- row is locked before eligibility is recomputed; related authorization rows
-- are share-locked so Guardian revocation, verification changes, account
-- suspension, release-control changes, and block writes cannot race the
-- insert inside this transaction.

create or replace function public.submit_job_application(
  p_job_id uuid,
  p_note text default null,
  p_availability_confirmed boolean default false,
  p_portfolio_ids uuid[] default '{}'::uuid[]
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user uuid := auth.uid();
  v_job public.jobs%rowtype;
  v_eligibility jsonb;
  v_application_id uuid;
  v_application public.job_applications%rowtype;
  v_existing_application public.job_applications%rowtype;
  v_profile public.profiles%rowtype;
  v_age_verification_id uuid;
  v_guardian_link_id uuid;
  v_now timestamptz;
  v_today date;
begin
  if v_user is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if not private.is_active_user()
    or private.current_role() <> 'teen'::public.mort_role then
    return jsonb_build_object('ok', false, 'code', 'active_teen_account_required');
  end if;
  if p_note is not null and char_length(btrim(p_note)) > 1000 then
    return jsonb_build_object('ok', false, 'code', 'application_note_too_long');
  end if;
  if coalesce(cardinality(p_portfolio_ids), 0) > 0 then
    return jsonb_build_object('ok', false, 'code', 'portfolio_evidence_not_supported');
  end if;

  -- Serialize against job edits/closure before inspecting any eligibility
  -- fields. The underlying mort_submit_job_application locks this same row
  -- again in the same transaction and retains its existing defensive checks.
  select * into v_job
  from public.jobs
  where id = p_job_id
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'job_not_available');
  end if;

  -- There is no request ID in the production signature. The unique
  -- (job_id, applicant_id) key is therefore the durable idempotency boundary.
  -- Read the existing row without a row lock: the live acceptance path locks
  -- application then job, while a new submit must lock job before insert. A
  -- locking replay read here would invert that order and deadlock with accept.
  -- This replay is read-only; the job lock still serializes new submits.
  select * into v_existing_application
  from public.job_applications
  where job_id = p_job_id and applicant_id = v_user;
  if found then
    if v_existing_application.status in (
      'submitted'::public.mort_application_status,
      'shortlisted'::public.mort_application_status,
      'accepted'::public.mort_application_status
    ) then
      return jsonb_build_object(
        'ok', true,
        'replayed', true,
        'application', jsonb_build_object(
          'id', v_existing_application.id,
          'job_id', v_existing_application.job_id,
          'teen_id', v_existing_application.applicant_id,
          'status', v_existing_application.status::text,
          'note', v_existing_application.cover_note,
          'guardian_id', v_existing_application.guardian_id,
          'availability_confirmed', v_existing_application.availability_confirmed,
          'created_at', v_existing_application.created_at,
          'updated_at', v_existing_application.updated_at
        )
      );
    end if;
    return jsonb_build_object(
      'ok', false,
      'code', 'application_already_exists',
      'status', v_existing_application.status::text
    );
  end if;

  if v_job.starts_at is not null and not coalesce(p_availability_confirmed, false) then
    return jsonb_build_object('ok', false, 'code', 'availability_confirmation_required');
  end if;

  -- Every block writer uses this same canonical pair key. The trigger on
  -- user_blocks also takes it for direct RLS-authorized inserts/deletes.
  if v_job.poster_id <> v_user then
    perform private.lock_user_pair(v_user, v_job.poster_id);
  end if;

  -- Match unlink_guardian's link-then-teen-profile lock order. This lock is
  -- acquired only when the job actually requires a linked Guardian.
  if v_job.requires_guardian_approval then
    perform gl.id
    from public.guardian_links gl
    where gl.teen_user_id = v_user
      and gl.status = 'active'
      and gl.teen_consent_at is not null
      and gl.guardian_consent_at is not null
    order by gl.id
    for share;

    perform guardian_profile.id
    from public.guardian_links gl
    join public.profiles guardian_profile on guardian_profile.id = gl.guardian_user_id
    join auth.users guardian_auth on guardian_auth.id = gl.guardian_user_id
    where gl.teen_user_id = v_user
      and gl.status = 'active'
      and gl.teen_consent_at is not null
      and gl.guardian_consent_at is not null
    order by gl.id
    for share of guardian_profile, guardian_auth;
  end if;

  -- Hold state rows stable while the existing production eligibility
  -- function checks active roles, age verification, poster status and release
  -- controls. These SELECTs do not grant clients direct table access.
  perform profile.id
  from public.profiles profile
  where profile.id in (v_user, v_job.poster_id)
  order by profile.id
  for share;

  select profile.* into v_profile
  from public.profiles profile
  where profile.id = v_user;
  if not found or v_profile.date_of_birth is null then
    return jsonb_build_object('ok', false, 'code', 'date_of_birth_required');
  end if;

  perform verification.id
  from public.verification_cases verification
  where verification.user_id = v_user
    and verification.verification_type = 'age'
    and verification.status = 'verified'::public.mort_verification_status
    and (verification.expires_at is null or verification.expires_at > now())
  order by verification.id
  for share;

  perform release_control.is_primary
  from public.mort_release_control release_control
  where release_control.is_primary
  for share;

  -- now() and current_date are fixed at transaction start in PostgreSQL.
  -- Capture wall-clock time only after lock waits have completed, then repeat
  -- the eligibility predicates that can change merely with elapsed time.
  v_now := clock_timestamp();
  v_today := (v_now at time zone current_setting('TimeZone'))::date;

  -- Crucially, this is recomputed only after the relevant locks are held.
  -- It reuses production's existing DOB, age verification, Guardian consent,
  -- release state, job approval/open/expiry/application-window, poster-active,
  -- and block checks; no new status or bypass is introduced.
  v_eligibility := public.get_job_application_eligibility(p_job_id);
  if v_eligibility->>'eligible' is distinct from 'true' then
    return jsonb_build_object(
      'ok', false,
      'code', v_eligibility->>'code',
      'message', v_eligibility->>'message'
    );
  end if;

  if v_job.expires_at is not null and v_job.expires_at <= v_now then
    return jsonb_build_object('ok', false, 'code', 'job_not_available',
      'message', 'This job is not accepting applications.');
  end if;

  if extract(year from age(v_today, v_profile.date_of_birth))::integer < v_job.age_min
     or extract(year from age(v_today, v_profile.date_of_birth))::integer > v_job.age_max then
    return jsonb_build_object('ok', false, 'code', 'applicant_age_not_allowed',
      'message', 'Your age does not match this job’s requirements.');
  end if;

  select verification.id into v_age_verification_id
  from public.verification_cases verification
    where verification.user_id = v_user
      and verification.verification_type = 'age'
      and verification.status = 'verified'::public.mort_verification_status
      and (verification.expires_at is null or verification.expires_at > v_now)
  order by verification.id
  limit 1
  for share;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'age_verification_required',
      'message', 'Complete age verification before applying.');
  end if;

  if v_job.requires_guardian_approval then
    select gl.id into v_guardian_link_id
    from public.guardian_links gl
    join public.profiles guardian_profile on guardian_profile.id = gl.guardian_user_id
    join auth.users guardian_auth on guardian_auth.id = gl.guardian_user_id
    where gl.teen_user_id = v_user
      and gl.status = 'active'
      and gl.teen_consent_at is not null
      and gl.guardian_consent_at is not null
      and guardian_profile.role = 'guardian'::public.mort_role
      and guardian_profile.account_status = 'active'
      and guardian_profile.date_of_birth is not null
      and extract(year from age(v_today, guardian_profile.date_of_birth)) >= 18
      and guardian_auth.email_confirmed_at is not null
    order by gl.id
    limit 1
    for share of gl, guardian_profile, guardian_auth;
    if not found then
      return jsonb_build_object('ok', false, 'code', 'guardian_approval_required',
        'message', 'Link a guardian before applying to this job.');
    end if;
  end if;

  v_application_id := public.mort_submit_job_application(p_job_id, p_note);
  update public.job_applications
  set availability_confirmed = coalesce(p_availability_confirmed, false)
  where id = v_application_id
  returning * into v_application;

  return jsonb_build_object(
    'ok', true,
    'replayed', false,
    'application', jsonb_build_object(
      'id', v_application.id,
      'job_id', v_application.job_id,
      'teen_id', v_application.applicant_id,
      'status', v_application.status::text,
      'note', v_application.cover_note,
      'guardian_id', v_application.guardian_id,
      'availability_confirmed', v_application.availability_confirmed,
      'created_at', v_application.created_at,
      'updated_at', v_application.updated_at
    )
  );
end;
$function$;

-- Preserve the live API surface while ensuring this privileged implementation
-- is callable only from authenticated clients and the trusted server role.
revoke all on function public.submit_job_application(uuid, text, boolean, uuid[])
  from public, anon;
grant execute on function public.submit_job_application(uuid, text, boolean, uuid[])
  to authenticated, service_role;
