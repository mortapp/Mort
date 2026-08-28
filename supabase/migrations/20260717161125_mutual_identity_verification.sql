-- Mandatory, role-aware identity verification. Raw evidence remains outside
-- ordinary profile and marketplace tables and is never publicly readable.

create type public.identity_verification_state as enum (
  'unverified',
  'verification_started',
  'verification_pending',
  'additional_information_required',
  'verified',
  'verification_expired',
  'verification_rejected',
  'verification_suspended',
  'manual_review',
  'appeal_pending'
);

create type public.identity_evidence_route as enum (
  'school_photo_id',
  'government_id',
  'verified_school_account',
  'approved_program_id',
  'manual_exception',
  'legacy_approved_record'
);

create type public.identity_evidence_type as enum (
  'school_photo_id',
  'drivers_license',
  'state_id',
  'learner_permit',
  'passport',
  'passport_card',
  'other_government_id',
  'school_account_assertion',
  'accredited_program_id',
  'youth_organization_id',
  'homeschool_document',
  'supporting_document',
  'ownership_selfie',
  'address_document'
);

create type public.admin_safety_role as enum (
  'support_agent',
  'moderator',
  'senior_safety_moderator',
  'verification_reviewer',
  'child_safety_specialist',
  'incident_manager',
  'legal_request_reviewer',
  'super_admin'
);

create table public.admin_role_assignments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  role public.admin_safety_role not null,
  granted_by uuid references public.profiles(id) on delete set null,
  grant_reason text,
  created_at timestamptz not null default now(),
  revoked_at timestamptz,
  constraint admin_role_assignment_reason_length check (
    grant_reason is null or char_length(grant_reason) <= 500
  )
);

create unique index admin_role_assignments_active_role_idx
on public.admin_role_assignments(user_id, role)
where revoked_at is null;

create index admin_role_assignments_user_active_idx
on public.admin_role_assignments(user_id, revoked_at);

insert into public.admin_role_assignments (user_id, role, grant_reason)
select profile.id, 'super_admin', 'Migrated existing MORT administrator.'
from public.profiles profile
where profile.role = 'admin'
on conflict (user_id, role) where revoked_at is null do nothing;

create or replace function private.has_admin_safety_role(
  p_user_id uuid,
  p_allowed public.admin_safety_role[]
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles profile
    join public.admin_role_assignments assignment
      on assignment.user_id = profile.id
     and assignment.revoked_at is null
    where profile.id = p_user_id
      and profile.role = 'admin'
      and profile.account_status = 'active'
      and (
        assignment.role = 'super_admin'
        or assignment.role = any(p_allowed)
      )
  );
$$;

revoke all on function private.has_admin_safety_role(uuid, public.admin_safety_role[])
from public, anon, authenticated;

create table public.identity_verifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  account_role public.user_role not null,
  evidence_route public.identity_evidence_route not null,
  provider text not null default 'mort_manual_review',
  provider_reference text,
  status public.identity_verification_state not null default 'verification_started',
  verification_level smallint not null default 0,
  age_band text not null,
  identity_match_result text not null default 'not_checked',
  liveness_result text not null default 'not_checked',
  email_verification_result text not null default 'not_checked',
  phone_verification_result text not null default 'not_checked',
  address_validation_result text not null default 'not_checked',
  enhanced_screening_status text not null default 'not_started',
  submitted_at timestamptz,
  reviewed_at timestamptz,
  expires_at timestamptz,
  retention_delete_at timestamptz,
  reviewer_id uuid references public.profiles(id) on delete set null,
  rejection_code text,
  appeal_status text not null default 'none',
  risk_flags jsonb not null default '{}'::jsonb,
  audit_version text not null default 'mutual-identity-v1',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint identity_verification_level_check check (verification_level between 0 and 4),
  constraint identity_verification_age_band_check check (age_band in ('teen_13_17', 'adult_18_plus')),
  constraint identity_verification_provider_length check (char_length(provider) between 2 and 80),
  constraint identity_verification_result_length check (
    char_length(identity_match_result) <= 80
    and char_length(liveness_result) <= 80
    and char_length(email_verification_result) <= 80
    and char_length(phone_verification_result) <= 80
    and char_length(address_validation_result) <= 80
    and char_length(enhanced_screening_status) <= 80
  )
);

create unique index identity_verifications_one_active_idx
on public.identity_verifications(user_id)
where status in (
  'verification_started',
  'verification_pending',
  'additional_information_required',
  'manual_review',
  'appeal_pending'
);

create index identity_verifications_user_created_idx
on public.identity_verifications(user_id, created_at desc);

create index identity_verifications_queue_idx
on public.identity_verifications(status, account_role, submitted_at);

create index identity_verifications_expiry_idx
on public.identity_verifications(expires_at)
where status = 'verified';

create table public.identity_verification_evidence (
  id uuid primary key,
  verification_id uuid not null references public.identity_verifications(id) on delete restrict,
  user_id uuid not null references public.profiles(id) on delete restrict,
  evidence_type public.identity_evidence_type not null,
  bucket_id text not null default 'identity-evidence',
  storage_path text not null unique,
  content_type text not null,
  byte_size bigint not null,
  sha256 text,
  evidence_status text not null default 'received',
  submitted_at timestamptz not null default now(),
  retention_delete_at timestamptz not null default (now() + interval '30 days'),
  preserved_until timestamptz,
  created_at timestamptz not null default now(),
  constraint identity_evidence_bucket_check check (bucket_id = 'identity-evidence'),
  constraint identity_evidence_content_type_check check (
    content_type in ('image/jpeg', 'image/png', 'application/pdf')
  ),
  constraint identity_evidence_size_check check (byte_size between 1 and 10485760),
  constraint identity_evidence_sha256_check check (
    sha256 is null or sha256 ~ '^[A-Fa-f0-9]{64}$'
  )
);

create unique index identity_evidence_slot_idx
on public.identity_verification_evidence(verification_id, evidence_type);

create index identity_evidence_user_idx
on public.identity_verification_evidence(user_id, submitted_at desc);

create index identity_evidence_retention_idx
on public.identity_verification_evidence(retention_delete_at)
where preserved_until is null;

create index identity_evidence_fingerprint_idx
on public.identity_verification_evidence(sha256)
where sha256 is not null;

create table public.identity_verification_appeals (
  id uuid primary key default gen_random_uuid(),
  verification_id uuid not null references public.identity_verifications(id) on delete restrict,
  user_id uuid not null references public.profiles(id) on delete cascade,
  reason text not null,
  status text not null default 'pending',
  reviewer_id uuid references public.profiles(id) on delete set null,
  decision_note text,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  constraint verification_appeal_reason_length check (char_length(reason) between 20 and 2000),
  constraint verification_appeal_status_check check (status in ('pending', 'reviewing', 'approved', 'denied', 'withdrawn')),
  constraint verification_appeal_decision_length check (decision_note is null or char_length(decision_note) <= 2000)
);

create unique index identity_verification_appeals_pending_idx
on public.identity_verification_appeals(verification_id)
where status in ('pending', 'reviewing');

create index identity_verification_appeals_user_idx
on public.identity_verification_appeals(user_id, created_at desc);

create table public.verification_referee_requests (
  id uuid primary key default gen_random_uuid(),
  verification_id uuid not null unique references public.identity_verifications(id) on delete restrict,
  user_id uuid not null references public.profiles(id) on delete cascade,
  exception_reason text not null,
  contact_collection_status text not null default 'not_collected',
  status text not null default 'support_follow_up_required',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint verification_referee_reason_length check (char_length(exception_reason) between 20 and 2000),
  constraint verification_referee_contact_check check (contact_collection_status = 'not_collected')
);

create table public.verification_evidence_access_grants (
  id uuid primary key default gen_random_uuid(),
  evidence_id uuid not null references public.identity_verification_evidence(id) on delete cascade,
  reviewer_id uuid not null references public.profiles(id) on delete cascade,
  access_reason text not null,
  granted_at timestamptz not null default now(),
  expires_at timestamptz not null,
  revoked_at timestamptz,
  constraint verification_access_reason_length check (char_length(access_reason) between 10 and 500),
  constraint verification_access_expiry_check check (expires_at > granted_at and expires_at <= granted_at + interval '15 minutes')
);

create index verification_evidence_access_active_idx
on public.verification_evidence_access_grants(reviewer_id, evidence_id, expires_at)
where revoked_at is null;

create table public.verification_audit_events (
  id bigint generated always as identity primary key,
  verification_id uuid references public.identity_verifications(id) on delete restrict,
  evidence_id uuid references public.identity_verification_evidence(id) on delete restrict,
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  access_reason text,
  event_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint verification_audit_action_length check (char_length(action) between 2 and 100),
  constraint verification_audit_reason_length check (access_reason is null or char_length(access_reason) <= 500)
);

create index verification_audit_verification_idx
on public.verification_audit_events(verification_id, created_at desc);

create index verification_audit_actor_idx
on public.verification_audit_events(actor_id, created_at desc);

create table public.identity_risk_signals (
  id uuid primary key default gen_random_uuid(),
  verification_id uuid not null references public.identity_verifications(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  signal_type text not null,
  severity text not null default 'review',
  signal_data jsonb not null default '{}'::jsonb,
  status text not null default 'open',
  reviewed_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  constraint identity_risk_signal_severity_check check (severity in ('info', 'review', 'high')),
  constraint identity_risk_signal_status_check check (status in ('open', 'reviewing', 'cleared', 'confirmed'))
);

create index identity_risk_signals_queue_idx
on public.identity_risk_signals(status, severity, created_at);

alter table public.admin_role_assignments enable row level security;
alter table public.identity_verifications enable row level security;
alter table public.identity_verification_evidence enable row level security;
alter table public.identity_verification_appeals enable row level security;
alter table public.verification_referee_requests enable row level security;
alter table public.verification_evidence_access_grants enable row level security;
alter table public.verification_audit_events enable row level security;
alter table public.identity_risk_signals enable row level security;

create policy admin_role_assignments_select_self_or_super
on public.admin_role_assignments for select to authenticated
using (
  user_id = (select auth.uid())
  or private.has_admin_safety_role(
    (select auth.uid()),
    array['super_admin']::public.admin_safety_role[]
  )
);

create policy identity_verifications_reviewer_select
on public.identity_verifications for select to authenticated
using (
  private.has_admin_safety_role(
    (select auth.uid()),
    array['verification_reviewer', 'senior_safety_moderator']::public.admin_safety_role[]
  )
);

create policy identity_evidence_reviewer_select
on public.identity_verification_evidence for select to authenticated
using (
  private.has_admin_safety_role(
    (select auth.uid()),
    array['verification_reviewer', 'senior_safety_moderator']::public.admin_safety_role[]
  )
  and exists (
    select 1
    from public.verification_evidence_access_grants access_grant
    where access_grant.evidence_id = identity_verification_evidence.id
      and access_grant.reviewer_id = (select auth.uid())
      and access_grant.revoked_at is null
      and access_grant.expires_at > now()
  )
);

create policy identity_appeals_owner_or_reviewer_select
on public.identity_verification_appeals for select to authenticated
using (
  user_id = (select auth.uid())
  or private.has_admin_safety_role(
    (select auth.uid()),
    array['verification_reviewer', 'senior_safety_moderator']::public.admin_safety_role[]
  )
);

create policy verification_referee_owner_or_reviewer_select
on public.verification_referee_requests for select to authenticated
using (
  user_id = (select auth.uid())
  or private.has_admin_safety_role(
    (select auth.uid()),
    array['verification_reviewer', 'child_safety_specialist']::public.admin_safety_role[]
  )
);

create policy verification_access_grants_reviewer_select
on public.verification_evidence_access_grants for select to authenticated
using (reviewer_id = (select auth.uid()));

create policy verification_audit_authorized_select
on public.verification_audit_events for select to authenticated
using (
  private.has_admin_safety_role(
    (select auth.uid()),
    array['verification_reviewer', 'senior_safety_moderator', 'incident_manager', 'legal_request_reviewer']::public.admin_safety_role[]
  )
);

create policy identity_risk_signals_authorized_select
on public.identity_risk_signals for select to authenticated
using (
  private.has_admin_safety_role(
    (select auth.uid()),
    array['verification_reviewer', 'senior_safety_moderator', 'child_safety_specialist']::public.admin_safety_role[]
  )
);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'identity-evidence',
  'identity-evidence',
  false,
  10485760,
  array['image/jpeg', 'image/png', 'application/pdf']
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

create policy identity_evidence_upload_started_attempt
on storage.objects for insert to authenticated
with check (
  bucket_id = 'identity-evidence'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and (storage.foldername(name))[2] ~ '^[0-9a-fA-F-]{36}$'
  and name !~ '(^|/)\.\.(/|$)'
  and lower(storage.extension(name)) in ('jpg', 'jpeg', 'png', 'pdf')
  and exists (
    select 1
    from public.identity_verifications verification
    where verification.id::text = (storage.foldername(name))[2]
      and verification.user_id = (select auth.uid())
      and verification.status in ('verification_started', 'additional_information_required')
  )
);

create policy identity_evidence_delete_unregistered
on storage.objects for delete to authenticated
using (
  bucket_id = 'identity-evidence'
  and owner_id = (select auth.uid())::text
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and exists (
    select 1
    from public.identity_verifications verification
    where verification.id::text = (storage.foldername(name))[2]
      and verification.user_id = (select auth.uid())
      and verification.status = 'verification_started'
  )
  and not exists (
    select 1
    from public.identity_verification_evidence evidence
    where evidence.storage_path = name
  )
);

create policy identity_evidence_authorized_reviewer_read
on storage.objects for select to authenticated
using (
  bucket_id = 'identity-evidence'
  and private.has_admin_safety_role(
    (select auth.uid()),
    array['verification_reviewer', 'senior_safety_moderator']::public.admin_safety_role[]
  )
  and exists (
    select 1
    from public.identity_verification_evidence evidence
    join public.verification_evidence_access_grants access_grant
      on access_grant.evidence_id = evidence.id
    where evidence.storage_path = name
      and access_grant.reviewer_id = (select auth.uid())
      and access_grant.revoked_at is null
      and access_grant.expires_at > now()
  )
);

create or replace function private.marketplace_identity_level(p_user_id uuid)
returns smallint
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when exists (
      select 1
      from public.profiles profile
      where profile.id = p_user_id
        and profile.role = 'admin'
        and profile.account_status = 'active'
    ) then 4::smallint
    else coalesce((
      select max(verification.verification_level)::smallint
      from public.identity_verifications verification
      where verification.user_id = p_user_id
        and verification.status = 'verified'
        and (verification.expires_at is null or verification.expires_at > now())
    ), 0::smallint)
  end;
$$;

create or replace function private.has_marketplace_identity(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles profile
    where profile.id = p_user_id
      and profile.account_status = 'active'
      and (
        profile.role = 'admin'
        or (profile.role = 'teen' and private.marketplace_identity_level(profile.id) >= 1)
        or (profile.role in ('adult', 'guardian') and private.marketplace_identity_level(profile.id) >= 2)
      )
  );
$$;

revoke all on function private.marketplace_identity_level(uuid)
from public, anon, authenticated;
revoke all on function private.has_marketplace_identity(uuid)
from public, anon, authenticated;

insert into public.identity_verifications (
  user_id,
  account_role,
  evidence_route,
  provider,
  status,
  verification_level,
  age_band,
  identity_match_result,
  liveness_result,
  email_verification_result,
  phone_verification_result,
  address_validation_result,
  submitted_at,
  reviewed_at,
  expires_at,
  risk_flags,
  audit_version
)
select
  profile.id,
  profile.role,
  'legacy_approved_record',
  'mort_legacy_review',
  'verified',
  case when profile.role = 'teen' then 1 else 2 end,
  case when profile.role = 'teen' then 'teen_13_17' else 'adult_18_plus' end,
  'legacy_review',
  'legacy_review',
  'legacy_review',
  'legacy_review',
  'legacy_review',
  profile.updated_at,
  profile.updated_at,
  now() + interval '90 days',
  jsonb_build_object(
    'legacy_bridge', true,
    'new_standard_recheck_required', true
  ),
  'legacy-bridge-v1'
from public.profiles profile
where profile.verification_status = 'approved'
  and profile.role in ('teen', 'adult', 'guardian')
  and not exists (
    select 1
    from public.identity_verifications existing
    where existing.user_id = profile.id
  );

drop trigger if exists business_verifications_sync_profile
on public.business_verifications;

create or replace function public.get_my_identity_verification()
returns jsonb
language plpgsql
stable
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_user_id uuid := auth.uid();
  v_profile public.profiles%rowtype;
  v_verification public.identity_verifications%rowtype;
  v_effective_status text;
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;

  select * into v_profile from public.profiles where id = v_user_id;
  select * into v_verification
  from public.identity_verifications verification
  where verification.user_id = v_user_id
  order by
    (verification.status in ('verification_started', 'verification_pending', 'additional_information_required', 'manual_review', 'appeal_pending')) desc,
    verification.created_at desc
  limit 1;

  if v_verification.id is null then
    return jsonb_build_object(
      'ok', true,
      'status', 'unverified',
      'verification_level', 0,
      'marketplace_enabled', false,
      'guardian_mode_optional', true,
      'role', v_profile.role
    );
  end if;

  v_effective_status := v_verification.status::text;
  if v_verification.status = 'verified'
     and v_verification.expires_at is not null
     and v_verification.expires_at <= now() then
    v_effective_status := 'verification_expired';
  end if;

  return jsonb_build_object(
    'ok', true,
    'id', v_verification.id,
    'role', v_verification.account_role,
    'status', v_effective_status,
    'evidence_route', v_verification.evidence_route,
    'verification_level', v_verification.verification_level,
    'age_band', v_verification.age_band,
    'submitted_at', v_verification.submitted_at,
    'reviewed_at', v_verification.reviewed_at,
    'expires_at', v_verification.expires_at,
    'appeal_status', v_verification.appeal_status,
    'rejection_code', v_verification.rejection_code,
    'marketplace_enabled', private.has_marketplace_identity(v_user_id),
    'guardian_mode_optional', true,
    'evidence_types', coalesce((
      select jsonb_agg(jsonb_build_object(
        'type', evidence.evidence_type,
        'status', evidence.evidence_status,
        'submitted_at', evidence.submitted_at
      ) order by evidence.submitted_at)
      from public.identity_verification_evidence evidence
      where evidence.verification_id = v_verification.id
    ), '[]'::jsonb),
    'raw_documents_visible_to_marketplace_users', false
  );
end;
$$;

create or replace function public.start_identity_verification(
  p_evidence_route text,
  p_attested boolean default false,
  p_exception_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_profile public.profiles%rowtype;
  v_route public.identity_evidence_route;
  v_age integer;
  v_verification public.identity_verifications%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if not p_attested then
    return jsonb_build_object('ok', false, 'code', 'verification_attestation_required');
  end if;

  select * into v_profile from public.profiles where id = auth.uid();
  if v_profile.id is null or v_profile.role is null or v_profile.dob is null then
    return jsonb_build_object('ok', false, 'code', 'profile_age_required');
  end if;
  if v_profile.role = 'admin' then
    return jsonb_build_object('ok', false, 'code', 'admin_verification_managed_server_side');
  end if;

  begin
    v_route := lower(btrim(p_evidence_route))::public.identity_evidence_route;
  exception when invalid_text_representation then
    return jsonb_build_object('ok', false, 'code', 'unsupported_evidence_route');
  end;

  v_age := date_part('year', age(current_date, v_profile.dob));
  if v_profile.role = 'teen' then
    if v_age < 13 or v_age > 17 then
      return jsonb_build_object('ok', false, 'code', 'teen_age_not_allowed');
    end if;
    if v_route not in ('school_photo_id', 'government_id', 'verified_school_account', 'approved_program_id', 'manual_exception') then
      return jsonb_build_object('ok', false, 'code', 'unsupported_teen_evidence_route');
    end if;
  else
    if v_age < 18 then
      return jsonb_build_object('ok', false, 'code', 'adult_age_not_allowed');
    end if;
    if v_route <> 'government_id' then
      return jsonb_build_object('ok', false, 'code', 'government_id_required');
    end if;
  end if;

  if exists (
    select 1
    from public.identity_verifications verification
    where verification.user_id = auth.uid()
      and verification.status in (
        'verification_started', 'verification_pending',
        'additional_information_required', 'manual_review', 'appeal_pending'
      )
  ) then
    return jsonb_build_object('ok', false, 'code', 'verification_already_active');
  end if;

  insert into public.identity_verifications (
    user_id, account_role, evidence_route, age_band, status,
    retention_delete_at
  ) values (
    auth.uid(),
    v_profile.role,
    v_route,
    case when v_profile.role = 'teen' then 'teen_13_17' else 'adult_18_plus' end,
    'verification_started',
    now() + interval '30 days'
  ) returning * into v_verification;

  if v_route = 'manual_exception' then
    if char_length(btrim(coalesce(p_exception_reason, ''))) < 20 then
      raise exception 'manual_exception_reason_required';
    end if;
    insert into public.verification_referee_requests (
      verification_id, user_id, exception_reason
    ) values (
      v_verification.id,
      auth.uid(),
      left(btrim(p_exception_reason), 2000)
    );
  end if;

  insert into public.verification_audit_events (
    verification_id, actor_id, action, event_data
  ) values (
    v_verification.id,
    auth.uid(),
    'verification_started',
    jsonb_build_object('route', v_route, 'role', v_profile.role)
  );

  return jsonb_build_object(
    'ok', true,
    'id', v_verification.id,
    'status', v_verification.status,
    'evidence_route', v_verification.evidence_route,
    'guardian_mode_optional', true
  );
end;
$$;

create or replace function public.register_identity_evidence(
  p_verification_id uuid,
  p_evidence_id uuid,
  p_storage_path text,
  p_evidence_type text,
  p_sha256 text default null
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'storage', 'pg_temp'
as $$
declare
  v_verification public.identity_verifications%rowtype;
  v_evidence_type public.identity_evidence_type;
  v_expected_prefix text;
  v_mime text;
  v_size bigint;
  v_evidence public.identity_verification_evidence%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_evidence_id is null or p_verification_id is null then
    return jsonb_build_object('ok', false, 'code', 'invalid_evidence_submission');
  end if;

  select * into v_verification
  from public.identity_verifications verification
  where verification.id = p_verification_id
    and verification.user_id = auth.uid()
  for update;

  if v_verification.id is null then
    return jsonb_build_object('ok', false, 'code', 'verification_not_found');
  end if;
  if v_verification.status not in ('verification_started', 'additional_information_required') then
    return jsonb_build_object('ok', false, 'code', 'verification_not_accepting_evidence');
  end if;

  begin
    v_evidence_type := lower(btrim(p_evidence_type))::public.identity_evidence_type;
  exception when invalid_text_representation then
    return jsonb_build_object('ok', false, 'code', 'unsupported_evidence_type');
  end;

  if v_verification.account_role = 'teen' then
    if v_verification.evidence_route = 'school_photo_id' and v_evidence_type not in ('school_photo_id', 'ownership_selfie') then
      return jsonb_build_object('ok', false, 'code', 'evidence_type_not_allowed_for_route');
    elsif v_verification.evidence_route = 'government_id' and v_evidence_type not in ('state_id', 'learner_permit', 'passport', 'passport_card', 'other_government_id', 'ownership_selfie') then
      return jsonb_build_object('ok', false, 'code', 'evidence_type_not_allowed_for_route');
    elsif v_verification.evidence_route = 'verified_school_account' and v_evidence_type not in ('school_account_assertion', 'ownership_selfie') then
      return jsonb_build_object('ok', false, 'code', 'evidence_type_not_allowed_for_route');
    elsif v_verification.evidence_route = 'approved_program_id' and v_evidence_type not in ('accredited_program_id', 'youth_organization_id', 'homeschool_document', 'ownership_selfie') then
      return jsonb_build_object('ok', false, 'code', 'evidence_type_not_allowed_for_route');
    elsif v_verification.evidence_route = 'manual_exception' and v_evidence_type not in ('supporting_document', 'ownership_selfie') then
      return jsonb_build_object('ok', false, 'code', 'evidence_type_not_allowed_for_route');
    end if;
  elsif v_evidence_type not in (
    'drivers_license', 'state_id', 'passport', 'passport_card',
    'other_government_id', 'ownership_selfie', 'address_document'
  ) then
    return jsonb_build_object('ok', false, 'code', 'evidence_type_not_allowed_for_route');
  end if;

  v_expected_prefix := auth.uid()::text || '/' || p_verification_id::text || '/' || v_evidence_type::text || '-' || p_evidence_id::text;
  if p_storage_path is null
     or p_storage_path not like v_expected_prefix || '.%'
     or position('..' in p_storage_path) > 0 then
    return jsonb_build_object('ok', false, 'code', 'invalid_evidence_path');
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
  where object.bucket_id = 'identity-evidence'
    and object.name = p_storage_path
    and object.owner_id = auth.uid()::text;

  if not found then
    return jsonb_build_object('ok', false, 'code', 'evidence_object_not_found');
  end if;
  if v_mime not in ('image/jpeg', 'image/png', 'application/pdf') then
    return jsonb_build_object('ok', false, 'code', 'evidence_file_type_invalid');
  end if;
  if v_size < 1 or v_size > 10485760 then
    return jsonb_build_object('ok', false, 'code', 'evidence_file_size_invalid');
  end if;
  if p_sha256 is not null and p_sha256 !~ '^[A-Fa-f0-9]{64}$' then
    return jsonb_build_object('ok', false, 'code', 'evidence_hash_invalid');
  end if;

  insert into public.identity_verification_evidence (
    id, verification_id, user_id, evidence_type, storage_path,
    content_type, byte_size, sha256,
    retention_delete_at
  ) values (
    p_evidence_id, p_verification_id, auth.uid(), v_evidence_type,
    p_storage_path, v_mime, v_size, upper(p_sha256),
    coalesce(v_verification.retention_delete_at, now() + interval '30 days')
  ) returning * into v_evidence;

  if v_evidence.sha256 is not null and exists (
    select 1
    from public.identity_verification_evidence other
    where other.sha256 = v_evidence.sha256
      and other.user_id <> auth.uid()
  ) then
    insert into public.identity_risk_signals (
      verification_id, user_id, signal_type, severity,
      signal_data
    ) values (
      p_verification_id,
      auth.uid(),
      'duplicate_client_evidence_fingerprint',
      'high',
      jsonb_build_object('evidence_id', p_evidence_id)
    );
  end if;

  insert into public.verification_audit_events (
    verification_id, evidence_id, actor_id, action,
    event_data
  ) values (
    p_verification_id,
    p_evidence_id,
    auth.uid(),
    'evidence_registered',
    jsonb_build_object('evidence_type', v_evidence_type, 'content_type', v_mime, 'byte_size', v_size)
  );

  return jsonb_build_object(
    'ok', true,
    'evidence_id', v_evidence.id,
    'evidence_type', v_evidence.evidence_type,
    'status', v_evidence.evidence_status
  );
exception
  when unique_violation then
    select * into v_evidence
    from public.identity_verification_evidence evidence
    where evidence.id = p_evidence_id
      and evidence.verification_id = p_verification_id
      and evidence.user_id = auth.uid()
      and evidence.storage_path = p_storage_path;
    if v_evidence.id is not null then
      return jsonb_build_object(
        'ok', true,
        'idempotent', true,
        'evidence_id', v_evidence.id,
        'evidence_type', v_evidence.evidence_type,
        'status', v_evidence.evidence_status
      );
    end if;
    return jsonb_build_object('ok', false, 'code', 'evidence_slot_already_used');
end;
$$;

create or replace function public.submit_identity_verification(
  p_verification_id uuid,
  p_acknowledged boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_verification public.identity_verifications%rowtype;
  v_has_identity_document boolean;
  v_has_selfie boolean;
  v_has_address boolean;
  v_next_status public.identity_verification_state;
  v_admin record;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if not p_acknowledged then
    return jsonb_build_object('ok', false, 'code', 'verification_privacy_acknowledgement_required');
  end if;

  select * into v_verification
  from public.identity_verifications verification
  where verification.id = p_verification_id
    and verification.user_id = auth.uid()
  for update;

  if v_verification.id is null then
    return jsonb_build_object('ok', false, 'code', 'verification_not_found');
  end if;
  if v_verification.status not in ('verification_started', 'additional_information_required') then
    return jsonb_build_object('ok', false, 'code', 'verification_not_submittable');
  end if;

  select
    bool_or(evidence.evidence_type in (
      'school_photo_id', 'drivers_license', 'state_id', 'learner_permit',
      'passport', 'passport_card', 'other_government_id',
      'school_account_assertion', 'accredited_program_id',
      'youth_organization_id', 'homeschool_document', 'supporting_document'
    )),
    bool_or(evidence.evidence_type = 'ownership_selfie'),
    bool_or(evidence.evidence_type = 'address_document')
  into v_has_identity_document, v_has_selfie, v_has_address
  from public.identity_verification_evidence evidence
  where evidence.verification_id = p_verification_id;

  if not coalesce(v_has_identity_document, false) then
    return jsonb_build_object('ok', false, 'code', 'identity_document_required');
  end if;
  if not coalesce(v_has_selfie, false) then
    return jsonb_build_object('ok', false, 'code', 'ownership_selfie_required');
  end if;
  if v_verification.account_role in ('adult', 'guardian')
     and not coalesce(v_has_address, false) then
    return jsonb_build_object('ok', false, 'code', 'address_evidence_required');
  end if;

  v_next_status := case
    when v_verification.evidence_route in ('manual_exception', 'verified_school_account')
      then 'manual_review'::public.identity_verification_state
    else 'verification_pending'::public.identity_verification_state
  end;

  update public.identity_verifications
  set status = v_next_status,
      submitted_at = now(),
      updated_at = now(),
      rejection_code = null
  where id = p_verification_id
  returning * into v_verification;

  perform set_config('mort.internal_update', 'true', true);
  update public.profiles
  set verification_status = 'pending', updated_at = now()
  where id = auth.uid();
  perform set_config('mort.internal_update', '', true);

  insert into public.verification_audit_events (
    verification_id, actor_id, action, event_data
  ) values (
    p_verification_id,
    auth.uid(),
    'verification_submitted',
    jsonb_build_object('status', v_next_status)
  );

  for v_admin in
    select distinct profile.id
    from public.profiles profile
    join public.admin_role_assignments assignment
      on assignment.user_id = profile.id
     and assignment.revoked_at is null
    where profile.role = 'admin'
      and assignment.role in ('verification_reviewer', 'super_admin')
  loop
    perform public.enqueue_notification(
      v_admin.id,
      'Identity verification ready',
      'A restricted identity-verification request is ready for authorized review.',
      jsonb_build_object('verificationId', p_verification_id, 'queue', 'identity_verifications')
    );
  end loop;

  return jsonb_build_object(
    'ok', true,
    'id', v_verification.id,
    'status', v_verification.status,
    'marketplace_enabled', false
  );
end;
$$;

create or replace function public.submit_identity_verification_appeal(
  p_verification_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_verification public.identity_verifications%rowtype;
  v_appeal public.identity_verification_appeals%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if char_length(btrim(coalesce(p_reason, ''))) < 20 then
    return jsonb_build_object('ok', false, 'code', 'appeal_reason_required');
  end if;

  select * into v_verification
  from public.identity_verifications verification
  where verification.id = p_verification_id
    and verification.user_id = auth.uid()
  for update;

  if v_verification.id is null then
    return jsonb_build_object('ok', false, 'code', 'verification_not_found');
  end if;
  if v_verification.status not in ('verification_rejected', 'verification_suspended', 'verification_expired') then
    return jsonb_build_object('ok', false, 'code', 'verification_not_appealable');
  end if;

  insert into public.identity_verification_appeals (
    verification_id, user_id, reason
  ) values (
    p_verification_id, auth.uid(), left(btrim(p_reason), 2000)
  ) returning * into v_appeal;

  update public.identity_verifications
  set status = 'appeal_pending', appeal_status = 'pending', updated_at = now()
  where id = p_verification_id;

  insert into public.verification_audit_events (
    verification_id, actor_id, action
  ) values (p_verification_id, auth.uid(), 'appeal_submitted');

  return jsonb_build_object('ok', true, 'appeal_id', v_appeal.id, 'status', v_appeal.status);
end;
$$;

create or replace function public.authorize_identity_evidence_access(
  p_evidence_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_evidence public.identity_verification_evidence%rowtype;
  v_grant public.verification_evidence_access_grants%rowtype;
begin
  if auth.uid() is null or not private.has_admin_safety_role(
    auth.uid(),
    array['verification_reviewer', 'senior_safety_moderator']::public.admin_safety_role[]
  ) then
    return jsonb_build_object('ok', false, 'code', 'verification_reviewer_required');
  end if;
  if char_length(btrim(coalesce(p_reason, ''))) < 10 then
    return jsonb_build_object('ok', false, 'code', 'evidence_access_reason_required');
  end if;

  select * into v_evidence
  from public.identity_verification_evidence evidence
  where evidence.id = p_evidence_id;
  if v_evidence.id is null then
    return jsonb_build_object('ok', false, 'code', 'evidence_not_found');
  end if;

  insert into public.verification_evidence_access_grants (
    evidence_id, reviewer_id, access_reason, expires_at
  ) values (
    p_evidence_id, auth.uid(), left(btrim(p_reason), 500), now() + interval '5 minutes'
  ) returning * into v_grant;

  insert into public.verification_audit_events (
    verification_id, evidence_id, actor_id, action, access_reason,
    event_data
  ) values (
    v_evidence.verification_id,
    p_evidence_id,
    auth.uid(),
    'evidence_access_authorized',
    left(btrim(p_reason), 500),
    jsonb_build_object('expires_at', v_grant.expires_at)
  );

  return jsonb_build_object(
    'ok', true,
    'evidence_id', v_evidence.id,
    'bucket_id', v_evidence.bucket_id,
    'storage_path', v_evidence.storage_path,
    'content_type', v_evidence.content_type,
    'expires_at', v_grant.expires_at
  );
end;
$$;

create or replace function public.admin_review_identity_verification(
  p_verification_id uuid,
  p_action text,
  p_decision_code text default null,
  p_identity_match_result text default 'not_checked',
  p_liveness_result text default 'not_checked',
  p_email_result text default 'not_checked',
  p_phone_result text default 'not_checked',
  p_address_result text default 'not_checked',
  p_expires_at timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_verification public.identity_verifications%rowtype;
  v_action text := lower(btrim(coalesce(p_action, '')));
  v_level smallint;
  v_profile_status public.verification_status;
begin
  if auth.uid() is null or not private.has_admin_safety_role(
    auth.uid(),
    array['verification_reviewer', 'senior_safety_moderator']::public.admin_safety_role[]
  ) then
    return jsonb_build_object('ok', false, 'code', 'verification_reviewer_required');
  end if;

  select * into v_verification
  from public.identity_verifications verification
  where verification.id = p_verification_id
  for update;

  if v_verification.id is null then
    return jsonb_build_object('ok', false, 'code', 'verification_not_found');
  end if;
  if v_verification.status not in (
    'verification_pending', 'manual_review', 'additional_information_required', 'appeal_pending'
  ) then
    return jsonb_build_object('ok', false, 'code', 'verification_not_reviewable');
  end if;

  if v_action = 'approve' then
    if p_identity_match_result not in ('passed', 'manual_pass')
       or p_liveness_result not in ('passed', 'manual_pass')
       or p_email_result not in ('passed', 'manual_pass') then
      return jsonb_build_object('ok', false, 'code', 'required_identity_checks_incomplete');
    end if;
    if v_verification.account_role in ('adult', 'guardian')
       and (
         p_phone_result not in ('passed', 'manual_pass')
         or p_address_result not in ('passed', 'manual_pass')
       ) then
      return jsonb_build_object('ok', false, 'code', 'required_adult_checks_incomplete');
    end if;
    if p_expires_at is null or p_expires_at <= now() or p_expires_at > now() + interval '3 years' then
      return jsonb_build_object('ok', false, 'code', 'verification_expiry_required');
    end if;
    v_level := case when v_verification.account_role = 'teen' then 1 else 2 end;
    v_profile_status := 'approved';
    update public.identity_verifications
    set status = 'verified',
        verification_level = v_level,
        identity_match_result = left(p_identity_match_result, 80),
        liveness_result = left(p_liveness_result, 80),
        email_verification_result = left(p_email_result, 80),
        phone_verification_result = left(p_phone_result, 80),
        address_validation_result = left(p_address_result, 80),
        reviewer_id = auth.uid(), reviewed_at = now(), expires_at = p_expires_at,
        rejection_code = null, appeal_status = 'none', updated_at = now()
    where id = p_verification_id
    returning * into v_verification;
  elsif v_action = 'request_information' then
    if char_length(btrim(coalesce(p_decision_code, ''))) < 3 then
      return jsonb_build_object('ok', false, 'code', 'decision_code_required');
    end if;
    v_profile_status := 'pending';
    update public.identity_verifications
    set status = 'additional_information_required',
        reviewer_id = auth.uid(), reviewed_at = now(),
        rejection_code = left(btrim(p_decision_code), 100), updated_at = now()
    where id = p_verification_id
    returning * into v_verification;
  elsif v_action = 'reject' then
    if char_length(btrim(coalesce(p_decision_code, ''))) < 3 then
      return jsonb_build_object('ok', false, 'code', 'decision_code_required');
    end if;
    v_profile_status := 'rejected';
    update public.identity_verifications
    set status = 'verification_rejected', verification_level = 0,
        reviewer_id = auth.uid(), reviewed_at = now(),
        rejection_code = left(btrim(p_decision_code), 100), updated_at = now()
    where id = p_verification_id
    returning * into v_verification;
  elsif v_action = 'suspend' then
    if char_length(btrim(coalesce(p_decision_code, ''))) < 3 then
      return jsonb_build_object('ok', false, 'code', 'decision_code_required');
    end if;
    v_profile_status := 'rejected';
    update public.identity_verifications
    set status = 'verification_suspended', verification_level = 0,
        reviewer_id = auth.uid(), reviewed_at = now(),
        rejection_code = left(btrim(p_decision_code), 100), updated_at = now()
    where id = p_verification_id
    returning * into v_verification;
  else
    return jsonb_build_object('ok', false, 'code', 'invalid_verification_action');
  end if;

  perform set_config('mort.internal_update', 'true', true);
  update public.profiles
  set verification_status = v_profile_status, updated_at = now()
  where id = v_verification.user_id;
  perform set_config('mort.internal_update', '', true);

  if v_verification.appeal_status = 'pending' or exists (
    select 1 from public.identity_verification_appeals appeal
    where appeal.verification_id = p_verification_id
      and appeal.status in ('pending', 'reviewing')
  ) then
    update public.identity_verification_appeals
    set status = case when v_action = 'approve' then 'approved' else 'denied' end,
        reviewer_id = auth.uid(),
        decision_note = left(coalesce(nullif(btrim(p_decision_code), ''), v_action), 2000),
        reviewed_at = now()
    where verification_id = p_verification_id
      and status in ('pending', 'reviewing');
  end if;

  insert into public.verification_audit_events (
    verification_id, actor_id, action, event_data
  ) values (
    p_verification_id,
    auth.uid(),
    'verification_' || v_action,
    jsonb_build_object(
      'status', v_verification.status,
      'verification_level', v_verification.verification_level,
      'decision_code', p_decision_code
    )
  );

  perform public.enqueue_notification(
    v_verification.user_id,
    'Identity verification update',
    case
      when v_action = 'approve' then 'Your identity verification was approved.'
      when v_action = 'request_information' then 'Your identity verification needs additional information.'
      when v_action = 'suspend' then 'Your identity verification is suspended while it is reviewed.'
      else 'Your identity verification was not approved. You may review the reason and appeal.'
    end,
    jsonb_build_object('verificationId', p_verification_id, 'status', v_verification.status)
  );

  return jsonb_build_object(
    'ok', true,
    'id', v_verification.id,
    'status', v_verification.status,
    'verification_level', v_verification.verification_level
  );
end;
$$;

create or replace function public.get_public_trust_badges(p_user_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = 'public', 'auth', 'pg_temp'
as $$
declare
  v_profile public.profiles%rowtype;
  v_verification public.identity_verifications%rowtype;
  v_email_verified boolean := false;
  v_phone_verified boolean := false;
  v_business_verified boolean := false;
  v_badges jsonb := '[]'::jsonb;
begin
  select * into v_profile
  from public.profiles profile
  where profile.id = p_user_id
    and profile.account_status = 'active';
  if v_profile.id is null then
    return jsonb_build_object('ok', false, 'code', 'profile_not_found');
  end if;

  select user_record.email_confirmed_at is not null,
         user_record.phone_confirmed_at is not null
  into v_email_verified, v_phone_verified
  from auth.users user_record
  where user_record.id = p_user_id;

  select * into v_verification
  from public.identity_verifications verification
  where verification.user_id = p_user_id
    and verification.status = 'verified'
    and (verification.expires_at is null or verification.expires_at > now())
  order by verification.verification_level desc, verification.reviewed_at desc
  limit 1;

  select exists (
    select 1
    from public.business_verifications business
    where business.adult_id = p_user_id
      and business.status = 'approved'
  ) into v_business_verified;

  if v_email_verified then
    v_badges := v_badges || jsonb_build_array(jsonb_build_object(
      'key', 'email_verified',
      'label', 'Email verified',
      'explanation', 'The account confirmed access to its email address. This does not guarantee safety.',
      'optional', false
    ));
  end if;
  if v_phone_verified then
    v_badges := v_badges || jsonb_build_array(jsonb_build_object(
      'key', 'phone_verified',
      'label', 'Phone verified',
      'explanation', 'The account confirmed access to a phone number. The number is not public and verification does not guarantee safety.',
      'optional', false
    ));
  end if;
  if v_verification.id is not null then
    v_badges := v_badges || jsonb_build_array(jsonb_build_object(
      'key', case when v_profile.role = 'teen' then 'teen_identity_verified' else 'adult_identity_verified' end,
      'label', case when v_profile.role = 'teen' then 'Teen identity verified' else 'Adult identity verified' end,
      'explanation', 'MORT recorded an approved identity and age review. Raw evidence, school details, full birth date, and home address are never shown here. Verification does not guarantee safety.',
      'expires_at', v_verification.expires_at,
      'optional', false,
      'legacy_recheck', coalesce((v_verification.risk_flags->>'legacy_bridge')::boolean, false)
    ));
  end if;
  if v_business_verified then
    v_badges := v_badges || jsonb_build_array(jsonb_build_object(
      'key', 'business_verified',
      'label', 'Business verified',
      'explanation', 'MORT approved submitted business evidence for the responsible account owner. This does not guarantee safety.',
      'optional', true
    ));
  end if;

  return jsonb_build_object('ok', true, 'badges', v_badges);
end;
$$;

create or replace function public.is_verified_adult()
returns boolean
language sql
stable
security definer
set search_path = 'public', 'pg_temp'
as $$
  select exists (
    select 1
    from public.profiles profile
    where profile.id = auth.uid()
      and profile.role in ('adult', 'admin')
      and private.has_marketplace_identity(profile.id)
  );
$$;

create or replace function public.is_application_participant(p_application_id uuid)
returns boolean
language sql
stable
security definer
set search_path = 'public', 'pg_temp'
as $$
  select exists (
    select 1
    from public.applications application
    join public.jobs job on job.id = application.job_id
    where application.id = p_application_id
      and (
        (application.teen_id = auth.uid() and private.has_marketplace_identity(auth.uid()))
        or (application.guardian_id = auth.uid() and private.has_marketplace_identity(auth.uid()))
        or (job.poster_id = auth.uid() and private.has_marketplace_identity(auth.uid()))
        or public.is_admin()
      )
  );
$$;

create or replace function public.is_thread_participant(p_thread_id uuid)
returns boolean
language sql
stable
security definer
set search_path = 'public', 'pg_temp'
as $$
  select exists (
    select 1
    from public.message_threads thread
    where thread.id = p_thread_id
      and (
        (thread.teen_id = auth.uid() and private.has_marketplace_identity(auth.uid()))
        or (thread.adult_id = auth.uid() and private.has_marketplace_identity(auth.uid()))
        or (thread.guardian_id = auth.uid() and private.has_marketplace_identity(auth.uid()))
        or public.is_admin()
      )
  );
$$;

create or replace function private.enforce_marketplace_identity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job public.jobs%rowtype;
begin
  if tg_table_name = 'jobs' then
    if new.status <> 'draft' and not private.has_marketplace_identity(new.poster_id) then
      raise exception 'poster_verification_required';
    end if;
  elsif tg_table_name = 'applications' then
    if not private.has_marketplace_identity(new.teen_id) then
      raise exception 'applicant_verification_required';
    end if;
    if new.status in ('accepted', 'in_progress', 'proof_submitted', 'completed') then
      select * into v_job from public.jobs where id = new.job_id;
      if not private.has_marketplace_identity(v_job.poster_id) then
        raise exception 'poster_verification_required';
      end if;
    end if;
  elsif tg_table_name = 'messages' then
    if not private.has_marketplace_identity(new.sender_id) then
      raise exception 'identity_verification_required';
    end if;
  elsif tg_table_name = 'proof_uploads' then
    if not private.has_marketplace_identity(new.uploaded_by) then
      raise exception 'identity_verification_required';
    end if;
  elsif tg_table_name = 'reviews' then
    if not private.has_marketplace_identity(new.reviewer_id) then
      raise exception 'identity_verification_required';
    end if;
  end if;
  return new;
end;
$$;

revoke all on function private.enforce_marketplace_identity()
from public, anon, authenticated;

create trigger jobs_require_verified_poster
before insert or update of status, poster_id on public.jobs
for each row execute function private.enforce_marketplace_identity();

create trigger applications_require_verified_participants
before insert or update of status, teen_id, job_id on public.applications
for each row execute function private.enforce_marketplace_identity();

create trigger messages_require_verified_sender
before insert on public.messages
for each row execute function private.enforce_marketplace_identity();

create trigger proof_uploads_require_verified_uploader
before insert on public.proof_uploads
for each row execute function private.enforce_marketplace_identity();

create trigger reviews_require_verified_reviewer
before insert on public.reviews
for each row execute function private.enforce_marketplace_identity();

create or replace function public.get_job_application_eligibility(p_job_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_profile public.profiles%rowtype;
  v_job public.jobs%rowtype;
  v_age integer;
  v_guardian_id uuid;
  v_policy jsonb;
  v_guardian_required boolean := false;
begin
  if auth.uid() is null then
    return jsonb_build_object('eligible', false, 'code', 'authentication_required', 'message', 'Sign in before applying.');
  end if;
  select * into v_profile from public.profiles where id = auth.uid();
  if v_profile.id is null or v_profile.role <> 'teen' then
    return jsonb_build_object('eligible', false, 'code', 'user_role_not_allowed', 'message', 'Only teen accounts can apply for jobs.');
  end if;
  if not public.is_profile_active(auth.uid()) or public.teen_is_paused(auth.uid()) then
    return jsonb_build_object('eligible', false, 'code', 'user_account_restricted', 'message', 'Your account is currently restricted.');
  end if;
  if not private.has_marketplace_identity(auth.uid()) then
    return jsonb_build_object('eligible', false, 'code', 'applicant_verification_required', 'message', 'Identity and age verification are required before applying. Guardian Mode is optional.');
  end if;

  select * into v_job from public.jobs where id = p_job_id;
  if v_job.id is null or v_job.status <> 'open' or not v_job.applications_open then
    return jsonb_build_object('eligible', false, 'code', 'job_not_open', 'message', 'This job is no longer accepting applications.');
  end if;
  if v_job.is_test and not v_profile.is_test_account then
    return jsonb_build_object('eligible', false, 'code', 'job_not_open', 'message', 'This job is not available in the production feed.');
  end if;
  if v_job.poster_id = auth.uid() then
    return jsonb_build_object('eligible', false, 'code', 'applicant_is_job_owner', 'message', 'You cannot apply to your own job.');
  end if;
  if v_job.expires_at is not null and v_job.expires_at <= now() then
    return jsonb_build_object('eligible', false, 'code', 'job_expired', 'message', 'This job has expired.');
  end if;
  if v_job.schedule_type = 'exact' and v_job.starts_at is not null and v_job.starts_at <= now() then
    return jsonb_build_object('eligible', false, 'code', 'job_start_time_passed', 'message', 'The start time has passed.');
  end if;
  if not private.has_marketplace_identity(v_job.poster_id) then
    return jsonb_build_object('eligible', false, 'code', 'poster_verification_required', 'message', 'The poster must finish identity verification first.');
  end if;
  if exists (select 1 from public.applications where job_id = p_job_id and teen_id = auth.uid()) then
    return jsonb_build_object('eligible', false, 'code', 'application_already_exists', 'message', 'You already applied to this job.');
  end if;

  v_age := date_part('year', age(current_date, v_profile.dob));
  if v_age < v_job.teen_min_age or v_age > v_job.teen_max_age then
    return jsonb_build_object('eligible', false, 'code', 'applicant_age_not_allowed', 'message', 'Your age does not match this job range.');
  end if;
  if (
    select count(*) from public.applications
    where teen_id = auth.uid()
      and status in ('submitted', 'guardian_pending', 'adult_review', 'viewed', 'accepted', 'in_progress', 'proof_submitted')
  ) >= 20 then
    return jsonb_build_object('eligible', false, 'code', 'application_limit_reached', 'message', 'Finish or withdraw an active application before adding another.');
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
    return jsonb_build_object(
      'eligible', false,
      'code', 'guardian_link_required',
      'message', 'This specific job requires guardian approval. Guardian Mode remains optional for ordinary jobs.',
      'guardian_required_for_this_job', true
    );
  end if;

  return jsonb_build_object(
    'eligible', true,
    'code', 'eligible',
    'message', 'You can apply to this job.',
    'guardian_required_for_this_job', v_guardian_required,
    'guardian_linked', v_guardian_id is not null,
    'identity_verified', true,
    'guardian_mode_optional', true,
    'schedule_type', v_job.schedule_type
  );
end;
$$;

create or replace function public.expire_identity_verifications()
returns integer
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_count integer;
begin
  if coalesce(auth.jwt()->>'role', '') <> 'service_role' then
    raise exception 'service_role_required';
  end if;

  with expired as (
    update public.identity_verifications
    set status = 'verification_expired', verification_level = 0, updated_at = now()
    where status = 'verified'
      and expires_at is not null
      and expires_at <= now()
    returning user_id
  )
  select count(*) into v_count from expired;

  perform set_config('mort.internal_update', 'true', true);
  update public.profiles profile
  set verification_status = 'not_started', updated_at = now()
  where exists (
    select 1
    from public.identity_verifications verification
    where verification.user_id = profile.id
      and verification.status = 'verification_expired'
  )
    and not private.has_marketplace_identity(profile.id);
  perform set_config('mort.internal_update', '', true);

  return v_count;
end;
$$;

revoke all on function public.get_my_identity_verification() from public, anon;
revoke all on function public.start_identity_verification(text, boolean, text) from public, anon;
revoke all on function public.register_identity_evidence(uuid, uuid, text, text, text) from public, anon;
revoke all on function public.submit_identity_verification(uuid, boolean) from public, anon;
revoke all on function public.submit_identity_verification_appeal(uuid, text) from public, anon;
revoke all on function public.authorize_identity_evidence_access(uuid, text) from public, anon;
revoke all on function public.admin_review_identity_verification(uuid, text, text, text, text, text, text, text, timestamptz) from public, anon;
revoke all on function public.get_public_trust_badges(uuid) from public;
revoke all on function public.expire_identity_verifications() from public, anon, authenticated;

grant execute on function public.get_my_identity_verification() to authenticated, service_role;
grant execute on function public.start_identity_verification(text, boolean, text) to authenticated, service_role;
grant execute on function public.register_identity_evidence(uuid, uuid, text, text, text) to authenticated, service_role;
grant execute on function public.submit_identity_verification(uuid, boolean) to authenticated, service_role;
grant execute on function public.submit_identity_verification_appeal(uuid, text) to authenticated, service_role;
grant execute on function public.authorize_identity_evidence_access(uuid, text) to authenticated, service_role;
grant execute on function public.admin_review_identity_verification(uuid, text, text, text, text, text, text, text, timestamptz) to authenticated, service_role;
grant execute on function public.get_public_trust_badges(uuid) to anon, authenticated, service_role;
grant execute on function public.expire_identity_verifications() to service_role;

grant select on public.admin_role_assignments to authenticated, service_role;
grant select on public.identity_verifications to authenticated, service_role;
grant select on public.identity_verification_evidence to authenticated, service_role;
grant select on public.identity_verification_appeals to authenticated, service_role;
grant select on public.verification_referee_requests to authenticated, service_role;
grant select on public.verification_evidence_access_grants to authenticated, service_role;
grant select on public.verification_audit_events to authenticated, service_role;
grant select on public.identity_risk_signals to authenticated, service_role;
grant all on public.admin_role_assignments,
  public.identity_verifications,
  public.identity_verification_evidence,
  public.identity_verification_appeals,
  public.verification_referee_requests,
  public.verification_evidence_access_grants,
  public.verification_audit_events,
  public.identity_risk_signals
to service_role;
grant usage, select on sequence public.verification_audit_events_id_seq to service_role;
