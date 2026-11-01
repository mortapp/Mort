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
begin
  if v_user is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
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

  v_application_id := public.mort_submit_job_application(p_job_id, p_note);
  update public.job_applications
  set availability_confirmed = coalesce(p_availability_confirmed, false)
  where id = v_application_id
  returning * into v_application;

  return jsonb_build_object(
    'ok', true,
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
