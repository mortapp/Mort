-- Safety contracts: serialize application eligibility with insertion and make
-- Guardian resend link-scoped. This migration is intentionally append-only.
-- It must be validated in an isolated Supabase environment before deployment.

begin;

-- The preflight eligibility RPC is also used by the client, so report an
-- existing active application before the submission RPC attempts its insert.
create or replace function public.get_job_application_eligibility(p_job_id uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_profile public.profiles%rowtype;
  v_job public.jobs%rowtype;
  v_release public.mort_release_control%rowtype;
  v_age integer;
  v_now timestamptz;
  v_guardian_linked boolean;
  v_poster_active boolean := false;
  v_profile_found boolean := false;
  v_job_found boolean := false;
  v_release_found boolean := false;
  v_code text := 'eligible';
  v_message text := 'You can apply to this job.';
begin
  if auth.uid() is null then
    return jsonb_build_object('eligible', false, 'code', 'authentication_required', 'message', 'Sign in to apply.', 'guardian_required_for_this_job', false, 'guardian_linked', false);
  end if;
  select * into v_profile from public.profiles profile where profile.id = auth.uid() for share;
  v_profile_found := found;
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
  end if;
  select * into v_release from public.mort_release_control release where release.is_primary for share;
  v_release_found := found;
  -- Lock active, dual-consented Guardian records and their identity rows
  -- before evaluating age against the fresh clock captured below.
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
  for share of gl, guardian_profile, guardian_auth;
  -- Lock every age-verification row in the eligible state, including expired
  -- rows, then evaluate expiry against the post-lock wall clock.
  perform verification.id
  from public.verification_cases verification
  where verification.user_id = auth.uid()
    and verification.verification_type = 'age'
    and verification.status = 'verified'::public.mort_verification_status
  for share;
  v_now := clock_timestamp();
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
  elsif not v_poster_active then
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
$$;

-- Hold the job row before preflight. Concurrent submitters therefore observe
-- the first committed application and receive application_already_exists,
-- rather than racing through a stale eligibility result.
create or replace function public.submit_job_application(
  p_job_id uuid,
  p_note text,
  p_availability_confirmed boolean default false,
  p_portfolio_ids uuid[] default '{}'::uuid[]
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job public.jobs%rowtype;
  v_eligibility jsonb;
  v_application_id uuid;
  v_application public.job_applications%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_note is not null and char_length(btrim(p_note)) > 1000 then
    return jsonb_build_object('ok', false, 'code', 'application_note_too_long');
  end if;
  if coalesce(cardinality(p_portfolio_ids), 0) > 0 then
    return jsonb_build_object('ok', false, 'code', 'portfolio_evidence_not_supported');
  end if;
  select * into v_job
  from public.jobs job
  where job.id = p_job_id
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'job_not_available');
  end if;
  if v_job.starts_at is not null and not p_availability_confirmed then
    return jsonb_build_object('ok', false, 'code', 'availability_confirmation_required');
  end if;
  v_eligibility := public.get_job_application_eligibility(p_job_id);
  if coalesce(v_eligibility->>'eligible', 'false') <> 'true' then
    return jsonb_build_object('ok', false, 'code', v_eligibility->>'code', 'message', v_eligibility->>'message');
  end if;
  v_application_id := public.mort_submit_job_application(p_job_id, p_note);
  update public.job_applications
  set availability_confirmed = p_availability_confirmed
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
$$;

-- Keep the lower-level helper safe for callers that bypass the wrapper. It
-- takes the same job lock and performs the complete eligibility check before
-- inserting, rather than relying on an earlier preflight result.
create or replace function public.mort_submit_job_application(
  p_job_id uuid,
  p_cover_note text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_job public.jobs%rowtype;
  v_eligibility jsonb;
  v_application_id uuid;
begin
  if v_user_id is null then raise exception 'Authentication required'; end if;
  if not private.is_active_user()
     or private.current_role() is distinct from 'teen'::public.mort_role then
    raise exception 'An active teen account is required';
  end if;
  if p_cover_note is not null and char_length(p_cover_note) > 1000 then
    raise exception 'Cover note exceeds 1000 characters';
  end if;
  select * into v_job
  from public.jobs job
  where job.id = p_job_id
  for update;
  if not found then raise exception 'Job is not available'; end if;
  v_eligibility := public.get_job_application_eligibility(p_job_id);
  if coalesce(v_eligibility->>'eligible', 'false') <> 'true' then
    raise exception '%', coalesce(v_eligibility->>'message', 'Job application is not eligible');
  end if;
  insert into public.job_applications(job_id, applicant_id, cover_note)
  values (p_job_id, v_user_id, nullif(btrim(p_cover_note), ''))
  returning id into v_application_id;
  return v_application_id;
end;
$$;

-- Resend only the selected pending link. Existing pending links for the same
-- teen remain untouched; the selected link's old code is consumed first.
create or replace function public.resend_guardian_invite(p_link_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_link public.guardian_links%rowtype;
  v_code text;
  v_expires_at timestamptz := now() + interval '7 days';
  v_email text;
  v_invite_count integer;
  v_rate_key bigint;
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if private.current_role() is distinct from 'teen'::public.mort_role
     or not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'user_role_not_allowed');
  end if;
  if p_link_id is null then
    return jsonb_build_object('ok', false, 'code', 'guardian_link_id_required');
  end if;
  v_rate_key := pg_catalog.hashtextextended(v_user_id::text, 0);
  perform pg_catalog.pg_advisory_xact_lock(v_rate_key);
  select * into v_link
  from public.guardian_links link
  where link.id = p_link_id
    and link.teen_user_id = v_user_id
    and link.status = 'pending'
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'pending_guardian_invite_not_found');
  end if;
  select count(*) into v_invite_count
  from private.guardian_invite_codes code
  where code.teen_user_id = v_user_id
    and code.created_at > now() - interval '24 hours';
  if v_invite_count >= 3 then
    return jsonb_build_object('ok', false, 'code', 'guardian_invite_limit_reached');
  end if;
  select code.invited_email into v_email
  from private.guardian_invite_codes code
  where code.guardian_link_id = p_link_id
    and code.consumed_at is null
  order by code.created_at desc
  limit 1;
  if v_email is null then
    return jsonb_build_object('ok', false, 'code', 'guardian_invite_code_missing');
  end if;
  update private.guardian_invite_codes
  set consumed_at = coalesce(consumed_at, now())
  where guardian_link_id = p_link_id and consumed_at is null;
  v_code := encode(extensions.gen_random_bytes(32), 'hex');
  insert into private.guardian_invite_codes(
    guardian_link_id, teen_user_id, code_sha256, invited_email, expires_at
  ) values (
    p_link_id, v_user_id,
    encode(extensions.digest(convert_to(v_code, 'utf8'), 'sha256'), 'hex'),
    v_email, v_expires_at
  );
  update public.guardian_links
  set updated_at = now()
  where id = p_link_id;
  return jsonb_build_object(
    'ok', true,
    'link_id', p_link_id,
    'invite_code', upper(v_code),
    'expires_at', v_expires_at,
    'delivery', 'share_code_with_guardian'
  );
end;
$$;

revoke all on function public.resend_guardian_invite(uuid) from public, anon;
grant execute on function public.resend_guardian_invite(uuid) to authenticated, service_role;

commit;
