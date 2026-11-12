-- MORT Verify v1: first-party teen school affiliation + age assurance.
-- This is additive and fail-closed. Production document collection remains
-- disabled until the control row is explicitly approved server-side.

create table if not exists private.mort_verify_control (
  singleton boolean primary key default true check (singleton),
  mode text not null default 'disabled'
    check (mode in ('disabled','sandbox','production')),
  school_email_enabled boolean not null default false,
  school_id_enabled boolean not null default false,
  manual_review_enabled boolean not null default false,
  production_document_collection_approved boolean not null default false,
  raw_document_retention_days integer not null default 14
    check (raw_document_retention_days between 1 and 30),
  session_ttl_hours integer not null default 24
    check (session_ttl_hours between 1 and 72),
  updated_at timestamptz not null default now(),
  updated_by uuid references public.profiles(id) on delete set null
);

insert into private.mort_verify_control(singleton)
values (true)
on conflict (singleton) do nothing;

create table if not exists private.mort_verify_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  identity_verification_id uuid not null unique
    references public.identity_verifications(id) on delete cascade,
  environment public.verification_environment not null,
  school_domain_id uuid references public.school_domains(id) on delete restrict,
  school_email text,
  school_email_hash text,
  claimed_dob date not null,
  status text not null default 'email_pending'
    check (status in (
      'email_pending','school_id_required','document_pending','manual_review',
      'needs_age_evidence','verified','rejected','expired','cancelled'
    )),
  school_email_verified_at timestamptz,
  school_affiliation_verified_at timestamptz,
  student_identity_verified_at timestamptz,
  age_verified_at timestamptz,
  verified_age_band text
    check (verified_age_band is null or verified_age_band in ('13_15','16_17')),
  age_evidence_kind text
    check (age_evidence_kind is null or age_evidence_kind in (
      'school_id_dob','school_record','government_id_age_only','manual_exception'
    )),
  submitted_at timestamptz,
  reviewed_at timestamptz,
  reviewer_id uuid references public.profiles(id) on delete set null,
  decision_code text,
  expires_at timestamptz not null,
  retention_delete_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint mort_verify_school_email_length
    check (school_email is null or char_length(school_email) between 3 and 320),
  constraint mort_verify_email_hash_format
    check (school_email_hash is null or school_email_hash ~ '^[A-Fa-f0-9]{64}$'),
  constraint mort_verify_decision_code_length
    check (decision_code is null or char_length(decision_code) <= 120)
);

create unique index if not exists mort_verify_one_open_session_idx
on private.mort_verify_sessions(user_id)
where status in (
  'email_pending','school_id_required','document_pending','manual_review',
  'needs_age_evidence'
);

create index if not exists mort_verify_review_queue_idx
on private.mort_verify_sessions(status, submitted_at, created_at);

create index if not exists mort_verify_retention_idx
on private.mort_verify_sessions(retention_delete_at);

create table if not exists private.mort_verify_email_challenges (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references private.mort_verify_sessions(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  code_hash text not null check (code_hash ~ '^[A-Fa-f0-9]{64}$'),
  delivery_status text not null default 'queued'
    check (delivery_status in ('queued','sent','failed','consumed','expired')),
  attempts integer not null default 0 check (attempts between 0 and 10),
  expires_at timestamptz not null,
  consumed_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists mort_verify_email_challenge_lookup_idx
on private.mort_verify_email_challenges(session_id, created_at desc);

create table if not exists private.mort_verify_documents (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references private.mort_verify_sessions(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  side text not null check (side in ('front','back')),
  bucket_id text not null default 'mort-verify-evidence'
    check (bucket_id = 'mort-verify-evidence'),
  storage_path text not null unique,
  content_type text not null
    check (content_type in ('image/jpeg','image/png','application/pdf')),
  byte_size bigint not null check (byte_size between 1 and 10485760),
  sha256 text not null check (sha256 ~ '^[A-Fa-f0-9]{64}$'),
  status text not null default 'active'
    check (status in ('active','superseded','rejected','deleted')),
  review_result text not null default 'pending'
    check (review_result in ('pending','accepted','recapture_required','rejected')),
  retention_delete_at timestamptz not null,
  preserved_until timestamptz,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewer_id uuid references public.profiles(id) on delete set null
);

create unique index if not exists mort_verify_document_active_side_idx
on private.mort_verify_documents(session_id, side)
where status = 'active';

create index if not exists mort_verify_document_fingerprint_idx
on private.mort_verify_documents(sha256)
where status = 'active';

create index if not exists mort_verify_document_retention_idx
on private.mort_verify_documents(retention_delete_at)
where preserved_until is null and status <> 'deleted';

create table if not exists private.mort_verify_review_assignments (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references private.mort_verify_sessions(id) on delete cascade,
  reviewer_id uuid not null references public.profiles(id) on delete cascade,
  access_reason text not null,
  assigned_at timestamptz not null default now(),
  expires_at timestamptz not null,
  revoked_at timestamptz,
  constraint mort_verify_review_reason_length
    check (char_length(access_reason) between 10 and 500),
  constraint mort_verify_review_assignment_ttl
    check (expires_at > assigned_at and expires_at <= assigned_at + interval '30 minutes')
);

create unique index if not exists mort_verify_active_assignment_idx
on private.mort_verify_review_assignments(session_id)
where revoked_at is null;

create table if not exists private.mort_verify_audit_events (
  id bigint generated always as identity primary key,
  session_id uuid references private.mort_verify_sessions(id) on delete set null,
  user_id uuid references public.profiles(id) on delete set null,
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  safe_metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint mort_verify_audit_action_length
    check (char_length(action) between 2 and 100)
);

create index if not exists mort_verify_audit_session_idx
on private.mort_verify_audit_events(session_id, created_at desc);

alter table private.mort_verify_control enable row level security;
alter table private.mort_verify_sessions enable row level security;
alter table private.mort_verify_email_challenges enable row level security;
alter table private.mort_verify_documents enable row level security;
alter table private.mort_verify_review_assignments enable row level security;
alter table private.mort_verify_audit_events enable row level security;

revoke all on private.mort_verify_control,
  private.mort_verify_sessions,
  private.mort_verify_email_challenges,
  private.mort_verify_documents,
  private.mort_verify_review_assignments,
  private.mort_verify_audit_events
from public, anon, authenticated;

insert into storage.buckets (
  id, name, public, file_size_limit, allowed_mime_types
) values (
  'mort-verify-evidence',
  'mort-verify-evidence',
  false,
  10485760,
  array['image/jpeg','image/png','application/pdf']
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists mort_verify_owner_upload on storage.objects;
create policy mort_verify_owner_upload
on storage.objects for insert to authenticated
with check (
  bucket_id = 'mort-verify-evidence'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and (storage.foldername(name))[2] ~ '^[0-9a-fA-F-]{36}$'
  and (storage.foldername(name))[3] in ('front','back')
  and name !~ '(^|/)\\.\\.(/|$)'
  and lower(storage.extension(name)) in ('jpg','jpeg','png','pdf')
  and exists (
    select 1
    from private.mort_verify_sessions session
    where session.id::text = (storage.foldername(name))[2]
      and session.user_id = (select auth.uid())
      and session.status in ('school_id_required','document_pending')
      and session.expires_at > now()
  )
);

drop policy if exists mort_verify_owner_delete_unregistered on storage.objects;
create policy mort_verify_owner_delete_unregistered
on storage.objects for delete to authenticated
using (
  bucket_id = 'mort-verify-evidence'
  and owner_id = (select auth.uid())::text
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and not exists (
    select 1 from private.mort_verify_documents document
    where document.storage_path = name
      and document.status = 'active'
  )
);

create or replace function private.mort_verify_control_row()
returns private.mort_verify_control
language sql
stable
security definer
set search_path = ''
as $$
  select control
  from private.mort_verify_control control
  where control.singleton
$$;

revoke all on function private.mort_verify_control_row()
from public, anon, authenticated;

create or replace function public.get_mort_verify_status()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_control private.mort_verify_control%rowtype;
  v_session private.mort_verify_sessions%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;

  select * into v_control from private.mort_verify_control_row();
  select * into v_session
  from private.mort_verify_sessions session
  where session.user_id = auth.uid()
  order by session.created_at desc
  limit 1;

  return jsonb_build_object(
    'ok', true,
    'mode', v_control.mode,
    'available',
      v_control.mode <> 'disabled'
      and v_control.school_email_enabled
      and v_control.school_id_enabled,
    'school_email_enabled', v_control.school_email_enabled,
    'school_id_enabled', v_control.school_id_enabled,
    'manual_review_enabled', v_control.manual_review_enabled,
    'session', case when v_session.id is null then null else jsonb_build_object(
      'id', v_session.id,
      'status', v_session.status,
      'school_email_verified', v_session.school_email_verified_at is not null,
      'school_affiliation_verified', v_session.school_affiliation_verified_at is not null,
      'student_identity_verified', v_session.student_identity_verified_at is not null,
      'age_verified', v_session.age_verified_at is not null,
      'age_band', v_session.verified_age_band,
      'expires_at', v_session.expires_at
    ) end
  );
end;
$$;

revoke all on function public.get_mort_verify_status()
from public, anon;
grant execute on function public.get_mort_verify_status()
to authenticated;

create or replace function public.start_mort_verify_teen_session(
  p_school_email text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_control private.mort_verify_control%rowtype;
  v_profile public.profiles%rowtype;
  v_domain text;
  v_school public.school_domains%rowtype;
  v_environment public.verification_environment;
  v_session_id uuid := gen_random_uuid();
  v_verification public.identity_verifications%rowtype;
  v_age integer;
  v_email text := lower(btrim(coalesce(p_school_email, '')));
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;

  select * into v_control from private.mort_verify_control_row();
  if v_control.mode = 'disabled'
     or not v_control.school_email_enabled
     or not v_control.school_id_enabled then
    return jsonb_build_object(
      'ok', false,
      'code', 'mort_verify_disabled',
      'message', 'MORT Verify is not accepting submissions yet.'
    );
  end if;

  select * into v_profile
  from public.profiles profile
  where profile.id = auth.uid();

  if v_profile.id is null or v_profile.role <> 'teen' or v_profile.dob is null then
    return jsonb_build_object('ok', false, 'code', 'teen_profile_age_required');
  end if;

  v_age := date_part('year', age(current_date, v_profile.dob))::integer;
  if v_age < 13 then
    return jsonb_build_object('ok', false, 'code', 'under_13_not_eligible');
  end if;
  if v_age >= 18 then
    return jsonb_build_object('ok', false, 'code', 'adult_account_required');
  end if;

  if v_control.mode = 'sandbox' and not v_profile.is_test_account then
    return jsonb_build_object('ok', false, 'code', 'sandbox_test_account_required');
  end if;
  if v_control.mode = 'production' and not v_control.production_document_collection_approved then
    return jsonb_build_object('ok', false, 'code', 'production_collection_not_approved');
  end if;

  if char_length(v_email) < 3
     or char_length(v_email) > 320
     or position('@' in v_email) <= 1 then
    return jsonb_build_object('ok', false, 'code', 'invalid_school_email');
  end if;

  if exists (
    select 1 from private.mort_verify_sessions session
    where session.user_id = auth.uid()
      and session.status in (
        'email_pending','school_id_required','document_pending',
        'manual_review','needs_age_evidence'
      )
  ) then
    return jsonb_build_object('ok', false, 'code', 'mort_verify_session_already_active');
  end if;

  v_environment := case
    when v_control.mode = 'sandbox' then 'sandbox'::public.verification_environment
    else 'production'::public.verification_environment
  end;

  v_domain := lower(split_part(v_email, '@', 2));

  select * into v_school
  from public.school_domains school
  where school.normalized_domain = v_domain
    and school.environment = v_environment
    and school.status = 'approved'
    and (school.expires_at is null or school.expires_at > now())
  order by school.approved_at desc nulls last, school.created_at desc
  limit 1;

  if v_school.id is null then
    return jsonb_build_object(
      'ok', false,
      'code', 'school_domain_not_approved',
      'message', 'That school email domain has not been approved for MORT Verify.'
    );
  end if;

  if exists (
    select 1 from public.identity_verifications verification
    where verification.user_id = auth.uid()
      and verification.status in (
        'verification_started','verification_pending',
        'additional_information_required','manual_review','appeal_pending'
      )
  ) then
    return jsonb_build_object('ok', false, 'code', 'identity_verification_already_active');
  end if;

  insert into public.identity_verifications (
    id,
    user_id,
    account_role,
    evidence_route,
    provider,
    provider_reference,
    status,
    verification_level,
    age_band,
    identity_match_result,
    liveness_result,
    email_verification_result,
    phone_verification_result,
    address_validation_result,
    submitted_at,
    retention_delete_at,
    risk_flags,
    audit_version,
    environment,
    decision_source
  ) values (
    gen_random_uuid(),
    auth.uid(),
    'teen',
    'school_photo_id',
    'mort_verify',
    'mort-verify:' || v_session_id::text,
    'verification_started',
    0,
    'teen_13_17',
    'not_checked',
    'not_checked',
    'pending',
    'not_checked',
    'not_checked',
    null,
    now() + make_interval(days => v_control.raw_document_retention_days),
    jsonb_build_object(
      'school_domain_id', v_school.id,
      'first_party', true,
      'legal_identity_claimed', false,
      'age_claim_only', true
    ),
    'mort-verify-v1',
    v_environment,
    'mort_verify_pending'
  ) returning * into v_verification;

  insert into private.mort_verify_sessions (
    id,
    user_id,
    identity_verification_id,
    environment,
    school_domain_id,
    school_email,
    school_email_hash,
    claimed_dob,
    status,
    expires_at,
    retention_delete_at
  ) values (
    v_session_id,
    auth.uid(),
    v_verification.id,
    v_environment,
    v_school.id,
    v_email,
    encode(digest(convert_to(v_email, 'UTF8'), 'sha256'), 'hex'),
    v_profile.dob,
    'email_pending',
    now() + make_interval(hours => v_control.session_ttl_hours),
    now() + make_interval(days => v_control.raw_document_retention_days)
  );

  insert into private.mort_verify_audit_events(
    session_id,user_id,actor_id,action,safe_metadata
  ) values (
    v_session_id,auth.uid(),auth.uid(),'session_started',
    jsonb_build_object(
      'environment', v_environment,
      'school_domain_id', v_school.id,
      'claimed_age_eligible', true
    )
  );

  return jsonb_build_object(
    'ok', true,
    'session_id', v_session_id,
    'status', 'email_pending',
    'school', v_school.organization_name,
    'email_masked',
      left(split_part(v_email,'@',1), 1) || '***@' || v_domain,
    'age_verified', false,
    'school_affiliation_verified', false,
    'student_identity_verified', false,
    'expires_at', now() + make_interval(hours => v_control.session_ttl_hours)
  );
end;
$$;

revoke all on function public.start_mort_verify_teen_session(text)
from public, anon;
grant execute on function public.start_mort_verify_teen_session(text)
to authenticated;

create or replace function public.service_mort_verify_issue_email_challenge(
  p_user_id uuid,
  p_session_id uuid,
  p_code_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session private.mort_verify_sessions%rowtype;
  v_recent_count integer;
  v_last_created timestamptz;
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then
    return jsonb_build_object('ok', false, 'code', 'service_role_required');
  end if;
  if p_code_hash is null or p_code_hash !~ '^[A-Fa-f0-9]{64}$' then
    return jsonb_build_object('ok', false, 'code', 'invalid_code_hash');
  end if;

  select * into v_session
  from private.mort_verify_sessions session
  where session.id = p_session_id
    and session.user_id = p_user_id
    and session.status = 'email_pending'
    and session.expires_at > now()
  for update;

  if v_session.id is null then
    return jsonb_build_object('ok', false, 'code', 'session_not_available');
  end if;

  select count(*), max(challenge.created_at)
  into v_recent_count, v_last_created
  from private.mort_verify_email_challenges challenge
  where challenge.user_id = p_user_id
    and challenge.created_at > now() - interval '1 hour';

  if v_recent_count >= 5 then
    return jsonb_build_object('ok', false, 'code', 'email_challenge_rate_limited');
  end if;
  if v_last_created is not null and v_last_created > now() - interval '60 seconds' then
    return jsonb_build_object('ok', false, 'code', 'email_challenge_cooldown');
  end if;

  update private.mort_verify_email_challenges
  set delivery_status = 'expired'
  where session_id = p_session_id
    and consumed_at is null
    and delivery_status in ('queued','sent')
    and expires_at > now();

  insert into private.mort_verify_email_challenges(
    session_id,user_id,code_hash,delivery_status,expires_at
  ) values (
    p_session_id,p_user_id,lower(p_code_hash),'queued',now() + interval '15 minutes'
  );

  return jsonb_build_object(
    'ok', true,
    'email', v_session.school_email,
    'expires_at', now() + interval '15 minutes'
  );
end;
$$;

revoke all on function public.service_mort_verify_issue_email_challenge(uuid,uuid,text)
from public, anon, authenticated;
grant execute on function public.service_mort_verify_issue_email_challenge(uuid,uuid,text)
to service_role;

create or replace function public.service_mort_verify_mark_email_delivery(
  p_session_id uuid,
  p_code_hash text,
  p_sent boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then
    return jsonb_build_object('ok', false, 'code', 'service_role_required');
  end if;

  update private.mort_verify_email_challenges
  set delivery_status = case when p_sent then 'sent' else 'failed' end
  where session_id = p_session_id
    and code_hash = lower(p_code_hash)
    and consumed_at is null
    and delivery_status = 'queued';

  return jsonb_build_object('ok', true);
end;
$$;

revoke all on function public.service_mort_verify_mark_email_delivery(uuid,text,boolean)
from public, anon, authenticated;
grant execute on function public.service_mort_verify_mark_email_delivery(uuid,text,boolean)
to service_role;

create or replace function public.verify_mort_school_email_code(
  p_session_id uuid,
  p_code text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session private.mort_verify_sessions%rowtype;
  v_challenge private.mort_verify_email_challenges%rowtype;
  v_hash text;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;

  if p_code is null or p_code !~ '^[0-9]{8}$' then
    return jsonb_build_object('ok', false, 'code', 'invalid_verification_code');
  end if;

  select * into v_session
  from private.mort_verify_sessions session
  where session.id = p_session_id
    and session.user_id = auth.uid()
    and session.status = 'email_pending'
    and session.expires_at > now()
  for update;

  if v_session.id is null then
    return jsonb_build_object('ok', false, 'code', 'session_not_available');
  end if;

  select * into v_challenge
  from private.mort_verify_email_challenges challenge
  where challenge.session_id = p_session_id
    and challenge.consumed_at is null
    and challenge.delivery_status = 'sent'
  order by challenge.created_at desc
  limit 1
  for update;

  if v_challenge.id is null or v_challenge.expires_at <= now() then
    return jsonb_build_object('ok', false, 'code', 'verification_code_expired');
  end if;
  if v_challenge.attempts >= 5 then
    return jsonb_build_object('ok', false, 'code', 'verification_code_attempts_exhausted');
  end if;

  v_hash := encode(digest(convert_to(p_code, 'UTF8'), 'sha256'), 'hex');

  if v_hash <> v_challenge.code_hash then
    update private.mort_verify_email_challenges
    set attempts = attempts + 1
    where id = v_challenge.id;
    return jsonb_build_object('ok', false, 'code', 'verification_code_invalid');
  end if;

  update private.mort_verify_email_challenges
  set consumed_at = now(), delivery_status = 'consumed'
  where id = v_challenge.id;

  update private.mort_verify_sessions
  set school_email_verified_at = now(),
      status = 'school_id_required',
      updated_at = now()
  where id = p_session_id;

  update public.identity_verifications
  set email_verification_result = 'school_email_verified',
      status = 'additional_information_required',
      updated_at = now()
  where id = v_session.identity_verification_id;

  insert into private.mort_verify_audit_events(
    session_id,user_id,actor_id,action,safe_metadata
  ) values (
    p_session_id,auth.uid(),auth.uid(),'school_email_verified',
    jsonb_build_object('challenge_id', v_challenge.id)
  );

  return jsonb_build_object(
    'ok', true,
    'status', 'school_id_required',
    'school_email_verified', true,
    'next_step', 'school_id'
  );
end;
$$;

revoke all on function public.verify_mort_school_email_code(uuid,text)
from public, anon;
grant execute on function public.verify_mort_school_email_code(uuid,text)
to authenticated;

create or replace function public.service_mort_verify_register_document(
  p_user_id uuid,
  p_session_id uuid,
  p_storage_path text,
  p_side text,
  p_content_type text,
  p_byte_size bigint,
  p_sha256 text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session private.mort_verify_sessions%rowtype;
  v_document private.mort_verify_documents%rowtype;
  v_control private.mort_verify_control%rowtype;
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then
    return jsonb_build_object('ok', false, 'code', 'service_role_required');
  end if;

  select * into v_control from private.mort_verify_control_row();

  if p_side not in ('front','back')
     or p_content_type not in ('image/jpeg','image/png','application/pdf')
     or p_byte_size not between 1 and 10485760
     or p_sha256 !~ '^[A-Fa-f0-9]{64}$' then
    return jsonb_build_object('ok', false, 'code', 'invalid_document_metadata');
  end if;

  select * into v_session
  from private.mort_verify_sessions session
  where session.id = p_session_id
    and session.user_id = p_user_id
    and session.school_email_verified_at is not null
    and session.status in ('school_id_required','document_pending')
    and session.expires_at > now()
  for update;

  if v_session.id is null then
    return jsonb_build_object('ok', false, 'code', 'session_not_available');
  end if;

  if p_storage_path !~ (
    '^' || p_user_id::text || '/' || p_session_id::text || '/' ||
    p_side || '/[0-9a-fA-F-]{36}[.](jpg|jpeg|png|pdf)$'
  ) then
    return jsonb_build_object('ok', false, 'code', 'invalid_storage_path');
  end if;

  if not exists (
    select 1 from storage.objects object
    where object.bucket_id = 'mort-verify-evidence'
      and object.name = p_storage_path
      and object.owner_id = p_user_id::text
  ) then
    return jsonb_build_object('ok', false, 'code', 'uploaded_object_not_found');
  end if;

  update private.mort_verify_documents
  set status = 'superseded'
  where session_id = p_session_id
    and side = p_side
    and status = 'active';

  insert into private.mort_verify_documents(
    session_id,user_id,side,storage_path,content_type,byte_size,sha256,
    retention_delete_at
  ) values (
    p_session_id,p_user_id,p_side,p_storage_path,p_content_type,p_byte_size,
    lower(p_sha256),now() + make_interval(days => v_control.raw_document_retention_days)
  ) returning * into v_document;

  update private.mort_verify_sessions
  set status = 'document_pending', updated_at = now()
  where id = p_session_id;

  insert into private.mort_verify_audit_events(
    session_id,user_id,actor_id,action,safe_metadata
  ) values (
    p_session_id,p_user_id,p_user_id,'school_id_registered',
    jsonb_build_object(
      'document_id', v_document.id,
      'side', p_side,
      'byte_size', p_byte_size,
      'content_type', p_content_type
    )
  );

  return jsonb_build_object(
    'ok', true,
    'document_id', v_document.id,
    'side', p_side,
    'status', 'document_pending'
  );
end;
$$;

revoke all on function public.service_mort_verify_register_document(
  uuid,uuid,text,text,text,bigint,text
)
from public, anon, authenticated;
grant execute on function public.service_mort_verify_register_document(
  uuid,uuid,text,text,text,bigint,text
)
to service_role;

create or replace function public.submit_mort_verify_session(
  p_session_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session private.mort_verify_sessions%rowtype;
  v_control private.mort_verify_control%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  select * into v_control from private.mort_verify_control_row();
  if not v_control.manual_review_enabled then
    return jsonb_build_object('ok', false, 'code', 'manual_review_not_enabled');
  end if;

  select * into v_session
  from private.mort_verify_sessions session
  where session.id = p_session_id
    and session.user_id = auth.uid()
    and session.status in ('school_id_required','document_pending')
    and session.expires_at > now()
  for update;

  if v_session.id is null then
    return jsonb_build_object('ok', false, 'code', 'session_not_available');
  end if;
  if v_session.school_email_verified_at is null then
    return jsonb_build_object('ok', false, 'code', 'school_email_required');
  end if;
  if not exists (
    select 1 from private.mort_verify_documents document
    where document.session_id = p_session_id
      and document.side = 'front'
      and document.status = 'active'
  ) then
    return jsonb_build_object('ok', false, 'code', 'school_id_front_required');
  end if;

  update private.mort_verify_sessions
  set status = 'manual_review',
      submitted_at = now(),
      updated_at = now()
  where id = p_session_id;

  update public.identity_verifications
  set status = 'manual_review',
      submitted_at = now(),
      updated_at = now()
  where id = v_session.identity_verification_id;

  insert into private.mort_verify_audit_events(
    session_id,user_id,actor_id,action,safe_metadata
  ) values (
    p_session_id,auth.uid(),auth.uid(),'submitted_for_manual_review','{}'::jsonb
  );

  return jsonb_build_object(
    'ok', true,
    'status', 'manual_review',
    'age_verified', false,
    'school_affiliation_verified', false,
    'student_identity_verified', false
  );
end;
$$;

revoke all on function public.submit_mort_verify_session(uuid)
from public, anon;
grant execute on function public.submit_mort_verify_session(uuid)
to authenticated;

create or replace function public.claim_mort_verify_review(
  p_access_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session private.mort_verify_sessions%rowtype;
  v_assignment private.mort_verify_review_assignments%rowtype;
begin
  if auth.uid() is null
     or not private.has_admin_safety_role(
       auth.uid(),
       array['verification_reviewer','senior_safety_moderator']::public.admin_safety_role[]
     ) then
    return jsonb_build_object('ok', false, 'code', 'verification_reviewer_required');
  end if;
  if char_length(btrim(coalesce(p_access_reason,''))) not between 10 and 500 then
    return jsonb_build_object('ok', false, 'code', 'access_reason_required');
  end if;

  select * into v_session
  from private.mort_verify_sessions session
  where session.status in ('manual_review','needs_age_evidence')
    and not exists (
      select 1 from private.mort_verify_review_assignments assignment
      where assignment.session_id = session.id
        and assignment.revoked_at is null
        and assignment.expires_at > now()
    )
  order by session.submitted_at nulls last, session.created_at
  limit 1
  for update skip locked;

  if v_session.id is null then
    return jsonb_build_object('ok', true, 'assignment', null);
  end if;

  update private.mort_verify_review_assignments
  set revoked_at = now()
  where session_id = v_session.id
    and revoked_at is null;

  insert into private.mort_verify_review_assignments(
    session_id,reviewer_id,access_reason,expires_at
  ) values (
    v_session.id,auth.uid(),btrim(p_access_reason),now() + interval '15 minutes'
  ) returning * into v_assignment;

  insert into private.mort_verify_audit_events(
    session_id,user_id,actor_id,action,safe_metadata
  ) values (
    v_session.id,v_session.user_id,auth.uid(),'review_claimed',
    jsonb_build_object('assignment_id',v_assignment.id)
  );

  return jsonb_build_object(
    'ok', true,
    'assignment', jsonb_build_object(
      'id', v_assignment.id,
      'session_id', v_session.id,
      'status', v_session.status,
      'expires_at', v_assignment.expires_at,
      'school_email_verified', v_session.school_email_verified_at is not null
    )
  );
end;
$$;

revoke all on function public.claim_mort_verify_review(text)
from public, anon;
grant execute on function public.claim_mort_verify_review(text)
to authenticated;

create or replace function public.admin_mort_verify_decide(
  p_session_id uuid,
  p_action text,
  p_reason_code text,
  p_student_identity_verified boolean default false,
  p_school_affiliation_verified boolean default false,
  p_age_band text default null,
  p_age_evidence_kind text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session private.mort_verify_sessions%rowtype;
  v_action text := lower(btrim(coalesce(p_action,'')));
  v_has_assignment boolean;
begin
  if auth.uid() is null
     or not private.has_admin_safety_role(
       auth.uid(),
       array['verification_reviewer','senior_safety_moderator']::public.admin_safety_role[]
     ) then
    return jsonb_build_object('ok', false, 'code', 'verification_reviewer_required');
  end if;

  select * into v_session
  from private.mort_verify_sessions session
  where session.id = p_session_id
    and session.status in ('manual_review','needs_age_evidence')
  for update;

  if v_session.id is null then
    return jsonb_build_object('ok', false, 'code', 'review_session_not_found');
  end if;

  select exists (
    select 1 from private.mort_verify_review_assignments assignment
    where assignment.session_id = p_session_id
      and assignment.reviewer_id = auth.uid()
      and assignment.revoked_at is null
      and assignment.expires_at > now()
  ) into v_has_assignment;

  if not v_has_assignment then
    return jsonb_build_object('ok', false, 'code', 'active_review_assignment_required');
  end if;

  if char_length(btrim(coalesce(p_reason_code,''))) not between 2 and 120 then
    return jsonb_build_object('ok', false, 'code', 'decision_reason_required');
  end if;

  if v_action = 'request_recapture' then
    update private.mort_verify_sessions
    set status='document_pending', decision_code=p_reason_code,
        reviewer_id=auth.uid(), reviewed_at=now(), updated_at=now()
    where id=p_session_id;
    update public.identity_verifications
    set status='additional_information_required', rejection_code=p_reason_code,
        reviewer_id=auth.uid(), reviewed_at=now(), updated_at=now()
    where id=v_session.identity_verification_id;
  elsif v_action = 'reject' then
    update private.mort_verify_sessions
    set status='rejected', decision_code=p_reason_code,
        reviewer_id=auth.uid(), reviewed_at=now(), updated_at=now()
    where id=p_session_id;
    update public.identity_verifications
    set status='verification_rejected', verification_level=0,
        rejection_code=p_reason_code, reviewer_id=auth.uid(),
        reviewed_at=now(), updated_at=now()
    where id=v_session.identity_verification_id;
  elsif v_action = 'approve_school_only' then
    if not p_student_identity_verified or not p_school_affiliation_verified then
      return jsonb_build_object('ok', false, 'code', 'school_identity_signals_required');
    end if;
    update private.mort_verify_sessions
    set status='needs_age_evidence',
        school_affiliation_verified_at=coalesce(school_affiliation_verified_at,now()),
        student_identity_verified_at=coalesce(student_identity_verified_at,now()),
        decision_code=p_reason_code,
        reviewer_id=auth.uid(), reviewed_at=now(), updated_at=now()
    where id=p_session_id;
    update public.identity_verifications
    set status='additional_information_required',
        identity_match_result='school_id_and_email_consistent',
        email_verification_result='school_email_verified',
        rejection_code=null, reviewer_id=auth.uid(),
        reviewed_at=now(), updated_at=now()
    where id=v_session.identity_verification_id;
  elsif v_action = 'approve_age_and_school' then
    if not p_student_identity_verified
       or not p_school_affiliation_verified
       or p_age_band not in ('13_15','16_17')
       or p_age_evidence_kind not in (
         'school_id_dob','school_record','government_id_age_only','manual_exception'
       ) then
      return jsonb_build_object('ok', false, 'code', 'verified_age_evidence_required');
    end if;
    update private.mort_verify_sessions
    set status='verified',
        school_affiliation_verified_at=coalesce(school_affiliation_verified_at,now()),
        student_identity_verified_at=coalesce(student_identity_verified_at,now()),
        age_verified_at=now(),
        verified_age_band=p_age_band,
        age_evidence_kind=p_age_evidence_kind,
        decision_code=p_reason_code,
        reviewer_id=auth.uid(), reviewed_at=now(), updated_at=now()
    where id=p_session_id;
    update public.identity_verifications
    set status='verified',
        verification_level=1,
        identity_match_result='school_id_and_email_consistent',
        email_verification_result='school_email_verified',
        liveness_result='not_checked',
        reviewed_at=now(),
        verified_at=now(),
        expires_at=now() + interval '1 year',
        reviewer_id=auth.uid(),
        rejection_code=null,
        decision_source='mort_verify_manual_review',
        risk_flags = risk_flags || jsonb_build_object(
          'age_verified', true,
          'age_band', p_age_band,
          'age_evidence_kind', p_age_evidence_kind,
          'school_affiliation_verified', true,
          'legal_identity_claimed', false
        ),
        updated_at=now()
    where id=v_session.identity_verification_id;

    insert into public.trust_signal_events(
      user_id,signal_type,category,status,environment,source_kind,
      source_reference,public_label,what_was_checked,what_was_not_checked,
      checked_at,expires_at,public_visibility,grants_marketplace_access,
      metadata,created_by
    ) values (
      v_session.user_id,
      'school_affiliation',
      'affiliation',
      'verified',
      v_session.environment,
      'mort_verify',
      p_session_id::text,
      'School affiliation verified',
      'A confirmed approved school email and reviewed current school ID were consistent.',
      'This does not establish a government-issued legal identity.',
      now(),now()+interval '1 year',false,false,
      jsonb_build_object('age_band_verified',p_age_band,'first_party',true),
      auth.uid()
    );
  else
    return jsonb_build_object('ok', false, 'code', 'unsupported_review_action');
  end if;

  update private.mort_verify_review_assignments
  set revoked_at=now()
  where session_id=p_session_id and reviewer_id=auth.uid() and revoked_at is null;

  insert into private.mort_verify_audit_events(
    session_id,user_id,actor_id,action,safe_metadata
  ) values (
    p_session_id,v_session.user_id,auth.uid(),'review_decision',
    jsonb_build_object(
      'action',v_action,
      'reason_code',p_reason_code,
      'student_identity_verified',p_student_identity_verified,
      'school_affiliation_verified',p_school_affiliation_verified,
      'age_band',p_age_band,
      'age_evidence_kind',p_age_evidence_kind
    )
  );

  return jsonb_build_object('ok',true,'status',(
    select session.status from private.mort_verify_sessions session
    where session.id=p_session_id
  ));
end;
$$;

revoke all on function public.admin_mort_verify_decide(
  uuid,text,text,boolean,boolean,text,text
)
from public, anon;
grant execute on function public.admin_mort_verify_decide(
  uuid,text,text,boolean,boolean,text,text
)
to authenticated;

create or replace function public.service_mort_verify_get_session_for_delivery(
  p_user_id uuid,
  p_session_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_session private.mort_verify_sessions%rowtype;
  v_school public.school_domains%rowtype;
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then
    return jsonb_build_object('ok', false, 'code', 'service_role_required');
  end if;
  select * into v_session
  from private.mort_verify_sessions session
  where session.id=p_session_id and session.user_id=p_user_id;
  if v_session.id is null then
    return jsonb_build_object('ok',false,'code','session_not_found');
  end if;
  select * into v_school from public.school_domains school where school.id=v_session.school_domain_id;
  return jsonb_build_object(
    'ok',true,
    'email',v_session.school_email,
    'school_name',v_school.organization_name,
    'status',v_session.status,
    'expires_at',v_session.expires_at
  );
end;
$$;

revoke all on function public.service_mort_verify_get_session_for_delivery(uuid,uuid)
from public, anon, authenticated;
grant execute on function public.service_mort_verify_get_session_for_delivery(uuid,uuid)
to service_role;

create or replace function public.service_mort_verify_get_review_document(
  p_reviewer_id uuid,
  p_session_id uuid,
  p_side text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_document private.mort_verify_documents%rowtype;
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then
    return jsonb_build_object('ok',false,'code','service_role_required');
  end if;
  if not exists (
    select 1 from private.mort_verify_review_assignments assignment
    where assignment.session_id=p_session_id
      and assignment.reviewer_id=p_reviewer_id
      and assignment.revoked_at is null
      and assignment.expires_at>now()
  ) then
    return jsonb_build_object('ok',false,'code','active_review_assignment_required');
  end if;
  select * into v_document
  from private.mort_verify_documents document
  where document.session_id=p_session_id
    and document.side=p_side
    and document.status='active'
  order by document.created_at desc
  limit 1;
  if v_document.id is null then
    return jsonb_build_object('ok',false,'code','document_not_found');
  end if;
  return jsonb_build_object(
    'ok',true,
    'document_id',v_document.id,
    'bucket_id',v_document.bucket_id,
    'storage_path',v_document.storage_path,
    'content_type',v_document.content_type,
    'byte_size',v_document.byte_size
  );
end;
$$;

revoke all on function public.service_mort_verify_get_review_document(uuid,uuid,text)
from public, anon, authenticated;
grant execute on function public.service_mort_verify_get_review_document(uuid,uuid,text)
to service_role;

-- Production remains off after installation. Synthetic QA may be enabled later
-- only by an explicit server-side control change after review.
update private.mort_verify_control
set mode='disabled',
    school_email_enabled=false,
    school_id_enabled=false,
    manual_review_enabled=false,
    production_document_collection_approved=false,
    updated_at=now()
where singleton;
