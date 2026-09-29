-- MORT Verify: teen age + school affiliation foundation.
-- Production collection remains fail-closed. Sandbox mode is available only
-- to synthetic/test accounts until legal/privacy/reviewer gates are approved.

create table if not exists private.teen_verification_control (
  singleton boolean primary key default true check (singleton),
  mode text not null default 'sandbox'
    check (mode in ('disabled','sandbox','production')),
  school_id_required boolean not null default true,
  school_email_required boolean not null default true,
  max_document_bytes bigint not null default 8388608
    check (max_document_bytes between 262144 and 10485760),
  retention_days smallint not null default 30
    check (retention_days between 1 and 90),
  legal_approved boolean not null default false,
  privacy_approved boolean not null default false,
  trained_reviewers_ready boolean not null default false,
  production_enabled boolean not null default false,
  updated_at timestamptz not null default now()
);
alter table private.teen_verification_control enable row level security;
revoke all on private.teen_verification_control from public, anon, authenticated;
grant select, insert, update, delete on private.teen_verification_control to service_role;

insert into private.teen_verification_control (singleton)
values (true)
on conflict (singleton) do nothing;

create table if not exists private.teen_verification_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  environment public.verification_environment not null,
  status text not null default 'created'
    check (status in (
      'created','school_email_required','document_required','document_submitted',
      'manual_review','age_evidence_required','verified','rejected','expired','cancelled'
    )),
  age_band text not null check (age_band in ('13_15','16_17')),
  school_email_verified_at timestamptz,
  school_domain_id uuid references public.school_domains(id) on delete set null,
  school_id_status text not null default 'required'
    check (school_id_status in ('required','submitted','under_review','recapture_required','reviewed','rejected')),
  age_status text not null default 'unresolved'
    check (age_status in ('unresolved','verified','mismatch','insufficient')),
  identity_status text not null default 'unresolved'
    check (identity_status in ('unresolved','verified','rejected')),
  decision_code text,
  reviewer_id uuid references public.profiles(id) on delete set null,
  submitted_at timestamptz,
  reviewed_at timestamptz,
  verified_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table private.teen_verification_sessions enable row level security;
revoke all on private.teen_verification_sessions from public, anon, authenticated;
grant select, insert, update, delete on private.teen_verification_sessions to service_role;

create unique index if not exists teen_verification_one_active_per_user
on private.teen_verification_sessions(user_id, environment)
where status not in ('verified','rejected','expired','cancelled');

create index if not exists teen_verification_review_queue_idx
on private.teen_verification_sessions(status, created_at)
where status in ('document_submitted','manual_review','age_evidence_required');

create table if not exists private.teen_school_id_documents (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references private.teen_verification_sessions(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  environment public.verification_environment not null,
  bucket_id text not null default 'teen-school-id'
    check (bucket_id = 'teen-school-id'),
  storage_path text not null unique,
  content_type text not null check (content_type = 'image/jpeg'),
  byte_size bigint not null check (byte_size between 1024 and 8388608),
  sha256 text not null check (sha256 ~ '^[a-f0-9]{64}$'),
  status text not null default 'submitted'
    check (status in ('submitted','under_review','reviewed','recapture_required','rejected','deleted')),
  submitted_at timestamptz not null default now(),
  retention_delete_at timestamptz not null default (now() + interval '30 days'),
  reviewed_at timestamptz,
  deleted_at timestamptz
);
alter table private.teen_school_id_documents enable row level security;
revoke all on private.teen_school_id_documents from public, anon, authenticated;
grant select, insert, update, delete on private.teen_school_id_documents to service_role;

create index if not exists teen_school_id_session_idx
on private.teen_school_id_documents(session_id, submitted_at desc);
create index if not exists teen_school_id_retention_idx
on private.teen_school_id_documents(retention_delete_at)
where deleted_at is null;
create index if not exists teen_school_id_hash_idx
on private.teen_school_id_documents(sha256);

create table if not exists private.teen_verification_review_assignments (
  session_id uuid primary key references private.teen_verification_sessions(id) on delete cascade,
  reviewer_id uuid not null references public.profiles(id) on delete cascade,
  case_id text not null,
  access_reason text not null,
  assigned_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '30 minutes'),
  revoked_at timestamptz
);
alter table private.teen_verification_review_assignments enable row level security;
revoke all on private.teen_verification_review_assignments from public, anon, authenticated;
grant select, insert, update, delete on private.teen_verification_review_assignments to service_role;

create table if not exists private.teen_school_id_access_grants (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references private.teen_school_id_documents(id) on delete cascade,
  reviewer_id uuid not null references public.profiles(id) on delete cascade,
  case_id text not null,
  access_reason text not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '5 minutes'),
  revoked_at timestamptz
);
alter table private.teen_school_id_access_grants enable row level security;
revoke all on private.teen_school_id_access_grants from public, anon, authenticated;
grant select, insert, update, delete on private.teen_school_id_access_grants to service_role;

create table if not exists private.teen_verification_audit_events (
  id bigint generated always as identity primary key,
  session_id uuid references private.teen_verification_sessions(id) on delete set null,
  document_id uuid references private.teen_school_id_documents(id) on delete set null,
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  safe_code text,
  case_id text,
  event_data jsonb not null default '{}'::jsonb
    check (jsonb_typeof(event_data) = 'object'),
  created_at timestamptz not null default now()
);
alter table private.teen_verification_audit_events enable row level security;
revoke all on private.teen_verification_audit_events from public, anon, authenticated;
grant select, insert, update, delete on private.teen_verification_audit_events to service_role;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'teen-school-id',
  'teen-school-id',
  false,
  8388608,
  array['image/jpeg']::text[]
)
on conflict (id) do update
set public = false,
    file_size_limit = 8388608,
    allowed_mime_types = array['image/jpeg']::text[];

create or replace function private.has_verified_school_affiliation(
  p_user_id uuid,
  p_environment public.verification_environment
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.trust_signal_events signal
    where signal.user_id = p_user_id
      and signal.signal_type = 'school_affiliation'
      and signal.status = 'verified'
      and signal.environment = p_environment
      and signal.revoked_at is null
      and (signal.expires_at is null or signal.expires_at > now())
  );
$$;

create or replace function private.teen_verification_submissions_enabled(
  p_user_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_control private.teen_verification_control%rowtype;
  v_profile public.profiles%rowtype;
begin
  select * into v_control
  from private.teen_verification_control control
  where control.singleton;
  select * into v_profile
  from public.profiles profile
  where profile.id = p_user_id
    and profile.account_status = 'active';

  if v_profile.id is null or v_profile.role <> 'teen' then
    return false;
  end if;
  if v_control.mode = 'sandbox' then
    return v_profile.is_test_account;
  end if;
  if v_control.mode = 'production' then
    return (not v_profile.is_test_account)
      and v_control.production_enabled
      and v_control.legal_approved
      and v_control.privacy_approved
      and v_control.trained_reviewers_ready;
  end if;
  return false;
end;
$$;

create or replace function private.can_upload_teen_school_id(
  p_session_id uuid,
  p_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from private.teen_verification_sessions session
    where session.id = p_session_id
      and session.user_id = p_user_id
      and session.status in ('created','school_email_required','document_required','document_submitted')
      and private.teen_verification_submissions_enabled(p_user_id)
  );
$$;

create or replace function private.can_delete_unregistered_teen_school_id(
  p_storage_path text,
  p_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    p_storage_path like p_user_id::text || '/%'
    and not exists (
      select 1
      from private.teen_school_id_documents document
      where document.storage_path = p_storage_path
        and document.deleted_at is null
    );
$$;

create or replace function private.can_read_teen_school_id(
  p_storage_path text,
  p_reviewer_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from private.teen_school_id_documents document
    join private.teen_verification_review_assignments assignment
      on assignment.session_id = document.session_id
     and assignment.reviewer_id = p_reviewer_id
     and assignment.revoked_at is null
     and assignment.expires_at > now()
    join private.teen_school_id_access_grants access_grant
      on access_grant.document_id = document.id
     and access_grant.reviewer_id = p_reviewer_id
     and access_grant.revoked_at is null
     and access_grant.expires_at > now()
    where document.storage_path = p_storage_path
      and document.deleted_at is null
      and private.has_trust_admin_role(
        p_reviewer_id,
        array['verification_reviewer','senior_verification_reviewer']::text[]
      )
  );
$$;

drop policy if exists teen_school_id_insert_own on storage.objects;
create policy teen_school_id_insert_own
on storage.objects for insert to authenticated
with check (
  bucket_id = 'teen-school-id'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and (storage.foldername(name))[2] ~ '^[0-9a-fA-F-]{36}$'
  and lower(storage.extension(name)) in ('jpg','jpeg')
  and private.can_upload_teen_school_id(
    ((storage.foldername(name))[2])::uuid,
    (select auth.uid())
  )
);

drop policy if exists teen_school_id_delete_unregistered_own on storage.objects;
create policy teen_school_id_delete_unregistered_own
on storage.objects for delete to authenticated
using (
  bucket_id = 'teen-school-id'
  and private.can_delete_unregistered_teen_school_id(
    name,
    (select auth.uid())
  )
);

drop policy if exists teen_school_id_reviewer_read on storage.objects;
create policy teen_school_id_reviewer_read
on storage.objects for select to authenticated
using (
  bucket_id = 'teen-school-id'
  and private.can_read_teen_school_id(name, (select auth.uid()))
);

create or replace function public.get_my_teen_verification()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_profile public.profiles%rowtype;
  v_control private.teen_verification_control%rowtype;
  v_environment public.verification_environment;
  v_session private.teen_verification_sessions%rowtype;
  v_school_verified boolean := false;
  v_submissions_enabled boolean := false;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  select * into v_profile
  from public.profiles profile
  where profile.id = auth.uid();
  if v_profile.id is null or v_profile.role <> 'teen' then
    return jsonb_build_object('ok', false, 'code', 'teen_account_required');
  end if;

  select * into v_control
  from private.teen_verification_control control
  where control.singleton;
  v_environment := private.user_trust_environment(auth.uid());
  v_school_verified := private.has_verified_school_affiliation(auth.uid(), v_environment);
  v_submissions_enabled := private.teen_verification_submissions_enabled(auth.uid());

  select * into v_session
  from private.teen_verification_sessions session
  where session.user_id = auth.uid()
    and session.environment = v_environment
  order by session.created_at desc
  limit 1;

  return jsonb_build_object(
    'ok', true,
    'mode', v_control.mode,
    'environment', v_environment,
    'submissions_enabled', v_submissions_enabled,
    'school_id_required', v_control.school_id_required,
    'school_email_required', v_control.school_email_required,
    'session_id', v_session.id,
    'status', coalesce(v_session.status, 'not_started'),
    'age_band', v_session.age_band,
    'school_email_verified', v_school_verified,
    'school_email_verified_at', coalesce(v_session.school_email_verified_at, null),
    'school_id_status', coalesce(v_session.school_id_status, 'required'),
    'age_status', coalesce(v_session.age_status, 'unresolved'),
    'identity_status', coalesce(v_session.identity_status, 'unresolved'),
    'decision_code', v_session.decision_code,
    'submitted_at', v_session.submitted_at,
    'reviewed_at', v_session.reviewed_at,
    'verified_at', v_session.verified_at,
    'expires_at', v_session.expires_at,
    'production_collection_enabled',
      v_control.mode = 'production'
      and v_control.production_enabled
      and v_control.legal_approved
      and v_control.privacy_approved
      and v_control.trained_reviewers_ready,
    'raw_document_public', false,
    'school_name_public', false
  );
end;
$$;

create or replace function public.start_my_teen_verification()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile public.profiles%rowtype;
  v_environment public.verification_environment;
  v_session private.teen_verification_sessions%rowtype;
  v_age integer;
  v_age_band text;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  select * into v_profile
  from public.profiles profile
  where profile.id = auth.uid()
    and profile.account_status = 'active';
  if v_profile.id is null or v_profile.role <> 'teen' then
    return jsonb_build_object('ok', false, 'code', 'teen_account_required');
  end if;
  if v_profile.dob is null then
    return jsonb_build_object('ok', false, 'code', 'date_of_birth_required');
  end if;

  v_age := extract(year from age(current_date, v_profile.dob))::integer;
  if v_age < 13 then
    return jsonb_build_object('ok', false, 'code', 'under_13_not_eligible');
  end if;
  if v_age >= 18 then
    return jsonb_build_object('ok', false, 'code', 'teen_account_age_mismatch');
  end if;
  if not private.teen_verification_submissions_enabled(auth.uid()) then
    return jsonb_build_object(
      'ok', false,
      'code', 'teen_verification_collection_not_enabled',
      'message', 'Teen verification collection is not enabled for this account.'
    );
  end if;

  v_environment := private.user_trust_environment(auth.uid());
  v_age_band := case when v_age <= 15 then '13_15' else '16_17' end;

  select * into v_session
  from private.teen_verification_sessions session
  where session.user_id = auth.uid()
    and session.environment = v_environment
    and session.status not in ('verified','rejected','expired','cancelled')
  order by session.created_at desc
  limit 1
  for update;

  if v_session.id is null then
    insert into private.teen_verification_sessions (
      user_id, environment, status, age_band
    ) values (
      auth.uid(), v_environment, 'school_email_required', v_age_band
    ) returning * into v_session;
    insert into private.teen_verification_audit_events (
      session_id, actor_id, action, safe_code
    ) values (
      v_session.id, auth.uid(), 'teen_verification_started', 'created'
    );
  end if;

  return jsonb_build_object(
    'ok', true,
    'session_id', v_session.id,
    'status', v_session.status,
    'age_band', v_session.age_band,
    'environment', v_session.environment
  );
end;
$$;

create or replace function public.sync_my_teen_school_affiliation(
  p_session_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session private.teen_verification_sessions%rowtype;
  v_signal public.trust_signal_events%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  select * into v_session
  from private.teen_verification_sessions session
  where session.id = p_session_id
    and session.user_id = auth.uid()
  for update;
  if v_session.id is null then
    return jsonb_build_object('ok', false, 'code', 'teen_verification_session_not_found');
  end if;

  select * into v_signal
  from public.trust_signal_events signal
  where signal.user_id = auth.uid()
    and signal.signal_type = 'school_affiliation'
    and signal.status = 'verified'
    and signal.environment = v_session.environment
    and signal.revoked_at is null
    and (signal.expires_at is null or signal.expires_at > now())
  order by signal.checked_at desc nulls last
  limit 1;

  if v_signal.id is null then
    return jsonb_build_object(
      'ok', true,
      'school_email_verified', false,
      'status', v_session.status
    );
  end if;

  update private.teen_verification_sessions
  set school_email_verified_at = coalesce(v_signal.checked_at, now()),
      school_domain_id = case
        when v_signal.source_kind = 'school_domain'
             and v_signal.source_reference ~ '^[0-9a-fA-F-]{36}$'
          then v_signal.source_reference::uuid
        else school_domain_id
      end,
      status = case
        when school_id_status in ('submitted','under_review','reviewed')
          then status
        else 'document_required'
      end,
      updated_at = now()
  where id = v_session.id
  returning * into v_session;

  return jsonb_build_object(
    'ok', true,
    'school_email_verified', true,
    'session_id', v_session.id,
    'status', v_session.status
  );
end;
$$;

create or replace function public.register_my_teen_school_id(
  p_session_id uuid,
  p_storage_path text,
  p_sha256 text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session private.teen_verification_sessions%rowtype;
  v_object storage.objects%rowtype;
  v_document private.teen_school_id_documents%rowtype;
  v_size bigint;
  v_content_type text;
  v_retention_days smallint;
  v_duplicate boolean := false;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  select * into v_session
  from private.teen_verification_sessions session
  where session.id = p_session_id
    and session.user_id = auth.uid()
  for update;
  if v_session.id is null then
    return jsonb_build_object('ok', false, 'code', 'teen_verification_session_not_found');
  end if;
  if not private.teen_verification_submissions_enabled(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'teen_verification_collection_not_enabled');
  end if;
  if p_storage_path !~ ('^' || auth.uid()::text || '/' || p_session_id::text ||
                        '/[0-9a-fA-F-]{36}[.](jpg|jpeg)$') then
    return jsonb_build_object('ok', false, 'code', 'school_id_storage_path_invalid');
  end if;
  if lower(coalesce(p_sha256, '')) !~ '^[a-f0-9]{64}$' then
    return jsonb_build_object('ok', false, 'code', 'school_id_hash_invalid');
  end if;

  select * into v_object
  from storage.objects object
  where object.bucket_id = 'teen-school-id'
    and object.name = p_storage_path
  limit 1;
  if v_object.id is null then
    return jsonb_build_object('ok', false, 'code', 'school_id_object_missing');
  end if;

  v_size := nullif(v_object.metadata->>'size', '')::bigint;
  v_content_type := lower(coalesce(
    v_object.metadata->>'mimetype',
    v_object.metadata->>'contentType',
    ''
  ));
  if v_content_type <> 'image/jpeg' or coalesce(v_size, 0) not between 1024 and 8388608 then
    return jsonb_build_object('ok', false, 'code', 'school_id_object_invalid');
  end if;

  select control.retention_days into v_retention_days
  from private.teen_verification_control control
  where control.singleton;

  select exists (
    select 1
    from private.teen_school_id_documents document
    where document.sha256 = lower(p_sha256)
      and document.user_id <> auth.uid()
      and document.deleted_at is null
  ) into v_duplicate;

  insert into private.teen_school_id_documents (
    session_id, user_id, environment, storage_path, content_type,
    byte_size, sha256, retention_delete_at
  ) values (
    v_session.id, auth.uid(), v_session.environment, p_storage_path,
    'image/jpeg', v_size, lower(p_sha256),
    now() + make_interval(days => v_retention_days)
  ) returning * into v_document;

  update private.teen_verification_sessions
  set school_id_status = 'submitted',
      status = case when private.has_verified_school_affiliation(auth.uid(), environment)
        then 'document_submitted' else 'school_email_required' end,
      updated_at = now()
  where id = v_session.id
  returning * into v_session;

  insert into private.teen_verification_audit_events (
    session_id, document_id, actor_id, action, safe_code, event_data
  ) values (
    v_session.id, v_document.id, auth.uid(), 'school_id_registered',
    case when v_duplicate then 'duplicate_hash_review' else 'registered' end,
    jsonb_build_object('exact_duplicate_hash_detected', v_duplicate)
  );

  return jsonb_build_object(
    'ok', true,
    'session_id', v_session.id,
    'document_id', v_document.id,
    'status', v_session.status,
    'school_id_status', v_session.school_id_status,
    'exact_duplicate_hash_detected', v_duplicate
  );
end;
$$;

create or replace function public.submit_my_teen_verification()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_environment public.verification_environment;
  v_session private.teen_verification_sessions%rowtype;
  v_document private.teen_school_id_documents%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  v_environment := private.user_trust_environment(auth.uid());

  select * into v_session
  from private.teen_verification_sessions session
  where session.user_id = auth.uid()
    and session.environment = v_environment
    and session.status not in ('verified','rejected','expired','cancelled')
  order by session.created_at desc
  limit 1
  for update;
  if v_session.id is null then
    return jsonb_build_object('ok', false, 'code', 'teen_verification_session_not_found');
  end if;
  if not private.has_verified_school_affiliation(auth.uid(), v_environment) then
    return jsonb_build_object('ok', false, 'code', 'verified_school_email_required');
  end if;

  select * into v_document
  from private.teen_school_id_documents document
  where document.session_id = v_session.id
    and document.deleted_at is null
    and document.status in ('submitted','recapture_required')
  order by document.submitted_at desc
  limit 1;
  if v_document.id is null then
    return jsonb_build_object('ok', false, 'code', 'school_id_required');
  end if;

  update private.teen_verification_sessions
  set school_email_verified_at = coalesce(school_email_verified_at, now()),
      school_id_status = 'under_review',
      status = 'manual_review',
      submitted_at = coalesce(submitted_at, now()),
      updated_at = now()
  where id = v_session.id
  returning * into v_session;

  update private.teen_school_id_documents
  set status = 'under_review'
  where id = v_document.id;

  perform set_config('mort.internal_update', 'true', true);
  update public.profiles
  set verification_status = 'pending'::public.verification_status,
      updated_at = now()
  where id = auth.uid();
  perform set_config('mort.internal_update', '', true);

  insert into private.teen_verification_audit_events (
    session_id, document_id, actor_id, action, safe_code
  ) values (
    v_session.id, v_document.id, auth.uid(), 'teen_verification_submitted', 'manual_review'
  );

  return jsonb_build_object(
    'ok', true,
    'session_id', v_session.id,
    'status', v_session.status,
    'school_email_verified', true,
    'school_id_status', v_session.school_id_status
  );
end;
$$;

create or replace function public.get_teen_verification_review_queue(
  p_access_reason text,
  p_case_id text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_items jsonb := '[]'::jsonb;
begin
  if auth.uid() is null or not private.has_trust_admin_role(
    auth.uid(),
    array['verification_reviewer','senior_verification_reviewer']::text[]
  ) then
    return jsonb_build_object('ok', false, 'code', 'verification_reviewer_required');
  end if;
  if not private.trust_admin_context_valid(p_access_reason, p_case_id) then
    return jsonb_build_object('ok', false, 'code', 'admin_access_reason_and_case_required');
  end if;

  select coalesce(jsonb_agg(item), '[]'::jsonb) into v_items
  from (
    select jsonb_build_object(
      'session_id', session.id,
      'user_id', session.user_id,
      'environment', session.environment,
      'status', session.status,
      'age_band', session.age_band,
      'school_email_verified', private.has_verified_school_affiliation(session.user_id, session.environment),
      'school_id_status', session.school_id_status,
      'age_status', session.age_status,
      'identity_status', session.identity_status,
      'submitted_at', session.submitted_at,
      'created_at', session.created_at
    ) as item
    from private.teen_verification_sessions session
    where session.status in ('document_submitted','manual_review','age_evidence_required')
    order by coalesce(session.submitted_at, session.created_at)
    limit 100
  ) queue;

  insert into private.teen_verification_audit_events (
    actor_id, action, safe_code, case_id, event_data
  ) values (
    auth.uid(), 'teen_verification_queue_accessed', 'metadata_only',
    btrim(p_case_id),
    jsonb_build_object('access_reason', left(btrim(p_access_reason), 800))
  );

  return jsonb_build_object(
    'ok', true,
    'items', v_items,
    'raw_document_paths_included', false
  );
end;
$$;

create or replace function public.claim_teen_verification_review(
  p_session_id uuid,
  p_access_reason text,
  p_case_id text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session private.teen_verification_sessions%rowtype;
begin
  if auth.uid() is null or not private.has_trust_admin_role(
    auth.uid(),
    array['verification_reviewer','senior_verification_reviewer']::text[]
  ) then
    return jsonb_build_object('ok', false, 'code', 'verification_reviewer_required');
  end if;
  if not private.trust_admin_context_valid(p_access_reason, p_case_id) then
    return jsonb_build_object('ok', false, 'code', 'admin_access_reason_and_case_required');
  end if;

  select * into v_session
  from private.teen_verification_sessions session
  where session.id = p_session_id
    and session.status in ('document_submitted','manual_review','age_evidence_required')
  for update;
  if v_session.id is null then
    return jsonb_build_object('ok', false, 'code', 'review_case_unavailable');
  end if;

  insert into private.teen_verification_review_assignments (
    session_id, reviewer_id, case_id, access_reason, expires_at, revoked_at
  ) values (
    v_session.id, auth.uid(), btrim(p_case_id), left(btrim(p_access_reason), 800),
    now() + interval '30 minutes', null
  )
  on conflict (session_id) do update
  set reviewer_id = case
        when private.teen_verification_review_assignments.revoked_at is not null
          or private.teen_verification_review_assignments.expires_at <= now()
          or private.teen_verification_review_assignments.reviewer_id = auth.uid()
        then excluded.reviewer_id
        else private.teen_verification_review_assignments.reviewer_id
      end,
      case_id = case
        when private.teen_verification_review_assignments.revoked_at is not null
          or private.teen_verification_review_assignments.expires_at <= now()
          or private.teen_verification_review_assignments.reviewer_id = auth.uid()
        then excluded.case_id
        else private.teen_verification_review_assignments.case_id
      end,
      access_reason = case
        when private.teen_verification_review_assignments.revoked_at is not null
          or private.teen_verification_review_assignments.expires_at <= now()
          or private.teen_verification_review_assignments.reviewer_id = auth.uid()
        then excluded.access_reason
        else private.teen_verification_review_assignments.access_reason
      end,
      assigned_at = case
        when private.teen_verification_review_assignments.revoked_at is not null
          or private.teen_verification_review_assignments.expires_at <= now()
          or private.teen_verification_review_assignments.reviewer_id = auth.uid()
        then now()
        else private.teen_verification_review_assignments.assigned_at
      end,
      expires_at = case
        when private.teen_verification_review_assignments.revoked_at is not null
          or private.teen_verification_review_assignments.expires_at <= now()
          or private.teen_verification_review_assignments.reviewer_id = auth.uid()
        then excluded.expires_at
        else private.teen_verification_review_assignments.expires_at
      end,
      revoked_at = case
        when private.teen_verification_review_assignments.revoked_at is not null
          or private.teen_verification_review_assignments.expires_at <= now()
          or private.teen_verification_review_assignments.reviewer_id = auth.uid()
        then null
        else private.teen_verification_review_assignments.revoked_at
      end;

  if not exists (
    select 1
    from private.teen_verification_review_assignments assignment
    where assignment.session_id = v_session.id
      and assignment.reviewer_id = auth.uid()
      and assignment.revoked_at is null
      and assignment.expires_at > now()
  ) then
    return jsonb_build_object('ok', false, 'code', 'review_case_already_claimed');
  end if;

  insert into private.teen_verification_audit_events (
    session_id, actor_id, action, safe_code, case_id
  ) values (
    v_session.id, auth.uid(), 'teen_verification_case_claimed', 'claimed', btrim(p_case_id)
  );

  return jsonb_build_object(
    'ok', true,
    'session_id', v_session.id,
    'assignment_expires_at', now() + interval '30 minutes'
  );
end;
$$;

create or replace function public.authorize_teen_school_id_access(
  p_session_id uuid,
  p_access_reason text,
  p_case_id text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_document private.teen_school_id_documents%rowtype;
  v_grant private.teen_school_id_access_grants%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if not private.trust_admin_context_valid(p_access_reason, p_case_id) then
    return jsonb_build_object('ok', false, 'code', 'admin_access_reason_and_case_required');
  end if;
  if not exists (
    select 1
    from private.teen_verification_review_assignments assignment
    where assignment.session_id = p_session_id
      and assignment.reviewer_id = auth.uid()
      and assignment.revoked_at is null
      and assignment.expires_at > now()
  ) then
    return jsonb_build_object('ok', false, 'code', 'active_review_assignment_required');
  end if;

  select * into v_document
  from private.teen_school_id_documents document
  where document.session_id = p_session_id
    and document.deleted_at is null
    and document.status in ('submitted','under_review','recapture_required')
  order by document.submitted_at desc
  limit 1;
  if v_document.id is null then
    return jsonb_build_object('ok', false, 'code', 'school_id_document_not_found');
  end if;

  insert into private.teen_school_id_access_grants (
    document_id, reviewer_id, case_id, access_reason, expires_at
  ) values (
    v_document.id, auth.uid(), btrim(p_case_id),
    left(btrim(p_access_reason), 800), now() + interval '5 minutes'
  ) returning * into v_grant;

  insert into private.teen_verification_audit_events (
    session_id, document_id, actor_id, action, safe_code, case_id
  ) values (
    p_session_id, v_document.id, auth.uid(),
    'teen_school_id_access_authorized', 'five_minute_grant', btrim(p_case_id)
  );

  return jsonb_build_object(
    'ok', true,
    'bucket_id', v_document.bucket_id,
    'storage_path', v_document.storage_path,
    'document_id', v_document.id,
    'expires_at', v_grant.expires_at
  );
end;
$$;

create or replace function public.review_teen_verification(
  p_session_id uuid,
  p_action text,
  p_school_id_current boolean,
  p_school_match boolean,
  p_name_match boolean,
  p_school_id_dob_present boolean,
  p_observed_age_band text,
  p_suspected_tamper boolean,
  p_decision_code text,
  p_access_reason text,
  p_case_id text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session private.teen_verification_sessions%rowtype;
  v_document private.teen_school_id_documents%rowtype;
  v_action text := lower(btrim(coalesce(p_action, '')));
  v_school_verified boolean := false;
  v_verified boolean := false;
  v_expires_at timestamptz;
begin
  if auth.uid() is null or not private.has_trust_admin_role(
    auth.uid(),
    array['verification_reviewer','senior_verification_reviewer']::text[]
  ) then
    return jsonb_build_object('ok', false, 'code', 'verification_reviewer_required');
  end if;
  if not private.trust_admin_context_valid(p_access_reason, p_case_id) then
    return jsonb_build_object('ok', false, 'code', 'admin_access_reason_and_case_required');
  end if;
  if v_action not in ('approve','reject','request_recapture','age_evidence_required') then
    return jsonb_build_object('ok', false, 'code', 'review_action_invalid');
  end if;
  if char_length(btrim(coalesce(p_decision_code, ''))) not between 3 and 100 then
    return jsonb_build_object('ok', false, 'code', 'decision_code_required');
  end if;

  if not exists (
    select 1
    from private.teen_verification_review_assignments assignment
    where assignment.session_id = p_session_id
      and assignment.reviewer_id = auth.uid()
      and assignment.revoked_at is null
      and assignment.expires_at > now()
  ) then
    return jsonb_build_object('ok', false, 'code', 'active_review_assignment_required');
  end if;

  select * into v_session
  from private.teen_verification_sessions session
  where session.id = p_session_id
    and session.status in ('document_submitted','manual_review','age_evidence_required')
  for update;
  if v_session.id is null then
    return jsonb_build_object('ok', false, 'code', 'review_case_unavailable');
  end if;

  select * into v_document
  from private.teen_school_id_documents document
  where document.session_id = v_session.id
    and document.deleted_at is null
  order by document.submitted_at desc
  limit 1;
  if v_document.id is null then
    return jsonb_build_object('ok', false, 'code', 'school_id_document_not_found');
  end if;

  v_school_verified := private.has_verified_school_affiliation(v_session.user_id, v_session.environment);

  if v_action = 'approve' then
    if not v_school_verified then
      return jsonb_build_object('ok', false, 'code', 'verified_school_email_required');
    end if;
    if not coalesce(p_school_id_current, false)
       or not coalesce(p_school_match, false)
       or not coalesce(p_name_match, false)
       or coalesce(p_suspected_tamper, false) then
      return jsonb_build_object('ok', false, 'code', 'school_id_review_not_passed');
    end if;
    if not coalesce(p_school_id_dob_present, false)
       or p_observed_age_band not in ('13_15','16_17')
       or p_observed_age_band <> v_session.age_band then
      return jsonb_build_object(
        'ok', false,
        'code', 'age_evidence_required',
        'message', 'School affiliation is verified, but the submitted school ID did not independently support the claimed teen age band.'
      );
    end if;

    v_expires_at := least(
      now() + interval '1 year',
      (
        select (profile.dob + interval '18 years')::timestamptz
        from public.profiles profile
        where profile.id = v_session.user_id
      )
    );
    update private.teen_verification_sessions
    set status = 'verified',
        school_email_verified_at = coalesce(school_email_verified_at, now()),
        school_id_status = 'reviewed',
        age_status = 'verified',
        identity_status = 'verified',
        decision_code = left(btrim(p_decision_code), 100),
        reviewer_id = auth.uid(),
        reviewed_at = now(),
        verified_at = now(),
        expires_at = v_expires_at,
        updated_at = now()
    where id = v_session.id
    returning * into v_session;
    update private.teen_school_id_documents
    set status = 'reviewed', reviewed_at = now()
    where id = v_document.id;

    perform set_config('mort.internal_update', 'true', true);
    update public.profiles
    set verification_status = 'approved'::public.verification_status,
        updated_at = now()
    where id = v_session.user_id;
    perform set_config('mort.internal_update', '', true);
    v_verified := true;

  elsif v_action = 'request_recapture' then
    update private.teen_verification_sessions
    set status = 'document_required',
        school_id_status = 'recapture_required',
        decision_code = left(btrim(p_decision_code), 100),
        reviewer_id = auth.uid(),
        reviewed_at = now(),
        updated_at = now()
    where id = v_session.id
    returning * into v_session;
    update private.teen_school_id_documents
    set status = 'recapture_required', reviewed_at = now()
    where id = v_document.id;

  elsif v_action = 'age_evidence_required' then
    update private.teen_verification_sessions
    set status = 'age_evidence_required',
        school_id_status = case
          when coalesce(p_school_id_current,false)
           and coalesce(p_school_match,false)
           and coalesce(p_name_match,false)
           and not coalesce(p_suspected_tamper,false)
          then 'reviewed' else 'rejected' end,
        age_status = 'insufficient',
        decision_code = left(btrim(p_decision_code), 100),
        reviewer_id = auth.uid(),
        reviewed_at = now(),
        updated_at = now()
    where id = v_session.id
    returning * into v_session;

  else
    update private.teen_verification_sessions
    set status = 'rejected',
        school_id_status = 'rejected',
        age_status = case when p_observed_age_band is not null
          and p_observed_age_band <> age_band then 'mismatch' else age_status end,
        identity_status = 'rejected',
        decision_code = left(btrim(p_decision_code), 100),
        reviewer_id = auth.uid(),
        reviewed_at = now(),
        updated_at = now()
    where id = v_session.id
    returning * into v_session;
    update private.teen_school_id_documents
    set status = 'rejected', reviewed_at = now()
    where id = v_document.id;

    perform set_config('mort.internal_update', 'true', true);
    update public.profiles
    set verification_status = 'rejected'::public.verification_status,
        updated_at = now()
    where id = v_session.user_id;
    perform set_config('mort.internal_update', '', true);
  end if;

  update private.teen_verification_review_assignments
  set revoked_at = now()
  where session_id = v_session.id
    and reviewer_id = auth.uid()
    and revoked_at is null;

  update private.teen_school_id_access_grants
  set revoked_at = now()
  where document_id = v_document.id
    and reviewer_id = auth.uid()
    and revoked_at is null;

  insert into private.teen_verification_audit_events (
    session_id, document_id, actor_id, action, safe_code, case_id, event_data
  ) values (
    v_session.id, v_document.id, auth.uid(), 'teen_verification_reviewed',
    left(btrim(p_decision_code), 100), btrim(p_case_id),
    jsonb_build_object(
      'action', v_action,
      'school_id_current', coalesce(p_school_id_current,false),
      'school_match', coalesce(p_school_match,false),
      'name_match', coalesce(p_name_match,false),
      'school_id_dob_present', coalesce(p_school_id_dob_present,false),
      'age_band_match', p_observed_age_band = v_session.age_band,
      'suspected_tamper', coalesce(p_suspected_tamper,false)
    )
  );

  return jsonb_build_object(
    'ok', true,
    'session_id', v_session.id,
    'status', v_session.status,
    'age_status', v_session.age_status,
    'identity_status', v_session.identity_status,
    'verified', v_verified,
    'expires_at', v_session.expires_at
  );
end;
$$;

revoke all on function private.has_verified_school_affiliation(uuid, public.verification_environment) from public, anon, authenticated;
revoke all on function private.teen_verification_submissions_enabled(uuid) from public, anon, authenticated;
revoke all on function private.can_upload_teen_school_id(uuid, uuid) from public, anon, authenticated;
revoke all on function private.can_delete_unregistered_teen_school_id(text, uuid) from public, anon, authenticated;
revoke all on function private.can_read_teen_school_id(text, uuid) from public, anon, authenticated;

grant execute on function private.has_verified_school_affiliation(uuid, public.verification_environment) to service_role;
grant execute on function private.teen_verification_submissions_enabled(uuid) to service_role;
grant execute on function private.can_upload_teen_school_id(uuid, uuid) to authenticated, service_role;
grant execute on function private.can_delete_unregistered_teen_school_id(text, uuid) to authenticated, service_role;
grant execute on function private.can_read_teen_school_id(text, uuid) to authenticated, service_role;

revoke all on function public.get_my_teen_verification() from public, anon;
revoke all on function public.start_my_teen_verification() from public, anon;
revoke all on function public.sync_my_teen_school_affiliation(uuid) from public, anon;
revoke all on function public.register_my_teen_school_id(uuid,text,text) from public, anon;
revoke all on function public.submit_my_teen_verification() from public, anon;
revoke all on function public.get_teen_verification_review_queue(text,text) from public, anon;
revoke all on function public.claim_teen_verification_review(uuid,text,text) from public, anon;
revoke all on function public.authorize_teen_school_id_access(uuid,text,text) from public, anon;
revoke all on function public.review_teen_verification(uuid,text,boolean,boolean,boolean,boolean,text,boolean,text,text,text) from public, anon;

grant execute on function public.get_my_teen_verification() to authenticated, service_role;
grant execute on function public.start_my_teen_verification() to authenticated, service_role;
grant execute on function public.sync_my_teen_school_affiliation(uuid) to authenticated, service_role;
grant execute on function public.register_my_teen_school_id(uuid,text,text) to authenticated, service_role;
grant execute on function public.submit_my_teen_verification() to authenticated, service_role;
grant execute on function public.get_teen_verification_review_queue(text,text) to authenticated, service_role;
grant execute on function public.claim_teen_verification_review(uuid,text,text) to authenticated, service_role;
grant execute on function public.authorize_teen_school_id_access(uuid,text,text) to authenticated, service_role;
grant execute on function public.review_teen_verification(uuid,text,boolean,boolean,boolean,boolean,text,boolean,text,text,text) to authenticated, service_role;

comment on table private.teen_school_id_documents is
  'Restricted teen school-ID evidence metadata. Raw objects remain private in Storage and are never public profile data.';
comment on table private.teen_verification_sessions is
  'MORT Verify teen age/school workflow. Production collection is gated separately from the existing adult provider system.';
