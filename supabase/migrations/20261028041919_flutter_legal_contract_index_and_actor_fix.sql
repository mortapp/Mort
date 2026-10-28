-- Cover child-side foreign keys reported by the Supabase performance advisor.
create index legal_acceptance_audit_acceptance_idx
  on public.legal_acceptance_audit_events(acceptance_id);
create index legal_acceptance_audit_document_idx
  on public.legal_acceptance_audit_events(document_id);
create index legal_acceptance_audit_version_idx
  on public.legal_acceptance_audit_events(document_version_id);
create index legal_acceptances_document_idx
  on public.legal_acceptances(document_id);
create index legal_acceptances_version_reference_idx
  on public.legal_acceptances(document_version_id, document_id, content_hash);

-- An authenticated user still needs an active, eligible MORT profile.
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
    'ok', exists (select 1 from actor),
    'guardian_mode_optional', true,
    'acceptance_inferred_from_browsing', false,
    'requirements', coalesce(jsonb_agg(to_jsonb(requirements)), '[]'::jsonb)
  )
  from requirements;
$$;
