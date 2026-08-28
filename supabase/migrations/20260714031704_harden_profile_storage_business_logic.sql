-- Security hardening for private profile fields, evidence storage, and job state
-- transitions. This migration preserves existing rows and uses no destructive
-- reset or table drop.

create or replace function public.protect_profile_sensitive_fields()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_internal_update text := current_setting('mort.internal_update', true);
  v_jwt_role text := coalesce(auth.jwt()->>'role', '');
  v_trusted_server boolean :=
    session_user in ('postgres', 'supabase_admin')
    or v_jwt_role = 'service_role';
begin
  if v_trusted_server or public.is_admin() or v_internal_update = 'true' then
    return new;
  end if;

  if new.role = 'admin' then
    raise exception 'admin_role_self_assignment_blocked';
  end if;

  if tg_op = 'INSERT' then
    if new.verification_status <> 'not_started' then
      raise exception 'verification_status_self_assignment_blocked';
    end if;
    if new.account_status <> 'active' or new.blocked_until is not null then
      raise exception 'account_status_self_assignment_blocked';
    end if;
    if new.is_test_account then
      raise exception 'test_account_self_assignment_blocked';
    end if;
  else
    if old.role is not null and old.role is distinct from new.role then
      raise exception 'role_change_requires_admin';
    end if;
    if old.verification_status is distinct from new.verification_status then
      raise exception 'verification_status_requires_admin';
    end if;
    if old.account_status is distinct from new.account_status then
      raise exception 'account_status_requires_admin';
    end if;
    if old.blocked_until is distinct from new.blocked_until then
      raise exception 'account_restriction_requires_admin';
    end if;
    if old.is_test_account is distinct from new.is_test_account then
      raise exception 'test_account_flag_requires_server';
    end if;
  end if;

  return new;
end;
$$;

-- Related users may read only directory-safe columns through PostgREST. Full
-- profile rows are available only through caller-bound/admin-checked RPCs.
revoke select on table public.profiles from public, anon, authenticated;
grant select (
  id,
  role,
  display_name,
  verification_status,
  created_at,
  updated_at,
  username,
  avatar_path,
  avatar_moderation_status,
  avatar_updated_at,
  bio,
  availability,
  preferred_job_categories,
  approximate_area,
  goals
) on public.profiles to authenticated;
grant select on table public.profiles to service_role;

create or replace function public.get_my_profile()
returns setof public.profiles
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select p.*
  from public.profiles p
  where auth.uid() is not null
    and p.id = auth.uid();
$$;

create or replace function public.admin_list_profiles(p_limit integer default 50)
returns setof public.profiles
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'admin_access_required';
  end if;

  return query
  select p.*
  from public.profiles p
  order by p.created_at desc
  limit greatest(1, least(coalesce(p_limit, 50), 100));
end;
$$;

-- Evidence objects are append-only for app users. Owners can remove unattached
-- proof/verification uploads through the dedicated delete policies, but cannot
-- overwrite bytes after upload. Admin moderation retains its existing access.
alter policy storage_mort_owner_insert on storage.objects
to authenticated
with check (
  bucket_id = any (array['proof-uploads', 'verification-uploads', 'report-uploads'])
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

alter policy storage_mort_owner_select on storage.objects
to authenticated
using (
  bucket_id = any (array['proof-uploads', 'verification-uploads', 'report-uploads'])
  and (
    (storage.foldername(name))[1] = (select auth.uid())::text
    or public.is_admin()
    or (
      bucket_id = 'proof-uploads'
      and exists (
        select 1
        from public.proof_uploads proof
        where proof.storage_path = storage.objects.name
          and public.is_application_participant(proof.application_id)
      )
    )
  )
);

drop policy if exists storage_mort_owner_update on storage.objects;
create policy storage_mort_admin_evidence_update
on storage.objects
for update
to authenticated
using (
  bucket_id = any (array['proof-uploads', 'verification-uploads', 'report-uploads'])
  and public.is_admin()
)
with check (
  bucket_id = any (array['proof-uploads', 'verification-uploads', 'report-uploads'])
  and public.is_admin()
);

alter policy storage_profile_avatars_insert_own on storage.objects
to authenticated
with check (
  bucket_id = 'profile-avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

alter policy storage_profile_avatars_select_owner_admin on storage.objects
to authenticated
using (
  bucket_id = 'profile-avatars'
  and (
    (storage.foldername(name))[1] = (select auth.uid())::text
    or public.is_admin()
  )
);

alter policy storage_profile_avatars_update_own on storage.objects
to authenticated
using (
  bucket_id = 'profile-avatars'
  and (
    (storage.foldername(name))[1] = (select auth.uid())::text
    or public.is_admin()
  )
)
with check (
  bucket_id = 'profile-avatars'
  and (
    (storage.foldername(name))[1] = (select auth.uid())::text
    or public.is_admin()
  )
);

alter policy storage_profile_avatars_delete_own on storage.objects
to authenticated
using (
  bucket_id = 'profile-avatars'
  and (
    (storage.foldername(name))[1] = (select auth.uid())::text
    or public.is_admin()
  )
);

alter policy storage_proof_uploads_delete_unattached_own on storage.objects
to authenticated
using (
  bucket_id = 'proof-uploads'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and not exists (
    select 1
    from public.proof_uploads proof
    where proof.storage_path = storage.objects.name
  )
);

alter policy storage_verification_delete_unattached_own on storage.objects
to authenticated
using (
  bucket_id = 'verification-uploads'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and not exists (
    select 1
    from public.business_verifications verification
    where verification.document_storage_path = storage.objects.name
  )
);

create or replace function public.submit_job_application(
  p_job_id uuid,
  p_note text default null,
  p_availability_confirmed boolean default false,
  p_portfolio_ids uuid[] default '{}'
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_eligibility jsonb;
  v_application public.applications%rowtype;
  v_job public.jobs%rowtype;
  v_guardian_id uuid;
  v_guardian_required boolean;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'eligible', false, 'code', 'authentication_required');
  end if;

  -- Serializes application submission against job closure/assignment.
  select * into v_job
  from public.jobs
  where id = p_job_id
  for update;

  v_eligibility := public.get_job_application_eligibility(p_job_id);
  if not coalesce((v_eligibility->>'eligible')::boolean, false) then
    return v_eligibility || jsonb_build_object('ok', false);
  end if;
  if not public.is_action_allowed('job_application_create') then
    return jsonb_build_object(
      'ok', false,
      'eligible', false,
      'code', 'application_limit_reached',
      'message', 'You have submitted too many applications today. Try again tomorrow.'
    );
  end if;

  v_guardian_required := coalesce((v_eligibility->>'guardian_required_for_this_job')::boolean, false);
  if v_guardian_required then
    select guardian_id into v_guardian_id
    from public.guardian_connections
    where teen_id = auth.uid()
      and status = 'active'
      and guardian_id is not null
    order by accepted_at desc nulls last
    limit 1;
  end if;

  insert into public.applications (
    job_id,
    teen_id,
    status,
    note,
    guardian_id,
    availability_confirmed,
    portfolio_ids
  ) values (
    p_job_id,
    auth.uid(),
    case
      when v_guardian_required then 'guardian_pending'::public.application_status
      else 'adult_review'::public.application_status
    end,
    nullif(left(btrim(coalesce(p_note, '')), 500), ''),
    v_guardian_id,
    p_availability_confirmed,
    coalesce(p_portfolio_ids, '{}')
  )
  returning * into v_application;

  perform public.record_rate_limit_event('job_application_create');
  return jsonb_build_object(
    'ok', true,
    'eligible', true,
    'code', 'application_submitted',
    'message', case
      when v_guardian_required then 'Application sent for guardian approval.'
      else 'Application submitted to the poster.'
    end,
    'application', to_jsonb(v_application) || jsonb_build_object('jobs', to_jsonb(v_job))
  );
exception
  when unique_violation then
    return jsonb_build_object(
      'ok', false,
      'eligible', false,
      'code', 'application_already_exists',
      'message', 'You already applied to this job.'
    );
end;
$$;

create or replace function public.update_application_status_v2(
  p_application_id uuid,
  p_action text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_application public.applications%rowtype;
  v_job public.jobs%rowtype;
  v_job_id uuid;
  v_action text := lower(btrim(p_action));
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;

  select application.job_id into v_job_id
  from public.applications application
  where application.id = p_application_id;
  if v_job_id is null then
    return jsonb_build_object('ok', false, 'code', 'application_not_found');
  end if;

  -- Every status transition locks the parent job first. This prevents two
  -- applicants from being accepted concurrently and avoids cross-app deadlocks.
  select * into v_job
  from public.jobs
  where id = v_job_id
  for update;

  select * into v_application
  from public.applications
  where id = p_application_id
  for update;

  if v_action in ('adult_review', 'guardian_rejected')
     and v_application.guardian_id = auth.uid()
     and v_application.status = 'guardian_pending'
     and public.guardian_is_connected_to_teen(v_application.teen_id, auth.uid()) then
    update public.applications
    set status = v_action::public.application_status
    where id = p_application_id
    returning * into v_application;
  elsif v_action = 'viewed'
     and v_job.poster_id = auth.uid()
     and v_application.status in ('submitted', 'adult_review') then
    update public.applications
    set status = 'viewed', viewed_at = now()
    where id = p_application_id
    returning * into v_application;
  elsif v_action = 'accepted'
     and v_job.poster_id = auth.uid()
     and v_application.status in ('submitted', 'adult_review', 'viewed')
     and v_job.status = 'open'
     and v_job.applications_open then
    update public.applications
    set status = 'accepted'
    where id = p_application_id
    returning * into v_application;
    update public.applications
    set status = 'rejected'
    where job_id = v_job.id
      and id <> p_application_id
      and status in ('submitted', 'adult_review', 'viewed');
    update public.jobs
    set status = 'assigned', applications_open = false
    where id = v_job.id
    returning * into v_job;
  elsif v_action = 'rejected'
     and v_job.poster_id = auth.uid()
     and v_application.status in ('submitted', 'adult_review', 'viewed') then
    update public.applications
    set status = 'rejected'
    where id = p_application_id
    returning * into v_application;
  elsif v_action = 'withdrawn'
     and v_application.teen_id = auth.uid()
     and v_application.status in ('submitted', 'guardian_pending', 'adult_review', 'viewed') then
    update public.applications
    set status = 'withdrawn', withdrawn_at = now()
    where id = p_application_id
    returning * into v_application;
  elsif v_action = 'in_progress'
     and v_application.teen_id = auth.uid()
     and v_application.status = 'accepted'
     and v_job.status = 'assigned' then
    update public.applications
    set status = 'in_progress'
    where id = p_application_id
    returning * into v_application;
    update public.jobs
    set status = 'in_progress'
    where id = v_job.id
    returning * into v_job;
  elsif v_action = 'completed'
     and v_job.poster_id = auth.uid()
     and v_application.status in ('in_progress', 'proof_submitted')
     and v_job.status in ('in_progress', 'proof_submitted') then
    if v_job.proof_expected and v_application.status <> 'proof_submitted' then
      return jsonb_build_object('ok', false, 'code', 'proof_required');
    end if;
    update public.applications
    set status = 'completed'
    where id = p_application_id
    returning * into v_application;
    update public.jobs
    set status = 'completed'
    where id = v_job.id
    returning * into v_job;
  else
    return jsonb_build_object('ok', false, 'code', 'invalid_application_transition');
  end if;

  return jsonb_build_object(
    'ok', true,
    'application', to_jsonb(v_application),
    'job', to_jsonb(v_job)
  );
end;
$$;

create or replace function public.submit_application_proof(
  p_proof_id uuid,
  p_application_id uuid,
  p_storage_path text,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_application public.applications%rowtype;
  v_job public.jobs%rowtype;
  v_job_id uuid;
  v_proof public.proof_uploads%rowtype;
  v_path text := btrim(coalesce(p_storage_path, ''));
  v_mime text;
  v_size bigint;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_proof_id is null then
    return jsonb_build_object('ok', false, 'code', 'invalid_proof_submission');
  end if;
  if v_path = ''
     or v_path <> (auth.uid()::text || '/' || p_proof_id::text || '.jpg')
     or position('..' in v_path) > 0 then
    return jsonb_build_object('ok', false, 'code', 'invalid_proof_path');
  end if;

  select * into v_proof
  from public.proof_uploads
  where id = p_proof_id;
  if v_proof.id is not null then
    if v_proof.application_id <> p_application_id
       or v_proof.uploaded_by <> auth.uid()
       or v_proof.storage_path <> v_path then
      return jsonb_build_object('ok', false, 'code', 'unknown_permission_failure');
    end if;
    select * into v_application
    from public.applications
    where id = v_proof.application_id;
    select * into v_job
    from public.jobs
    where id = v_application.job_id;
    return jsonb_build_object(
      'ok', true,
      'idempotent', true,
      'proof', to_jsonb(v_proof),
      'application', to_jsonb(v_application),
      'job', to_jsonb(v_job)
    );
  end if;

  select application.job_id into v_job_id
  from public.applications application
  where application.id = p_application_id;
  if v_job_id is null then
    return jsonb_build_object('ok', false, 'code', 'application_not_found');
  end if;

  select * into v_job
  from public.jobs
  where id = v_job_id
  for update;

  select * into v_application
  from public.applications
  where id = p_application_id
  for update;

  if v_application.teen_id <> auth.uid() then
    return jsonb_build_object('ok', false, 'code', 'unknown_permission_failure');
  end if;
  if v_application.status <> 'in_progress' then
    return jsonb_build_object('ok', false, 'code', 'invalid_application_transition');
  end if;
  if v_job.id is null or v_job.status <> 'in_progress' then
    return jsonb_build_object('ok', false, 'code', 'invalid_job_transition');
  end if;

  select
    lower(coalesce(object.metadata->>'mimetype', '')),
    case
      when coalesce(object.metadata->>'size', '') ~ '^[0-9]+$'
        then (object.metadata->>'size')::bigint
      else 0
    end
  into v_mime, v_size
  from storage.objects object
  where object.bucket_id = 'proof-uploads'
    and object.name = v_path
    and object.owner_id = auth.uid()::text;

  if not found then
    return jsonb_build_object('ok', false, 'code', 'proof_object_not_found');
  end if;
  if v_mime <> 'image/jpeg' then
    return jsonb_build_object('ok', false, 'code', 'proof_file_type_invalid');
  end if;
  if v_size < 1 or v_size > 10485760 then
    return jsonb_build_object('ok', false, 'code', 'proof_file_size_invalid');
  end if;

  insert into public.proof_uploads (
    id,
    application_id,
    uploaded_by,
    storage_path,
    note
  ) values (
    p_proof_id,
    p_application_id,
    auth.uid(),
    v_path,
    nullif(left(btrim(coalesce(p_note, '')), 500), '')
  )
  returning * into v_proof;

  update public.applications
  set status = 'proof_submitted'
  where id = p_application_id
  returning * into v_application;

  update public.jobs
  set status = 'proof_submitted'
  where id = v_application.job_id
  returning * into v_job;

  return jsonb_build_object(
    'ok', true,
    'idempotent', false,
    'proof', to_jsonb(v_proof),
    'application', to_jsonb(v_application),
    'job', to_jsonb(v_job)
  );
exception
  when unique_violation then
    select * into v_proof
    from public.proof_uploads
    where id = p_proof_id;
    if v_proof.id is not null
       and v_proof.application_id = p_application_id
       and v_proof.uploaded_by = auth.uid()
       and v_proof.storage_path = v_path then
      select * into v_application
      from public.applications
      where id = v_proof.application_id;
      select * into v_job
      from public.jobs
      where id = v_application.job_id;
      return jsonb_build_object(
        'ok', true,
        'idempotent', true,
        'proof', to_jsonb(v_proof),
        'application', to_jsonb(v_application),
        'job', to_jsonb(v_job)
      );
    end if;
    return jsonb_build_object('ok', false, 'code', 'unknown_permission_failure');
end;
$$;

create or replace function public.submit_business_verification(
  p_verification_id uuid,
  p_storage_path text,
  p_business_name text,
  p_business_type text,
  p_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_profile public.profiles%rowtype;
  v_verification public.business_verifications%rowtype;
  v_path text := btrim(coalesce(p_storage_path, ''));
  v_name text := btrim(coalesce(p_business_name, ''));
  v_type text := lower(btrim(coalesce(p_business_type, '')));
  v_mime text;
  v_size bigint;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_verification_id is null then
    return jsonb_build_object('ok', false, 'code', 'invalid_verification_submission');
  end if;
  if v_path <> (auth.uid()::text || '/' || p_verification_id::text || '.jpg')
     or position('..' in v_path) > 0 then
    return jsonb_build_object('ok', false, 'code', 'invalid_verification_path');
  end if;

  select * into v_verification
  from public.business_verifications
  where id = p_verification_id;
  if v_verification.id is not null then
    if v_verification.adult_id <> auth.uid()
       or v_verification.document_storage_path <> v_path then
      return jsonb_build_object('ok', false, 'code', 'unknown_permission_failure');
    end if;
    return jsonb_build_object(
      'ok', true,
      'idempotent', true,
      'verification', to_jsonb(v_verification)
    );
  end if;

  select * into v_profile
  from public.profiles
  where id = auth.uid()
  for update;
  if v_profile.role <> 'adult' or v_profile.account_status <> 'active' then
    return jsonb_build_object('ok', false, 'code', 'user_role_not_allowed');
  end if;
  if char_length(v_name) not between 2 and 120
     or v_type not in (
       'individual',
       'sole_proprietor',
       'business',
       'nonprofit',
       'community_organization'
     )
     or char_length(coalesce(p_notes, '')) > 1000 then
    return jsonb_build_object('ok', false, 'code', 'invalid_verification_details');
  end if;
  if exists (
    select 1
    from public.business_verifications
    where adult_id = auth.uid()
      and status = 'pending'
  ) then
    return jsonb_build_object('ok', false, 'code', 'verification_already_pending');
  end if;

  select
    lower(coalesce(object.metadata->>'mimetype', '')),
    case
      when coalesce(object.metadata->>'size', '') ~ '^[0-9]+$'
        then (object.metadata->>'size')::bigint
      else 0
    end
  into v_mime, v_size
  from storage.objects object
  where object.bucket_id = 'verification-uploads'
    and object.name = v_path
    and object.owner_id = auth.uid()::text;

  if not found then
    return jsonb_build_object('ok', false, 'code', 'verification_object_not_found');
  end if;
  if v_mime <> 'image/jpeg' then
    return jsonb_build_object('ok', false, 'code', 'verification_file_type_invalid');
  end if;
  if v_size < 1 or v_size > 10485760 then
    return jsonb_build_object('ok', false, 'code', 'verification_file_size_invalid');
  end if;

  insert into public.business_verifications (
    id,
    adult_id,
    business_name,
    business_type,
    document_storage_path,
    notes,
    status
  ) values (
    p_verification_id,
    auth.uid(),
    v_name,
    v_type,
    v_path,
    nullif(btrim(coalesce(p_notes, '')), ''),
    'pending'
  )
  returning * into v_verification;

  return jsonb_build_object(
    'ok', true,
    'idempotent', false,
    'verification', to_jsonb(v_verification)
  );
end;
$$;

-- Public is never an execution principal for MORT RPCs. Re-grant only the
-- authenticated APIs that previously depended on PostgreSQL's default PUBLIC
-- function privilege, then lock the default for future functions.
revoke execute on all functions in schema public from public, anon;
alter default privileges for role postgres in schema public
  revoke execute on functions from public;

grant execute on function public.get_my_profile() to authenticated, service_role;
grant execute on function public.admin_list_profiles(integer) to authenticated, service_role;
grant execute on function public.get_my_entitlements() to authenticated, service_role;
grant execute on function public.record_paywall_event(public.paywall_event_type, text, text, text, text, text)
  to authenticated, service_role;
grant execute on function public.record_ad_impression(text, public.ad_format, text, boolean)
  to authenticated, service_role;
grant execute on function public.get_ad_eligibility(text, public.ad_format)
  to authenticated, service_role;
grant execute on function public.get_boosted_jobs() to authenticated, service_role;
grant execute on function public.admin_monetization_overview() to authenticated, service_role;

grant execute on function public.submit_job_application(uuid, text, boolean, uuid[])
  to authenticated, service_role;
grant execute on function public.update_application_status_v2(uuid, text)
  to authenticated, service_role;
grant execute on function public.submit_application_proof(uuid, uuid, text, text)
  to authenticated, service_role;
grant execute on function public.submit_business_verification(uuid, text, text, text, text)
  to authenticated, service_role;
