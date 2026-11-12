-- MORT production baseline recovery: mort p (jxbnrkasktbhtiujkhay)
-- Generated 2026-11-12 via pg_dump --schema-only from the production database
-- through the IPv4 session pooler. Covers the public and private schemas.
--
-- Restore procedure (isolated environment only, never over production):
--   1. Drop and recreate the public and private schemas on the target.
--   2. Run this file end to end (psql or the SQL API). It is idempotent on
--      schema creation and contains no user data.
--   3. Run storage-policies-2026-11-12.sql to restore storage policies and
--      bucket definitions.
--
-- Platform-managed objects (auth/storage catalogs, default privileges owned
-- by supabase_admin) are intentionally not included; the Supabase platform
-- provides them. The 2026-11-12 restore validation against the isolated QA
-- project matched production exactly except the platform's storage
-- lifecycle tables (storage.bucket_lifecycle_states,
-- storage.lifecycle_abandoned_artifacts), which come with the platform
-- version, not this schema.

--
-- PostgreSQL database dump
--


-- Dumped from database version 17.11
-- Dumped by pg_dump version 18.6 (Ubuntu 18.6-0ubuntu0.26.04.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: private; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA IF NOT EXISTS private;


--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA IF NOT EXISTS public;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: mort_application_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.mort_application_status AS ENUM (
    'submitted',
    'withdrawn',
    'shortlisted',
    'accepted',
    'rejected',
    'cancelled'
);


--
-- Name: mort_job_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.mort_job_status AS ENUM (
    'draft',
    'open',
    'paused',
    'filled',
    'in_progress',
    'completed',
    'cancelled',
    'under_review'
);


--
-- Name: mort_role; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.mort_role AS ENUM (
    'pending',
    'teen',
    'adult',
    'admin',
    'moderator',
    'guardian'
);


--
-- Name: mort_verification_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.mort_verification_status AS ENUM (
    'not_started',
    'pending',
    'verified',
    'rejected',
    'expired',
    'needs_review'
);


--
-- Name: abort_application_proof_upload_internal(uuid, uuid); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.abort_application_proof_upload_internal(p_proof_id uuid, p_application_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin
  if auth.uid() is null then return jsonb_build_object('ok',false,'code','authentication_required'); end if;
  update public.proof_uploads proof set status='abandoned',updated_at=now()
   where proof.id=p_proof_id and proof.application_id=p_application_id
     and proof.uploaded_by=auth.uid() and proof.status='uploading';
  return jsonb_build_object('ok',true);
end;
$$;


--
-- Name: archive_job_private_location_before_update(); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.archive_job_private_location_before_update() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin
  insert into private.job_private_location_history (
    job_id, poster_id, exact_address, address_fingerprint,
    arrival_instructions, access_notes,
    location_version, original_updated_at
  ) values (
    old.job_id, old.poster_id, old.exact_address, old.address_fingerprint,
    old.arrival_instructions, old.access_notes,
    old.location_version, old.updated_at
  );
  return new;
end;
$$;


--
-- Name: archive_job_safety_agreement_before_update(); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.archive_job_safety_agreement_before_update() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin
  insert into private.job_safety_agreement_history (
    agreement_id, application_id, job_id, teen_id, adult_id,
    agreement_version, terms_snapshot, material_terms_hash, status,
    teen_confirmed_at, adult_confirmed_at,
    teen_confirmed_version, adult_confirmed_version,
    location_version, original_created_at, original_updated_at
  ) values (
    old.id, old.application_id, old.job_id, old.teen_id, old.adult_id,
    old.agreement_version, old.terms_snapshot, old.material_terms_hash, old.status,
    old.teen_confirmed_at, old.adult_confirmed_at,
    old.teen_confirmed_version, old.adult_confirmed_version,
    old.location_version, old.created_at, old.updated_at
  );
  return new;
end;
$$;


--
-- Name: audit_guardian_link_revocation(); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.audit_guardian_link_revocation() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin
  if new.status = 'revoked' and old.status is distinct from new.status then
    new.revoked_by := coalesce(new.revoked_by, auth.uid(), new.initiated_by);
    new.revoked_at := coalesce(new.revoked_at, now());
  end if;
  return new;
end;
$$;


--
-- Name: begin_application_proof_upload_internal(uuid, uuid, text, text); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.begin_application_proof_upload_internal(p_proof_id uuid, p_application_id uuid, p_storage_path text, p_note text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_assignment public.job_assignments%rowtype;
  v_existing public.proof_uploads%rowtype;
  v_note text := nullif(btrim(p_note), '');
  v_expected_path text;
begin
  if auth.uid() is null then return jsonb_build_object('ok',false,'code','authentication_required'); end if;
  if p_proof_id is null or p_application_id is null then return jsonb_build_object('ok',false,'code','invalid_proof_submission'); end if;
  v_expected_path := auth.uid()::text || '/' || p_proof_id::text || '.jpg';
  if p_storage_path is distinct from v_expected_path then return jsonb_build_object('ok',false,'code','invalid_proof_path'); end if;
  if v_note is not null and char_length(v_note) > 500 then return jsonb_build_object('ok',false,'code','proof_note_too_long'); end if;

  select assignment.* into v_assignment
    from public.job_assignments assignment
   where assignment.application_id = p_application_id
   for update;
  if not found or v_assignment.teen_user_id <> auth.uid() then return jsonb_build_object('ok',false,'code','job_participant_required'); end if;
  if v_assignment.status not in ('in_progress','awaiting_confirmation') then return jsonb_build_object('ok',false,'code','job_not_ready_for_proof'); end if;

  update public.proof_uploads set status='abandoned',updated_at=now()
   where application_id=p_application_id and status='uploading'
     and created_at < now() - interval '30 minutes';

  select proof.* into v_existing from public.proof_uploads proof where proof.id = p_proof_id for update;
  if found then
    if v_existing.application_id = p_application_id
       and v_existing.uploaded_by = auth.uid()
       and v_existing.storage_path = p_storage_path
       and v_existing.status in ('uploading','submitted') then
      return jsonb_build_object('ok',true,'proof_id',v_existing.id,'storage_path',v_existing.storage_path,'status',v_existing.status);
    end if;
    if v_existing.status = 'abandoned' and v_existing.uploaded_by = auth.uid()
       and v_existing.application_id = p_application_id and v_existing.storage_path = p_storage_path then
      update public.proof_uploads set status='uploading', note=v_note, updated_at=now() where id=p_proof_id;
      return jsonb_build_object('ok',true,'proof_id',p_proof_id,'storage_path',p_storage_path,'status','uploading');
    end if;
    return jsonb_build_object('ok',false,'code','proof_submission_conflict');
  end if;

  if exists (select 1 from public.proof_uploads proof
              where proof.application_id=p_application_id
                and proof.status in ('uploading','submitted')) then
    return jsonb_build_object('ok',false,'code','proof_already_pending');
  end if;
  if exists (select 1 from public.proof_uploads proof
              where proof.application_id=p_application_id and proof.status='approved') then
    return jsonb_build_object('ok',false,'code','proof_already_approved');
  end if;

  insert into public.proof_uploads(id,assignment_id,application_id,uploaded_by,storage_path,status,note)
  values (p_proof_id,v_assignment.id,p_application_id,auth.uid(),p_storage_path,'uploading',v_note);
  return jsonb_build_object('ok',true,'proof_id',p_proof_id,'storage_path',p_storage_path,'status','uploading');
end;
$$;


--
-- Name: can_access_application_status_events(uuid); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.can_access_application_status_events(p_application_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
  select auth.uid() is not null and private.is_active_user() and (
    private.has_staff_role(array['admin','moderator']::public.mort_role[])
    or exists(
      select 1 from public.job_applications ja join public.jobs j on j.id=ja.job_id
      where ja.id=p_application_id and (
        ja.applicant_id=auth.uid() or j.poster_id=auth.uid()
        or exists(select 1 from public.guardian_links gl
          where gl.teen_user_id=ja.applicant_id and gl.guardian_user_id=auth.uid()
            and gl.status='active' and gl.teen_consent_at is not null and gl.guardian_consent_at is not null)
      )
    )
  );
$$;


--
-- Name: can_access_assignment(uuid); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.can_access_assignment(target_assignment uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
  select exists (
    select 1 from public.job_assignments a
    where a.id = target_assignment
      and ((select auth.uid()) = a.teen_user_id or (select auth.uid()) = a.adult_user_id
        or private.has_staff_role(array['admin','moderator']::public.mort_role[]))
  );
$$;


--
-- Name: can_access_conversation(uuid); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.can_access_conversation(target_conversation uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
  select exists (
    select 1 from public.conversation_members cm
    where cm.conversation_id = target_conversation and cm.user_id = (select auth.uid())
  );
$$;


--
-- Name: can_access_job_status_events(uuid); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.can_access_job_status_events(p_job_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
  select auth.uid() is not null and private.is_active_user() and (
    private.has_staff_role(array['admin','moderator']::public.mort_role[])
    or exists(select 1 from public.jobs j where j.id=p_job_id and j.poster_id=auth.uid())
    or exists(select 1 from public.job_applications ja where ja.job_id=p_job_id and ja.applicant_id=auth.uid())
    or exists(select 1 from public.job_assignments a where a.job_id=p_job_id and (a.teen_user_id=auth.uid() or a.adult_user_id=auth.uid()))
    or exists(
      select 1 from public.guardian_links gl
      join public.job_applications ja on ja.applicant_id=gl.teen_user_id
      where ja.job_id=p_job_id and gl.guardian_user_id=auth.uid() and gl.status='active'
        and gl.teen_consent_at is not null and gl.guardian_consent_at is not null
    )
  );
$$;


--
-- Name: capture_application_status_event(); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.capture_application_status_event() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$ begin if new.status is distinct from old.status then insert into public.application_status_events(application_id,actor_id,from_status,to_status) values(new.id,auth.uid(),old.status,new.status); end if; return new; end; $$;


--
-- Name: capture_job_status_event(); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.capture_job_status_event() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_action text := coalesce(nullif(current_setting('mort.job_action', true), ''), 'status_changed');
begin
  if tg_op = 'INSERT' or new.status is distinct from old.status then
    insert into public.job_status_events(job_id, actor_id, from_status, to_status, action)
    values (new.id, auth.uid(), case when tg_op = 'INSERT' then null else old.status end, new.status, v_action);
  end if;
  return new;
end;
$$;


--
-- Name: complete_job_after_proof_internal(uuid, uuid); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.complete_job_after_proof_internal(p_application_id uuid, p_proof_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_assignment public.job_assignments%rowtype;
  v_job public.jobs%rowtype;
  v_session private.job_execution_sessions%rowtype;
begin
  if auth.uid() is null then return jsonb_build_object('ok',false,'code','authentication_required'); end if;
  select assignment.* into v_assignment from public.job_assignments assignment
   where assignment.application_id=p_application_id;
  if not found or v_assignment.adult_user_id<>auth.uid() then return jsonb_build_object('ok',false,'code','job_participant_required'); end if;
  if v_assignment.status='completed' then return jsonb_build_object('ok',true,'application_id',p_application_id,'status','completed'); end if;
  if v_assignment.status<>'awaiting_confirmation' then return jsonb_build_object('ok',false,'code','job_not_awaiting_confirmation'); end if;

  select session.* into v_session from private.job_execution_sessions session
   where session.assignment_id=v_assignment.id for update;
  if not found or v_session.execution_state<>'completion_pending_release'
     or v_session.review_window_ends_at is null then
    return jsonb_build_object('ok',false,'code','job_execution_review_required');
  end if;
  if v_session.review_window_ends_at>now() then
    return jsonb_build_object('ok',false,'code','completion_review_window_open',
      'review_window_ends_at',v_session.review_window_ends_at);
  end if;

  select assignment.* into v_assignment from public.job_assignments assignment
   where assignment.id=v_assignment.id for update;
  if not found or v_assignment.status<>'awaiting_confirmation'
     or v_assignment.adult_user_id<>auth.uid() then
    return jsonb_build_object('ok',false,'code','job_not_awaiting_confirmation');
  end if;

  select job.* into v_job from public.jobs job where job.id=v_assignment.job_id for update;
  if not found then return jsonb_build_object('ok',false,'code','job_not_available'); end if;
  if v_job.status<>'under_review' then return jsonb_build_object('ok',false,'code','job_not_awaiting_confirmation'); end if;
  if v_job.proof_expected and not exists (
    select 1 from public.proof_uploads proof
     where proof.id=p_proof_id and proof.assignment_id=v_assignment.id
       and proof.application_id=p_application_id and proof.status='approved'
  ) then return jsonb_build_object('ok',false,'code','proof_approval_required'); end if;
  if p_proof_id is not null and not exists (
    select 1 from public.proof_uploads proof
     where proof.id=p_proof_id and proof.assignment_id=v_assignment.id and proof.status='approved'
  ) then return jsonb_build_object('ok',false,'code','proof_approval_required'); end if;

  update public.job_assignments set status='completed',completed_by_adult_at=now(),closed_at=now()
   where id=v_assignment.id;
  update public.jobs set status='completed',completed_at=now(),updated_at=now()
   where id=v_job.id;
  -- Leave the execution session in completion_pending_release: financial
  -- release is a separate server-controlled workflow and this RPC moves no money.
  return jsonb_build_object('ok',true,'application_id',p_application_id,
    'status','completed','financial_release_pending',true);
end;
$$;


--
-- Name: confirm_job_finish_pin_internal(uuid, text, uuid); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.confirm_job_finish_pin_internal(p_application_id uuid, p_pin text, p_client_request_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $_$
declare
  v_user_id uuid := auth.uid();
  v_assignment public.job_assignments%rowtype;
  v_session private.job_execution_sessions%rowtype;
  v_request private.job_pin_confirmation_requests%rowtype;
  v_gate jsonb;
  v_response jsonb;
  v_attempts integer;
begin
  if v_user_id is null or not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;
  if p_client_request_id is null then
    return jsonb_build_object('ok', false, 'code', 'request_id_required');
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_user_id::text || ':' || p_client_request_id::text, 0)
  );
  select request.* into v_request from private.job_pin_confirmation_requests request
   where request.actor_id = v_user_id and request.client_request_id = p_client_request_id;
  if found then
    if v_request.application_id <> p_application_id
       or v_request.pin_kind <> 'finish'
       or extensions.crypt(coalesce(p_pin, ''), v_request.pin_hash) <> v_request.pin_hash then
      return jsonb_build_object('ok', false, 'code', 'pin_request_payload_mismatch');
    end if;
    return v_request.response || jsonb_build_object('replayed', true);
  end if;
  select assignment.* into v_assignment from public.job_assignments assignment
   where assignment.application_id = p_application_id
   for update;
  if not found or v_assignment.teen_user_id <> v_user_id then
    return jsonb_build_object('ok', false, 'code', 'job_participant_required');
  end if;
  if p_pin is null or p_pin !~ '^[0-9]{6}$' then
    return jsonb_build_object('ok', false, 'code', 'finish_pin_invalid');
  end if;
  v_gate := private.job_execution_gate(p_application_id, 'finish');
  if coalesce((v_gate->>'ok')::boolean, false) is not true then
    return v_gate;
  end if;
  select session.* into v_session from private.job_execution_sessions session
   where session.assignment_id = v_assignment.id for update;
  if not found or v_session.finish_pin_hash is null then
    return jsonb_build_object('ok', false, 'code', 'finish_pin_required');
  end if;
  if v_session.finish_pin_used_at is not null then
    return jsonb_build_object('ok', false, 'code', 'finish_pin_already_used');
  end if;
  if v_session.finish_pin_locked_until > now() then
    return jsonb_build_object('ok', false, 'code', 'finish_pin_locked');
  end if;
  if v_session.finish_pin_expires_at <= now() then
    return jsonb_build_object('ok', false, 'code', 'finish_pin_expired');
  end if;

  if extensions.crypt(p_pin, v_session.finish_pin_hash) <> v_session.finish_pin_hash then
    v_attempts := v_session.finish_pin_attempt_count + 1;
    update private.job_execution_sessions
       set finish_pin_attempt_count = v_attempts,
           finish_pin_locked_until = case when v_attempts >= 5 then now() + interval '30 minutes' else null end,
           updated_at = now()
     where assignment_id = v_assignment.id;
    insert into private.job_execution_events(
      assignment_id, application_id, actor_id, event_type,
      from_state, to_state, request_id, safe_metadata
    ) values (
      v_assignment.id, p_application_id, v_user_id,
      case when v_attempts >= 5 then 'finish_pin_locked' else 'finish_pin_failed_attempt' end,
      'finish_pin_active', 'finish_pin_active', p_client_request_id,
      jsonb_build_object('attempt_count', v_attempts)
    ) on conflict do nothing;
    v_response := jsonb_build_object(
      'ok', false,
      'code', case when v_attempts >= 5 then 'finish_pin_locked' else 'finish_pin_invalid' end,
      'attempts_remaining', greatest(0, 5 - v_attempts)
    );
  else
    update private.job_execution_sessions
       set execution_state = 'completion_pending_release',
           finish_pin_used_at = now(), finish_pin_hash = null,
           completion_pending_at = now(),
           review_window_ends_at = now() + interval '24 hours',
           updated_at = now()
     where assignment_id = v_assignment.id;
    update public.job_assignments
       set status = 'awaiting_confirmation',
           completed_by_teen_at = coalesce(completed_by_teen_at, now())
     where id = v_assignment.id;
    update public.jobs set status = 'under_review', updated_at = now()
     where id = v_assignment.job_id and status = 'in_progress';
    insert into private.job_execution_events(
      assignment_id, application_id, actor_id, event_type,
      from_state, to_state, request_id
    ) values (
      v_assignment.id, p_application_id, v_user_id, 'finish_confirmed',
      'finish_pin_active', 'completion_pending_release', p_client_request_id
    ) on conflict do nothing;
    v_response := jsonb_build_object(
      'ok', true,
      'replayed', false,
      'state', 'completion_pending_release',
      'review_window_ends_at', now() + interval '24 hours',
      'money_moved', false
    );
  end if;
  insert into private.job_pin_confirmation_requests(
    actor_id, client_request_id, application_id, pin_kind,
    pin_hash, person_matches_profile, response
  ) values (
    v_user_id, p_client_request_id, p_application_id, 'finish',
    extensions.crypt(coalesce(p_pin, ''), extensions.gen_salt('bf', 10)),
    null, v_response
  ) on conflict (actor_id, client_request_id) do nothing;
  return v_response;
end;
$_$;


--
-- Name: confirm_job_safety_agreement_internal(uuid, integer); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.confirm_job_safety_agreement_internal(p_application_id uuid, p_agreement_version integer) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_user uuid := auth.uid();
  v_agreement public.job_safety_agreements%rowtype;
  v_terms jsonb;
begin
  if v_user is null or not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;
  if not private.is_job_safety_participant(p_application_id, v_user) then
    return jsonb_build_object('ok', false, 'code', 'job_participant_required');
  end if;
  if not exists (
    select 1
    from public.job_applications application
    join public.job_assignments assignment
      on assignment.application_id = application.id
     and assignment.job_id = application.job_id
    where application.id = p_application_id
      and application.status = 'accepted'::public.mort_application_status
      and assignment.status = 'accepted'
  ) then
    return jsonb_build_object('ok', false, 'code', 'accepted_job_required');
  end if;

  select * into v_agreement
  from public.job_safety_agreements
  where application_id = p_application_id
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'safety_agreement_not_found');
  end if;
  if p_agreement_version is null
     or p_agreement_version <> v_agreement.agreement_version then
    return jsonb_build_object('ok', false, 'code', 'safety_agreement_version_changed');
  end if;

  v_terms := private.job_safety_terms(p_application_id);
  if v_terms is null
     or v_agreement.material_terms_hash <>
       encode(extensions.digest(v_agreement.terms_snapshot::text, 'sha256'), 'hex')
     or v_agreement.material_terms_hash <>
       encode(extensions.digest(v_terms::text, 'sha256'), 'hex') then
    perform private.refresh_job_safety_agreement(p_application_id);
    return jsonb_build_object('ok', false, 'code', 'safety_agreement_version_changed');
  end if;

  if not exists (
    select 1 from public.job_safety_plans plan
    where plan.application_id = p_application_id
      and plan.checkin_cadence_minutes between 15 and 240
      and (plan.expected_people is not null or exists (
        select 1 from public.jobs job
        where job.id = plan.job_id and job.remote_allowed
      ))
  ) then
    return jsonb_build_object('ok', false, 'code', 'safety_plan_required');
  end if;

  update public.job_safety_agreements
  set teen_confirmed_at = case when teen_id = v_user then coalesce(teen_confirmed_at, now()) else teen_confirmed_at end,
      adult_confirmed_at = case when adult_id = v_user then coalesce(adult_confirmed_at, now()) else adult_confirmed_at end,
      teen_confirmed_version = case when teen_id = v_user then agreement_version else teen_confirmed_version end,
      adult_confirmed_version = case when adult_id = v_user then agreement_version else adult_confirmed_version end,
      updated_at = now()
  where application_id = p_application_id
  returning * into v_agreement;

  update public.job_safety_agreements
  set status = case
    when teen_confirmed_version = agreement_version
      and adult_confirmed_version = agreement_version then 'confirmed'
    when teen_confirmed_version = agreement_version then 'awaiting_adult'
    when adult_confirmed_version = agreement_version then 'awaiting_teen'
    else 'awaiting_both'
  end,
  updated_at = now()
  where application_id = p_application_id
  returning * into v_agreement;

  return jsonb_build_object(
    'ok', true,
    'status', v_agreement.status,
    'agreement_version', v_agreement.agreement_version,
    'both_confirmed', v_agreement.status = 'confirmed'
  );
end;
$$;


--
-- Name: confirm_job_start_pin_internal(uuid, text, boolean, uuid); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.confirm_job_start_pin_internal(p_application_id uuid, p_pin text, p_person_matches_profile boolean, p_client_request_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $_$
declare
  v_user_id uuid := auth.uid();
  v_assignment public.job_assignments%rowtype;
  v_session private.job_execution_sessions%rowtype;
  v_request private.job_pin_confirmation_requests%rowtype;
  v_gate jsonb;
  v_response jsonb;
  v_attempts integer;
begin
  if v_user_id is null or not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;
  if p_client_request_id is null then
    return jsonb_build_object('ok', false, 'code', 'request_id_required');
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_user_id::text || ':' || p_client_request_id::text, 0)
  );
  select request.* into v_request from private.job_pin_confirmation_requests request
   where request.actor_id = v_user_id and request.client_request_id = p_client_request_id;
  if found then
    if v_request.application_id <> p_application_id
       or v_request.pin_kind <> 'start'
       or v_request.person_matches_profile is distinct from p_person_matches_profile
       or extensions.crypt(coalesce(p_pin, ''), v_request.pin_hash) <> v_request.pin_hash then
      return jsonb_build_object('ok', false, 'code', 'pin_request_payload_mismatch');
    end if;
    return v_request.response || jsonb_build_object('replayed', true);
  end if;
  select assignment.* into v_assignment from public.job_assignments assignment
   where assignment.application_id = p_application_id
   for update;
  if not found or v_assignment.teen_user_id <> v_user_id then
    return jsonb_build_object('ok', false, 'code', 'job_participant_required');
  end if;

  if p_person_matches_profile is null then
    return jsonb_build_object('ok', false, 'code', 'person_match_confirmation_required');
  end if;

  if coalesce(p_person_matches_profile, false) is false then
    if v_assignment.status <> 'accepted' then
      return jsonb_build_object('ok', false, 'code', 'job_not_awaiting_start');
    end if;
    return private.submit_safety_cancellation_internal(
      p_application_id,
      'person_mismatch',
      'The teen reported that the adult present did not match the profile for this job. Do not proceed until reviewed.'
    ) || jsonb_build_object('code', 'person_mismatch_reported');
  end if;
  if p_pin is null or p_pin !~ '^[0-9]{6}$' then
    return jsonb_build_object('ok', false, 'code', 'start_pin_invalid');
  end if;
  v_gate := private.job_execution_gate(p_application_id, 'start');
  if coalesce((v_gate->>'ok')::boolean, false) is not true then
    return v_gate;
  end if;
  select session.* into v_session from private.job_execution_sessions session
   where session.assignment_id = v_assignment.id for update;
  if not found or v_session.start_pin_hash is null then
    return jsonb_build_object('ok', false, 'code', 'start_pin_required');
  end if;
  if v_session.start_pin_used_at is not null then
    return jsonb_build_object('ok', false, 'code', 'start_pin_already_used');
  end if;
  if v_session.start_pin_locked_until > now() then
    return jsonb_build_object('ok', false, 'code', 'start_pin_locked');
  end if;
  if v_session.start_pin_expires_at <= now() then
    return jsonb_build_object('ok', false, 'code', 'start_pin_expired');
  end if;

  if extensions.crypt(p_pin, v_session.start_pin_hash) <> v_session.start_pin_hash then
    v_attempts := v_session.start_pin_attempt_count + 1;
    update private.job_execution_sessions
       set start_pin_attempt_count = v_attempts,
           start_pin_locked_until = case when v_attempts >= 5 then now() + interval '30 minutes' else null end,
           updated_at = now()
     where assignment_id = v_assignment.id;
    insert into private.job_execution_events(
      assignment_id, application_id, actor_id, event_type,
      from_state, to_state, request_id, safe_metadata
    ) values (
      v_assignment.id, p_application_id, v_user_id,
      case when v_attempts >= 5 then 'start_pin_locked' else 'start_pin_failed_attempt' end,
      'start_pin_active', 'start_pin_active', p_client_request_id,
      jsonb_build_object('attempt_count', v_attempts)
    ) on conflict do nothing;
    v_response := jsonb_build_object(
      'ok', false,
      'code', case when v_attempts >= 5 then 'start_pin_locked' else 'start_pin_invalid' end,
      'attempts_remaining', greatest(0, 5 - v_attempts)
    );
  else
    update private.job_execution_sessions
       set execution_state = 'in_progress',
           start_pin_used_at = now(), start_pin_hash = null,
           finish_pin_hash = null,
           updated_at = now()
     where assignment_id = v_assignment.id;
    update public.job_assignments
       set status = 'in_progress', started_at = coalesce(started_at, now())
     where id = v_assignment.id;
    update public.jobs set status = 'in_progress', updated_at = now()
     where id = v_assignment.job_id and status = 'filled';
    insert into private.job_execution_events(
      assignment_id, application_id, actor_id, event_type,
      from_state, to_state, request_id
    ) values (
      v_assignment.id, p_application_id, v_user_id, 'start_confirmed',
      'start_pin_active', 'in_progress', p_client_request_id
    ) on conflict do nothing;
    v_response := jsonb_build_object(
      'ok', true, 'replayed', false, 'state', 'in_progress', 'money_moved', false
    );
  end if;

  insert into private.job_pin_confirmation_requests(
    actor_id, client_request_id, application_id, pin_kind,
    pin_hash, person_matches_profile, response
  ) values (
    v_user_id, p_client_request_id, p_application_id, 'start',
    extensions.crypt(coalesce(p_pin, ''), extensions.gen_salt('bf', 10)),
    p_person_matches_profile, v_response
  ) on conflict (actor_id, client_request_id) do nothing;
  return v_response;
end;
$_$;


--
-- Name: create_job_contract_after_acceptance(); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.create_job_contract_after_acceptance() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_job public.jobs%rowtype;
  v_teen public.profiles%rowtype;
  v_adult public.profiles%rowtype;
  v_contract_id uuid;
  v_terms jsonb;
  v_amount_cents integer;
  v_amount_type text;
  v_hours numeric(6,2);
  v_excluded_work text[] := array[
    'Work outside the accepted scope',
    'Work prohibited by MORT safety rules'
  ]::text[];
begin
  if new.status <> 'accepted'::public.mort_application_status
     or old.status = 'accepted'::public.mort_application_status then
    return new;
  end if;

  select * into v_job from public.jobs where id = new.job_id;
  select * into v_teen from public.profiles where id = new.applicant_id;
  select * into v_adult from public.profiles where id = v_job.poster_id;
  if v_job.id is null or v_teen.id is null or v_adult.id is null then
    raise exception 'Contract participants are unavailable';
  end if;

  insert into public.job_contracts (job_id, application_id, teen_id, adult_id)
  values (v_job.id, new.id, v_teen.id, v_adult.id)
  on conflict (application_id) do nothing
  returning id into v_contract_id;
  if v_contract_id is null then
    select id into v_contract_id from public.job_contracts where application_id = new.id;
  end if;
  if exists (select 1 from public.job_contract_versions where contract_id = v_contract_id) then
    return new;
  end if;

  v_amount_cents := greatest(0, coalesce(
    v_job.pay_amount_cents,
    round(v_job.pay_amount * 100)::integer,
    0
  ));
  v_amount_type := case when v_job.payment_type = 'hourly' then 'hourly' else 'fixed' end;
  v_hours := greatest(
    0.25,
    coalesce(v_job.estimated_duration_minutes, v_job.estimated_minutes, 60)::numeric / 60
  );
  v_terms := jsonb_build_object(
    'teen_public_identifier', coalesce(nullif(v_teen.username, ''), nullif(v_teen.display_name, ''), 'Teen participant'),
    'adult_public_identifier', coalesce(nullif(v_adult.username, ''), nullif(v_adult.display_name, ''), 'Adult participant'),
    'agreed_scope', v_job.description,
    'excluded_work', to_jsonb(v_excluded_work),
    'location_type', coalesce(nullif(v_job.location_type, ''), 'unspecified'),
    'exact_location_release_state', 'accepted_not_released',
    'service_date', coalesce(v_job.starts_at::date, current_date)::text,
    'start_window', v_job.starts_at,
    'expected_end_window', v_job.ends_at,
    'amount_type', v_amount_type,
    'hourly_rate_cents', case when v_amount_type = 'hourly' then v_amount_cents else null end,
    'maximum_approved_hours', case when v_amount_type = 'hourly' then v_hours else null end,
    'fixed_total_cents', case when v_amount_type = 'fixed' then v_amount_cents else null end,
    'currency_code', 'USD',
    'payment_preference', coalesce(v_job.payment_method, 'flexible'),
    'payment_due_rule', coalesce(v_job.payment_timing, 'after_completion'),
    'authorized_expenses', '[]'::jsonb,
    'equipment', nullif(concat_ws('; ', nullif(v_job.equipment_provided, ''), nullif(v_job.equipment_worker_brings, '')), ''),
    'hazards', nullif(v_job.safety_notes, ''),
    'expected_people_present', 'Not specified; confirm before work begins.',
    'supervision', case when v_job.adult_supervision_present then 'Adult supervision disclosed as present.' else 'No adult supervision commitment recorded.' end,
    'proof_requirements', case when v_job.proof_expected then coalesce(nullif(v_job.special_instructions, ''), 'Reasonable, noninvasive completion proof requested.') else 'No media proof required.' end,
    'completion_requirements', coalesce(nullif(v_job.summary, ''), v_job.description),
    'cancellation_terms', 'Contact the other party in MORT before cancelling or changing the agreed schedule.',
    'material_change_process', 'Changes to scope, pay, hours, location, hazards, expenses, or timing require a new version and both parties’ confirmation.',
    'dispute_process', 'Raise concerns privately through MORT. MORT does not determine legal liability or guarantee recovery.',
    'safety_agreement_version', 'job-safety-v1',
    'payment_processed_by_mort', false,
    'escrow_provided_by_mort', false
  );

  insert into public.job_contract_versions (
    contract_id, version_number, source, teen_public_identifier,
    adult_public_identifier, agreed_scope, excluded_work, location_type,
    exact_location_release_state, service_date, start_window,
    expected_end_window, amount_type, hourly_rate_cents,
    maximum_approved_hours, fixed_total_cents, currency_code,
    payment_preference, payment_due_rule, authorized_expenses,
    equipment, hazards, expected_people_present, supervision,
    proof_requirements, completion_requirements, cancellation_terms,
    material_change_process, dispute_process, safety_agreement_version,
    terms_snapshot, content_hash, created_by
  ) values (
    v_contract_id, 1, 'application_acceptance',
    v_terms->>'teen_public_identifier', v_terms->>'adult_public_identifier',
    v_terms->>'agreed_scope', v_excluded_work, v_terms->>'location_type',
    v_terms->>'exact_location_release_state', (v_terms->>'service_date')::date,
    (v_terms->>'start_window')::timestamptz, (v_terms->>'expected_end_window')::timestamptz,
    v_amount_type,
    case when v_amount_type = 'hourly' then v_amount_cents else null end,
    case when v_amount_type = 'hourly' then v_hours else null end,
    case when v_amount_type = 'fixed' then v_amount_cents else null end,
    'USD', coalesce(v_job.payment_method, 'flexible'), coalesce(v_job.payment_timing, 'after_completion'),
    '{}'::text[], v_terms->>'equipment', v_terms->>'hazards', v_terms->>'expected_people_present',
    v_terms->>'supervision', v_terms->>'proof_requirements', v_terms->>'completion_requirements',
    v_terms->>'cancellation_terms', v_terms->>'material_change_process',
    v_terms->>'dispute_process', v_terms->>'safety_agreement_version', v_terms,
    encode(extensions.digest(v_terms::text, 'sha256'), 'hex'), v_job.poster_id
  );
  return new;
end;
$$;


--
-- Name: create_job_safety_agreement_after_acceptance(); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.create_job_safety_agreement_after_acceptance() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_job public.jobs%rowtype;
  v_terms jsonb;
begin
  if new.status <> 'accepted'::public.mort_application_status
     or old.status is not distinct from new.status then
    return new;
  end if;

  select * into v_job from public.jobs where id = new.job_id;
  if v_job.id is null then
    raise exception 'Safety agreement job is unavailable';
  end if;

  insert into public.job_safety_plans (
    application_id, job_id, teen_id, adult_id,
    public_or_visible_meeting, daylight_preferred, checkin_cadence_minutes
  ) values (
    new.id, new.job_id, new.applicant_id, v_job.poster_id, true, true, 30
  ) on conflict (application_id) do nothing;

  v_terms := private.job_safety_terms(new.id);
  insert into public.job_safety_agreements (
    application_id, job_id, teen_id, adult_id,
    terms_snapshot, material_terms_hash
  ) values (
    new.id, new.job_id, new.applicant_id, v_job.poster_id,
    v_terms, encode(extensions.digest(v_terms::text, 'sha256'), 'hex')
  ) on conflict (application_id) do nothing;

  return new;
end;
$$;


--
-- Name: current_role(); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private."current_role"() RETURNS public.mort_role
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
  select p.role from public.profiles p where p.id = (select auth.uid());
$$;


--
-- Name: enforce_minor_school_email_on_auth_email_change(); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.enforce_minor_school_email_on_auth_email_change() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_dob date;
begin
  if new.email is not distinct from old.email then
    return new;
  end if;

  select p.date_of_birth
    into v_dob
  from public.profiles p
  where p.id = new.id;

  if v_dob is not null
    and extract(year from age(current_date, v_dob))::integer between 13 and 17
    and not private.is_approved_school_email(new.email) then
    raise exception using
      errcode = 'check_violation',
      message = 'MORT_SCHOOL_EMAIL_REQUIRED';
  end if;

  return new;
end;
$$;


--
-- Name: enforce_profile_minimum_age(); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.enforce_profile_minimum_age() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_age integer;
begin
  if new.date_of_birth is null then
    if tg_op = 'UPDATE' and old.date_of_birth is not null then
      raise exception using errcode = 'check_violation', message = 'MORT_DOB_IMMUTABLE';
    end if;
    return new;
  end if;

  if new.date_of_birth > current_date then
    raise exception using errcode = 'check_violation', message = 'MORT_DOB_INVALID';
  end if;

  v_age := private.mort_age_years(new.date_of_birth);
  if v_age < 13 then
    raise exception using errcode = 'check_violation', message = 'MORT_MINIMUM_AGE_REQUIRED';
  end if;

  if tg_op = 'UPDATE' and old.date_of_birth is not null
     and new.date_of_birth is distinct from old.date_of_birth then
    raise exception using errcode = 'check_violation', message = 'MORT_DOB_IMMUTABLE';
  end if;

  if v_age between 13 and 17 and new.role not in ('pending'::public.mort_role, 'teen'::public.mort_role) then
    raise exception using errcode = 'check_violation', message = 'MORT_MINOR_ROLE_REQUIRED';
  end if;
  if v_age >= 18 and new.role = 'teen'::public.mort_role then
    raise exception using errcode = 'check_violation', message = 'MORT_ADULT_ROLE_REQUIRED';
  end if;

  return new;
end;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.profiles (
    id uuid NOT NULL,
    role public.mort_role DEFAULT 'pending'::public.mort_role NOT NULL,
    account_status text DEFAULT 'pending'::text NOT NULL,
    display_name text,
    avatar_path text,
    bio text,
    city text,
    region text,
    timezone text DEFAULT 'America/Indiana/Indianapolis'::text NOT NULL,
    date_of_birth date,
    onboarding_completed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    username text,
    location_setup_mode text DEFAULT 'city_state'::text NOT NULL,
    approximate_area text,
    availability text,
    preferred_job_categories text[] DEFAULT '{}'::text[] NOT NULL,
    transportation_methods text[] DEFAULT '{}'::text[] NOT NULL,
    max_travel_distance_miles integer,
    max_travel_minutes integer,
    walking_distance_only boolean DEFAULT false NOT NULL,
    guardian_transportation_possible boolean DEFAULT false NOT NULL,
    guardian_setup_status text DEFAULT 'not_started'::text NOT NULL,
    verification_status text DEFAULT 'not_started'::text NOT NULL,
    avatar_moderation_status text DEFAULT 'active'::text NOT NULL,
    avatar_updated_at timestamp with time zone,
    guardian_paused boolean DEFAULT false NOT NULL,
    guardian_paused_at timestamp with time zone,
    guardian_paused_by uuid,
    CONSTRAINT profiles_account_status_check CHECK ((account_status = ANY (ARRAY['pending'::text, 'active'::text, 'suspended'::text, 'closed'::text]))),
    CONSTRAINT profiles_bio_length CHECK (((bio IS NULL) OR (char_length(bio) <= 500))),
    CONSTRAINT profiles_display_name_length CHECK (((display_name IS NULL) OR ((char_length(display_name) >= 1) AND (char_length(display_name) <= 80)))),
    CONSTRAINT profiles_no_public_dob CHECK (((date_of_birth IS NULL) OR (date_of_birth <= CURRENT_DATE)))
);

ALTER TABLE ONLY public.profiles FORCE ROW LEVEL SECURITY;


--
-- Name: ensure_my_profile(); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.ensure_my_profile() RETURNS SETOF public.profiles
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_user_id uuid := (select auth.uid());
begin
  if v_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'authentication_required';
  end if;

  if not exists (
    select 1 from auth.users as auth_user where auth_user.id = v_user_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'authentication_required';
  end if;

  -- Only fill a missing row. Never overwrite role, account status, or user data.
  insert into public.profiles (id)
  values (v_user_id)
  on conflict (id) do nothing;

  if not exists (
    select 1 from public.profiles as profile where profile.id = v_user_id
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'profile_bootstrap_failed';
  end if;

  return query
  select profile.*
  from public.profiles as profile
  where profile.id = v_user_id;
end;
$$;


--
-- Name: evaluate_mort_onboarding(uuid); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.evaluate_mort_onboarding(p_user_id uuid) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $_$
declare
  profile public.profiles%rowtype;
  missing text[] := array[]::text[];
  completed_steps text[] := array[]::text[];
  active_step text := 'account';
  current_age integer;
  safety_saved boolean;
begin
  select * into profile from public.profiles where id = p_user_id;
  if profile.id is null then
    missing := array['profile'];
  else
    if profile.role not in ('teen'::public.mort_role, 'adult'::public.mort_role, 'guardian'::public.mort_role) then
      missing := missing || array['role'];
    end if;
    if profile.date_of_birth is null then missing := missing || array['date_of_birth']; end if;
    if coalesce(length(btrim(profile.display_name)), 0) < 2 then missing := missing || array['display_name']; end if;
    if profile.username is null then missing := missing || array['username']; end if;
    if profile.role in ('adult'::public.mort_role, 'guardian'::public.mort_role)
      and (nullif(btrim(profile.city), '') is null or profile.region !~ '^[A-Z]{2}$') then
      missing := missing || array['general_location'];
    elsif profile.role = 'teen'::public.mort_role
      and (profile.location_setup_mode <> 'location_deferred'
        or nullif(btrim(profile.approximate_area), '') is null) then
      missing := missing || array['approximate_area'];
    end if;
    if profile.date_of_birth is not null then
      current_age := extract(year from age(current_date, profile.date_of_birth))::integer;
      if current_age < 13
        or (profile.role = 'teen'::public.mort_role and current_age not between 13 and 17)
        or (profile.role in ('adult'::public.mort_role, 'guardian'::public.mort_role) and current_age < 18) then
        missing := missing || array['age_role_eligibility'];
      end if;
    end if;
  end if;

  if cardinality(missing) = 0 then
    completed_steps := completed_steps || array['account'];
    active_step := 'work_preferences';
    if profile.role = 'teen'::public.mort_role then
      if nullif(btrim(profile.availability), '') is null then missing := missing || array['availability']; end if;
      if cardinality(profile.preferred_job_categories) = 0 then missing := missing || array['preferred_job_categories']; end if;
      if cardinality(profile.transportation_methods) = 0 then missing := missing || array['transportation_methods']; end if;
    end if;
  end if;

  if cardinality(missing) = 0 then
    completed_steps := completed_steps || array['work_preferences'];
    active_step := 'safety_support';
    select exists (select 1 from private.mort_onboarding_safety where user_id = p_user_id)
      into safety_saved;
    if not safety_saved then missing := missing || array['safety_support_intent']; end if;
    if profile.role = 'teen'::public.mort_role
      and profile.guardian_setup_status not in ('skipped', 'invite_pending', 'linked') then
      missing := missing || array['guardian_setup_choice'];
    end if;
  end if;

  if cardinality(missing) = 0 then
    completed_steps := completed_steps || array['safety_support'];
    active_step := 'review';
    if profile.onboarding_completed_at is not null then
      completed_steps := completed_steps || array['review'];
      active_step := 'complete';
    else
      -- This project has no published legal-document version to accept yet.
      missing := array['published_legal_documents'];
    end if;
  end if;

  return jsonb_build_object(
    'ok', true,
    'completed', active_step = 'complete',
    'active_step', active_step,
    'primary_steps', jsonb_build_array('account','work_preferences','safety_support','review'),
    'completed_steps', to_jsonb(completed_steps),
    'missing_requirements', to_jsonb(missing),
    'role', profile.role::text,
    'revision', profile.updated_at,
    'replayed', false
  );
end;
$_$;


--
-- Name: generate_job_finish_pin_internal(uuid, uuid); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.generate_job_finish_pin_internal(p_application_id uuid, p_client_request_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_user_id uuid := auth.uid();
  v_assignment public.job_assignments%rowtype;
  v_session private.job_execution_sessions%rowtype;
  v_gate jsonb;
  v_pin text;
  v_random bytea;
begin
  if v_user_id is null or not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;
  if p_client_request_id is null then
    return jsonb_build_object('ok', false, 'code', 'request_id_required');
  end if;
  select assignment.* into v_assignment from public.job_assignments assignment
   where assignment.application_id = p_application_id
   for update;
  if not found or v_assignment.adult_user_id <> v_user_id then
    return jsonb_build_object('ok', false, 'code', 'job_participant_required');
  end if;
  v_gate := private.job_execution_gate(p_application_id, 'finish');
  if coalesce((v_gate->>'ok')::boolean, false) is not true then
    return v_gate;
  end if;
  select session.* into v_session from private.job_execution_sessions session
   where session.assignment_id = v_assignment.id for update;
  if not found or v_session.execution_state not in ('in_progress', 'finish_pin_active') then
    return jsonb_build_object('ok', false, 'code', 'job_not_in_progress');
  end if;
  if v_session.finish_client_request_id = p_client_request_id then
    return jsonb_build_object(
      'ok', false,
      'code', 'pin_generation_replayed',
      'expires_at', v_session.finish_pin_expires_at
    );
  end if;
  if v_session.finish_pin_generated_at is not null
     and v_session.finish_pin_generated_at + interval '60 seconds' > now() then
    return jsonb_build_object(
      'ok', false,
      'code', 'pin_generation_rate_limited',
      'retry_at', v_session.finish_pin_generated_at + interval '60 seconds'
    );
  end if;
  v_random := extensions.gen_random_bytes(4);
  v_pin := lpad((mod(
    get_byte(v_random, 0)::bigint * 16777216
      + get_byte(v_random, 1)::bigint * 65536
      + get_byte(v_random, 2)::bigint * 256
      + get_byte(v_random, 3)::bigint,
    1000000
  ))::text, 6, '0');
  update private.job_execution_sessions
     set execution_state = 'finish_pin_active',
         finish_pin_hash = extensions.crypt(v_pin, extensions.gen_salt('bf', 10)),
         finish_pin_generated_at = now(),
         finish_pin_expires_at = now() + interval '10 minutes',
         finish_pin_used_at = null,
         finish_pin_attempt_count = 0,
         finish_pin_locked_until = null,
         finish_client_request_id = p_client_request_id,
         updated_at = now()
   where assignment_id = v_assignment.id
   returning * into v_session;
  update public.job_assignments set completed_by_adult_at = now()
   where id = v_assignment.id;
  insert into private.job_execution_events(
    assignment_id, application_id, actor_id, event_type,
    from_state, to_state, request_id
  ) values (
    v_assignment.id, p_application_id, v_user_id, 'finish_pin_generated',
    'in_progress', 'finish_pin_active', p_client_request_id
  ) on conflict do nothing;
  return jsonb_build_object(
    'ok', true,
    'finish_pin', v_pin,
    'expires_at', v_session.finish_pin_expires_at,
    'state', 'finish_pin_active'
  );
end;
$$;


--
-- Name: generate_job_start_pin_internal(uuid, uuid); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.generate_job_start_pin_internal(p_application_id uuid, p_client_request_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_user_id uuid := auth.uid();
  v_assignment public.job_assignments%rowtype;
  v_session private.job_execution_sessions%rowtype;
  v_gate jsonb;
  v_pin text;
  v_random bytea;
begin
  if v_user_id is null or not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;
  if p_client_request_id is null then
    return jsonb_build_object('ok', false, 'code', 'request_id_required');
  end if;
  select assignment.* into v_assignment from public.job_assignments assignment
   where assignment.application_id = p_application_id
   for update;
  if not found or v_assignment.adult_user_id <> v_user_id then
    return jsonb_build_object('ok', false, 'code', 'job_participant_required');
  end if;
  v_gate := private.job_execution_gate(p_application_id, 'start');
  if coalesce((v_gate->>'ok')::boolean, false) is not true then
    return v_gate;
  end if;

  insert into private.job_execution_sessions(assignment_id, application_id, job_id)
  values (v_assignment.id, v_assignment.application_id, v_assignment.job_id)
  on conflict (assignment_id) do nothing;
  select session.* into v_session from private.job_execution_sessions session
   where session.assignment_id = v_assignment.id for update;
  if v_session.start_pin_used_at is not null then
    return jsonb_build_object('ok', false, 'code', 'start_pin_already_used');
  end if;
  if v_session.start_client_request_id = p_client_request_id then
    return jsonb_build_object(
      'ok', false,
      'code', 'pin_generation_replayed',
      'expires_at', v_session.start_pin_expires_at
    );
  end if;
  if v_session.start_pin_generated_at is not null
     and v_session.start_pin_generated_at + interval '60 seconds' > now() then
    return jsonb_build_object(
      'ok', false,
      'code', 'pin_generation_rate_limited',
      'retry_at', v_session.start_pin_generated_at + interval '60 seconds'
    );
  end if;
  v_random := extensions.gen_random_bytes(4);
  v_pin := lpad((mod(
    get_byte(v_random, 0)::bigint * 16777216
      + get_byte(v_random, 1)::bigint * 65536
      + get_byte(v_random, 2)::bigint * 256
      + get_byte(v_random, 3)::bigint,
    1000000
  ))::text, 6, '0');
  update private.job_execution_sessions
     set execution_state = 'start_pin_active',
         start_pin_hash = extensions.crypt(v_pin, extensions.gen_salt('bf', 10)),
         start_pin_generated_at = now(),
         start_pin_expires_at = now() + interval '10 minutes',
         start_pin_used_at = null,
         start_pin_attempt_count = 0,
         start_pin_locked_until = null,
         start_client_request_id = p_client_request_id,
         updated_at = now()
   where assignment_id = v_assignment.id
   returning * into v_session;
  insert into private.job_execution_events(
    assignment_id, application_id, actor_id, event_type,
    from_state, to_state, request_id
  ) values (
    v_assignment.id, p_application_id, v_user_id, 'start_pin_generated',
    'awaiting_start', 'start_pin_active', p_client_request_id
  ) on conflict do nothing;
  return jsonb_build_object(
    'ok', true,
    'start_pin', v_pin,
    'expires_at', v_session.start_pin_expires_at,
    'state', 'start_pin_active'
  );
end;
$$;


--
-- Name: get_job_execution_status_internal(uuid); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.get_job_execution_status_internal(p_application_id uuid) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_user_id uuid := auth.uid();
  v_assignment public.job_assignments%rowtype;
  v_contract public.job_contracts%rowtype;
  v_session private.job_execution_sessions%rowtype;
  v_funding_status text;
  v_live_payment_enabled boolean := false;
  v_state text;
begin
  if v_user_id is null or not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;
  select assignment.* into v_assignment from public.job_assignments assignment
   where assignment.application_id = p_application_id
     and v_user_id in (assignment.teen_user_id, assignment.adult_user_id);
  if not found then
    return jsonb_build_object('ok', false, 'code', 'job_participant_required');
  end if;
  select contract.* into v_contract from public.job_contracts contract
   where contract.application_id = p_application_id
     and v_user_id in (contract.teen_id, contract.adult_id);
  if not found then
    return jsonb_build_object('ok', false, 'code', 'active_contract_required');
  end if;
  select session.* into v_session from private.job_execution_sessions session
   where session.assignment_id = v_assignment.id;
  select payment.status into v_funding_status
    from public.payment_records payment
   where payment.assignment_id = v_assignment.id
     and v_user_id in (payment.payer_id, payment.payee_id)
   order by payment.updated_at desc, payment.created_at desc limit 1;
  if v_funding_status is null then
    select payment.status into v_funding_status
      from private.stripe_payment_intents payment
     where payment.assignment_id = v_assignment.id
     order by payment.updated_at desc limit 1;
  end if;
  v_live_payment_enabled := coalesce(
    not ((public.get_runtime_feature_status()->>'payments_disabled')::boolean), false
  );
  v_state := case
    when v_assignment.status = 'awaiting_confirmation' then 'completion_pending_release'
    when v_assignment.status = 'completed' then 'completed'
    when v_assignment.status = 'cancelled' then 'cancelled'
    when v_assignment.status = 'disputed' then 'disputed'
    when v_session.finish_pin_hash is not null
      and v_session.finish_pin_expires_at > now() then 'finish_pin_active'
    when v_assignment.status = 'in_progress' then 'in_progress'
    when v_session.start_pin_hash is not null
      and v_session.start_pin_expires_at > now() then 'start_pin_active'
    else 'awaiting_start'
  end;
  return pg_catalog.jsonb_build_object(
    'ok', true,
    'application_id', v_assignment.application_id,
    'job_id', v_assignment.job_id,
    'contract_id', v_contract.id,
    'role', case when v_user_id = v_assignment.teen_user_id then 'teen' else 'adult' end,
    'state', v_state,
    'funding_status', case when v_funding_status in ('succeeded', 'authorized') then 'funded'
                           else coalesce(v_funding_status, 'missing') end,
    'start_pin_active', v_session.start_pin_hash is not null
      and v_session.start_pin_expires_at > now(),
    'finish_pin_active', v_session.finish_pin_hash is not null
      and v_session.finish_pin_expires_at > now(),
    'live_payment_enabled', v_live_payment_enabled,
    'start_pin_expires_at', v_session.start_pin_expires_at,
    'finish_pin_expires_at', v_session.finish_pin_expires_at,
    'started_at', v_assignment.started_at,
    'completion_pending_at', coalesce(v_session.completion_pending_at, v_assignment.completed_by_teen_at),
    'review_window_ends_at', v_session.review_window_ends_at,
    'contract_ready', v_contract.status = 'active' and v_contract.active_version_id is not null,
    'execution_actions_enabled', true,
    'execution_actions_reason', null
  );
end;
$$;


--
-- Name: guard_job_table_mutations(); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.guard_job_table_mutations() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO ''
    AS $$
begin
  if current_user in ('anon', 'authenticated') then
    raise exception using errcode = '42501', message = 'Use the protected job operations.';
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;


--
-- Name: handle_new_user(); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.handle_new_user() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_dob_text text;
  v_dob date;
  v_provider text;
begin
  v_provider := coalesce(new.raw_app_meta_data ->> 'provider', 'email');
  v_dob_text := nullif(btrim(coalesce(
    new.raw_user_meta_data ->> 'date_of_birth',
    new.raw_user_meta_data ->> 'dob',
    ''
  )), '');

  if v_dob_text is null and new.invited_at is null and v_provider = 'email' then
    raise exception using
      errcode = 'check_violation',
      message = 'MORT_DOB_REQUIRED';
  end if;

  if v_dob_text is not null then
    begin
      v_dob := v_dob_text::date;
    exception when others then
      raise exception using errcode = 'check_violation', message = 'MORT_DOB_INVALID';
    end;
    if v_dob > current_date then
      raise exception using errcode = 'check_violation', message = 'MORT_DOB_INVALID';
    end if;
    if private.mort_age_years(v_dob) < 13 then
      raise exception using errcode = 'check_violation', message = 'MORT_MINIMUM_AGE_REQUIRED';
    end if;
  end if;

  insert into public.profiles (id, display_name, role, account_status, date_of_birth)
  values (
    new.id,
    nullif(left(coalesce(new.raw_user_meta_data ->> 'display_name', ''), 80), ''),
    'pending'::public.mort_role,
    'pending',
    v_dob
  )
  on conflict (id) do nothing;
  return new;
end;
$$;


--
-- Name: has_staff_role(public.mort_role[]); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.has_staff_role(required_roles public.mort_role[]) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
  select exists (
    select 1
    from private.user_roles ur
    where ur.user_id = (select auth.uid())
      and ur.role = any(required_roles)
  );
$$;


--
-- Name: ingest_verification_provider_event(text, text, text, text, text); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.ingest_verification_provider_event(p_project_ref text, p_provider_key text, p_timestamp text, p_signature text, p_raw_body text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $_$
declare
  v_key private.verification_provider_ingestion_keys%rowtype;
  v_expected text;
  v_event jsonb;
  v_event_id text;
  v_case_id uuid;
  v_user_id uuid;
  v_type text;
  v_reference text;
  v_result text;
  v_verified_at timestamptz;
  v_expires_at timestamptz;
  v_case public.verification_cases%rowtype;
  v_event_time timestamptz;
  v_sha text;
begin
  if p_provider_key is null or btrim(p_provider_key) = '' or char_length(p_provider_key) > 100
     or p_signature is null or p_signature !~ '^[0-9a-f]{64}$'
     or p_raw_body is null or char_length(p_raw_body) < 2 or char_length(p_raw_body) > 65536
     or p_project_ref is null or p_project_ref !~ '^[a-z]{20}$' then
    return jsonb_build_object('ok', false, 'error', 'invalid_request');
  end if;

  begin
    v_event_time := p_timestamp::timestamptz;
    exception when others then
    return jsonb_build_object('ok', false, 'error', 'invalid_provider_timestamp');
  end;
  if p_timestamp is null or char_length(btrim(p_timestamp)) < 10
     or abs(extract(epoch from (clock_timestamp() - v_event_time))) > 300 then
    return jsonb_build_object('ok', false, 'error', 'stale_provider_timestamp');
  end if;

  -- Tenant binding: the key must exist for this provider AND this project.
  select * into v_key
  from private.verification_provider_ingestion_keys keys
  where keys.provider_key = btrim(p_provider_key)
    and keys.project_ref = p_project_ref
    and keys.is_enabled;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'unknown_provider');
  end if;

  -- HMAC-SHA256 over "<timestamp>.<raw body>".
  v_expected := encode(
    extensions.hmac(
      convert_to(p_timestamp || '.' || p_raw_body, 'UTF8'),
      convert_to(v_key.hmac_key, 'UTF8'),
      'sha256'
    ),
    'hex'
  );
  if p_signature <> v_expected then
    return jsonb_build_object('ok', false, 'error', 'invalid_signature');
  end if;

  -- Event shape.
  begin
    v_event := p_raw_body::jsonb;
    exception when others then
    return jsonb_build_object('ok', false, 'error', 'invalid_json');
  end;
  v_event_id := btrim(coalesce(v_event->>'provider_event_id', ''));
  v_type := btrim(coalesce(v_event->>'verification_type', ''));
  v_result := btrim(coalesce(v_event->>'result', ''));
  v_reference := nullif(btrim(coalesce(v_event->>'provider_reference', '')), '');
  if v_event_id = '' or char_length(v_event_id) > 200
     or v_type not in ('age','identity','guardian_consent','school_email','school_id','business')
     or v_result not in ('verified','rejected','needs_review')
     or (v_reference is not null and char_length(v_reference) > 200) then
    return jsonb_build_object('ok', false, 'error', 'invalid_event_payload');
  end if;
  begin
    v_case_id := (v_event->>'case_id')::uuid;
    v_user_id := (v_event->>'user_id')::uuid;
    exception when others then
    return jsonb_build_object('ok', false, 'error', 'invalid_event_payload');
  end;
  if v_case_id is null or v_user_id is null then
    return jsonb_build_object('ok', false, 'error', 'invalid_event_payload');
  end if;
  if v_event ? 'verified_at' and jsonb_typeof(v_event->'verified_at') <> 'null' then
    begin
      v_verified_at := (v_event->>'verified_at')::timestamptz;
    exception when others then
      return jsonb_build_object('ok', false, 'error', 'invalid_event_payload');
    end;
  end if;
  if v_event ? 'expires_at' and jsonb_typeof(v_event->'expires_at') <> 'null' then
    begin
      v_expires_at := (v_event->>'expires_at')::timestamptz;
    exception when others then
    return jsonb_build_object('ok', false, 'error', 'invalid_event_payload');
    end;
  end if;
  if (v_result = 'verified' and v_verified_at is null)
     or (v_expires_at is not null and v_verified_at is null) then
    return jsonb_build_object('ok', false, 'error', 'invalid_event_payload');
  end if;

  -- Case binding: the case must exist in this project and match the
  -- event's subject, verification type, provider, and reference.
  select * into v_case
  from public.verification_cases cases
  where cases.id = v_case_id;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'case_not_found');
  end if;
  if v_case.user_id <> v_user_id
     or v_case.verification_type <> v_type
     or v_case.provider <> btrim(p_provider_key)
     or v_case.provider_reference is distinct from v_reference then
    return jsonb_build_object('ok', false, 'error', 'case_binding_mismatch');
  end if;

  -- Allowlist: fail closed while empty.
  if not exists (
    select 1
    from private.verification_provider_allowlist allowlist
    where allowlist.provider_key = btrim(p_provider_key)
      and allowlist.verification_type = v_type
      and allowlist.is_enabled
  ) then
    return jsonb_build_object('ok', false, 'error', 'provider_not_allowlisted');
  end if;

  -- Evidence freshness: verified after case submission (staleness), not
  -- future-dated beyond clock skew, and expiry (when set) after verification.
  if v_verified_at is not null then
    if v_verified_at < coalesce(v_case.submitted_at, v_case.created_at)
       or v_verified_at > clock_timestamp() + interval '300 seconds' then
      return jsonb_build_object('ok', false, 'error', 'evidence_time_invalid');
    end if;
  end if;
  if v_expires_at is not null and v_expires_at <= v_verified_at then
    return jsonb_build_object('ok', false, 'error', 'evidence_expiry_invalid');
  end if;

  -- Replay idempotency + provenance fingerprint of the exact raw body.
  v_sha := encode(extensions.digest(convert_to(p_raw_body, 'UTF8'), 'sha256'), 'hex');
  insert into private.verification_provider_results (
    verification_case_id, user_id, verification_type, provider_key,
    provider_reference, provider_event_id, result, evidence_sha256,
    verified_at, expires_at
  ) values (
    v_case.id, v_user_id, v_type, btrim(p_provider_key),
    v_reference, v_event_id, v_result, v_sha,
    v_verified_at, v_expires_at
  )
  on conflict (provider_key, provider_event_id) do nothing;
  if not found then
    return jsonb_build_object('ok', true, 'duplicate', true);
  end if;
  return jsonb_build_object('ok', true, 'duplicate', false);
end;
$_$;


--
-- Name: is_active_user(); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.is_active_user() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
  select exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid())
      and p.account_status = 'active'
      and p.role in ('teen','adult','admin','moderator')
  );
$$;


--
-- Name: is_approved_school_email(text); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.is_approved_school_email(p_email text) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $_$
  select case
    when p_email is null or btrim(p_email) = '' then false
    when p_email !~* '^[^@[:space:]]+@[^@[:space:]]+$' then false
    else exists (
      select 1
      from private.school_email_domains d
      where d.domain = lower(split_part(btrim(p_email), '@', 2))
        and d.status = 'active'
        and d.verified_at is not null
        and d.verification_source is not null
    )
  end;
$_$;


--
-- Name: is_fully_consented_guardian(uuid); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.is_fully_consented_guardian(p_teen_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
  select exists (
    select 1 from public.guardian_links gl
    where gl.guardian_user_id = (select auth.uid())
      and gl.teen_user_id = p_teen_id
      and gl.status = 'active'
      and gl.teen_consent_at is not null
      and gl.guardian_consent_at is not null
  );
$$;


--
-- Name: is_guardian_paused(uuid); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.is_guardian_paused(p_user_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
  select exists (
    select 1 from public.profiles
    where id = p_user_id and guardian_paused
  );
$$;


--
-- Name: is_job_safety_participant(uuid, uuid); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.is_job_safety_participant(p_application_id uuid, p_user_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
  select p_user_id is not null
    and p_user_id = (select auth.uid())
    and exists (
      select 1
      from public.job_applications application
      join public.jobs job on job.id = application.job_id
      join public.job_assignments assignment
        on assignment.application_id = application.id
       and assignment.job_id = application.job_id
      where application.id = p_application_id
        and p_user_id in (application.applicant_id, job.poster_id)
    );
$$;


--
-- Name: job_execution_gate(uuid, text); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.job_execution_gate(p_application_id uuid, p_operation text) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_user_id uuid := auth.uid();
  v_assignment public.job_assignments%rowtype;
  v_application public.job_applications%rowtype;
  v_job public.jobs%rowtype;
  v_teen public.profiles%rowtype;
  v_adult public.profiles%rowtype;
  v_contract public.job_contracts%rowtype;
  v_version public.job_contract_versions%rowtype;
  v_safety public.job_safety_agreements%rowtype;
  v_safety_terms jsonb;
  v_acceptances integer;
  v_funded boolean := false;
  v_runtime jsonb;
  v_start_at timestamptz;
begin
  if p_operation is null or p_operation not in ('start', 'finish') then
    return jsonb_build_object('ok', false, 'code', 'invalid_job_execution_operation');
  end if;
  if v_user_id is null or not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;

  select assignment.* into v_assignment
    from public.job_assignments assignment
   where assignment.application_id = p_application_id;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'job_participant_required');
  end if;
  if v_user_id not in (v_assignment.teen_user_id, v_assignment.adult_user_id) then
    return jsonb_build_object('ok', false, 'code', 'job_participant_required');
  end if;
  if p_operation = 'start' and v_assignment.status <> 'accepted' then
    return jsonb_build_object('ok', false, 'code', 'job_not_awaiting_start');
  end if;
  if p_operation = 'finish' and v_assignment.status <> 'in_progress' then
    return jsonb_build_object('ok', false, 'code', 'job_not_in_progress');
  end if;

  select application.* into v_application
    from public.job_applications application
   where application.id = v_assignment.application_id
     and application.job_id = v_assignment.job_id;
  if not found or v_application.status <> 'accepted'::public.mort_application_status then
    return jsonb_build_object('ok', false, 'code', 'accepted_job_required');
  end if;
  select job.* into v_job
    from public.jobs job
   where job.id = v_assignment.job_id
     and job.poster_id = v_assignment.adult_user_id;
  if not found or (p_operation = 'start' and v_job.status <> 'filled')
     or (p_operation = 'finish' and v_job.status <> 'in_progress') then
    return jsonb_build_object('ok', false, 'code', 'assigned_job_required');
  end if;

  select profile.* into v_teen from public.profiles profile
   where profile.id = v_assignment.teen_user_id;
  select profile.* into v_adult from public.profiles profile
   where profile.id = v_assignment.adult_user_id;
  if v_teen.role <> 'teen' or v_adult.role <> 'adult'
     or v_teen.account_status <> 'active'
     or v_adult.account_status <> 'active'
     or v_teen.verification_status::text <> 'approved'
     or v_adult.verification_status::text <> 'approved' then
    return jsonb_build_object('ok', false, 'code', 'participant_not_eligible');
  end if;

  select contract.* into v_contract from public.job_contracts contract
   where contract.application_id = p_application_id
     and contract.job_id = v_job.id
     and contract.teen_id = v_assignment.teen_user_id
     and contract.adult_id = v_assignment.adult_user_id;
  if not found or v_contract.status <> 'active'
     or v_contract.active_version_id is null then
    return jsonb_build_object('ok', false, 'code', 'active_contract_required');
  end if;
  select version.* into v_version from public.job_contract_versions version
   where version.id = v_contract.active_version_id
     and version.contract_id = v_contract.id
     and version.status = 'active';
  if not found then
    return jsonb_build_object('ok', false, 'code', 'active_contract_required');
  end if;
  select count(distinct acceptance.user_id)::integer into v_acceptances
    from public.job_contract_acceptances acceptance
   where acceptance.contract_id = v_contract.id
     and acceptance.contract_version_id = v_version.id
     and acceptance.content_hash = v_version.content_hash
     and acceptance.affirmative_checkbox
     and ((acceptance.user_id = v_assignment.teen_user_id and acceptance.party_role = 'teen')
       or (acceptance.user_id = v_assignment.adult_user_id and acceptance.party_role = 'adult'));
  if v_acceptances <> 2 then
    return jsonb_build_object('ok', false, 'code', 'current_contract_acceptance_required');
  end if;

  select agreement.* into v_safety from public.job_safety_agreements agreement
   where agreement.application_id = p_application_id
     and agreement.teen_id = v_assignment.teen_user_id
     and agreement.adult_id = v_assignment.adult_user_id;
  if not found or v_safety.status <> 'confirmed'
     or v_safety.teen_confirmed_version <> v_safety.agreement_version
     or v_safety.adult_confirmed_version <> v_safety.agreement_version then
    return jsonb_build_object('ok', false, 'code', 'mutual_safety_agreement_required');
  end if;
  v_safety_terms := private.job_safety_terms(p_application_id);
  if v_safety_terms is null
     or v_safety.material_terms_hash <> encode(extensions.digest(v_safety.terms_snapshot::text, 'sha256'), 'hex')
     or v_safety.material_terms_hash <> encode(extensions.digest(v_safety_terms::text, 'sha256'), 'hex') then
    return jsonb_build_object('ok', false, 'code', 'safety_agreement_version_changed');
  end if;
  if not exists (
    select 1 from public.job_safety_plans plan
     where plan.application_id = p_application_id
       and plan.checkin_cadence_minutes between 15 and 240
       and (plan.expected_people is not null or v_job.remote_allowed)
  ) then
    return jsonb_build_object('ok', false, 'code', 'safety_plan_required');
  end if;
  if exists (
    select 1 from public.safety_reports report
     where (report.application_id = p_application_id or report.job_id = v_job.id)
       and report.status not in ('resolved', 'dismissed', 'closed')
  ) then
    return jsonb_build_object('ok', false, 'code', 'active_safety_incident_blocks_start');
  end if;
  if exists (
    select 1 from public.disputes dispute
     where dispute.assignment_id = v_assignment.id
       and dispute.status in ('open', 'investigating', 'awaiting_evidence')
  ) then
    return jsonb_build_object('ok', false, 'code', 'active_dispute_blocks_execution');
  end if;

  if p_operation = 'start' then
    v_start_at := coalesce(v_version.start_window, v_job.starts_at);
    if v_start_at is null then
      return jsonb_build_object('ok', false, 'code', 'start_window_required');
    end if;
    if now() < v_start_at - interval '2 hours'
       or now() > v_start_at + interval '4 hours' then
      return jsonb_build_object('ok', false, 'code', 'outside_start_window');
    end if;
    v_runtime := public.get_runtime_feature_status();
    if coalesce((v_runtime->>'payments_disabled')::boolean, true) then
      return jsonb_build_object('ok', false, 'code', 'confirmed_job_funding_required');
    end if;
    select exists (
      select 1 from private.stripe_payment_intents payment
       where payment.assignment_id = v_assignment.id
         and payment.environment = 'live'
         and payment.status in ('succeeded', 'authorized')
    ) into v_funded;
    if not v_funded then
      return jsonb_build_object('ok', false, 'code', 'confirmed_job_funding_required');
    end if;
  end if;

  return jsonb_build_object(
    'ok', true,
    'application_id', p_application_id,
    'assignment_id', v_assignment.id,
    'job_id', v_job.id,
    'teen_id', v_assignment.teen_user_id,
    'adult_id', v_assignment.adult_user_id,
    'contract_id', v_contract.id,
    'contract_version_id', v_version.id,
    'contract_content_hash', v_version.content_hash,
    'safety_agreement_version', v_safety.agreement_version,
    'start_window', coalesce(v_version.start_window, v_job.starts_at)
  );
end;
$$;


--
-- Name: job_safety_terms(uuid); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.job_safety_terms(p_application_id uuid) RETURNS jsonb
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
  select jsonb_build_object(
    'job_id', job.id,
    'job_title', job.title,
    'scope', coalesce(nullif(job.summary, ''), job.description),
    'approximate_area', jsonb_build_object(
      'city', job.city,
      'region', job.region,
      'remote', job.remote_allowed
    ),
    'private_location_version', coalesce(location.location_version, 0),
    'private_location_available', location.job_id is not null,
    'who_will_be_present', coalesce(
      nullif(plan.expected_people, ''),
      case when job.adult_supervision_present
        then 'The job poster reports adult supervision will be present.'
        else 'Presence details must be agreed before the job starts.'
      end
    ),
    'physical_requirements', to_jsonb(job.physical_requirements),
    'hazards', job.safety_notes,
    'equipment', jsonb_build_object(
      'provided', job.equipment_provided,
      'worker_brings', job.equipment_worker_brings
    ),
    'payment', jsonb_build_object(
      'amount_cents', job.pay_amount_cents,
      'type', job.payment_type,
      'method_preference', job.payment_method,
      'timing', job.payment_timing
    ),
    'proof_expected', job.proof_expected,
    'safety_plan', jsonb_build_object(
      'public_or_visible_meeting', plan.public_or_visible_meeting,
      'daylight_preferred', plan.daylight_preferred,
      'transportation_plan', plan.transportation_plan,
      'checkin_cadence_minutes', plan.checkin_cadence_minutes
    ),
    'contract', (
      select jsonb_build_object(
        'contract_id', contract.id,
        'version_id', coalesce(contract.active_version_id, latest.id),
        'content_hash', latest.content_hash,
        'status', contract.status
      )
      from public.job_contracts contract
      left join lateral (
        select version.id, version.content_hash
        from public.job_contract_versions version
        where version.contract_id = contract.id
        order by version.version_number desc
        limit 1
      ) latest on true
      where contract.application_id = application.id
    ),
    'exact_location_policy',
      'The exact address stays private until the authorized job stage.',
    'communication_boundaries', jsonb_build_array(
      'Keep job communication in MORT.',
      'No harassment, sexual behavior, threats, weapons, alcohol, or drugs.',
      'No forced off-platform contact or unapproved work changes.'
    ),
    'right_to_leave', true,
    'verification_not_safety_guarantee', true
  )
  from public.job_applications application
  join public.jobs job on job.id = application.job_id
  left join public.job_safety_plans plan on plan.application_id = application.id
  left join private.job_private_locations location on location.job_id = job.id
  where application.id = p_application_id;
$$;


--
-- Name: message_thread_summary(uuid, uuid); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.message_thread_summary(p_conversation_id uuid, p_user_id uuid) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_conversation public.conversations%rowtype;
  v_counterparty public.profiles%rowtype;
  v_teen_id uuid;
  v_adult_id uuid;
  v_guardian_id uuid;
  v_job_title text;
  v_last_message text;
  v_last_message_at timestamptz;
  v_unread_count integer;
begin
  if p_user_id is null or p_user_id <> (select auth.uid()) then
    return null;
  end if;

  select conversation.* into v_conversation
  from public.conversations as conversation
  where conversation.id = p_conversation_id
    and private.can_access_conversation(conversation.id);
  if not found then return null; end if;

  select profile.* into v_counterparty
  from public.conversation_members as member
  join public.profiles as profile on profile.id = member.user_id
  where member.conversation_id = p_conversation_id
    and member.user_id <> p_user_id
  order by member.joined_at, member.user_id
  limit 1;

  select profile.id into v_teen_id
  from public.conversation_members as member
  join public.profiles as profile on profile.id = member.user_id
  where member.conversation_id = p_conversation_id
    and profile.role = 'teen'::public.mort_role
  order by member.joined_at, member.user_id
  limit 1;

  select profile.id into v_adult_id
  from public.conversation_members as member
  join public.profiles as profile on profile.id = member.user_id
  where member.conversation_id = p_conversation_id
    and profile.role = 'adult'::public.mort_role
  order by member.joined_at, member.user_id
  limit 1;

  select profile.id into v_guardian_id
  from public.conversation_members as member
  join public.profiles as profile on profile.id = member.user_id
  where member.conversation_id = p_conversation_id
    and profile.role = 'guardian'::public.mort_role
  order by member.joined_at, member.user_id
  limit 1;

  select job.title into v_job_title
  from public.jobs as job
  where job.id = v_conversation.job_id;

  select left(message.body, 160), message.created_at
    into v_last_message, v_last_message_at
  from public.messages as message
  where message.conversation_id = p_conversation_id
    and message.deleted_at is null
    and message.moderation_status = 'approved'
  order by message.created_at desc, message.id desc
  limit 1;

  select count(*)::integer into v_unread_count
  from public.messages as message
  join public.conversation_members as member
    on member.conversation_id = message.conversation_id
   and member.user_id = p_user_id
  where message.conversation_id = p_conversation_id
    and message.sender_id <> p_user_id
    and message.deleted_at is null
    and message.moderation_status = 'approved'
    and (member.last_read_at is null or message.created_at > member.last_read_at);

  return jsonb_build_object(
    'id', v_conversation.id,
    'job_id', v_conversation.job_id,
    'application_id', null,
    'teen_id', v_teen_id,
    'adult_id', v_adult_id,
    'guardian_id', v_guardian_id,
    'lifecycle_status', v_conversation.status,
    'updated_at', v_conversation.updated_at,
    'unread_count', coalesce(v_unread_count, 0),
    'job_title', v_job_title,
    'counterparty_id', v_counterparty.id,
    'counterparty_display_name', v_counterparty.display_name,
    'counterparty_role', v_counterparty.role::text,
    'counterparty_verification_status', v_counterparty.verification_status,
    'last_message_preview', v_last_message,
    'last_message_at', v_last_message_at
  );
end;
$$;


--
-- Name: mort_age_years(date); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.mort_age_years(p_date_of_birth date) RETURNS integer
    LANGUAGE sql STABLE
    SET search_path TO ''
    AS $$
  select case when p_date_of_birth is null then null
    else extract(year from age(current_date, p_date_of_birth))::integer
  end;
$$;


--
-- Name: mort_legal_age_band(date); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.mort_legal_age_band(p_date_of_birth date) RETURNS text
    LANGUAGE sql STABLE
    SET search_path TO ''
    AS $$
  select case
    when p_date_of_birth is null then 'unknown'
    when age(current_date, p_date_of_birth) < interval '13 years' then 'ineligible'
    when age(current_date, p_date_of_birth) < interval '16 years' then 'teen_13_15'
    when age(current_date, p_date_of_birth) < interval '18 years' then 'teen_16_17'
    else 'adult_18_plus'
  end;
$$;


--
-- Name: mort_user_has_current_legal_acceptances(uuid); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.mort_user_has_current_legal_acceptances(p_user_id uuid) RETURNS boolean
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_actor public.profiles%rowtype;
  v_age_band text;
  v_required_count integer;
  v_missing_count integer;
begin
  select * into v_actor from public.profiles where id = p_user_id;
  if v_actor.id is null or v_actor.role is null or v_actor.role = 'pending' then
    return false;
  end if;
  v_age_band := private.mort_legal_age_band(v_actor.date_of_birth);
  if v_age_band in ('unknown', 'ineligible') then
    return false;
  end if;

  select count(*) into v_required_count
  from public.legal_role_requirements requirement
  join public.legal_documents document
    on document.id = requirement.document_id
   and document.publication_status = 'published'
  where requirement.role = v_actor.role
    and requirement.required
    and requirement.age_band in ('all', v_age_band);
  if v_required_count = 0 then
    return false;
  end if;

  select count(*) into v_missing_count
  from public.legal_role_requirements requirement
  join public.legal_documents document
    on document.id = requirement.document_id
   and document.publication_status = 'published'
  where requirement.role = v_actor.role
    and requirement.required
    and requirement.age_band in ('all', v_age_band)
    and not exists (
      select 1
      from public.legal_document_versions version
      join public.legal_acceptances acceptance
        on acceptance.document_id = document.id
       and acceptance.document_version_id = version.id
       and acceptance.content_hash = version.content_hash
       and acceptance.user_id = v_actor.id
       and acceptance.active
      where version.document_id = document.id
        and version.publication_status = 'published'
        and version.effective_at is not null
        and version.effective_at <= now()
        and version.id = (
          select current_version.id
          from public.legal_document_versions current_version
          where current_version.document_id = document.id
            and current_version.publication_status = 'published'
            and current_version.effective_at is not null
            and current_version.effective_at <= now()
          order by current_version.effective_at desc, current_version.created_at desc
          limit 1
        )
    );
  return v_missing_count = 0;
end;
$$;


--
-- Name: notify_guardians_of_safety_ping(); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.notify_guardians_of_safety_ping() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin
  insert into public.notifications (
    user_id, notification_type, title, body, data
  )
  select
    link.guardian_user_id,
    'safety_ping',
    case when new.immediate_danger then 'Urgent Safety Ping' else 'Safety Ping' end,
    'A linked teen sent a Safety Ping. Open MORT to review it.',
    jsonb_build_object(
      'safety_ping_id', new.id,
      'teen_id', new.teen_id,
      'immediate_danger', new.immediate_danger
    )
  from public.guardian_links link
  left join public.guardian_preferences guardian_preferences
    on guardian_preferences.link_id = link.id
  left join public.notification_preferences notification_preferences
    on notification_preferences.user_id = link.guardian_user_id
  where link.teen_user_id = new.teen_id
    and link.guardian_user_id is not null
    and link.status = 'active'
    and coalesce(guardian_preferences.safety_ping_alerts, true)
    and coalesce(notification_preferences.safety_alerts, true);
  return new;
end;
$$;


--
-- Name: refresh_job_safety_agreement(uuid); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.refresh_job_safety_agreement(p_application_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_terms jsonb;
begin
  v_terms := private.job_safety_terms(p_application_id);
  if v_terms is null then
    return;
  end if;

  update public.job_safety_agreements
  set agreement_version = agreement_version + 1,
      terms_snapshot = v_terms,
      material_terms_hash = encode(extensions.digest(v_terms::text, 'sha256'), 'hex'),
      status = 'reconfirmation_required',
      teen_confirmed_at = null,
      adult_confirmed_at = null,
      teen_confirmed_version = null,
      adult_confirmed_version = null,
      updated_at = now()
  where application_id = p_application_id;
end;
$$;


--
-- Name: refresh_safety_agreement_after_contract_change(); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.refresh_safety_agreement_after_contract_change() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin
  if new.active_version_id is distinct from old.active_version_id
     and new.active_version_id is not null then
    perform private.refresh_job_safety_agreement(new.application_id);
  end if;
  return new;
end;
$$;


--
-- Name: report_finish_pin_unavailable_internal(uuid, timestamp with time zone, timestamp with time zone, text, text, uuid); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.report_finish_pin_unavailable_internal(p_application_id uuid, p_actual_start_at timestamp with time zone, p_actual_finish_at timestamp with time zone, p_work_completed text, p_statement text, p_client_request_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_user_id uuid := auth.uid();
  v_assignment public.job_assignments%rowtype;
  v_dispute public.disputes%rowtype;
  v_existing private.job_execution_events%rowtype;
  v_description text;
begin
  if v_user_id is null or not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;
  if p_client_request_id is null then
    return jsonb_build_object('ok', false, 'code', 'request_id_required');
  end if;
  select assignment.* into v_assignment from public.job_assignments assignment
   where assignment.application_id = p_application_id for update;
  if not found or v_assignment.teen_user_id <> v_user_id then
    return jsonb_build_object('ok', false, 'code', 'assigned_worker_required');
  end if;
  select event.* into v_existing from private.job_execution_events event
   where event.application_id = p_application_id and event.actor_id = v_user_id
     and event.event_type = 'finish_pin_unavailable_reported'
     and event.request_id = p_client_request_id;
  if found then
    return jsonb_build_object('ok', true, 'replayed', true,
      'dispute_id', v_existing.safe_metadata->>'dispute_id', 'money_moved', false);
  end if;
  if v_assignment.status <> 'in_progress' then
    return jsonb_build_object('ok', false, 'code', 'in_progress_start_confirmation_required');
  end if;
  if p_actual_start_at is null or p_actual_finish_at is null
     or p_actual_start_at < now() - interval '7 days'
     or p_actual_finish_at < p_actual_start_at
     or p_actual_finish_at > now() + interval '5 minutes' then
    return jsonb_build_object('ok', false, 'code', 'valid_work_times_required');
  end if;
  if char_length(btrim(coalesce(p_work_completed, ''))) not between 10 and 2000
     or char_length(btrim(coalesce(p_statement, ''))) not between 10 and 2000 then
    return jsonb_build_object('ok', false, 'code', 'factual_completion_statement_required');
  end if;
  v_description := 'Finish PIN unavailable. Actual start: ' || p_actual_start_at::text
    || E'\nActual finish: ' || p_actual_finish_at::text
    || E'\nWork completed: ' || btrim(p_work_completed)
    || E'\nStatement: ' || btrim(p_statement);
  insert into public.disputes(assignment_id, opened_by, category, description, status)
  values (v_assignment.id, v_user_id, 'other', v_description, 'open')
  returning * into v_dispute;
  update public.job_assignments set status = 'disputed' where id = v_assignment.id;
  update public.jobs set status = 'paused', updated_at = now()
   where id = v_assignment.job_id and status = 'in_progress';
  update public.job_contracts set status = 'disputed'
   where application_id = p_application_id and status = 'active';
  update private.job_execution_sessions set execution_state = 'disputed',
    finish_pin_hash = null, finish_pin_expires_at = null, updated_at = now()
   where assignment_id = v_assignment.id;
  insert into private.job_execution_events(assignment_id, application_id, actor_id,
    event_type, from_state, to_state, request_id, safe_metadata)
  values (v_assignment.id, p_application_id, v_user_id,
    'finish_pin_unavailable_reported', 'in_progress', 'disputed', p_client_request_id,
    jsonb_build_object('dispute_id', v_dispute.id));
  return jsonb_build_object('ok', true, 'replayed', false,
    'dispute_id', v_dispute.id, 'money_moved', false, 'human_review_required', true);
end;
$$;


--
-- Name: report_possible_teen_abandonment_internal(uuid, text, uuid); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.report_possible_teen_abandonment_internal(p_application_id uuid, p_statement text, p_client_request_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_user_id uuid := auth.uid();
  v_assignment public.job_assignments%rowtype;
  v_dispute public.disputes%rowtype;
  v_existing private.job_execution_events%rowtype;
begin
  if v_user_id is null or not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;
  if p_client_request_id is null then
    return jsonb_build_object('ok', false, 'code', 'request_id_required');
  end if;
  select assignment.* into v_assignment from public.job_assignments assignment
   where assignment.application_id = p_application_id for update;
  if not found or v_assignment.adult_user_id <> v_user_id then
    return jsonb_build_object('ok', false, 'code', 'job_poster_required');
  end if;
  select event.* into v_existing from private.job_execution_events event
   where event.application_id = p_application_id and event.actor_id = v_user_id
     and event.event_type = 'teen_abandonment_reported'
     and event.request_id = p_client_request_id;
  if found then
    return jsonb_build_object('ok', true, 'replayed', true,
      'dispute_id', v_existing.safe_metadata->>'dispute_id',
      'cooldown_applied', false, 'money_moved', false);
  end if;
  if v_assignment.status <> 'in_progress' then
    return jsonb_build_object('ok', false, 'code', 'in_progress_start_confirmation_required');
  end if;
  if char_length(btrim(coalesce(p_statement, ''))) not between 10 and 2000 then
    return jsonb_build_object('ok', false, 'code', 'abandonment_statement_required');
  end if;
  insert into public.disputes(assignment_id, opened_by, category, description, status)
  values (v_assignment.id, v_user_id, 'no_show',
    'Allegation only; no finding or cooldown has been applied. ' || btrim(p_statement), 'open')
  returning * into v_dispute;
  update public.job_assignments set status = 'disputed' where id = v_assignment.id;
  update public.jobs set status = 'paused', updated_at = now()
   where id = v_assignment.job_id and status = 'in_progress';
  update public.job_contracts set status = 'disputed'
   where application_id = p_application_id and status = 'active';
  update private.job_execution_sessions set execution_state = 'disputed',
    finish_pin_hash = null, finish_pin_expires_at = null, updated_at = now()
   where assignment_id = v_assignment.id;
  insert into private.job_execution_events(assignment_id, application_id, actor_id,
    event_type, from_state, to_state, request_id, safe_metadata)
  values (v_assignment.id, p_application_id, v_user_id,
    'teen_abandonment_reported', 'in_progress', 'disputed', p_client_request_id,
    jsonb_build_object('dispute_id', v_dispute.id, 'allegation_only', true));
  return jsonb_build_object('ok', true, 'replayed', false,
    'dispute_id', v_dispute.id, 'cooldown_applied', false,
    'money_moved', false, 'human_review_required', true);
end;
$$;


--
-- Name: request_adult_job_cancellation_internal(uuid, text, uuid); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.request_adult_job_cancellation_internal(p_application_id uuid, p_reason text, p_client_request_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_user_id uuid := auth.uid();
  v_assignment public.job_assignments%rowtype;
  v_dispute public.disputes%rowtype;
  v_existing private.job_execution_events%rowtype;
begin
  if v_user_id is null or not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;
  if p_client_request_id is null then
    return jsonb_build_object('ok', false, 'code', 'request_id_required');
  end if;
  select assignment.* into v_assignment from public.job_assignments assignment
   where assignment.application_id = p_application_id for update;
  if not found or v_assignment.adult_user_id <> v_user_id then
    return jsonb_build_object('ok', false, 'code', 'job_poster_required');
  end if;
  select event.* into v_existing from private.job_execution_events event
   where event.application_id = p_application_id and event.actor_id = v_user_id
     and event.event_type = 'adult_cancellation_requested'
     and event.request_id = p_client_request_id;
  if found then
    return jsonb_build_object('ok', true, 'replayed', true,
      'dispute_id', v_existing.safe_metadata->>'dispute_id', 'money_moved', false);
  end if;
  if v_assignment.status not in ('accepted', 'in_progress') then
    return jsonb_build_object('ok', false, 'code', 'job_not_cancellable');
  end if;
  if char_length(btrim(coalesce(p_reason, ''))) not between 3 and 2000 then
    return jsonb_build_object('ok', false, 'code', 'cancellation_reason_required');
  end if;
  insert into public.disputes(assignment_id, opened_by, category, description, status)
  values (v_assignment.id, v_user_id, 'other',
    'Adult requested cancellation. Reason: ' || btrim(p_reason), 'open')
  returning * into v_dispute;
  update public.job_assignments set status = 'disputed' where id = v_assignment.id;
  update public.jobs set status = 'paused', updated_at = now()
   where id = v_assignment.job_id and status in ('filled', 'in_progress');
  update public.job_contracts set status = 'disputed'
   where application_id = p_application_id and status = 'active';
  update private.job_execution_sessions set execution_state = 'disputed',
    start_pin_hash = null, finish_pin_hash = null, updated_at = now()
   where assignment_id = v_assignment.id;
  insert into private.job_execution_events(assignment_id, application_id, actor_id,
    event_type, from_state, to_state, request_id, safe_metadata)
  values (v_assignment.id, p_application_id, v_user_id,
    'adult_cancellation_requested', v_assignment.status, 'disputed', p_client_request_id,
    jsonb_build_object('dispute_id', v_dispute.id));
  return jsonb_build_object('ok', true, 'replayed', false,
    'dispute_id', v_dispute.id, 'money_moved', false, 'human_review_required', true);
end;
$$;


--
-- Name: require_stripe_service_role(); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.require_stripe_service_role() RETURNS void
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'stripe_service_role_required' using errcode = '42501';
  end if;
end;
$$;


--
-- Name: respond_to_teen_abandonment_internal(uuid, text, boolean, uuid); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.respond_to_teen_abandonment_internal(p_application_id uuid, p_statement text, p_safety_related boolean, p_client_request_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_user_id uuid := auth.uid();
  v_assignment public.job_assignments%rowtype;
  v_dispute public.disputes%rowtype;
  v_response public.job_execution_review_responses%rowtype;
begin
  if v_user_id is null or not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;
  if p_client_request_id is null then
    return jsonb_build_object('ok', false, 'code', 'request_id_required');
  end if;
  select assignment.* into v_assignment from public.job_assignments assignment
   where assignment.application_id = p_application_id for update;
  if not found or v_assignment.teen_user_id <> v_user_id then
    return jsonb_build_object('ok', false, 'code', 'assigned_worker_required');
  end if;
  select response.* into v_response from public.job_execution_review_responses response
   where response.assignment_id = v_assignment.id
     and response.responded_by = v_user_id
     and response.client_request_id = p_client_request_id;
  if found then
    return jsonb_build_object('ok', true, 'replayed', true,
      'dispute_id', v_response.dispute_id,
      'safety_route_recommended', v_response.safety_related,
      'cooldown_applied', false, 'money_moved', false);
  end if;
  if char_length(btrim(coalesce(p_statement, ''))) not between 10 and 2000 then
    return jsonb_build_object('ok', false, 'code', 'abandonment_statement_required');
  end if;
  if p_safety_related is null then
    return jsonb_build_object('ok', false, 'code', 'safety_response_required');
  end if;
  select dispute.* into v_dispute from public.disputes dispute
   where dispute.assignment_id = v_assignment.id
     and dispute.opened_by = v_assignment.adult_user_id
     and dispute.category = 'no_show'
     and dispute.status in ('open', 'investigating', 'awaiting_evidence')
   order by dispute.created_at desc limit 1 for update;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'adult_report_required');
  end if;
  insert into public.job_execution_review_responses(
    dispute_id, assignment_id, responded_by, client_request_id, statement, safety_related
  ) values (
    v_dispute.id, v_assignment.id, v_user_id, p_client_request_id,
    btrim(p_statement), p_safety_related
  ) returning * into v_response;
  insert into private.job_execution_events(assignment_id, application_id, actor_id,
    event_type, from_state, to_state, request_id,
    safe_metadata)
  values (v_assignment.id, p_application_id, v_user_id,
    'teen_abandonment_response', 'disputed', 'disputed', p_client_request_id,
    jsonb_build_object('dispute_id', v_dispute.id, 'safety_related', p_safety_related))
  on conflict do nothing;
  return jsonb_build_object('ok', true, 'replayed', false,
    'dispute_id', v_dispute.id,
    'safety_route_recommended', p_safety_related,
    'cooldown_applied', false, 'money_moved', false);
end;
$$;


--
-- Name: reveal_reciprocal_job_reviews(); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.reveal_reciprocal_job_reviews() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin
  if exists (
    select 1
    from public.reviews as other_review
    where other_review.application_id = new.application_id
      and other_review.reviewer_id = new.subject_id
      and other_review.subject_id = new.reviewer_id
  ) then
    update public.reviews
    set revealed_at = coalesce(revealed_at, now())
    where application_id = new.application_id
      and (reviewer_id = new.reviewer_id or reviewer_id = new.subject_id);
  end if;

  return new;
end;
$$;


--
-- Name: review_application_proof_internal(uuid, text, text); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.review_application_proof_internal(p_proof_id uuid, p_action text, p_note text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_proof public.proof_uploads%rowtype;
  v_assignment public.job_assignments%rowtype;
  v_note text := nullif(btrim(p_note), '');
begin
  if auth.uid() is null then return jsonb_build_object('ok',false,'code','authentication_required'); end if;
  if p_action is null or p_action not in ('approved','resubmission_requested','rejected') then return jsonb_build_object('ok',false,'code','invalid_proof_review_action'); end if;
  if p_action<>'approved' and (v_note is null or char_length(v_note)<10) then return jsonb_build_object('ok',false,'code','proof_review_note_required'); end if;
  if v_note is not null and char_length(v_note)>500 then return jsonb_build_object('ok',false,'code','proof_review_note_too_long'); end if;

  select proof.* into v_proof from public.proof_uploads proof where proof.id=p_proof_id;
  if not found then return jsonb_build_object('ok',false,'code','proof_upload_not_found'); end if;
  select assignment.* into v_assignment from public.job_assignments assignment
   where assignment.id=v_proof.assignment_id for update;
  if not found or v_assignment.adult_user_id<>auth.uid() then return jsonb_build_object('ok',false,'code','job_participant_required'); end if;
  select proof.* into v_proof from public.proof_uploads proof
   where proof.id=p_proof_id and proof.assignment_id=v_assignment.id for update;
  if not found then return jsonb_build_object('ok',false,'code','proof_upload_not_found'); end if;
  if v_proof.status<>'submitted' then return jsonb_build_object('ok',false,'code','proof_not_awaiting_review'); end if;
  if v_assignment.status<>'awaiting_confirmation' then return jsonb_build_object('ok',false,'code','job_not_awaiting_review'); end if;

  update public.proof_uploads set status=p_action,reviewed_by=auth.uid(),review_note=v_note,reviewed_at=now(),updated_at=now()
   where id=p_proof_id returning * into v_proof;
  return jsonb_build_object('ok',true,'proof',to_jsonb(v_proof));
end;
$$;


--
-- Name: save_job_safety_plan_internal(uuid, text, boolean, boolean, text, integer); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.save_job_safety_plan_internal(p_application_id uuid, p_expected_people text, p_public_or_visible_meeting boolean, p_daylight_preferred boolean, p_transportation_plan text, p_checkin_cadence_minutes integer) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_plan public.job_safety_plans%rowtype;
  v_agreement public.job_safety_agreements%rowtype;
  v_user uuid := auth.uid();
begin
  if v_user is null or not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;
  if not private.is_job_safety_participant(p_application_id, v_user) then
    return jsonb_build_object('ok', false, 'code', 'job_participant_required');
  end if;
  if not exists (
    select 1
    from public.job_applications application
    join public.job_assignments assignment
      on assignment.application_id = application.id
     and assignment.job_id = application.job_id
    where application.id = p_application_id
      and application.status = 'accepted'::public.mort_application_status
      and assignment.status = 'accepted'
  ) then
    return jsonb_build_object('ok', false, 'code', 'accepted_job_required');
  end if;
  if char_length(coalesce(p_expected_people, '')) > 500
     or char_length(coalesce(p_transportation_plan, '')) > 1000
     or p_checkin_cadence_minutes is null
     or p_checkin_cadence_minutes not between 15 and 240
     or p_public_or_visible_meeting is null
     or p_daylight_preferred is null then
    return jsonb_build_object('ok', false, 'code', 'invalid_safety_plan');
  end if;

  update public.job_safety_plans
  set expected_people = nullif(left(btrim(coalesce(p_expected_people, '')), 500), ''),
      public_or_visible_meeting = p_public_or_visible_meeting,
      daylight_preferred = p_daylight_preferred,
      transportation_plan = nullif(left(btrim(coalesce(p_transportation_plan, '')), 1000), ''),
      checkin_cadence_minutes = p_checkin_cadence_minutes,
      teen_updated_at = case when teen_id = v_user then now() else teen_updated_at end,
      adult_updated_at = case when adult_id = v_user then now() else adult_updated_at end,
      updated_at = now()
  where application_id = p_application_id
  returning * into v_plan;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'safety_plan_not_found');
  end if;

  perform private.refresh_job_safety_agreement(p_application_id);
  select * into v_agreement from public.job_safety_agreements
  where application_id = p_application_id;

  return jsonb_build_object(
    'ok', true,
    'plan', to_jsonb(v_plan),
    'agreement_version', v_agreement.agreement_version,
    'agreement_status', v_agreement.status
  );
end;
$$;


--
-- Name: submit_application_proof_internal(uuid, uuid, text, text); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.submit_application_proof_internal(p_proof_id uuid, p_application_id uuid, p_storage_path text, p_note text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_assignment public.job_assignments%rowtype;
  v_proof public.proof_uploads%rowtype;
  v_note text := nullif(btrim(p_note), '');
begin
  if auth.uid() is null then return jsonb_build_object('ok',false,'code','authentication_required'); end if;
  select assignment.* into v_assignment from public.job_assignments assignment
   where assignment.application_id=p_application_id for update;
  if not found or v_assignment.teen_user_id <> auth.uid() then return jsonb_build_object('ok',false,'code','job_participant_required'); end if;
  if v_assignment.status not in ('in_progress','awaiting_confirmation') then return jsonb_build_object('ok',false,'code','job_not_ready_for_proof'); end if;
  select proof.* into v_proof from public.proof_uploads proof
   where proof.id=p_proof_id and proof.application_id=p_application_id for update;
  if not found or v_proof.uploaded_by <> auth.uid() or v_proof.storage_path <> p_storage_path then
    return jsonb_build_object('ok',false,'code','proof_upload_not_found');
  end if;
  if v_proof.status='submitted' then return jsonb_build_object('ok',true,'proof',to_jsonb(v_proof)); end if;
  if v_proof.status <> 'uploading' then return jsonb_build_object('ok',false,'code','proof_upload_not_pending'); end if;
  if v_note is not null and char_length(v_note)>500 then return jsonb_build_object('ok',false,'code','proof_note_too_long'); end if;
  if not exists (select 1 from storage.objects object
                  where object.bucket_id='proof-uploads' and object.name=p_storage_path) then
    return jsonb_build_object('ok',false,'code','proof_file_missing');
  end if;

  update public.proof_uploads set status='submitted', note=v_note, updated_at=now()
   where id=p_proof_id returning * into v_proof;
  update public.job_assignments set status='awaiting_confirmation', completed_by_teen_at=coalesce(completed_by_teen_at,now())
   where id=v_assignment.id and status in ('in_progress','awaiting_confirmation');
  update public.jobs set status='under_review', updated_at=now()
   where id=v_assignment.job_id and status in ('in_progress','under_review');
  return jsonb_build_object('ok',true,'proof',to_jsonb(v_proof));
end;
$$;


--
-- Name: submit_safety_cancellation_internal(uuid, text, text); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.submit_safety_cancellation_internal(p_application_id uuid, p_reason text, p_details text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_user_id uuid := auth.uid();
  v_assignment public.job_assignments%rowtype;
  v_application public.job_applications%rowtype;
  v_job public.jobs%rowtype;
  v_existing public.job_safety_cancellations%rowtype;
  v_cancellation public.job_safety_cancellations%rowtype;
  v_reason text := lower(btrim(coalesce(p_reason, '')));
  v_details text := btrim(coalesce(p_details, ''));
  v_target_user_id uuid;
  v_report jsonb;
  v_category text;
  v_severity text;
  v_immediate_danger boolean;
begin
  if v_user_id is null or not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;
  if p_application_id is null
     or not private.is_job_safety_participant(p_application_id, v_user_id) then
    return jsonb_build_object('ok', false, 'code', 'job_participant_required');
  end if;
  if v_reason not in (
    'unsafe_condition', 'person_mismatch', 'harassment',
    'location_changed', 'scope_changed', 'emergency'
  ) then
    return jsonb_build_object('ok', false, 'code', 'invalid_cancellation_reason');
  end if;
  if char_length(v_details) not between 10 and 3000 then
    return jsonb_build_object('ok', false, 'code', 'safety_cancellation_details_required');
  end if;

  select assignment.* into v_assignment
  from public.job_assignments as assignment
  where assignment.application_id = p_application_id
    and v_user_id in (assignment.teen_user_id, assignment.adult_user_id)
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'job_participant_required');
  end if;

  select application.* into v_application
  from public.job_applications as application
  where application.id = v_assignment.application_id
    and application.job_id = v_assignment.job_id
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'accepted_job_required');
  end if;

  select job.* into v_job
  from public.jobs as job
  where job.id = v_assignment.job_id
    and job.poster_id = v_assignment.adult_user_id
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'accepted_job_required');
  end if;
  if v_application.status <> 'accepted'::public.mort_application_status
     or v_assignment.status not in ('accepted', 'in_progress')
     or v_job.status not in ('filled', 'in_progress') then
    return jsonb_build_object('ok', false, 'code', 'active_job_required');
  end if;

  select cancellation.* into v_existing
  from public.job_safety_cancellations as cancellation
  where cancellation.application_id = p_application_id
    and cancellation.actor_id = v_user_id;
  if found then
    if v_existing.reason = v_reason and v_existing.details = v_details then
      return jsonb_build_object(
        'ok', true,
        'replayed', true,
        'cancellation_id', v_existing.id,
        'safety_report_id', v_existing.safety_report_id,
        'safety_related', true,
        'reputation_penalty_applied', false
      );
    end if;
    return jsonb_build_object('ok', false, 'code', 'safety_cancellation_already_submitted');
  end if;

  v_target_user_id := case
    when v_user_id = v_assignment.teen_user_id then v_assignment.adult_user_id
    else v_assignment.teen_user_id
  end;
  v_category := case
    when v_reason = 'harassment' then 'harassment'
    else 'unsafe_meeting'
  end;
  v_immediate_danger := v_reason = 'emergency';
  v_severity := case
    when v_immediate_danger then 'critical'
    when v_reason in ('person_mismatch', 'harassment') then 'high'
    else 'normal'
  end;

  v_report := public.submit_safety_report_v2(
    v_target_user_id,
    v_job.id,
    null,
    null,
    p_application_id,
    v_category,
    v_severity,
    v_immediate_danger,
    v_details,
    now(),
    v_job.location_type,
    'End the job safely and prevent retaliation.',
    true,
    gen_random_uuid()
  );
  if coalesce((v_report->>'ok')::boolean, false) is not true then
    return jsonb_build_object(
      'ok', false,
      'code', coalesce(v_report->>'code', 'safety_report_failed')
    );
  end if;

  insert into public.job_safety_cancellations (
    application_id, assignment_id, job_id, actor_id, reported_user_id,
    reason, details, safety_report_id
  ) values (
    p_application_id, v_assignment.id, v_job.id, v_user_id, v_target_user_id,
    v_reason, left(v_details, 3000), nullif(v_report->>'report_id', '')::uuid
  ) returning * into v_cancellation;

  -- Stop job execution while the cancellation is reviewed. Keep the accepted
  -- application row in its current enum state; the live model uses assignment
  -- status for execution lifecycle.
  update public.job_assignments
  set status = 'disputed', closed_at = coalesce(closed_at, now())
  where id = v_assignment.id;
  update public.jobs
  set status = 'paused', applications_open = false, updated_at = now()
  where id = v_job.id;

  return jsonb_build_object(
    'ok', true,
    'replayed', false,
    'cancellation_id', v_cancellation.id,
    'safety_report_id', v_cancellation.safety_report_id,
    'safety_related', true,
    'reputation_penalty_applied', false
  );
end;
$$;


--
-- Name: touch_updated_at(); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.touch_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO ''
    AS $$ begin new.updated_at = now(); return new; end $$;


--
-- Name: abort_application_proof_upload(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.abort_application_proof_upload(p_proof_id uuid, p_application_id uuid) RETURNS jsonb
    LANGUAGE sql
    SET search_path TO ''
    AS $_$
  select private.abort_application_proof_upload_internal($1,$2)
$_$;


--
-- Name: accept_guardian_invite(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.accept_guardian_invite(p_invite_code text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $_$
declare
  guardian_id uuid := auth.uid();
  guardian_profile public.profiles%rowtype;
  auth_email text;
  invite private.guardian_invite_codes%rowtype;
  link public.guardian_links%rowtype;
  code_hash text;
  window_start timestamptz := date_trunc('minute', now());
  attempts integer;
begin
  if guardian_id is null then raise exception 'authentication_required' using errcode = '42501'; end if;
  insert into private.guardian_invite_accept_limits(user_id, window_started_at, attempt_count)
  values (guardian_id, window_start, 1)
  on conflict (user_id, window_started_at) do update
  set attempt_count = private.guardian_invite_accept_limits.attempt_count + 1
  returning attempt_count into attempts;
  if attempts > 10 then raise exception 'guardian_invite_accept_rate_limit_reached' using errcode = '42501'; end if;

  select * into guardian_profile from public.profiles where id = guardian_id for update;
  if not found or guardian_profile.role <> 'guardian'::public.mort_role
    or guardian_profile.account_status <> 'active'
    or guardian_profile.date_of_birth is null
    or extract(year from age(current_date, guardian_profile.date_of_birth)) < 18 then
    raise exception 'adult_guardian_account_required' using errcode = '42501';
  end if;
  select lower(u.email) into auth_email from auth.users u where u.id = guardian_id;
  if not exists (
    select 1 from auth.users u
    where u.id = guardian_id and u.email_confirmed_at is not null
  ) then
    raise exception 'guardian_email_confirmation_required' using errcode = '42501';
  end if;
  if p_invite_code is null or p_invite_code !~* '^[a-f0-9]{64}$' then
    raise exception 'guardian_invite_invalid_or_expired' using errcode = '22023';
  end if;
  code_hash := encode(extensions.digest(convert_to(lower(p_invite_code), 'utf8'), 'sha256'), 'hex');
  select * into invite from private.guardian_invite_codes
  where code_sha256 = code_hash and consumed_at is null and expires_at > now()
  for update;
  if not found or (invite.invited_email is not null and invite.invited_email <> coalesce(auth_email, '')) then
    raise exception 'guardian_invite_invalid_or_expired' using errcode = '22023';
  end if;
  select * into link from public.guardian_links where id = invite.guardian_link_id for update;
  if not found or link.status <> 'pending' or link.guardian_user_id is not null
    or link.teen_user_id = guardian_id then
    raise exception 'guardian_invite_invalid_or_expired' using errcode = '22023';
  end if;
  if exists (select 1 from public.guardian_links active
    where active.teen_user_id = link.teen_user_id and active.status = 'active') then
    raise exception 'guardian_link_already_exists' using errcode = '23505';
  end if;
  update public.guardian_links
  set guardian_user_id = guardian_id, status = 'active', guardian_consent_at = now(), updated_at = now()
  where id = link.id;
  update private.guardian_invite_codes set consumed_at = now() where id = invite.id;
  update public.profiles set guardian_setup_status = 'linked', updated_at = now() where id = link.teen_user_id;
  return link.id;
end;
$_$;


--
-- Name: FUNCTION accept_guardian_invite(p_invite_code text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.accept_guardian_invite(p_invite_code text) IS 'Links an adult guardian only after authenticated role/age checks, optional invite-email match, and explicit guardian consent.';


--
-- Name: begin_application_proof_upload(uuid, uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.begin_application_proof_upload(p_proof_id uuid, p_application_id uuid, p_storage_path text, p_note text) RETURNS jsonb
    LANGUAGE sql
    SET search_path TO ''
    AS $_$
  select private.begin_application_proof_upload_internal($1,$2,$3,$4)
$_$;


--
-- Name: block_user_v2(uuid, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.block_user_v2(p_blocked_id uuid, p_reason text DEFAULT NULL::text, p_client_request_id uuid DEFAULT NULL::uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_user_id uuid := auth.uid();
  v_key bigint;
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_blocked_id is null or p_blocked_id = v_user_id then
    return jsonb_build_object('ok', false, 'code', 'invalid_block_target');
  end if;
  if not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;
  v_key := pg_catalog.hashtextextended(least(v_user_id, p_blocked_id)::text || ':' || greatest(v_user_id, p_blocked_id)::text, 0);
  perform pg_catalog.pg_advisory_xact_lock(v_key);
  insert into public.user_blocks(blocker_id, blocked_id, reason)
  values (v_user_id, p_blocked_id, nullif(left(btrim(coalesce(p_reason, '')), 500), ''))
  on conflict (blocker_id, blocked_id) do update set reason = excluded.reason;
  return jsonb_build_object('ok', true, 'blocked_id', p_blocked_id);
end;
$$;


--
-- Name: cancel_guardian_invite(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.cancel_guardian_invite(p_link_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  user_id uuid := auth.uid();
  affected integer;
begin
  if user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_link_id is null then
    return jsonb_build_object('ok', false, 'code', 'guardian_link_id_required');
  end if;

  update public.guardian_links
  set status = 'revoked', updated_at = now()
  where id = p_link_id and teen_user_id = user_id and status = 'pending';
  get diagnostics affected = row_count;
  if affected <> 1 then
    return jsonb_build_object('ok', false, 'code', 'pending_guardian_invite_not_found');
  end if;

  update private.guardian_invite_codes
  set consumed_at = coalesce(consumed_at, now())
  where guardian_link_id = p_link_id and consumed_at is null;
  update public.profiles
  set guardian_setup_status = 'not_started', updated_at = now()
  where id = user_id and role = 'teen'::public.mort_role;

  return jsonb_build_object('ok', true, 'link_id', p_link_id, 'status', 'revoked');
end;
$$;


--
-- Name: FUNCTION cancel_guardian_invite(p_link_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.cancel_guardian_invite(p_link_id uuid) IS 'Allows only the teen who created a pending guardian invitation to revoke it; consumes its code.';


--
-- Name: close_team_hustle_v1(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.close_team_hustle_v1(p_hustle_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_user uuid := auth.uid();
  v_role public.mort_role;
begin
  if v_user is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;

  select p.role into v_role from public.profiles p where p.id = v_user;

  update public.team_hustles th
  set status = 'closed', updated_at = now()
  where th.id = p_hustle_id
    and (th.poster_id = v_user or v_role = 'admin');
  if not found then
    return jsonb_build_object('ok', false, 'code', 'not_found_or_not_poster');
  end if;
  return jsonb_build_object('ok', true);
end;
$$;


--
-- Name: complete_active_job_checkin(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.complete_active_job_checkin(p_checkin_id uuid, p_client_request_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  user_id uuid := auth.uid();
  completed_id uuid;
  completed_at_value timestamptz;
begin
  if user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if private.current_role() <> 'teen'::public.mort_role or not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_teen_account_required');
  end if;
  if p_client_request_id is null then
    return jsonb_build_object('ok', false, 'code', 'client_request_id_required');
  end if;

  update public.job_safety_checkins
  set status = 'completed', completed_at = now()
  where id = p_checkin_id
    and teen_user_id = user_id
    and status = 'scheduled'
  returning id, completed_at into completed_id, completed_at_value;

  if completed_id is null then
    select id, completed_at into completed_id, completed_at_value
    from public.job_safety_checkins
    where id = p_checkin_id and teen_user_id = user_id and status = 'completed';
  end if;
  if completed_id is null then
    return jsonb_build_object('ok', false, 'code', 'active_checkin_not_found');
  end if;
  return jsonb_build_object(
    'ok', true, 'checkin_id', completed_id, 'completed_at', completed_at_value
  );
end;
$$;


--
-- Name: complete_job_after_proof(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.complete_job_after_proof(p_application_id uuid, p_proof_id uuid) RETURNS jsonb
    LANGUAGE sql
    SET search_path TO ''
    AS $_$
  select private.complete_job_after_proof_internal($1,$2)
$_$;


--
-- Name: complete_my_onboarding_v2(jsonb, uuid, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.complete_my_onboarding_v2(p_payload jsonb, p_client_request_id uuid, p_payload_version integer DEFAULT 1, p_expected_revision text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  user_id uuid := auth.uid();
  progress jsonb;
  completed_at timestamptz;
begin
  if user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object'
     or p_client_request_id is null or p_payload_version <> 1 then
    return jsonb_build_object('ok', false, 'code', 'onboarding_request_invalid');
  end if;

  select profile.onboarding_completed_at into completed_at
  from public.profiles profile
  where profile.id = user_id;
  if completed_at is not null then
    return jsonb_build_object('ok', true, 'already_completed', true, 'completed_at', completed_at);
  end if;

  progress := private.evaluate_mort_onboarding(user_id);
  if progress->>'active_step' <> 'review' then
    return jsonb_build_object(
      'ok', false,
      'code', 'onboarding_steps_incomplete',
      'missing_requirements', progress->'missing_requirements'
    );
  end if;
  if not private.mort_user_has_current_legal_acceptances(user_id) then
    return jsonb_build_object('ok', false, 'code', 'published_legal_acceptance_required');
  end if;

  update public.profiles
  set onboarding_completed_at = coalesce(onboarding_completed_at, now()),
      updated_at = now()
  where id = user_id
  returning onboarding_completed_at into completed_at;

  return jsonb_build_object('ok', true, 'already_completed', false, 'completed_at', completed_at);
end;
$$;


--
-- Name: confirm_job_contract_version(uuid, boolean, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.confirm_job_contract_version(p_contract_version_id uuid, p_affirmative_checkbox boolean, p_confirmation_text text, p_platform text, p_app_version text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_user uuid := auth.uid();
  v_version public.job_contract_versions%rowtype;
  v_contract public.job_contracts%rowtype;
  v_party_role text;
  v_confirmations integer;
begin
  if v_user is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if not coalesce(p_affirmative_checkbox, false) then
    return jsonb_build_object('ok', false, 'code', 'affirmative_checkbox_required');
  end if;
  if char_length(btrim(coalesce(p_confirmation_text, ''))) < 8 then
    return jsonb_build_object('ok', false, 'code', 'confirmation_text_required');
  end if;
  if char_length(coalesce(p_platform, '')) not between 1 and 40
     or char_length(coalesce(p_app_version, '')) not between 1 and 40 then
    return jsonb_build_object('ok', false, 'code', 'client_context_required');
  end if;

  select * into v_version
  from public.job_contract_versions
  where id = p_contract_version_id
  for update;
  if not found or v_version.status <> 'pending_confirmation'
     or v_version.content_hash <> encode(extensions.digest(v_version.terms_snapshot::text, 'sha256'), 'hex') then
    return jsonb_build_object('ok', false, 'code', 'pending_contract_version_required');
  end if;

  select * into v_contract
  from public.job_contracts
  where id = v_version.contract_id
  for update;
  if v_user = v_contract.teen_id then
    v_party_role := 'teen';
  elsif v_user = v_contract.adult_id then
    v_party_role := 'adult';
  else
    return jsonb_build_object('ok', false, 'code', 'contract_party_required');
  end if;

  insert into public.job_contract_acceptances (
    contract_id, contract_version_id, user_id, party_role, content_hash,
    affirmative_checkbox, confirmation_text, platform, app_version
  ) values (
    v_contract.id, v_version.id, v_user, v_party_role, v_version.content_hash,
    true, left(btrim(p_confirmation_text), 300), left(btrim(p_platform), 40), left(btrim(p_app_version), 40)
  ) on conflict (contract_version_id, user_id) do nothing;

  select count(distinct user_id)::integer into v_confirmations
  from public.job_contract_acceptances
  where contract_version_id = v_version.id
    and content_hash = v_version.content_hash
    and user_id in (v_contract.teen_id, v_contract.adult_id);

  if v_confirmations = 2 then
    update public.job_contract_versions
    set status = 'superseded', superseded_at = now()
    where id = v_contract.active_version_id
      and id <> v_version.id
      and status = 'active';
    update public.job_contract_versions
    set status = 'active', activated_at = coalesce(activated_at, now())
    where id = v_version.id;
    update public.job_contracts
    set status = 'active', active_version_id = v_version.id,
        activated_at = coalesce(activated_at, now())
    where id = v_contract.id;
  end if;

  return jsonb_build_object(
    'ok', true,
    'code', case when v_confirmations = 2 then 'contract_active' else 'confirmation_recorded' end,
    'confirmations', v_confirmations,
    'required_confirmations', 2
  );
end;
$$;


--
-- Name: FUNCTION confirm_job_contract_version(p_contract_version_id uuid, p_affirmative_checkbox boolean, p_confirmation_text text, p_platform text, p_app_version text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.confirm_job_contract_version(p_contract_version_id uuid, p_affirmative_checkbox boolean, p_confirmation_text text, p_platform text, p_app_version text) IS 'Records a party confirmation of the exact immutable contract version; activates only after both parties confirm.';


--
-- Name: confirm_job_finish_pin_v2(uuid, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.confirm_job_finish_pin_v2(p_application_id uuid, p_pin text, p_client_request_id uuid) RETURNS jsonb
    LANGUAGE sql
    SET search_path TO ''
    AS $$
  select private.confirm_job_finish_pin_internal(
    p_application_id, p_pin, p_client_request_id
  );
$$;


--
-- Name: confirm_job_safety_agreement(uuid, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.confirm_job_safety_agreement(p_application_id uuid, p_agreement_version integer) RETURNS jsonb
    LANGUAGE sql
    SET search_path TO ''
    AS $$
  select private.confirm_job_safety_agreement_internal(
    p_application_id,
    p_agreement_version
  );
$$;


--
-- Name: FUNCTION confirm_job_safety_agreement(p_application_id uuid, p_agreement_version integer); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.confirm_job_safety_agreement(p_application_id uuid, p_agreement_version integer) IS 'Records one current participant confirmation; the agreement is confirmed only after both parties accept the same hashed snapshot.';


--
-- Name: confirm_job_start_pin_v2(uuid, text, boolean, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.confirm_job_start_pin_v2(p_application_id uuid, p_pin text, p_person_matches_profile boolean, p_client_request_id uuid) RETURNS jsonb
    LANGUAGE sql
    SET search_path TO ''
    AS $$
  select private.confirm_job_start_pin_internal(
    p_application_id, p_pin, p_person_matches_profile, p_client_request_id
  );
$$;


--
-- Name: consume_my_edge_action_limit(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.consume_my_edge_action_limit(p_action text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_user uuid := auth.uid();
  v_window timestamptz := date_trunc('minute', now());
  v_limit integer;
  v_count integer;
begin
  if v_user is null then return false; end if;
  if p_action not in (
    'stripe_job_funding_quote', 'stripe_tip_payment_intent', 'stripe_job_payment_intent',
    'stripe_connected_account_status', 'stripe_connected_account_create', 'stripe_onboarding_link',
    'stripe_financial_document', 'stripe_financial_history', 'stripe_job_payment_status',
    'stripe_job_resolution', 'stripe_assignment_payment_intent'
  ) then return false; end if;
  v_limit := case
    when p_action in ('stripe_tip_payment_intent', 'stripe_job_payment_intent', 'stripe_assignment_payment_intent') then 4
    when p_action in ('stripe_connected_account_create', 'stripe_onboarding_link') then 3
    else 20
  end;
  insert into private.mort_edge_action_limits(user_id, action, window_started_at, request_count)
  values (v_user, p_action, v_window, 1)
  on conflict (user_id, action, window_started_at) do update
    set request_count = private.mort_edge_action_limits.request_count + 1
    where private.mort_edge_action_limits.request_count < v_limit
  returning request_count into v_count;
  return found;
end;
$$;


--
-- Name: create_guardian_invite_v2(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_guardian_invite_v2(p_invite_email text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $_$
declare
  teen_id uuid := auth.uid();
  teen_profile public.profiles%rowtype;
  email_value text := nullif(lower(btrim(p_invite_email)), '');
  invite_code text;
  link_id uuid;
  invite_limit integer;
  expires_at_value timestamptz := now() + interval '7 days';
begin
  if teen_id is null then return jsonb_build_object('ok', false, 'code', 'authentication_required'); end if;
  select * into teen_profile from public.profiles where id = teen_id for update;
  if not found or teen_profile.role <> 'teen'::public.mort_role
    or teen_profile.date_of_birth is null
    or extract(year from age(current_date, teen_profile.date_of_birth)) not between 13 and 17 then
    return jsonb_build_object('ok', false, 'code', 'active_teen_account_required');
  end if;
  if email_value is not null and (char_length(email_value) > 254 or email_value !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$') then
    return jsonb_build_object('ok', false, 'code', 'guardian_email_invalid');
  end if;
  select count(*) into invite_limit from private.guardian_invite_codes
  where teen_user_id = teen_id and created_at > now() - interval '24 hours';
  if invite_limit >= 3 then return jsonb_build_object('ok', false, 'code', 'guardian_invite_limit_reached'); end if;

  update public.guardian_links set status = 'revoked', updated_at = now()
  where teen_user_id = teen_id and status = 'pending';
  invite_code := encode(extensions.gen_random_bytes(32), 'hex');
  insert into public.guardian_links(teen_user_id, guardian_user_id, status, initiated_by, teen_consent_at)
  values (teen_id, null, 'pending', teen_id, now()) returning id into link_id;
  insert into private.guardian_invite_codes(guardian_link_id, teen_user_id, code_sha256, invited_email, expires_at)
  values (link_id, teen_id, encode(extensions.digest(convert_to(invite_code, 'utf8'), 'sha256'), 'hex'), email_value, expires_at_value);
  update public.profiles set guardian_setup_status = 'invite_pending', updated_at = now() where id = teen_id;
  return jsonb_build_object(
    'ok', true,
    'link_id', link_id,
    'invite_code', upper(invite_code),
    'expires_at', expires_at_value,
    'delivery', 'share_code_with_guardian'
  );
end;
$_$;


--
-- Name: FUNCTION create_guardian_invite_v2(p_invite_email text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.create_guardian_invite_v2(p_invite_email text) IS 'Creates a teen-consented, expiring guardian invite. The code is not emailed; the teen must share it directly.';


--
-- Name: create_safety_ping_v2(text, text, uuid, boolean, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_safety_ping_v2(p_status text, p_note text, p_job_id uuid, p_immediate_danger boolean, p_client_request_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  user_id uuid := auth.uid();
  ping_id uuid;
  guardian_count integer;
begin
  if user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if private.current_role() <> 'teen'::public.mort_role or not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_teen_account_required');
  end if;
  if p_client_request_id is null then
    return jsonb_build_object('ok', false, 'code', 'client_request_id_required');
  end if;
  if p_status is distinct from 'needs_help' then
    return jsonb_build_object('ok', false, 'code', 'safety_ping_status_invalid');
  end if;
  if char_length(coalesce(p_note, '')) > 500 then
    return jsonb_build_object('ok', false, 'code', 'safety_ping_note_too_long');
  end if;
  if p_job_id is not null and not exists (
    select 1
    from public.job_assignments assignment
    where assignment.teen_user_id = user_id
      and assignment.job_id = p_job_id
      and assignment.status in ('accepted', 'in_progress')
  ) then
    return jsonb_build_object('ok', false, 'code', 'active_job_required');
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(user_id::text, 0)
  );
  select id into ping_id
  from public.safety_pings
  where teen_id = user_id and client_request_id = p_client_request_id;
  if ping_id is null and exists (
    select 1 from public.safety_pings
    where teen_id = user_id and created_at > now() - interval '30 seconds'
  ) then
    return jsonb_build_object('ok', false, 'code', 'safety_ping_rate_limited');
  end if;

  if ping_id is null then
    insert into public.safety_pings (
      teen_id, status, note, job_id, immediate_danger, client_request_id
    ) values (
      user_id, 'needs_help', nullif(btrim(coalesce(p_note, '')), ''),
      p_job_id, coalesce(p_immediate_danger, false), p_client_request_id
    )
    on conflict (teen_id, client_request_id) do nothing
    returning id into ping_id;
  end if;

  if ping_id is null then
    select id into ping_id from public.safety_pings
    where teen_id = user_id and client_request_id = p_client_request_id;
  end if;

  select count(*) into guardian_count
  from public.notifications notification
  where notification.user_id in (
    select link.guardian_user_id
    from public.guardian_links link
    left join public.guardian_preferences preferences on preferences.link_id = link.id
    where link.teen_user_id = user_id
      and link.guardian_user_id is not null
      and link.status = 'active'
      and coalesce(preferences.safety_ping_alerts, true)
  )
  and notification.notification_type = 'safety_ping'
  and notification.data ->> 'safety_ping_id' = ping_id::text;

  return jsonb_build_object(
    'ok', true,
    'ping_id', ping_id,
    'immediate_danger', coalesce(p_immediate_danger, false),
    'guardian_notified', guardian_count > 0,
    'delivery', 'in_app_only'
  );
end;
$$;


--
-- Name: create_team_hustle_v1(text, text, text, text, numeric, integer, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_team_hustle_v1(p_title text, p_description text, p_category text, p_pay_type text, p_pay_amount numeric, p_workers_needed integer, p_city text, p_region text, p_location_notes text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_user uuid := auth.uid();
  v_role public.mort_role;
begin
  if v_user is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;

  select p.role into v_role from public.profiles p where p.id = v_user;
  if v_role not in ('adult','admin') then
    return jsonb_build_object('ok', false, 'code', 'adult_required');
  end if;

  if p_title is null or length(btrim(p_title)) < 3 or length(btrim(p_title)) > 120 then
    return jsonb_build_object('ok', false, 'code', 'invalid_title');
  end if;
  if p_description is null or length(btrim(p_description)) < 10 or length(btrim(p_description)) > 2000 then
    return jsonb_build_object('ok', false, 'code', 'invalid_description');
  end if;
  if p_pay_type is null or p_pay_type not in ('per_person','total_split') then
    return jsonb_build_object('ok', false, 'code', 'invalid_pay_type');
  end if;
  if p_pay_amount is not null and (p_pay_amount < 1 or p_pay_amount > 10000) then
    return jsonb_build_object('ok', false, 'code', 'invalid_pay_amount');
  end if;
  if p_workers_needed is null or p_workers_needed < 2 or p_workers_needed > 10 then
    return jsonb_build_object('ok', false, 'code', 'invalid_workers_needed');
  end if;
  if p_region is not null and length(btrim(p_region)) <> 2 then
    return jsonb_build_object('ok', false, 'code', 'invalid_region');
  end if;

  if (select count(*) from public.team_hustles th
      where th.poster_id = v_user and th.status = 'open') >= 10 then
    return jsonb_build_object('ok', false, 'code', 'too_many_open_hustles');
  end if;
  if (select count(*) from public.team_hustles th
      where th.poster_id = v_user and th.created_at > now() - interval '24 hours') >= 5 then
    return jsonb_build_object('ok', false, 'code', 'too_many_posts_today');
  end if;

  insert into public.team_hustles (
    poster_id, title, description, category, pay_type, pay_amount,
    workers_needed, city, region, location_notes
  ) values (
    v_user, btrim(p_title), btrim(p_description), nullif(btrim(coalesce(p_category,'')),''),
    p_pay_type, p_pay_amount, p_workers_needed,
    nullif(btrim(coalesce(p_city,'')),''), upper(nullif(btrim(coalesce(p_region,'')),'')),
    nullif(btrim(coalesce(p_location_notes,'')),'')
  );

  insert into public.admin_audit_log (actor_id, action, target_type, target_id, reason, metadata)
  values (v_user, 'team_hustle_created', 'team_hustle', p_title, null,
          jsonb_build_object('workers_needed', p_workers_needed, 'pay_type', p_pay_type));

  return jsonb_build_object('ok', true);
end;
$$;


--
-- Name: ensure_my_profile(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ensure_my_profile() RETURNS SETOF public.profiles
    LANGUAGE sql
    SET search_path TO ''
    AS $$
  select * from private.ensure_my_profile();
$$;


--
-- Name: FUNCTION ensure_my_profile(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.ensure_my_profile() IS 'Returns only the authenticated caller profile and creates a missing row without assigning a role or changing account status.';


--
-- Name: generate_job_finish_pin(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_job_finish_pin(p_application_id uuid, p_client_request_id uuid) RETURNS jsonb
    LANGUAGE sql
    SET search_path TO ''
    AS $$
  select private.generate_job_finish_pin_internal(p_application_id, p_client_request_id);
$$;


--
-- Name: generate_job_start_pin(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_job_start_pin(p_application_id uuid, p_client_request_id uuid) RETURNS jsonb
    LANGUAGE sql
    SET search_path TO ''
    AS $$
  select private.generate_job_start_pin_internal(p_application_id, p_client_request_id);
$$;


--
-- Name: get_first_party_trust_status(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_first_party_trust_status() RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_marketplace_enabled boolean;
  v_maintenance_mode boolean;
  v_real_document_collection boolean;
  v_payments_enabled boolean;
  v_updated_at timestamptz;
begin
  if auth.uid() is null then
    raise exception using
      errcode = '42501',
      message = 'authentication_required';
  end if;

  select
    release.public_marketplace_enabled,
    release.maintenance_mode,
    release.real_document_collection,
    stripe.mode = 'live'
      and stripe.payments_enabled
      and stripe.job_funding_enabled,
    greatest(release.updated_at, stripe.updated_at)
  into
    v_marketplace_enabled,
    v_maintenance_mode,
    v_real_document_collection,
    v_payments_enabled,
    v_updated_at
  from public.mort_release_control as release
  cross join private.stripe_runtime_controls as stripe
  where release.is_primary and stripe.singleton;

  if not found then
    return jsonb_build_object(
      'ok', false,
      'real_document_collection_enabled', false,
      'external_web_reuse_enabled', false,
      'real_live_presence_enabled', false,
      'real_appearance_review_enabled', false,
      'synthetic_qa_only', true,
      'authoritative_identity_provider_connected', false,
      'public_marketplace_open', false,
      'payments_enabled', false,
      'maintenance_mode', true,
      'document_quality_is_identity', false,
      'web_reuse_is_authenticity', false,
      'liveness_is_legal_identity', false,
      'device_biometric_is_legal_identity', false,
      'guardian_mode_optional', true,
      'status_updated_at', null
    );
  end if;

  return jsonb_build_object(
    'ok', true,
    'real_document_collection_enabled', v_real_document_collection,
    'external_web_reuse_enabled', false,
    'real_live_presence_enabled', false,
    'real_appearance_review_enabled', false,
    'synthetic_qa_only', true,
    'authoritative_identity_provider_connected', false,
    'public_marketplace_open', v_marketplace_enabled and not v_maintenance_mode,
    'payments_enabled', v_payments_enabled,
    'maintenance_mode', v_maintenance_mode,
    'document_quality_is_identity', false,
    'web_reuse_is_authenticity', false,
    'liveness_is_legal_identity', false,
    'device_biometric_is_legal_identity', false,
    'guardian_mode_optional', true,
    'status_updated_at', v_updated_at
  );
end;
$$;


--
-- Name: FUNCTION get_first_party_trust_status(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_first_party_trust_status() IS 'Returns the current release and payment capability state to signed-in Flutter clients; provider-dependent trust capabilities fail closed.';


--
-- Name: get_job_application_eligibility(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_job_application_eligibility(p_job_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
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


--
-- Name: get_job_execution_status(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_job_execution_status(p_application_id uuid) RETURNS jsonb
    LANGUAGE sql STABLE
    SET search_path TO ''
    AS $$
  select private.get_job_execution_status_internal(p_application_id);
$$;


--
-- Name: get_my_active_job_checkins(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_my_active_job_checkins() RETURNS jsonb
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
  select coalesce(jsonb_agg(to_jsonb(checkins) order by checkins.expected_at nulls last), '[]'::jsonb)
  from (
    select
      assignment.application_id,
      assignment.job_id,
      job.title as job_title,
      checkin.id as checkin_id,
      coalesce(checkin.status, 'not_scheduled') as status,
      checkin.expected_at
    from public.job_assignments assignment
    join public.jobs job on job.id = assignment.job_id
    left join lateral (
      select c.id, c.status, c.expected_at
      from public.job_safety_checkins c
      where c.application_id = assignment.application_id
        and c.teen_user_id = (select auth.uid())
        and c.status = 'scheduled'
      order by c.expected_at asc
      limit 1
    ) checkin on true
    where assignment.teen_user_id = (select auth.uid())
      and assignment.status in ('accepted', 'in_progress')
  ) checkins
$$;


--
-- Name: get_my_assignment_payment_status(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_my_assignment_payment_status(p_provider_payment_intent_id text) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $_$
declare
  payment private.stripe_payment_intents%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_provider_payment_intent_id is null or p_provider_payment_intent_id !~ '^pi_[A-Za-z0-9]+$' then
    return jsonb_build_object('ok', false, 'code', 'invalid_payment_intent_id');
  end if;
  select * into payment from private.stripe_payment_intents
  where provider_payment_intent_id = p_provider_payment_intent_id
    and auth.uid() in (payer_id, payee_id);
  if not found then
    return jsonb_build_object('ok', false, 'code', 'payment_not_found');
  end if;
  return jsonb_build_object(
    'ok', true,
    'state', case payment.status
      when 'succeeded' then 'SUCCEEDED'
      when 'processing' then 'PROCESSING'
      when 'requires_action' then 'REQUIRES_ACTION'
      when 'authorized' then 'AUTHORIZED'
      when 'failed' then 'FAILED'
      when 'cancelled' then 'CANCELLED'
      when 'refunded' then 'REFUNDED'
      when 'disputed' then 'DISPUTED'
      else 'PENDING'
    end,
    'amount_cents', payment.gross_amount_cents,
    'currency_code', payment.currency_code,
    'updated_at', payment.updated_at
  );
end;
$_$;


--
-- Name: FUNCTION get_my_assignment_payment_status(p_provider_payment_intent_id text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_my_assignment_payment_status(p_provider_payment_intent_id text) IS 'Returns a minimal Stripe assignment payment status only to its adult payer or teen payee.';


--
-- Name: get_my_identity_verification_v2(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_my_identity_verification_v2() RETURNS jsonb
    LANGUAGE plpgsql STABLE
    SET search_path TO ''
    AS $$
declare
  v_user uuid := auth.uid();
  v_role public.mort_role;
  v_status text;
  v_dob date;
  v_minor boolean;
  v_case public.verification_cases%rowtype;
begin
  if v_user is null then
    raise exception using
      errcode = '42501',
      message = 'authentication_required';
  end if;

  select p.role, p.verification_status, p.date_of_birth
    into v_role, v_status, v_dob
  from public.profiles p
  where p.id = v_user;

  select * into v_case from public.verification_cases vc
  where vc.user_id = v_user
  order by vc.created_at desc
  limit 1;

  v_minor := v_dob is not null and private.mort_age_years(v_dob) between 13 and 17;

  return jsonb_build_object(
    'ok', true,
    'id', v_user,
    'role', v_role,
    'status', coalesce(v_status, 'not_started'),
    'evidence_route', case when v_minor then 'school_id' else 'identity' end,
    'verification_level', case when v_status = 'verified' then 1 else 0 end,
    'marketplace_enabled', true,
    'guardian_mode_optional', true,
    'verification_mode', 'mort_staff_review',
    'production_verified', (v_status = 'verified'),
    'sandbox_eligible', false,
    'test_mode', false,
    'submissions_enabled', true,
    'production_provider_available', true,
    'can_retry', (v_case.id is null or v_case.status in ('rejected','expired')),
    'support_escalation_available', true,
    'documents_collected_by_mort', true,
    'provider', 'mort',
    'provider_reference', v_case.provider,
    'decision_source', case when v_case.id is null then null else 'mort_staff_review' end,
    'failure_code', null,
    'public_message', 'Upload your school ID (teens) or government photo ID (adults). MORT staff review every submission and update your status.',
    'evidence_types', case when v_minor
      then '["school_photo_id","official_enrollment_confirmation"]'::jsonb
      else '["government_photo_id"]'::jsonb end
  );
end;
$$;


--
-- Name: FUNCTION get_my_identity_verification_v2(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_my_identity_verification_v2() IS 'Returns a fail-closed identity verification status for the signed-in user while no production provider is configured; it collects no identity data.';


--
-- Name: get_my_job_applications(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_my_job_applications(p_application_id uuid DEFAULT NULL::uuid) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$ declare v_user uuid:=auth.uid(); v_items jsonb; begin if v_user is null or (
    not private.is_active_user()
    and not exists (
      select 1
      from public.profiles guardian_profile
      join auth.users guardian_auth on guardian_auth.id = guardian_profile.id
      where guardian_profile.id = v_user
        and guardian_profile.role = 'guardian'::public.mort_role
        and guardian_profile.account_status = 'active'
        and guardian_profile.date_of_birth is not null
        and extract(year from age(current_date, guardian_profile.date_of_birth)) >= 18
        and guardian_auth.email_confirmed_at is not null
    )
  ) then return jsonb_build_object('ok',false,'code','active_account_required'); end if; select coalesce(jsonb_agg(jsonb_build_object('id',ja.id,'job_id',ja.job_id,'teen_id',ja.applicant_id,'status',ja.status::text,'note',ja.cover_note,'guardian_id',case
  when ja.applicant_id=v_user or exists(
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
  ) then ja.guardian_id
  else null
end,'availability_confirmed',ja.availability_confirmed,'created_at',ja.created_at,'updated_at',ja.updated_at,'viewed_at',ja.viewed_at,'withdrawn_at',ja.withdrawn_at,'teen',jsonb_build_object('display_name',teen.display_name,'avatar_path',teen.avatar_path),'jobs',jsonb_build_object('id',j.id,'poster_id',j.poster_id,'title',j.title,'summary',j.summary,'description',j.description,'category',j.category,'location_text',case when j.remote_allowed then 'Remote' else concat_ws(', ',j.city,j.region) end,'city',j.city,'state',j.region,'status',j.status::text,'requires_guardian_approval',j.requires_guardian_approval,'adult_job_amount_cents',round(j.pay_amount*100)::integer,'mort_service_fee_cents',j.mort_service_fee_cents,'pay_amount_cents',round(j.pay_amount*100)::integer,'starts_at',j.starts_at,'ends_at',j.ends_at,'deadline_at',j.deadline_at,'expires_at',j.expires_at,'published_at',j.published_at,'updated_at',j.updated_at,'profiles',jsonb_build_object('display_name',poster.display_name,'verification_status',poster.verification_status,'avatar_path',poster.avatar_path),'schedule_type',j.schedule_type,'payment_type',j.pay_type,'payment_method',j.payment_method,'payment_timing',j.payment_timing,'verification_requirement',j.verification_requirement,'work_environment',j.work_environment,'location_type',j.location_type,'experience_level',j.experience_level,'estimated_duration_minutes',j.estimated_duration_minutes,'workers_needed',j.workers_needed,'skills_needed',to_jsonb(j.skills_needed),'physical_requirements',to_jsonb(j.physical_requirements),'equipment_provided',j.equipment_provided,'equipment_worker_brings',j.equipment_worker_brings,'special_instructions',j.special_instructions,'safety_notes',j.safety_notes,'proof_expected',j.proof_expected,'adult_supervision_present',j.adult_supervision_present,'tip_allowed',j.tip_allowed,'applications_open',j.applications_open,'is_test',false,'recurring',j.recurring,'recurrence_rule',j.recurrence_rule,'timezone',j.timezone,'urgency',j.urgency,'acceptable_transportation_methods',to_jsonb(j.acceptable_transportation_methods),'teen_min_age',j.age_min,'teen_max_age',j.age_max,'quick_accept_eligible',false)) order by ja.created_at desc,ja.id desc),'[]'::jsonb) into v_items from public.job_applications ja join public.jobs j on j.id=ja.job_id join public.profiles teen on teen.id=ja.applicant_id join public.profiles poster on poster.id=j.poster_id where (p_application_id is null or ja.id=p_application_id) and (ja.applicant_id=v_user or j.poster_id=v_user or exists (
    select 1
    from public.guardian_links gl
    join public.profiles guardian_profile on guardian_profile.id = gl.guardian_user_id
    join auth.users guardian_auth on guardian_auth.id = gl.guardian_user_id
    where gl.teen_user_id = ja.applicant_id
      and gl.guardian_user_id = v_user
      and gl.status = 'active'
      and gl.teen_consent_at is not null
      and gl.guardian_consent_at is not null
      and guardian_profile.role = 'guardian'::public.mort_role
      and guardian_profile.account_status = 'active'
      and guardian_profile.date_of_birth is not null
      and extract(year from age(current_date, guardian_profile.date_of_birth)) >= 18
      and guardian_auth.email_confirmed_at is not null
  )); return jsonb_build_object('ok',true,'items',v_items); end; $$;


--
-- Name: FUNCTION get_my_job_applications(p_application_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_my_job_applications(p_application_id uuid) IS 'Returns minimal application and job details only for the applicant, job poster, or actively linked guardian.';


--
-- Name: get_my_legal_requirements(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_my_legal_requirements() RETURNS jsonb
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
  with actor as (
    select profile.id, profile.role, profile.date_of_birth,
      private.mort_legal_age_band(profile.date_of_birth) as age_band
    from public.profiles profile
    where profile.id = auth.uid()
      and (
        profile.account_status = 'active'
        or (
          profile.account_status = 'pending'
          and exists (
            select 1 from auth.users auth_user
            where auth_user.id = profile.id
              and auth_user.email_confirmed_at is not null
          )
        )
      )
      and profile.role <> 'pending'
  ), current_versions as (
    select distinct on (version.document_id)
      version.document_id, version.id as version_id, version.version_label,
      version.content_hash, version.effective_at, version.language_code,
      version.jurisdiction_policy, version.acceptance_ui_version,
      version.requires_electronic_signature
    from public.legal_document_versions version
    join public.legal_documents document
      on document.id = version.document_id
     and document.publication_status = 'published'
    where version.publication_status = 'published'
      and version.effective_at <= now()
    order by version.document_id, version.effective_at desc, version.created_at desc
  ), requirements as (
    select document.document_key, document.title, role_requirement.required,
      current_version.version_id, current_version.version_label,
      current_version.content_hash, current_version.effective_at,
      current_version.language_code, current_version.jurisdiction_policy,
      current_version.acceptance_ui_version,
      current_version.requires_electronic_signature,
      acceptance.id as acceptance_id, acceptance.accepted_at
    from actor
    join public.legal_role_requirements role_requirement
      on role_requirement.role = actor.role
     and role_requirement.age_band in ('all', actor.age_band)
    join public.legal_documents document
      on document.id = role_requirement.document_id
     and document.publication_status = 'published'
    join current_versions current_version
      on current_version.document_id = document.id
    left join public.legal_acceptances acceptance
      on acceptance.user_id = actor.id
     and acceptance.document_version_id = current_version.version_id
     and acceptance.active
    order by role_requirement.priority, document.document_key
  )
  select jsonb_build_object(
    'ok', exists (select 1 from actor),
    'guardian_mode_optional', true,
    'acceptance_inferred_from_browsing', false,
    'requirements', coalesce(jsonb_agg(to_jsonb(requirements)), '[]'::jsonb)
  )
  from requirements;
$$;


--
-- Name: get_my_onboarding_progress(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_my_onboarding_progress() RETURNS jsonb
    LANGUAGE sql STABLE
    SET search_path TO ''
    AS $$
  select pg_catalog.jsonb_build_object(
    'ok', true,
    'current_step', 'account',
    'resume_path', '/onboarding',
    'completed_steps', pg_catalog.jsonb_build_array()
  )
  from public.profiles as profile
  where profile.id = (select auth.uid())
    and profile.onboarding_completed_at is null;
$$;


--
-- Name: get_my_onboarding_progress_v2(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_my_onboarding_progress_v2() RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin
  if auth.uid() is null then return jsonb_build_object('ok', false, 'code', 'authentication_required'); end if;
  return private.evaluate_mort_onboarding(auth.uid());
end;
$$;


--
-- Name: FUNCTION get_my_onboarding_progress_v2(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_my_onboarding_progress_v2() IS 'Returns the initial account step until resumable onboarding writes are installed.';


--
-- Name: get_my_profile(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_my_profile() RETURNS SETOF public.profiles
    LANGUAGE sql STABLE
    SET search_path TO ''
    AS $$
  select profile.*
  from public.profiles as profile
  where profile.id = (select auth.uid());
$$;


--
-- Name: FUNCTION get_my_profile(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_my_profile() IS 'Returns only the authenticated caller profile.';


--
-- Name: get_my_stripe_payout_status(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_my_stripe_payout_status() RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  controls private.stripe_runtime_controls%rowtype;
  connected private.stripe_connected_accounts%rowtype;
  stripe_environment text;
begin
  if auth.uid() is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  select * into strict controls from private.stripe_runtime_controls where singleton;
  stripe_environment := case controls.mode when 'sandbox' then 'test' when 'live' then 'live' else null end;
  if stripe_environment is not null then
    select * into connected
    from private.stripe_connected_accounts
    where user_id = auth.uid() and environment = stripe_environment;
  end if;
  return jsonb_build_object(
    'configured', false,
    'enabled', controls.connected_onboarding_enabled and controls.payouts_approved,
    'connected', connected.id is not null,
    'onboarding_status', coalesce(connected.onboarding_status, 'not_started'),
    'details_submitted', coalesce(connected.details_submitted, false),
    'payouts_enabled', coalesce(connected.payouts_enabled, false),
    'transfers_capability_status', coalesce(connected.transfers_capability_status, 'inactive'),
    'requirements_status', coalesce(connected.requirements_status, 'unknown')
  );
end;
$$;


--
-- Name: get_my_verification_requirements_v1(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_my_verification_requirements_v1() RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_user_id uuid := auth.uid();
  v_dob date;
  v_age integer;
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;

  select p.date_of_birth into v_dob
  from public.profiles p
  where p.id = v_user_id;

  if v_dob is null then
    return jsonb_build_object(
      'ok', true, 'eligible', false, 'code', 'dob_required',
      'minimum_age', 13, 'verification_available', true
    );
  end if;

  v_age := private.mort_age_years(v_dob);
  if v_age < 13 then
    return jsonb_build_object(
      'ok', true, 'eligible', false, 'code', 'minimum_age_required',
      'minimum_age', 13, 'verification_available', false
    );
  end if;

  if v_age between 13 and 17 then
    return jsonb_build_object(
      'ok', true,
      'eligible', true,
      'age_band', 'minor',
      'minimum_age', 13,
      'school_email_required', true,
      'identity_evidence_options', jsonb_build_array('school_photo_id', 'official_enrollment_confirmation'),
      'identity_evidence_rule', 'Upload a current school-issued photo ID, or official enrollment confirmation if your school has no photo ID. MORT staff review every submission and update your status.',
      'verification_available', true,
      'submissions_enabled', true,
      'provider_status', 'mort_staff_review',
      'documents_collected_by_mort', true
    );
  end if;

  return jsonb_build_object(
    'ok', true,
    'eligible', true,
    'age_band', 'adult',
    'minimum_age', 13,
    'school_email_required', false,
    'identity_evidence_options', jsonb_build_array('government_photo_id'),
    'identity_evidence_rule', 'Upload a valid, unexpired government-issued photo ID (driver license, state ID, or passport). MORT staff review every submission and update your status.',
    'verification_available', true,
    'submissions_enabled', true,
    'provider_status', 'mort_staff_review',
    'documents_collected_by_mort', true
  );
end;
$$;


--
-- Name: get_release_mode_status(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_release_mode_status() RETURNS jsonb
    LANGUAGE sql STABLE
    SET search_path TO ''
    AS $$
  select coalesce(
    (
      select jsonb_build_object(
        'release_mode', control.release_mode,
        'maintenance_mode', control.maintenance_mode,
        'public_marketplace_enabled', control.public_marketplace_enabled,
        'real_document_collection', control.real_document_collection
      )
      from public.mort_release_control control
      where control.is_primary
    ),
    jsonb_build_object(
      'release_mode', 'unconfigured',
      'maintenance_mode', true,
      'public_marketplace_enabled', false,
      'real_document_collection', false
    )
  );
$$;


--
-- Name: get_released_job_location(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_released_job_location(p_application_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_user_id uuid := auth.uid();
  v_application public.job_applications%rowtype;
  v_job public.jobs%rowtype;
  v_assignment public.job_assignments%rowtype;
  v_agreement public.job_safety_agreements%rowtype;
  v_location private.job_private_locations%rowtype;
  v_allowed boolean := false;
  v_pair_key bigint;
  v_pair_other uuid;
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;
  -- Match the live lifecycle lock order: application, assignment, job,
  -- agreement, location. This avoids assignment/job lock inversion with
  -- start, cancellation, and completion operations.
  select * into v_application
  from public.job_applications application
  where application.id = p_application_id
  for share;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'exact_location_not_released');
  end if;
  select * into v_assignment
  from public.job_assignments assignment
  where assignment.application_id = p_application_id
  for share;
  select * into v_job
  from public.jobs job
  where job.id = v_application.job_id
  for share;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'exact_location_not_released');
  end if;
  if v_job.status::text in ('cancelled', 'completed')
     or (v_assignment.id is not null and v_assignment.status in ('cancelled', 'completed')) then
    return jsonb_build_object('ok', false, 'code', 'exact_location_not_released');
  end if;
  select * into v_location
  from private.job_private_locations location
  where location.job_id = v_job.id
  for share;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'exact_location_not_configured');
  end if;
  if v_location.poster_id is distinct from v_job.poster_id then
    return jsonb_build_object('ok', false, 'code', 'exact_location_not_released');
  end if;
  if v_job.poster_id = v_user_id then
    v_allowed := true;
    v_pair_other := v_assignment.teen_user_id;
  else
    v_pair_other := v_job.poster_id;
    select * into v_agreement
    from public.job_safety_agreements agreement
    where agreement.application_id = p_application_id
    for share;
    v_allowed := coalesce(
      v_application.applicant_id = v_user_id
      and v_application.status = 'accepted'::public.mort_application_status
      and v_assignment.id is not null
      and v_assignment.job_id = v_job.id
      and v_assignment.teen_user_id = v_user_id
      and v_assignment.adult_user_id = v_job.poster_id
      and v_assignment.status = 'in_progress'
      and v_job.status = 'in_progress'
      and v_agreement.id is not null
      and v_agreement.status = 'confirmed'
      and v_agreement.location_version > 0
      and v_agreement.location_version = v_location.location_version
      and v_agreement.teen_confirmed_version = v_agreement.agreement_version
      and v_agreement.adult_confirmed_version = v_agreement.agreement_version,
      false
    );
  end if;
  if coalesce(v_allowed, false) is not true then
    return jsonb_build_object('ok', false, 'code', 'exact_location_not_released');
  end if;
  -- Serialize a release check with concurrent block/unblock. If a block wins
  -- the pair lock, this function observes it before returning exact data.
  if v_pair_other is not null then
    v_pair_key := pg_catalog.hashtextextended(
      least(v_user_id, v_pair_other)::text || ':' || greatest(v_user_id, v_pair_other)::text,
      0
    );
    perform pg_catalog.pg_advisory_xact_lock(v_pair_key);
  end if;
  if v_pair_other is not null and exists (
    select 1 from public.user_blocks block
    where (block.blocker_id = v_user_id and block.blocked_id = v_pair_other)
       or (block.blocker_id = v_pair_other and block.blocked_id = v_user_id)
  ) then
    return jsonb_build_object('ok', false, 'code', 'exact_location_not_released');
  end if;
  insert into private.job_private_location_access_events(actor_id, resource_type, resource_id, action, reason)
  values (v_user_id, 'job_private_location', v_job.id, 'read', 'Authorized participant accessed a restricted job location.');
  return jsonb_build_object(
    'ok', true,
    'job_id', v_job.id,
    'exact_address', v_location.exact_address,
    'arrival_instructions', v_location.arrival_instructions,
    'access_notes', v_location.access_notes,
    'latitude', v_location.latitude,
    'longitude', v_location.longitude,
    'location_version', v_location.location_version,
    'release_stage', case when v_job.poster_id = v_user_id then 'poster' else 'active_assignment' end
  );
end;
$$;


--
-- Name: get_runtime_feature_status(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_runtime_feature_status() RETURNS jsonb
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
  select coalesce(
    (
      select jsonb_build_object(
        'ok', true,
        'maintenance_mode', release.maintenance_mode,
        -- AI is fail-closed until a production provider is configured.
        'ai_provider_disabled', true,
        'payments_disabled', not (
          stripe.mode = 'live'
          and stripe.payments_enabled
          and stripe.job_funding_enabled
        ),
        'new_job_publishing_disabled',
          not release.public_marketplace_enabled or release.maintenance_mode,
        'public_marketplace_closed', not release.public_marketplace_enabled,
        'real_document_collection', release.real_document_collection,
        'status_updated_at', greatest(release.updated_at, stripe.updated_at),
        'maintenance_message', case
          when release.maintenance_mode then
            'MORT is temporarily unavailable while safety or reliability work is completed.'
          else null
        end
      )
      from public.mort_release_control as release
      cross join private.stripe_runtime_controls as stripe
      where release.is_primary and stripe.singleton
    ),
    jsonb_build_object(
      'ok', false,
      'maintenance_mode', true,
      'ai_provider_disabled', true,
      'payments_disabled', true,
      'new_job_publishing_disabled', true,
      'public_marketplace_closed', true,
      'real_document_collection', false,
      'status_updated_at', null,
      'maintenance_message',
        'MORT runtime controls are unavailable. Operations are fail-closed.'
    )
  );
$$;


--
-- Name: FUNCTION get_runtime_feature_status(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_runtime_feature_status() IS 'Returns non-sensitive production runtime gates from release and Stripe controls for the Flutter app; missing controls fail closed.';


--
-- Name: get_stripe_runtime_status(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_stripe_runtime_status() RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  controls private.stripe_runtime_controls%rowtype;
begin
  if auth.uid() is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  select * into strict controls
  from private.stripe_runtime_controls
  where singleton;
  return jsonb_build_object(
    'mode', controls.mode,
    'environment', case controls.mode when 'sandbox' then 'test' when 'live' then 'live' else null end,
    'currency_code', controls.currency_code,
    'service_fee_cents', controls.service_fee_cents,
    'payments_enabled', controls.payments_enabled,
    'connected_onboarding_enabled', controls.connected_onboarding_enabled,
    'job_funding_enabled', controls.job_funding_enabled,
    'transfers_enabled', controls.transfers_enabled,
    'refunds_enabled', controls.refunds_enabled,
    'live_mode_enabled', controls.live_mode_enabled,
    'configured', false,
    'provider', 'stripe'
  );
end;
$$;


--
-- Name: join_team_hustle_v1(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.join_team_hustle_v1(p_hustle_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_user uuid := auth.uid();
  v_role public.mort_role;
  v_dob date;
  v_age integer;
  v_hustle public.team_hustles%rowtype;
begin
  if v_user is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;

  select p.role, p.date_of_birth into v_role, v_dob
  from public.profiles p where p.id = v_user;
  v_age := case when v_dob is null then null else private.mort_age_years(v_dob) end;

  if v_role <> 'teen' or v_age is null or v_age not between 13 and 17 then
    return jsonb_build_object('ok', false, 'code', 'teen_required');
  end if;

  select * into v_hustle from public.team_hustles th where th.id = p_hustle_id;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'not_found');
  end if;
  if v_hustle.status <> 'open' then
    return jsonb_build_object('ok', false, 'code', 'hustle_closed');
  end if;
  if v_hustle.poster_id = v_user then
    return jsonb_build_object('ok', false, 'code', 'cannot_join_own_hustle');
  end if;
  if v_age < v_hustle.age_min or v_age > v_hustle.age_max then
    return jsonb_build_object('ok', false, 'code', 'age_out_of_range');
  end if;
  if exists (select 1 from public.team_hustle_members m
             where m.hustle_id = p_hustle_id and m.user_id = v_user) then
    return jsonb_build_object('ok', false, 'code', 'already_member');
  end if;
  if (select count(*) from public.team_hustle_members m
      where m.hustle_id = p_hustle_id) >= v_hustle.workers_needed then
    return jsonb_build_object('ok', false, 'code', 'hustle_full');
  end if;
  if (select count(*) from public.team_hustle_members m
      where m.user_id = v_user and m.joined_at > now() - interval '24 hours') >= 20 then
    return jsonb_build_object('ok', false, 'code', 'too_many_joins_today');
  end if;

  insert into public.team_hustle_members (hustle_id, user_id)
  values (p_hustle_id, v_user);

  return jsonb_build_object('ok', true);
end;
$$;


--
-- Name: leave_team_hustle_v1(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.leave_team_hustle_v1(p_hustle_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;

  delete from public.team_hustle_members m
  where m.hustle_id = p_hustle_id and m.user_id = v_user;

  if not found then
    return jsonb_build_object('ok', false, 'code', 'not_a_member');
  end if;
  return jsonb_build_object('ok', true);
end;
$$;


--
-- Name: list_my_message_threads_page(text, timestamp with time zone, uuid, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.list_my_message_threads_page(p_query text DEFAULT ''::text, p_cursor_updated_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_cursor_id uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 20) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_user_id uuid := (select auth.uid());
  v_query text := lower(btrim(coalesce(p_query, '')));
  v_limit integer := least(greatest(coalesce(p_limit, 20), 1), 50);
  v_items jsonb;
  v_has_more boolean;
  v_next_cursor jsonb;
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if not exists (
    select 1 from public.profiles as profile
    where profile.id = v_user_id and profile.account_status = 'active'
  ) then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;
  if (p_cursor_updated_at is null) <> (p_cursor_id is null) then
    return jsonb_build_object('ok', false, 'code', 'message_cursor_invalid');
  end if;

  with candidates as (
    select conversation.id, conversation.updated_at
    from public.conversations as conversation
    join public.conversation_members as member
      on member.conversation_id = conversation.id
     and member.user_id = v_user_id
    where (p_cursor_updated_at is null
      or (conversation.updated_at, conversation.id) < (p_cursor_updated_at, p_cursor_id))
      and (
        v_query = ''
        or exists (
          select 1
          from public.jobs as job
          where job.id = conversation.job_id
            and position(v_query in lower(job.title)) > 0
        )
        or exists (
          select 1
          from public.conversation_members as other_member
          join public.profiles as other_profile on other_profile.id = other_member.user_id
          where other_member.conversation_id = conversation.id
            and other_member.user_id <> v_user_id
            and position(v_query in lower(coalesce(other_profile.display_name, ''))) > 0
        )
        or exists (
          select 1 from public.messages as message
          where message.conversation_id = conversation.id
            and message.deleted_at is null
            and message.moderation_status = 'approved'
            and position(v_query in lower(message.body)) > 0
        )
      )
    order by conversation.updated_at desc, conversation.id desc
    limit v_limit + 1
  ), numbered as (
    select candidates.id, candidates.updated_at,
      row_number() over (order by candidates.updated_at desc, candidates.id desc) as row_number,
      private.message_thread_summary(candidates.id, v_user_id) as item
    from candidates
  )
  select coalesce(
      jsonb_agg(numbered.item order by numbered.updated_at desc, numbered.id desc)
        filter (where numbered.row_number <= v_limit),
      '[]'::jsonb
    ),
    count(*) > v_limit
  into v_items, v_has_more
  from numbered;

  if v_has_more then
    with candidates as (
      select conversation.id, conversation.updated_at
      from public.conversations as conversation
      join public.conversation_members as member
        on member.conversation_id = conversation.id
       and member.user_id = v_user_id
      where (p_cursor_updated_at is null
        or (conversation.updated_at, conversation.id) < (p_cursor_updated_at, p_cursor_id))
        and (
          v_query = ''
          or exists (select 1 from public.jobs as job
            where job.id = conversation.job_id
              and position(v_query in lower(job.title)) > 0)
          or exists (select 1 from public.conversation_members as other_member
            join public.profiles as other_profile on other_profile.id = other_member.user_id
            where other_member.conversation_id = conversation.id
              and other_member.user_id <> v_user_id
              and position(v_query in lower(coalesce(other_profile.display_name, ''))) > 0)
          or exists (select 1 from public.messages as message
            where message.conversation_id = conversation.id
              and message.deleted_at is null
              and message.moderation_status = 'approved'
              and position(v_query in lower(message.body)) > 0)
        )
      order by conversation.updated_at desc, conversation.id desc
      limit v_limit + 1
    )
    select jsonb_build_object('updated_at', candidates.updated_at, 'id', candidates.id)
      into v_next_cursor
    from candidates
    order by candidates.updated_at desc, candidates.id desc
    offset v_limit - 1 limit 1;
  end if;

  return jsonb_build_object(
    'items', v_items,
    'has_more', coalesce(v_has_more, false),
    'next_cursor', v_next_cursor
  );
end;
$$;


--
-- Name: list_my_saved_jobs(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.list_my_saved_jobs() RETURNS SETOF jsonb
    LANGUAGE sql STABLE
    SET search_path TO ''
    AS $$
select (to_jsonb(job)-array['exact_address','location_notes','neighborhood','zip_code','travel_radius_miles','transportation_considerations','safety_review_status','pay_amount','remote_allowed','age_min','age_max'])
|| jsonb_build_object('location_text',case when job.remote_allowed then 'Remote' else concat_ws(', ',job.city,job.region) end,'state',job.region,'adult_job_amount_cents',round(job.pay_amount*100)::integer,'pay_amount_cents',round(job.pay_amount*100)::integer,'pay_label',null,'profiles',jsonb_build_object('display_name',null,'verification_status',null,'avatar_path',null),'is_test',false,'teen_min_age',job.age_min,'teen_max_age',job.age_max,'distance_status','unavailable','transportation_match',null,'match_explanation',null,'neighborhood',null,'zip_code',null,'travel_radius_miles',null,'transportation_considerations',null)
from public.saved_jobs saved join public.jobs job on job.id=saved.job_id join public.profiles profile on profile.id=(select auth.uid())
where saved.user_id=(select auth.uid()) and profile.role='teen'::public.mort_role and profile.account_status='active' and job.status='open'::public.mort_job_status and job.safety_review_status='approved' and job.applications_open and (job.expires_at is null or job.expires_at>now()) and (profile.date_of_birth is null or extract(year from age(current_date,profile.date_of_birth)) between job.age_min and job.age_max)
order by saved.created_at desc;
$$;


--
-- Name: list_my_verification_cases_v1(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.list_my_verification_cases_v1() RETURNS jsonb
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', vc.id,
        'verification_type', vc.verification_type,
        'status', vc.status,
        'submitted_at', vc.submitted_at,
        'reviewed_at', vc.reviewed_at
      ) order by vc.created_at desc
    ),
    '[]'::jsonb
  )
  from public.verification_cases vc
  where vc.user_id = (select auth.uid());
$$;


--
-- Name: list_open_jobs_page(text, text, integer, text, text, text, boolean, text, text, text, text[], text, text, uuid, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.list_open_jobs_page(p_keyword text DEFAULT ''::text, p_category text DEFAULT NULL::text, p_minimum_pay_cents integer DEFAULT NULL::integer, p_payment_type text DEFAULT NULL::text, p_schedule_type text DEFAULT NULL::text, p_verification_requirement text DEFAULT NULL::text, p_requires_guardian_approval boolean DEFAULT NULL::boolean, p_work_environment text DEFAULT NULL::text, p_city text DEFAULT NULL::text, p_state text DEFAULT NULL::text, p_transportation_methods text[] DEFAULT NULL::text[], p_sort text DEFAULT 'newest'::text, p_cursor_value text DEFAULT NULL::text, p_cursor_id uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 20) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_profile public.profiles%rowtype;
  v_release public.mort_release_control%rowtype;
  v_job record;
  v_items jsonb := '[]'::jsonb;
  v_cursor jsonb;
  v_has_more boolean := false;
  v_count integer := 0;
  v_limit integer := greatest(1, least(coalesce(p_limit, 20), 50));
  v_age integer;
  v_cursor_time timestamptz;
  v_cursor_pay numeric;
  v_keyword text := lower(btrim(coalesce(p_keyword, '')));
  v_category text := nullif(lower(replace(btrim(coalesce(p_category, '')), ' ', '_')), '');
begin
  p_sort := coalesce(p_sort, 'newest');
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  select * into v_profile from public.profiles where id = auth.uid();
  if not found or v_profile.role <> 'teen'::public.mort_role or v_profile.account_status <> 'active' then
    return jsonb_build_object('ok', false, 'code', 'active_teen_account_required');
  end if;
  select * into v_release from public.mort_release_control where is_primary;
  if not found or v_release.maintenance_mode then
    return jsonb_build_object('ok', false, 'code', 'maintenance_mode_active');
  end if;
  if not v_release.public_marketplace_enabled then
    return jsonb_build_object('ok', false, 'code', 'public_marketplace_disabled');
  end if;
  if coalesce(p_sort, 'newest') not in ('newest', 'highest_pay', 'soonest_start') then
    return jsonb_build_object('ok', false, 'code', 'invalid_job_sort');
  end if;
  if p_cursor_value is not null and p_cursor_id is not null then
    if p_sort in ('newest', 'soonest_start') then
      begin
        v_cursor_time := p_cursor_value::timestamptz;
      exception when others then
        return jsonb_build_object('ok', false, 'code', 'invalid_job_cursor');
      end;
    else
      begin
        v_cursor_pay := p_cursor_value::numeric;
      exception when others then
        return jsonb_build_object('ok', false, 'code', 'invalid_job_cursor');
      end;
    end if;
  end if;
  if v_profile.date_of_birth is not null then
    v_age := extract(year from age(current_date, v_profile.date_of_birth))::integer;
  end if;

  for v_job in
    select j.*,
      p.display_name as poster_display_name,
      p.avatar_path as poster_avatar_path,
      case when exists (
        select 1 from public.verification_cases vc
        where vc.user_id = p.id and vc.verification_type = 'identity'
          and vc.status = 'verified'::public.mort_verification_status
          and (vc.expires_at is null or vc.expires_at > now())
      ) then 'approved' else 'pending' end as poster_verification_status,
      coalesce(j.published_at, j.created_at) as feed_published_at,
      coalesce(j.starts_at, 'infinity'::timestamptz) as feed_start_at
    from public.jobs j
    join public.profiles p on p.id = j.poster_id
    where p.account_status = 'active'
      and j.status = 'open'::public.mort_job_status
      and j.safety_review_status = 'approved'
      and j.applications_open
      and (j.expires_at is null or j.expires_at > now())
      and (v_age is null or (j.age_min <= v_age and j.age_max >= v_age))
      and (v_keyword = '' or lower(j.title || ' ' || j.description || ' ' || coalesce(j.summary, '')) like '%' || v_keyword || '%')
      and (v_category is null or j.category = v_category)
      and (p_minimum_pay_cents is null or round(j.pay_amount * 100)::integer >= p_minimum_pay_cents)
      and (p_payment_type is null or p_payment_type in ('any', '') or j.pay_type = p_payment_type)
      and (p_schedule_type is null or p_schedule_type in ('any', '') or j.schedule_type = p_schedule_type)
      and (p_requires_guardian_approval is null or j.requires_guardian_approval = p_requires_guardian_approval)
      and (p_work_environment is null or p_work_environment in ('any', '') or j.work_environment = p_work_environment)
      and (p_city is null or btrim(p_city) = '' or lower(j.city) = lower(btrim(p_city)))
      and (p_state is null or btrim(p_state) = '' or lower(j.region) = lower(btrim(p_state)))
      and (p_transportation_methods is null or cardinality(p_transportation_methods) = 0
        or j.acceptable_transportation_methods && p_transportation_methods)
      and (p_verification_requirement is null or p_verification_requirement in ('any', '')
        or (p_verification_requirement = 'required' and exists (
          select 1 from public.verification_cases vc
          where vc.user_id = p.id and vc.verification_type = 'identity'
            and vc.status = 'verified'::public.mort_verification_status
            and (vc.expires_at is null or vc.expires_at > now())
        )))
      and (p_cursor_id is null or p_cursor_value is null
        or (p_sort = 'newest' and (
          coalesce(j.published_at, j.created_at) < v_cursor_time
          or (coalesce(j.published_at, j.created_at) = v_cursor_time and j.id > p_cursor_id)
        ))
        or (p_sort = 'soonest_start' and (
          coalesce(j.starts_at, 'infinity'::timestamptz) > v_cursor_time
          or (coalesce(j.starts_at, 'infinity'::timestamptz) = v_cursor_time and j.id > p_cursor_id)
        ))
        or (p_sort = 'highest_pay' and (
          j.pay_amount < v_cursor_pay
          or (j.pay_amount = v_cursor_pay and j.id > p_cursor_id)
        )))
    order by
      case when p_sort = 'newest' then coalesce(j.published_at, j.created_at) end desc nulls last,
      case when p_sort = 'highest_pay' then j.pay_amount end desc nulls last,
      case when p_sort = 'soonest_start' then coalesce(j.starts_at, 'infinity'::timestamptz) end asc nulls last,
      j.id asc
    limit v_limit + 1
  loop
    if v_count >= v_limit then
      v_has_more := true;
      exit;
    end if;
    v_count := v_count + 1;
    v_cursor := jsonb_build_object(
      'value', case p_sort
        when 'highest_pay' then v_job.pay_amount::text
        when 'soonest_start' then v_job.feed_start_at::text
        else v_job.feed_published_at::text
      end,
      'id', v_job.id
    );
    v_items := v_items || jsonb_build_array(jsonb_build_object(
      'id', v_job.id,
      'poster_id', v_job.poster_id,
      'title', v_job.title,
      'summary', v_job.summary,
      'description', v_job.description,
      'category', v_job.category,
      'location_text', case when v_job.remote_allowed then 'Remote' else concat_ws(', ', v_job.city, v_job.region) end,
      'city', v_job.city,
      'state', v_job.region,
      'status', v_job.status::text,
      'requires_guardian_approval', v_job.requires_guardian_approval,
      'adult_job_amount_cents', round(v_job.pay_amount * 100)::integer,
      'mort_service_fee_cents', v_job.mort_service_fee_cents,
      'pay_amount_cents', round(v_job.pay_amount * 100)::integer,
      'pay_label', null,
      'starts_at', v_job.starts_at,
      'ends_at', v_job.ends_at,
      'deadline_at', v_job.deadline_at,
      'expires_at', v_job.expires_at,
      'published_at', v_job.published_at,
      'updated_at', v_job.updated_at,
      'profiles', jsonb_build_object(
        'display_name', v_job.poster_display_name,
        'verification_status', v_job.poster_verification_status,
        'avatar_path', v_job.poster_avatar_path
      ),
      'schedule_type', v_job.schedule_type,
      'payment_type', v_job.pay_type,
      'payment_method', v_job.payment_method,
      'payment_timing', v_job.payment_timing,
      'verification_requirement', v_job.verification_requirement,
      'work_environment', v_job.work_environment,
      'location_type', v_job.location_type,
      'experience_level', v_job.experience_level,
      'estimated_duration_minutes', v_job.estimated_duration_minutes,
      'workers_needed', v_job.workers_needed,
      'skills_needed', to_jsonb(v_job.skills_needed),
      'physical_requirements', to_jsonb(v_job.physical_requirements),
      'equipment_provided', v_job.equipment_provided,
      'equipment_worker_brings', v_job.equipment_worker_brings,
      'special_instructions', v_job.special_instructions,
      'safety_notes', v_job.safety_notes,
      'proof_expected', v_job.proof_expected,
      'adult_supervision_present', v_job.adult_supervision_present,
      'tip_allowed', v_job.tip_allowed,
      'applications_open', v_job.applications_open,
      'is_test', false,
      'recurring', v_job.recurring,
      'recurrence_rule', v_job.recurrence_rule,
      'timezone', v_job.timezone,
      'urgency', v_job.urgency,
      'neighborhood', null,
      'zip_code', null,
      'travel_radius_miles', null,
      'acceptable_transportation_methods', to_jsonb(v_job.acceptable_transportation_methods),
      'transportation_considerations', null,
      'teen_min_age', v_job.age_min,
      'teen_max_age', v_job.age_max,
      'distance_status', 'unavailable',
      'transportation_match', null,
      'match_explanation', null,
      'quick_accept_eligible', v_job.quick_accept_eligible
    ));
  end loop;

  return jsonb_build_object(
    'ok', true,
    'items', v_items,
    'has_more', v_has_more,
    'next_cursor', case when v_has_more then v_cursor else null end
  );
end;
$$;


--
-- Name: FUNCTION list_open_jobs_page(p_keyword text, p_category text, p_minimum_pay_cents integer, p_payment_type text, p_schedule_type text, p_verification_requirement text, p_requires_guardian_approval boolean, p_work_environment text, p_city text, p_state text, p_transportation_methods text[], p_sort text, p_cursor_value text, p_cursor_id uuid, p_limit integer); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.list_open_jobs_page(p_keyword text, p_category text, p_minimum_pay_cents integer, p_payment_type text, p_schedule_type text, p_verification_requirement text, p_requires_guardian_approval boolean, p_work_environment text, p_city text, p_state text, p_transportation_methods text[], p_sort text, p_cursor_value text, p_cursor_id uuid, p_limit integer) IS 'Authenticated teen marketplace feed. Requires production public-marketplace activation and never returns exact addresses.';


--
-- Name: list_team_hustles_v1(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.list_team_hustles_v1() RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    return '[]'::jsonb;
  end if;
  return coalesce((
    select jsonb_agg(row_to_json(h) order by (h.status = 'open') desc, h.created_at desc)
    from (
      select
        th.id, th.title, th.description, th.category, th.city, th.region,
        th.workers_needed, th.age_min, th.age_max, th.pay_amount, th.pay_type,
        th.location_notes, th.status, th.created_at,
        (select count(*) from public.team_hustle_members m
         where m.hustle_id = th.id)::int as joined_count,
        p.display_name as poster_display_name,
        exists(select 1 from public.team_hustle_members m
               where m.hustle_id = th.id and m.user_id = v_user) as my_membership,
        (th.poster_id = v_user) as i_am_poster
      from public.team_hustles th
      join public.profiles p on p.id = th.poster_id
      where th.created_at > now() - interval '60 days'
    ) h
  ), '[]'::jsonb);
end;
$$;


--
-- Name: list_thread_messages_page(uuid, timestamp with time zone, uuid, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.list_thread_messages_page(p_thread_id uuid, p_cursor_created_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_cursor_id uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 40) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_user_id uuid := (select auth.uid());
  v_limit integer := least(greatest(coalesce(p_limit, 40), 1), 100);
  v_items jsonb;
  v_has_more boolean;
  v_next_cursor jsonb;
  v_thread jsonb;
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_thread_id is null or not private.can_access_conversation(p_thread_id) then
    return jsonb_build_object('ok', false, 'code', 'conversation_unavailable');
  end if;
  if (p_cursor_created_at is null) <> (p_cursor_id is null) then
    return jsonb_build_object('ok', false, 'code', 'message_cursor_invalid');
  end if;

  v_thread := private.message_thread_summary(p_thread_id, v_user_id);
  if v_thread is null then
    return jsonb_build_object('ok', false, 'code', 'conversation_unavailable');
  end if;

  with candidates as (
    select message.id, message.conversation_id, message.sender_id,
      message.body, message.moderation_status, message.created_at
    from public.messages as message
    where message.conversation_id = p_thread_id
      and message.deleted_at is null
      and (
        message.moderation_status = 'approved'
        or message.sender_id = v_user_id
      )
      and (p_cursor_created_at is null
        or (message.created_at, message.id) < (p_cursor_created_at, p_cursor_id))
    order by message.created_at desc, message.id desc
    limit v_limit + 1
  ), numbered as (
    select candidates.*,
      row_number() over (order by candidates.created_at desc, candidates.id desc) as row_number
    from candidates
  )
  select coalesce(
      jsonb_agg(jsonb_build_object(
        'id', numbered.id,
        'thread_id', numbered.conversation_id,
        'sender_id', numbered.sender_id,
        'body', numbered.body,
        'scanner_status', numbered.moderation_status,
        'scanner_reason', null,
        'created_at', numbered.created_at
      ) order by numbered.created_at desc, numbered.id desc)
        filter (where numbered.row_number <= v_limit),
      '[]'::jsonb
    ),
    count(*) > v_limit
  into v_items, v_has_more
  from numbered;

  if v_has_more then
    with candidates as (
      select message.id, message.created_at
      from public.messages as message
      where message.conversation_id = p_thread_id
        and message.deleted_at is null
        and (
          message.moderation_status = 'approved'
          or message.sender_id = v_user_id
        )
        and (p_cursor_created_at is null
          or (message.created_at, message.id) < (p_cursor_created_at, p_cursor_id))
      order by message.created_at desc, message.id desc
      limit v_limit + 1
    )
    select jsonb_build_object('created_at', candidates.created_at, 'id', candidates.id)
      into v_next_cursor
    from candidates
    order by candidates.created_at desc, candidates.id desc
    offset v_limit - 1 limit 1;
  end if;

  return jsonb_build_object(
    'items', v_items,
    'has_more', coalesce(v_has_more, false),
    'next_cursor', v_next_cursor,
    'lifecycle_status', v_thread->>'lifecycle_status',
    'thread', v_thread
  );
end;
$$;


--
-- Name: manage_job_v2(uuid, text, text, uuid, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.manage_job_v2(p_job_id uuid, p_action text, p_reason text DEFAULT NULL::text, p_client_request_id uuid DEFAULT NULL::uuid, p_expected_updated_at timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_user uuid := auth.uid();
  v_job public.jobs%rowtype;
  v_copy public.jobs%rowtype;
  v_previous_status public.mort_job_status;
  v_response jsonb;
  v_hash text;
  v_action text := coalesce(nullif(p_action,''),'');
  v_inserted integer;
  v_request_exists boolean := false;
  v_public_enabled boolean;
  v_maintenance boolean;
begin
  if v_user is null or not private.is_active_user() or private.current_role() <> 'adult'::public.mort_role then
    return jsonb_build_object('ok',false,'code','active_adult_account_required');
  end if;
  if p_job_id is null or p_client_request_id is null or v_action not in ('pause','resume','cancel','delete_draft','duplicate') then
    return jsonb_build_object('ok',false,'code','job_action_invalid');
  end if;
  select response,request_hash into v_response,v_hash from private.mort_job_mutation_requests
  where user_id=v_user and client_request_id=p_client_request_id;
  v_request_exists := found;
  if found then
    if v_hash <> md5(p_job_id::text||'|'||v_action||'|'||coalesce(p_reason,'')||'|'||coalesce(p_expected_updated_at::text,'')) then
      return jsonb_build_object('ok',false,'code','idempotency_key_reused');
    end if;
    if v_response is not null then return v_response || jsonb_build_object('replayed',true); end if;
  end if;

  select * into v_job from public.jobs where id=p_job_id and poster_id=v_user for update;
  if not found then return jsonb_build_object('ok',false,'code','job_not_available'); end if;
  v_previous_status := v_job.status;
  select response,request_hash into v_response,v_hash from private.mort_job_mutation_requests
  where user_id=v_user and client_request_id=p_client_request_id;
  v_request_exists := found;
  if found and v_response is not null then return v_response || jsonb_build_object('replayed',true); end if;
  if p_expected_updated_at is not null and v_job.updated_at<>p_expected_updated_at then
    return jsonb_build_object('ok',false,'code','job_changed_refresh');
  end if;
  if v_action='cancel' and char_length(btrim(coalesce(p_reason,'')))<10 then
    return jsonb_build_object('ok',false,'code','job_cancellation_reason_required');
  end if;
  if v_action='pause' and v_job.status<>'open'::public.mort_job_status then
    return jsonb_build_object('ok',false,'code','job_not_open');
  end if;
  if v_action='cancel' and v_job.status not in ('open'::public.mort_job_status,'paused'::public.mort_job_status,'under_review'::public.mort_job_status) then
    return jsonb_build_object('ok',false,'code','job_not_cancellable');
  end if;
  if v_action='delete_draft' and (v_job.status<>'draft'::public.mort_job_status
      or exists(select 1 from public.job_applications where job_id=v_job.id)
      or exists(select 1 from public.job_assignments where job_id=v_job.id)
      or exists(select 1 from public.conversations where job_id=v_job.id)) then
    return jsonb_build_object('ok',false,'code','job_draft_not_deletable');
  end if;
  if v_action='resume' then
    select public_marketplace_enabled,maintenance_mode into v_public_enabled,v_maintenance from public.mort_release_control where is_primary;
    if not coalesce(v_public_enabled,false) or coalesce(v_maintenance,true) then
      return jsonb_build_object('ok',false,'code','marketplace_unavailable');
    end if;
    if v_job.safety_review_status<>'approved' or v_job.status<>'paused'::public.mort_job_status then
      return jsonb_build_object('ok',false,'code','job_not_resumable');
    end if;
  end if;

  v_hash := md5(p_job_id::text||'|'||v_action||'|'||coalesce(p_reason,'')||'|'||coalesce(p_expected_updated_at::text,''));
  if not v_request_exists then
    insert into private.mort_job_mutation_requests(user_id,client_request_id,operation,request_hash)
    values(v_user,p_client_request_id,'manage_job',v_hash) on conflict do nothing;
    get diagnostics v_inserted = row_count;
    if v_inserted=0 then
      select request_hash,response into v_hash,v_response from private.mort_job_mutation_requests
      where user_id=v_user and client_request_id=p_client_request_id for update;
      if v_response is not null then return v_response || jsonb_build_object('replayed',true); end if;
      return jsonb_build_object('ok',false,'code','job_action_in_progress');
    end if;
  end if;

  perform set_config('mort.job_action',v_action,true);
  if v_action='pause' then
    update public.jobs set status='paused'::public.mort_job_status,applications_open=false where id=v_job.id returning * into v_job;
  elsif v_action='resume' then
    update public.jobs set status='open'::public.mort_job_status,applications_open=true where id=v_job.id returning * into v_job;
  elsif v_action='cancel' then
    update public.jobs set status='cancelled'::public.mort_job_status,applications_open=false where id=v_job.id returning * into v_job;
    insert into public.admin_audit_log(actor_id,action,target_type,target_id,reason,metadata)
    values(v_user,'job_cancelled','job',v_job.id::text,nullif(btrim(p_reason),''),jsonb_build_object('previous_status',v_previous_status));
    insert into public.notifications(user_id,notification_type,title,body,data)
    select distinct ja.applicant_id,'job_update','Job cancelled','The job poster cancelled this job.',jsonb_build_object('job_id',v_job.id)
    from public.job_applications ja where ja.job_id=v_job.id and ja.status in ('submitted'::public.mort_application_status,'shortlisted'::public.mort_application_status);
  elsif v_action='duplicate' then
    select (jsonb_populate_record(null::public.jobs,to_jsonb(v_job)||jsonb_build_object(
      'id',gen_random_uuid(),'status','draft','safety_review_status','pending','applications_open',false,
      'published_at',null,'exact_address',null,'location_notes',null,'created_at',now(),'updated_at',now()
    ))).* into v_copy;
    insert into public.jobs select v_copy.* returning * into v_copy;
    v_job := v_copy;
  elsif v_action='delete_draft' then
    insert into public.admin_audit_log(actor_id,action,target_type,target_id,reason,metadata)
    values(v_user,'job_draft_deleted','job',v_job.id::text,null,jsonb_build_object('status',v_job.status));
    delete from public.jobs where id=v_job.id;
    v_response := jsonb_build_object('ok',true,'job',null,'replayed',false);
    update private.mort_job_mutation_requests set response=v_response where user_id=v_user and client_request_id=p_client_request_id;
    return v_response;
  end if;

  v_response := jsonb_build_object('ok',true,'job',to_jsonb(v_job)-'exact_address','replayed',false);
  update private.mort_job_mutation_requests set response=v_response where user_id=v_user and client_request_id=p_client_request_id;
  return v_response;
end;
$$;


--
-- Name: FUNCTION manage_job_v2(p_job_id uuid, p_action text, p_reason text, p_client_request_id uuid, p_expected_updated_at timestamp with time zone); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.manage_job_v2(p_job_id uuid, p_action text, p_reason text, p_client_request_id uuid, p_expected_updated_at timestamp with time zone) IS 'Performs allowlisted adult-owned job lifecycle actions with concurrency checks and idempotency.';


--
-- Name: mark_message_thread_read(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.mark_message_thread_read(p_thread_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_user_id uuid := (select auth.uid());
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_thread_id is null or not private.can_access_conversation(p_thread_id) then
    return jsonb_build_object('ok', false, 'code', 'conversation_unavailable');
  end if;

  update public.conversation_members
  set last_read_at = now()
  where conversation_id = p_thread_id and user_id = v_user_id;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'conversation_unavailable');
  end if;
  return jsonb_build_object('ok', true);
end;
$$;


--
-- Name: mort_accept_job_application(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.mort_accept_job_application(p_application_id uuid) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
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
$$;


--
-- Name: FUNCTION mort_accept_job_application(p_application_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.mort_accept_job_application(p_application_id uuid) IS 'Accepts an eligible application and rechecks current teen age, adult identity, block, and required guardian consent before creating an assignment.';


--
-- Name: mort_admin_list_users_v1(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.mort_admin_list_users_v1(p_limit integer DEFAULT 200) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin
  if not private.has_staff_role(array['admin']::public.mort_role[]) then
    return jsonb_build_object('ok', false, 'code', 'admin_required');
  end if;

  return coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'id', p.id,
        'email', u.email,
        'display_name', p.display_name,
        'role', p.role,
        'account_status', p.account_status,
        'verification_status', p.verification_status,
        'created_at', p.created_at
      ) order by p.created_at desc
    )
    from (
      select id, display_name, role, account_status, verification_status, created_at
      from public.profiles
      order by created_at desc
      limit least(greatest(coalesce(p_limit, 200), 1), 500)
    ) p
    join auth.users u on u.id = p.id
  ), '[]'::jsonb);
end;
$$;


--
-- Name: mort_ingest_verification_provider_event(text, text, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.mort_ingest_verification_provider_event(p_project_ref text, p_provider_key text, p_timestamp text, p_signature text, p_raw_body text) RETURNS jsonb
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO ''
    AS $$
  select private.ingest_verification_provider_event(
    p_project_ref, p_provider_key, p_timestamp, p_signature, p_raw_body
  );
$$;


--
-- Name: FUNCTION mort_ingest_verification_provider_event(p_project_ref text, p_provider_key text, p_timestamp text, p_signature text, p_raw_body text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.mort_ingest_verification_provider_event(p_project_ref text, p_provider_key text, p_timestamp text, p_signature text, p_raw_body text) IS 'Issue #50: trusted ingestion boundary for verification provider events. Service-role only; verifies provider HMAC signature, tenant binding, case binding, allowlist, freshness, and replay idempotency before any insert.';


--
-- Name: mort_moderate_message(uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.mort_moderate_message(p_message_id uuid, p_status text, p_reason text DEFAULT NULL::text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null or not private.has_staff_role(array['admin','moderator']::public.mort_role[]) then
    raise exception 'Authorized moderation role required';
  end if;
  if p_status not in ('approved','flagged','blocked','removed') then
    raise exception 'Invalid moderation outcome';
  end if;
  update public.messages
  set moderation_status=p_status, moderation_reason=nullif(btrim(p_reason),'')
  where id=p_message_id;
  if not found then raise exception 'Message not found'; end if;
  insert into public.admin_audit_log(actor_id,action,target_type,target_id,reason,metadata)
  values (v_user,'message_moderated','message',p_message_id::text,
          nullif(btrim(p_reason),''),jsonb_build_object('status',p_status));
  return p_message_id;
end;
$$;


--
-- Name: mort_record_staff_document_review(uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.mort_record_staff_document_review(p_case_id uuid, p_decision text, p_note text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_user uuid := auth.uid();
  v_case public.verification_cases%rowtype;
  v_sha text;
begin
  if v_user is null or not private.has_staff_role(array['admin','moderator']::public.mort_role[]) then
    return jsonb_build_object('ok', false, 'code', 'authorized_reviewer_required');
  end if;
  if p_decision is null or p_decision not in ('verified','rejected') then
    return jsonb_build_object('ok', false, 'code', 'invalid_decision');
  end if;

  select * into v_case
  from public.verification_cases vc
  where vc.id = p_case_id
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'case_not_found');
  end if;
  if v_case.provider is distinct from 'mort_staff_review' then
    return jsonb_build_object('ok', false, 'code', 'not_staff_review_case');
  end if;
  if v_case.status not in ('pending','needs_review') then
    return jsonb_build_object('ok', false, 'code', 'case_already_decided');
  end if;
  if v_case.evidence_path is null then
    return jsonb_build_object('ok', false, 'code', 'no_evidence_document');
  end if;
  if not exists (
    select 1 from storage.objects o
    where o.bucket_id = 'verification-evidence'
      and o.name = v_case.evidence_path
  ) then
    return jsonb_build_object('ok', false, 'code', 'evidence_document_missing');
  end if;
  if not exists (
    select 1 from private.verification_provider_allowlist a
    where a.provider_key = 'mort_staff_review'
      and a.verification_type = v_case.verification_type
      and a.is_enabled
  ) then
    return jsonb_build_object('ok', false, 'code', 'provider_not_allowlisted');
  end if;

  v_sha := encode(extensions.digest(convert_to(
    v_case.id::text || '|' || v_case.evidence_path || '|' || v_user::text || '|' || p_decision,
    'UTF8'), 'sha256'), 'hex');

  insert into private.verification_provider_results (
    verification_case_id, user_id, verification_type, provider_key,
    provider_reference, provider_event_id, result, evidence_sha256,
    verified_at, expires_at
  ) values (
    v_case.id, v_case.user_id, v_case.verification_type, 'mort_staff_review',
    v_case.provider_reference,
    'staff-' || v_case.id::text || '-' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISSUS'),
    p_decision, v_sha,
    case when p_decision = 'verified' then clock_timestamp() else null end,
    null
  );

  insert into public.admin_audit_log (actor_id, action, target_type, target_id, reason, metadata)
  values (v_user, 'staff_document_review_recorded', 'verification_case', v_case.id::text,
          nullif(btrim(coalesce(p_note, '')), ''),
          jsonb_build_object(
            'decision', p_decision,
            'verification_type', v_case.verification_type,
            'evidence_path', v_case.evidence_path,
            'provider_key', 'mort_staff_review'));

  return jsonb_build_object('ok', true, 'decision', p_decision);
end;
$$;


--
-- Name: FUNCTION mort_record_staff_document_review(p_case_id uuid, p_decision text, p_note text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.mort_record_staff_document_review(p_case_id uuid, p_decision text, p_note text) IS 'Issue #50: staff-only attestation that the reviewer examined the case''s uploaded evidence document and reached a decision. Records an immutable, case-bound provider result for the internal mort_staff_review provider; mort_review_verification_case still requires this evidence before any verified outcome.';


--
-- Name: mort_review_job(uuid, boolean, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.mort_review_job(p_job_id uuid, p_approve boolean, p_reason text DEFAULT NULL::text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_user uuid := auth.uid();
  v_job public.jobs%rowtype;
begin
  if v_user is null or not private.has_staff_role(array['admin','moderator']::public.mort_role[]) then
    raise exception 'Authorized moderation role required';
  end if;
  select * into v_job from public.jobs where id=p_job_id for update;
  if not found or v_job.status<>'under_review'::public.mort_job_status
      or v_job.safety_review_status not in ('pending','flagged') then
    raise exception 'Job is not awaiting safety review';
  end if;
  perform set_config('mort.job_action',case when p_approve then 'moderator_approved' else 'moderator_rejected' end,true);
  if p_approve then
    update public.jobs set safety_review_status='approved',
      status='open'::public.mort_job_status,applications_open=true,
      published_at=now(),updated_at=now()
    where id=p_job_id;
  else
    update public.jobs set safety_review_status='rejected',
      status='under_review'::public.mort_job_status,applications_open=false,updated_at=now()
    where id=p_job_id;
  end if;
  insert into public.admin_audit_log(actor_id,action,target_type,target_id,reason,metadata)
  values(v_user,case when p_approve then 'job_approved' else 'job_rejected' end,
    'job',p_job_id::text,nullif(btrim(p_reason),''),
    jsonb_build_object('previous_status',v_job.status,'approved',p_approve));
  return p_job_id;
end;
$$;


--
-- Name: mort_review_role_request(uuid, boolean, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.mort_review_role_request(p_request_id uuid, p_approve boolean, p_reason text DEFAULT NULL::text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_user uuid := auth.uid();
  v_req public.role_requests%rowtype;
begin
  if v_user is null or not private.has_staff_role(array['admin']::public.mort_role[]) then
    raise exception 'Administrator role required for role approval';
  end if;

  select * into v_req from public.role_requests where id=p_request_id for update;
  if not found or v_req.status <> 'pending' then
    raise exception 'Pending role request not found';
  end if;

  if p_approve then
    if v_req.requested_role='teen'::public.mort_role then
      if not exists (
        select 1 from public.verification_cases vc
        where vc.user_id=v_req.user_id and vc.verification_type='age'
          and vc.status='verified'::public.mort_verification_status
          and (vc.expires_at is null or vc.expires_at>now())
      ) or not exists (
        select 1 from public.verification_cases vc
        where vc.user_id=v_req.user_id and vc.verification_type='school_id'
          and vc.status='verified'::public.mort_verification_status
          and (vc.expires_at is null or vc.expires_at>now())
      ) or not exists (
        select 1 from public.verification_cases vc
        where vc.user_id=v_req.user_id and vc.verification_type='school_email'
          and vc.status='verified'::public.mort_verification_status
          and (vc.expires_at is null or vc.expires_at>now())
      ) then
        raise exception 'Teen approval requires verified age, school ID, and school email';
      end if;
    elsif v_req.requested_role='adult'::public.mort_role then
      if not exists (
        select 1 from public.verification_cases vc
        where vc.user_id=v_req.user_id and vc.verification_type='identity'
          and vc.status='verified'::public.mort_verification_status
          and (vc.expires_at is null or vc.expires_at>now())
      ) then
        raise exception 'Adult approval requires verified identity';
      end if;
    else
      raise exception 'Unsupported requested role';
    end if;

    update public.profiles
    set role=v_req.requested_role, account_status='active', updated_at=now()
    where id=v_req.user_id;
    if not found then raise exception 'Profile not found'; end if;
    update public.role_requests
    set status='approved', reviewed_at=now(), reviewed_by=v_user,
        review_note=nullif(btrim(p_reason),'')
    where id=p_request_id;
  else
    update public.role_requests
    set status='rejected', reviewed_at=now(), reviewed_by=v_user,
        review_note=nullif(btrim(p_reason),'')
    where id=p_request_id;
  end if;

  insert into public.admin_audit_log(actor_id,action,target_type,target_id,reason,metadata)
  values (v_user,case when p_approve then 'role_request_approved' else 'role_request_rejected' end,
          'role_request',p_request_id::text,nullif(btrim(p_reason),''),
          jsonb_build_object('user_id',v_req.user_id,'requested_role',v_req.requested_role));
  return p_request_id;
end;
$$;


--
-- Name: mort_review_verification_case(uuid, public.mort_verification_status, text, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.mort_review_verification_case(p_case_id uuid, p_status public.mort_verification_status, p_note text DEFAULT NULL::text, p_expires_at timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_user uuid := auth.uid();
  v_owner uuid;
  v_snapshot public.verification_cases%rowtype;
  v_case public.verification_cases%rowtype;
  v_date_of_birth date;
  v_now timestamptz;
  v_evidence_result_id uuid;
  v_evidence_expires_at timestamptz;
begin
  if v_user is null or not private.has_staff_role(array['admin','moderator']::public.mort_role[]) then
    raise exception 'Authorized verification reviewer required';
  end if;
  if p_status not in ('verified'::public.mort_verification_status,
                      'rejected'::public.mort_verification_status,
                      'needs_review'::public.mort_verification_status,
                      'expired'::public.mort_verification_status) then
    raise exception 'Invalid review outcome';
  end if;

  -- Unlocked snapshot to discover the subject. Lock order for approvals:
  -- profile -> allowlist -> case -> provider result.
  select * into v_snapshot
  from public.verification_cases vc
  where vc.id = p_case_id;
  if not found then raise exception 'Verification case not found'; end if;
  v_owner := v_snapshot.user_id;

  if p_status = 'verified'::public.mort_verification_status then
    select profile.date_of_birth into v_date_of_birth
    from public.profiles profile
    where profile.id = v_owner
      for share;
    if not found or v_date_of_birth is null
       or extract(year from age(current_date, v_date_of_birth)) < 13 then
      raise exception 'minimum_age_verification_required';
    end if;

    -- Fail-closed provider allowlist: empty table means no approvals.
    perform provider.provider_key
    from private.verification_provider_allowlist provider
    where provider.provider_key = v_snapshot.provider
      and provider.verification_type = v_snapshot.verification_type
      and provider.is_enabled
    for share;
    if not found then
      raise exception 'trusted_verification_provider_unavailable';
    end if;
  end if;

  v_now := clock_timestamp();
  if p_expires_at is not null and p_expires_at <= v_now then
    raise exception 'verification_expiry_must_be_in_future';
  end if;

  -- Lock the case and refuse to apply a decision to changed details.
  select * into v_case
  from public.verification_cases vc
  where vc.id = p_case_id
    for update;
  if not found then raise exception 'Verification case not found'; end if;
  if v_case.user_id is distinct from v_snapshot.user_id
     or v_case.provider is distinct from v_snapshot.provider
     or v_case.verification_type is distinct from v_snapshot.verification_type
     or v_case.provider_reference is distinct from v_snapshot.provider_reference
     or v_case.status is distinct from v_snapshot.status
     or v_case.updated_at is distinct from v_snapshot.updated_at then
    raise exception 'verification_case_changed_retry';
  end if;

  if p_status = 'verified'::public.mort_verification_status then
    -- Case-bound evidence: same subject, provider, reference, and type;
    -- verified after submission, received after submission, not expired.
    select result.id, result.expires_at
      into v_evidence_result_id, v_evidence_expires_at
    from private.verification_provider_results result
    where result.verification_case_id = v_case.id
      and result.user_id = v_case.user_id
      and result.verification_type = v_case.verification_type
      and result.provider_key = v_case.provider
      and result.provider_reference is not distinct from v_case.provider_reference
      and result.result = 'verified'
      and result.verified_at <= v_now
      and result.verified_at >= coalesce(v_case.submitted_at, v_case.created_at)
      and result.received_at <= v_now
      and result.received_at >= coalesce(v_case.submitted_at, v_case.created_at)
      and (result.expires_at is null or result.expires_at > v_now)
    order by result.received_at desc
    limit 1
    for share;
    if not found then
      raise exception 'case_appropriate_provider_evidence_required';
    end if;
    -- The verification cannot outlive the provider evidence it rests on.
    if v_evidence_expires_at is not null
       and (p_expires_at is null or p_expires_at > v_evidence_expires_at) then
      raise exception 'review_expiry_exceeds_provider_evidence';
    end if;
  end if;

  update public.verification_cases
  set status=p_status, reviewer_id=v_user,
      reviewer_note=nullif(btrim(p_note),''),
      reviewed_at=v_now, expires_at=p_expires_at, updated_at=v_now
  where id=p_case_id;

  update public.profiles
  set verification_status = case p_status
        when 'verified' then 'verified'
        when 'rejected' then 'rejected'
        when 'needs_review' then 'pending'
        when 'expired' then 'expired'
      end,
      updated_at = now()
  where id = v_owner;

  insert into public.admin_audit_log(actor_id,action,target_type,target_id,reason,metadata)
  values (v_user,'verification_reviewed','verification_case',p_case_id::text,
          nullif(btrim(p_note),''),
          jsonb_build_object(
            'status', p_status,
            'provider_result_id', v_evidence_result_id,
            'provider_key', case when p_status = 'verified'::public.mort_verification_status then v_case.provider else null end
          ));
  return p_case_id;
end;
$$;


--
-- Name: mort_send_message(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.mort_send_message(p_conversation_id uuid, p_body text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_user uuid := auth.uid();
  v_message uuid;
  v_other_user uuid;
  v_conversation public.conversations%rowtype;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if not private.is_active_user() then raise exception 'Active account required'; end if;
  if private.is_guardian_paused(v_user) then
    raise exception 'Your guardian has paused your account. Ask them to resume it before messaging.';
  end if;
  if p_body is null or char_length(btrim(p_body)) < 1 or char_length(p_body) > 4000 then
    raise exception 'Message must contain 1 to 4000 characters';
  end if;
  select * into v_conversation
  from public.conversations conversation
  where conversation.id = p_conversation_id
  for update;
  if not found or v_conversation.status <> 'active' or not exists (
    select 1 from public.conversation_members member
    where member.conversation_id = p_conversation_id and member.user_id = v_user
  ) then
    raise exception 'Conversation unavailable';
  end if;
  for v_other_user in
    select member.user_id
    from public.conversation_members member
    where member.conversation_id = p_conversation_id
      and member.user_id <> v_user
    order by member.user_id
  loop
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(
        least(v_user, v_other_user)::text || ':' || greatest(v_user, v_other_user)::text,
        0
      )
    );
  end loop;
  if exists (
    select 1
    from public.conversation_members mine
    join public.conversation_members theirs
      on theirs.conversation_id = mine.conversation_id
     and theirs.user_id <> v_user
    join public.user_blocks block
      on (block.blocker_id = v_user and block.blocked_id = theirs.user_id)
      or (block.blocker_id = theirs.user_id and block.blocked_id = v_user)
    where mine.conversation_id = p_conversation_id
      and mine.user_id = v_user
  ) then
    raise exception 'Messaging is unavailable';
  end if;
  insert into public.messages(conversation_id, sender_id, body, moderation_status)
  values (p_conversation_id, v_user, btrim(p_body), 'pending')
  returning id into v_message;
  update public.conversations set updated_at = now() where id = p_conversation_id;
  return v_message;
end;
$$;


--
-- Name: mort_set_guardian_consent(uuid, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.mort_set_guardian_consent(p_link_id uuid, p_accept boolean) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
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


--
-- Name: mort_set_guardian_pause_v1(uuid, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.mort_set_guardian_pause_v1(p_teen_id uuid, p_paused boolean) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_user uuid := auth.uid();
  v_target_role public.mort_role;
begin
  -- Note: private.is_active_user() deliberately excludes the 'guardian'
  -- role (it guards teen/adult marketplace actions). Guardians must be
  -- able to call this RPC, so the active-account check here is explicit
  -- and role-agnostic.
  if v_user is null or not exists (
    select 1 from public.profiles
    where id = v_user and account_status = 'active'
  ) then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;

  -- The caller must be an admin staff member, or a guardian with an active,
  -- mutually-consented link to this teen.
  if not private.has_staff_role(array['admin']::public.mort_role[]) and not exists (
    select 1
    from public.guardian_links gl
    where gl.guardian_user_id = v_user
      and gl.teen_user_id = p_teen_id
      and gl.status = 'active'
      and gl.teen_consent_at is not null
      and gl.guardian_consent_at is not null
  ) then
    return jsonb_build_object('ok', false, 'code', 'active_guardian_link_required');
  end if;

  select role into v_target_role from public.profiles where id = p_teen_id for update;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'target_user_not_found');
  end if;
  if v_target_role is distinct from 'teen'::public.mort_role then
    return jsonb_build_object('ok', false, 'code', 'target_must_be_teen');
  end if;

  update public.profiles
  set guardian_paused = p_paused,
      guardian_paused_at = now(),
      guardian_paused_by = v_user,
      updated_at = now()
  where id = p_teen_id;

  insert into public.admin_audit_log (actor_id, action, target_type, target_id, reason, metadata)
  values (
    v_user,
    'guardian_pause_set',
    'profile',
    p_teen_id::text,
    case when p_paused then 'Teen activity paused by guardian' else 'Teen activity resumed by guardian' end,
    jsonb_build_object('paused', p_paused)
  );

  return jsonb_build_object('ok', true, 'paused', p_paused);
end;
$$;


--
-- Name: mort_submit_job_application(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.mort_submit_job_application(p_job_id uuid, p_cover_note text DEFAULT NULL::text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
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
  if private.is_guardian_paused(v_user_id) then
    raise exception 'Your guardian has paused your account. Ask them to resume it before applying to jobs.';
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


--
-- Name: report_finish_pin_unavailable(uuid, timestamp with time zone, timestamp with time zone, text, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.report_finish_pin_unavailable(p_application_id uuid, p_actual_start_at timestamp with time zone, p_actual_finish_at timestamp with time zone, p_work_completed text, p_statement text, p_client_request_id uuid) RETURNS jsonb
    LANGUAGE sql
    SET search_path TO ''
    AS $$
  select private.report_finish_pin_unavailable_internal(
    p_application_id, p_actual_start_at, p_actual_finish_at,
    p_work_completed, p_statement, p_client_request_id
  );
$$;


--
-- Name: report_possible_teen_abandonment(uuid, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.report_possible_teen_abandonment(p_application_id uuid, p_statement text, p_client_request_id uuid) RETURNS jsonb
    LANGUAGE sql
    SET search_path TO ''
    AS $$
  select private.report_possible_teen_abandonment_internal(
    p_application_id, p_statement, p_client_request_id
  );
$$;


--
-- Name: request_adult_job_cancellation(uuid, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.request_adult_job_cancellation(p_application_id uuid, p_reason text, p_client_request_id uuid) RETURNS jsonb
    LANGUAGE sql
    SET search_path TO ''
    AS $$
  select private.request_adult_job_cancellation_internal(
    p_application_id, p_reason, p_client_request_id
  );
$$;


--
-- Name: request_job_contract_change(uuid, jsonb, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.request_job_contract_change(p_contract_id uuid, p_patch jsonb, p_reason text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $_$
declare
  v_user uuid := auth.uid();
  v_contract public.job_contracts%rowtype;
  v_base public.job_contract_versions%rowtype;
  v_terms jsonb;
  v_categories text[] := '{}'::text[];
  v_change_id uuid;
  v_role text;
begin
  if v_user is null then return jsonb_build_object('ok', false, 'code', 'authentication_required'); end if;
  if jsonb_typeof(p_patch) <> 'object' or p_patch = '{}'::jsonb then
    return jsonb_build_object('ok', false, 'code', 'change_terms_required');
  end if;
  if char_length(btrim(coalesce(p_reason, ''))) not between 8 and 1000 then
    return jsonb_build_object('ok', false, 'code', 'change_reason_required');
  end if;
  if exists (
    select 1 from jsonb_object_keys(p_patch) as key_name
    where key_name not in ('agreed_scope', 'amount_type', 'fixed_total_cents', 'hourly_rate_cents', 'maximum_approved_hours')
  ) then
    return jsonb_build_object('ok', false, 'code', 'unsupported_material_change');
  end if;

  select * into v_contract from public.job_contracts where id = p_contract_id for update;
  if not found or v_contract.status <> 'active' then
    return jsonb_build_object('ok', false, 'code', 'active_contract_required');
  end if;
  if v_user = v_contract.teen_id then v_role := 'teen';
  elsif v_user = v_contract.adult_id then v_role := 'adult';
  else return jsonb_build_object('ok', false, 'code', 'contract_party_required'); end if;
  select * into v_base from public.job_contract_versions where id = v_contract.active_version_id;
  if not found then return jsonb_build_object('ok', false, 'code', 'active_contract_version_missing'); end if;

  v_terms := v_base.terms_snapshot || p_patch;
  if p_patch ? 'agreed_scope' then
    if jsonb_typeof(p_patch->'agreed_scope') <> 'string'
       or char_length(btrim(v_terms->>'agreed_scope')) not between 1 and 4000 then
      return jsonb_build_object('ok', false, 'code', 'invalid_agreed_scope');
    end if;
    v_categories := array_append(v_categories, 'scope');
  end if;
  if p_patch ?| array['amount_type', 'fixed_total_cents', 'hourly_rate_cents', 'maximum_approved_hours'] then
    if v_terms->>'amount_type' = 'fixed' then
      if coalesce(v_terms->>'fixed_total_cents', '') !~ '^[0-9]{1,9}$'
         or (v_terms->>'fixed_total_cents')::bigint > 50000000 then
        return jsonb_build_object('ok', false, 'code', 'invalid_fixed_total');
      end if;
      v_terms := jsonb_set(v_terms - 'hourly_rate_cents' - 'maximum_approved_hours', '{fixed_total_cents}', to_jsonb((v_terms->>'fixed_total_cents')::integer), true);
    elsif v_terms->>'amount_type' = 'hourly' then
      if coalesce(v_terms->>'hourly_rate_cents', '') !~ '^[0-9]{1,9}$'
         or coalesce(v_terms->>'maximum_approved_hours', '') !~ '^[0-9]{1,3}(\.[0-9]{1,2})?$'
         or (v_terms->>'hourly_rate_cents')::bigint > 50000000
         or (v_terms->>'maximum_approved_hours')::numeric <= 0
         or (v_terms->>'maximum_approved_hours')::numeric > 1000 then
        return jsonb_build_object('ok', false, 'code', 'invalid_hourly_terms');
      end if;
      v_terms := jsonb_set(v_terms - 'fixed_total_cents', '{hourly_rate_cents}', to_jsonb((v_terms->>'hourly_rate_cents')::integer), true);
      v_terms := jsonb_set(v_terms, '{maximum_approved_hours}', to_jsonb((v_terms->>'maximum_approved_hours')::numeric), true);
    else
      return jsonb_build_object('ok', false, 'code', 'invalid_amount_type');
    end if;
    v_categories := array_append(v_categories, 'compensation');
  end if;
  if cardinality(v_categories) = 0 then
    return jsonb_build_object('ok', false, 'code', 'supported_change_required');
  end if;

  insert into public.job_contract_change_requests (
    contract_id, base_version_id, requested_by, change_categories,
    proposed_terms, proposed_content_hash, reason
  ) values (
    v_contract.id, v_base.id, v_user, v_categories, v_terms,
    encode(extensions.digest(v_terms::text, 'sha256'), 'hex'), left(btrim(p_reason), 1000)
  ) returning id into v_change_id;
  insert into public.job_contract_change_acceptances (
    change_request_id, user_id, party_role, accepted,
    proposed_content_hash, affirmative_checkbox
  ) values (
    v_change_id, v_user, v_role, true,
    encode(extensions.digest(v_terms::text, 'sha256'), 'hex'), true
  );
  update public.job_contracts set status = 'change_pending' where id = v_contract.id;
  return jsonb_build_object('ok', true, 'change_request_id', v_change_id, 'status', 'pending_both_parties');
exception when unique_violation then
  return jsonb_build_object('ok', false, 'code', 'change_already_pending');
end;
$_$;


--
-- Name: resend_guardian_invite(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.resend_guardian_invite(p_link_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
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


--
-- Name: respond_job_contract_change(uuid, boolean, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.respond_job_contract_change(p_change_request_id uuid, p_accept boolean, p_affirmative_checkbox boolean) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_user uuid := auth.uid();
  v_change public.job_contract_change_requests%rowtype;
  v_contract public.job_contracts%rowtype;
  v_base public.job_contract_versions%rowtype;
  v_role text;
  v_acceptances integer;
  v_new_version_id uuid;
  v_terms jsonb;
begin
  if v_user is null then return jsonb_build_object('ok', false, 'code', 'authentication_required'); end if;
  if coalesce(p_accept, false) and not coalesce(p_affirmative_checkbox, false) then
    return jsonb_build_object('ok', false, 'code', 'affirmative_checkbox_required');
  end if;
  select * into v_change from public.job_contract_change_requests where id = p_change_request_id for update;
  if not found or v_change.status <> 'pending_both_parties' then
    return jsonb_build_object('ok', false, 'code', 'pending_change_required');
  end if;
  select * into v_contract from public.job_contracts where id = v_change.contract_id for update;
  if v_user = v_contract.teen_id then v_role := 'teen';
  elsif v_user = v_contract.adult_id then v_role := 'adult';
  else return jsonb_build_object('ok', false, 'code', 'contract_party_required'); end if;
  if v_user = v_change.requested_by then
    return jsonb_build_object('ok', false, 'code', 'other_party_response_required');
  end if;
  if exists (select 1 from public.job_contract_change_acceptances where change_request_id = v_change.id and user_id = v_user) then
    return jsonb_build_object('ok', false, 'code', 'change_already_answered');
  end if;
  insert into public.job_contract_change_acceptances (
    change_request_id, user_id, party_role, accepted,
    proposed_content_hash, affirmative_checkbox
  ) values (
    v_change.id, v_user, v_role, coalesce(p_accept, false),
    v_change.proposed_content_hash, coalesce(p_affirmative_checkbox, false)
  );
  if not coalesce(p_accept, false) then
    update public.job_contract_change_requests set status = 'declined', resolved_at = now() where id = v_change.id;
    update public.job_contracts set status = 'active' where id = v_contract.id;
    return jsonb_build_object('ok', true, 'status', 'declined');
  end if;

  select count(*)::integer into v_acceptances
  from public.job_contract_change_acceptances
  where change_request_id = v_change.id
    and accepted and affirmative_checkbox
    and proposed_content_hash = v_change.proposed_content_hash;
  if v_acceptances < 2 then
    return jsonb_build_object('ok', true, 'status', 'pending_both_parties');
  end if;

  select * into v_base from public.job_contract_versions where id = v_change.base_version_id for update;
  v_terms := v_change.proposed_terms;
  insert into public.job_contract_versions (
    contract_id, version_number, source, source_change_request_id, status,
    teen_public_identifier, adult_public_identifier, agreed_scope, excluded_work,
    location_type, exact_location_release_state, service_date, start_window,
    expected_end_window, amount_type, hourly_rate_cents, maximum_approved_hours,
    fixed_total_cents, currency_code, payment_preference, payment_due_rule,
    authorized_expenses, equipment, hazards, expected_people_present, supervision,
    proof_requirements, completion_requirements, cancellation_terms,
    material_change_process, dispute_process, safety_agreement_version,
    terms_snapshot, content_hash, created_by
  ) values (
    v_contract.id, v_base.version_number + 1, 'mutual_change_request', v_change.id,
    'pending_confirmation', v_terms->>'teen_public_identifier', v_terms->>'adult_public_identifier',
    v_terms->>'agreed_scope', array(select jsonb_array_elements_text(v_terms->'excluded_work')),
    v_terms->>'location_type', v_terms->>'exact_location_release_state',
    nullif(v_terms->>'service_date', '')::date, nullif(v_terms->>'start_window', '')::timestamptz,
    nullif(v_terms->>'expected_end_window', '')::timestamptz, v_terms->>'amount_type',
    nullif(v_terms->>'hourly_rate_cents', '')::integer,
    nullif(v_terms->>'maximum_approved_hours', '')::numeric,
    nullif(v_terms->>'fixed_total_cents', '')::integer, coalesce(v_terms->>'currency_code', 'USD'),
    v_terms->>'payment_preference', v_terms->>'payment_due_rule',
    array(select jsonb_array_elements_text(v_terms->'authorized_expenses')),
    v_terms->>'equipment', v_terms->>'hazards', v_terms->>'expected_people_present',
    v_terms->>'supervision', v_terms->>'proof_requirements', v_terms->>'completion_requirements',
    v_terms->>'cancellation_terms', v_terms->>'material_change_process',
    v_terms->>'dispute_process', v_terms->>'safety_agreement_version', v_terms,
    v_change.proposed_content_hash, v_user
  ) returning id into v_new_version_id;
  update public.job_contract_change_requests
  set status = 'accepted', resolved_at = now(), created_version_id = v_new_version_id
  where id = v_change.id;
  return jsonb_build_object('ok', true, 'status', 'accepted', 'contract_version_id', v_new_version_id);
exception when unique_violation then
  return jsonb_build_object('ok', false, 'code', 'contract_change_conflict');
end;
$$;


--
-- Name: respond_to_teen_abandonment(uuid, text, boolean, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.respond_to_teen_abandonment(p_application_id uuid, p_statement text, p_safety_related boolean, p_client_request_id uuid) RETURNS jsonb
    LANGUAGE sql
    SET search_path TO ''
    AS $$
  select private.respond_to_teen_abandonment_internal(
    p_application_id, p_statement, p_safety_related, p_client_request_id
  );
$$;


--
-- Name: review_application_proof(uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.review_application_proof(p_proof_id uuid, p_action text, p_note text) RETURNS jsonb
    LANGUAGE sql
    SET search_path TO ''
    AS $_$
  select private.review_application_proof_internal($1,$2,$3)
$_$;


--
-- Name: save_job_draft_or_publish(uuid, uuid, jsonb, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.save_job_draft_or_publish(p_job_id uuid, p_client_request_id uuid, p_payload jsonb, p_publish boolean) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_user uuid := auth.uid();
  v_existing public.jobs%rowtype;
  v_job public.jobs%rowtype;
  v_payload jsonb := coalesce(p_payload, '{}'::jsonb);
  v_category text := v_payload->>'category';
  v_title text := btrim(coalesce(v_payload->>'title', ''));
  v_description text := btrim(coalesce(v_payload->>'description', ''));
  v_city text := nullif(btrim(coalesce(v_payload->>'city', '')), '');
  v_region text := nullif(upper(btrim(coalesce(v_payload->>'state', ''))), '');
  v_amount_cents integer := nullif(v_payload->>'adult_job_amount_cents', '')::integer;
  v_min_age integer := coalesce(nullif(v_payload->>'teen_min_age', '')::integer, 13);
  v_max_age integer := coalesce(nullif(v_payload->>'teen_max_age', '')::integer, 17);
  v_schedule text := coalesce(nullif(v_payload->>'schedule_type', ''), 'flexible');
  v_payment_type text := coalesce(nullif(v_payload->>'payment_type', ''), 'fixed');
  v_hash text;
  v_response jsonb;
  v_inserted integer;
  v_state public.mort_job_status;
  v_public_enabled boolean;
  v_maintenance boolean;
begin
  if v_user is null or not private.is_active_user() or private.current_role() <> 'adult'::public.mort_role then
    return jsonb_build_object('ok', false, 'code', 'active_adult_account_required');
  end if;
  if p_client_request_id is null or jsonb_typeof(v_payload) <> 'object' then
    return jsonb_build_object('ok', false, 'code', 'job_save_request_invalid');
  end if;
  if v_category not in ('yard_work','pet_care','tutoring','household_help','moving_help','tech_help','other') then
    return jsonb_build_object('ok', false, 'code', 'job_category_invalid', 'field', 'category');
  end if;
  if char_length(v_title) > 120 or char_length(v_description) > 5000 then
    return jsonb_build_object('ok', false, 'code', 'job_content_too_long');
  end if;
  if v_amount_cents is not null and (v_amount_cents < 0 or v_amount_cents > 1000000) then
    return jsonb_build_object('ok', false, 'code', 'job_amount_invalid', 'field', 'adult_job_amount_cents');
  end if;
  if v_min_age < 13 or v_min_age > 17 or v_max_age < v_min_age or v_max_age > 17 then
    return jsonb_build_object('ok', false, 'code', 'job_age_range_invalid');
  end if;
  if v_schedule not in ('flexible','exact') or v_payment_type not in ('fixed','hourly') then
    return jsonb_build_object('ok', false, 'code', 'job_schedule_or_payment_invalid');
  end if;
  if p_publish and (char_length(v_title) < 5 or char_length(v_description) < 20
      or coalesce(v_amount_cents,0) <= 0 or v_city is null or v_region is null) then
    return jsonb_build_object('ok', false, 'code', 'job_publication_fields_required');
  end if;
  if p_publish then
    select public_marketplace_enabled, maintenance_mode into v_public_enabled, v_maintenance
    from public.mort_release_control where is_primary;
    if not coalesce(v_public_enabled, false) or coalesce(v_maintenance, true) then
      return jsonb_build_object('ok', false, 'code', 'marketplace_unavailable');
    end if;
  end if;

  select * into v_existing from public.jobs where id = p_job_id for update;
  if p_job_id is not null and (not found or v_existing.poster_id <> v_user) then
    return jsonb_build_object('ok', false, 'code', 'job_not_available');
  end if;
  if p_job_id is not null and v_existing.status not in ('draft'::public.mort_job_status,'under_review'::public.mort_job_status,'open'::public.mort_job_status,'paused'::public.mort_job_status) then
    return jsonb_build_object('ok', false, 'code', 'job_cannot_be_edited_in_current_state');
  end if;
  if p_job_id is not null and exists (select 1 from public.job_applications ja where ja.job_id=p_job_id) then
    return jsonb_build_object('ok', false, 'code', 'job_has_applications');
  end if;
  if p_job_id is not null and not p_publish and v_existing.status in ('open'::public.mort_job_status,'paused'::public.mort_job_status) then
    return jsonb_build_object('ok', false, 'code', 'published_job_must_resubmit_for_review');
  end if;

  v_hash := md5(coalesce(p_job_id::text,'new') || '|' || v_payload::text || '|' || p_publish::text);
  select response into v_response from private.mort_job_mutation_requests
  where user_id=v_user and client_request_id=p_client_request_id;
  if found then
    if (select request_hash from private.mort_job_mutation_requests where user_id=v_user and client_request_id=p_client_request_id) <> v_hash then
      return jsonb_build_object('ok', false, 'code', 'idempotency_key_reused');
    end if;
    if v_response is not null then return v_response || jsonb_build_object('replayed', true); end if;
  else
    insert into private.mort_job_mutation_requests(user_id,client_request_id,operation,request_hash)
    values(v_user,p_client_request_id,'save_job',v_hash) on conflict do nothing;
    get diagnostics v_inserted = row_count;
    if v_inserted = 0 then
      select request_hash,response into v_hash,v_response from private.mort_job_mutation_requests
      where user_id=v_user and client_request_id=p_client_request_id for update;
      if v_response is not null then return v_response || jsonb_build_object('replayed', true); end if;
      return jsonb_build_object('ok', false, 'code', 'job_save_in_progress');
    end if;
  end if;

  v_state := case when p_publish then 'under_review'::public.mort_job_status else 'draft'::public.mort_job_status end;
  perform set_config('mort.job_action', case when p_publish then 'submitted_for_review' else 'saved_draft' end, true);
  insert into public.jobs (
    id,poster_id,title,summary,description,category,status,pay_type,pay_amount,
    estimated_minutes,estimated_duration_minutes,city,region,location_text,location_notes,exact_address,
    age_min,age_max,teen_min_age,teen_max_age,remote_allowed,starts_at,ends_at,safety_review_status,
    published_at,adult_job_amount_cents,pay_amount_cents,schedule_type,payment_type,payment_method,
    payment_timing,verification_requirement,work_environment,location_type,experience_level,
    workers_needed,skills_needed,physical_requirements,equipment_provided,equipment_worker_brings,
    special_instructions,safety_notes,proof_expected,adult_supervision_present,tip_allowed,
    applications_open,deadline_at,expires_at,recurring,recurrence_rule,timezone,urgency,
    neighborhood,zip_code,travel_radius_miles,acceptable_transportation_methods,
    transportation_considerations,requires_guardian_approval,quick_accept_eligible
  ) values (
    coalesce(p_job_id,gen_random_uuid()),v_user,v_title,nullif(btrim(v_payload->>'summary'),''),v_description,
    v_category,v_state,v_payment_type,coalesce(v_amount_cents,0)::numeric/100,
    nullif(v_payload->>'estimated_duration_minutes','')::integer,
    nullif(v_payload->>'estimated_duration_minutes','')::integer,v_city,v_region,
    nullif(btrim(v_payload->>'location_text'),''),null,null,
    v_min_age,v_max_age,v_min_age,v_max_age,false,
    nullif(v_payload->>'starts_at','')::timestamptz,nullif(v_payload->>'ends_at','')::timestamptz,
    'pending',null,v_amount_cents,v_amount_cents,v_schedule,v_payment_type,
    coalesce(nullif(v_payload->>'payment_method',''),'flexible'),
    coalesce(nullif(v_payload->>'payment_timing',''),'after_completion'),
    coalesce(nullif(v_payload->>'verification_requirement',''),'none'),
    coalesce(nullif(v_payload->>'work_environment',''),'unspecified'),
    coalesce(nullif(v_payload->>'location_type',''),'unspecified'),
    coalesce(nullif(v_payload->>'experience_level',''),'any'),
    coalesce(nullif(v_payload->>'workers_needed','')::integer,1),
    case when jsonb_typeof(v_payload->'skills_needed')='array' then array(select jsonb_array_elements_text(v_payload->'skills_needed')) else '{}'::text[] end,
    case when jsonb_typeof(v_payload->'physical_requirements')='array' then array(select jsonb_array_elements_text(v_payload->'physical_requirements')) else '{}'::text[] end,
    nullif(btrim(v_payload->>'equipment_provided'),''),nullif(btrim(v_payload->>'equipment_worker_brings'),''),
    nullif(btrim(v_payload->>'special_instructions'),''),nullif(btrim(v_payload->>'safety_notes'),''),
    coalesce((v_payload->>'proof_expected')::boolean,false),
    coalesce((v_payload->>'adult_supervision_present')::boolean,false),
    coalesce((v_payload->>'tip_allowed')::boolean,false),false,
    nullif(v_payload->>'deadline_at','')::timestamptz,
    nullif(v_payload->>'deadline_at','')::timestamptz,
    coalesce((v_payload->>'recurring')::boolean,false),nullif(btrim(v_payload->>'recurrence_rule'),''),
    coalesce(nullif(v_payload->>'timezone',''),'America/Indiana/Indianapolis'),
    coalesce(nullif(v_payload->>'urgency',''),'normal'),
    nullif(btrim(v_payload->>'neighborhood'),''),nullif(btrim(v_payload->>'zip_code'),''),
    nullif(v_payload->>'travel_radius_miles','')::integer,
    case when jsonb_typeof(v_payload->'acceptable_transportation_methods')='array' then array(select jsonb_array_elements_text(v_payload->'acceptable_transportation_methods')) else array['walking','bicycle','car','public_transit','rideshare','other']::text[] end,
    nullif(btrim(v_payload->>'transportation_considerations'),''),
    coalesce((v_payload->>'requires_guardian_approval')::boolean,false),false
  ) on conflict (id) do update set
    title=excluded.title,summary=excluded.summary,description=excluded.description,category=excluded.category,
    status=excluded.status,pay_type=excluded.pay_type,pay_amount=excluded.pay_amount,
    estimated_minutes=excluded.estimated_minutes,estimated_duration_minutes=excluded.estimated_duration_minutes,
    city=excluded.city,region=excluded.region,location_text=excluded.location_text,location_notes=null,exact_address=null,
    age_min=excluded.age_min,age_max=excluded.age_max,teen_min_age=excluded.teen_min_age,teen_max_age=excluded.teen_max_age,
    remote_allowed=excluded.remote_allowed,starts_at=excluded.starts_at,ends_at=excluded.ends_at,
    safety_review_status='pending',published_at=null,adult_job_amount_cents=excluded.adult_job_amount_cents,
    pay_amount_cents=excluded.pay_amount_cents,schedule_type=excluded.schedule_type,payment_type=excluded.payment_type,
    payment_method=excluded.payment_method,payment_timing=excluded.payment_timing,
    verification_requirement=excluded.verification_requirement,work_environment=excluded.work_environment,
    location_type=excluded.location_type,experience_level=excluded.experience_level,workers_needed=excluded.workers_needed,
    skills_needed=excluded.skills_needed,physical_requirements=excluded.physical_requirements,
    equipment_provided=excluded.equipment_provided,equipment_worker_brings=excluded.equipment_worker_brings,
    special_instructions=excluded.special_instructions,safety_notes=excluded.safety_notes,proof_expected=excluded.proof_expected,
    adult_supervision_present=excluded.adult_supervision_present,tip_allowed=excluded.tip_allowed,
    applications_open=false,deadline_at=excluded.deadline_at,expires_at=excluded.expires_at,
    recurring=excluded.recurring,recurrence_rule=excluded.recurrence_rule,timezone=excluded.timezone,
    urgency=excluded.urgency,neighborhood=excluded.neighborhood,zip_code=excluded.zip_code,
    travel_radius_miles=excluded.travel_radius_miles,acceptable_transportation_methods=excluded.acceptable_transportation_methods,
    transportation_considerations=excluded.transportation_considerations,
    requires_guardian_approval=excluded.requires_guardian_approval,quick_accept_eligible=false
  where public.jobs.poster_id=v_user
  returning * into v_job;
  if not found then
    delete from private.mort_job_mutation_requests where user_id=v_user and client_request_id=p_client_request_id;
    return jsonb_build_object('ok', false, 'code', 'job_not_available');
  end if;

  v_response := jsonb_build_object('ok',true,'job',to_jsonb(v_job)-'exact_address','publication_state',case when p_publish then 'pending_review' else 'draft' end,'replayed',false);
  update private.mort_job_mutation_requests set response=v_response
  where user_id=v_user and client_request_id=p_client_request_id;
  return v_response;
end;
$$;


--
-- Name: FUNCTION save_job_draft_or_publish(p_job_id uuid, p_client_request_id uuid, p_payload jsonb, p_publish boolean); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.save_job_draft_or_publish(p_job_id uuid, p_client_request_id uuid, p_payload jsonb, p_publish boolean) IS 'Saves adult-owned job drafts or submits a complete job for moderator review; publication never bypasses safety approval.';


--
-- Name: save_job_private_location_v1(uuid, text, text, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.save_job_private_location_v1(p_job_id uuid, p_exact_address text, p_arrival_instructions text, p_access_notes text, p_client_request_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_user_id uuid := auth.uid();
  v_job public.jobs%rowtype;
  v_location private.job_private_locations%rowtype;
  v_application_id uuid;
  v_payload_sha256 text;
  v_prior_sha256 text;
  v_prior_job_id uuid;
  v_prior_response jsonb;
  v_response jsonb;
  v_next_version integer;
  v_location_changed boolean := false;
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if not private.is_active_user()
     or private.current_role() is distinct from 'adult'::public.mort_role then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;
  if p_job_id is null or p_client_request_id is null
     or p_exact_address is null
     or char_length(btrim(p_exact_address)) not between 5 and 500 then
    return jsonb_build_object('ok', false, 'code', 'job_location_request_invalid');
  end if;
  if char_length(coalesce(p_arrival_instructions, '')) > 1000
     or char_length(coalesce(p_access_notes, '')) > 1000 then
    return jsonb_build_object('ok', false, 'code', 'job_location_notes_too_long');
  end if;
  v_payload_sha256 := encode(extensions.digest(convert_to(
    jsonb_build_object(
      'job_id', p_job_id,
      'exact_address', btrim(p_exact_address),
      'arrival_instructions', nullif(btrim(coalesce(p_arrival_instructions, '')), ''),
      'access_notes', nullif(btrim(coalesce(p_access_notes, '')), '')
    )::text, 'UTF8'), 'sha256'), 'hex');
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('job_location:' || v_user_id::text || ':' || p_client_request_id::text, 0)
  );
  select request.payload_sha256, request.job_id, request.response
  into v_prior_sha256, v_prior_job_id, v_prior_response
  from private.job_private_location_requests request
  where request.actor_id = v_user_id
    and request.client_request_id = p_client_request_id
  for update;
  if found then
    if v_prior_sha256 <> v_payload_sha256 or v_prior_job_id <> p_job_id then
      return jsonb_build_object('ok', false, 'code', 'idempotency_key_reused');
    end if;
    return v_prior_response || jsonb_build_object('replayed', true);
  end if;
  -- A location change before work starts invalidates consent and refreshes the
  -- legal safety snapshot. Moving a job already in progress uses cancellation.
  select * into v_job
  from public.jobs job
  where job.id = p_job_id
  for update;
  if not found or v_job.poster_id <> v_user_id
     or v_job.status::text not in ('draft', 'under_review', 'open', 'paused', 'filled') then
    return jsonb_build_object('ok', false, 'code', 'job_location_write_not_allowed');
  end if;
  perform agreement.id
  from public.job_safety_agreements agreement
  where agreement.job_id = p_job_id
  order by agreement.application_id
  for update;
  select * into v_location
  from private.job_private_locations location
  where location.job_id = p_job_id
  for update;
  if not found then
    v_next_version := 1;
    insert into private.job_private_locations(
      job_id, poster_id, exact_address, address_fingerprint,
      arrival_instructions, access_notes, location_version,
      location_source, verified_for_job, captured_at, updated_at
    ) values (
      p_job_id, v_user_id, btrim(p_exact_address),
      encode(extensions.digest(convert_to(btrim(p_exact_address), 'UTF8'), 'sha256'), 'hex'),
      nullif(btrim(coalesce(p_arrival_instructions, '')), ''),
      nullif(btrim(coalesce(p_access_notes, '')), ''), v_next_version,
      'address_text', false, now(), now()
    ) returning * into v_location;
    v_location_changed := true;
  elsif v_location.address_fingerprint <> encode(
      extensions.digest(convert_to(btrim(p_exact_address), 'UTF8'), 'sha256'), 'hex'
    )
    or v_location.arrival_instructions is distinct from nullif(btrim(coalesce(p_arrival_instructions, '')), '')
    or v_location.access_notes is distinct from nullif(btrim(coalesce(p_access_notes, '')), '') then
    v_next_version := v_location.location_version + 1;
    update private.job_private_locations
    set exact_address = btrim(p_exact_address),
        address_fingerprint = encode(extensions.digest(convert_to(btrim(p_exact_address), 'UTF8'), 'sha256'), 'hex'),
        arrival_instructions = nullif(btrim(coalesce(p_arrival_instructions, '')), ''),
        access_notes = nullif(btrim(coalesce(p_access_notes, '')), ''),
        latitude = null,
        longitude = null,
        location_source = 'address_text',
        location_accuracy_meters = null,
        location_version = v_next_version,
        verified_for_job = false,
        captured_at = now(),
        updated_at = now()
    where job_id = p_job_id
    returning * into v_location;
    v_location_changed := true;
  else
    v_next_version := v_location.location_version;
  end if;
  if v_location_changed then
    update public.job_safety_agreements agreement
    set location_version = v_next_version
    where agreement.job_id = p_job_id;
    for v_application_id in
      select agreement.application_id
      from public.job_safety_agreements agreement
      where agreement.job_id = p_job_id
      order by agreement.application_id
    loop
      perform private.refresh_job_safety_agreement(v_application_id);
    end loop;
  end if;
  insert into private.job_private_location_access_events(actor_id, resource_type, resource_id, action, reason)
  values (v_user_id, 'job_private_location', p_job_id, 'write', 'Job poster saved the restricted job location.');
  v_response := jsonb_build_object(
    'ok', true,
    'job_id', p_job_id,
    'location_version', v_next_version,
    'public_feed_contains_exact_address', false,
    'public_feed_contains_coordinates', false,
    'replayed', false
  );
  insert into private.job_private_location_requests(
    actor_id, client_request_id, job_id, payload_sha256, response
  ) values (v_user_id, p_client_request_id, p_job_id, v_payload_sha256, v_response);
  return v_response;
end;
$$;


--
-- Name: save_job_safety_plan(uuid, text, boolean, boolean, text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.save_job_safety_plan(p_application_id uuid, p_expected_people text, p_public_or_visible_meeting boolean, p_daylight_preferred boolean, p_transportation_plan text, p_checkin_cadence_minutes integer) RETURNS jsonb
    LANGUAGE sql
    SET search_path TO ''
    AS $$
  select private.save_job_safety_plan_internal(
    p_application_id,
    p_expected_people,
    p_public_or_visible_meeting,
    p_daylight_preferred,
    p_transportation_plan,
    p_checkin_cadence_minutes
  );
$$;


--
-- Name: FUNCTION save_job_safety_plan(p_application_id uuid, p_expected_people text, p_public_or_visible_meeting boolean, p_daylight_preferred boolean, p_transportation_plan text, p_checkin_cadence_minutes integer); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.save_job_safety_plan(p_application_id uuid, p_expected_people text, p_public_or_visible_meeting boolean, p_daylight_preferred boolean, p_transportation_plan text, p_checkin_cadence_minutes integer) IS 'Saves an accepted job participants’ safety plan and clears prior confirmations when it changes.';


--
-- Name: save_my_initial_dob_v1(date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.save_my_initial_dob_v1(p_date_of_birth date) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_user_id uuid := auth.uid();
  v_profile public.profiles%rowtype;
  v_age integer;
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_date_of_birth is null or p_date_of_birth > current_date then
    return jsonb_build_object('ok', false, 'code', 'dob_invalid', 'field', 'date_of_birth');
  end if;

  v_age := private.mort_age_years(p_date_of_birth);
  if v_age < 13 then
    return jsonb_build_object('ok', false, 'code', 'minimum_age_required', 'field', 'date_of_birth');
  end if;

  perform public.ensure_my_profile();
  select * into v_profile
  from public.profiles
  where id = v_user_id
  for update;

  if v_profile.id is null then
    return jsonb_build_object('ok', false, 'code', 'profile_not_found');
  end if;
  if v_profile.onboarding_completed_at is not null then
    return jsonb_build_object('ok', false, 'code', 'dob_immutable');
  end if;
  if v_profile.date_of_birth is not null
     and v_profile.date_of_birth is distinct from p_date_of_birth then
    return jsonb_build_object('ok', false, 'code', 'dob_immutable');
  end if;

  update public.profiles
  set date_of_birth = coalesce(date_of_birth, p_date_of_birth),
      updated_at = now()
  where id = v_user_id;

  return jsonb_build_object(
    'ok', true,
    'age_band', case when v_age between 13 and 17 then 'minor' else 'adult' end,
    'minimum_age', 13
  );
end;
$$;


--
-- Name: save_my_job_v1(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.save_my_job_v1(p_job_id uuid) RETURNS jsonb
    LANGUAGE plpgsql
    SET search_path TO ''
    AS $$
declare user_id uuid:=auth.uid(); profile public.profiles%rowtype; job public.jobs%rowtype;
begin
if user_id is null then return jsonb_build_object('ok',false,'code','authentication_required'); end if;
if p_job_id is null then return jsonb_build_object('ok',false,'code','job_id_required'); end if;
select * into profile from public.profiles where id=user_id;
if not found or profile.role<>'teen'::public.mort_role or profile.account_status<>'active' then return jsonb_build_object('ok',false,'code','active_teen_account_required'); end if;
select * into job from public.jobs candidate where candidate.id=p_job_id and candidate.status='open'::public.mort_job_status and candidate.safety_review_status='approved' and candidate.applications_open and (candidate.expires_at is null or candidate.expires_at>now());
if not found then return jsonb_build_object('ok',false,'code','job_not_available'); end if;
if profile.date_of_birth is not null and (extract(year from age(current_date,profile.date_of_birth))::integer<job.age_min or extract(year from age(current_date,profile.date_of_birth))::integer>job.age_max) then return jsonb_build_object('ok',false,'code','job_not_eligible'); end if;
insert into public.saved_jobs(user_id,job_id) values(user_id,p_job_id) on conflict(user_id,job_id) do nothing;
return jsonb_build_object('ok',true,'job_id',p_job_id);
end;$$;


--
-- Name: save_my_onboarding_account_v2(jsonb, uuid, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.save_my_onboarding_account_v2(p_payload jsonb, p_client_request_id uuid, p_payload_version integer DEFAULT 1) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $_$
declare
  v_user_id uuid := auth.uid();
  profile public.profiles%rowtype;
  dob date;
  age_years integer;
  selected_role text;
  chosen_role public.mort_role;
  display_name_value text;
  username_value text;
  city_value text;
  region_value text;
  area_value text;
  mode_value text;
  unknown_keys text[];
  v_auth_email text;
  v_email_confirmed_at timestamptz;
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object'
    or p_client_request_id is null or p_payload_version <> 1 then
    return jsonb_build_object('ok', false, 'code', 'onboarding_request_invalid');
  end if;

  select coalesce(array_agg(key order by key), array[]::text[])
  into unknown_keys
  from jsonb_object_keys(p_payload) key
  where key not in (
    'role','display_name','username','dob','city','state',
    'location_setup_mode','approximate_area','adult_account_type','business_name'
  );
  if cardinality(unknown_keys) > 0 then
    return jsonb_build_object('ok', false, 'code', 'onboarding_payload_unknown_fields');
  end if;

  begin
    dob := (p_payload->>'dob')::date;
  exception when others then
    return jsonb_build_object('ok', false, 'code', 'dob_invalid', 'field', 'dob');
  end;
  if dob is null then
    return jsonb_build_object('ok', false, 'code', 'dob_invalid', 'field', 'dob');
  end if;

  age_years := extract(year from age(current_date, dob))::integer;
  if age_years < 13 then
    return jsonb_build_object('ok', false, 'code', 'minimum_age_required', 'field', 'dob');
  end if;

  selected_role := lower(btrim(coalesce(p_payload->>'role', '')));
  if age_years < 18 then
    chosen_role := 'teen'::public.mort_role;
  elsif selected_role in ('adult','guardian') then
    chosen_role := selected_role::public.mort_role;
  else
    return jsonb_build_object('ok', false, 'code', 'adult_role_required', 'field', 'role');
  end if;

  if age_years between 13 and 17 then
    select u.email, u.email_confirmed_at
      into v_auth_email, v_email_confirmed_at
    from auth.users u
    where u.id = v_user_id;

    if v_email_confirmed_at is null then
      return jsonb_build_object('ok', false, 'code', 'school_email_verification_required', 'field', 'email');
    end if;
    if not private.is_approved_school_email(v_auth_email) then
      return jsonb_build_object('ok', false, 'code', 'school_email_required', 'field', 'email');
    end if;
  end if;

  display_name_value := btrim(coalesce(p_payload->>'display_name', ''));
  username_value := lower(btrim(coalesce(p_payload->>'username', '')));
  if char_length(display_name_value) not between 2 and 80
    or display_name_value ~ '[[:cntrl:]]' then
    return jsonb_build_object('ok', false, 'code', 'display_name_invalid', 'field', 'display_name');
  end if;
  if username_value !~ '^[a-z0-9_]{3,24}$' then
    return jsonb_build_object('ok', false, 'code', 'username_invalid', 'field', 'username');
  end if;

  mode_value := coalesce(p_payload->>'location_setup_mode', 'city_state');
  if chosen_role = 'teen'::public.mort_role then
    mode_value := 'location_deferred';
    area_value := nullif(btrim(p_payload->>'approximate_area'), '');
    if area_value is null or char_length(area_value) > 80 then
      return jsonb_build_object('ok', false, 'code', 'approximate_area_required', 'field', 'approximate_area');
    end if;
    city_value := null;
    region_value := null;
  else
    city_value := nullif(btrim(p_payload->>'city'), '');
    region_value := upper(btrim(coalesce(p_payload->>'state', '')));
    if mode_value <> 'city_state' or city_value is null or region_value !~ '^[A-Z]{2}$' then
      return jsonb_build_object('ok', false, 'code', 'general_location_required');
    end if;
  end if;

  perform public.ensure_my_profile();
  select * into profile from public.profiles where id = v_user_id for update;
  if profile.id is null then
    return jsonb_build_object('ok', false, 'code', 'profile_not_found');
  end if;
  if profile.onboarding_completed_at is not null then
    return private.evaluate_mort_onboarding(v_user_id) || jsonb_build_object('replayed', true);
  end if;
  if profile.date_of_birth is not null and profile.date_of_birth <> dob then
    return jsonb_build_object('ok', false, 'code', 'dob_immutable', 'field', 'dob');
  end if;
  if profile.role <> 'pending'::public.mort_role
    and profile.role is distinct from chosen_role then
    return jsonb_build_object('ok', false, 'code', 'role_immutable', 'field', 'role');
  end if;

  update public.profiles
  set role = chosen_role,
      date_of_birth = coalesce(date_of_birth, dob),
      display_name = display_name_value,
      username = username_value,
      city = city_value,
      region = region_value,
      location_setup_mode = mode_value,
      approximate_area = area_value,
      updated_at = now()
  where id = v_user_id;

  insert into public.verification_cases(
    user_id, verification_type, status, provider, submitted_at
  )
  select v_user_id, 'age', 'pending'::public.mort_verification_status,
         'self_reported', now()
  where not exists (
    select 1
    from public.verification_cases vc
    where vc.user_id = v_user_id
      and vc.verification_type = 'age'
      and vc.status in (
        'pending'::public.mort_verification_status,
        'verified'::public.mort_verification_status
      )
  );

  return private.evaluate_mort_onboarding(v_user_id) || jsonb_build_object('replayed', false);
exception when unique_violation then
  return jsonb_build_object('ok', false, 'code', 'username_taken', 'field', 'username');
end;
$_$;


--
-- Name: save_my_onboarding_safety_v2(jsonb, uuid, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.save_my_onboarding_safety_v2(p_payload jsonb, p_client_request_id uuid, p_payload_version integer DEFAULT 1, p_expected_revision text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_user_id uuid := auth.uid();
  profile public.profiles%rowtype;
  intent text := coalesce(p_payload->>'notification_intent', 'ask_later');
  guardian_choice text := coalesce(p_payload->>'guardian_choice', 'not_applicable');
  unknown_keys text[];
begin
  if v_user_id is null then return jsonb_build_object('ok', false, 'code', 'authentication_required'); end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' or p_client_request_id is null or p_payload_version <> 1 then
    return jsonb_build_object('ok', false, 'code', 'onboarding_request_invalid');
  end if;
  select coalesce(array_agg(key order by key), array[]::text[]) into unknown_keys
  from jsonb_object_keys(p_payload) key where key not in ('notification_intent','guardian_choice');
  if cardinality(unknown_keys) > 0 or intent not in ('ask_later','preferred','not_preferred') then
    return jsonb_build_object('ok', false, 'code', 'onboarding_safety_support_invalid');
  end if;
  select * into profile from public.profiles where id = v_user_id for update;
  if profile.id is null then return jsonb_build_object('ok', false, 'code', 'onboarding_account_required'); end if;
  if p_expected_revision is not null and profile.updated_at is distinct from p_expected_revision::timestamptz then
    return jsonb_build_object('ok', false, 'code', 'onboarding_revision_conflict', 'revision', profile.updated_at);
  end if;
  if profile.role = 'teen'::public.mort_role then
    if guardian_choice = 'skip' then
      perform public.set_guardian_setup_skipped();
    elsif guardian_choice = 'existing' and profile.guardian_setup_status not in ('invite_pending','linked') then
      return jsonb_build_object('ok', false, 'code', 'guardian_invite_required_or_skip');
    elsif guardian_choice not in ('existing','skip') then
      return jsonb_build_object('ok', false, 'code', 'guardian_invite_required_or_skip');
    end if;
  end if;
  insert into private.mort_onboarding_safety(user_id, notification_intent)
  values (v_user_id, intent)
  on conflict (user_id) do update set notification_intent = excluded.notification_intent, saved_at = now();
  return private.evaluate_mort_onboarding(v_user_id) || jsonb_build_object('replayed', false);
end;
$$;


--
-- Name: save_my_onboarding_work_v2(jsonb, uuid, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.save_my_onboarding_work_v2(p_payload jsonb, p_client_request_id uuid, p_payload_version integer DEFAULT 1, p_expected_revision text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  user_id uuid := auth.uid();
  profile public.profiles%rowtype;
  unknown_keys text[];
  categories text[];
  transport text[];
  availability_value text;
  distance_value integer;
  minutes_value integer;
begin
  if user_id is null then return jsonb_build_object('ok', false, 'code', 'authentication_required'); end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' or p_client_request_id is null or p_payload_version <> 1 then
    return jsonb_build_object('ok', false, 'code', 'onboarding_request_invalid');
  end if;
  select coalesce(array_agg(key order by key), array[]::text[]) into unknown_keys
  from jsonb_object_keys(p_payload) key where key not in (
    'availability','preferred_job_categories','transportation_methods','max_travel_distance_miles',
    'max_travel_minutes','walking_distance_only','guardian_transportation_possible'
  );
  if cardinality(unknown_keys) > 0 then return jsonb_build_object('ok', false, 'code', 'onboarding_payload_unknown_fields'); end if;
  select * into profile from public.profiles where id = user_id for update;
  if profile.id is null or profile.role not in ('teen'::public.mort_role, 'adult'::public.mort_role, 'guardian'::public.mort_role) then
    return jsonb_build_object('ok', false, 'code', 'onboarding_account_required');
  end if;
  if p_expected_revision is not null and profile.updated_at is distinct from p_expected_revision::timestamptz then
    return jsonb_build_object('ok', false, 'code', 'onboarding_revision_conflict', 'revision', profile.updated_at);
  end if;
  if profile.role <> 'teen'::public.mort_role then return private.evaluate_mort_onboarding(user_id) || jsonb_build_object('replayed', false); end if;
  availability_value := nullif(btrim(p_payload->>'availability'), '');
  if availability_value is null or char_length(availability_value) > 240 then
    return jsonb_build_object('ok', false, 'code', 'availability_required');
  end if;
  if jsonb_typeof(coalesce(p_payload->'preferred_job_categories','[]'::jsonb)) <> 'array'
    or jsonb_typeof(coalesce(p_payload->'transportation_methods','[]'::jsonb)) <> 'array' then
    return jsonb_build_object('ok', false, 'code', 'onboarding_work_preferences_invalid');
  end if;
  select coalesce(array_agg(distinct lower(btrim(value))), array[]::text[]) into categories
  from jsonb_array_elements_text(coalesce(p_payload->'preferred_job_categories','[]'::jsonb)) value
  where char_length(btrim(value)) between 1 and 60;
  select coalesce(array_agg(distinct lower(btrim(value))), array[]::text[]) into transport
  from jsonb_array_elements_text(coalesce(p_payload->'transportation_methods','[]'::jsonb)) value
  where lower(btrim(value)) in ('walking','bicycle','public_transit','car','rideshare','other');
  if cardinality(categories) = 0 or cardinality(categories) > 20 or cardinality(transport) = 0 then
    return jsonb_build_object('ok', false, 'code', 'onboarding_work_preferences_required');
  end if;
  begin
    distance_value := nullif(p_payload->>'max_travel_distance_miles','')::integer;
    minutes_value := nullif(p_payload->>'max_travel_minutes','')::integer;
  exception when others then return jsonb_build_object('ok', false, 'code', 'onboarding_work_preferences_invalid'); end;
  if distance_value is not null and distance_value not between 1 and 100 then return jsonb_build_object('ok', false, 'code', 'onboarding_work_preferences_invalid'); end if;
  if minutes_value is not null and minutes_value not between 1 and 240 then return jsonb_build_object('ok', false, 'code', 'onboarding_work_preferences_invalid'); end if;
  update public.profiles set
    availability = availability_value,
    preferred_job_categories = categories,
    transportation_methods = transport,
    max_travel_distance_miles = distance_value,
    max_travel_minutes = minutes_value,
    walking_distance_only = coalesce((p_payload->>'walking_distance_only')::boolean, false),
    guardian_transportation_possible = coalesce((p_payload->>'guardian_transportation_possible')::boolean, false),
    updated_at = now()
  where id = user_id;
  return private.evaluate_mort_onboarding(user_id) || jsonb_build_object('replayed', false);
exception when invalid_text_representation then
  return jsonb_build_object('ok', false, 'code', 'onboarding_work_preferences_invalid');
end;
$$;


--
-- Name: schedule_active_job_checkin(uuid, integer, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.schedule_active_job_checkin(p_application_id uuid, p_minutes_from_now integer, p_client_request_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  user_id uuid := auth.uid();
  assignment public.job_assignments%rowtype;
  checkin_id uuid;
  expected_at_value timestamptz;
begin
  if user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if private.current_role() <> 'teen'::public.mort_role or not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_teen_account_required');
  end if;
  if p_client_request_id is null then
    return jsonb_build_object('ok', false, 'code', 'client_request_id_required');
  end if;
  if p_minutes_from_now is null or p_minutes_from_now not between 5 and 240 then
    return jsonb_build_object('ok', false, 'code', 'checkin_interval_invalid');
  end if;

  select * into assignment
  from public.job_assignments
  where application_id = p_application_id
    and teen_user_id = user_id
    and status in ('accepted', 'in_progress');
  if not found then
    return jsonb_build_object('ok', false, 'code', 'active_assignment_required');
  end if;

  expected_at_value := now() + make_interval(mins => p_minutes_from_now);
  insert into public.job_safety_checkins (
    application_id, job_id, teen_user_id, adult_user_id,
    expected_at, client_request_id
  ) values (
    assignment.application_id, assignment.job_id, assignment.teen_user_id,
    assignment.adult_user_id, expected_at_value, p_client_request_id
  )
  on conflict (teen_user_id, client_request_id) do nothing
  returning id, expected_at into checkin_id, expected_at_value;

  if checkin_id is null then
    select id, expected_at into checkin_id, expected_at_value
    from public.job_safety_checkins
    where teen_user_id = user_id and client_request_id = p_client_request_id;
  end if;
  return jsonb_build_object(
    'ok', true, 'checkin_id', checkin_id, 'expected_at', expected_at_value
  );
end;
$$;


--
-- Name: send_safe_message_v2(uuid, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.send_safe_message_v2(p_thread_id uuid, p_body text, p_client_request_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_user_id uuid := (select auth.uid());
  v_message_id uuid;
  v_message public.messages%rowtype;
  v_body text := btrim(coalesce(p_body, ''));
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;
  if p_thread_id is null or p_client_request_id is null then
    return jsonb_build_object('ok', false, 'code', 'message_request_invalid');
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_user_id::text || ':' || p_client_request_id::text, 0)
  );

  select message.id, message.conversation_id, message.body
    into v_message_id, v_message.conversation_id, v_message.body
  from public.messages as message
  where message.sender_id = v_user_id
    and message.client_request_id = p_client_request_id;
  if found then
    if v_message.conversation_id <> p_thread_id or v_message.body <> v_body then
      return jsonb_build_object('ok', false, 'code', 'message_request_id_reused');
    end if;
    select * into v_message from public.messages where id = v_message_id;
  else
    v_message_id := public.mort_send_message(p_thread_id, v_body);
    update public.messages
    set client_request_id = p_client_request_id
    where id = v_message_id and sender_id = v_user_id
    returning * into v_message;
  end if;

  return jsonb_build_object(
    'id', v_message.id,
    'thread_id', v_message.conversation_id,
    'sender_id', v_message.sender_id,
    'body', v_message.body,
    'scanner_status', v_message.moderation_status,
    'scanner_reason', null,
    'created_at', v_message.created_at
  );
end;
$$;


--
-- Name: set_guardian_alert_preferences(uuid, boolean, boolean, boolean, boolean, boolean, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_guardian_alert_preferences(p_link_id uuid, p_safety_ping_alerts boolean, p_job_checkin_alerts boolean, p_accepted_job_summary boolean, p_safety_warning_alerts boolean, p_weekly_digest boolean, p_optional_job_approval_enabled boolean) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  user_id uuid := auth.uid();
begin
  if user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_link_id is null
    or p_safety_ping_alerts is null
    or p_job_checkin_alerts is null
    or p_accepted_job_summary is null
    or p_safety_warning_alerts is null
    or p_weekly_digest is null
    or p_optional_job_approval_enabled is null then
    return jsonb_build_object('ok', false, 'code', 'guardian_preferences_required');
  end if;

  if not exists (
    select 1
    from public.guardian_links link
    where link.id = p_link_id
      and link.teen_user_id = user_id
      and link.status = 'active'
  ) then
    return jsonb_build_object('ok', false, 'code', 'active_guardian_link_not_found');
  end if;

  insert into public.guardian_preferences (
    link_id,
    safety_ping_alerts,
    job_checkin_alerts,
    accepted_job_summary,
    safety_warning_alerts,
    weekly_digest,
    optional_job_approval_enabled
  ) values (
    p_link_id,
    p_safety_ping_alerts,
    p_job_checkin_alerts,
    p_accepted_job_summary,
    p_safety_warning_alerts,
    p_weekly_digest,
    p_optional_job_approval_enabled
  )
  on conflict (link_id) do update set
    safety_ping_alerts = excluded.safety_ping_alerts,
    job_checkin_alerts = excluded.job_checkin_alerts,
    accepted_job_summary = excluded.accepted_job_summary,
    safety_warning_alerts = excluded.safety_warning_alerts,
    weekly_digest = excluded.weekly_digest,
    optional_job_approval_enabled = excluded.optional_job_approval_enabled,
    updated_at = now();

  return jsonb_build_object('ok', true, 'link_id', p_link_id);
end;
$$;


--
-- Name: set_guardian_setup_skipped(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_guardian_setup_skipped() RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  user_id uuid := auth.uid();
begin
  if user_id is null then return jsonb_build_object('ok', false, 'code', 'authentication_required'); end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = user_id and p.role = 'teen'::public.mort_role
      and p.date_of_birth is not null and extract(year from age(current_date, p.date_of_birth)) between 13 and 17
  ) then return jsonb_build_object('ok', false, 'code', 'active_teen_account_required'); end if;
  update public.guardian_links set status = 'revoked', updated_at = now()
  where teen_user_id = user_id and status = 'pending';
  update private.guardian_invite_codes set consumed_at = coalesce(consumed_at, now())
  where teen_user_id = user_id and consumed_at is null;
  update public.profiles set guardian_setup_status = 'skipped', updated_at = now() where id = user_id;
  return private.evaluate_mort_onboarding(user_id) || jsonb_build_object('ok', true);
end;
$$;


--
-- Name: stripe_server_apply_assignment_payment_webhook(text, text, uuid, uuid, text, text, integer, text, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.stripe_server_apply_assignment_payment_webhook(p_environment text, p_provider_event_id text, p_lease_token uuid, p_ledger_id uuid, p_provider_payment_intent_id text, p_provider_status text, p_amount_cents integer, p_currency_code text, p_event_created_at timestamp with time zone) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $_$
declare
  event_row private.stripe_webhook_events%rowtype;
  payment private.stripe_payment_intents%rowtype;
  mapped_status text;
begin
  perform private.require_stripe_service_role();
  if p_environment not in ('test', 'live')
    or p_provider_event_id !~ '^evt_[A-Za-z0-9]+$'
    or p_provider_payment_intent_id !~ '^pi_[A-Za-z0-9]+$' then
    raise exception 'stripe_webhook_payment_envelope_invalid';
  end if;
  mapped_status := case p_provider_status
    when 'requires_payment_method' then 'requires_payment_method'
    when 'requires_action' then 'requires_action'
    when 'requires_confirmation' then 'requires_payment_method'
    when 'requires_capture' then 'authorized'
    when 'processing' then 'processing'
    when 'succeeded' then 'succeeded'
    when 'canceled' then 'cancelled'
    else 'unknown'
  end;
  select * into strict event_row from private.stripe_webhook_events
  where environment = p_environment and provider_event_id = p_provider_event_id
    and processing_status = 'processing' and lease_token = p_lease_token
  for update;
  select * into strict payment from private.stripe_payment_intents
  where id = p_ledger_id and environment = p_environment
  for update;
  if payment.provider_payment_intent_id <> p_provider_payment_intent_id
    or payment.gross_amount_cents <> p_amount_cents
    or lower(payment.currency_code) <> lower(p_currency_code) then
    raise exception 'stripe_payment_snapshot_mismatch';
  end if;
  if p_event_created_at >= coalesce(payment.last_provider_event_at, '-infinity'::timestamptz) then
    update private.stripe_payment_intents
    set status = mapped_status,
        last_provider_event_at = p_event_created_at,
        updated_at = now()
    where id = p_ledger_id
    returning * into payment;
  end if;
  return jsonb_build_object(
    'ok', true,
    'ledger_id', payment.id,
    'status', payment.status,
    'stale_event', p_event_created_at < coalesce(payment.last_provider_event_at, '-infinity'::timestamptz)
  );
end;
$_$;


--
-- Name: FUNCTION stripe_server_apply_assignment_payment_webhook(p_environment text, p_provider_event_id text, p_lease_token uuid, p_ledger_id uuid, p_provider_payment_intent_id text, p_provider_status text, p_amount_cents integer, p_currency_code text, p_event_created_at timestamp with time zone); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.stripe_server_apply_assignment_payment_webhook(p_environment text, p_provider_event_id text, p_lease_token uuid, p_ledger_id uuid, p_provider_payment_intent_id text, p_provider_status text, p_amount_cents integer, p_currency_code text, p_event_created_at timestamp with time zone) IS 'Applies signature-verified Stripe PaymentIntent state only through an active event lease and exact amount/currency snapshot match.';


--
-- Name: stripe_server_claim_webhook_event(text, text, text, timestamp with time zone, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.stripe_server_claim_webhook_event(p_environment text, p_provider_event_id text, p_event_type text, p_provider_created_at timestamp with time zone, p_payload_sha256 text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $_$
declare
  controls private.stripe_runtime_controls%rowtype;
  event_row private.stripe_webhook_events%rowtype;
  lease uuid;
begin
  perform private.require_stripe_service_role();
  if p_environment not in ('test', 'live')
    or p_provider_event_id !~ '^evt_[A-Za-z0-9]+$'
    or p_payload_sha256 !~ '^[a-f0-9]{64}$'
    or char_length(p_event_type) not between 3 and 120 then
    raise exception 'stripe_webhook_envelope_invalid';
  end if;
  select * into strict controls from private.stripe_runtime_controls where singleton;
  if controls.mode = 'disabled'
    or (controls.mode = 'sandbox' and p_environment <> 'test')
    or (controls.mode = 'live' and (p_environment <> 'live' or not controls.live_mode_enabled)) then
    raise exception 'stripe_environment_not_enabled' using errcode = '42501';
  end if;

  insert into private.stripe_webhook_events(
    environment, provider_event_id, event_type, provider_created_at,
    payload_sha256, signature_verified
  ) values (
    p_environment, p_provider_event_id, p_event_type, p_provider_created_at,
    p_payload_sha256, true
  ) on conflict (environment, provider_event_id) do nothing;

  select * into strict event_row
  from private.stripe_webhook_events
  where environment = p_environment and provider_event_id = p_provider_event_id
  for update;

  if event_row.payload_sha256 <> p_payload_sha256
    or event_row.event_type <> p_event_type then
    raise exception 'stripe_webhook_event_conflict';
  end if;
  if event_row.processing_status in ('processed', 'ignored') then
    return jsonb_build_object('claimed', false, 'duplicate', true, 'in_flight', false);
  end if;
  if event_row.processing_status = 'processing'
    and event_row.lease_expires_at > now() then
    return jsonb_build_object('claimed', false, 'duplicate', false, 'in_flight', true);
  end if;

  lease := gen_random_uuid();
  update private.stripe_webhook_events set
    processing_status = 'processing',
    lease_epoch = lease_epoch + 1,
    lease_token = lease,
    lease_expires_at = now() + interval '5 minutes',
    attempt_count = attempt_count + 1,
    safe_failure_code = null
  where id = event_row.id
  returning * into event_row;
  return jsonb_build_object(
    'claimed', true,
    'duplicate', false,
    'in_flight', false,
    'lease_token', event_row.lease_token,
    'lease_epoch', event_row.lease_epoch
  );
end;
$_$;


--
-- Name: stripe_server_finish_webhook_event(text, text, uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.stripe_server_finish_webhook_event(p_environment text, p_provider_event_id text, p_lease_token uuid, p_disposition text, p_safe_failure_code text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $_$
declare
  next_status text;
begin
  perform private.require_stripe_service_role();
  if p_disposition not in ('processed', 'ignored', 'failed') then
    raise exception 'stripe_webhook_disposition_invalid';
  end if;
  if p_safe_failure_code is not null and p_safe_failure_code !~ '^[a-z0-9_]{1,100}$' then
    raise exception 'stripe_webhook_failure_code_invalid';
  end if;
  next_status := p_disposition;
  update private.stripe_webhook_events set
    processing_status = next_status,
    safe_failure_code = case when next_status = 'failed' then p_safe_failure_code else null end,
    processed_at = case when next_status in ('processed', 'ignored') then now() else null end,
    lease_token = null,
    lease_expires_at = null
  where environment = p_environment
    and provider_event_id = p_provider_event_id
    and processing_status = 'processing'
    and lease_token = p_lease_token;
  if not found then
    raise exception 'stripe_webhook_lease_lost' using errcode = '40001';
  end if;
  return jsonb_build_object('ok', true, 'status', next_status);
end;
$_$;


--
-- Name: stripe_server_prepare_assignment_payment(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.stripe_server_prepare_assignment_payment(p_payer_id uuid, p_assignment_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  controls private.stripe_runtime_controls%rowtype;
  assignment public.job_assignments%rowtype;
  job public.jobs%rowtype;
  connected private.stripe_connected_accounts%rowtype;
  ledger private.stripe_payment_intents%rowtype;
  env text;
  gross_big bigint;
  gross integer;
  fee integer;
  net integer;
begin
  perform private.require_stripe_service_role();
  if p_payer_id is null or p_assignment_id is null then
    return jsonb_build_object('ok', false, 'code', 'invalid_payment_request');
  end if;
  select * into strict controls from private.stripe_runtime_controls where singleton;
  if controls.mode = 'disabled'
    or not controls.payments_enabled
    or not controls.job_funding_enabled then
    return jsonb_build_object('ok', false, 'code', 'stripe_job_funding_disabled');
  end if;
  if controls.mode = 'live' and (not controls.live_mode_enabled or not controls.live_owner_approved) then
    return jsonb_build_object('ok', false, 'code', 'stripe_live_not_approved');
  end if;
  env := case controls.mode when 'sandbox' then 'test' when 'live' then 'live' else null end;

  select * into assignment from public.job_assignments where id = p_assignment_id for update;
  if not found or assignment.adult_user_id <> p_payer_id
    or assignment.status not in ('accepted', 'in_progress', 'awaiting_confirmation') then
    return jsonb_build_object('ok', false, 'code', 'active_assignment_required');
  end if;
  select * into job from public.jobs where id = assignment.job_id;
  if not found or job.status not in ('filled', 'in_progress') then
    return jsonb_build_object('ok', false, 'code', 'active_assignment_required');
  end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = p_payer_id and p.role = 'adult'::public.mort_role and p.account_status = 'active'
  ) or not exists (
    select 1 from public.verification_cases vc
    where vc.user_id = p_payer_id and vc.verification_type = 'identity'
      and vc.status = 'verified'::public.mort_verification_status
      and (vc.expires_at is null or vc.expires_at > now())
  ) then
    return jsonb_build_object('ok', false, 'code', 'verified_adult_payer_required');
  end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = assignment.teen_user_id and p.role = 'teen'::public.mort_role and p.account_status = 'active'
      and p.date_of_birth is not null
      and extract(year from age(current_date, p.date_of_birth)) between job.age_min and job.age_max
  ) or not exists (
    select 1 from public.verification_cases vc
    where vc.user_id = assignment.teen_user_id and vc.verification_type = 'age'
      and vc.status = 'verified'::public.mort_verification_status
      and (vc.expires_at is null or vc.expires_at > now())
  ) then
    return jsonb_build_object('ok', false, 'code', 'verified_teen_payee_required');
  end if;
  if not controls.connected_accounts_approved or not controls.payouts_approved then
    return jsonb_build_object('ok', false, 'code', 'stripe_connected_accounts_not_approved');
  end if;
  select * into connected from private.stripe_connected_accounts
  where user_id = assignment.teen_user_id and environment = env;
  if not found or not connected.payouts_enabled or connected.transfers_capability_status <> 'active'
    or connected.requirements_status <> 'satisfied' then
    return jsonb_build_object('ok', false, 'code', 'verified_connected_payout_account_required');
  end if;

  gross_big := round(assignment.agreed_amount * 100)::bigint;
  if gross_big < 1000 or gross_big > 99999999 then
    return jsonb_build_object('ok', false, 'code', 'assignment_amount_not_fundable');
  end if;
  gross := gross_big::integer;
  fee := controls.service_fee_cents;
  net := gross - fee;
  if fee < 0 or net <= 0 then
    return jsonb_build_object('ok', false, 'code', 'assignment_amount_not_fundable');
  end if;

  select * into ledger from private.stripe_payment_intents
  where assignment_id = assignment.id and environment = env and operation_version = 1
  for update;
  if not found then
    insert into private.stripe_payment_intents(
      assignment_id, payer_id, payee_id, environment, operation_version,
      gross_amount_cents, service_fee_cents, teen_net_cents, currency_code,
      idempotency_key, status
    ) values (
      assignment.id, assignment.adult_user_id, assignment.teen_user_id, env, 1,
      gross, fee, net, controls.currency_code,
      'mort:' || env || ':assignment:' || assignment.id::text || ':payment:v1', 'prepared'
    ) returning * into ledger;
  elsif ledger.payer_id <> assignment.adult_user_id
    or ledger.payee_id <> assignment.teen_user_id
    or ledger.gross_amount_cents <> gross
    or ledger.service_fee_cents <> fee
    or ledger.currency_code <> controls.currency_code then
    return jsonb_build_object('ok', false, 'code', 'payment_snapshot_conflict');
  end if;

  return jsonb_build_object(
    'ok', true,
    'ledger_id', ledger.id,
    'assignment_id', ledger.assignment_id,
    'environment', ledger.environment,
    'gross_amount_cents', ledger.gross_amount_cents,
    'service_fee_cents', ledger.service_fee_cents,
    'teen_net_cents', ledger.teen_net_cents,
    'currency_code', ledger.currency_code,
    'idempotency_key', ledger.idempotency_key,
    'provider_payment_intent_id', ledger.provider_payment_intent_id,
    'status', ledger.status
  );
end;
$$;


--
-- Name: FUNCTION stripe_server_prepare_assignment_payment(p_payer_id uuid, p_assignment_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.stripe_server_prepare_assignment_payment(p_payer_id uuid, p_assignment_id uuid) IS 'Builds an immutable, idempotent server-authored funding snapshot for an accepted assignment; blocked unless Stripe live/sandbox and payout gates are explicitly enabled.';


--
-- Name: stripe_server_record_assignment_payment_intent(uuid, text, text, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.stripe_server_record_assignment_payment_intent(p_ledger_id uuid, p_provider_payment_intent_id text, p_provider_status text, p_provider_created_at timestamp with time zone) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $_$
declare
  ledger private.stripe_payment_intents%rowtype;
  mapped_status text;
begin
  perform private.require_stripe_service_role();
  if p_provider_payment_intent_id !~ '^pi_[A-Za-z0-9]+$' then
    raise exception 'stripe_payment_intent_id_invalid';
  end if;
  mapped_status := case p_provider_status
    when 'requires_payment_method' then 'requires_payment_method'
    when 'requires_action' then 'requires_action'
    when 'processing' then 'processing'
    when 'succeeded' then 'succeeded'
    when 'canceled' then 'cancelled'
    when 'requires_confirmation' then 'requires_payment_method'
    else 'unknown'
  end;
  select * into strict ledger from private.stripe_payment_intents where id = p_ledger_id for update;
  if ledger.provider_payment_intent_id is not null
    and ledger.provider_payment_intent_id <> p_provider_payment_intent_id then
    raise exception 'stripe_payment_intent_conflict';
  end if;
  update private.stripe_payment_intents
  set provider_payment_intent_id = p_provider_payment_intent_id,
      status = mapped_status,
      last_provider_event_at = coalesce(p_provider_created_at, last_provider_event_at),
      updated_at = now()
  where id = p_ledger_id
  returning * into ledger;
  return jsonb_build_object(
    'ledger_id', ledger.id,
    'provider_payment_intent_id', ledger.provider_payment_intent_id,
    'status', ledger.status
  );
end;
$_$;


--
-- Name: FUNCTION stripe_server_record_assignment_payment_intent(p_ledger_id uuid, p_provider_payment_intent_id text, p_provider_status text, p_provider_created_at timestamp with time zone); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.stripe_server_record_assignment_payment_intent(p_ledger_id uuid, p_provider_payment_intent_id text, p_provider_status text, p_provider_created_at timestamp with time zone) IS 'Service-only persistence for a Stripe PaymentIntent created from the server-authored assignment snapshot.';


--
-- Name: submit_application_proof(uuid, uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.submit_application_proof(p_proof_id uuid, p_application_id uuid, p_storage_path text, p_note text) RETURNS jsonb
    LANGUAGE sql
    SET search_path TO ''
    AS $_$
  select private.submit_application_proof_internal($1,$2,$3,$4)
$_$;


--
-- Name: submit_job_application(uuid, text, boolean, uuid[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.submit_job_application(p_job_id uuid, p_note text DEFAULT NULL::text, p_availability_confirmed boolean DEFAULT false, p_portfolio_ids uuid[] DEFAULT '{}'::uuid[]) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
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


--
-- Name: FUNCTION submit_job_application(p_job_id uuid, p_note text, p_availability_confirmed boolean, p_portfolio_ids uuid[]); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.submit_job_application(p_job_id uuid, p_note text, p_availability_confirmed boolean, p_portfolio_ids uuid[]) IS 'Compatibility RPC for the Flutter application flow; delegates age, role, and job checks to server-side guards.';


--
-- Name: submit_legal_acceptance(uuid, boolean, boolean, text, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.submit_legal_acceptance(p_document_version_id uuid, p_affirmative_checkbox boolean, p_teen_summary_viewed boolean, p_electronic_signature_text text, p_platform text, p_app_version text, p_language_code text DEFAULT 'en-US'::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_actor public.profiles%rowtype;
  v_version public.legal_document_versions%rowtype;
  v_document public.legal_documents%rowtype;
  v_acceptance public.legal_acceptances%rowtype;
  v_age_band text;
  v_inserted boolean := false;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if not coalesce(p_affirmative_checkbox, false) then
    return jsonb_build_object('ok', false, 'code', 'affirmative_checkbox_required');
  end if;
  if char_length(btrim(coalesce(p_platform, ''))) not between 2 and 40
     or char_length(btrim(coalesce(p_app_version, ''))) not between 1 and 40 then
    return jsonb_build_object('ok', false, 'code', 'platform_and_app_version_required');
  end if;

  select * into v_actor
  from public.profiles
  where id = auth.uid()
    and (
      account_status = 'active'
      or (
        account_status = 'pending'
        and exists (
          select 1 from auth.users auth_user
          where auth_user.id = public.profiles.id
            and auth_user.email_confirmed_at is not null
        )
      )
    )
  for share;
  if v_actor.id is null or v_actor.role is null or v_actor.role = 'pending' then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;
  v_age_band := private.mort_legal_age_band(v_actor.date_of_birth);
  if v_age_band in ('unknown', 'ineligible') then
    return jsonb_build_object('ok', false, 'code', 'eligible_date_of_birth_required');
  end if;

  select * into v_version
  from public.legal_document_versions
  where id = p_document_version_id
    and publication_status = 'published'
    and effective_at is not null
    and effective_at <= now()
  for share;
  if v_version.id is null then
    return jsonb_build_object('ok', false, 'code', 'published_effective_version_required');
  end if;

  select * into v_document
  from public.legal_documents
  where id = v_version.document_id
    and publication_status = 'published';
  if v_document.id is null then
    return jsonb_build_object('ok', false, 'code', 'published_document_required');
  end if;

  if not exists (
    select 1 from public.legal_role_requirements requirement
    where requirement.document_id = v_document.id
      and requirement.role = v_actor.role
      and requirement.age_band in ('all', v_age_band)
  ) then
    return jsonb_build_object('ok', false, 'code', 'legal_document_not_available_for_role');
  end if;
  if v_actor.role = 'teen' and not coalesce(p_teen_summary_viewed, false) then
    return jsonb_build_object('ok', false, 'code', 'teen_summary_must_be_viewed_first');
  end if;
  if v_version.requires_electronic_signature
     and char_length(btrim(coalesce(p_electronic_signature_text, ''))) < 3 then
    return jsonb_build_object('ok', false, 'code', 'electronic_signature_text_required');
  end if;

  insert into public.legal_acceptances (
    user_id, role, age_band, document_id, document_version_id,
    content_hash, effective_date, platform, app_version, language_code,
    jurisdiction_policy, acceptance_ui_version, affirmative_checkbox,
    electronic_signature_text
  ) values (
    v_actor.id, v_actor.role, v_age_band, v_document.id, v_version.id,
    v_version.content_hash, v_version.effective_at, left(btrim(p_platform), 40),
    left(btrim(p_app_version), 40), left(btrim(coalesce(p_language_code, 'en-US')), 20),
    v_version.jurisdiction_policy, v_version.acceptance_ui_version, true,
    nullif(left(btrim(coalesce(p_electronic_signature_text, '')), 200), '')
  )
  on conflict (user_id, document_version_id) where active
  do nothing
  returning * into v_acceptance;
  v_inserted := found;

  if not v_inserted then
    select * into v_acceptance
    from public.legal_acceptances
    where user_id = v_actor.id
      and document_version_id = v_version.id
      and active;
  else
    insert into public.legal_acceptance_audit_events (
      user_id, document_id, document_version_id, acceptance_id,
      event_type, event_metadata
    ) values (
      v_actor.id, v_document.id, v_version.id, v_acceptance.id,
      'accepted', jsonb_build_object(
        'role', v_actor.role,
        'age_band', v_age_band,
        'platform', left(btrim(p_platform), 40),
        'app_version', left(btrim(p_app_version), 40),
        'affirmative_checkbox', true,
        'teen_summary_viewed', case when v_actor.role = 'teen' then true else null end
      )
    );
  end if;

  return jsonb_build_object(
    'ok', true,
    'acceptance_id', v_acceptance.id,
    'document_version_id', v_version.id,
    'content_hash', v_version.content_hash,
    'accepted_at', v_acceptance.accepted_at,
    'already_recorded', not v_inserted
  );
end;
$$;


--
-- Name: submit_my_verification_evidence_v1(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.submit_my_verification_evidence_v1(p_verification_type text, p_evidence_path text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $_$
declare
  v_user uuid := auth.uid();
  v_dob date;
  v_age integer;
  v_expected text;
begin
  if v_user is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;

  select p.date_of_birth into v_dob from public.profiles p where p.id = v_user;
  if v_dob is null then
    return jsonb_build_object('ok', false, 'code', 'dob_required');
  end if;
  v_age := private.mort_age_years(v_dob);
  if v_age < 13 then
    return jsonb_build_object('ok', false, 'code', 'minimum_age_required');
  end if;
  v_expected := case when v_age between 13 and 17 then 'school_id' else 'identity' end;
  if p_verification_type is null or p_verification_type <> v_expected then
    return jsonb_build_object('ok', false, 'code', 'evidence_type_age_mismatch', 'expected', v_expected);
  end if;

  if p_evidence_path is null
     or p_evidence_path !~ ('^' || v_user::text
        || '/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|png|heic|webp|pdf)$') then
    return jsonb_build_object('ok', false, 'code', 'invalid_evidence_path');
  end if;

  if exists (
    select 1 from public.verification_cases vc
    where vc.user_id = v_user and vc.status in ('pending','needs_review')
  ) then
    return jsonb_build_object('ok', false, 'code', 'case_already_pending');
  end if;
  if (
    select count(*) from public.verification_cases vc
    where vc.user_id = v_user and vc.created_at > now() - interval '24 hours'
  ) >= 5 then
    return jsonb_build_object('ok', false, 'code', 'too_many_submissions');
  end if;

  insert into public.verification_cases (
    user_id, verification_type, status, provider, evidence_path, submitted_at
  ) values (
    v_user, p_verification_type, 'pending', 'mort_staff_review', p_evidence_path, now()
  );

  update public.profiles
  set verification_status = 'pending', updated_at = now()
  where id = v_user;

  insert into public.admin_audit_log (actor_id, action, target_type, target_id, reason, metadata)
  values (
    v_user, 'verification_evidence_submitted', 'verification_case', p_evidence_path, null,
    jsonb_build_object('verification_type', p_verification_type, 'age_band',
      case when v_age between 13 and 17 then 'minor' else 'adult' end)
  );

  return jsonb_build_object('ok', true, 'status', 'pending');
end;
$_$;


--
-- Name: submit_safety_cancellation(uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.submit_safety_cancellation(p_application_id uuid, p_reason text, p_details text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE sql
    SET search_path TO ''
    AS $$
  select private.submit_safety_cancellation_internal(
    p_application_id,
    p_reason,
    p_details
  );
$$;


--
-- Name: FUNCTION submit_safety_cancellation(p_application_id uuid, p_reason text, p_details text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.submit_safety_cancellation(p_application_id uuid, p_reason text, p_details text) IS 'Authenticated participant-only safety cancellation RPC for the current job_assignments model.';


--
-- Name: submit_safety_report_v2(uuid, uuid, uuid, uuid, uuid, text, text, boolean, text, timestamp with time zone, text, text, boolean, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.submit_safety_report_v2(p_target_user_id uuid, p_target_job_id uuid, p_target_message_id uuid, p_target_review_id uuid, p_application_id uuid, p_category text, p_severity text, p_immediate_danger boolean, p_details text, p_occurred_at timestamp with time zone, p_location_type text, p_desired_outcome text, p_confidential_safety_feedback boolean, p_client_request_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  reporter uuid := auth.uid();
  report_id uuid;
  clean_details text := btrim(coalesce(p_details, ''));
  clean_location_type text := nullif(btrim(coalesce(p_location_type, '')), '');
  clean_desired_outcome text := nullif(btrim(coalesce(p_desired_outcome, '')), '');
  v_existing public.safety_reports%rowtype;
  v_count integer;
begin
  if reporter is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_client_request_id is null then
    return jsonb_build_object('ok', false, 'code', 'client_request_id_required');
  end if;
  if p_target_user_id = reporter then
    return jsonb_build_object('ok', false, 'code', 'cannot_report_self');
  end if;
  if char_length(clean_details) < 10 or char_length(clean_details) > 4000 then
    return jsonb_build_object('ok', false, 'code', 'safety_report_details_invalid');
  end if;
  if p_category is null or p_category not in (
    'harassment', 'unsafe_meeting', 'scam', 'inappropriate_content',
    'privacy', 'underage_concern', 'payment', 'other'
  ) then
    return jsonb_build_object('ok', false, 'code', 'safety_report_category_invalid');
  end if;
  if p_severity is null or p_severity not in ('low', 'normal', 'high', 'critical') then
    return jsonb_build_object('ok', false, 'code', 'safety_report_severity_invalid');
  end if;

  -- Private artifacts can only be reported by someone who participated in them.
  if p_target_message_id is not null and not exists (
    select 1
    from public.messages message
    join public.conversation_members member
      on member.conversation_id = message.conversation_id
    where message.id = p_target_message_id
      and member.user_id = reporter
      and (
        p_target_user_id is null
        or exists (
          select 1 from public.conversation_members target_member
          where target_member.conversation_id = message.conversation_id
            and target_member.user_id = p_target_user_id
        )
      )
  ) then
    return jsonb_build_object('ok', false, 'code', 'report_target_not_authorized');
  end if;
  if p_application_id is not null and not exists (
    select 1
    from public.job_applications application
    join public.jobs job on job.id = application.job_id
    where application.id = p_application_id
      and (
        application.applicant_id = reporter
        or job.poster_id = reporter
      )
      and (
        p_target_user_id is null
        or (application.applicant_id = reporter and job.poster_id = p_target_user_id)
        or (job.poster_id = reporter and application.applicant_id = p_target_user_id)
      )
  ) then
    return jsonb_build_object('ok', false, 'code', 'report_target_not_authorized');
  end if;
  if p_target_review_id is not null and not exists (
    select 1
    from public.reviews review
    where review.id = p_target_review_id
      and (review.reviewer_id = reporter or review.subject_id = reporter)
      and (
        p_target_user_id is null
        or (review.reviewer_id = reporter and review.subject_id = p_target_user_id)
        or (review.subject_id = reporter and review.reviewer_id = p_target_user_id)
      )
  ) then
    return jsonb_build_object('ok', false, 'code', 'report_target_not_authorized');
  end if;
  if p_target_job_id is not null and not exists (
    select 1
    from public.jobs job
    where job.id = p_target_job_id
      and (
        job.poster_id = reporter
        or exists (
          select 1 from public.job_applications application
          where application.job_id = job.id and application.applicant_id = reporter
        )
        or exists (
          select 1 from public.saved_jobs saved
          where saved.job_id = job.id and saved.user_id = reporter
        )
        or exists (
          select 1 from public.conversations conversation
          join public.conversation_members member on member.conversation_id = conversation.id
          where conversation.job_id = job.id and member.user_id = reporter
        )
        or (
          job.status = 'open'::public.mort_job_status
          and job.safety_review_status = 'approved'
          and exists (
            select 1 from public.profiles poster
            where poster.id = job.poster_id and poster.account_status = 'active'
          )
        )
      )
  ) then
    return jsonb_build_object('ok', false, 'code', 'report_target_not_authorized');
  end if;

  -- Serialize retries for the same request ID before applying rate limits.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(reporter::text || ':safety-report-request:' || p_client_request_id::text, 0)
  );
  select * into v_existing
  from public.safety_reports report
  where report.reporter_id = reporter
    and report.client_request_id = p_client_request_id
  for update;
  if found then
    if v_existing.reported_user_id is distinct from p_target_user_id
      or v_existing.job_id is distinct from p_target_job_id
      or v_existing.message_id is distinct from p_target_message_id
      or v_existing.target_review_id is distinct from p_target_review_id
      or v_existing.application_id is distinct from p_application_id
      or v_existing.category is distinct from p_category
      or v_existing.severity is distinct from p_severity
      or v_existing.immediate_danger is distinct from coalesce(p_immediate_danger, false)
      or v_existing.description is distinct from clean_details
      or v_existing.occurred_at is distinct from p_occurred_at
      or v_existing.location_type is distinct from clean_location_type
      or v_existing.desired_outcome is distinct from clean_desired_outcome
      or v_existing.confidential_safety_feedback is distinct from coalesce(p_confidential_safety_feedback, false) then
      return jsonb_build_object('ok', false, 'code', 'safety_request_payload_mismatch');
    end if;
    return jsonb_build_object(
      'ok', true,
      'report_id', v_existing.id,
      'immediate_danger', v_existing.immediate_danger,
      'replayed', true
    );
  end if;

  -- Urgent reports have a separate, more generous throttle so the ordinary
  -- daily limit cannot suppress a time-sensitive safety report.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(reporter::text || ':safety-report-limit:' || coalesce(p_immediate_danger, false)::text, 0)
  );
  if coalesce(p_immediate_danger, false) then
    select count(*) into v_count
    from public.safety_reports report
    where report.reporter_id = reporter
      and report.immediate_danger
      and report.created_at >= now() - interval '1 hour';
    if v_count >= 20 then
      return jsonb_build_object(
        'ok', false, 'code', 'urgent_safety_rate_limited',
        'emergency_guidance_required', true
      );
    end if;
  else
    select count(*) into v_count
    from public.safety_reports report
    where report.reporter_id = reporter
      and not report.immediate_danger
      and report.created_at >= now() - interval '1 day';
    if v_count >= 15 then
      return jsonb_build_object('ok', false, 'code', 'safety_report_rate_limited');
    end if;
  end if;

  insert into public.safety_reports (
    reporter_id, reported_user_id, job_id, message_id, target_review_id,
    application_id, category, description, status, severity, immediate_danger,
    occurred_at, location_type, desired_outcome, confidential_safety_feedback,
    client_request_id
  ) values (
    reporter, p_target_user_id, p_target_job_id, p_target_message_id,
    p_target_review_id, p_application_id, p_category, clean_details, 'open',
    p_severity, coalesce(p_immediate_danger, false), p_occurred_at,
    clean_location_type, clean_desired_outcome,
    coalesce(p_confidential_safety_feedback, false), p_client_request_id
  ) returning id into report_id;

  return jsonb_build_object(
    'ok', true,
    'report_id', report_id,
    'immediate_danger', coalesce(p_immediate_danger, false),
    'replayed', false
  );
end;
$$;


--
-- Name: sync_safety_agreement_location_version(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_safety_agreement_location_version() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin
  select location.location_version
    into new.location_version
  from private.job_private_locations location
  where location.job_id = new.job_id;
  new.location_version := coalesce(new.location_version, 0);
  return new;
end;
$$;


--
-- Name: unblock_user_v2(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.unblock_user_v2(p_blocked_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_user_id uuid := auth.uid();
  v_key bigint;
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_blocked_id is null or p_blocked_id = v_user_id then
    return jsonb_build_object('ok', false, 'code', 'invalid_block_target');
  end if;
  v_key := pg_catalog.hashtextextended(least(v_user_id, p_blocked_id)::text || ':' || greatest(v_user_id, p_blocked_id)::text, 0);
  perform pg_catalog.pg_advisory_xact_lock(v_key);
  delete from public.user_blocks where blocker_id = v_user_id and blocked_id = p_blocked_id;
  return jsonb_build_object('ok', true, 'blocked_id', p_blocked_id);
end;
$$;


--
-- Name: unlink_guardian(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.unlink_guardian(p_link_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  user_id uuid := auth.uid();
  affected integer;
  teen_id uuid;
begin
  if user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_link_id is null then
    return jsonb_build_object('ok', false, 'code', 'guardian_link_id_required');
  end if;

  update public.guardian_links
  set status = 'revoked', updated_at = now()
  where id = p_link_id
    and status = 'active'
    and (teen_user_id = user_id or guardian_user_id = user_id)
  returning teen_user_id into teen_id;
  get diagnostics affected = row_count;
  if affected <> 1 then
    return jsonb_build_object('ok', false, 'code', 'active_guardian_link_not_found');
  end if;

  update public.profiles
  set guardian_setup_status = 'not_started', updated_at = now()
  where id = teen_id and role = 'teen'::public.mort_role;

  return jsonb_build_object('ok', true, 'link_id', p_link_id, 'status', 'revoked');
end;
$$;


--
-- Name: FUNCTION unlink_guardian(p_link_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.unlink_guardian(p_link_id uuid) IS 'Allows either participant to revoke their own active guardian link while preserving the historical row.';


--
-- Name: update_my_job_application_status(uuid, text, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_my_job_application_status(p_application_id uuid, p_action text, p_expected_updated_at timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$ declare v_user uuid:=auth.uid(); v_role public.mort_role:=private.current_role(); v_app public.job_applications%rowtype; v_job public.jobs%rowtype; v_assignment uuid; v_recipient uuid; v_title text; v_body text; v_updated jsonb; begin if v_user is null or not private.is_active_user() then return jsonb_build_object('ok',false,'code','active_account_required'); end if; select ja.* into v_app from public.job_applications ja where ja.id=p_application_id and (ja.applicant_id=v_user or exists(select 1 from public.jobs j where j.id=ja.job_id and j.poster_id=v_user)) for update; if not found then return jsonb_build_object('ok',false,'code','application_not_available'); end if; if p_expected_updated_at is not null and v_app.updated_at<>p_expected_updated_at then return jsonb_build_object('ok',false,'code','application_changed_refresh'); end if; select * into v_job from public.jobs where id=v_app.job_id; if p_action='accepted' and v_role='adult'::public.mort_role and v_job.poster_id=v_user then v_assignment:=public.mort_accept_job_application(v_app.id); elsif p_action in ('shortlisted','rejected','viewed') and v_role='adult'::public.mort_role and v_job.poster_id=v_user and v_app.status in ('submitted'::public.mort_application_status,'shortlisted'::public.mort_application_status) then if p_action='viewed' then update public.job_applications set viewed_at=coalesce(viewed_at,now()) where id=v_app.id; else update public.job_applications set status=p_action::public.mort_application_status where id=v_app.id; v_recipient:=v_app.applicant_id; v_title:=case when p_action='shortlisted' then 'Application shortlisted' else 'Application update' end; v_body:=case when p_action='shortlisted' then 'Your application was shortlisted.' else 'Your application was declined.' end; end if; elsif p_action='withdrawn' and v_role='teen'::public.mort_role and v_app.applicant_id=v_user and v_app.status in ('submitted'::public.mort_application_status,'shortlisted'::public.mort_application_status) then update public.job_applications set status='withdrawn'::public.mort_application_status,withdrawn_at=now() where id=v_app.id; v_recipient:=v_job.poster_id; v_title:='Application withdrawn'; v_body:='A teen withdrew their application.'; else return jsonb_build_object('ok',false,'code','application_action_not_allowed'); end if; if v_recipient is not null then insert into public.notifications(user_id,notification_type,title,body,data) values(v_recipient,'application_status',v_title,v_body,jsonb_build_object('application_id',v_app.id,'job_id',v_app.job_id)); end if; v_updated:=public.get_my_job_applications(v_app.id)->'items'->0; return jsonb_build_object('ok',true,'application',v_updated,'assignment_id',v_assignment); end; $$;


--
-- Name: FUNCTION update_my_job_application_status(p_application_id uuid, p_action text, p_expected_updated_at timestamp with time zone); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.update_my_job_application_status(p_application_id uuid, p_action text, p_expected_updated_at timestamp with time zone) IS 'Applies allowlisted application transitions for the current active teen or adult; acceptance delegates to the verified assignment flow.';


--
-- Name: guardian_invite_accept_limits; Type: TABLE; Schema: private; Owner: -
--

CREATE TABLE private.guardian_invite_accept_limits (
    user_id uuid NOT NULL,
    window_started_at timestamp with time zone NOT NULL,
    attempt_count integer NOT NULL,
    CONSTRAINT guardian_invite_accept_limits_attempt_count_check CHECK ((attempt_count > 0))
);

ALTER TABLE ONLY private.guardian_invite_accept_limits FORCE ROW LEVEL SECURITY;


--
-- Name: guardian_invite_codes; Type: TABLE; Schema: private; Owner: -
--

CREATE TABLE private.guardian_invite_codes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    guardian_link_id uuid NOT NULL,
    teen_user_id uuid NOT NULL,
    code_sha256 text NOT NULL,
    invited_email text,
    expires_at timestamp with time zone NOT NULL,
    consumed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT guardian_invite_codes_code_sha256_check CHECK ((code_sha256 ~ '^[a-f0-9]{64}$'::text))
);

ALTER TABLE ONLY private.guardian_invite_codes FORCE ROW LEVEL SECURITY;


--
-- Name: TABLE guardian_invite_codes; Type: COMMENT; Schema: private; Owner: -
--

COMMENT ON TABLE private.guardian_invite_codes IS 'Private, expiring one-use guardian invite hashes. Raw invitation codes are returned only once to the teen who initiated the invite.';


--
-- Name: job_execution_events; Type: TABLE; Schema: private; Owner: -
--

CREATE TABLE private.job_execution_events (
    id bigint NOT NULL,
    assignment_id uuid NOT NULL,
    application_id uuid NOT NULL,
    actor_id uuid,
    event_type text NOT NULL,
    from_state text,
    to_state text,
    request_id uuid,
    safe_metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT job_execution_events_type_check CHECK ((event_type = ANY (ARRAY['start_pin_generated'::text, 'start_pin_failed_attempt'::text, 'start_pin_locked'::text, 'start_confirmed'::text, 'finish_pin_generated'::text, 'finish_pin_failed_attempt'::text, 'finish_pin_locked'::text, 'finish_confirmed'::text, 'finish_pin_unavailable_reported'::text, 'adult_cancellation_requested'::text, 'teen_abandonment_reported'::text, 'teen_abandonment_response'::text])))
);

ALTER TABLE ONLY private.job_execution_events FORCE ROW LEVEL SECURITY;


--
-- Name: job_execution_events_id_seq; Type: SEQUENCE; Schema: private; Owner: -
--

ALTER TABLE private.job_execution_events ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME private.job_execution_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: job_execution_sessions; Type: TABLE; Schema: private; Owner: -
--

CREATE TABLE private.job_execution_sessions (
    assignment_id uuid NOT NULL,
    application_id uuid NOT NULL,
    job_id uuid NOT NULL,
    execution_state text DEFAULT 'awaiting_start'::text NOT NULL,
    start_pin_hash text,
    start_pin_generated_at timestamp with time zone,
    start_pin_expires_at timestamp with time zone,
    start_pin_used_at timestamp with time zone,
    start_pin_attempt_count integer DEFAULT 0 NOT NULL,
    start_pin_locked_until timestamp with time zone,
    start_client_request_id uuid,
    finish_pin_hash text,
    finish_pin_generated_at timestamp with time zone,
    finish_pin_expires_at timestamp with time zone,
    finish_pin_used_at timestamp with time zone,
    finish_pin_attempt_count integer DEFAULT 0 NOT NULL,
    finish_pin_locked_until timestamp with time zone,
    finish_client_request_id uuid,
    completion_pending_at timestamp with time zone,
    review_window_ends_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT job_execution_sessions_attempts_check CHECK ((((start_pin_attempt_count >= 0) AND (start_pin_attempt_count <= 100)) AND ((finish_pin_attempt_count >= 0) AND (finish_pin_attempt_count <= 100)))),
    CONSTRAINT job_execution_sessions_finish_hash_check CHECK (((finish_pin_hash IS NULL) OR (finish_pin_hash ~~ '$2%'::text))),
    CONSTRAINT job_execution_sessions_start_hash_check CHECK (((start_pin_hash IS NULL) OR (start_pin_hash ~~ '$2%'::text))),
    CONSTRAINT job_execution_sessions_state_check CHECK ((execution_state = ANY (ARRAY['awaiting_start'::text, 'start_pin_active'::text, 'in_progress'::text, 'finish_pin_active'::text, 'completion_pending_release'::text, 'disputed'::text, 'cancelled'::text, 'completed'::text])))
);

ALTER TABLE ONLY private.job_execution_sessions FORCE ROW LEVEL SECURITY;


--
-- Name: job_pin_confirmation_requests; Type: TABLE; Schema: private; Owner: -
--

CREATE TABLE private.job_pin_confirmation_requests (
    actor_id uuid NOT NULL,
    client_request_id uuid NOT NULL,
    application_id uuid NOT NULL,
    pin_kind text NOT NULL,
    pin_hash text NOT NULL,
    person_matches_profile boolean,
    response jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT job_pin_confirmation_request_hash_check CHECK ((pin_hash ~~ '$2%'::text)),
    CONSTRAINT job_pin_confirmation_requests_pin_kind_check CHECK ((pin_kind = ANY (ARRAY['start'::text, 'finish'::text])))
);

ALTER TABLE ONLY private.job_pin_confirmation_requests FORCE ROW LEVEL SECURITY;


--
-- Name: job_private_location_access_events; Type: TABLE; Schema: private; Owner: -
--

CREATE TABLE private.job_private_location_access_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    actor_id uuid,
    resource_type text NOT NULL,
    resource_id uuid NOT NULL,
    action text NOT NULL,
    reason text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY private.job_private_location_access_events FORCE ROW LEVEL SECURITY;


--
-- Name: job_private_location_history; Type: TABLE; Schema: private; Owner: -
--

CREATE TABLE private.job_private_location_history (
    history_id bigint NOT NULL,
    job_id uuid NOT NULL,
    poster_id uuid NOT NULL,
    exact_address text NOT NULL,
    address_fingerprint text NOT NULL,
    arrival_instructions text,
    access_notes text,
    location_version integer NOT NULL,
    original_updated_at timestamp with time zone NOT NULL,
    archived_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY private.job_private_location_history FORCE ROW LEVEL SECURITY;


--
-- Name: job_private_location_history_history_id_seq; Type: SEQUENCE; Schema: private; Owner: -
--

ALTER TABLE private.job_private_location_history ALTER COLUMN history_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME private.job_private_location_history_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: job_private_location_requests; Type: TABLE; Schema: private; Owner: -
--

CREATE TABLE private.job_private_location_requests (
    actor_id uuid NOT NULL,
    client_request_id uuid NOT NULL,
    job_id uuid NOT NULL,
    payload_sha256 text NOT NULL,
    response jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT job_private_location_requests_payload_sha256_check CHECK ((payload_sha256 ~ '^[0-9a-f]{64}$'::text))
);

ALTER TABLE ONLY private.job_private_location_requests FORCE ROW LEVEL SECURITY;


--
-- Name: job_private_locations; Type: TABLE; Schema: private; Owner: -
--

CREATE TABLE private.job_private_locations (
    job_id uuid NOT NULL,
    poster_id uuid NOT NULL,
    exact_address text NOT NULL,
    address_fingerprint text NOT NULL,
    arrival_instructions text,
    access_notes text,
    latitude double precision,
    longitude double precision,
    location_source text DEFAULT 'address_text'::text NOT NULL,
    location_accuracy_meters double precision,
    location_version integer DEFAULT 1 NOT NULL,
    verified_for_job boolean DEFAULT false NOT NULL,
    captured_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT job_private_locations_accuracy_valid CHECK (((location_accuracy_meters IS NULL) OR ((location_accuracy_meters >= (0)::double precision) AND (location_accuracy_meters <= (50000)::double precision)))),
    CONSTRAINT job_private_locations_address_fingerprint_check CHECK ((address_fingerprint ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT job_private_locations_address_length CHECK (((char_length(btrim(exact_address)) >= 5) AND (char_length(btrim(exact_address)) <= 500))),
    CONSTRAINT job_private_locations_coordinates_valid CHECK ((((latitude IS NULL) = (longitude IS NULL)) AND ((latitude IS NULL) OR (((latitude >= ('-90'::integer)::double precision) AND (latitude <= (90)::double precision)) AND ((longitude >= ('-180'::integer)::double precision) AND (longitude <= (180)::double precision)))))),
    CONSTRAINT job_private_locations_source_check CHECK ((location_source = ANY (ARRAY['address_text'::text, 'precise_gps'::text])))
);

ALTER TABLE ONLY private.job_private_locations FORCE ROW LEVEL SECURITY;


--
-- Name: job_safety_agreement_history; Type: TABLE; Schema: private; Owner: -
--

CREATE TABLE private.job_safety_agreement_history (
    history_id bigint NOT NULL,
    agreement_id uuid NOT NULL,
    application_id uuid NOT NULL,
    job_id uuid NOT NULL,
    teen_id uuid NOT NULL,
    adult_id uuid NOT NULL,
    agreement_version integer NOT NULL,
    terms_snapshot jsonb NOT NULL,
    material_terms_hash text NOT NULL,
    status text NOT NULL,
    teen_confirmed_at timestamp with time zone,
    adult_confirmed_at timestamp with time zone,
    teen_confirmed_version integer,
    adult_confirmed_version integer,
    location_version integer NOT NULL,
    original_created_at timestamp with time zone NOT NULL,
    original_updated_at timestamp with time zone NOT NULL,
    archived_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY private.job_safety_agreement_history FORCE ROW LEVEL SECURITY;


--
-- Name: job_safety_agreement_history_history_id_seq; Type: SEQUENCE; Schema: private; Owner: -
--

ALTER TABLE private.job_safety_agreement_history ALTER COLUMN history_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME private.job_safety_agreement_history_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: mort_edge_action_limits; Type: TABLE; Schema: private; Owner: -
--

CREATE TABLE private.mort_edge_action_limits (
    user_id uuid NOT NULL,
    action text NOT NULL,
    window_started_at timestamp with time zone NOT NULL,
    request_count integer NOT NULL,
    CONSTRAINT mort_edge_action_limits_action_check CHECK ((action ~ '^[a-z0-9_]{1,80}$'::text)),
    CONSTRAINT mort_edge_action_limits_request_count_check CHECK ((request_count > 0))
);


--
-- Name: mort_job_mutation_requests; Type: TABLE; Schema: private; Owner: -
--

CREATE TABLE private.mort_job_mutation_requests (
    user_id uuid NOT NULL,
    client_request_id uuid NOT NULL,
    operation text NOT NULL,
    request_hash text NOT NULL,
    response jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: mort_onboarding_safety; Type: TABLE; Schema: private; Owner: -
--

CREATE TABLE private.mort_onboarding_safety (
    user_id uuid NOT NULL,
    notification_intent text NOT NULL,
    saved_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT mort_onboarding_safety_notification_intent_check CHECK ((notification_intent = ANY (ARRAY['ask_later'::text, 'preferred'::text, 'not_preferred'::text])))
);

ALTER TABLE ONLY private.mort_onboarding_safety FORCE ROW LEVEL SECURITY;


--
-- Name: school_email_domains; Type: TABLE; Schema: private; Owner: -
--

CREATE TABLE private.school_email_domains (
    domain text NOT NULL,
    school_name text NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    verification_source text,
    verified_at timestamp with time zone,
    approved_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT school_email_domains_active_verified CHECK (((status <> 'active'::text) OR ((verified_at IS NOT NULL) AND (verification_source IS NOT NULL)))),
    CONSTRAINT school_email_domains_domain_format CHECK (((domain = lower(btrim(domain))) AND (domain !~ '[@[:space:]/]'::text) AND (POSITION(('.'::text) IN (domain)) > 1))),
    CONSTRAINT school_email_domains_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'active'::text, 'rejected'::text, 'suspended'::text])))
);


--
-- Name: stripe_connected_accounts; Type: TABLE; Schema: private; Owner: -
--

CREATE TABLE private.stripe_connected_accounts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    environment text NOT NULL,
    provider_account_id text NOT NULL,
    onboarding_status text DEFAULT 'pending'::text NOT NULL,
    details_submitted boolean DEFAULT false NOT NULL,
    charges_enabled boolean DEFAULT false NOT NULL,
    payouts_enabled boolean DEFAULT false NOT NULL,
    transfers_capability_status text DEFAULT 'inactive'::text NOT NULL,
    requirements_status text DEFAULT 'unknown'::text NOT NULL,
    country text,
    default_currency text,
    last_synchronized_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT stripe_connected_accounts_country_check CHECK (((country IS NULL) OR (country ~ '^[A-Z]{2}$'::text))),
    CONSTRAINT stripe_connected_accounts_default_currency_check CHECK (((default_currency IS NULL) OR (default_currency ~ '^[A-Z]{3}$'::text))),
    CONSTRAINT stripe_connected_accounts_environment_check CHECK ((environment = ANY (ARRAY['test'::text, 'live'::text]))),
    CONSTRAINT stripe_connected_accounts_onboarding_status_check CHECK ((onboarding_status = ANY (ARRAY['pending'::text, 'in_progress'::text, 'complete'::text, 'restricted'::text, 'action_required'::text, 'disconnected'::text]))),
    CONSTRAINT stripe_connected_accounts_provider_account_id_check CHECK ((provider_account_id ~ '^acct_[A-Za-z0-9]+$'::text)),
    CONSTRAINT stripe_connected_accounts_requirements_status_check CHECK ((requirements_status = ANY (ARRAY['unknown'::text, 'currently_due'::text, 'eventually_due'::text, 'past_due'::text, 'pending_verification'::text, 'satisfied'::text, 'restricted'::text]))),
    CONSTRAINT stripe_connected_accounts_transfers_capability_status_check CHECK ((transfers_capability_status = ANY (ARRAY['inactive'::text, 'pending'::text, 'active'::text, 'restricted'::text])))
);


--
-- Name: stripe_customers; Type: TABLE; Schema: private; Owner: -
--

CREATE TABLE private.stripe_customers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    environment text NOT NULL,
    provider_customer_id text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT stripe_customers_environment_check CHECK ((environment = ANY (ARRAY['test'::text, 'live'::text]))),
    CONSTRAINT stripe_customers_provider_customer_id_check CHECK ((provider_customer_id ~ '^cus_[A-Za-z0-9]+$'::text))
);


--
-- Name: stripe_payment_intents; Type: TABLE; Schema: private; Owner: -
--

CREATE TABLE private.stripe_payment_intents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    assignment_id uuid NOT NULL,
    payer_id uuid NOT NULL,
    payee_id uuid NOT NULL,
    environment text NOT NULL,
    operation_version integer DEFAULT 1 NOT NULL,
    gross_amount_cents integer NOT NULL,
    service_fee_cents integer NOT NULL,
    teen_net_cents integer NOT NULL,
    currency_code text DEFAULT 'USD'::text NOT NULL,
    provider_customer_id text,
    provider_payment_intent_id text,
    provider_charge_id text,
    idempotency_key text NOT NULL,
    status text DEFAULT 'prepared'::text NOT NULL,
    safe_failure_code text,
    last_provider_event_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT stripe_payment_intents_check CHECK (((teen_net_cents = (gross_amount_cents - service_fee_cents)) AND (teen_net_cents > 0))),
    CONSTRAINT stripe_payment_intents_check1 CHECK ((payer_id <> payee_id)),
    CONSTRAINT stripe_payment_intents_currency_code_check CHECK ((currency_code ~ '^[A-Z]{3}$'::text)),
    CONSTRAINT stripe_payment_intents_environment_check CHECK ((environment = ANY (ARRAY['test'::text, 'live'::text]))),
    CONSTRAINT stripe_payment_intents_gross_amount_cents_check CHECK ((gross_amount_cents >= 1000)),
    CONSTRAINT stripe_payment_intents_idempotency_key_check CHECK (((char_length(idempotency_key) >= 16) AND (char_length(idempotency_key) <= 200))),
    CONSTRAINT stripe_payment_intents_operation_version_check CHECK ((operation_version > 0)),
    CONSTRAINT stripe_payment_intents_provider_charge_id_check CHECK (((provider_charge_id IS NULL) OR (provider_charge_id ~ '^ch_[A-Za-z0-9]+$'::text))),
    CONSTRAINT stripe_payment_intents_provider_customer_id_check CHECK (((provider_customer_id IS NULL) OR (provider_customer_id ~ '^cus_[A-Za-z0-9]+$'::text))),
    CONSTRAINT stripe_payment_intents_provider_payment_intent_id_check CHECK (((provider_payment_intent_id IS NULL) OR (provider_payment_intent_id ~ '^pi_[A-Za-z0-9]+$'::text))),
    CONSTRAINT stripe_payment_intents_safe_failure_code_check CHECK (((safe_failure_code IS NULL) OR (safe_failure_code ~ '^[a-z0-9_]{1,100}$'::text))),
    CONSTRAINT stripe_payment_intents_service_fee_cents_check CHECK ((service_fee_cents >= 0)),
    CONSTRAINT stripe_payment_intents_status_check CHECK ((status = ANY (ARRAY['prepared'::text, 'requires_payment_method'::text, 'requires_action'::text, 'authorized'::text, 'processing'::text, 'succeeded'::text, 'failed'::text, 'cancelled'::text, 'refunded'::text, 'disputed'::text, 'unknown'::text])))
);


--
-- Name: TABLE stripe_payment_intents; Type: COMMENT; Schema: private; Owner: -
--

COMMENT ON TABLE private.stripe_payment_intents IS 'Private provider reference and amount ledger. It is not an escrow or a promise of payout.';


--
-- Name: stripe_runtime_controls; Type: TABLE; Schema: private; Owner: -
--

CREATE TABLE private.stripe_runtime_controls (
    singleton boolean DEFAULT true NOT NULL,
    mode text DEFAULT 'disabled'::text NOT NULL,
    currency_code text DEFAULT 'USD'::text NOT NULL,
    service_fee_cents integer DEFAULT 297 NOT NULL,
    payments_enabled boolean DEFAULT false NOT NULL,
    connected_onboarding_enabled boolean DEFAULT false NOT NULL,
    job_funding_enabled boolean DEFAULT false NOT NULL,
    transfers_enabled boolean DEFAULT false NOT NULL,
    refunds_enabled boolean DEFAULT false NOT NULL,
    live_mode_enabled boolean DEFAULT false NOT NULL,
    live_owner_approved boolean DEFAULT false NOT NULL,
    connected_accounts_approved boolean DEFAULT false NOT NULL,
    payouts_approved boolean DEFAULT false NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT stripe_live_mode_requires_approval CHECK (((mode <> 'live'::text) OR (live_mode_enabled AND live_owner_approved))),
    CONSTRAINT stripe_runtime_controls_currency_code_check CHECK ((currency_code ~ '^[A-Z]{3}$'::text)),
    CONSTRAINT stripe_runtime_controls_mode_check CHECK ((mode = ANY (ARRAY['disabled'::text, 'sandbox'::text, 'live'::text]))),
    CONSTRAINT stripe_runtime_controls_service_fee_cents_check CHECK (((service_fee_cents >= 0) AND (service_fee_cents <= 100000))),
    CONSTRAINT stripe_runtime_controls_singleton_check CHECK (singleton)
);


--
-- Name: TABLE stripe_runtime_controls; Type: COMMENT; Schema: private; Owner: -
--

COMMENT ON TABLE private.stripe_runtime_controls IS 'Server-only Stripe gates. Starts disabled; live mode requires separately reviewed owner approval.';


--
-- Name: stripe_webhook_events; Type: TABLE; Schema: private; Owner: -
--

CREATE TABLE private.stripe_webhook_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    environment text NOT NULL,
    provider_event_id text NOT NULL,
    event_type text NOT NULL,
    provider_created_at timestamp with time zone,
    payload_sha256 text NOT NULL,
    signature_verified boolean DEFAULT true NOT NULL,
    processing_status text DEFAULT 'received'::text NOT NULL,
    safe_failure_code text,
    lease_epoch bigint DEFAULT 0 NOT NULL,
    lease_token uuid,
    lease_expires_at timestamp with time zone,
    attempt_count integer DEFAULT 0 NOT NULL,
    received_at timestamp with time zone DEFAULT now() NOT NULL,
    processed_at timestamp with time zone,
    CONSTRAINT stripe_webhook_events_attempt_count_check CHECK ((attempt_count >= 0)),
    CONSTRAINT stripe_webhook_events_environment_check CHECK ((environment = ANY (ARRAY['test'::text, 'live'::text]))),
    CONSTRAINT stripe_webhook_events_event_type_check CHECK (((char_length(event_type) >= 3) AND (char_length(event_type) <= 120))),
    CONSTRAINT stripe_webhook_events_lease_epoch_check CHECK ((lease_epoch >= 0)),
    CONSTRAINT stripe_webhook_events_payload_sha256_check CHECK ((payload_sha256 ~ '^[a-f0-9]{64}$'::text)),
    CONSTRAINT stripe_webhook_events_processing_status_check CHECK ((processing_status = ANY (ARRAY['received'::text, 'processing'::text, 'processed'::text, 'ignored'::text, 'failed'::text]))),
    CONSTRAINT stripe_webhook_events_provider_event_id_check CHECK ((provider_event_id ~ '^evt_[A-Za-z0-9]+$'::text)),
    CONSTRAINT stripe_webhook_events_safe_failure_code_check CHECK (((safe_failure_code IS NULL) OR (safe_failure_code ~ '^[a-z0-9_]{1,100}$'::text))),
    CONSTRAINT stripe_webhook_events_signature_verified_check CHECK (signature_verified)
);


--
-- Name: TABLE stripe_webhook_events; Type: COMMENT; Schema: private; Owner: -
--

COMMENT ON TABLE private.stripe_webhook_events IS 'Signature-verified Stripe event deduplication and fenced retry ledger; raw request bodies are never stored.';


--
-- Name: user_roles; Type: TABLE; Schema: private; Owner: -
--

CREATE TABLE private.user_roles (
    user_id uuid NOT NULL,
    role public.mort_role NOT NULL,
    granted_by uuid,
    granted_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT user_roles_role_check CHECK ((role = ANY (ARRAY['admin'::public.mort_role, 'moderator'::public.mort_role])))
);


--
-- Name: verification_provider_allowlist; Type: TABLE; Schema: private; Owner: -
--

CREATE TABLE private.verification_provider_allowlist (
    provider_key text NOT NULL,
    verification_type text NOT NULL,
    is_enabled boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    CONSTRAINT verification_provider_allowlist_provider_key_check CHECK (((provider_key = btrim(provider_key)) AND ((char_length(provider_key) >= 1) AND (char_length(provider_key) <= 100)))),
    CONSTRAINT verification_provider_allowlist_verification_type_check CHECK ((verification_type = ANY (ARRAY['age'::text, 'identity'::text, 'guardian_consent'::text, 'school_email'::text, 'school_id'::text, 'business'::text])))
);


--
-- Name: TABLE verification_provider_allowlist; Type: COMMENT; Schema: private; Owner: -
--

COMMENT ON TABLE private.verification_provider_allowlist IS 'Issue #50: explicitly approved verification providers by case type; intentionally empty until provider/legal/security approval is documented. Empty means no positive verification can succeed (fail closed).';


--
-- Name: verification_provider_ingestion_keys; Type: TABLE; Schema: private; Owner: -
--

CREATE TABLE private.verification_provider_ingestion_keys (
    provider_key text NOT NULL,
    project_ref text NOT NULL,
    hmac_key text NOT NULL,
    is_enabled boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    rotated_at timestamp with time zone,
    CONSTRAINT verification_provider_ingestion_keys_hmac_key_check CHECK (((char_length(hmac_key) >= 32) AND (char_length(hmac_key) <= 512))),
    CONSTRAINT verification_provider_ingestion_keys_project_ref_check CHECK ((project_ref ~ '^[a-z]{20}$'::text))
);


--
-- Name: TABLE verification_provider_ingestion_keys; Type: COMMENT; Schema: private; Owner: -
--

COMMENT ON TABLE private.verification_provider_ingestion_keys IS 'Issue #50: per-provider, per-project HMAC signing keys for the provider event ingestion boundary. A key is only valid for the project it was issued for (tenant binding). Not seeded by migrations; an operator inserts keys only after documented provider approval.';


--
-- Name: verification_provider_results; Type: TABLE; Schema: private; Owner: -
--

CREATE TABLE private.verification_provider_results (
    id uuid DEFAULT extensions.gen_random_uuid() NOT NULL,
    verification_case_id uuid NOT NULL,
    user_id uuid NOT NULL,
    verification_type text NOT NULL,
    provider_key text NOT NULL,
    provider_reference text,
    provider_event_id text NOT NULL,
    result text NOT NULL,
    evidence_sha256 text NOT NULL,
    verified_at timestamp with time zone,
    expires_at timestamp with time zone,
    received_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    CONSTRAINT verification_provider_results_check CHECK ((((result = 'verified'::text) AND (verified_at IS NOT NULL)) OR (result <> 'verified'::text))),
    CONSTRAINT verification_provider_results_check1 CHECK (((expires_at IS NULL) OR (verified_at IS NULL) OR (expires_at > verified_at))),
    CONSTRAINT verification_provider_results_evidence_sha256_check CHECK ((evidence_sha256 ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT verification_provider_results_provider_event_id_check CHECK (((provider_event_id = btrim(provider_event_id)) AND ((char_length(provider_event_id) >= 1) AND (char_length(provider_event_id) <= 200)))),
    CONSTRAINT verification_provider_results_provider_key_check CHECK (((provider_key = btrim(provider_key)) AND ((char_length(provider_key) >= 1) AND (char_length(provider_key) <= 100)))),
    CONSTRAINT verification_provider_results_provider_reference_check CHECK (((provider_reference IS NULL) OR ((provider_reference = btrim(provider_reference)) AND ((char_length(provider_reference) >= 1) AND (char_length(provider_reference) <= 200))))),
    CONSTRAINT verification_provider_results_result_check CHECK ((result = ANY (ARRAY['verified'::text, 'rejected'::text, 'needs_review'::text]))),
    CONSTRAINT verification_provider_results_verification_type_check CHECK ((verification_type = ANY (ARRAY['age'::text, 'identity'::text, 'guardian_consent'::text, 'school_email'::text, 'school_id'::text, 'business'::text])))
);


--
-- Name: TABLE verification_provider_results; Type: COMMENT; Schema: private; Owner: -
--

COMMENT ON TABLE private.verification_provider_results IS 'Issue #50: immutable provider result metadata; insert only via the signed ingestion boundary after HMAC signature, tenant, case-binding, freshness, and replay verification. evidence_sha256 is the SHA-256 of the exact raw request body (UTF-8) — a provenance fingerprint, not a proof of authenticity (authenticity is the verified HMAC signature).';


--
-- Name: admin_audit_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admin_audit_log (
    id bigint NOT NULL,
    actor_id uuid,
    action text NOT NULL,
    target_type text NOT NULL,
    target_id text,
    reason text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.admin_audit_log FORCE ROW LEVEL SECURITY;


--
-- Name: admin_audit_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.admin_audit_log ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.admin_audit_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: application_status_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.application_status_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    application_id uuid NOT NULL,
    actor_id uuid,
    from_status public.mort_application_status,
    to_status public.mort_application_status NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: consents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.consents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    consent_type text NOT NULL,
    document_version text NOT NULL,
    granted boolean NOT NULL,
    recorded_at timestamp with time zone DEFAULT now() NOT NULL,
    revoked_at timestamp with time zone,
    source text DEFAULT 'app'::text NOT NULL,
    CONSTRAINT consents_consent_type_check CHECK ((consent_type = ANY (ARRAY['terms'::text, 'privacy'::text, 'community_guidelines'::text, 'guardian_consent'::text, 'data_processing'::text])))
);

ALTER TABLE ONLY public.consents FORCE ROW LEVEL SECURITY;


--
-- Name: conversation_members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.conversation_members (
    conversation_id uuid NOT NULL,
    user_id uuid NOT NULL,
    joined_at timestamp with time zone DEFAULT now() NOT NULL,
    last_read_at timestamp with time zone,
    muted_at timestamp with time zone
);

ALTER TABLE ONLY public.conversation_members FORCE ROW LEVEL SECURITY;


--
-- Name: conversations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.conversations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    job_id uuid,
    assignment_id uuid,
    conversation_type text DEFAULT 'job'::text NOT NULL,
    status text DEFAULT 'active'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT conversations_conversation_type_check CHECK ((conversation_type = ANY (ARRAY['job'::text, 'support'::text, 'dispute'::text]))),
    CONSTRAINT conversations_status_check CHECK ((status = ANY (ARRAY['active'::text, 'closed'::text, 'under_review'::text])))
);

ALTER TABLE ONLY public.conversations FORCE ROW LEVEL SECURITY;


--
-- Name: disputes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.disputes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    assignment_id uuid NOT NULL,
    opened_by uuid NOT NULL,
    category text NOT NULL,
    description text NOT NULL,
    status text DEFAULT 'open'::text NOT NULL,
    resolution text,
    assigned_to uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    resolved_at timestamp with time zone,
    CONSTRAINT disputes_category_check CHECK ((category = ANY (ARRAY['work_quality'::text, 'nonpayment'::text, 'no_show'::text, 'safety'::text, 'scope_change'::text, 'other'::text]))),
    CONSTRAINT disputes_description_check CHECK (((char_length(description) >= 10) AND (char_length(description) <= 4000))),
    CONSTRAINT disputes_status_check CHECK ((status = ANY (ARRAY['open'::text, 'investigating'::text, 'awaiting_evidence'::text, 'resolved'::text, 'dismissed'::text])))
);

ALTER TABLE ONLY public.disputes FORCE ROW LEVEL SECURITY;


--
-- Name: evidence_files; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.evidence_files (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    uploaded_by uuid NOT NULL,
    assignment_id uuid,
    dispute_id uuid,
    report_id uuid,
    storage_path text NOT NULL,
    content_type text NOT NULL,
    file_size_bytes bigint NOT NULL,
    sha256 text,
    visibility text DEFAULT 'participants'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT evidence_files_check CHECK ((num_nonnulls(assignment_id, dispute_id, report_id) = 1)),
    CONSTRAINT evidence_files_file_size_bytes_check CHECK (((file_size_bytes >= 1) AND (file_size_bytes <= 26214400))),
    CONSTRAINT evidence_files_visibility_check CHECK ((visibility = ANY (ARRAY['uploader'::text, 'participants'::text, 'staff_only'::text])))
);

ALTER TABLE ONLY public.evidence_files FORCE ROW LEVEL SECURITY;


--
-- Name: guardian_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.guardian_links (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    teen_user_id uuid NOT NULL,
    guardian_user_id uuid,
    status text DEFAULT 'pending'::text NOT NULL,
    initiated_by uuid NOT NULL,
    teen_consent_at timestamp with time zone,
    guardian_consent_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    revoked_by uuid,
    revoked_at timestamp with time zone,
    CONSTRAINT guardian_links_check CHECK ((teen_user_id <> guardian_user_id)),
    CONSTRAINT guardian_links_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'active'::text, 'revoked'::text, 'rejected'::text])))
);

ALTER TABLE ONLY public.guardian_links FORCE ROW LEVEL SECURITY;


--
-- Name: COLUMN guardian_links.revoked_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.guardian_links.revoked_by IS 'Authenticated account that initiated revocation; populated by a guarded transition trigger.';


--
-- Name: COLUMN guardian_links.revoked_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.guardian_links.revoked_at IS 'Timestamp of the first transition to revoked.';


--
-- Name: guardian_preferences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.guardian_preferences (
    link_id uuid NOT NULL,
    safety_ping_alerts boolean DEFAULT true NOT NULL,
    job_checkin_alerts boolean DEFAULT true NOT NULL,
    accepted_job_summary boolean DEFAULT true NOT NULL,
    safety_warning_alerts boolean DEFAULT true NOT NULL,
    weekly_digest boolean DEFAULT false NOT NULL,
    optional_job_approval_enabled boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: job_applications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.job_applications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    job_id uuid NOT NULL,
    applicant_id uuid NOT NULL,
    status public.mort_application_status DEFAULT 'submitted'::public.mort_application_status NOT NULL,
    cover_note text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    availability_confirmed boolean DEFAULT false NOT NULL,
    guardian_id uuid,
    viewed_at timestamp with time zone,
    withdrawn_at timestamp with time zone,
    CONSTRAINT job_applications_cover_note_check CHECK (((cover_note IS NULL) OR (char_length(cover_note) <= 1000)))
);

ALTER TABLE ONLY public.job_applications FORCE ROW LEVEL SECURITY;


--
-- Name: job_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.job_assignments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    job_id uuid NOT NULL,
    application_id uuid NOT NULL,
    teen_user_id uuid NOT NULL,
    adult_user_id uuid NOT NULL,
    status text DEFAULT 'accepted'::text NOT NULL,
    agreed_amount numeric(10,2) NOT NULL,
    accepted_at timestamp with time zone DEFAULT now() NOT NULL,
    started_at timestamp with time zone,
    completed_by_teen_at timestamp with time zone,
    completed_by_adult_at timestamp with time zone,
    closed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT job_assignments_agreed_amount_check CHECK ((agreed_amount > (0)::numeric)),
    CONSTRAINT job_assignments_status_check CHECK ((status = ANY (ARRAY['accepted'::text, 'in_progress'::text, 'awaiting_confirmation'::text, 'completed'::text, 'cancelled'::text, 'disputed'::text])))
);

ALTER TABLE ONLY public.job_assignments FORCE ROW LEVEL SECURITY;


--
-- Name: job_contract_acceptances; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.job_contract_acceptances (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    contract_id uuid NOT NULL,
    contract_version_id uuid NOT NULL,
    user_id uuid NOT NULL,
    party_role text NOT NULL,
    content_hash text NOT NULL,
    affirmative_checkbox boolean NOT NULL,
    confirmation_text text NOT NULL,
    platform text NOT NULL,
    app_version text NOT NULL,
    accepted_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT job_contract_acceptances_checkbox_check CHECK (affirmative_checkbox),
    CONSTRAINT job_contract_acceptances_hash_check CHECK ((content_hash ~ '^[a-f0-9]{64}$'::text)),
    CONSTRAINT job_contract_acceptances_role_check CHECK ((party_role = ANY (ARRAY['teen'::text, 'adult'::text])))
);


--
-- Name: job_contract_change_acceptances; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.job_contract_change_acceptances (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    change_request_id uuid NOT NULL,
    user_id uuid NOT NULL,
    party_role text NOT NULL,
    accepted boolean NOT NULL,
    proposed_content_hash text NOT NULL,
    affirmative_checkbox boolean NOT NULL,
    responded_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT job_contract_change_acceptances_checkbox_check CHECK (((accepted AND affirmative_checkbox) OR ((NOT accepted) AND (NOT affirmative_checkbox)))),
    CONSTRAINT job_contract_change_acceptances_hash_check CHECK ((proposed_content_hash ~ '^[a-f0-9]{64}$'::text)),
    CONSTRAINT job_contract_change_acceptances_role_check CHECK ((party_role = ANY (ARRAY['teen'::text, 'adult'::text])))
);


--
-- Name: job_contract_change_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.job_contract_change_requests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    contract_id uuid NOT NULL,
    base_version_id uuid NOT NULL,
    requested_by uuid NOT NULL,
    change_categories text[] NOT NULL,
    proposed_terms jsonb NOT NULL,
    proposed_content_hash text NOT NULL,
    reason text NOT NULL,
    status text DEFAULT 'pending_both_parties'::text NOT NULL,
    requested_at timestamp with time zone DEFAULT now() NOT NULL,
    resolved_at timestamp with time zone,
    created_version_id uuid,
    CONSTRAINT job_contract_change_requests_categories_check CHECK ((cardinality(change_categories) > 0)),
    CONSTRAINT job_contract_change_requests_hash_check CHECK ((proposed_content_hash ~ '^[a-f0-9]{64}$'::text)),
    CONSTRAINT job_contract_change_requests_status_check CHECK ((status = ANY (ARRAY['pending_both_parties'::text, 'accepted'::text, 'declined'::text, 'cancelled'::text])))
);


--
-- Name: job_contract_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.job_contract_versions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    contract_id uuid NOT NULL,
    version_number integer NOT NULL,
    source text NOT NULL,
    source_change_request_id uuid,
    status text DEFAULT 'pending_confirmation'::text NOT NULL,
    teen_public_identifier text NOT NULL,
    adult_public_identifier text NOT NULL,
    agreed_scope text NOT NULL,
    excluded_work text[] DEFAULT '{}'::text[] NOT NULL,
    location_type text NOT NULL,
    exact_location_release_state text NOT NULL,
    service_date date,
    start_window timestamp with time zone,
    expected_end_window timestamp with time zone,
    amount_type text NOT NULL,
    hourly_rate_cents integer,
    maximum_approved_hours numeric(6,2),
    fixed_total_cents integer,
    currency_code text DEFAULT 'USD'::text NOT NULL,
    payment_preference text NOT NULL,
    payment_due_rule text NOT NULL,
    authorized_expenses text[] DEFAULT '{}'::text[] NOT NULL,
    equipment text,
    hazards text,
    expected_people_present text,
    supervision text,
    proof_requirements text,
    completion_requirements text,
    cancellation_terms text NOT NULL,
    material_change_process text NOT NULL,
    dispute_process text NOT NULL,
    safety_agreement_version text NOT NULL,
    terms_snapshot jsonb NOT NULL,
    content_hash text NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    activated_at timestamp with time zone,
    superseded_at timestamp with time zone,
    CONSTRAINT job_contract_versions_amount_check CHECK ((((amount_type = 'hourly'::text) AND (hourly_rate_cents IS NOT NULL) AND (hourly_rate_cents >= 0) AND (maximum_approved_hours IS NOT NULL) AND (maximum_approved_hours > (0)::numeric) AND (fixed_total_cents IS NULL)) OR ((amount_type = 'fixed'::text) AND (fixed_total_cents IS NOT NULL) AND (fixed_total_cents >= 0) AND (hourly_rate_cents IS NULL) AND (maximum_approved_hours IS NULL)))),
    CONSTRAINT job_contract_versions_amount_type_check CHECK ((amount_type = ANY (ARRAY['hourly'::text, 'fixed'::text]))),
    CONSTRAINT job_contract_versions_hash_check CHECK ((content_hash ~ '^[a-f0-9]{64}$'::text)),
    CONSTRAINT job_contract_versions_number_check CHECK ((version_number > 0)),
    CONSTRAINT job_contract_versions_source_check CHECK ((source = ANY (ARRAY['application_acceptance'::text, 'mutual_change_request'::text]))),
    CONSTRAINT job_contract_versions_status_check CHECK ((status = ANY (ARRAY['pending_confirmation'::text, 'active'::text, 'superseded'::text, 'cancelled'::text])))
);


--
-- Name: TABLE job_contract_versions; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.job_contract_versions IS 'Immutable agreement terms snapshots. Authenticated clients are read-only; writes go through guarded RPCs.';


--
-- Name: job_contracts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.job_contracts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    job_id uuid NOT NULL,
    application_id uuid NOT NULL,
    teen_id uuid NOT NULL,
    adult_id uuid NOT NULL,
    status text DEFAULT 'pending_confirmation'::text NOT NULL,
    active_version_id uuid,
    classification_status text DEFAULT 'classification_unknown'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    activated_at timestamp with time zone,
    closed_at timestamp with time zone,
    CONSTRAINT job_contracts_classification_check CHECK ((classification_status = ANY (ARRAY['classification_unknown'::text, 'possible_employee_relationship'::text, 'possible_independent_service_relationship'::text, 'organization_program_role'::text, 'requires_review'::text]))),
    CONSTRAINT job_contracts_party_check CHECK ((teen_id <> adult_id)),
    CONSTRAINT job_contracts_status_check CHECK ((status = ANY (ARRAY['pending_confirmation'::text, 'active'::text, 'change_pending'::text, 'completed'::text, 'disputed'::text, 'cancelled'::text])))
);


--
-- Name: TABLE job_contracts; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.job_contracts IS 'Private-to-participants agreement envelope for a MORT job application. Authenticated clients are read-only; writes go through guarded RPCs.';


--
-- Name: job_execution_review_responses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.job_execution_review_responses (
    id uuid DEFAULT extensions.gen_random_uuid() NOT NULL,
    dispute_id uuid NOT NULL,
    assignment_id uuid NOT NULL,
    responded_by uuid NOT NULL,
    client_request_id uuid NOT NULL,
    statement text NOT NULL,
    safety_related boolean NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT job_execution_review_responses_statement_check CHECK (((char_length(btrim(statement)) >= 10) AND (char_length(btrim(statement)) <= 2000)))
);


--
-- Name: job_interests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.job_interests (
    user_id uuid NOT NULL,
    job_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: job_safety_agreements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.job_safety_agreements (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    application_id uuid NOT NULL,
    job_id uuid NOT NULL,
    teen_id uuid NOT NULL,
    adult_id uuid NOT NULL,
    agreement_version integer DEFAULT 1 NOT NULL,
    terms_snapshot jsonb NOT NULL,
    material_terms_hash text NOT NULL,
    status text DEFAULT 'awaiting_both'::text NOT NULL,
    teen_confirmed_at timestamp with time zone,
    adult_confirmed_at timestamp with time zone,
    teen_confirmed_version integer,
    adult_confirmed_version integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    location_version integer DEFAULT 0 NOT NULL,
    CONSTRAINT job_safety_agreements_hash_check CHECK ((material_terms_hash ~ '^[a-f0-9]{64}$'::text)),
    CONSTRAINT job_safety_agreements_party_check CHECK ((teen_id <> adult_id)),
    CONSTRAINT job_safety_agreements_status_check CHECK ((status = ANY (ARRAY['awaiting_both'::text, 'awaiting_teen'::text, 'awaiting_adult'::text, 'confirmed'::text, 'reconfirmation_required'::text]))),
    CONSTRAINT job_safety_agreements_version_check CHECK ((agreement_version > 0))
);


--
-- Name: TABLE job_safety_agreements; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.job_safety_agreements IS 'Immutable, participant-scoped safety snapshots for accepted MORT jobs; material changes invalidate both confirmations.';


--
-- Name: job_safety_cancellations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.job_safety_cancellations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    application_id uuid NOT NULL,
    assignment_id uuid NOT NULL,
    job_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    reported_user_id uuid NOT NULL,
    reason text NOT NULL,
    details text NOT NULL,
    is_safety_related boolean DEFAULT true NOT NULL,
    reputation_penalty_applied boolean DEFAULT false NOT NULL,
    safety_report_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT job_safety_cancellations_details_length CHECK (((char_length(btrim(details)) >= 10) AND (char_length(btrim(details)) <= 3000))),
    CONSTRAINT job_safety_cancellations_no_automatic_penalty CHECK ((is_safety_related AND (NOT reputation_penalty_applied))),
    CONSTRAINT job_safety_cancellations_participant_pair CHECK ((actor_id <> reported_user_id)),
    CONSTRAINT job_safety_cancellations_reason_check CHECK ((reason = ANY (ARRAY['unsafe_condition'::text, 'person_mismatch'::text, 'harassment'::text, 'location_changed'::text, 'scope_changed'::text, 'emergency'::text])))
);


--
-- Name: TABLE job_safety_cancellations; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.job_safety_cancellations IS 'Private audit of a participant safety cancellation; no automatic reputation penalty is applied.';


--
-- Name: job_safety_checkins; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.job_safety_checkins (
    id uuid DEFAULT extensions.gen_random_uuid() NOT NULL,
    application_id uuid NOT NULL,
    job_id uuid NOT NULL,
    teen_user_id uuid NOT NULL,
    adult_user_id uuid NOT NULL,
    status text DEFAULT 'scheduled'::text NOT NULL,
    expected_at timestamp with time zone NOT NULL,
    completed_at timestamp with time zone,
    client_request_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT job_safety_checkins_status_check CHECK ((status = ANY (ARRAY['scheduled'::text, 'completed'::text, 'cancelled'::text])))
);


--
-- Name: job_safety_plans; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.job_safety_plans (
    application_id uuid NOT NULL,
    job_id uuid NOT NULL,
    teen_id uuid NOT NULL,
    adult_id uuid NOT NULL,
    expected_people text,
    public_or_visible_meeting boolean DEFAULT true NOT NULL,
    daylight_preferred boolean DEFAULT true NOT NULL,
    transportation_plan text,
    checkin_cadence_minutes integer,
    teen_updated_at timestamp with time zone,
    adult_updated_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT job_safety_plans_cadence_check CHECK (((checkin_cadence_minutes IS NULL) OR ((checkin_cadence_minutes >= 15) AND (checkin_cadence_minutes <= 240)))),
    CONSTRAINT job_safety_plans_party_check CHECK ((teen_id <> adult_id)),
    CONSTRAINT job_safety_plans_people_length CHECK (((expected_people IS NULL) OR (char_length(expected_people) <= 500))),
    CONSTRAINT job_safety_plans_transport_length CHECK (((transportation_plan IS NULL) OR (char_length(transportation_plan) <= 1000)))
);


--
-- Name: job_status_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.job_status_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    job_id uuid NOT NULL,
    actor_id uuid,
    from_status public.mort_job_status,
    to_status public.mort_job_status NOT NULL,
    action text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.jobs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    poster_id uuid NOT NULL,
    title text NOT NULL,
    description text NOT NULL,
    category text NOT NULL,
    status public.mort_job_status DEFAULT 'draft'::public.mort_job_status NOT NULL,
    pay_type text DEFAULT 'fixed'::text NOT NULL,
    pay_amount numeric(10,2) NOT NULL,
    estimated_minutes integer,
    city text,
    region text,
    location_notes text,
    exact_address text,
    age_min integer DEFAULT 13 NOT NULL,
    age_max integer DEFAULT 17 NOT NULL,
    remote_allowed boolean DEFAULT false NOT NULL,
    starts_at timestamp with time zone,
    ends_at timestamp with time zone,
    safety_review_status text DEFAULT 'pending'::text NOT NULL,
    published_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    completed_at timestamp with time zone,
    summary text,
    location_text text,
    adult_job_amount_cents integer,
    mort_service_fee_cents integer,
    pay_amount_cents integer,
    pay_label text,
    schedule_type text DEFAULT 'flexible'::text NOT NULL,
    payment_type text DEFAULT 'fixed'::text NOT NULL,
    payment_method text DEFAULT 'flexible'::text NOT NULL,
    payment_timing text DEFAULT 'after_completion'::text NOT NULL,
    verification_requirement text DEFAULT 'none'::text NOT NULL,
    work_environment text DEFAULT 'unspecified'::text NOT NULL,
    location_type text DEFAULT 'unspecified'::text NOT NULL,
    experience_level text DEFAULT 'any'::text NOT NULL,
    estimated_duration_minutes integer,
    workers_needed integer DEFAULT 1 NOT NULL,
    skills_needed text[] DEFAULT '{}'::text[] NOT NULL,
    physical_requirements text[] DEFAULT '{}'::text[] NOT NULL,
    equipment_provided text,
    equipment_worker_brings text,
    special_instructions text,
    safety_notes text,
    proof_expected boolean DEFAULT false NOT NULL,
    adult_supervision_present boolean DEFAULT false NOT NULL,
    tip_allowed boolean DEFAULT false NOT NULL,
    applications_open boolean DEFAULT true NOT NULL,
    deadline_at timestamp with time zone,
    expires_at timestamp with time zone,
    recurring boolean DEFAULT false NOT NULL,
    recurrence_rule text,
    timezone text DEFAULT 'America/Indiana/Indianapolis'::text NOT NULL,
    urgency text DEFAULT 'normal'::text NOT NULL,
    neighborhood text,
    zip_code text,
    travel_radius_miles integer,
    acceptable_transportation_methods text[] DEFAULT ARRAY['walking'::text, 'bicycle'::text, 'car'::text, 'public_transit'::text, 'rideshare'::text, 'other'::text] NOT NULL,
    transportation_considerations text,
    teen_min_age integer DEFAULT 13 NOT NULL,
    teen_max_age integer DEFAULT 17 NOT NULL,
    requires_guardian_approval boolean DEFAULT false NOT NULL,
    quick_accept_eligible boolean DEFAULT false NOT NULL,
    CONSTRAINT jobs_age_min_check CHECK (((age_min >= 13) AND (age_min <= 17))),
    CONSTRAINT jobs_category_check CHECK ((category = ANY (ARRAY['yard_work'::text, 'pet_care'::text, 'tutoring'::text, 'household_help'::text, 'moving_help'::text, 'tech_help'::text, 'other'::text]))),
    CONSTRAINT jobs_check CHECK (((age_max >= age_min) AND (age_max <= 17))),
    CONSTRAINT jobs_check1 CHECK (((ends_at IS NULL) OR (starts_at IS NULL) OR (ends_at > starts_at))),
    CONSTRAINT jobs_check2 CHECK (((status <> 'open'::public.mort_job_status) OR (safety_review_status = 'approved'::text))),
    CONSTRAINT jobs_description_check CHECK (((char_length(description) <= 5000) AND ((status = 'draft'::public.mort_job_status) OR (char_length(description) >= 20)))),
    CONSTRAINT jobs_estimated_minutes_check CHECK (((estimated_minutes IS NULL) OR ((estimated_minutes >= 5) AND (estimated_minutes <= 1440)))),
    CONSTRAINT jobs_pay_amount_check CHECK (((pay_amount >= (0)::numeric) AND (pay_amount <= (10000)::numeric) AND ((status = 'draft'::public.mort_job_status) OR (pay_amount > (0)::numeric)))),
    CONSTRAINT jobs_pay_type_check CHECK ((pay_type = ANY (ARRAY['fixed'::text, 'hourly'::text]))),
    CONSTRAINT jobs_publication_requirements_check CHECK (((status = 'draft'::public.mort_job_status) OR (((char_length(title) >= 5) AND (char_length(title) <= 120)) AND ((char_length(description) >= 20) AND (char_length(description) <= 5000)) AND (pay_amount > (0)::numeric) AND (city IS NOT NULL) AND (btrim(city) <> ''::text) AND (region IS NOT NULL) AND (btrim(region) <> ''::text)))),
    CONSTRAINT jobs_safety_review_status_check CHECK ((safety_review_status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text, 'flagged'::text]))),
    CONSTRAINT jobs_title_check CHECK (((char_length(title) <= 120) AND ((status = 'draft'::public.mort_job_status) OR (char_length(title) >= 5))))
);

ALTER TABLE ONLY public.jobs FORCE ROW LEVEL SECURITY;


--
-- Name: legal_acceptance_audit_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.legal_acceptance_audit_events (
    id bigint NOT NULL,
    user_id uuid NOT NULL,
    document_id uuid NOT NULL,
    document_version_id uuid NOT NULL,
    acceptance_id uuid,
    event_type text NOT NULL,
    event_metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    occurred_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT legal_acceptance_audit_reference_check CHECK ((acceptance_id IS NOT NULL)),
    CONSTRAINT legal_acceptance_audit_type_check CHECK ((event_type = 'accepted'::text))
);


--
-- Name: legal_acceptance_audit_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.legal_acceptance_audit_events ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.legal_acceptance_audit_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: legal_acceptances; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.legal_acceptances (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    role public.mort_role NOT NULL,
    age_band text NOT NULL,
    document_id uuid NOT NULL,
    document_version_id uuid NOT NULL,
    content_hash text NOT NULL,
    effective_date timestamp with time zone NOT NULL,
    accepted_at timestamp with time zone DEFAULT now() NOT NULL,
    platform text NOT NULL,
    app_version text NOT NULL,
    language_code text NOT NULL,
    jurisdiction_policy text NOT NULL,
    acceptance_ui_version text NOT NULL,
    affirmative_checkbox boolean NOT NULL,
    electronic_signature_text text,
    active boolean DEFAULT true NOT NULL,
    withdrawn_at timestamp with time zone,
    server_request_id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT legal_acceptances_affirmative_check CHECK (affirmative_checkbox),
    CONSTRAINT legal_acceptances_age_band_check CHECK ((age_band = ANY (ARRAY['teen_13_15'::text, 'teen_16_17'::text, 'adult_18_plus'::text]))),
    CONSTRAINT legal_acceptances_app_version_check CHECK (((char_length(btrim(app_version)) >= 1) AND (char_length(btrim(app_version)) <= 40))),
    CONSTRAINT legal_acceptances_platform_check CHECK (((char_length(btrim(platform)) >= 2) AND (char_length(btrim(platform)) <= 40))),
    CONSTRAINT legal_acceptances_role_check CHECK ((role = ANY (ARRAY['teen'::public.mort_role, 'adult'::public.mort_role, 'guardian'::public.mort_role, 'admin'::public.mort_role, 'moderator'::public.mort_role]))),
    CONSTRAINT legal_acceptances_withdrawal_check CHECK (((active AND (withdrawn_at IS NULL)) OR ((NOT active) AND (withdrawn_at IS NOT NULL))))
);


--
-- Name: legal_document_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.legal_document_versions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    document_id uuid NOT NULL,
    version_label text NOT NULL,
    content_hash text NOT NULL,
    content_path text,
    content_markdown text,
    effective_at timestamp with time zone,
    published_at timestamp with time zone,
    retired_at timestamp with time zone,
    material_revision boolean DEFAULT true NOT NULL,
    requires_electronic_signature boolean DEFAULT false NOT NULL,
    publication_status text DEFAULT 'draft_attorney_review'::text NOT NULL,
    language_code text DEFAULT 'en-US'::text NOT NULL,
    jurisdiction_policy text DEFAULT 'requires_jurisdiction_specific_attorney_review'::text NOT NULL,
    acceptance_ui_version text DEFAULT 'legal-clickwrap-v1'::text NOT NULL,
    attorney_reviewed_at timestamp with time zone,
    approved_by_counsel_reference text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT legal_document_versions_hash_check CHECK ((content_hash ~ '^[a-f0-9]{64}$'::text)),
    CONSTRAINT legal_document_versions_label_check CHECK (((char_length(btrim(version_label)) >= 1) AND (char_length(btrim(version_label)) <= 100))),
    CONSTRAINT legal_document_versions_published_check CHECK (((publication_status <> 'published'::text) OR ((effective_at IS NOT NULL) AND (published_at IS NOT NULL) AND (attorney_reviewed_at IS NOT NULL) AND (NULLIF(btrim(approved_by_counsel_reference), ''::text) IS NOT NULL) AND (char_length(COALESCE(content_markdown, ''::text)) >= 200)))),
    CONSTRAINT legal_document_versions_status_check CHECK ((publication_status = ANY (ARRAY['draft_attorney_review'::text, 'published'::text, 'retired'::text])))
);


--
-- Name: legal_documents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.legal_documents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    document_key text NOT NULL,
    title text NOT NULL,
    document_category text NOT NULL,
    guardian_mode_independent boolean DEFAULT true NOT NULL,
    publication_status text DEFAULT 'draft_attorney_review'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT legal_documents_guardian_independent_check CHECK (guardian_mode_independent),
    CONSTRAINT legal_documents_key_check CHECK ((document_key ~ '^[a-z0-9_]{3,100}$'::text)),
    CONSTRAINT legal_documents_status_check CHECK ((publication_status = ANY (ARRAY['draft_attorney_review'::text, 'published'::text, 'retired'::text]))),
    CONSTRAINT legal_documents_title_check CHECK (((char_length(btrim(title)) >= 3) AND (char_length(btrim(title)) <= 200)))
);


--
-- Name: legal_role_requirements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.legal_role_requirements (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    document_id uuid NOT NULL,
    role public.mort_role NOT NULL,
    age_band text DEFAULT 'all'::text NOT NULL,
    required boolean DEFAULT true NOT NULL,
    priority integer DEFAULT 100 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT legal_role_age_band_check CHECK ((age_band = ANY (ARRAY['teen_13_15'::text, 'teen_16_17'::text, 'adult_18_plus'::text, 'all'::text])))
);


--
-- Name: messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    conversation_id uuid NOT NULL,
    sender_id uuid NOT NULL,
    body text NOT NULL,
    attachment_path text,
    moderation_status text DEFAULT 'pending'::text NOT NULL,
    moderation_reason text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    edited_at timestamp with time zone,
    deleted_at timestamp with time zone,
    client_request_id uuid,
    CONSTRAINT messages_body_check CHECK (((char_length(body) >= 1) AND (char_length(body) <= 4000))),
    CONSTRAINT messages_moderation_status_check CHECK ((moderation_status = ANY (ARRAY['pending'::text, 'approved'::text, 'flagged'::text, 'blocked'::text, 'removed'::text])))
);

ALTER TABLE ONLY public.messages FORCE ROW LEVEL SECURITY;


--
-- Name: mort_release_control; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mort_release_control (
    is_primary boolean DEFAULT true NOT NULL,
    release_mode text NOT NULL,
    maintenance_mode boolean DEFAULT false NOT NULL,
    public_marketplace_enabled boolean DEFAULT false NOT NULL,
    real_document_collection boolean DEFAULT false NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT mort_release_control_is_primary_check CHECK (is_primary),
    CONSTRAINT mort_release_control_release_mode_check CHECK ((release_mode = ANY (ARRAY['production_public'::text, 'unconfigured'::text])))
);


--
-- Name: notification_preferences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notification_preferences (
    user_id uuid NOT NULL,
    email_enabled boolean DEFAULT true NOT NULL,
    push_enabled boolean DEFAULT true NOT NULL,
    job_updates boolean DEFAULT true NOT NULL,
    message_updates boolean DEFAULT true NOT NULL,
    safety_alerts boolean DEFAULT true NOT NULL,
    marketing_enabled boolean DEFAULT false NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.notification_preferences FORCE ROW LEVEL SECURITY;


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notifications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    notification_type text NOT NULL,
    title text NOT NULL,
    body text NOT NULL,
    data jsonb DEFAULT '{}'::jsonb NOT NULL,
    read_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT notifications_body_check CHECK ((char_length(body) <= 1000)),
    CONSTRAINT notifications_title_check CHECK (((char_length(title) >= 1) AND (char_length(title) <= 120)))
);

ALTER TABLE ONLY public.notifications FORCE ROW LEVEL SECURITY;


--
-- Name: payment_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment_records (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    assignment_id uuid NOT NULL,
    payer_id uuid NOT NULL,
    payee_id uuid NOT NULL,
    provider text DEFAULT 'stripe'::text NOT NULL,
    provider_payment_id text,
    amount numeric(10,2) NOT NULL,
    currency text DEFAULT 'usd'::text NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    idempotency_key text,
    failure_code text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT payment_records_amount_check CHECK ((amount > (0)::numeric)),
    CONSTRAINT payment_records_currency_check CHECK (((currency = lower(currency)) AND (char_length(currency) = 3))),
    CONSTRAINT payment_records_provider_check CHECK ((provider = ANY (ARRAY['stripe'::text, 'manual'::text, 'other'::text]))),
    CONSTRAINT payment_records_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'requires_action'::text, 'authorized'::text, 'processing'::text, 'succeeded'::text, 'failed'::text, 'refunded'::text, 'cancelled'::text])))
);

ALTER TABLE ONLY public.payment_records FORCE ROW LEVEL SECURITY;


--
-- Name: proof_uploads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.proof_uploads (
    id uuid NOT NULL,
    assignment_id uuid NOT NULL,
    application_id uuid NOT NULL,
    uploaded_by uuid NOT NULL,
    storage_path text NOT NULL,
    status text DEFAULT 'uploading'::text NOT NULL,
    note text,
    reviewed_by uuid,
    review_note text,
    reviewed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT proof_uploads_note_check CHECK (((note IS NULL) OR (char_length(note) <= 500))),
    CONSTRAINT proof_uploads_path_check CHECK ((storage_path ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.jpg$'::text)),
    CONSTRAINT proof_uploads_review_note_check CHECK (((review_note IS NULL) OR (char_length(review_note) <= 500))),
    CONSTRAINT proof_uploads_review_state_check CHECK ((((status = ANY (ARRAY['approved'::text, 'resubmission_requested'::text, 'rejected'::text])) AND (reviewed_by IS NOT NULL) AND (reviewed_at IS NOT NULL)) OR (status <> ALL (ARRAY['approved'::text, 'resubmission_requested'::text, 'rejected'::text])))),
    CONSTRAINT proof_uploads_status_check CHECK ((status = ANY (ARRAY['uploading'::text, 'submitted'::text, 'approved'::text, 'resubmission_requested'::text, 'rejected'::text, 'abandoned'::text])))
);


--
-- Name: reviews; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reviews (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    application_id uuid NOT NULL,
    job_id uuid NOT NULL,
    reviewer_id uuid NOT NULL,
    subject_id uuid NOT NULL,
    rating integer NOT NULL,
    body text,
    moderation_status text DEFAULT 'approved'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    revealed_at timestamp with time zone,
    CONSTRAINT review_body_not_enabled CHECK ((body IS NULL)),
    CONSTRAINT reviews_approved_rating_only CHECK ((moderation_status = 'approved'::text)),
    CONSTRAINT reviews_distinct_participants CHECK ((reviewer_id <> subject_id)),
    CONSTRAINT reviews_rating_check CHECK (((rating >= 1) AND (rating <= 5)))
);


--
-- Name: role_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.role_requests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    requested_role public.mort_role NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    submitted_at timestamp with time zone DEFAULT now() NOT NULL,
    reviewed_at timestamp with time zone,
    reviewed_by uuid,
    review_note text,
    CONSTRAINT role_requests_requested_role_check CHECK ((requested_role = ANY (ARRAY['teen'::public.mort_role, 'adult'::public.mort_role]))),
    CONSTRAINT role_requests_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text, 'withdrawn'::text])))
);

ALTER TABLE ONLY public.role_requests FORCE ROW LEVEL SECURITY;


--
-- Name: safety_pings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.safety_pings (
    id uuid DEFAULT extensions.gen_random_uuid() NOT NULL,
    teen_id uuid NOT NULL,
    status text DEFAULT 'needs_help'::text NOT NULL,
    note text,
    job_id uuid,
    immediate_danger boolean DEFAULT false NOT NULL,
    client_request_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT safety_pings_note_length CHECK (((note IS NULL) OR (char_length(note) <= 500))),
    CONSTRAINT safety_pings_status_check CHECK ((status = ANY (ARRAY['needs_help'::text, 'safe'::text])))
);


--
-- Name: safety_reports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.safety_reports (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    reporter_id uuid NOT NULL,
    reported_user_id uuid,
    job_id uuid,
    message_id uuid,
    category text NOT NULL,
    description text NOT NULL,
    status text DEFAULT 'open'::text NOT NULL,
    severity text DEFAULT 'normal'::text NOT NULL,
    assigned_to uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    resolved_at timestamp with time zone,
    application_id uuid,
    target_review_id uuid,
    immediate_danger boolean DEFAULT false NOT NULL,
    occurred_at timestamp with time zone,
    location_type text,
    desired_outcome text,
    confidential_safety_feedback boolean DEFAULT false NOT NULL,
    client_request_id uuid,
    CONSTRAINT safety_reports_category_check CHECK ((category = ANY (ARRAY['harassment'::text, 'unsafe_meeting'::text, 'scam'::text, 'inappropriate_content'::text, 'privacy'::text, 'underage_concern'::text, 'payment'::text, 'other'::text]))),
    CONSTRAINT safety_reports_description_check CHECK (((char_length(description) >= 10) AND (char_length(description) <= 4000))),
    CONSTRAINT safety_reports_severity_check CHECK ((severity = ANY (ARRAY['low'::text, 'normal'::text, 'high'::text, 'critical'::text]))),
    CONSTRAINT safety_reports_status_check CHECK ((status = ANY (ARRAY['open'::text, 'triaged'::text, 'investigating'::text, 'resolved'::text, 'dismissed'::text])))
);

ALTER TABLE ONLY public.safety_reports FORCE ROW LEVEL SECURITY;


--
-- Name: saved_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.saved_jobs (
    user_id uuid NOT NULL,
    job_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: team_hustle_members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.team_hustle_members (
    hustle_id uuid NOT NULL,
    user_id uuid NOT NULL,
    joined_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: team_hustles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.team_hustles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    poster_id uuid NOT NULL,
    title text NOT NULL,
    description text NOT NULL,
    category text,
    pay_type text DEFAULT 'per_person'::text NOT NULL,
    pay_amount numeric(10,2),
    workers_needed integer DEFAULT 3 NOT NULL,
    city text,
    region text,
    location_notes text,
    age_min integer DEFAULT 13 NOT NULL,
    age_max integer DEFAULT 17 NOT NULL,
    status text DEFAULT 'open'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT team_hustles_age_max_check CHECK (((age_max >= 13) AND (age_max <= 17))),
    CONSTRAINT team_hustles_age_min_check CHECK (((age_min >= 13) AND (age_min <= 17))),
    CONSTRAINT team_hustles_pay_amount_check CHECK (((pay_amount IS NULL) OR ((pay_amount >= (1)::numeric) AND (pay_amount <= (10000)::numeric)))),
    CONSTRAINT team_hustles_pay_type_check CHECK ((pay_type = ANY (ARRAY['per_person'::text, 'total_split'::text]))),
    CONSTRAINT team_hustles_status_check CHECK ((status = ANY (ARRAY['open'::text, 'closed'::text]))),
    CONSTRAINT team_hustles_workers_needed_check CHECK (((workers_needed >= 2) AND (workers_needed <= 10)))
);


--
-- Name: user_blocks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_blocks (
    blocker_id uuid NOT NULL,
    blocked_id uuid NOT NULL,
    reason text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT user_blocks_check CHECK ((blocker_id <> blocked_id))
);

ALTER TABLE ONLY public.user_blocks FORCE ROW LEVEL SECURITY;


--
-- Name: verification_cases; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.verification_cases (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    verification_type text NOT NULL,
    status public.mort_verification_status DEFAULT 'not_started'::public.mort_verification_status NOT NULL,
    provider text,
    provider_reference text,
    evidence_path text,
    reviewer_id uuid,
    reviewer_note text,
    submitted_at timestamp with time zone,
    reviewed_at timestamp with time zone,
    expires_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT verification_cases_verification_type_check CHECK ((verification_type = ANY (ARRAY['age'::text, 'identity'::text, 'guardian_consent'::text, 'school_email'::text, 'school_id'::text, 'business'::text])))
);

ALTER TABLE ONLY public.verification_cases FORCE ROW LEVEL SECURITY;


--
-- Name: guardian_invite_accept_limits guardian_invite_accept_limits_pkey; Type: CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.guardian_invite_accept_limits
    ADD CONSTRAINT guardian_invite_accept_limits_pkey PRIMARY KEY (user_id, window_started_at);


--
-- Name: guardian_invite_codes guardian_invite_codes_code_sha256_key; Type: CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.guardian_invite_codes
    ADD CONSTRAINT guardian_invite_codes_code_sha256_key UNIQUE (code_sha256);


--
-- Name: guardian_invite_codes guardian_invite_codes_guardian_link_id_key; Type: CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.guardian_invite_codes
    ADD CONSTRAINT guardian_invite_codes_guardian_link_id_key UNIQUE (guardian_link_id);


--
-- Name: guardian_invite_codes guardian_invite_codes_pkey; Type: CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.guardian_invite_codes
    ADD CONSTRAINT guardian_invite_codes_pkey PRIMARY KEY (id);


--
-- Name: job_execution_events job_execution_events_pkey; Type: CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.job_execution_events
    ADD CONSTRAINT job_execution_events_pkey PRIMARY KEY (id);


--
-- Name: job_execution_sessions job_execution_sessions_pkey; Type: CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.job_execution_sessions
    ADD CONSTRAINT job_execution_sessions_pkey PRIMARY KEY (assignment_id);


--
-- Name: job_pin_confirmation_requests job_pin_confirmation_requests_pkey; Type: CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.job_pin_confirmation_requests
    ADD CONSTRAINT job_pin_confirmation_requests_pkey PRIMARY KEY (actor_id, client_request_id);


--
-- Name: job_private_location_access_events job_private_location_access_events_pkey; Type: CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.job_private_location_access_events
    ADD CONSTRAINT job_private_location_access_events_pkey PRIMARY KEY (id);


--
-- Name: job_private_location_history job_private_location_history_pkey; Type: CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.job_private_location_history
    ADD CONSTRAINT job_private_location_history_pkey PRIMARY KEY (history_id);


--
-- Name: job_private_location_requests job_private_location_requests_pkey; Type: CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.job_private_location_requests
    ADD CONSTRAINT job_private_location_requests_pkey PRIMARY KEY (actor_id, client_request_id);


--
-- Name: job_private_locations job_private_locations_pkey; Type: CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.job_private_locations
    ADD CONSTRAINT job_private_locations_pkey PRIMARY KEY (job_id);


--
-- Name: job_safety_agreement_history job_safety_agreement_history_pkey; Type: CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.job_safety_agreement_history
    ADD CONSTRAINT job_safety_agreement_history_pkey PRIMARY KEY (history_id);


--
-- Name: mort_edge_action_limits mort_edge_action_limits_pkey; Type: CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.mort_edge_action_limits
    ADD CONSTRAINT mort_edge_action_limits_pkey PRIMARY KEY (user_id, action, window_started_at);


--
-- Name: mort_job_mutation_requests mort_job_mutation_requests_pkey; Type: CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.mort_job_mutation_requests
    ADD CONSTRAINT mort_job_mutation_requests_pkey PRIMARY KEY (user_id, client_request_id);


--
-- Name: mort_onboarding_safety mort_onboarding_safety_pkey; Type: CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.mort_onboarding_safety
    ADD CONSTRAINT mort_onboarding_safety_pkey PRIMARY KEY (user_id);


--
-- Name: school_email_domains school_email_domains_pkey; Type: CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.school_email_domains
    ADD CONSTRAINT school_email_domains_pkey PRIMARY KEY (domain);


--
-- Name: stripe_connected_accounts stripe_connected_accounts_environment_provider_account_id_key; Type: CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.stripe_connected_accounts
    ADD CONSTRAINT stripe_connected_accounts_environment_provider_account_id_key UNIQUE (environment, provider_account_id);


--
-- Name: stripe_connected_accounts stripe_connected_accounts_pkey; Type: CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.stripe_connected_accounts
    ADD CONSTRAINT stripe_connected_accounts_pkey PRIMARY KEY (id);


--
-- Name: stripe_connected_accounts stripe_connected_accounts_user_id_environment_key; Type: CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.stripe_connected_accounts
    ADD CONSTRAINT stripe_connected_accounts_user_id_environment_key UNIQUE (user_id, environment);


--
-- Name: stripe_customers stripe_customers_environment_provider_customer_id_key; Type: CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.stripe_customers
    ADD CONSTRAINT stripe_customers_environment_provider_customer_id_key UNIQUE (environment, provider_customer_id);


--
-- Name: stripe_customers stripe_customers_pkey; Type: CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.stripe_customers
    ADD CONSTRAINT stripe_customers_pkey PRIMARY KEY (id);


--
-- Name: stripe_customers stripe_customers_user_id_environment_key; Type: CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.stripe_customers
    ADD CONSTRAINT stripe_customers_user_id_environment_key UNIQUE (user_id, environment);


--
-- Name: stripe_payment_intents stripe_payment_intents_assignment_id_environment_operation__key; Type: CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.stripe_payment_intents
    ADD CONSTRAINT stripe_payment_intents_assignment_id_environment_operation__key UNIQUE (assignment_id, environment, operation_version);


--
-- Name: stripe_payment_intents stripe_payment_intents_environment_idempotency_key_key; Type: CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.stripe_payment_intents
    ADD CONSTRAINT stripe_payment_intents_environment_idempotency_key_key UNIQUE (environment, idempotency_key);


--
-- Name: stripe_payment_intents stripe_payment_intents_environment_provider_payment_intent__key; Type: CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.stripe_payment_intents
    ADD CONSTRAINT stripe_payment_intents_environment_provider_payment_intent__key UNIQUE (environment, provider_payment_intent_id);


--
-- Name: stripe_payment_intents stripe_payment_intents_pkey; Type: CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.stripe_payment_intents
    ADD CONSTRAINT stripe_payment_intents_pkey PRIMARY KEY (id);


--
-- Name: stripe_runtime_controls stripe_runtime_controls_pkey; Type: CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.stripe_runtime_controls
    ADD CONSTRAINT stripe_runtime_controls_pkey PRIMARY KEY (singleton);


--
-- Name: stripe_webhook_events stripe_webhook_events_environment_provider_event_id_key; Type: CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.stripe_webhook_events
    ADD CONSTRAINT stripe_webhook_events_environment_provider_event_id_key UNIQUE (environment, provider_event_id);


--
-- Name: stripe_webhook_events stripe_webhook_events_pkey; Type: CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.stripe_webhook_events
    ADD CONSTRAINT stripe_webhook_events_pkey PRIMARY KEY (id);


--
-- Name: user_roles user_roles_pkey; Type: CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.user_roles
    ADD CONSTRAINT user_roles_pkey PRIMARY KEY (user_id, role);


--
-- Name: verification_provider_allowlist verification_provider_allowlist_pkey; Type: CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.verification_provider_allowlist
    ADD CONSTRAINT verification_provider_allowlist_pkey PRIMARY KEY (provider_key, verification_type);


--
-- Name: verification_provider_ingestion_keys verification_provider_ingestion_keys_pkey; Type: CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.verification_provider_ingestion_keys
    ADD CONSTRAINT verification_provider_ingestion_keys_pkey PRIMARY KEY (provider_key, project_ref);


--
-- Name: verification_provider_results verification_provider_results_pkey; Type: CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.verification_provider_results
    ADD CONSTRAINT verification_provider_results_pkey PRIMARY KEY (id);


--
-- Name: verification_provider_results verification_provider_results_provider_key_provider_event_i_key; Type: CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.verification_provider_results
    ADD CONSTRAINT verification_provider_results_provider_key_provider_event_i_key UNIQUE (provider_key, provider_event_id);


--
-- Name: verification_provider_results verification_provider_results_verification_case_id_provider_key; Type: CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.verification_provider_results
    ADD CONSTRAINT verification_provider_results_verification_case_id_provider_key UNIQUE (verification_case_id, provider_key, provider_reference, provider_event_id);


--
-- Name: admin_audit_log admin_audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_audit_log
    ADD CONSTRAINT admin_audit_log_pkey PRIMARY KEY (id);


--
-- Name: application_status_events application_status_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.application_status_events
    ADD CONSTRAINT application_status_events_pkey PRIMARY KEY (id);


--
-- Name: consents consents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consents
    ADD CONSTRAINT consents_pkey PRIMARY KEY (id);


--
-- Name: conversation_members conversation_members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation_members
    ADD CONSTRAINT conversation_members_pkey PRIMARY KEY (conversation_id, user_id);


--
-- Name: conversations conversations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_pkey PRIMARY KEY (id);


--
-- Name: disputes disputes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.disputes
    ADD CONSTRAINT disputes_pkey PRIMARY KEY (id);


--
-- Name: evidence_files evidence_files_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evidence_files
    ADD CONSTRAINT evidence_files_pkey PRIMARY KEY (id);


--
-- Name: evidence_files evidence_files_storage_path_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evidence_files
    ADD CONSTRAINT evidence_files_storage_path_key UNIQUE (storage_path);


--
-- Name: guardian_links guardian_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guardian_links
    ADD CONSTRAINT guardian_links_pkey PRIMARY KEY (id);


--
-- Name: guardian_links guardian_links_teen_user_id_guardian_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guardian_links
    ADD CONSTRAINT guardian_links_teen_user_id_guardian_user_id_key UNIQUE (teen_user_id, guardian_user_id);


--
-- Name: guardian_preferences guardian_preferences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guardian_preferences
    ADD CONSTRAINT guardian_preferences_pkey PRIMARY KEY (link_id);


--
-- Name: job_applications job_applications_job_id_applicant_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_applications
    ADD CONSTRAINT job_applications_job_id_applicant_id_key UNIQUE (job_id, applicant_id);


--
-- Name: job_applications job_applications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_applications
    ADD CONSTRAINT job_applications_pkey PRIMARY KEY (id);


--
-- Name: job_assignments job_assignments_application_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_assignments
    ADD CONSTRAINT job_assignments_application_id_key UNIQUE (application_id);


--
-- Name: job_assignments job_assignments_job_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_assignments
    ADD CONSTRAINT job_assignments_job_id_key UNIQUE (job_id);


--
-- Name: job_assignments job_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_assignments
    ADD CONSTRAINT job_assignments_pkey PRIMARY KEY (id);


--
-- Name: job_contract_acceptances job_contract_acceptances_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_contract_acceptances
    ADD CONSTRAINT job_contract_acceptances_pkey PRIMARY KEY (id);


--
-- Name: job_contract_acceptances job_contract_acceptances_version_user_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_contract_acceptances
    ADD CONSTRAINT job_contract_acceptances_version_user_key UNIQUE (contract_version_id, user_id);


--
-- Name: job_contract_change_acceptances job_contract_change_acceptances_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_contract_change_acceptances
    ADD CONSTRAINT job_contract_change_acceptances_pkey PRIMARY KEY (id);


--
-- Name: job_contract_change_acceptances job_contract_change_acceptances_request_user_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_contract_change_acceptances
    ADD CONSTRAINT job_contract_change_acceptances_request_user_key UNIQUE (change_request_id, user_id);


--
-- Name: job_contract_change_requests job_contract_change_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_contract_change_requests
    ADD CONSTRAINT job_contract_change_requests_pkey PRIMARY KEY (id);


--
-- Name: job_contract_versions job_contract_versions_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_contract_versions
    ADD CONSTRAINT job_contract_versions_number_key UNIQUE (contract_id, version_number);


--
-- Name: job_contract_versions job_contract_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_contract_versions
    ADD CONSTRAINT job_contract_versions_pkey PRIMARY KEY (id);


--
-- Name: job_contracts job_contracts_application_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_contracts
    ADD CONSTRAINT job_contracts_application_key UNIQUE (application_id);


--
-- Name: job_contracts job_contracts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_contracts
    ADD CONSTRAINT job_contracts_pkey PRIMARY KEY (id);


--
-- Name: job_execution_review_responses job_execution_review_responses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_execution_review_responses
    ADD CONSTRAINT job_execution_review_responses_pkey PRIMARY KEY (id);


--
-- Name: job_execution_review_responses job_execution_review_responses_request_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_execution_review_responses
    ADD CONSTRAINT job_execution_review_responses_request_key UNIQUE (assignment_id, responded_by, client_request_id);


--
-- Name: job_interests job_interests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_interests
    ADD CONSTRAINT job_interests_pkey PRIMARY KEY (user_id, job_id);


--
-- Name: job_safety_agreements job_safety_agreements_application_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_safety_agreements
    ADD CONSTRAINT job_safety_agreements_application_id_key UNIQUE (application_id);


--
-- Name: job_safety_agreements job_safety_agreements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_safety_agreements
    ADD CONSTRAINT job_safety_agreements_pkey PRIMARY KEY (id);


--
-- Name: job_safety_cancellations job_safety_cancellations_application_actor_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_safety_cancellations
    ADD CONSTRAINT job_safety_cancellations_application_actor_key UNIQUE (application_id, actor_id);


--
-- Name: job_safety_cancellations job_safety_cancellations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_safety_cancellations
    ADD CONSTRAINT job_safety_cancellations_pkey PRIMARY KEY (id);


--
-- Name: job_safety_checkins job_safety_checkins_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_safety_checkins
    ADD CONSTRAINT job_safety_checkins_pkey PRIMARY KEY (id);


--
-- Name: job_safety_checkins job_safety_checkins_teen_request_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_safety_checkins
    ADD CONSTRAINT job_safety_checkins_teen_request_unique UNIQUE (teen_user_id, client_request_id);


--
-- Name: job_safety_plans job_safety_plans_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_safety_plans
    ADD CONSTRAINT job_safety_plans_pkey PRIMARY KEY (application_id);


--
-- Name: job_status_events job_status_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_status_events
    ADD CONSTRAINT job_status_events_pkey PRIMARY KEY (id);


--
-- Name: jobs jobs_estimated_duration_minutes_check; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.jobs
    ADD CONSTRAINT jobs_estimated_duration_minutes_check CHECK (((estimated_duration_minutes IS NULL) OR ((estimated_duration_minutes >= 5) AND (estimated_duration_minutes <= 1440)))) NOT VALID;


--
-- Name: jobs jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jobs
    ADD CONSTRAINT jobs_pkey PRIMARY KEY (id);


--
-- Name: jobs jobs_service_fee_nonnegative_check; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.jobs
    ADD CONSTRAINT jobs_service_fee_nonnegative_check CHECK (((mort_service_fee_cents IS NULL) OR (mort_service_fee_cents >= 0))) NOT VALID;


--
-- Name: jobs jobs_teen_age_range_check; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.jobs
    ADD CONSTRAINT jobs_teen_age_range_check CHECK ((((teen_min_age >= 13) AND (teen_min_age <= 17)) AND ((teen_max_age >= teen_min_age) AND (teen_max_age <= 17)))) NOT VALID;


--
-- Name: jobs jobs_workers_needed_check; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.jobs
    ADD CONSTRAINT jobs_workers_needed_check CHECK (((workers_needed >= 1) AND (workers_needed <= 100))) NOT VALID;


--
-- Name: legal_acceptance_audit_events legal_acceptance_audit_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legal_acceptance_audit_events
    ADD CONSTRAINT legal_acceptance_audit_events_pkey PRIMARY KEY (id);


--
-- Name: legal_acceptances legal_acceptances_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legal_acceptances
    ADD CONSTRAINT legal_acceptances_pkey PRIMARY KEY (id);


--
-- Name: legal_acceptances legal_acceptances_user_id_document_version_id_server_reques_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legal_acceptances
    ADD CONSTRAINT legal_acceptances_user_id_document_version_id_server_reques_key UNIQUE (user_id, document_version_id, server_request_id);


--
-- Name: legal_document_versions legal_document_versions_document_id_version_label_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legal_document_versions
    ADD CONSTRAINT legal_document_versions_document_id_version_label_key UNIQUE (document_id, version_label);


--
-- Name: legal_document_versions legal_document_versions_id_document_id_content_hash_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legal_document_versions
    ADD CONSTRAINT legal_document_versions_id_document_id_content_hash_key UNIQUE (id, document_id, content_hash);


--
-- Name: legal_document_versions legal_document_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legal_document_versions
    ADD CONSTRAINT legal_document_versions_pkey PRIMARY KEY (id);


--
-- Name: legal_documents legal_documents_document_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legal_documents
    ADD CONSTRAINT legal_documents_document_key_key UNIQUE (document_key);


--
-- Name: legal_documents legal_documents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legal_documents
    ADD CONSTRAINT legal_documents_pkey PRIMARY KEY (id);


--
-- Name: legal_role_requirements legal_role_requirements_document_id_role_age_band_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legal_role_requirements
    ADD CONSTRAINT legal_role_requirements_document_id_role_age_band_key UNIQUE (document_id, role, age_band);


--
-- Name: legal_role_requirements legal_role_requirements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legal_role_requirements
    ADD CONSTRAINT legal_role_requirements_pkey PRIMARY KEY (id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: mort_release_control mort_release_control_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mort_release_control
    ADD CONSTRAINT mort_release_control_pkey PRIMARY KEY (is_primary);


--
-- Name: notification_preferences notification_preferences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_preferences
    ADD CONSTRAINT notification_preferences_pkey PRIMARY KEY (user_id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: payment_records payment_records_idempotency_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_records
    ADD CONSTRAINT payment_records_idempotency_key_key UNIQUE (idempotency_key);


--
-- Name: payment_records payment_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_records
    ADD CONSTRAINT payment_records_pkey PRIMARY KEY (id);


--
-- Name: payment_records payment_records_provider_payment_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_records
    ADD CONSTRAINT payment_records_provider_payment_id_key UNIQUE (provider_payment_id);


--
-- Name: profiles profiles_guardian_setup_status_check; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.profiles
    ADD CONSTRAINT profiles_guardian_setup_status_check CHECK ((guardian_setup_status = ANY (ARRAY['not_started'::text, 'skipped'::text, 'invite_pending'::text, 'linked'::text]))) NOT VALID;


--
-- Name: profiles profiles_location_setup_mode_check; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.profiles
    ADD CONSTRAINT profiles_location_setup_mode_check CHECK ((location_setup_mode = ANY (ARRAY['city_state'::text, 'partner_supported'::text, 'location_deferred'::text]))) NOT VALID;


--
-- Name: profiles profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);


--
-- Name: profiles profiles_travel_distance_check; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.profiles
    ADD CONSTRAINT profiles_travel_distance_check CHECK (((max_travel_distance_miles IS NULL) OR ((max_travel_distance_miles >= 1) AND (max_travel_distance_miles <= 100)))) NOT VALID;


--
-- Name: profiles profiles_travel_minutes_check; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.profiles
    ADD CONSTRAINT profiles_travel_minutes_check CHECK (((max_travel_minutes IS NULL) OR ((max_travel_minutes >= 1) AND (max_travel_minutes <= 240)))) NOT VALID;


--
-- Name: profiles profiles_username_format_check; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.profiles
    ADD CONSTRAINT profiles_username_format_check CHECK (((username IS NULL) OR (username ~ '^[a-z0-9_]{3,24}$'::text))) NOT VALID;


--
-- Name: proof_uploads proof_uploads_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.proof_uploads
    ADD CONSTRAINT proof_uploads_pkey PRIMARY KEY (id);


--
-- Name: proof_uploads proof_uploads_storage_path_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.proof_uploads
    ADD CONSTRAINT proof_uploads_storage_path_key UNIQUE (storage_path);


--
-- Name: reviews reviews_one_per_side_per_application; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_one_per_side_per_application UNIQUE (application_id, reviewer_id);


--
-- Name: reviews reviews_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_pkey PRIMARY KEY (id);


--
-- Name: role_requests role_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_requests
    ADD CONSTRAINT role_requests_pkey PRIMARY KEY (id);


--
-- Name: role_requests role_requests_user_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_requests
    ADD CONSTRAINT role_requests_user_id_id_key UNIQUE (user_id, id);


--
-- Name: safety_pings safety_pings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.safety_pings
    ADD CONSTRAINT safety_pings_pkey PRIMARY KEY (id);


--
-- Name: safety_pings safety_pings_teen_request_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.safety_pings
    ADD CONSTRAINT safety_pings_teen_request_unique UNIQUE (teen_id, client_request_id);


--
-- Name: safety_reports safety_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.safety_reports
    ADD CONSTRAINT safety_reports_pkey PRIMARY KEY (id);


--
-- Name: saved_jobs saved_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_jobs
    ADD CONSTRAINT saved_jobs_pkey PRIMARY KEY (user_id, job_id);


--
-- Name: team_hustle_members team_hustle_members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_hustle_members
    ADD CONSTRAINT team_hustle_members_pkey PRIMARY KEY (hustle_id, user_id);


--
-- Name: team_hustles team_hustles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_hustles
    ADD CONSTRAINT team_hustles_pkey PRIMARY KEY (id);


--
-- Name: user_blocks user_blocks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_blocks
    ADD CONSTRAINT user_blocks_pkey PRIMARY KEY (blocker_id, blocked_id);


--
-- Name: verification_cases verification_cases_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.verification_cases
    ADD CONSTRAINT verification_cases_pkey PRIMARY KEY (id);


--
-- Name: guardian_invite_codes_teen_recent_idx; Type: INDEX; Schema: private; Owner: -
--

CREATE INDEX guardian_invite_codes_teen_recent_idx ON private.guardian_invite_codes USING btree (teen_user_id, created_at DESC);


--
-- Name: idx_user_roles_granted_by; Type: INDEX; Schema: private; Owner: -
--

CREATE INDEX idx_user_roles_granted_by ON private.user_roles USING btree (granted_by);


--
-- Name: job_execution_events_application_idx; Type: INDEX; Schema: private; Owner: -
--

CREATE INDEX job_execution_events_application_idx ON private.job_execution_events USING btree (application_id, created_at DESC);


--
-- Name: job_execution_events_request_idx; Type: INDEX; Schema: private; Owner: -
--

CREATE UNIQUE INDEX job_execution_events_request_idx ON private.job_execution_events USING btree (application_id, event_type, actor_id, request_id) WHERE (request_id IS NOT NULL);


--
-- Name: job_execution_sessions_application_idx; Type: INDEX; Schema: private; Owner: -
--

CREATE UNIQUE INDEX job_execution_sessions_application_idx ON private.job_execution_sessions USING btree (application_id);


--
-- Name: job_private_locations_poster_idx; Type: INDEX; Schema: private; Owner: -
--

CREATE INDEX job_private_locations_poster_idx ON private.job_private_locations USING btree (poster_id);


--
-- Name: stripe_connected_accounts_user_idx; Type: INDEX; Schema: private; Owner: -
--

CREATE INDEX stripe_connected_accounts_user_idx ON private.stripe_connected_accounts USING btree (user_id, environment);


--
-- Name: stripe_payment_intents_assignment_idx; Type: INDEX; Schema: private; Owner: -
--

CREATE INDEX stripe_payment_intents_assignment_idx ON private.stripe_payment_intents USING btree (assignment_id, environment, created_at DESC);


--
-- Name: stripe_payment_intents_payee_id_idx; Type: INDEX; Schema: private; Owner: -
--

CREATE INDEX stripe_payment_intents_payee_id_idx ON private.stripe_payment_intents USING btree (payee_id);


--
-- Name: stripe_payment_intents_payer_id_idx; Type: INDEX; Schema: private; Owner: -
--

CREATE INDEX stripe_payment_intents_payer_id_idx ON private.stripe_payment_intents USING btree (payer_id);


--
-- Name: stripe_webhook_events_retry_idx; Type: INDEX; Schema: private; Owner: -
--

CREATE INDEX stripe_webhook_events_retry_idx ON private.stripe_webhook_events USING btree (environment, processing_status, lease_expires_at);


--
-- Name: verification_provider_results_case_current_idx; Type: INDEX; Schema: private; Owner: -
--

CREATE INDEX verification_provider_results_case_current_idx ON private.verification_provider_results USING btree (verification_case_id, provider_key, verification_type, received_at DESC);


--
-- Name: application_status_events_actor_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX application_status_events_actor_id_idx ON public.application_status_events USING btree (actor_id);


--
-- Name: application_status_events_application_created_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX application_status_events_application_created_idx ON public.application_status_events USING btree (application_id, created_at, id);


--
-- Name: guardian_links_one_active_guardian_per_teen; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX guardian_links_one_active_guardian_per_teen ON public.guardian_links USING btree (teen_user_id) WHERE (status = 'active'::text);


--
-- Name: guardian_links_one_pending_invite_per_teen; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX guardian_links_one_pending_invite_per_teen ON public.guardian_links USING btree (teen_user_id) WHERE (status = 'pending'::text);


--
-- Name: guardian_links_revoked_by_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX guardian_links_revoked_by_idx ON public.guardian_links USING btree (revoked_by);


--
-- Name: idx_admin_audit_actor; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_admin_audit_actor ON public.admin_audit_log USING btree (actor_id);


--
-- Name: idx_applications_applicant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_applications_applicant ON public.job_applications USING btree (applicant_id, created_at DESC);


--
-- Name: idx_applications_job; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_applications_job ON public.job_applications USING btree (job_id, status);


--
-- Name: idx_assignments_adult; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_assignments_adult ON public.job_assignments USING btree (adult_user_id, status);


--
-- Name: idx_assignments_teen; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_assignments_teen ON public.job_assignments USING btree (teen_user_id, status);


--
-- Name: idx_consents_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_consents_user ON public.consents USING btree (user_id);


--
-- Name: idx_conversations_assignment; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_conversations_assignment ON public.conversations USING btree (assignment_id);


--
-- Name: idx_conversations_job; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_conversations_job ON public.conversations USING btree (job_id);


--
-- Name: idx_disputes_assigned_to; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_disputes_assigned_to ON public.disputes USING btree (assigned_to);


--
-- Name: idx_disputes_assignment; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_disputes_assignment ON public.disputes USING btree (assignment_id);


--
-- Name: idx_disputes_opened_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_disputes_opened_by ON public.disputes USING btree (opened_by);


--
-- Name: idx_disputes_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_disputes_status ON public.disputes USING btree (status, created_at);


--
-- Name: idx_evidence_assignment; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_evidence_assignment ON public.evidence_files USING btree (assignment_id);


--
-- Name: idx_evidence_dispute; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_evidence_dispute ON public.evidence_files USING btree (dispute_id);


--
-- Name: idx_evidence_report; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_evidence_report ON public.evidence_files USING btree (report_id);


--
-- Name: idx_evidence_uploader; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_evidence_uploader ON public.evidence_files USING btree (uploaded_by);


--
-- Name: idx_guardian_links_guardian; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_guardian_links_guardian ON public.guardian_links USING btree (guardian_user_id);


--
-- Name: idx_guardian_links_initiator; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_guardian_links_initiator ON public.guardian_links USING btree (initiated_by);


--
-- Name: idx_jobs_feed; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_jobs_feed ON public.jobs USING btree (status, safety_review_status, published_at DESC);


--
-- Name: idx_jobs_location; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_jobs_location ON public.jobs USING btree (region, city, status);


--
-- Name: idx_jobs_poster; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_jobs_poster ON public.jobs USING btree (poster_id, created_at DESC);


--
-- Name: idx_members_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_members_user ON public.conversation_members USING btree (user_id, conversation_id);


--
-- Name: idx_messages_conversation; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_messages_conversation ON public.messages USING btree (conversation_id, created_at);


--
-- Name: idx_messages_sender; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_messages_sender ON public.messages USING btree (sender_id);


--
-- Name: idx_notifications_user_unread; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notifications_user_unread ON public.notifications USING btree (user_id, created_at DESC) WHERE (read_at IS NULL);


--
-- Name: idx_payments_assignment; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payments_assignment ON public.payment_records USING btree (assignment_id);


--
-- Name: idx_payments_payee; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payments_payee ON public.payment_records USING btree (payee_id);


--
-- Name: idx_payments_payer; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payments_payer ON public.payment_records USING btree (payer_id);


--
-- Name: idx_reports_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_reports_status ON public.safety_reports USING btree (status, severity, created_at);


--
-- Name: idx_role_requests_reviewer; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_role_requests_reviewer ON public.role_requests USING btree (reviewed_by);


--
-- Name: idx_safety_reports_assigned; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_safety_reports_assigned ON public.safety_reports USING btree (assigned_to);


--
-- Name: idx_safety_reports_job; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_safety_reports_job ON public.safety_reports USING btree (job_id);


--
-- Name: idx_safety_reports_message; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_safety_reports_message ON public.safety_reports USING btree (message_id);


--
-- Name: idx_safety_reports_reported_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_safety_reports_reported_user ON public.safety_reports USING btree (reported_user_id);


--
-- Name: idx_safety_reports_reporter; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_safety_reports_reporter ON public.safety_reports USING btree (reporter_id);


--
-- Name: idx_user_blocks_blocked; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_blocks_blocked ON public.user_blocks USING btree (blocked_id);


--
-- Name: idx_verification_reviewer; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_verification_reviewer ON public.verification_cases USING btree (reviewer_id);


--
-- Name: idx_verification_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_verification_user ON public.verification_cases USING btree (user_id);


--
-- Name: job_applications_guardian_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX job_applications_guardian_id_idx ON public.job_applications USING btree (guardian_id);


--
-- Name: job_contract_acceptances_contract_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX job_contract_acceptances_contract_idx ON public.job_contract_acceptances USING btree (contract_id, accepted_at);


--
-- Name: job_contract_change_requests_contract_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX job_contract_change_requests_contract_idx ON public.job_contract_change_requests USING btree (contract_id, requested_at DESC);


--
-- Name: job_contract_one_pending_change_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX job_contract_one_pending_change_idx ON public.job_contract_change_requests USING btree (contract_id) WHERE (status = 'pending_both_parties'::text);


--
-- Name: job_contract_versions_contract_order_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX job_contract_versions_contract_order_idx ON public.job_contract_versions USING btree (contract_id, version_number DESC);


--
-- Name: job_execution_review_responses_dispute_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX job_execution_review_responses_dispute_idx ON public.job_execution_review_responses USING btree (dispute_id);


--
-- Name: job_execution_review_responses_responded_by_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX job_execution_review_responses_responded_by_idx ON public.job_execution_review_responses USING btree (responded_by);


--
-- Name: job_interests_job_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX job_interests_job_id_idx ON public.job_interests USING btree (job_id);


--
-- Name: job_safety_agreements_adult_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX job_safety_agreements_adult_id_idx ON public.job_safety_agreements USING btree (adult_id);


--
-- Name: job_safety_agreements_job_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX job_safety_agreements_job_id_idx ON public.job_safety_agreements USING btree (job_id);


--
-- Name: job_safety_agreements_participants_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX job_safety_agreements_participants_idx ON public.job_safety_agreements USING btree (teen_id, adult_id, status);


--
-- Name: job_safety_cancellations_actor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX job_safety_cancellations_actor_idx ON public.job_safety_cancellations USING btree (actor_id);


--
-- Name: job_safety_cancellations_assignment_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX job_safety_cancellations_assignment_idx ON public.job_safety_cancellations USING btree (assignment_id);


--
-- Name: job_safety_cancellations_job_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX job_safety_cancellations_job_idx ON public.job_safety_cancellations USING btree (job_id);


--
-- Name: job_safety_cancellations_reported_user_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX job_safety_cancellations_reported_user_idx ON public.job_safety_cancellations USING btree (reported_user_id);


--
-- Name: job_safety_cancellations_safety_report_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX job_safety_cancellations_safety_report_idx ON public.job_safety_cancellations USING btree (safety_report_id);


--
-- Name: job_safety_checkins_adult_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX job_safety_checkins_adult_idx ON public.job_safety_checkins USING btree (adult_user_id);


--
-- Name: job_safety_checkins_application_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX job_safety_checkins_application_idx ON public.job_safety_checkins USING btree (application_id);


--
-- Name: job_safety_checkins_job_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX job_safety_checkins_job_idx ON public.job_safety_checkins USING btree (job_id);


--
-- Name: job_safety_checkins_teen_due_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX job_safety_checkins_teen_due_idx ON public.job_safety_checkins USING btree (teen_user_id, expected_at) WHERE (status = 'scheduled'::text);


--
-- Name: job_safety_plans_adult_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX job_safety_plans_adult_id_idx ON public.job_safety_plans USING btree (adult_id);


--
-- Name: job_safety_plans_job_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX job_safety_plans_job_status_idx ON public.job_safety_plans USING btree (job_id, updated_at DESC);


--
-- Name: job_safety_plans_teen_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX job_safety_plans_teen_id_idx ON public.job_safety_plans USING btree (teen_id);


--
-- Name: job_status_events_actor_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX job_status_events_actor_id_idx ON public.job_status_events USING btree (actor_id);


--
-- Name: job_status_events_job_created_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX job_status_events_job_created_idx ON public.job_status_events USING btree (job_id, created_at, id);


--
-- Name: jobs_public_feed_newest_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX jobs_public_feed_newest_idx ON public.jobs USING btree (published_at DESC, id DESC) WHERE ((status = 'open'::public.mort_job_status) AND (safety_review_status = 'approved'::text));


--
-- Name: jobs_public_feed_pay_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX jobs_public_feed_pay_idx ON public.jobs USING btree (pay_amount DESC, id DESC) WHERE ((status = 'open'::public.mort_job_status) AND (safety_review_status = 'approved'::text));


--
-- Name: legal_acceptance_audit_acceptance_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX legal_acceptance_audit_acceptance_idx ON public.legal_acceptance_audit_events USING btree (acceptance_id);


--
-- Name: legal_acceptance_audit_document_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX legal_acceptance_audit_document_idx ON public.legal_acceptance_audit_events USING btree (document_id);


--
-- Name: legal_acceptance_audit_user_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX legal_acceptance_audit_user_idx ON public.legal_acceptance_audit_events USING btree (user_id, occurred_at DESC);


--
-- Name: legal_acceptance_audit_version_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX legal_acceptance_audit_version_idx ON public.legal_acceptance_audit_events USING btree (document_version_id);


--
-- Name: legal_acceptances_document_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX legal_acceptances_document_idx ON public.legal_acceptances USING btree (document_id);


--
-- Name: legal_acceptances_one_active_version_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX legal_acceptances_one_active_version_idx ON public.legal_acceptances USING btree (user_id, document_version_id) WHERE active;


--
-- Name: legal_acceptances_user_document_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX legal_acceptances_user_document_idx ON public.legal_acceptances USING btree (user_id, document_id, accepted_at DESC);


--
-- Name: legal_acceptances_version_reference_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX legal_acceptances_version_reference_idx ON public.legal_acceptances USING btree (document_version_id, document_id, content_hash);


--
-- Name: legal_document_versions_current_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX legal_document_versions_current_idx ON public.legal_document_versions USING btree (document_id, publication_status, effective_at DESC, created_at DESC);


--
-- Name: legal_role_requirements_role_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX legal_role_requirements_role_idx ON public.legal_role_requirements USING btree (role, age_band, document_id);


--
-- Name: messages_sender_client_request_id_uidx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX messages_sender_client_request_id_uidx ON public.messages USING btree (sender_id, client_request_id) WHERE (client_request_id IS NOT NULL);


--
-- Name: profiles_username_lower_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX profiles_username_lower_unique ON public.profiles USING btree (lower(username)) WHERE (username IS NOT NULL);


--
-- Name: proof_uploads_application_created_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX proof_uploads_application_created_idx ON public.proof_uploads USING btree (application_id, created_at DESC);


--
-- Name: proof_uploads_assignment_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX proof_uploads_assignment_status_idx ON public.proof_uploads USING btree (assignment_id, status, created_at DESC);


--
-- Name: reviews_subject_revealed_created_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX reviews_subject_revealed_created_idx ON public.reviews USING btree (subject_id, revealed_at, created_at DESC) WHERE (moderation_status = 'approved'::text);


--
-- Name: safety_pings_job_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX safety_pings_job_idx ON public.safety_pings USING btree (job_id) WHERE (job_id IS NOT NULL);


--
-- Name: safety_pings_teen_created_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX safety_pings_teen_created_idx ON public.safety_pings USING btree (teen_id, created_at DESC);


--
-- Name: safety_reports_reporter_danger_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX safety_reports_reporter_danger_created_at_idx ON public.safety_reports USING btree (reporter_id, immediate_danger, created_at DESC);


--
-- Name: safety_reports_reporter_request_id_uidx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX safety_reports_reporter_request_id_uidx ON public.safety_reports USING btree (reporter_id, client_request_id) WHERE (client_request_id IS NOT NULL);


--
-- Name: saved_jobs_job_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX saved_jobs_job_idx ON public.saved_jobs USING btree (job_id);


--
-- Name: saved_jobs_user_created_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX saved_jobs_user_created_idx ON public.saved_jobs USING btree (user_id, created_at DESC);


--
-- Name: team_hustle_members_user_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX team_hustle_members_user_idx ON public.team_hustle_members USING btree (user_id, joined_at DESC);


--
-- Name: team_hustles_poster_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX team_hustles_poster_idx ON public.team_hustles USING btree (poster_id, created_at DESC);


--
-- Name: team_hustles_status_created_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX team_hustles_status_created_idx ON public.team_hustles USING btree (status, created_at DESC);


--
-- Name: job_private_locations job_private_locations_archive_before_update; Type: TRIGGER; Schema: private; Owner: -
--

CREATE TRIGGER job_private_locations_archive_before_update BEFORE UPDATE ON private.job_private_locations FOR EACH ROW EXECUTE FUNCTION private.archive_job_private_location_before_update();


--
-- Name: job_applications applications_touch_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER applications_touch_updated_at BEFORE UPDATE ON public.job_applications FOR EACH ROW EXECUTE FUNCTION private.touch_updated_at();


--
-- Name: conversations conversations_touch_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER conversations_touch_updated_at BEFORE UPDATE ON public.conversations FOR EACH ROW EXECUTE FUNCTION private.touch_updated_at();


--
-- Name: disputes disputes_touch_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER disputes_touch_updated_at BEFORE UPDATE ON public.disputes FOR EACH ROW EXECUTE FUNCTION private.touch_updated_at();


--
-- Name: guardian_links guardian_links_audit_revocation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER guardian_links_audit_revocation BEFORE UPDATE OF status ON public.guardian_links FOR EACH ROW EXECUTE FUNCTION private.audit_guardian_link_revocation();


--
-- Name: guardian_links guardian_links_touch_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER guardian_links_touch_updated_at BEFORE UPDATE ON public.guardian_links FOR EACH ROW EXECUTE FUNCTION private.touch_updated_at();


--
-- Name: job_applications job_applications_create_contract; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER job_applications_create_contract AFTER UPDATE OF status ON public.job_applications FOR EACH ROW EXECUTE FUNCTION private.create_job_contract_after_acceptance();


--
-- Name: job_applications job_applications_create_safety_agreement; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER job_applications_create_safety_agreement AFTER UPDATE OF status ON public.job_applications FOR EACH ROW EXECUTE FUNCTION private.create_job_safety_agreement_after_acceptance();


--
-- Name: job_applications job_applications_log_status_event; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER job_applications_log_status_event AFTER UPDATE OF status ON public.job_applications FOR EACH ROW EXECUTE FUNCTION private.capture_application_status_event();


--
-- Name: job_contracts job_contracts_refresh_safety_agreement; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER job_contracts_refresh_safety_agreement AFTER UPDATE OF active_version_id ON public.job_contracts FOR EACH ROW EXECUTE FUNCTION private.refresh_safety_agreement_after_contract_change();


--
-- Name: job_safety_agreements job_safety_agreements_archive_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER job_safety_agreements_archive_before_update BEFORE UPDATE ON public.job_safety_agreements FOR EACH ROW EXECUTE FUNCTION private.archive_job_safety_agreement_before_update();


--
-- Name: job_safety_agreements job_safety_agreements_location_version_trg; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER job_safety_agreements_location_version_trg BEFORE INSERT OR UPDATE OF job_id ON public.job_safety_agreements FOR EACH ROW EXECUTE FUNCTION public.sync_safety_agreement_location_version();


--
-- Name: jobs jobs_log_status_event; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER jobs_log_status_event AFTER INSERT OR UPDATE OF status ON public.jobs FOR EACH ROW EXECUTE FUNCTION private.capture_job_status_event();


--
-- Name: jobs jobs_require_protected_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER jobs_require_protected_mutation BEFORE INSERT OR DELETE OR UPDATE ON public.jobs FOR EACH ROW EXECUTE FUNCTION private.guard_job_table_mutations();


--
-- Name: jobs jobs_touch_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER jobs_touch_updated_at BEFORE UPDATE ON public.jobs FOR EACH ROW EXECUTE FUNCTION private.touch_updated_at();


--
-- Name: profiles mort_enforce_profile_minimum_age; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER mort_enforce_profile_minimum_age BEFORE INSERT OR UPDATE OF date_of_birth, role ON public.profiles FOR EACH ROW EXECUTE FUNCTION private.enforce_profile_minimum_age();


--
-- Name: payment_records payments_touch_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER payments_touch_updated_at BEFORE UPDATE ON public.payment_records FOR EACH ROW EXECUTE FUNCTION private.touch_updated_at();


--
-- Name: profiles profiles_touch_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER profiles_touch_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION private.touch_updated_at();


--
-- Name: safety_reports reports_touch_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER reports_touch_updated_at BEFORE UPDATE ON public.safety_reports FOR EACH ROW EXECUTE FUNCTION private.touch_updated_at();


--
-- Name: reviews reviews_reveal_reciprocal_after_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER reviews_reveal_reciprocal_after_insert AFTER INSERT ON public.reviews FOR EACH ROW EXECUTE FUNCTION private.reveal_reciprocal_job_reviews();


--
-- Name: safety_pings safety_pings_notify_guardians; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER safety_pings_notify_guardians AFTER INSERT ON public.safety_pings FOR EACH ROW EXECUTE FUNCTION private.notify_guardians_of_safety_ping();


--
-- Name: verification_cases verification_cases_touch_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER verification_cases_touch_updated_at BEFORE UPDATE ON public.verification_cases FOR EACH ROW EXECUTE FUNCTION private.touch_updated_at();


--
-- Name: guardian_invite_accept_limits guardian_invite_accept_limits_user_id_fkey; Type: FK CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.guardian_invite_accept_limits
    ADD CONSTRAINT guardian_invite_accept_limits_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: guardian_invite_codes guardian_invite_codes_guardian_link_id_fkey; Type: FK CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.guardian_invite_codes
    ADD CONSTRAINT guardian_invite_codes_guardian_link_id_fkey FOREIGN KEY (guardian_link_id) REFERENCES public.guardian_links(id) ON DELETE CASCADE;


--
-- Name: guardian_invite_codes guardian_invite_codes_teen_user_id_fkey; Type: FK CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.guardian_invite_codes
    ADD CONSTRAINT guardian_invite_codes_teen_user_id_fkey FOREIGN KEY (teen_user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: job_execution_events job_execution_events_actor_id_fkey; Type: FK CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.job_execution_events
    ADD CONSTRAINT job_execution_events_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: job_execution_events job_execution_events_application_id_fkey; Type: FK CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.job_execution_events
    ADD CONSTRAINT job_execution_events_application_id_fkey FOREIGN KEY (application_id) REFERENCES public.job_applications(id) ON DELETE RESTRICT;


--
-- Name: job_execution_events job_execution_events_assignment_id_fkey; Type: FK CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.job_execution_events
    ADD CONSTRAINT job_execution_events_assignment_id_fkey FOREIGN KEY (assignment_id) REFERENCES public.job_assignments(id) ON DELETE RESTRICT;


--
-- Name: job_execution_sessions job_execution_sessions_application_id_fkey; Type: FK CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.job_execution_sessions
    ADD CONSTRAINT job_execution_sessions_application_id_fkey FOREIGN KEY (application_id) REFERENCES public.job_applications(id) ON DELETE RESTRICT;


--
-- Name: job_execution_sessions job_execution_sessions_assignment_id_fkey; Type: FK CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.job_execution_sessions
    ADD CONSTRAINT job_execution_sessions_assignment_id_fkey FOREIGN KEY (assignment_id) REFERENCES public.job_assignments(id) ON DELETE RESTRICT;


--
-- Name: job_execution_sessions job_execution_sessions_job_id_fkey; Type: FK CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.job_execution_sessions
    ADD CONSTRAINT job_execution_sessions_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id) ON DELETE RESTRICT;


--
-- Name: job_pin_confirmation_requests job_pin_confirmation_requests_actor_id_fkey; Type: FK CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.job_pin_confirmation_requests
    ADD CONSTRAINT job_pin_confirmation_requests_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: job_pin_confirmation_requests job_pin_confirmation_requests_application_id_fkey; Type: FK CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.job_pin_confirmation_requests
    ADD CONSTRAINT job_pin_confirmation_requests_application_id_fkey FOREIGN KEY (application_id) REFERENCES public.job_applications(id) ON DELETE RESTRICT;


--
-- Name: job_private_location_access_events job_private_location_access_events_actor_id_fkey; Type: FK CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.job_private_location_access_events
    ADD CONSTRAINT job_private_location_access_events_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: job_private_locations job_private_locations_job_id_fkey; Type: FK CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.job_private_locations
    ADD CONSTRAINT job_private_locations_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id) ON DELETE CASCADE;


--
-- Name: job_private_locations job_private_locations_poster_id_fkey; Type: FK CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.job_private_locations
    ADD CONSTRAINT job_private_locations_poster_id_fkey FOREIGN KEY (poster_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: mort_edge_action_limits mort_edge_action_limits_user_id_fkey; Type: FK CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.mort_edge_action_limits
    ADD CONSTRAINT mort_edge_action_limits_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: mort_job_mutation_requests mort_job_mutation_requests_user_id_fkey; Type: FK CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.mort_job_mutation_requests
    ADD CONSTRAINT mort_job_mutation_requests_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: mort_onboarding_safety mort_onboarding_safety_user_id_fkey; Type: FK CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.mort_onboarding_safety
    ADD CONSTRAINT mort_onboarding_safety_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: stripe_connected_accounts stripe_connected_accounts_user_id_fkey; Type: FK CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.stripe_connected_accounts
    ADD CONSTRAINT stripe_connected_accounts_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE RESTRICT;


--
-- Name: stripe_customers stripe_customers_user_id_fkey; Type: FK CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.stripe_customers
    ADD CONSTRAINT stripe_customers_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE RESTRICT;


--
-- Name: stripe_payment_intents stripe_payment_intents_assignment_id_fkey; Type: FK CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.stripe_payment_intents
    ADD CONSTRAINT stripe_payment_intents_assignment_id_fkey FOREIGN KEY (assignment_id) REFERENCES public.job_assignments(id) ON DELETE RESTRICT;


--
-- Name: stripe_payment_intents stripe_payment_intents_payee_id_fkey; Type: FK CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.stripe_payment_intents
    ADD CONSTRAINT stripe_payment_intents_payee_id_fkey FOREIGN KEY (payee_id) REFERENCES auth.users(id) ON DELETE RESTRICT;


--
-- Name: stripe_payment_intents stripe_payment_intents_payer_id_fkey; Type: FK CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.stripe_payment_intents
    ADD CONSTRAINT stripe_payment_intents_payer_id_fkey FOREIGN KEY (payer_id) REFERENCES auth.users(id) ON DELETE RESTRICT;


--
-- Name: user_roles user_roles_granted_by_fkey; Type: FK CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.user_roles
    ADD CONSTRAINT user_roles_granted_by_fkey FOREIGN KEY (granted_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: user_roles user_roles_user_id_fkey; Type: FK CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.user_roles
    ADD CONSTRAINT user_roles_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: verification_provider_results verification_provider_results_user_id_fkey; Type: FK CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.verification_provider_results
    ADD CONSTRAINT verification_provider_results_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: verification_provider_results verification_provider_results_verification_case_id_fkey; Type: FK CONSTRAINT; Schema: private; Owner: -
--

ALTER TABLE ONLY private.verification_provider_results
    ADD CONSTRAINT verification_provider_results_verification_case_id_fkey FOREIGN KEY (verification_case_id) REFERENCES public.verification_cases(id) ON DELETE CASCADE;


--
-- Name: admin_audit_log admin_audit_log_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_audit_log
    ADD CONSTRAINT admin_audit_log_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: application_status_events application_status_events_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.application_status_events
    ADD CONSTRAINT application_status_events_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: application_status_events application_status_events_application_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.application_status_events
    ADD CONSTRAINT application_status_events_application_id_fkey FOREIGN KEY (application_id) REFERENCES public.job_applications(id) ON DELETE CASCADE;


--
-- Name: consents consents_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consents
    ADD CONSTRAINT consents_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: conversation_members conversation_members_conversation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation_members
    ADD CONSTRAINT conversation_members_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.conversations(id) ON DELETE CASCADE;


--
-- Name: conversation_members conversation_members_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation_members
    ADD CONSTRAINT conversation_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: conversations conversations_assignment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_assignment_id_fkey FOREIGN KEY (assignment_id) REFERENCES public.job_assignments(id) ON DELETE SET NULL;


--
-- Name: conversations conversations_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id) ON DELETE SET NULL;


--
-- Name: disputes disputes_assigned_to_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.disputes
    ADD CONSTRAINT disputes_assigned_to_fkey FOREIGN KEY (assigned_to) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: disputes disputes_assignment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.disputes
    ADD CONSTRAINT disputes_assignment_id_fkey FOREIGN KEY (assignment_id) REFERENCES public.job_assignments(id) ON DELETE RESTRICT;


--
-- Name: disputes disputes_opened_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.disputes
    ADD CONSTRAINT disputes_opened_by_fkey FOREIGN KEY (opened_by) REFERENCES public.profiles(id) ON DELETE RESTRICT;


--
-- Name: evidence_files evidence_files_assignment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evidence_files
    ADD CONSTRAINT evidence_files_assignment_id_fkey FOREIGN KEY (assignment_id) REFERENCES public.job_assignments(id) ON DELETE CASCADE;


--
-- Name: evidence_files evidence_files_dispute_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evidence_files
    ADD CONSTRAINT evidence_files_dispute_id_fkey FOREIGN KEY (dispute_id) REFERENCES public.disputes(id) ON DELETE CASCADE;


--
-- Name: evidence_files evidence_files_report_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evidence_files
    ADD CONSTRAINT evidence_files_report_id_fkey FOREIGN KEY (report_id) REFERENCES public.safety_reports(id) ON DELETE CASCADE;


--
-- Name: evidence_files evidence_files_uploaded_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evidence_files
    ADD CONSTRAINT evidence_files_uploaded_by_fkey FOREIGN KEY (uploaded_by) REFERENCES public.profiles(id) ON DELETE RESTRICT;


--
-- Name: guardian_links guardian_links_guardian_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guardian_links
    ADD CONSTRAINT guardian_links_guardian_user_id_fkey FOREIGN KEY (guardian_user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: guardian_links guardian_links_initiated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guardian_links
    ADD CONSTRAINT guardian_links_initiated_by_fkey FOREIGN KEY (initiated_by) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: guardian_links guardian_links_revoked_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guardian_links
    ADD CONSTRAINT guardian_links_revoked_by_fkey FOREIGN KEY (revoked_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: guardian_links guardian_links_teen_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guardian_links
    ADD CONSTRAINT guardian_links_teen_user_id_fkey FOREIGN KEY (teen_user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: guardian_preferences guardian_preferences_link_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guardian_preferences
    ADD CONSTRAINT guardian_preferences_link_id_fkey FOREIGN KEY (link_id) REFERENCES public.guardian_links(id) ON DELETE CASCADE;


--
-- Name: job_applications job_applications_applicant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_applications
    ADD CONSTRAINT job_applications_applicant_id_fkey FOREIGN KEY (applicant_id) REFERENCES public.profiles(id) ON DELETE RESTRICT;


--
-- Name: job_applications job_applications_guardian_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_applications
    ADD CONSTRAINT job_applications_guardian_id_fkey FOREIGN KEY (guardian_id) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: job_applications job_applications_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_applications
    ADD CONSTRAINT job_applications_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id) ON DELETE RESTRICT;


--
-- Name: job_assignments job_assignments_adult_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_assignments
    ADD CONSTRAINT job_assignments_adult_user_id_fkey FOREIGN KEY (adult_user_id) REFERENCES public.profiles(id) ON DELETE RESTRICT;


--
-- Name: job_assignments job_assignments_application_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_assignments
    ADD CONSTRAINT job_assignments_application_id_fkey FOREIGN KEY (application_id) REFERENCES public.job_applications(id) ON DELETE RESTRICT;


--
-- Name: job_assignments job_assignments_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_assignments
    ADD CONSTRAINT job_assignments_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id) ON DELETE RESTRICT;


--
-- Name: job_assignments job_assignments_teen_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_assignments
    ADD CONSTRAINT job_assignments_teen_user_id_fkey FOREIGN KEY (teen_user_id) REFERENCES public.profiles(id) ON DELETE RESTRICT;


--
-- Name: job_contract_acceptances job_contract_acceptances_contract_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_contract_acceptances
    ADD CONSTRAINT job_contract_acceptances_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES public.job_contracts(id) ON DELETE RESTRICT;


--
-- Name: job_contract_acceptances job_contract_acceptances_contract_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_contract_acceptances
    ADD CONSTRAINT job_contract_acceptances_contract_version_id_fkey FOREIGN KEY (contract_version_id) REFERENCES public.job_contract_versions(id) ON DELETE RESTRICT;


--
-- Name: job_contract_acceptances job_contract_acceptances_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_contract_acceptances
    ADD CONSTRAINT job_contract_acceptances_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE RESTRICT;


--
-- Name: job_contract_change_acceptances job_contract_change_acceptances_change_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_contract_change_acceptances
    ADD CONSTRAINT job_contract_change_acceptances_change_request_id_fkey FOREIGN KEY (change_request_id) REFERENCES public.job_contract_change_requests(id) ON DELETE RESTRICT;


--
-- Name: job_contract_change_acceptances job_contract_change_acceptances_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_contract_change_acceptances
    ADD CONSTRAINT job_contract_change_acceptances_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE RESTRICT;


--
-- Name: job_contract_change_requests job_contract_change_requests_base_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_contract_change_requests
    ADD CONSTRAINT job_contract_change_requests_base_version_id_fkey FOREIGN KEY (base_version_id) REFERENCES public.job_contract_versions(id) ON DELETE RESTRICT;


--
-- Name: job_contract_change_requests job_contract_change_requests_contract_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_contract_change_requests
    ADD CONSTRAINT job_contract_change_requests_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES public.job_contracts(id) ON DELETE RESTRICT;


--
-- Name: job_contract_change_requests job_contract_change_requests_created_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_contract_change_requests
    ADD CONSTRAINT job_contract_change_requests_created_version_id_fkey FOREIGN KEY (created_version_id) REFERENCES public.job_contract_versions(id) ON DELETE RESTRICT;


--
-- Name: job_contract_change_requests job_contract_change_requests_requested_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_contract_change_requests
    ADD CONSTRAINT job_contract_change_requests_requested_by_fkey FOREIGN KEY (requested_by) REFERENCES public.profiles(id) ON DELETE RESTRICT;


--
-- Name: job_contract_versions job_contract_versions_contract_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_contract_versions
    ADD CONSTRAINT job_contract_versions_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES public.job_contracts(id) ON DELETE RESTRICT;


--
-- Name: job_contract_versions job_contract_versions_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_contract_versions
    ADD CONSTRAINT job_contract_versions_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id) ON DELETE RESTRICT;


--
-- Name: job_contracts job_contracts_active_version_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_contracts
    ADD CONSTRAINT job_contracts_active_version_fkey FOREIGN KEY (active_version_id) REFERENCES public.job_contract_versions(id) ON DELETE RESTRICT;


--
-- Name: job_contracts job_contracts_adult_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_contracts
    ADD CONSTRAINT job_contracts_adult_id_fkey FOREIGN KEY (adult_id) REFERENCES public.profiles(id) ON DELETE RESTRICT;


--
-- Name: job_contracts job_contracts_application_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_contracts
    ADD CONSTRAINT job_contracts_application_id_fkey FOREIGN KEY (application_id) REFERENCES public.job_applications(id) ON DELETE RESTRICT;


--
-- Name: job_contracts job_contracts_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_contracts
    ADD CONSTRAINT job_contracts_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id) ON DELETE RESTRICT;


--
-- Name: job_contracts job_contracts_teen_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_contracts
    ADD CONSTRAINT job_contracts_teen_id_fkey FOREIGN KEY (teen_id) REFERENCES public.profiles(id) ON DELETE RESTRICT;


--
-- Name: job_execution_review_responses job_execution_review_responses_assignment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_execution_review_responses
    ADD CONSTRAINT job_execution_review_responses_assignment_id_fkey FOREIGN KEY (assignment_id) REFERENCES public.job_assignments(id) ON DELETE RESTRICT;


--
-- Name: job_execution_review_responses job_execution_review_responses_dispute_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_execution_review_responses
    ADD CONSTRAINT job_execution_review_responses_dispute_id_fkey FOREIGN KEY (dispute_id) REFERENCES public.disputes(id) ON DELETE RESTRICT;


--
-- Name: job_execution_review_responses job_execution_review_responses_responded_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_execution_review_responses
    ADD CONSTRAINT job_execution_review_responses_responded_by_fkey FOREIGN KEY (responded_by) REFERENCES public.profiles(id) ON DELETE RESTRICT;


--
-- Name: job_interests job_interests_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_interests
    ADD CONSTRAINT job_interests_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id) ON DELETE CASCADE;


--
-- Name: job_interests job_interests_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_interests
    ADD CONSTRAINT job_interests_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: job_safety_agreements job_safety_agreements_adult_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_safety_agreements
    ADD CONSTRAINT job_safety_agreements_adult_id_fkey FOREIGN KEY (adult_id) REFERENCES public.profiles(id) ON DELETE RESTRICT;


--
-- Name: job_safety_agreements job_safety_agreements_application_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_safety_agreements
    ADD CONSTRAINT job_safety_agreements_application_id_fkey FOREIGN KEY (application_id) REFERENCES public.job_applications(id) ON DELETE RESTRICT;


--
-- Name: job_safety_agreements job_safety_agreements_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_safety_agreements
    ADD CONSTRAINT job_safety_agreements_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id) ON DELETE RESTRICT;


--
-- Name: job_safety_agreements job_safety_agreements_teen_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_safety_agreements
    ADD CONSTRAINT job_safety_agreements_teen_id_fkey FOREIGN KEY (teen_id) REFERENCES public.profiles(id) ON DELETE RESTRICT;


--
-- Name: job_safety_cancellations job_safety_cancellations_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_safety_cancellations
    ADD CONSTRAINT job_safety_cancellations_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.profiles(id) ON DELETE RESTRICT;


--
-- Name: job_safety_cancellations job_safety_cancellations_application_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_safety_cancellations
    ADD CONSTRAINT job_safety_cancellations_application_id_fkey FOREIGN KEY (application_id) REFERENCES public.job_applications(id) ON DELETE RESTRICT;


--
-- Name: job_safety_cancellations job_safety_cancellations_assignment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_safety_cancellations
    ADD CONSTRAINT job_safety_cancellations_assignment_id_fkey FOREIGN KEY (assignment_id) REFERENCES public.job_assignments(id) ON DELETE RESTRICT;


--
-- Name: job_safety_cancellations job_safety_cancellations_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_safety_cancellations
    ADD CONSTRAINT job_safety_cancellations_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id) ON DELETE RESTRICT;


--
-- Name: job_safety_cancellations job_safety_cancellations_reported_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_safety_cancellations
    ADD CONSTRAINT job_safety_cancellations_reported_user_id_fkey FOREIGN KEY (reported_user_id) REFERENCES public.profiles(id) ON DELETE RESTRICT;


--
-- Name: job_safety_cancellations job_safety_cancellations_safety_report_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_safety_cancellations
    ADD CONSTRAINT job_safety_cancellations_safety_report_id_fkey FOREIGN KEY (safety_report_id) REFERENCES public.safety_reports(id) ON DELETE SET NULL;


--
-- Name: job_safety_checkins job_safety_checkins_adult_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_safety_checkins
    ADD CONSTRAINT job_safety_checkins_adult_user_id_fkey FOREIGN KEY (adult_user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: job_safety_checkins job_safety_checkins_application_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_safety_checkins
    ADD CONSTRAINT job_safety_checkins_application_id_fkey FOREIGN KEY (application_id) REFERENCES public.job_applications(id) ON DELETE CASCADE;


--
-- Name: job_safety_checkins job_safety_checkins_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_safety_checkins
    ADD CONSTRAINT job_safety_checkins_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id) ON DELETE CASCADE;


--
-- Name: job_safety_checkins job_safety_checkins_teen_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_safety_checkins
    ADD CONSTRAINT job_safety_checkins_teen_user_id_fkey FOREIGN KEY (teen_user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: job_safety_plans job_safety_plans_adult_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_safety_plans
    ADD CONSTRAINT job_safety_plans_adult_id_fkey FOREIGN KEY (adult_id) REFERENCES public.profiles(id) ON DELETE RESTRICT;


--
-- Name: job_safety_plans job_safety_plans_application_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_safety_plans
    ADD CONSTRAINT job_safety_plans_application_id_fkey FOREIGN KEY (application_id) REFERENCES public.job_applications(id) ON DELETE RESTRICT;


--
-- Name: job_safety_plans job_safety_plans_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_safety_plans
    ADD CONSTRAINT job_safety_plans_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id) ON DELETE RESTRICT;


--
-- Name: job_safety_plans job_safety_plans_teen_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_safety_plans
    ADD CONSTRAINT job_safety_plans_teen_id_fkey FOREIGN KEY (teen_id) REFERENCES public.profiles(id) ON DELETE RESTRICT;


--
-- Name: job_status_events job_status_events_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_status_events
    ADD CONSTRAINT job_status_events_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: job_status_events job_status_events_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_status_events
    ADD CONSTRAINT job_status_events_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id) ON DELETE CASCADE;


--
-- Name: jobs jobs_poster_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jobs
    ADD CONSTRAINT jobs_poster_id_fkey FOREIGN KEY (poster_id) REFERENCES public.profiles(id) ON DELETE RESTRICT;


--
-- Name: legal_acceptance_audit_events legal_acceptance_audit_events_acceptance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legal_acceptance_audit_events
    ADD CONSTRAINT legal_acceptance_audit_events_acceptance_id_fkey FOREIGN KEY (acceptance_id) REFERENCES public.legal_acceptances(id) ON DELETE RESTRICT;


--
-- Name: legal_acceptance_audit_events legal_acceptance_audit_events_document_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legal_acceptance_audit_events
    ADD CONSTRAINT legal_acceptance_audit_events_document_id_fkey FOREIGN KEY (document_id) REFERENCES public.legal_documents(id) ON DELETE RESTRICT;


--
-- Name: legal_acceptance_audit_events legal_acceptance_audit_events_document_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legal_acceptance_audit_events
    ADD CONSTRAINT legal_acceptance_audit_events_document_version_id_fkey FOREIGN KEY (document_version_id) REFERENCES public.legal_document_versions(id) ON DELETE RESTRICT;


--
-- Name: legal_acceptance_audit_events legal_acceptance_audit_events_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legal_acceptance_audit_events
    ADD CONSTRAINT legal_acceptance_audit_events_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE RESTRICT;


--
-- Name: legal_acceptances legal_acceptances_document_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legal_acceptances
    ADD CONSTRAINT legal_acceptances_document_id_fkey FOREIGN KEY (document_id) REFERENCES public.legal_documents(id) ON DELETE RESTRICT;


--
-- Name: legal_acceptances legal_acceptances_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legal_acceptances
    ADD CONSTRAINT legal_acceptances_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE RESTRICT;


--
-- Name: legal_acceptances legal_acceptances_version_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legal_acceptances
    ADD CONSTRAINT legal_acceptances_version_fk FOREIGN KEY (document_version_id, document_id, content_hash) REFERENCES public.legal_document_versions(id, document_id, content_hash) ON DELETE RESTRICT;


--
-- Name: legal_document_versions legal_document_versions_document_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legal_document_versions
    ADD CONSTRAINT legal_document_versions_document_id_fkey FOREIGN KEY (document_id) REFERENCES public.legal_documents(id) ON DELETE RESTRICT;


--
-- Name: legal_role_requirements legal_role_requirements_document_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legal_role_requirements
    ADD CONSTRAINT legal_role_requirements_document_id_fkey FOREIGN KEY (document_id) REFERENCES public.legal_documents(id) ON DELETE RESTRICT;


--
-- Name: messages messages_conversation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.conversations(id) ON DELETE CASCADE;


--
-- Name: messages messages_sender_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.profiles(id) ON DELETE RESTRICT;


--
-- Name: notification_preferences notification_preferences_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_preferences
    ADD CONSTRAINT notification_preferences_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: notifications notifications_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: payment_records payment_records_assignment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_records
    ADD CONSTRAINT payment_records_assignment_id_fkey FOREIGN KEY (assignment_id) REFERENCES public.job_assignments(id) ON DELETE RESTRICT;


--
-- Name: payment_records payment_records_payee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_records
    ADD CONSTRAINT payment_records_payee_id_fkey FOREIGN KEY (payee_id) REFERENCES public.profiles(id) ON DELETE RESTRICT;


--
-- Name: payment_records payment_records_payer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_records
    ADD CONSTRAINT payment_records_payer_id_fkey FOREIGN KEY (payer_id) REFERENCES public.profiles(id) ON DELETE RESTRICT;


--
-- Name: profiles profiles_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: proof_uploads proof_uploads_application_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.proof_uploads
    ADD CONSTRAINT proof_uploads_application_id_fkey FOREIGN KEY (application_id) REFERENCES public.job_applications(id) ON DELETE RESTRICT;


--
-- Name: proof_uploads proof_uploads_assignment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.proof_uploads
    ADD CONSTRAINT proof_uploads_assignment_id_fkey FOREIGN KEY (assignment_id) REFERENCES public.job_assignments(id) ON DELETE RESTRICT;


--
-- Name: proof_uploads proof_uploads_reviewed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.proof_uploads
    ADD CONSTRAINT proof_uploads_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES public.profiles(id) ON DELETE RESTRICT;


--
-- Name: proof_uploads proof_uploads_uploaded_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.proof_uploads
    ADD CONSTRAINT proof_uploads_uploaded_by_fkey FOREIGN KEY (uploaded_by) REFERENCES public.profiles(id) ON DELETE RESTRICT;


--
-- Name: reviews reviews_application_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_application_id_fkey FOREIGN KEY (application_id) REFERENCES public.job_applications(id) ON DELETE RESTRICT;


--
-- Name: reviews reviews_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id) ON DELETE RESTRICT;


--
-- Name: reviews reviews_reviewer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_reviewer_id_fkey FOREIGN KEY (reviewer_id) REFERENCES public.profiles(id) ON DELETE RESTRICT;


--
-- Name: reviews reviews_subject_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES public.profiles(id) ON DELETE RESTRICT;


--
-- Name: role_requests role_requests_reviewed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_requests
    ADD CONSTRAINT role_requests_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: role_requests role_requests_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_requests
    ADD CONSTRAINT role_requests_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: safety_pings safety_pings_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.safety_pings
    ADD CONSTRAINT safety_pings_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id) ON DELETE SET NULL;


--
-- Name: safety_pings safety_pings_teen_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.safety_pings
    ADD CONSTRAINT safety_pings_teen_id_fkey FOREIGN KEY (teen_id) REFERENCES public.profiles(id) ON DELETE RESTRICT;


--
-- Name: safety_reports safety_reports_application_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.safety_reports
    ADD CONSTRAINT safety_reports_application_id_fkey FOREIGN KEY (application_id) REFERENCES public.job_applications(id) ON DELETE SET NULL;


--
-- Name: safety_reports safety_reports_assigned_to_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.safety_reports
    ADD CONSTRAINT safety_reports_assigned_to_fkey FOREIGN KEY (assigned_to) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: safety_reports safety_reports_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.safety_reports
    ADD CONSTRAINT safety_reports_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id) ON DELETE SET NULL;


--
-- Name: safety_reports safety_reports_message_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.safety_reports
    ADD CONSTRAINT safety_reports_message_id_fkey FOREIGN KEY (message_id) REFERENCES public.messages(id) ON DELETE SET NULL;


--
-- Name: safety_reports safety_reports_reported_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.safety_reports
    ADD CONSTRAINT safety_reports_reported_user_id_fkey FOREIGN KEY (reported_user_id) REFERENCES public.profiles(id) ON DELETE RESTRICT;


--
-- Name: safety_reports safety_reports_reporter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.safety_reports
    ADD CONSTRAINT safety_reports_reporter_id_fkey FOREIGN KEY (reporter_id) REFERENCES public.profiles(id) ON DELETE RESTRICT;


--
-- Name: saved_jobs saved_jobs_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_jobs
    ADD CONSTRAINT saved_jobs_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id) ON DELETE CASCADE;


--
-- Name: saved_jobs saved_jobs_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_jobs
    ADD CONSTRAINT saved_jobs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: team_hustle_members team_hustle_members_hustle_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_hustle_members
    ADD CONSTRAINT team_hustle_members_hustle_id_fkey FOREIGN KEY (hustle_id) REFERENCES public.team_hustles(id) ON DELETE CASCADE;


--
-- Name: team_hustle_members team_hustle_members_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_hustle_members
    ADD CONSTRAINT team_hustle_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: team_hustles team_hustles_poster_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_hustles
    ADD CONSTRAINT team_hustles_poster_id_fkey FOREIGN KEY (poster_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: user_blocks user_blocks_blocked_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_blocks
    ADD CONSTRAINT user_blocks_blocked_id_fkey FOREIGN KEY (blocked_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: user_blocks user_blocks_blocker_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_blocks
    ADD CONSTRAINT user_blocks_blocker_id_fkey FOREIGN KEY (blocker_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: verification_cases verification_cases_reviewer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.verification_cases
    ADD CONSTRAINT verification_cases_reviewer_id_fkey FOREIGN KEY (reviewer_id) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: verification_cases verification_cases_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.verification_cases
    ADD CONSTRAINT verification_cases_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: guardian_invite_accept_limits; Type: ROW SECURITY; Schema: private; Owner: -
--

ALTER TABLE private.guardian_invite_accept_limits ENABLE ROW LEVEL SECURITY;

--
-- Name: guardian_invite_codes; Type: ROW SECURITY; Schema: private; Owner: -
--

ALTER TABLE private.guardian_invite_codes ENABLE ROW LEVEL SECURITY;

--
-- Name: job_execution_events; Type: ROW SECURITY; Schema: private; Owner: -
--

ALTER TABLE private.job_execution_events ENABLE ROW LEVEL SECURITY;

--
-- Name: job_execution_sessions; Type: ROW SECURITY; Schema: private; Owner: -
--

ALTER TABLE private.job_execution_sessions ENABLE ROW LEVEL SECURITY;

--
-- Name: job_pin_confirmation_requests; Type: ROW SECURITY; Schema: private; Owner: -
--

ALTER TABLE private.job_pin_confirmation_requests ENABLE ROW LEVEL SECURITY;

--
-- Name: job_private_location_access_events; Type: ROW SECURITY; Schema: private; Owner: -
--

ALTER TABLE private.job_private_location_access_events ENABLE ROW LEVEL SECURITY;

--
-- Name: job_private_location_history; Type: ROW SECURITY; Schema: private; Owner: -
--

ALTER TABLE private.job_private_location_history ENABLE ROW LEVEL SECURITY;

--
-- Name: job_private_location_requests; Type: ROW SECURITY; Schema: private; Owner: -
--

ALTER TABLE private.job_private_location_requests ENABLE ROW LEVEL SECURITY;

--
-- Name: job_private_locations; Type: ROW SECURITY; Schema: private; Owner: -
--

ALTER TABLE private.job_private_locations ENABLE ROW LEVEL SECURITY;

--
-- Name: job_safety_agreement_history; Type: ROW SECURITY; Schema: private; Owner: -
--

ALTER TABLE private.job_safety_agreement_history ENABLE ROW LEVEL SECURITY;

--
-- Name: mort_edge_action_limits; Type: ROW SECURITY; Schema: private; Owner: -
--

ALTER TABLE private.mort_edge_action_limits ENABLE ROW LEVEL SECURITY;

--
-- Name: mort_job_mutation_requests; Type: ROW SECURITY; Schema: private; Owner: -
--

ALTER TABLE private.mort_job_mutation_requests ENABLE ROW LEVEL SECURITY;

--
-- Name: mort_onboarding_safety; Type: ROW SECURITY; Schema: private; Owner: -
--

ALTER TABLE private.mort_onboarding_safety ENABLE ROW LEVEL SECURITY;

--
-- Name: school_email_domains; Type: ROW SECURITY; Schema: private; Owner: -
--

ALTER TABLE private.school_email_domains ENABLE ROW LEVEL SECURITY;

--
-- Name: stripe_connected_accounts; Type: ROW SECURITY; Schema: private; Owner: -
--

ALTER TABLE private.stripe_connected_accounts ENABLE ROW LEVEL SECURITY;

--
-- Name: stripe_customers; Type: ROW SECURITY; Schema: private; Owner: -
--

ALTER TABLE private.stripe_customers ENABLE ROW LEVEL SECURITY;

--
-- Name: stripe_payment_intents; Type: ROW SECURITY; Schema: private; Owner: -
--

ALTER TABLE private.stripe_payment_intents ENABLE ROW LEVEL SECURITY;

--
-- Name: stripe_runtime_controls; Type: ROW SECURITY; Schema: private; Owner: -
--

ALTER TABLE private.stripe_runtime_controls ENABLE ROW LEVEL SECURITY;

--
-- Name: stripe_webhook_events; Type: ROW SECURITY; Schema: private; Owner: -
--

ALTER TABLE private.stripe_webhook_events ENABLE ROW LEVEL SECURITY;

--
-- Name: user_roles; Type: ROW SECURITY; Schema: private; Owner: -
--

ALTER TABLE private.user_roles ENABLE ROW LEVEL SECURITY;

--
-- Name: verification_provider_allowlist; Type: ROW SECURITY; Schema: private; Owner: -
--

ALTER TABLE private.verification_provider_allowlist ENABLE ROW LEVEL SECURITY;

--
-- Name: verification_provider_ingestion_keys; Type: ROW SECURITY; Schema: private; Owner: -
--

ALTER TABLE private.verification_provider_ingestion_keys ENABLE ROW LEVEL SECURITY;

--
-- Name: verification_provider_results; Type: ROW SECURITY; Schema: private; Owner: -
--

ALTER TABLE private.verification_provider_results ENABLE ROW LEVEL SECURITY;

--
-- Name: admin_audit_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.admin_audit_log ENABLE ROW LEVEL SECURITY;

--
-- Name: application_status_events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.application_status_events ENABLE ROW LEVEL SECURITY;

--
-- Name: application_status_events application_status_events_select_participant; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY application_status_events_select_participant ON public.application_status_events FOR SELECT TO authenticated USING (private.can_access_application_status_events(application_id));


--
-- Name: job_applications applications_insert_teen; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY applications_insert_teen ON public.job_applications FOR INSERT TO authenticated WITH CHECK (((applicant_id = ( SELECT auth.uid() AS uid)) AND (private."current_role"() = 'teen'::public.mort_role) AND private.is_active_user() AND (status = 'submitted'::public.mort_application_status) AND (EXISTS ( SELECT 1
   FROM public.jobs j
  WHERE ((j.id = job_applications.job_id) AND (j.status = 'open'::public.mort_job_status) AND (j.safety_review_status = 'approved'::text) AND (j.poster_id <> ( SELECT auth.uid() AS uid)))))));


--
-- Name: job_assignments assignments_select_parties; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY assignments_select_parties ON public.job_assignments FOR SELECT TO authenticated USING (((teen_user_id = ( SELECT auth.uid() AS uid)) OR (adult_user_id = ( SELECT auth.uid() AS uid)) OR private.has_staff_role(ARRAY['admin'::public.mort_role, 'moderator'::public.mort_role])));


--
-- Name: admin_audit_log audit_select_staff; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY audit_select_staff ON public.admin_audit_log FOR SELECT TO authenticated USING (private.has_staff_role(ARRAY['admin'::public.mort_role, 'moderator'::public.mort_role]));


--
-- Name: reviews blind_review_reveal; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY blind_review_reveal ON public.reviews FOR SELECT TO authenticated USING (((reviewer_id = ( SELECT auth.uid() AS uid)) OR ((subject_id = ( SELECT auth.uid() AS uid)) AND (moderation_status = 'approved'::text) AND ((revealed_at IS NOT NULL) OR (created_at <= (now() - '14 days'::interval))))));


--
-- Name: user_blocks blocks_delete_self; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY blocks_delete_self ON public.user_blocks FOR DELETE TO authenticated USING ((blocker_id = ( SELECT auth.uid() AS uid)));


--
-- Name: user_blocks blocks_insert_self; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY blocks_insert_self ON public.user_blocks FOR INSERT TO authenticated WITH CHECK ((blocker_id = ( SELECT auth.uid() AS uid)));


--
-- Name: user_blocks blocks_select_participant; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY blocks_select_participant ON public.user_blocks FOR SELECT TO authenticated USING (((blocker_id = ( SELECT auth.uid() AS uid)) OR (blocked_id = ( SELECT auth.uid() AS uid))));


--
-- Name: consents; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.consents ENABLE ROW LEVEL SECURITY;

--
-- Name: consents consents_insert_self; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY consents_insert_self ON public.consents FOR INSERT TO authenticated WITH CHECK ((user_id = ( SELECT auth.uid() AS uid)));


--
-- Name: consents consents_select_self_or_staff; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY consents_select_self_or_staff ON public.consents FOR SELECT TO authenticated USING (((user_id = ( SELECT auth.uid() AS uid)) OR private.has_staff_role(ARRAY['admin'::public.mort_role, 'moderator'::public.mort_role])));


--
-- Name: conversation_members; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.conversation_members ENABLE ROW LEVEL SECURITY;

--
-- Name: conversations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;

--
-- Name: conversations conversations_select_member_or_staff; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY conversations_select_member_or_staff ON public.conversations FOR SELECT TO authenticated USING ((private.can_access_conversation(id) OR private.has_staff_role(ARRAY['admin'::public.mort_role, 'moderator'::public.mort_role])));


--
-- Name: job_safety_cancellations deny_all_api_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY deny_all_api_access ON public.job_safety_cancellations TO authenticated, anon USING (false) WITH CHECK (false);


--
-- Name: legal_acceptance_audit_events deny_all_api_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY deny_all_api_access ON public.legal_acceptance_audit_events TO authenticated, anon USING (false) WITH CHECK (false);


--
-- Name: legal_role_requirements deny_all_api_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY deny_all_api_access ON public.legal_role_requirements TO authenticated, anon USING (false) WITH CHECK (false);


--
-- Name: team_hustle_members deny_all_api_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY deny_all_api_access ON public.team_hustle_members TO authenticated, anon USING (false) WITH CHECK (false);


--
-- Name: disputes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.disputes ENABLE ROW LEVEL SECURITY;

--
-- Name: disputes disputes_insert_assignment_participant; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY disputes_insert_assignment_participant ON public.disputes FOR INSERT TO authenticated WITH CHECK (((opened_by = ( SELECT auth.uid() AS uid)) AND private.can_access_assignment(assignment_id) AND (status = 'open'::text) AND (assigned_to IS NULL)));


--
-- Name: disputes disputes_select_participant_or_staff; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY disputes_select_participant_or_staff ON public.disputes FOR SELECT TO authenticated USING (((opened_by = ( SELECT auth.uid() AS uid)) OR private.can_access_assignment(assignment_id) OR private.has_staff_role(ARRAY['admin'::public.mort_role, 'moderator'::public.mort_role])));


--
-- Name: evidence_files; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.evidence_files ENABLE ROW LEVEL SECURITY;

--
-- Name: evidence_files evidence_select_authorized; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY evidence_select_authorized ON public.evidence_files FOR SELECT TO authenticated USING (((uploaded_by = ( SELECT auth.uid() AS uid)) OR ((visibility <> 'staff_only'::text) AND (assignment_id IS NOT NULL) AND private.can_access_assignment(assignment_id)) OR private.has_staff_role(ARRAY['admin'::public.mort_role, 'moderator'::public.mort_role])));


--
-- Name: guardian_links; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.guardian_links ENABLE ROW LEVEL SECURITY;

--
-- Name: guardian_links guardian_links_select_participants_or_staff; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY guardian_links_select_participants_or_staff ON public.guardian_links FOR SELECT TO authenticated USING (((teen_user_id = ( SELECT auth.uid() AS uid)) OR ((guardian_user_id = ( SELECT auth.uid() AS uid)) AND (EXISTS ( SELECT 1
   FROM public.profiles guardian_profile
  WHERE ((guardian_profile.id = ( SELECT auth.uid() AS uid)) AND (guardian_profile.role = 'guardian'::public.mort_role) AND (guardian_profile.account_status = 'active'::text) AND (guardian_profile.date_of_birth IS NOT NULL) AND (EXTRACT(year FROM age((CURRENT_DATE)::timestamp with time zone, (guardian_profile.date_of_birth)::timestamp with time zone)) >= (18)::numeric))))) OR private.has_staff_role(ARRAY['admin'::public.mort_role, 'moderator'::public.mort_role])));


--
-- Name: guardian_preferences; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.guardian_preferences ENABLE ROW LEVEL SECURITY;

--
-- Name: guardian_preferences guardian_preferences_select_participants; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY guardian_preferences_select_participants ON public.guardian_preferences FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.guardian_links link
  WHERE ((link.id = guardian_preferences.link_id) AND (link.status = 'active'::text) AND ((link.teen_user_id = ( SELECT auth.uid() AS uid)) OR ((link.guardian_user_id = ( SELECT auth.uid() AS uid)) AND (EXISTS ( SELECT 1
           FROM public.profiles guardian_profile
          WHERE ((guardian_profile.id = ( SELECT auth.uid() AS uid)) AND (guardian_profile.role = 'guardian'::public.mort_role) AND (guardian_profile.account_status = 'active'::text) AND (guardian_profile.date_of_birth IS NOT NULL) AND (EXTRACT(year FROM age((CURRENT_DATE)::timestamp with time zone, (guardian_profile.date_of_birth)::timestamp with time zone)) >= (18)::numeric))))))))));


--
-- Name: profiles guardian_reads_linked_teen_profiles; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY guardian_reads_linked_teen_profiles ON public.profiles FOR SELECT TO authenticated USING (private.is_fully_consented_guardian(id));


--
-- Name: job_applications; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.job_applications ENABLE ROW LEVEL SECURITY;

--
-- Name: job_assignments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.job_assignments ENABLE ROW LEVEL SECURITY;

--
-- Name: job_contract_acceptances; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.job_contract_acceptances ENABLE ROW LEVEL SECURITY;

--
-- Name: job_contract_acceptances job_contract_acceptances_parties_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY job_contract_acceptances_parties_read ON public.job_contract_acceptances FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.job_contracts contract
  WHERE ((contract.id = job_contract_acceptances.contract_id) AND ((( SELECT auth.uid() AS uid) = contract.teen_id) OR (( SELECT auth.uid() AS uid) = contract.adult_id))))));


--
-- Name: job_contract_change_acceptances; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.job_contract_change_acceptances ENABLE ROW LEVEL SECURITY;

--
-- Name: job_contract_change_requests; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.job_contract_change_requests ENABLE ROW LEVEL SECURITY;

--
-- Name: job_contract_change_acceptances job_contract_change_responses_parties_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY job_contract_change_responses_parties_read ON public.job_contract_change_acceptances FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM (public.job_contract_change_requests request
     JOIN public.job_contracts contract ON ((contract.id = request.contract_id)))
  WHERE ((request.id = job_contract_change_acceptances.change_request_id) AND ((( SELECT auth.uid() AS uid) = contract.teen_id) OR (( SELECT auth.uid() AS uid) = contract.adult_id))))));


--
-- Name: job_contract_change_requests job_contract_changes_parties_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY job_contract_changes_parties_read ON public.job_contract_change_requests FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.job_contracts contract
  WHERE ((contract.id = job_contract_change_requests.contract_id) AND ((( SELECT auth.uid() AS uid) = contract.teen_id) OR (( SELECT auth.uid() AS uid) = contract.adult_id))))));


--
-- Name: job_contracts job_contract_parties_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY job_contract_parties_read ON public.job_contracts FOR SELECT TO authenticated USING (((( SELECT auth.uid() AS uid) = teen_id) OR (( SELECT auth.uid() AS uid) = adult_id)));


--
-- Name: job_contract_versions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.job_contract_versions ENABLE ROW LEVEL SECURITY;

--
-- Name: job_contract_versions job_contract_versions_parties_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY job_contract_versions_parties_read ON public.job_contract_versions FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.job_contracts contract
  WHERE ((contract.id = job_contract_versions.contract_id) AND ((( SELECT auth.uid() AS uid) = contract.teen_id) OR (( SELECT auth.uid() AS uid) = contract.adult_id))))));


--
-- Name: job_contracts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.job_contracts ENABLE ROW LEVEL SECURITY;

--
-- Name: job_execution_review_responses; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.job_execution_review_responses ENABLE ROW LEVEL SECURITY;

--
-- Name: job_execution_review_responses job_execution_review_responses_participants_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY job_execution_review_responses_participants_read ON public.job_execution_review_responses FOR SELECT TO authenticated USING ((private.can_access_assignment(assignment_id) OR private.has_staff_role(ARRAY['admin'::public.mort_role, 'moderator'::public.mort_role])));


--
-- Name: job_interests; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.job_interests ENABLE ROW LEVEL SECURITY;

--
-- Name: job_interests job_interests_owner_teen_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY job_interests_owner_teen_only ON public.job_interests TO authenticated USING (((user_id = ( SELECT auth.uid() AS uid)) AND (( SELECT private."current_role"() AS "current_role") = 'teen'::public.mort_role) AND ( SELECT private.is_active_user() AS is_active_user))) WITH CHECK (((user_id = ( SELECT auth.uid() AS uid)) AND (( SELECT private."current_role"() AS "current_role") = 'teen'::public.mort_role) AND ( SELECT private.is_active_user() AS is_active_user)));


--
-- Name: job_safety_agreements job_safety_agreement_participants_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY job_safety_agreement_participants_read ON public.job_safety_agreements FOR SELECT TO authenticated USING (private.is_job_safety_participant(application_id, ( SELECT auth.uid() AS uid)));


--
-- Name: job_safety_agreements; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.job_safety_agreements ENABLE ROW LEVEL SECURITY;

--
-- Name: job_safety_cancellations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.job_safety_cancellations ENABLE ROW LEVEL SECURITY;

--
-- Name: job_safety_checkins; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.job_safety_checkins ENABLE ROW LEVEL SECURITY;

--
-- Name: job_safety_checkins job_safety_checkins_select_parties; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY job_safety_checkins_select_parties ON public.job_safety_checkins FOR SELECT TO authenticated USING (((teen_user_id = ( SELECT auth.uid() AS uid)) OR (adult_user_id = ( SELECT auth.uid() AS uid)) OR private.has_staff_role(ARRAY['admin'::public.mort_role, 'moderator'::public.mort_role])));


--
-- Name: job_safety_plans job_safety_plan_participants_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY job_safety_plan_participants_read ON public.job_safety_plans FOR SELECT TO authenticated USING (private.is_job_safety_participant(application_id, ( SELECT auth.uid() AS uid)));


--
-- Name: job_safety_plans; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.job_safety_plans ENABLE ROW LEVEL SECURITY;

--
-- Name: job_status_events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.job_status_events ENABLE ROW LEVEL SECURITY;

--
-- Name: job_status_events job_status_events_select_participant; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY job_status_events_select_participant ON public.job_status_events FOR SELECT TO authenticated USING (private.can_access_job_status_events(job_id));


--
-- Name: jobs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.jobs ENABLE ROW LEVEL SECURITY;

--
-- Name: jobs jobs_insert_adult; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY jobs_insert_adult ON public.jobs FOR INSERT TO authenticated WITH CHECK (((poster_id = ( SELECT auth.uid() AS uid)) AND (private."current_role"() = 'adult'::public.mort_role) AND private.is_active_user() AND (status = ANY (ARRAY['draft'::public.mort_job_status, 'open'::public.mort_job_status])) AND (safety_review_status = 'pending'::text)));


--
-- Name: jobs jobs_select_visible; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY jobs_select_visible ON public.jobs FOR SELECT TO authenticated USING (((poster_id = ( SELECT auth.uid() AS uid)) OR private.has_staff_role(ARRAY['admin'::public.mort_role, 'moderator'::public.mort_role]) OR ((status = 'open'::public.mort_job_status) AND (safety_review_status = 'approved'::text) AND private.is_active_user() AND (EXISTS ( SELECT 1
   FROM public.profiles poster
  WHERE ((poster.id = jobs.poster_id) AND (poster.account_status = 'active'::text)))))));


--
-- Name: jobs jobs_update_owner; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY jobs_update_owner ON public.jobs FOR UPDATE TO authenticated USING (((poster_id = ( SELECT auth.uid() AS uid)) AND (private."current_role"() = 'adult'::public.mort_role))) WITH CHECK (((poster_id = ( SELECT auth.uid() AS uid)) AND (private."current_role"() = 'adult'::public.mort_role) AND (safety_review_status = ANY (ARRAY['pending'::text, 'approved'::text, 'flagged'::text]))));


--
-- Name: legal_acceptance_audit_events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.legal_acceptance_audit_events ENABLE ROW LEVEL SECURITY;

--
-- Name: legal_acceptances; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.legal_acceptances ENABLE ROW LEVEL SECURITY;

--
-- Name: legal_acceptances legal_acceptances_owner_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY legal_acceptances_owner_select ON public.legal_acceptances FOR SELECT TO authenticated USING ((user_id = ( SELECT auth.uid() AS uid)));


--
-- Name: legal_document_versions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.legal_document_versions ENABLE ROW LEVEL SECURITY;

--
-- Name: legal_documents; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.legal_documents ENABLE ROW LEVEL SECURITY;

--
-- Name: legal_documents legal_documents_published_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY legal_documents_published_select ON public.legal_documents FOR SELECT TO authenticated USING ((publication_status = 'published'::text));


--
-- Name: legal_role_requirements; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.legal_role_requirements ENABLE ROW LEVEL SECURITY;

--
-- Name: legal_document_versions legal_versions_published_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY legal_versions_published_select ON public.legal_document_versions FOR SELECT TO authenticated USING (((publication_status = 'published'::text) AND (effective_at IS NOT NULL) AND (effective_at <= now()) AND (EXISTS ( SELECT 1
   FROM public.legal_documents document
  WHERE ((document.id = legal_document_versions.document_id) AND (document.publication_status = 'published'::text))))));


--
-- Name: conversation_members members_select_same_conversation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY members_select_same_conversation ON public.conversation_members FOR SELECT TO authenticated USING (((user_id = ( SELECT auth.uid() AS uid)) OR private.can_access_conversation(conversation_id) OR private.has_staff_role(ARRAY['admin'::public.mort_role, 'moderator'::public.mort_role])));


--
-- Name: messages; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

--
-- Name: messages messages_select_member; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY messages_select_member ON public.messages FOR SELECT TO authenticated USING ((private.can_access_conversation(conversation_id) AND ((deleted_at IS NULL) OR (sender_id = ( SELECT auth.uid() AS uid))) AND ((moderation_status = 'approved'::text) OR (sender_id = ( SELECT auth.uid() AS uid)))));


--
-- Name: mort_release_control; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.mort_release_control ENABLE ROW LEVEL SECURITY;

--
-- Name: mort_release_control mort_release_control_public_status_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY mort_release_control_public_status_read ON public.mort_release_control FOR SELECT TO authenticated, anon USING (is_primary);


--
-- Name: notification_preferences; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;

--
-- Name: notification_preferences notification_prefs_insert_self; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY notification_prefs_insert_self ON public.notification_preferences FOR INSERT TO authenticated WITH CHECK ((user_id = ( SELECT auth.uid() AS uid)));


--
-- Name: notification_preferences notification_prefs_select_self; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY notification_prefs_select_self ON public.notification_preferences FOR SELECT TO authenticated USING ((user_id = ( SELECT auth.uid() AS uid)));


--
-- Name: notification_preferences notification_prefs_update_self; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY notification_prefs_update_self ON public.notification_preferences FOR UPDATE TO authenticated USING ((user_id = ( SELECT auth.uid() AS uid))) WITH CHECK ((user_id = ( SELECT auth.uid() AS uid)));


--
-- Name: notifications; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

--
-- Name: notifications notifications_select_self; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY notifications_select_self ON public.notifications FOR SELECT TO authenticated USING ((user_id = ( SELECT auth.uid() AS uid)));


--
-- Name: notifications notifications_update_self; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY notifications_update_self ON public.notifications FOR UPDATE TO authenticated USING ((user_id = ( SELECT auth.uid() AS uid))) WITH CHECK ((user_id = ( SELECT auth.uid() AS uid)));


--
-- Name: payment_records; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.payment_records ENABLE ROW LEVEL SECURITY;

--
-- Name: payment_records payments_select_parties; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY payments_select_parties ON public.payment_records FOR SELECT TO authenticated USING (((payer_id = ( SELECT auth.uid() AS uid)) OR (payee_id = ( SELECT auth.uid() AS uid)) OR private.has_staff_role(ARRAY['admin'::public.mort_role, 'moderator'::public.mort_role])));


--
-- Name: profiles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

--
-- Name: profiles profiles_select_self_or_staff; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY profiles_select_self_or_staff ON public.profiles FOR SELECT TO authenticated USING (((id = ( SELECT auth.uid() AS uid)) OR private.has_staff_role(ARRAY['admin'::public.mort_role, 'moderator'::public.mort_role])));


--
-- Name: profiles profiles_update_self; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY profiles_update_self ON public.profiles FOR UPDATE TO authenticated USING ((id = ( SELECT auth.uid() AS uid))) WITH CHECK ((id = ( SELECT auth.uid() AS uid)));


--
-- Name: proof_uploads; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.proof_uploads ENABLE ROW LEVEL SECURITY;

--
-- Name: proof_uploads proof_uploads_participants_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY proof_uploads_participants_read ON public.proof_uploads FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.job_assignments assignment
  WHERE ((assignment.id = proof_uploads.assignment_id) AND ((( SELECT auth.uid() AS uid) = assignment.teen_user_id) OR (( SELECT auth.uid() AS uid) = assignment.adult_user_id))))));


--
-- Name: safety_reports reports_select_reporter_or_staff; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY reports_select_reporter_or_staff ON public.safety_reports FOR SELECT TO authenticated USING (((reporter_id = ( SELECT auth.uid() AS uid)) OR private.has_staff_role(ARRAY['admin'::public.mort_role, 'moderator'::public.mort_role])));


--
-- Name: reviews; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

--
-- Name: reviews reviews_insert_completed_assignment; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY reviews_insert_completed_assignment ON public.reviews FOR INSERT TO authenticated WITH CHECK (((reviewer_id = ( SELECT auth.uid() AS uid)) AND (body IS NULL) AND (moderation_status = 'approved'::text) AND (EXISTS ( SELECT 1
   FROM public.job_assignments ja
  WHERE ((ja.application_id = reviews.application_id) AND (ja.job_id = reviews.job_id) AND (ja.status = 'completed'::text) AND (ja.completed_by_teen_at IS NOT NULL) AND (ja.completed_by_adult_at IS NOT NULL) AND (((ja.teen_user_id = reviews.reviewer_id) AND (ja.adult_user_id = reviews.subject_id)) OR ((ja.adult_user_id = reviews.reviewer_id) AND (ja.teen_user_id = reviews.subject_id))))))));


--
-- Name: role_requests; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.role_requests ENABLE ROW LEVEL SECURITY;

--
-- Name: role_requests role_requests_insert_self; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY role_requests_insert_self ON public.role_requests FOR INSERT TO authenticated WITH CHECK (((user_id = ( SELECT auth.uid() AS uid)) AND (status = 'pending'::text) AND (reviewed_at IS NULL) AND (reviewed_by IS NULL)));


--
-- Name: role_requests role_requests_select_self_or_staff; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY role_requests_select_self_or_staff ON public.role_requests FOR SELECT TO authenticated USING (((user_id = ( SELECT auth.uid() AS uid)) OR private.has_staff_role(ARRAY['admin'::public.mort_role, 'moderator'::public.mort_role])));


--
-- Name: safety_pings; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.safety_pings ENABLE ROW LEVEL SECURITY;

--
-- Name: safety_pings safety_pings_select_authorized_parties; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY safety_pings_select_authorized_parties ON public.safety_pings FOR SELECT TO authenticated USING (((teen_id = ( SELECT auth.uid() AS uid)) OR (EXISTS ( SELECT 1
   FROM (public.guardian_links link
     LEFT JOIN public.guardian_preferences preferences ON ((preferences.link_id = link.id)))
  WHERE ((link.teen_user_id = safety_pings.teen_id) AND (link.guardian_user_id = ( SELECT auth.uid() AS uid)) AND (link.status = 'active'::text) AND COALESCE(preferences.safety_ping_alerts, true) AND (EXISTS ( SELECT 1
           FROM public.profiles guardian_profile
          WHERE ((guardian_profile.id = ( SELECT auth.uid() AS uid)) AND (guardian_profile.role = 'guardian'::public.mort_role) AND (guardian_profile.account_status = 'active'::text) AND (guardian_profile.date_of_birth IS NOT NULL) AND (EXTRACT(year FROM age((CURRENT_DATE)::timestamp with time zone, (guardian_profile.date_of_birth)::timestamp with time zone)) >= (18)::numeric))))))) OR private.has_staff_role(ARRAY['admin'::public.mort_role, 'moderator'::public.mort_role])));


--
-- Name: safety_reports; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.safety_reports ENABLE ROW LEVEL SECURITY;

--
-- Name: saved_jobs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.saved_jobs ENABLE ROW LEVEL SECURITY;

--
-- Name: saved_jobs saved_jobs_delete_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY saved_jobs_delete_own ON public.saved_jobs FOR DELETE TO authenticated USING ((user_id = ( SELECT auth.uid() AS uid)));


--
-- Name: saved_jobs saved_jobs_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY saved_jobs_insert_own ON public.saved_jobs FOR INSERT TO authenticated WITH CHECK (((user_id = ( SELECT auth.uid() AS uid)) AND (private."current_role"() = 'teen'::public.mort_role) AND private.is_active_user() AND (EXISTS ( SELECT 1
   FROM public.jobs job
  WHERE ((job.id = saved_jobs.job_id) AND (job.status = 'open'::public.mort_job_status) AND (job.safety_review_status = 'approved'::text) AND job.applications_open AND ((job.expires_at IS NULL) OR (job.expires_at > now())))))));


--
-- Name: saved_jobs saved_jobs_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY saved_jobs_select_own ON public.saved_jobs FOR SELECT TO authenticated USING ((user_id = ( SELECT auth.uid() AS uid)));


--
-- Name: team_hustle_members; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.team_hustle_members ENABLE ROW LEVEL SECURITY;

--
-- Name: team_hustles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.team_hustles ENABLE ROW LEVEL SECURITY;

--
-- Name: team_hustles team_hustles_select_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY team_hustles_select_authenticated ON public.team_hustles FOR SELECT TO authenticated USING (true);


--
-- Name: user_blocks; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_blocks ENABLE ROW LEVEL SECURITY;

--
-- Name: verification_cases; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.verification_cases ENABLE ROW LEVEL SECURITY;

--
-- Name: verification_cases verification_insert_owner; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY verification_insert_owner ON public.verification_cases FOR INSERT TO authenticated WITH CHECK (((user_id = ( SELECT auth.uid() AS uid)) AND (status = 'not_started'::public.mort_verification_status) AND (reviewer_id IS NULL) AND (reviewed_at IS NULL)));


--
-- Name: verification_cases verification_select_owner_or_staff; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY verification_select_owner_or_staff ON public.verification_cases FOR SELECT TO authenticated USING (((user_id = ( SELECT auth.uid() AS uid)) OR private.has_staff_role(ARRAY['admin'::public.mort_role, 'moderator'::public.mort_role])));


--
-- Name: SCHEMA private; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA private TO authenticated;
GRANT USAGE ON SCHEMA private TO service_role;


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA public TO postgres;
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO service_role;


--
-- Name: FUNCTION abort_application_proof_upload_internal(p_proof_id uuid, p_application_id uuid); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.abort_application_proof_upload_internal(p_proof_id uuid, p_application_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION private.abort_application_proof_upload_internal(p_proof_id uuid, p_application_id uuid) TO authenticated;


--
-- Name: FUNCTION archive_job_private_location_before_update(); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.archive_job_private_location_before_update() FROM PUBLIC;


--
-- Name: FUNCTION archive_job_safety_agreement_before_update(); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.archive_job_safety_agreement_before_update() FROM PUBLIC;


--
-- Name: FUNCTION audit_guardian_link_revocation(); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.audit_guardian_link_revocation() FROM PUBLIC;


--
-- Name: FUNCTION begin_application_proof_upload_internal(p_proof_id uuid, p_application_id uuid, p_storage_path text, p_note text); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.begin_application_proof_upload_internal(p_proof_id uuid, p_application_id uuid, p_storage_path text, p_note text) FROM PUBLIC;
GRANT ALL ON FUNCTION private.begin_application_proof_upload_internal(p_proof_id uuid, p_application_id uuid, p_storage_path text, p_note text) TO authenticated;


--
-- Name: FUNCTION can_access_application_status_events(p_application_id uuid); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.can_access_application_status_events(p_application_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION private.can_access_application_status_events(p_application_id uuid) TO authenticated;


--
-- Name: FUNCTION can_access_assignment(target_assignment uuid); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.can_access_assignment(target_assignment uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION private.can_access_assignment(target_assignment uuid) TO authenticated;


--
-- Name: FUNCTION can_access_conversation(target_conversation uuid); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.can_access_conversation(target_conversation uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION private.can_access_conversation(target_conversation uuid) TO authenticated;


--
-- Name: FUNCTION can_access_job_status_events(p_job_id uuid); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.can_access_job_status_events(p_job_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION private.can_access_job_status_events(p_job_id uuid) TO authenticated;


--
-- Name: FUNCTION capture_application_status_event(); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.capture_application_status_event() FROM PUBLIC;


--
-- Name: FUNCTION capture_job_status_event(); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.capture_job_status_event() FROM PUBLIC;


--
-- Name: FUNCTION complete_job_after_proof_internal(p_application_id uuid, p_proof_id uuid); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.complete_job_after_proof_internal(p_application_id uuid, p_proof_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION private.complete_job_after_proof_internal(p_application_id uuid, p_proof_id uuid) TO authenticated;


--
-- Name: FUNCTION confirm_job_finish_pin_internal(p_application_id uuid, p_pin text, p_client_request_id uuid); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.confirm_job_finish_pin_internal(p_application_id uuid, p_pin text, p_client_request_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION private.confirm_job_finish_pin_internal(p_application_id uuid, p_pin text, p_client_request_id uuid) TO authenticated;


--
-- Name: FUNCTION confirm_job_safety_agreement_internal(p_application_id uuid, p_agreement_version integer); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.confirm_job_safety_agreement_internal(p_application_id uuid, p_agreement_version integer) FROM PUBLIC;
GRANT ALL ON FUNCTION private.confirm_job_safety_agreement_internal(p_application_id uuid, p_agreement_version integer) TO authenticated;


--
-- Name: FUNCTION confirm_job_start_pin_internal(p_application_id uuid, p_pin text, p_person_matches_profile boolean, p_client_request_id uuid); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.confirm_job_start_pin_internal(p_application_id uuid, p_pin text, p_person_matches_profile boolean, p_client_request_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION private.confirm_job_start_pin_internal(p_application_id uuid, p_pin text, p_person_matches_profile boolean, p_client_request_id uuid) TO authenticated;


--
-- Name: FUNCTION create_job_contract_after_acceptance(); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.create_job_contract_after_acceptance() FROM PUBLIC;


--
-- Name: FUNCTION create_job_safety_agreement_after_acceptance(); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.create_job_safety_agreement_after_acceptance() FROM PUBLIC;


--
-- Name: FUNCTION "current_role"(); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private."current_role"() FROM PUBLIC;
GRANT ALL ON FUNCTION private."current_role"() TO authenticated;


--
-- Name: FUNCTION enforce_minor_school_email_on_auth_email_change(); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.enforce_minor_school_email_on_auth_email_change() FROM PUBLIC;


--
-- Name: FUNCTION enforce_profile_minimum_age(); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.enforce_profile_minimum_age() FROM PUBLIC;


--
-- Name: TABLE profiles; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.profiles TO service_role;
GRANT SELECT ON TABLE public.profiles TO authenticated;


--
-- Name: COLUMN profiles.display_name; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE(display_name) ON TABLE public.profiles TO authenticated;


--
-- Name: COLUMN profiles.avatar_path; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE(avatar_path) ON TABLE public.profiles TO authenticated;


--
-- Name: COLUMN profiles.bio; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE(bio) ON TABLE public.profiles TO authenticated;


--
-- Name: COLUMN profiles.city; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE(city) ON TABLE public.profiles TO authenticated;


--
-- Name: COLUMN profiles.region; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE(region) ON TABLE public.profiles TO authenticated;


--
-- Name: COLUMN profiles.timezone; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE(timezone) ON TABLE public.profiles TO authenticated;


--
-- Name: COLUMN profiles.username; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE(username) ON TABLE public.profiles TO authenticated;


--
-- Name: COLUMN profiles.location_setup_mode; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE(location_setup_mode) ON TABLE public.profiles TO authenticated;


--
-- Name: COLUMN profiles.approximate_area; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE(approximate_area) ON TABLE public.profiles TO authenticated;


--
-- Name: COLUMN profiles.availability; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE(availability) ON TABLE public.profiles TO authenticated;


--
-- Name: COLUMN profiles.preferred_job_categories; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE(preferred_job_categories) ON TABLE public.profiles TO authenticated;


--
-- Name: COLUMN profiles.transportation_methods; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE(transportation_methods) ON TABLE public.profiles TO authenticated;


--
-- Name: COLUMN profiles.max_travel_distance_miles; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE(max_travel_distance_miles) ON TABLE public.profiles TO authenticated;


--
-- Name: COLUMN profiles.max_travel_minutes; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE(max_travel_minutes) ON TABLE public.profiles TO authenticated;


--
-- Name: COLUMN profiles.walking_distance_only; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE(walking_distance_only) ON TABLE public.profiles TO authenticated;


--
-- Name: COLUMN profiles.guardian_transportation_possible; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE(guardian_transportation_possible) ON TABLE public.profiles TO authenticated;


--
-- Name: COLUMN profiles.guardian_setup_status; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE(guardian_setup_status) ON TABLE public.profiles TO authenticated;


--
-- Name: COLUMN profiles.guardian_paused; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT(guardian_paused) ON TABLE public.profiles TO authenticated;


--
-- Name: FUNCTION ensure_my_profile(); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.ensure_my_profile() FROM PUBLIC;
GRANT ALL ON FUNCTION private.ensure_my_profile() TO service_role;
GRANT ALL ON FUNCTION private.ensure_my_profile() TO authenticated;


--
-- Name: FUNCTION evaluate_mort_onboarding(p_user_id uuid); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.evaluate_mort_onboarding(p_user_id uuid) FROM PUBLIC;


--
-- Name: FUNCTION generate_job_finish_pin_internal(p_application_id uuid, p_client_request_id uuid); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.generate_job_finish_pin_internal(p_application_id uuid, p_client_request_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION private.generate_job_finish_pin_internal(p_application_id uuid, p_client_request_id uuid) TO authenticated;


--
-- Name: FUNCTION generate_job_start_pin_internal(p_application_id uuid, p_client_request_id uuid); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.generate_job_start_pin_internal(p_application_id uuid, p_client_request_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION private.generate_job_start_pin_internal(p_application_id uuid, p_client_request_id uuid) TO authenticated;


--
-- Name: FUNCTION get_job_execution_status_internal(p_application_id uuid); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.get_job_execution_status_internal(p_application_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION private.get_job_execution_status_internal(p_application_id uuid) TO authenticated;


--
-- Name: FUNCTION guard_job_table_mutations(); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.guard_job_table_mutations() FROM PUBLIC;


--
-- Name: FUNCTION handle_new_user(); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.handle_new_user() FROM PUBLIC;


--
-- Name: FUNCTION has_staff_role(required_roles public.mort_role[]); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.has_staff_role(required_roles public.mort_role[]) FROM PUBLIC;
GRANT ALL ON FUNCTION private.has_staff_role(required_roles public.mort_role[]) TO authenticated;


--
-- Name: FUNCTION ingest_verification_provider_event(p_project_ref text, p_provider_key text, p_timestamp text, p_signature text, p_raw_body text); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.ingest_verification_provider_event(p_project_ref text, p_provider_key text, p_timestamp text, p_signature text, p_raw_body text) FROM PUBLIC;


--
-- Name: FUNCTION is_active_user(); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.is_active_user() FROM PUBLIC;
GRANT ALL ON FUNCTION private.is_active_user() TO authenticated;


--
-- Name: FUNCTION is_approved_school_email(p_email text); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.is_approved_school_email(p_email text) FROM PUBLIC;
GRANT ALL ON FUNCTION private.is_approved_school_email(p_email text) TO service_role;


--
-- Name: FUNCTION is_job_safety_participant(p_application_id uuid, p_user_id uuid); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.is_job_safety_participant(p_application_id uuid, p_user_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION private.is_job_safety_participant(p_application_id uuid, p_user_id uuid) TO authenticated;


--
-- Name: FUNCTION job_execution_gate(p_application_id uuid, p_operation text); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.job_execution_gate(p_application_id uuid, p_operation text) FROM PUBLIC;


--
-- Name: FUNCTION job_safety_terms(p_application_id uuid); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.job_safety_terms(p_application_id uuid) FROM PUBLIC;


--
-- Name: FUNCTION message_thread_summary(p_conversation_id uuid, p_user_id uuid); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.message_thread_summary(p_conversation_id uuid, p_user_id uuid) FROM PUBLIC;


--
-- Name: FUNCTION mort_legal_age_band(p_date_of_birth date); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.mort_legal_age_band(p_date_of_birth date) FROM PUBLIC;
GRANT ALL ON FUNCTION private.mort_legal_age_band(p_date_of_birth date) TO authenticated;
GRANT ALL ON FUNCTION private.mort_legal_age_band(p_date_of_birth date) TO service_role;


--
-- Name: FUNCTION mort_user_has_current_legal_acceptances(p_user_id uuid); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.mort_user_has_current_legal_acceptances(p_user_id uuid) FROM PUBLIC;


--
-- Name: FUNCTION notify_guardians_of_safety_ping(); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.notify_guardians_of_safety_ping() FROM PUBLIC;


--
-- Name: FUNCTION refresh_job_safety_agreement(p_application_id uuid); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.refresh_job_safety_agreement(p_application_id uuid) FROM PUBLIC;


--
-- Name: FUNCTION refresh_safety_agreement_after_contract_change(); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.refresh_safety_agreement_after_contract_change() FROM PUBLIC;


--
-- Name: FUNCTION report_finish_pin_unavailable_internal(p_application_id uuid, p_actual_start_at timestamp with time zone, p_actual_finish_at timestamp with time zone, p_work_completed text, p_statement text, p_client_request_id uuid); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.report_finish_pin_unavailable_internal(p_application_id uuid, p_actual_start_at timestamp with time zone, p_actual_finish_at timestamp with time zone, p_work_completed text, p_statement text, p_client_request_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION private.report_finish_pin_unavailable_internal(p_application_id uuid, p_actual_start_at timestamp with time zone, p_actual_finish_at timestamp with time zone, p_work_completed text, p_statement text, p_client_request_id uuid) TO authenticated;


--
-- Name: FUNCTION report_possible_teen_abandonment_internal(p_application_id uuid, p_statement text, p_client_request_id uuid); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.report_possible_teen_abandonment_internal(p_application_id uuid, p_statement text, p_client_request_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION private.report_possible_teen_abandonment_internal(p_application_id uuid, p_statement text, p_client_request_id uuid) TO authenticated;


--
-- Name: FUNCTION request_adult_job_cancellation_internal(p_application_id uuid, p_reason text, p_client_request_id uuid); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.request_adult_job_cancellation_internal(p_application_id uuid, p_reason text, p_client_request_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION private.request_adult_job_cancellation_internal(p_application_id uuid, p_reason text, p_client_request_id uuid) TO authenticated;


--
-- Name: FUNCTION require_stripe_service_role(); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.require_stripe_service_role() FROM PUBLIC;
GRANT ALL ON FUNCTION private.require_stripe_service_role() TO service_role;


--
-- Name: FUNCTION respond_to_teen_abandonment_internal(p_application_id uuid, p_statement text, p_safety_related boolean, p_client_request_id uuid); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.respond_to_teen_abandonment_internal(p_application_id uuid, p_statement text, p_safety_related boolean, p_client_request_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION private.respond_to_teen_abandonment_internal(p_application_id uuid, p_statement text, p_safety_related boolean, p_client_request_id uuid) TO authenticated;


--
-- Name: FUNCTION reveal_reciprocal_job_reviews(); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.reveal_reciprocal_job_reviews() FROM PUBLIC;


--
-- Name: FUNCTION review_application_proof_internal(p_proof_id uuid, p_action text, p_note text); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.review_application_proof_internal(p_proof_id uuid, p_action text, p_note text) FROM PUBLIC;
GRANT ALL ON FUNCTION private.review_application_proof_internal(p_proof_id uuid, p_action text, p_note text) TO authenticated;


--
-- Name: FUNCTION save_job_safety_plan_internal(p_application_id uuid, p_expected_people text, p_public_or_visible_meeting boolean, p_daylight_preferred boolean, p_transportation_plan text, p_checkin_cadence_minutes integer); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.save_job_safety_plan_internal(p_application_id uuid, p_expected_people text, p_public_or_visible_meeting boolean, p_daylight_preferred boolean, p_transportation_plan text, p_checkin_cadence_minutes integer) FROM PUBLIC;
GRANT ALL ON FUNCTION private.save_job_safety_plan_internal(p_application_id uuid, p_expected_people text, p_public_or_visible_meeting boolean, p_daylight_preferred boolean, p_transportation_plan text, p_checkin_cadence_minutes integer) TO authenticated;


--
-- Name: FUNCTION submit_application_proof_internal(p_proof_id uuid, p_application_id uuid, p_storage_path text, p_note text); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.submit_application_proof_internal(p_proof_id uuid, p_application_id uuid, p_storage_path text, p_note text) FROM PUBLIC;
GRANT ALL ON FUNCTION private.submit_application_proof_internal(p_proof_id uuid, p_application_id uuid, p_storage_path text, p_note text) TO authenticated;


--
-- Name: FUNCTION submit_safety_cancellation_internal(p_application_id uuid, p_reason text, p_details text); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.submit_safety_cancellation_internal(p_application_id uuid, p_reason text, p_details text) FROM PUBLIC;
GRANT ALL ON FUNCTION private.submit_safety_cancellation_internal(p_application_id uuid, p_reason text, p_details text) TO authenticated;


--
-- Name: FUNCTION abort_application_proof_upload(p_proof_id uuid, p_application_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.abort_application_proof_upload(p_proof_id uuid, p_application_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.abort_application_proof_upload(p_proof_id uuid, p_application_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.abort_application_proof_upload(p_proof_id uuid, p_application_id uuid) TO service_role;


--
-- Name: FUNCTION accept_guardian_invite(p_invite_code text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.accept_guardian_invite(p_invite_code text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.accept_guardian_invite(p_invite_code text) TO authenticated;
GRANT ALL ON FUNCTION public.accept_guardian_invite(p_invite_code text) TO service_role;


--
-- Name: FUNCTION begin_application_proof_upload(p_proof_id uuid, p_application_id uuid, p_storage_path text, p_note text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.begin_application_proof_upload(p_proof_id uuid, p_application_id uuid, p_storage_path text, p_note text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.begin_application_proof_upload(p_proof_id uuid, p_application_id uuid, p_storage_path text, p_note text) TO authenticated;
GRANT ALL ON FUNCTION public.begin_application_proof_upload(p_proof_id uuid, p_application_id uuid, p_storage_path text, p_note text) TO service_role;


--
-- Name: FUNCTION block_user_v2(p_blocked_id uuid, p_reason text, p_client_request_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.block_user_v2(p_blocked_id uuid, p_reason text, p_client_request_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.block_user_v2(p_blocked_id uuid, p_reason text, p_client_request_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.block_user_v2(p_blocked_id uuid, p_reason text, p_client_request_id uuid) TO service_role;


--
-- Name: FUNCTION cancel_guardian_invite(p_link_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.cancel_guardian_invite(p_link_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.cancel_guardian_invite(p_link_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.cancel_guardian_invite(p_link_id uuid) TO service_role;


--
-- Name: FUNCTION close_team_hustle_v1(p_hustle_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.close_team_hustle_v1(p_hustle_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.close_team_hustle_v1(p_hustle_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.close_team_hustle_v1(p_hustle_id uuid) TO service_role;


--
-- Name: FUNCTION complete_active_job_checkin(p_checkin_id uuid, p_client_request_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.complete_active_job_checkin(p_checkin_id uuid, p_client_request_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.complete_active_job_checkin(p_checkin_id uuid, p_client_request_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.complete_active_job_checkin(p_checkin_id uuid, p_client_request_id uuid) TO authenticated;


--
-- Name: FUNCTION complete_job_after_proof(p_application_id uuid, p_proof_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.complete_job_after_proof(p_application_id uuid, p_proof_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.complete_job_after_proof(p_application_id uuid, p_proof_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.complete_job_after_proof(p_application_id uuid, p_proof_id uuid) TO service_role;


--
-- Name: FUNCTION complete_my_onboarding_v2(p_payload jsonb, p_client_request_id uuid, p_payload_version integer, p_expected_revision text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.complete_my_onboarding_v2(p_payload jsonb, p_client_request_id uuid, p_payload_version integer, p_expected_revision text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.complete_my_onboarding_v2(p_payload jsonb, p_client_request_id uuid, p_payload_version integer, p_expected_revision text) TO authenticated;
GRANT ALL ON FUNCTION public.complete_my_onboarding_v2(p_payload jsonb, p_client_request_id uuid, p_payload_version integer, p_expected_revision text) TO service_role;


--
-- Name: FUNCTION confirm_job_contract_version(p_contract_version_id uuid, p_affirmative_checkbox boolean, p_confirmation_text text, p_platform text, p_app_version text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.confirm_job_contract_version(p_contract_version_id uuid, p_affirmative_checkbox boolean, p_confirmation_text text, p_platform text, p_app_version text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.confirm_job_contract_version(p_contract_version_id uuid, p_affirmative_checkbox boolean, p_confirmation_text text, p_platform text, p_app_version text) TO authenticated;
GRANT ALL ON FUNCTION public.confirm_job_contract_version(p_contract_version_id uuid, p_affirmative_checkbox boolean, p_confirmation_text text, p_platform text, p_app_version text) TO service_role;


--
-- Name: FUNCTION confirm_job_finish_pin_v2(p_application_id uuid, p_pin text, p_client_request_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.confirm_job_finish_pin_v2(p_application_id uuid, p_pin text, p_client_request_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.confirm_job_finish_pin_v2(p_application_id uuid, p_pin text, p_client_request_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.confirm_job_finish_pin_v2(p_application_id uuid, p_pin text, p_client_request_id uuid) TO service_role;


--
-- Name: FUNCTION confirm_job_safety_agreement(p_application_id uuid, p_agreement_version integer); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.confirm_job_safety_agreement(p_application_id uuid, p_agreement_version integer) FROM PUBLIC;
GRANT ALL ON FUNCTION public.confirm_job_safety_agreement(p_application_id uuid, p_agreement_version integer) TO authenticated;
GRANT ALL ON FUNCTION public.confirm_job_safety_agreement(p_application_id uuid, p_agreement_version integer) TO service_role;


--
-- Name: FUNCTION confirm_job_start_pin_v2(p_application_id uuid, p_pin text, p_person_matches_profile boolean, p_client_request_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.confirm_job_start_pin_v2(p_application_id uuid, p_pin text, p_person_matches_profile boolean, p_client_request_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.confirm_job_start_pin_v2(p_application_id uuid, p_pin text, p_person_matches_profile boolean, p_client_request_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.confirm_job_start_pin_v2(p_application_id uuid, p_pin text, p_person_matches_profile boolean, p_client_request_id uuid) TO service_role;


--
-- Name: FUNCTION consume_my_edge_action_limit(p_action text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.consume_my_edge_action_limit(p_action text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.consume_my_edge_action_limit(p_action text) TO authenticated;
GRANT ALL ON FUNCTION public.consume_my_edge_action_limit(p_action text) TO service_role;


--
-- Name: FUNCTION create_guardian_invite_v2(p_invite_email text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.create_guardian_invite_v2(p_invite_email text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.create_guardian_invite_v2(p_invite_email text) TO authenticated;
GRANT ALL ON FUNCTION public.create_guardian_invite_v2(p_invite_email text) TO service_role;


--
-- Name: FUNCTION create_safety_ping_v2(p_status text, p_note text, p_job_id uuid, p_immediate_danger boolean, p_client_request_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.create_safety_ping_v2(p_status text, p_note text, p_job_id uuid, p_immediate_danger boolean, p_client_request_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.create_safety_ping_v2(p_status text, p_note text, p_job_id uuid, p_immediate_danger boolean, p_client_request_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.create_safety_ping_v2(p_status text, p_note text, p_job_id uuid, p_immediate_danger boolean, p_client_request_id uuid) TO authenticated;


--
-- Name: FUNCTION create_team_hustle_v1(p_title text, p_description text, p_category text, p_pay_type text, p_pay_amount numeric, p_workers_needed integer, p_city text, p_region text, p_location_notes text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.create_team_hustle_v1(p_title text, p_description text, p_category text, p_pay_type text, p_pay_amount numeric, p_workers_needed integer, p_city text, p_region text, p_location_notes text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.create_team_hustle_v1(p_title text, p_description text, p_category text, p_pay_type text, p_pay_amount numeric, p_workers_needed integer, p_city text, p_region text, p_location_notes text) TO authenticated;
GRANT ALL ON FUNCTION public.create_team_hustle_v1(p_title text, p_description text, p_category text, p_pay_type text, p_pay_amount numeric, p_workers_needed integer, p_city text, p_region text, p_location_notes text) TO service_role;


--
-- Name: FUNCTION ensure_my_profile(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.ensure_my_profile() FROM PUBLIC;
GRANT ALL ON FUNCTION public.ensure_my_profile() TO authenticated;
GRANT ALL ON FUNCTION public.ensure_my_profile() TO service_role;


--
-- Name: FUNCTION generate_job_finish_pin(p_application_id uuid, p_client_request_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.generate_job_finish_pin(p_application_id uuid, p_client_request_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.generate_job_finish_pin(p_application_id uuid, p_client_request_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.generate_job_finish_pin(p_application_id uuid, p_client_request_id uuid) TO service_role;


--
-- Name: FUNCTION generate_job_start_pin(p_application_id uuid, p_client_request_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.generate_job_start_pin(p_application_id uuid, p_client_request_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.generate_job_start_pin(p_application_id uuid, p_client_request_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.generate_job_start_pin(p_application_id uuid, p_client_request_id uuid) TO service_role;


--
-- Name: FUNCTION get_first_party_trust_status(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.get_first_party_trust_status() FROM PUBLIC;
GRANT ALL ON FUNCTION public.get_first_party_trust_status() TO authenticated;
GRANT ALL ON FUNCTION public.get_first_party_trust_status() TO service_role;


--
-- Name: FUNCTION get_job_application_eligibility(p_job_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.get_job_application_eligibility(p_job_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.get_job_application_eligibility(p_job_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_job_application_eligibility(p_job_id uuid) TO service_role;


--
-- Name: FUNCTION get_job_execution_status(p_application_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.get_job_execution_status(p_application_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.get_job_execution_status(p_application_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_job_execution_status(p_application_id uuid) TO service_role;


--
-- Name: FUNCTION get_my_active_job_checkins(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.get_my_active_job_checkins() FROM PUBLIC;
GRANT ALL ON FUNCTION public.get_my_active_job_checkins() TO service_role;
GRANT ALL ON FUNCTION public.get_my_active_job_checkins() TO authenticated;


--
-- Name: FUNCTION get_my_assignment_payment_status(p_provider_payment_intent_id text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.get_my_assignment_payment_status(p_provider_payment_intent_id text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.get_my_assignment_payment_status(p_provider_payment_intent_id text) TO authenticated;
GRANT ALL ON FUNCTION public.get_my_assignment_payment_status(p_provider_payment_intent_id text) TO service_role;


--
-- Name: FUNCTION get_my_identity_verification_v2(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.get_my_identity_verification_v2() FROM PUBLIC;
GRANT ALL ON FUNCTION public.get_my_identity_verification_v2() TO authenticated;
GRANT ALL ON FUNCTION public.get_my_identity_verification_v2() TO service_role;


--
-- Name: FUNCTION get_my_job_applications(p_application_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.get_my_job_applications(p_application_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.get_my_job_applications(p_application_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_my_job_applications(p_application_id uuid) TO service_role;


--
-- Name: FUNCTION get_my_legal_requirements(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.get_my_legal_requirements() FROM PUBLIC;
GRANT ALL ON FUNCTION public.get_my_legal_requirements() TO authenticated;
GRANT ALL ON FUNCTION public.get_my_legal_requirements() TO service_role;


--
-- Name: FUNCTION get_my_onboarding_progress(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.get_my_onboarding_progress() FROM PUBLIC;
GRANT ALL ON FUNCTION public.get_my_onboarding_progress() TO authenticated;
GRANT ALL ON FUNCTION public.get_my_onboarding_progress() TO service_role;


--
-- Name: FUNCTION get_my_onboarding_progress_v2(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.get_my_onboarding_progress_v2() FROM PUBLIC;
GRANT ALL ON FUNCTION public.get_my_onboarding_progress_v2() TO authenticated;
GRANT ALL ON FUNCTION public.get_my_onboarding_progress_v2() TO service_role;


--
-- Name: FUNCTION get_my_profile(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.get_my_profile() FROM PUBLIC;
GRANT ALL ON FUNCTION public.get_my_profile() TO authenticated;
GRANT ALL ON FUNCTION public.get_my_profile() TO service_role;


--
-- Name: FUNCTION get_my_stripe_payout_status(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.get_my_stripe_payout_status() FROM PUBLIC;
GRANT ALL ON FUNCTION public.get_my_stripe_payout_status() TO authenticated;
GRANT ALL ON FUNCTION public.get_my_stripe_payout_status() TO service_role;


--
-- Name: FUNCTION get_my_verification_requirements_v1(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.get_my_verification_requirements_v1() FROM PUBLIC;
GRANT ALL ON FUNCTION public.get_my_verification_requirements_v1() TO authenticated;
GRANT ALL ON FUNCTION public.get_my_verification_requirements_v1() TO service_role;


--
-- Name: FUNCTION get_release_mode_status(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.get_release_mode_status() FROM PUBLIC;
GRANT ALL ON FUNCTION public.get_release_mode_status() TO anon;
GRANT ALL ON FUNCTION public.get_release_mode_status() TO authenticated;
GRANT ALL ON FUNCTION public.get_release_mode_status() TO service_role;


--
-- Name: FUNCTION get_released_job_location(p_application_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.get_released_job_location(p_application_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.get_released_job_location(p_application_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_released_job_location(p_application_id uuid) TO service_role;


--
-- Name: FUNCTION get_runtime_feature_status(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.get_runtime_feature_status() FROM PUBLIC;
GRANT ALL ON FUNCTION public.get_runtime_feature_status() TO authenticated;
GRANT ALL ON FUNCTION public.get_runtime_feature_status() TO service_role;


--
-- Name: FUNCTION get_stripe_runtime_status(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.get_stripe_runtime_status() FROM PUBLIC;
GRANT ALL ON FUNCTION public.get_stripe_runtime_status() TO authenticated;
GRANT ALL ON FUNCTION public.get_stripe_runtime_status() TO service_role;


--
-- Name: FUNCTION join_team_hustle_v1(p_hustle_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.join_team_hustle_v1(p_hustle_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.join_team_hustle_v1(p_hustle_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.join_team_hustle_v1(p_hustle_id uuid) TO service_role;


--
-- Name: FUNCTION leave_team_hustle_v1(p_hustle_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.leave_team_hustle_v1(p_hustle_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.leave_team_hustle_v1(p_hustle_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.leave_team_hustle_v1(p_hustle_id uuid) TO service_role;


--
-- Name: FUNCTION list_my_message_threads_page(p_query text, p_cursor_updated_at timestamp with time zone, p_cursor_id uuid, p_limit integer); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.list_my_message_threads_page(p_query text, p_cursor_updated_at timestamp with time zone, p_cursor_id uuid, p_limit integer) FROM PUBLIC;
GRANT ALL ON FUNCTION public.list_my_message_threads_page(p_query text, p_cursor_updated_at timestamp with time zone, p_cursor_id uuid, p_limit integer) TO authenticated;
GRANT ALL ON FUNCTION public.list_my_message_threads_page(p_query text, p_cursor_updated_at timestamp with time zone, p_cursor_id uuid, p_limit integer) TO service_role;


--
-- Name: FUNCTION list_my_saved_jobs(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.list_my_saved_jobs() FROM PUBLIC;
GRANT ALL ON FUNCTION public.list_my_saved_jobs() TO service_role;
GRANT ALL ON FUNCTION public.list_my_saved_jobs() TO authenticated;


--
-- Name: FUNCTION list_my_verification_cases_v1(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.list_my_verification_cases_v1() FROM PUBLIC;
GRANT ALL ON FUNCTION public.list_my_verification_cases_v1() TO authenticated;
GRANT ALL ON FUNCTION public.list_my_verification_cases_v1() TO service_role;


--
-- Name: FUNCTION list_open_jobs_page(p_keyword text, p_category text, p_minimum_pay_cents integer, p_payment_type text, p_schedule_type text, p_verification_requirement text, p_requires_guardian_approval boolean, p_work_environment text, p_city text, p_state text, p_transportation_methods text[], p_sort text, p_cursor_value text, p_cursor_id uuid, p_limit integer); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.list_open_jobs_page(p_keyword text, p_category text, p_minimum_pay_cents integer, p_payment_type text, p_schedule_type text, p_verification_requirement text, p_requires_guardian_approval boolean, p_work_environment text, p_city text, p_state text, p_transportation_methods text[], p_sort text, p_cursor_value text, p_cursor_id uuid, p_limit integer) FROM PUBLIC;
GRANT ALL ON FUNCTION public.list_open_jobs_page(p_keyword text, p_category text, p_minimum_pay_cents integer, p_payment_type text, p_schedule_type text, p_verification_requirement text, p_requires_guardian_approval boolean, p_work_environment text, p_city text, p_state text, p_transportation_methods text[], p_sort text, p_cursor_value text, p_cursor_id uuid, p_limit integer) TO authenticated;
GRANT ALL ON FUNCTION public.list_open_jobs_page(p_keyword text, p_category text, p_minimum_pay_cents integer, p_payment_type text, p_schedule_type text, p_verification_requirement text, p_requires_guardian_approval boolean, p_work_environment text, p_city text, p_state text, p_transportation_methods text[], p_sort text, p_cursor_value text, p_cursor_id uuid, p_limit integer) TO service_role;


--
-- Name: FUNCTION list_team_hustles_v1(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.list_team_hustles_v1() FROM PUBLIC;
GRANT ALL ON FUNCTION public.list_team_hustles_v1() TO authenticated;
GRANT ALL ON FUNCTION public.list_team_hustles_v1() TO service_role;


--
-- Name: FUNCTION list_thread_messages_page(p_thread_id uuid, p_cursor_created_at timestamp with time zone, p_cursor_id uuid, p_limit integer); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.list_thread_messages_page(p_thread_id uuid, p_cursor_created_at timestamp with time zone, p_cursor_id uuid, p_limit integer) FROM PUBLIC;
GRANT ALL ON FUNCTION public.list_thread_messages_page(p_thread_id uuid, p_cursor_created_at timestamp with time zone, p_cursor_id uuid, p_limit integer) TO authenticated;
GRANT ALL ON FUNCTION public.list_thread_messages_page(p_thread_id uuid, p_cursor_created_at timestamp with time zone, p_cursor_id uuid, p_limit integer) TO service_role;


--
-- Name: FUNCTION manage_job_v2(p_job_id uuid, p_action text, p_reason text, p_client_request_id uuid, p_expected_updated_at timestamp with time zone); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.manage_job_v2(p_job_id uuid, p_action text, p_reason text, p_client_request_id uuid, p_expected_updated_at timestamp with time zone) FROM PUBLIC;
GRANT ALL ON FUNCTION public.manage_job_v2(p_job_id uuid, p_action text, p_reason text, p_client_request_id uuid, p_expected_updated_at timestamp with time zone) TO authenticated;
GRANT ALL ON FUNCTION public.manage_job_v2(p_job_id uuid, p_action text, p_reason text, p_client_request_id uuid, p_expected_updated_at timestamp with time zone) TO service_role;


--
-- Name: FUNCTION mark_message_thread_read(p_thread_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.mark_message_thread_read(p_thread_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.mark_message_thread_read(p_thread_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.mark_message_thread_read(p_thread_id uuid) TO service_role;


--
-- Name: FUNCTION mort_accept_job_application(p_application_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.mort_accept_job_application(p_application_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.mort_accept_job_application(p_application_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.mort_accept_job_application(p_application_id uuid) TO service_role;


--
-- Name: FUNCTION mort_admin_list_users_v1(p_limit integer); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.mort_admin_list_users_v1(p_limit integer) FROM PUBLIC;
GRANT ALL ON FUNCTION public.mort_admin_list_users_v1(p_limit integer) TO authenticated;
GRANT ALL ON FUNCTION public.mort_admin_list_users_v1(p_limit integer) TO service_role;


--
-- Name: FUNCTION mort_ingest_verification_provider_event(p_project_ref text, p_provider_key text, p_timestamp text, p_signature text, p_raw_body text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.mort_ingest_verification_provider_event(p_project_ref text, p_provider_key text, p_timestamp text, p_signature text, p_raw_body text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.mort_ingest_verification_provider_event(p_project_ref text, p_provider_key text, p_timestamp text, p_signature text, p_raw_body text) TO service_role;


--
-- Name: FUNCTION mort_moderate_message(p_message_id uuid, p_status text, p_reason text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.mort_moderate_message(p_message_id uuid, p_status text, p_reason text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.mort_moderate_message(p_message_id uuid, p_status text, p_reason text) TO authenticated;
GRANT ALL ON FUNCTION public.mort_moderate_message(p_message_id uuid, p_status text, p_reason text) TO service_role;


--
-- Name: FUNCTION mort_record_staff_document_review(p_case_id uuid, p_decision text, p_note text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.mort_record_staff_document_review(p_case_id uuid, p_decision text, p_note text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.mort_record_staff_document_review(p_case_id uuid, p_decision text, p_note text) TO service_role;
GRANT ALL ON FUNCTION public.mort_record_staff_document_review(p_case_id uuid, p_decision text, p_note text) TO authenticated;


--
-- Name: FUNCTION mort_review_job(p_job_id uuid, p_approve boolean, p_reason text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.mort_review_job(p_job_id uuid, p_approve boolean, p_reason text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.mort_review_job(p_job_id uuid, p_approve boolean, p_reason text) TO service_role;
GRANT ALL ON FUNCTION public.mort_review_job(p_job_id uuid, p_approve boolean, p_reason text) TO authenticated;


--
-- Name: FUNCTION mort_review_role_request(p_request_id uuid, p_approve boolean, p_reason text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.mort_review_role_request(p_request_id uuid, p_approve boolean, p_reason text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.mort_review_role_request(p_request_id uuid, p_approve boolean, p_reason text) TO authenticated;
GRANT ALL ON FUNCTION public.mort_review_role_request(p_request_id uuid, p_approve boolean, p_reason text) TO service_role;


--
-- Name: FUNCTION mort_review_verification_case(p_case_id uuid, p_status public.mort_verification_status, p_note text, p_expires_at timestamp with time zone); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.mort_review_verification_case(p_case_id uuid, p_status public.mort_verification_status, p_note text, p_expires_at timestamp with time zone) FROM PUBLIC;
GRANT ALL ON FUNCTION public.mort_review_verification_case(p_case_id uuid, p_status public.mort_verification_status, p_note text, p_expires_at timestamp with time zone) TO authenticated;
GRANT ALL ON FUNCTION public.mort_review_verification_case(p_case_id uuid, p_status public.mort_verification_status, p_note text, p_expires_at timestamp with time zone) TO service_role;


--
-- Name: FUNCTION mort_send_message(p_conversation_id uuid, p_body text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.mort_send_message(p_conversation_id uuid, p_body text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.mort_send_message(p_conversation_id uuid, p_body text) TO service_role;


--
-- Name: FUNCTION mort_set_guardian_consent(p_link_id uuid, p_accept boolean); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.mort_set_guardian_consent(p_link_id uuid, p_accept boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION public.mort_set_guardian_consent(p_link_id uuid, p_accept boolean) TO authenticated;
GRANT ALL ON FUNCTION public.mort_set_guardian_consent(p_link_id uuid, p_accept boolean) TO service_role;


--
-- Name: FUNCTION mort_set_guardian_pause_v1(p_teen_id uuid, p_paused boolean); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.mort_set_guardian_pause_v1(p_teen_id uuid, p_paused boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION public.mort_set_guardian_pause_v1(p_teen_id uuid, p_paused boolean) TO authenticated;
GRANT ALL ON FUNCTION public.mort_set_guardian_pause_v1(p_teen_id uuid, p_paused boolean) TO service_role;


--
-- Name: FUNCTION mort_submit_job_application(p_job_id uuid, p_cover_note text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.mort_submit_job_application(p_job_id uuid, p_cover_note text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.mort_submit_job_application(p_job_id uuid, p_cover_note text) TO service_role;


--
-- Name: FUNCTION report_finish_pin_unavailable(p_application_id uuid, p_actual_start_at timestamp with time zone, p_actual_finish_at timestamp with time zone, p_work_completed text, p_statement text, p_client_request_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.report_finish_pin_unavailable(p_application_id uuid, p_actual_start_at timestamp with time zone, p_actual_finish_at timestamp with time zone, p_work_completed text, p_statement text, p_client_request_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.report_finish_pin_unavailable(p_application_id uuid, p_actual_start_at timestamp with time zone, p_actual_finish_at timestamp with time zone, p_work_completed text, p_statement text, p_client_request_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.report_finish_pin_unavailable(p_application_id uuid, p_actual_start_at timestamp with time zone, p_actual_finish_at timestamp with time zone, p_work_completed text, p_statement text, p_client_request_id uuid) TO service_role;


--
-- Name: FUNCTION report_possible_teen_abandonment(p_application_id uuid, p_statement text, p_client_request_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.report_possible_teen_abandonment(p_application_id uuid, p_statement text, p_client_request_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.report_possible_teen_abandonment(p_application_id uuid, p_statement text, p_client_request_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.report_possible_teen_abandonment(p_application_id uuid, p_statement text, p_client_request_id uuid) TO service_role;


--
-- Name: FUNCTION request_adult_job_cancellation(p_application_id uuid, p_reason text, p_client_request_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.request_adult_job_cancellation(p_application_id uuid, p_reason text, p_client_request_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.request_adult_job_cancellation(p_application_id uuid, p_reason text, p_client_request_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.request_adult_job_cancellation(p_application_id uuid, p_reason text, p_client_request_id uuid) TO service_role;


--
-- Name: FUNCTION request_job_contract_change(p_contract_id uuid, p_patch jsonb, p_reason text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.request_job_contract_change(p_contract_id uuid, p_patch jsonb, p_reason text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.request_job_contract_change(p_contract_id uuid, p_patch jsonb, p_reason text) TO authenticated;
GRANT ALL ON FUNCTION public.request_job_contract_change(p_contract_id uuid, p_patch jsonb, p_reason text) TO service_role;


--
-- Name: FUNCTION resend_guardian_invite(p_link_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.resend_guardian_invite(p_link_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.resend_guardian_invite(p_link_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.resend_guardian_invite(p_link_id uuid) TO service_role;


--
-- Name: FUNCTION respond_job_contract_change(p_change_request_id uuid, p_accept boolean, p_affirmative_checkbox boolean); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.respond_job_contract_change(p_change_request_id uuid, p_accept boolean, p_affirmative_checkbox boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION public.respond_job_contract_change(p_change_request_id uuid, p_accept boolean, p_affirmative_checkbox boolean) TO authenticated;
GRANT ALL ON FUNCTION public.respond_job_contract_change(p_change_request_id uuid, p_accept boolean, p_affirmative_checkbox boolean) TO service_role;


--
-- Name: FUNCTION respond_to_teen_abandonment(p_application_id uuid, p_statement text, p_safety_related boolean, p_client_request_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.respond_to_teen_abandonment(p_application_id uuid, p_statement text, p_safety_related boolean, p_client_request_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.respond_to_teen_abandonment(p_application_id uuid, p_statement text, p_safety_related boolean, p_client_request_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.respond_to_teen_abandonment(p_application_id uuid, p_statement text, p_safety_related boolean, p_client_request_id uuid) TO service_role;


--
-- Name: FUNCTION review_application_proof(p_proof_id uuid, p_action text, p_note text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.review_application_proof(p_proof_id uuid, p_action text, p_note text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.review_application_proof(p_proof_id uuid, p_action text, p_note text) TO authenticated;
GRANT ALL ON FUNCTION public.review_application_proof(p_proof_id uuid, p_action text, p_note text) TO service_role;


--
-- Name: FUNCTION save_job_draft_or_publish(p_job_id uuid, p_client_request_id uuid, p_payload jsonb, p_publish boolean); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.save_job_draft_or_publish(p_job_id uuid, p_client_request_id uuid, p_payload jsonb, p_publish boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION public.save_job_draft_or_publish(p_job_id uuid, p_client_request_id uuid, p_payload jsonb, p_publish boolean) TO authenticated;
GRANT ALL ON FUNCTION public.save_job_draft_or_publish(p_job_id uuid, p_client_request_id uuid, p_payload jsonb, p_publish boolean) TO service_role;


--
-- Name: FUNCTION save_job_private_location_v1(p_job_id uuid, p_exact_address text, p_arrival_instructions text, p_access_notes text, p_client_request_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.save_job_private_location_v1(p_job_id uuid, p_exact_address text, p_arrival_instructions text, p_access_notes text, p_client_request_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.save_job_private_location_v1(p_job_id uuid, p_exact_address text, p_arrival_instructions text, p_access_notes text, p_client_request_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.save_job_private_location_v1(p_job_id uuid, p_exact_address text, p_arrival_instructions text, p_access_notes text, p_client_request_id uuid) TO service_role;


--
-- Name: FUNCTION save_job_safety_plan(p_application_id uuid, p_expected_people text, p_public_or_visible_meeting boolean, p_daylight_preferred boolean, p_transportation_plan text, p_checkin_cadence_minutes integer); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.save_job_safety_plan(p_application_id uuid, p_expected_people text, p_public_or_visible_meeting boolean, p_daylight_preferred boolean, p_transportation_plan text, p_checkin_cadence_minutes integer) FROM PUBLIC;
GRANT ALL ON FUNCTION public.save_job_safety_plan(p_application_id uuid, p_expected_people text, p_public_or_visible_meeting boolean, p_daylight_preferred boolean, p_transportation_plan text, p_checkin_cadence_minutes integer) TO authenticated;
GRANT ALL ON FUNCTION public.save_job_safety_plan(p_application_id uuid, p_expected_people text, p_public_or_visible_meeting boolean, p_daylight_preferred boolean, p_transportation_plan text, p_checkin_cadence_minutes integer) TO service_role;


--
-- Name: FUNCTION save_my_initial_dob_v1(p_date_of_birth date); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.save_my_initial_dob_v1(p_date_of_birth date) FROM PUBLIC;
GRANT ALL ON FUNCTION public.save_my_initial_dob_v1(p_date_of_birth date) TO authenticated;
GRANT ALL ON FUNCTION public.save_my_initial_dob_v1(p_date_of_birth date) TO service_role;


--
-- Name: FUNCTION save_my_job_v1(p_job_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.save_my_job_v1(p_job_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.save_my_job_v1(p_job_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.save_my_job_v1(p_job_id uuid) TO authenticated;


--
-- Name: FUNCTION save_my_onboarding_account_v2(p_payload jsonb, p_client_request_id uuid, p_payload_version integer); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.save_my_onboarding_account_v2(p_payload jsonb, p_client_request_id uuid, p_payload_version integer) FROM PUBLIC;
GRANT ALL ON FUNCTION public.save_my_onboarding_account_v2(p_payload jsonb, p_client_request_id uuid, p_payload_version integer) TO authenticated;
GRANT ALL ON FUNCTION public.save_my_onboarding_account_v2(p_payload jsonb, p_client_request_id uuid, p_payload_version integer) TO service_role;


--
-- Name: FUNCTION save_my_onboarding_safety_v2(p_payload jsonb, p_client_request_id uuid, p_payload_version integer, p_expected_revision text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.save_my_onboarding_safety_v2(p_payload jsonb, p_client_request_id uuid, p_payload_version integer, p_expected_revision text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.save_my_onboarding_safety_v2(p_payload jsonb, p_client_request_id uuid, p_payload_version integer, p_expected_revision text) TO authenticated;
GRANT ALL ON FUNCTION public.save_my_onboarding_safety_v2(p_payload jsonb, p_client_request_id uuid, p_payload_version integer, p_expected_revision text) TO service_role;


--
-- Name: FUNCTION save_my_onboarding_work_v2(p_payload jsonb, p_client_request_id uuid, p_payload_version integer, p_expected_revision text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.save_my_onboarding_work_v2(p_payload jsonb, p_client_request_id uuid, p_payload_version integer, p_expected_revision text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.save_my_onboarding_work_v2(p_payload jsonb, p_client_request_id uuid, p_payload_version integer, p_expected_revision text) TO authenticated;
GRANT ALL ON FUNCTION public.save_my_onboarding_work_v2(p_payload jsonb, p_client_request_id uuid, p_payload_version integer, p_expected_revision text) TO service_role;


--
-- Name: FUNCTION schedule_active_job_checkin(p_application_id uuid, p_minutes_from_now integer, p_client_request_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.schedule_active_job_checkin(p_application_id uuid, p_minutes_from_now integer, p_client_request_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.schedule_active_job_checkin(p_application_id uuid, p_minutes_from_now integer, p_client_request_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.schedule_active_job_checkin(p_application_id uuid, p_minutes_from_now integer, p_client_request_id uuid) TO authenticated;


--
-- Name: FUNCTION send_safe_message_v2(p_thread_id uuid, p_body text, p_client_request_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.send_safe_message_v2(p_thread_id uuid, p_body text, p_client_request_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.send_safe_message_v2(p_thread_id uuid, p_body text, p_client_request_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.send_safe_message_v2(p_thread_id uuid, p_body text, p_client_request_id uuid) TO service_role;


--
-- Name: FUNCTION set_guardian_alert_preferences(p_link_id uuid, p_safety_ping_alerts boolean, p_job_checkin_alerts boolean, p_accepted_job_summary boolean, p_safety_warning_alerts boolean, p_weekly_digest boolean, p_optional_job_approval_enabled boolean); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.set_guardian_alert_preferences(p_link_id uuid, p_safety_ping_alerts boolean, p_job_checkin_alerts boolean, p_accepted_job_summary boolean, p_safety_warning_alerts boolean, p_weekly_digest boolean, p_optional_job_approval_enabled boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION public.set_guardian_alert_preferences(p_link_id uuid, p_safety_ping_alerts boolean, p_job_checkin_alerts boolean, p_accepted_job_summary boolean, p_safety_warning_alerts boolean, p_weekly_digest boolean, p_optional_job_approval_enabled boolean) TO service_role;
GRANT ALL ON FUNCTION public.set_guardian_alert_preferences(p_link_id uuid, p_safety_ping_alerts boolean, p_job_checkin_alerts boolean, p_accepted_job_summary boolean, p_safety_warning_alerts boolean, p_weekly_digest boolean, p_optional_job_approval_enabled boolean) TO authenticated;


--
-- Name: FUNCTION set_guardian_setup_skipped(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.set_guardian_setup_skipped() FROM PUBLIC;
GRANT ALL ON FUNCTION public.set_guardian_setup_skipped() TO authenticated;
GRANT ALL ON FUNCTION public.set_guardian_setup_skipped() TO service_role;


--
-- Name: FUNCTION stripe_server_apply_assignment_payment_webhook(p_environment text, p_provider_event_id text, p_lease_token uuid, p_ledger_id uuid, p_provider_payment_intent_id text, p_provider_status text, p_amount_cents integer, p_currency_code text, p_event_created_at timestamp with time zone); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.stripe_server_apply_assignment_payment_webhook(p_environment text, p_provider_event_id text, p_lease_token uuid, p_ledger_id uuid, p_provider_payment_intent_id text, p_provider_status text, p_amount_cents integer, p_currency_code text, p_event_created_at timestamp with time zone) FROM PUBLIC;
GRANT ALL ON FUNCTION public.stripe_server_apply_assignment_payment_webhook(p_environment text, p_provider_event_id text, p_lease_token uuid, p_ledger_id uuid, p_provider_payment_intent_id text, p_provider_status text, p_amount_cents integer, p_currency_code text, p_event_created_at timestamp with time zone) TO service_role;


--
-- Name: FUNCTION stripe_server_claim_webhook_event(p_environment text, p_provider_event_id text, p_event_type text, p_provider_created_at timestamp with time zone, p_payload_sha256 text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.stripe_server_claim_webhook_event(p_environment text, p_provider_event_id text, p_event_type text, p_provider_created_at timestamp with time zone, p_payload_sha256 text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.stripe_server_claim_webhook_event(p_environment text, p_provider_event_id text, p_event_type text, p_provider_created_at timestamp with time zone, p_payload_sha256 text) TO service_role;


--
-- Name: FUNCTION stripe_server_finish_webhook_event(p_environment text, p_provider_event_id text, p_lease_token uuid, p_disposition text, p_safe_failure_code text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.stripe_server_finish_webhook_event(p_environment text, p_provider_event_id text, p_lease_token uuid, p_disposition text, p_safe_failure_code text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.stripe_server_finish_webhook_event(p_environment text, p_provider_event_id text, p_lease_token uuid, p_disposition text, p_safe_failure_code text) TO service_role;


--
-- Name: FUNCTION stripe_server_prepare_assignment_payment(p_payer_id uuid, p_assignment_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.stripe_server_prepare_assignment_payment(p_payer_id uuid, p_assignment_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.stripe_server_prepare_assignment_payment(p_payer_id uuid, p_assignment_id uuid) TO service_role;


--
-- Name: FUNCTION stripe_server_record_assignment_payment_intent(p_ledger_id uuid, p_provider_payment_intent_id text, p_provider_status text, p_provider_created_at timestamp with time zone); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.stripe_server_record_assignment_payment_intent(p_ledger_id uuid, p_provider_payment_intent_id text, p_provider_status text, p_provider_created_at timestamp with time zone) FROM PUBLIC;
GRANT ALL ON FUNCTION public.stripe_server_record_assignment_payment_intent(p_ledger_id uuid, p_provider_payment_intent_id text, p_provider_status text, p_provider_created_at timestamp with time zone) TO service_role;


--
-- Name: FUNCTION submit_application_proof(p_proof_id uuid, p_application_id uuid, p_storage_path text, p_note text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.submit_application_proof(p_proof_id uuid, p_application_id uuid, p_storage_path text, p_note text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.submit_application_proof(p_proof_id uuid, p_application_id uuid, p_storage_path text, p_note text) TO authenticated;
GRANT ALL ON FUNCTION public.submit_application_proof(p_proof_id uuid, p_application_id uuid, p_storage_path text, p_note text) TO service_role;


--
-- Name: FUNCTION submit_job_application(p_job_id uuid, p_note text, p_availability_confirmed boolean, p_portfolio_ids uuid[]); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.submit_job_application(p_job_id uuid, p_note text, p_availability_confirmed boolean, p_portfolio_ids uuid[]) FROM PUBLIC;
GRANT ALL ON FUNCTION public.submit_job_application(p_job_id uuid, p_note text, p_availability_confirmed boolean, p_portfolio_ids uuid[]) TO authenticated;
GRANT ALL ON FUNCTION public.submit_job_application(p_job_id uuid, p_note text, p_availability_confirmed boolean, p_portfolio_ids uuid[]) TO service_role;


--
-- Name: FUNCTION submit_legal_acceptance(p_document_version_id uuid, p_affirmative_checkbox boolean, p_teen_summary_viewed boolean, p_electronic_signature_text text, p_platform text, p_app_version text, p_language_code text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.submit_legal_acceptance(p_document_version_id uuid, p_affirmative_checkbox boolean, p_teen_summary_viewed boolean, p_electronic_signature_text text, p_platform text, p_app_version text, p_language_code text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.submit_legal_acceptance(p_document_version_id uuid, p_affirmative_checkbox boolean, p_teen_summary_viewed boolean, p_electronic_signature_text text, p_platform text, p_app_version text, p_language_code text) TO authenticated;
GRANT ALL ON FUNCTION public.submit_legal_acceptance(p_document_version_id uuid, p_affirmative_checkbox boolean, p_teen_summary_viewed boolean, p_electronic_signature_text text, p_platform text, p_app_version text, p_language_code text) TO service_role;


--
-- Name: FUNCTION submit_my_verification_evidence_v1(p_verification_type text, p_evidence_path text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.submit_my_verification_evidence_v1(p_verification_type text, p_evidence_path text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.submit_my_verification_evidence_v1(p_verification_type text, p_evidence_path text) TO authenticated;
GRANT ALL ON FUNCTION public.submit_my_verification_evidence_v1(p_verification_type text, p_evidence_path text) TO service_role;


--
-- Name: FUNCTION submit_safety_cancellation(p_application_id uuid, p_reason text, p_details text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.submit_safety_cancellation(p_application_id uuid, p_reason text, p_details text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.submit_safety_cancellation(p_application_id uuid, p_reason text, p_details text) TO authenticated;
GRANT ALL ON FUNCTION public.submit_safety_cancellation(p_application_id uuid, p_reason text, p_details text) TO service_role;


--
-- Name: FUNCTION submit_safety_report_v2(p_target_user_id uuid, p_target_job_id uuid, p_target_message_id uuid, p_target_review_id uuid, p_application_id uuid, p_category text, p_severity text, p_immediate_danger boolean, p_details text, p_occurred_at timestamp with time zone, p_location_type text, p_desired_outcome text, p_confidential_safety_feedback boolean, p_client_request_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.submit_safety_report_v2(p_target_user_id uuid, p_target_job_id uuid, p_target_message_id uuid, p_target_review_id uuid, p_application_id uuid, p_category text, p_severity text, p_immediate_danger boolean, p_details text, p_occurred_at timestamp with time zone, p_location_type text, p_desired_outcome text, p_confidential_safety_feedback boolean, p_client_request_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.submit_safety_report_v2(p_target_user_id uuid, p_target_job_id uuid, p_target_message_id uuid, p_target_review_id uuid, p_application_id uuid, p_category text, p_severity text, p_immediate_danger boolean, p_details text, p_occurred_at timestamp with time zone, p_location_type text, p_desired_outcome text, p_confidential_safety_feedback boolean, p_client_request_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.submit_safety_report_v2(p_target_user_id uuid, p_target_job_id uuid, p_target_message_id uuid, p_target_review_id uuid, p_application_id uuid, p_category text, p_severity text, p_immediate_danger boolean, p_details text, p_occurred_at timestamp with time zone, p_location_type text, p_desired_outcome text, p_confidential_safety_feedback boolean, p_client_request_id uuid) TO authenticated;


--
-- Name: FUNCTION sync_safety_agreement_location_version(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.sync_safety_agreement_location_version() FROM PUBLIC;
GRANT ALL ON FUNCTION public.sync_safety_agreement_location_version() TO service_role;


--
-- Name: FUNCTION unblock_user_v2(p_blocked_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.unblock_user_v2(p_blocked_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.unblock_user_v2(p_blocked_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.unblock_user_v2(p_blocked_id uuid) TO service_role;


--
-- Name: FUNCTION unlink_guardian(p_link_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.unlink_guardian(p_link_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.unlink_guardian(p_link_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.unlink_guardian(p_link_id uuid) TO service_role;


--
-- Name: FUNCTION update_my_job_application_status(p_application_id uuid, p_action text, p_expected_updated_at timestamp with time zone); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.update_my_job_application_status(p_application_id uuid, p_action text, p_expected_updated_at timestamp with time zone) FROM PUBLIC;
GRANT ALL ON FUNCTION public.update_my_job_application_status(p_application_id uuid, p_action text, p_expected_updated_at timestamp with time zone) TO authenticated;
GRANT ALL ON FUNCTION public.update_my_job_application_status(p_application_id uuid, p_action text, p_expected_updated_at timestamp with time zone) TO service_role;


--
-- Name: TABLE guardian_invite_accept_limits; Type: ACL; Schema: private; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE private.guardian_invite_accept_limits TO service_role;


--
-- Name: TABLE guardian_invite_codes; Type: ACL; Schema: private; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE private.guardian_invite_codes TO service_role;


--
-- Name: TABLE job_execution_events; Type: ACL; Schema: private; Owner: -
--

GRANT ALL ON TABLE private.job_execution_events TO service_role;


--
-- Name: TABLE job_execution_sessions; Type: ACL; Schema: private; Owner: -
--

GRANT ALL ON TABLE private.job_execution_sessions TO service_role;


--
-- Name: TABLE job_pin_confirmation_requests; Type: ACL; Schema: private; Owner: -
--

GRANT ALL ON TABLE private.job_pin_confirmation_requests TO service_role;


--
-- Name: TABLE job_private_location_access_events; Type: ACL; Schema: private; Owner: -
--

GRANT ALL ON TABLE private.job_private_location_access_events TO service_role;


--
-- Name: TABLE job_private_locations; Type: ACL; Schema: private; Owner: -
--

GRANT ALL ON TABLE private.job_private_locations TO service_role;


--
-- Name: TABLE mort_edge_action_limits; Type: ACL; Schema: private; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE private.mort_edge_action_limits TO service_role;


--
-- Name: TABLE mort_onboarding_safety; Type: ACL; Schema: private; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE private.mort_onboarding_safety TO service_role;


--
-- Name: TABLE school_email_domains; Type: ACL; Schema: private; Owner: -
--

GRANT ALL ON TABLE private.school_email_domains TO service_role;


--
-- Name: TABLE stripe_connected_accounts; Type: ACL; Schema: private; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE private.stripe_connected_accounts TO service_role;


--
-- Name: TABLE stripe_customers; Type: ACL; Schema: private; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE private.stripe_customers TO service_role;


--
-- Name: TABLE stripe_payment_intents; Type: ACL; Schema: private; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE private.stripe_payment_intents TO service_role;


--
-- Name: TABLE stripe_runtime_controls; Type: ACL; Schema: private; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE private.stripe_runtime_controls TO service_role;


--
-- Name: TABLE stripe_webhook_events; Type: ACL; Schema: private; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE private.stripe_webhook_events TO service_role;


--
-- Name: TABLE verification_provider_allowlist; Type: ACL; Schema: private; Owner: -
--

GRANT SELECT ON TABLE private.verification_provider_allowlist TO service_role;


--
-- Name: TABLE verification_provider_ingestion_keys; Type: ACL; Schema: private; Owner: -
--

GRANT SELECT ON TABLE private.verification_provider_ingestion_keys TO service_role;


--
-- Name: TABLE verification_provider_results; Type: ACL; Schema: private; Owner: -
--

GRANT SELECT,INSERT ON TABLE private.verification_provider_results TO service_role;


--
-- Name: TABLE admin_audit_log; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.admin_audit_log TO service_role;
GRANT SELECT ON TABLE public.admin_audit_log TO authenticated;


--
-- Name: SEQUENCE admin_audit_log_id_seq; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON SEQUENCE public.admin_audit_log_id_seq TO anon;
GRANT ALL ON SEQUENCE public.admin_audit_log_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.admin_audit_log_id_seq TO service_role;


--
-- Name: TABLE application_status_events; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.application_status_events TO service_role;
GRANT SELECT ON TABLE public.application_status_events TO authenticated;


--
-- Name: TABLE consents; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.consents TO service_role;
GRANT SELECT ON TABLE public.consents TO authenticated;


--
-- Name: COLUMN consents.user_id; Type: ACL; Schema: public; Owner: -
--

GRANT INSERT(user_id) ON TABLE public.consents TO authenticated;


--
-- Name: COLUMN consents.consent_type; Type: ACL; Schema: public; Owner: -
--

GRANT INSERT(consent_type) ON TABLE public.consents TO authenticated;


--
-- Name: COLUMN consents.document_version; Type: ACL; Schema: public; Owner: -
--

GRANT INSERT(document_version) ON TABLE public.consents TO authenticated;


--
-- Name: COLUMN consents.granted; Type: ACL; Schema: public; Owner: -
--

GRANT INSERT(granted) ON TABLE public.consents TO authenticated;


--
-- Name: TABLE conversation_members; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.conversation_members TO service_role;
GRANT SELECT ON TABLE public.conversation_members TO authenticated;


--
-- Name: COLUMN conversation_members.last_read_at; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE(last_read_at) ON TABLE public.conversation_members TO authenticated;


--
-- Name: COLUMN conversation_members.muted_at; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE(muted_at) ON TABLE public.conversation_members TO authenticated;


--
-- Name: TABLE conversations; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.conversations TO service_role;
GRANT SELECT ON TABLE public.conversations TO authenticated;


--
-- Name: TABLE disputes; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.disputes TO service_role;
GRANT SELECT,INSERT ON TABLE public.disputes TO authenticated;


--
-- Name: TABLE evidence_files; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.evidence_files TO service_role;
GRANT SELECT ON TABLE public.evidence_files TO authenticated;


--
-- Name: TABLE guardian_links; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.guardian_links TO service_role;
GRANT SELECT ON TABLE public.guardian_links TO authenticated;


--
-- Name: TABLE guardian_preferences; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.guardian_preferences TO service_role;
GRANT SELECT ON TABLE public.guardian_preferences TO authenticated;


--
-- Name: TABLE job_applications; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.job_applications TO service_role;
GRANT SELECT ON TABLE public.job_applications TO authenticated;


--
-- Name: TABLE job_assignments; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.job_assignments TO service_role;
GRANT SELECT ON TABLE public.job_assignments TO authenticated;


--
-- Name: TABLE job_contract_acceptances; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.job_contract_acceptances TO service_role;
GRANT SELECT ON TABLE public.job_contract_acceptances TO authenticated;


--
-- Name: TABLE job_contract_change_acceptances; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.job_contract_change_acceptances TO service_role;
GRANT SELECT ON TABLE public.job_contract_change_acceptances TO authenticated;


--
-- Name: TABLE job_contract_change_requests; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.job_contract_change_requests TO service_role;
GRANT SELECT ON TABLE public.job_contract_change_requests TO authenticated;


--
-- Name: TABLE job_contract_versions; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.job_contract_versions TO service_role;
GRANT SELECT ON TABLE public.job_contract_versions TO authenticated;


--
-- Name: TABLE job_contracts; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.job_contracts TO service_role;
GRANT SELECT ON TABLE public.job_contracts TO authenticated;


--
-- Name: TABLE job_execution_review_responses; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.job_execution_review_responses TO service_role;
GRANT SELECT ON TABLE public.job_execution_review_responses TO authenticated;


--
-- Name: TABLE job_interests; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.job_interests TO service_role;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.job_interests TO authenticated;


--
-- Name: TABLE job_safety_agreements; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.job_safety_agreements TO service_role;
GRANT SELECT ON TABLE public.job_safety_agreements TO authenticated;


--
-- Name: TABLE job_safety_cancellations; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.job_safety_cancellations TO service_role;


--
-- Name: TABLE job_safety_checkins; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.job_safety_checkins TO service_role;
GRANT SELECT ON TABLE public.job_safety_checkins TO authenticated;


--
-- Name: TABLE job_safety_plans; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.job_safety_plans TO service_role;
GRANT SELECT ON TABLE public.job_safety_plans TO authenticated;


--
-- Name: TABLE job_status_events; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.job_status_events TO service_role;
GRANT SELECT ON TABLE public.job_status_events TO authenticated;


--
-- Name: TABLE jobs; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.jobs TO service_role;
GRANT SELECT ON TABLE public.jobs TO authenticated;


--
-- Name: COLUMN jobs.id; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT(id) ON TABLE public.jobs TO authenticated;


--
-- Name: COLUMN jobs.poster_id; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT(poster_id) ON TABLE public.jobs TO authenticated;


--
-- Name: COLUMN jobs.title; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT(title) ON TABLE public.jobs TO authenticated;


--
-- Name: COLUMN jobs.description; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT(description) ON TABLE public.jobs TO authenticated;


--
-- Name: COLUMN jobs.category; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT(category) ON TABLE public.jobs TO authenticated;


--
-- Name: COLUMN jobs.status; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT(status) ON TABLE public.jobs TO authenticated;


--
-- Name: COLUMN jobs.pay_type; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT(pay_type) ON TABLE public.jobs TO authenticated;


--
-- Name: COLUMN jobs.pay_amount; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT(pay_amount) ON TABLE public.jobs TO authenticated;


--
-- Name: COLUMN jobs.estimated_minutes; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT(estimated_minutes) ON TABLE public.jobs TO authenticated;


--
-- Name: COLUMN jobs.city; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT(city) ON TABLE public.jobs TO authenticated;


--
-- Name: COLUMN jobs.region; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT(region) ON TABLE public.jobs TO authenticated;


--
-- Name: COLUMN jobs.location_notes; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT(location_notes) ON TABLE public.jobs TO authenticated;


--
-- Name: COLUMN jobs.age_min; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT(age_min) ON TABLE public.jobs TO authenticated;


--
-- Name: COLUMN jobs.age_max; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT(age_max) ON TABLE public.jobs TO authenticated;


--
-- Name: COLUMN jobs.remote_allowed; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT(remote_allowed) ON TABLE public.jobs TO authenticated;


--
-- Name: COLUMN jobs.starts_at; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT(starts_at) ON TABLE public.jobs TO authenticated;


--
-- Name: COLUMN jobs.ends_at; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT(ends_at) ON TABLE public.jobs TO authenticated;


--
-- Name: COLUMN jobs.safety_review_status; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT(safety_review_status) ON TABLE public.jobs TO authenticated;


--
-- Name: COLUMN jobs.published_at; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT(published_at) ON TABLE public.jobs TO authenticated;


--
-- Name: COLUMN jobs.created_at; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT(created_at) ON TABLE public.jobs TO authenticated;


--
-- Name: COLUMN jobs.updated_at; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT(updated_at) ON TABLE public.jobs TO authenticated;


--
-- Name: COLUMN jobs.completed_at; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT(completed_at) ON TABLE public.jobs TO authenticated;


--
-- Name: TABLE legal_acceptance_audit_events; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.legal_acceptance_audit_events TO service_role;


--
-- Name: SEQUENCE legal_acceptance_audit_events_id_seq; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON SEQUENCE public.legal_acceptance_audit_events_id_seq TO anon;
GRANT ALL ON SEQUENCE public.legal_acceptance_audit_events_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.legal_acceptance_audit_events_id_seq TO service_role;


--
-- Name: TABLE legal_acceptances; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.legal_acceptances TO service_role;
GRANT SELECT ON TABLE public.legal_acceptances TO authenticated;


--
-- Name: TABLE legal_document_versions; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.legal_document_versions TO service_role;
GRANT SELECT ON TABLE public.legal_document_versions TO authenticated;


--
-- Name: TABLE legal_documents; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.legal_documents TO service_role;
GRANT SELECT ON TABLE public.legal_documents TO authenticated;


--
-- Name: TABLE legal_role_requirements; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.legal_role_requirements TO service_role;


--
-- Name: TABLE messages; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.messages TO service_role;
GRANT SELECT ON TABLE public.messages TO authenticated;


--
-- Name: TABLE mort_release_control; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.mort_release_control TO anon;
GRANT SELECT ON TABLE public.mort_release_control TO authenticated;
GRANT SELECT,UPDATE ON TABLE public.mort_release_control TO service_role;


--
-- Name: TABLE notification_preferences; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.notification_preferences TO service_role;
GRANT SELECT,INSERT,UPDATE ON TABLE public.notification_preferences TO authenticated;


--
-- Name: TABLE notifications; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.notifications TO service_role;
GRANT SELECT ON TABLE public.notifications TO authenticated;


--
-- Name: COLUMN notifications.read_at; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE(read_at) ON TABLE public.notifications TO authenticated;


--
-- Name: TABLE payment_records; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.payment_records TO service_role;
GRANT SELECT ON TABLE public.payment_records TO authenticated;


--
-- Name: TABLE proof_uploads; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.proof_uploads TO service_role;
GRANT SELECT ON TABLE public.proof_uploads TO authenticated;


--
-- Name: TABLE reviews; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.reviews TO service_role;
GRANT SELECT,INSERT ON TABLE public.reviews TO authenticated;


--
-- Name: TABLE role_requests; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.role_requests TO service_role;
GRANT SELECT,INSERT ON TABLE public.role_requests TO authenticated;


--
-- Name: TABLE safety_pings; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.safety_pings TO service_role;
GRANT SELECT ON TABLE public.safety_pings TO authenticated;


--
-- Name: TABLE safety_reports; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.safety_reports TO service_role;
GRANT SELECT ON TABLE public.safety_reports TO authenticated;


--
-- Name: TABLE saved_jobs; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.saved_jobs TO service_role;
GRANT SELECT,INSERT,DELETE ON TABLE public.saved_jobs TO authenticated;


--
-- Name: TABLE team_hustle_members; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.team_hustle_members TO anon;
GRANT ALL ON TABLE public.team_hustle_members TO authenticated;
GRANT ALL ON TABLE public.team_hustle_members TO service_role;


--
-- Name: TABLE team_hustles; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.team_hustles TO anon;
GRANT ALL ON TABLE public.team_hustles TO authenticated;
GRANT ALL ON TABLE public.team_hustles TO service_role;


--
-- Name: TABLE user_blocks; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.user_blocks TO service_role;
GRANT SELECT ON TABLE public.user_blocks TO authenticated;


--
-- Name: TABLE verification_cases; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.verification_cases TO service_role;
GRANT SELECT,INSERT ON TABLE public.verification_cases TO authenticated;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: -
--



--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: -
--



--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: -
--



--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: -
--



--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: -
--



--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: -
--



--
-- PostgreSQL database dump complete
--


