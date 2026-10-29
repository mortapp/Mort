-- Fail closed on legal publication. Public clients may read only versions that are
-- published, effective, attorney-reviewed, counsel-referenced, and hash-consistent.
-- The release RPC returns a boolean summary only; draft legal content remains private.

begin;

alter table public.legal_documents enable row level security;
alter table public.legal_document_versions enable row level security;
alter table public.legal_role_requirements enable row level security;

revoke all on table public.legal_documents, public.legal_document_versions,
  public.legal_role_requirements from anon, authenticated;
grant select on table public.legal_documents, public.legal_document_versions,
  public.legal_role_requirements to anon, authenticated;

drop policy if exists legal_documents_published_select on public.legal_documents;
create policy legal_documents_published_select
  on public.legal_documents
  for select to anon, authenticated
  using (publication_status = 'published');

drop policy if exists legal_versions_published_select on public.legal_document_versions;
create policy legal_versions_published_select
  on public.legal_document_versions
  for select to anon, authenticated
  using (
    publication_status = 'published'
    and effective_at is not null
    and effective_at <= now()
    and published_at is not null
    and attorney_reviewed_at is not null
    and nullif(btrim(approved_by_counsel_reference), '') is not null
    and length(btrim(coalesce(content_markdown, ''))) >= 200
    and content_hash = encode(
      extensions.digest(convert_to(content_markdown, 'UTF8'), 'sha256'),
      'hex'
    )
    and exists (
      select 1
      from public.legal_documents document
      where document.id = legal_document_versions.document_id
        and document.publication_status = 'published'
    )
  );

drop policy if exists legal_role_requirements_published_select on public.legal_role_requirements;
create policy legal_role_requirements_published_select
  on public.legal_role_requirements
  for select to anon, authenticated
  using (
    required
    and exists (
      select 1
      from public.legal_documents document
      where document.id = legal_role_requirements.document_id
        and document.publication_status = 'published'
    )
  );

create or replace function public.get_my_legal_requirements()
returns jsonb
language sql
stable
security definer
set search_path to ''
as $function$
  with actor as (
    select profile.id, profile.role, profile.date_of_birth,
      private.mort_legal_age_band(profile.date_of_birth) as age_band
    from public.profiles profile
    where profile.id = auth.uid()
      and profile.account_status = 'active'
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
      and version.effective_at is not null
      and version.effective_at <= now()
      and version.published_at is not null
      and version.attorney_reviewed_at is not null
      and nullif(btrim(version.approved_by_counsel_reference), '') is not null
      and length(btrim(coalesce(version.content_markdown, ''))) >= 200
      and version.content_hash = encode(
        extensions.digest(convert_to(version.content_markdown, 'UTF8'), 'sha256'),
        'hex'
      )
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
$function$;

create or replace function public.get_release_mode_status()
returns jsonb
language sql
stable
set search_path to ''
as $function$
  with current_versions as (
    select distinct on (document.document_key)
      document.id as document_id,
      document.document_key,
      document.guardian_mode_independent
    from public.legal_documents document
    join public.legal_document_versions version
      on version.document_id = document.id
    where document.document_key in (
      'master_terms_of_service',
      'privacy_policy',
      'safety_rules',
      'community_guidelines'
    )
      and document.publication_status = 'published'
      and version.publication_status = 'published'
      and version.effective_at is not null
      and version.effective_at <= now()
      and version.published_at is not null
      and version.attorney_reviewed_at is not null
      and nullif(btrim(version.approved_by_counsel_reference), '') is not null
      and length(btrim(coalesce(version.content_markdown, ''))) >= 200
      and version.content_hash = encode(
        extensions.digest(convert_to(version.content_markdown, 'UTF8'), 'sha256'),
        'hex'
      )
    order by document.document_key, version.effective_at desc, version.created_at desc
  ), legal_gate as (
    select
      count(distinct document_key) = 4
        and coalesce(bool_and(guardian_mode_independent), false)
        and coalesce(bool_and(exists (
          select 1 from public.legal_role_requirements requirement
          where requirement.document_id = current_versions.document_id
            and requirement.role = 'teen'
            and requirement.age_band = 'all'
            and requirement.required
        )), false)
        and coalesce(bool_and(exists (
          select 1 from public.legal_role_requirements requirement
          where requirement.document_id = current_versions.document_id
            and requirement.role = 'adult'
            and requirement.age_band = 'all'
            and requirement.required
        )), false)
        and coalesce(bool_and(exists (
          select 1 from public.legal_role_requirements requirement
          where requirement.document_id = current_versions.document_id
            and requirement.role = 'guardian'
            and requirement.age_band = 'all'
            and requirement.required
        )), false)
        as legal_release_ready,
      count(distinct document_key) as published_legal_document_count
    from current_versions
  )
  select coalesce(
    (
      select jsonb_build_object(
        'release_mode', control.release_mode,
        'maintenance_mode', control.maintenance_mode,
        'public_marketplace_enabled', control.public_marketplace_enabled,
        'real_document_collection', control.real_document_collection,
        'legal_release_ready', coalesce(legal_gate.legal_release_ready, false),
        'published_legal_document_count', coalesce(legal_gate.published_legal_document_count, 0)
      )
      from public.mort_release_control control
      cross join legal_gate
      where control.is_primary
    ),
    jsonb_build_object(
      'release_mode', 'unconfigured',
      'maintenance_mode', true,
      'public_marketplace_enabled', false,
      'real_document_collection', false,
      'legal_release_ready', false,
      'published_legal_document_count', 0
    )
  );
$function$;

commit;
