
create table public.legal_documents (
  id uuid primary key default gen_random_uuid(),
  document_key text not null unique,
  title text not null,
  document_category text not null,
  guardian_mode_independent boolean not null default true,
  publication_status text not null default 'draft_attorney_review',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint legal_documents_key_check check (document_key ~ '^[a-z0-9_]{3,100}$'),
  constraint legal_documents_title_check check (char_length(btrim(title)) between 3 and 200),
  constraint legal_documents_status_check check (publication_status in ('draft_attorney_review', 'published', 'retired')),
  constraint legal_documents_guardian_independent_check check (guardian_mode_independent)
);

create table public.legal_document_versions (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.legal_documents(id) on delete restrict,
  version_label text not null,
  content_hash text not null,
  content_path text,
  content_markdown text,
  effective_at timestamptz,
  published_at timestamptz,
  retired_at timestamptz,
  material_revision boolean not null default true,
  requires_electronic_signature boolean not null default false,
  publication_status text not null default 'draft_attorney_review',
  language_code text not null default 'en-US',
  jurisdiction_policy text not null default 'requires_jurisdiction_specific_attorney_review',
  acceptance_ui_version text not null default 'legal-clickwrap-v1',
  attorney_reviewed_at timestamptz,
  approved_by_counsel_reference text,
  created_at timestamptz not null default now(),
  unique (document_id, version_label),
  unique (id, document_id, content_hash),
  constraint legal_document_versions_label_check check (char_length(btrim(version_label)) between 1 and 100),
  constraint legal_document_versions_hash_check check (content_hash ~ '^[a-f0-9]{64}$'),
  constraint legal_document_versions_status_check check (publication_status in ('draft_attorney_review', 'published', 'retired')),
  constraint legal_document_versions_published_check check (
    publication_status <> 'published'
    or (
      effective_at is not null
      and published_at is not null
      and attorney_reviewed_at is not null
      and nullif(btrim(approved_by_counsel_reference), '') is not null
      and char_length(coalesce(content_markdown, '')) >= 200
    )
  )
);

create table public.legal_role_requirements (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.legal_documents(id) on delete restrict,
  role public.mort_role not null,
  age_band text not null default 'all',
  required boolean not null default true,
  priority integer not null default 100,
  created_at timestamptz not null default now(),
  unique (document_id, role, age_band),
  constraint legal_role_age_band_check check (age_band in ('teen_13_15', 'teen_16_17', 'adult_18_plus', 'all'))
);

create table public.legal_acceptances (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete restrict,
  role public.mort_role not null,
  age_band text not null,
  document_id uuid not null references public.legal_documents(id) on delete restrict,
  document_version_id uuid not null,
  content_hash text not null,
  effective_date timestamptz not null,
  accepted_at timestamptz not null default now(),
  platform text not null,
  app_version text not null,
  language_code text not null,
  jurisdiction_policy text not null,
  acceptance_ui_version text not null,
  affirmative_checkbox boolean not null,
  electronic_signature_text text,
  active boolean not null default true,
  withdrawn_at timestamptz,
  server_request_id uuid not null default gen_random_uuid(),
  created_at timestamptz not null default now(),
  constraint legal_acceptances_version_fk
    foreign key (document_version_id, document_id, content_hash)
    references public.legal_document_versions(id, document_id, content_hash)
    on delete restrict,
  constraint legal_acceptances_affirmative_check check (affirmative_checkbox),
  constraint legal_acceptances_role_check check (role in ('teen', 'adult', 'guardian', 'admin', 'moderator')),
  constraint legal_acceptances_age_band_check check (age_band in ('teen_13_15', 'teen_16_17', 'adult_18_plus')),
  constraint legal_acceptances_withdrawal_check check ((active and withdrawn_at is null) or (not active and withdrawn_at is not null)),
  constraint legal_acceptances_platform_check check (char_length(btrim(platform)) between 2 and 40),
  constraint legal_acceptances_app_version_check check (char_length(btrim(app_version)) between 1 and 40),
  unique (user_id, document_version_id, server_request_id)
);

create unique index legal_acceptances_one_active_version_idx
  on public.legal_acceptances(user_id, document_version_id)
  where active;
create index legal_document_versions_current_idx
  on public.legal_document_versions(document_id, publication_status, effective_at desc, created_at desc);
create index legal_role_requirements_role_idx
  on public.legal_role_requirements(role, age_band, document_id);
create index legal_acceptances_user_document_idx
  on public.legal_acceptances(user_id, document_id, accepted_at desc);

create table public.legal_acceptance_audit_events (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete restrict,
  document_id uuid not null references public.legal_documents(id) on delete restrict,
  document_version_id uuid not null references public.legal_document_versions(id) on delete restrict,
  acceptance_id uuid references public.legal_acceptances(id) on delete restrict,
  event_type text not null,
  event_metadata jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now(),
  constraint legal_acceptance_audit_type_check check (event_type = 'accepted'),
  constraint legal_acceptance_audit_reference_check check (acceptance_id is not null)
);
create index legal_acceptance_audit_user_idx
  on public.legal_acceptance_audit_events(user_id, occurred_at desc);

alter table public.legal_documents enable row level security;
alter table public.legal_document_versions enable row level security;
alter table public.legal_role_requirements enable row level security;
alter table public.legal_acceptances enable row level security;
alter table public.legal_acceptance_audit_events enable row level security;

revoke all on public.legal_documents, public.legal_document_versions,
  public.legal_role_requirements, public.legal_acceptances,
  public.legal_acceptance_audit_events from public, anon, authenticated;
grant select on public.legal_documents, public.legal_document_versions to authenticated;
grant select on public.legal_acceptances to authenticated;
grant all on public.legal_documents, public.legal_document_versions,
  public.legal_role_requirements, public.legal_acceptances,
  public.legal_acceptance_audit_events to service_role;
grant usage, select on sequence public.legal_acceptance_audit_events_id_seq to service_role;

create policy legal_documents_published_select
on public.legal_documents for select to authenticated
using (publication_status = 'published');

create policy legal_versions_published_select
on public.legal_document_versions for select to authenticated
using (
  publication_status = 'published'
  and effective_at is not null
  and effective_at <= now()
  and exists (
    select 1 from public.legal_documents document
    where document.id = legal_document_versions.document_id
      and document.publication_status = 'published'
  )
);

create policy legal_acceptances_owner_select
on public.legal_acceptances for select to authenticated
using (user_id = (select auth.uid()));

create or replace function private.mort_legal_age_band(p_date_of_birth date)
returns text
language sql
stable
set search_path = ''
as $$
  select case
    when p_date_of_birth is null then 'unknown'
    when age(current_date, p_date_of_birth) < interval '13 years' then 'ineligible'
    when age(current_date, p_date_of_birth) < interval '16 years' then 'teen_13_15'
    when age(current_date, p_date_of_birth) < interval '18 years' then 'teen_16_17'
    else 'adult_18_plus'
  end;
$$;
revoke all on function private.mort_legal_age_band(date) from public, anon;
grant execute on function private.mort_legal_age_band(date) to authenticated, service_role;

create or replace function public.get_my_legal_requirements()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with actor as (
    select profile.id, profile.role, profile.date_of_birth,
      private.mort_legal_age_band(profile.date_of_birth) as age_band
    from public.profiles profile
    where profile.id = auth.uid()
      and profile.account_status = 'active'
      and profile.role <> 'pending'
  ), current_versions as (
    select distinct on (version.document_id)
      version.document_id,
      version.id as version_id,
      version.version_label,
      version.content_hash,
      version.effective_at,
      version.language_code,
      version.jurisdiction_policy,
      version.acceptance_ui_version,
      version.requires_electronic_signature
    from public.legal_document_versions version
    join public.legal_documents document
      on document.id = version.document_id
     and document.publication_status = 'published'
    where version.publication_status = 'published'
      and version.effective_at <= now()
    order by version.document_id, version.effective_at desc, version.created_at desc
  ), requirements as (
    select
      document.document_key,
      document.title,
      role_requirement.required,
      current_version.version_id,
      current_version.version_label,
      current_version.content_hash,
      current_version.effective_at,
      current_version.language_code,
      current_version.jurisdiction_policy,
      current_version.acceptance_ui_version,
      current_version.requires_electronic_signature,
      acceptance.id as acceptance_id,
      acceptance.accepted_at
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
    'ok', auth.uid() is not null,
    'guardian_mode_optional', true,
    'acceptance_inferred_from_browsing', false,
    'requirements', coalesce(jsonb_agg(to_jsonb(requirements)), '[]'::jsonb)
  )
  from requirements;
$$;

create or replace function public.submit_legal_acceptance(
  p_document_version_id uuid,
  p_affirmative_checkbox boolean,
  p_teen_summary_viewed boolean,
  p_electronic_signature_text text,
  p_platform text,
  p_app_version text,
  p_language_code text default 'en-US'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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
    and account_status = 'active'
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

create or replace function private.mort_user_has_current_legal_acceptances(p_user_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
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

create or replace function public.complete_my_onboarding_v2(
  p_payload jsonb,
  p_client_request_id uuid,
  p_payload_version integer default 1,
  p_expected_revision text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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

revoke all on function public.get_my_legal_requirements() from public, anon;
revoke all on function public.submit_legal_acceptance(uuid, boolean, boolean, text, text, text, text) from public, anon;
revoke all on function public.complete_my_onboarding_v2(jsonb, uuid, integer, text) from public, anon;
revoke all on function private.mort_user_has_current_legal_acceptances(uuid) from public, anon, authenticated;
grant execute on function public.get_my_legal_requirements() to authenticated;
grant execute on function public.submit_legal_acceptance(uuid, boolean, boolean, text, text, text, text) to authenticated;
grant execute on function public.complete_my_onboarding_v2(jsonb, uuid, integer, text) to authenticated;
grant execute on function public.get_my_legal_requirements() to service_role;
grant execute on function public.submit_legal_acceptance(uuid, boolean, boolean, text, text, text, text) to service_role;
grant execute on function public.complete_my_onboarding_v2(jsonb, uuid, integer, text) to service_role;
