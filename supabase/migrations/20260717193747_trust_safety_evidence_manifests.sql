-- Metadata-only evidence manifests break the reviewer-discovery deadlock
-- without exposing document paths or content before a reasoned access grant.

create or replace function public.get_identity_evidence_manifest(
  p_verification_id uuid
)
returns table (
  evidence_id uuid,
  evidence_type public.identity_evidence_type,
  evidence_status text,
  content_type text,
  byte_size bigint,
  submitted_at timestamptz,
  retention_delete_at timestamptz,
  preserved boolean
)
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
begin
  if auth.uid() is null or not private.has_admin_safety_role(
    auth.uid(),
    array['verification_reviewer', 'senior_safety_moderator']::public.admin_safety_role[]
  ) then
    raise exception 'verification_reviewer_required';
  end if;
  if not exists (
    select 1 from public.identity_verifications verification
    where verification.id = p_verification_id
  ) then
    raise exception 'verification_not_found';
  end if;

  insert into public.verification_audit_events (
    verification_id, actor_id, action, access_reason
  ) values (
    p_verification_id, auth.uid(), 'evidence_manifest_viewed',
    'Reviewer opened metadata-only evidence manifest; no document path or content was returned.'
  );

  return query
  select
    evidence.id,
    evidence.evidence_type,
    evidence.evidence_status,
    evidence.content_type,
    evidence.byte_size,
    evidence.submitted_at,
    evidence.retention_delete_at,
    evidence.preserved_until is not null and evidence.preserved_until > now()
  from public.identity_verification_evidence evidence
  where evidence.verification_id = p_verification_id
  order by evidence.submitted_at;
end;
$$;

create or replace function public.get_incident_evidence_manifest(
  p_incident_id uuid
)
returns table (
  evidence_id uuid,
  evidence_type text,
  evidence_status text,
  content_type text,
  byte_size bigint,
  submitted_at timestamptz,
  retention_delete_at timestamptz,
  preserved boolean
)
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
begin
  if auth.uid() is null or not private.can_manage_incident(auth.uid()) then
    raise exception 'incident_reviewer_required';
  end if;
  if not exists (
    select 1 from public.safety_incidents incident
    where incident.id = p_incident_id
  ) then
    raise exception 'incident_not_found';
  end if;

  insert into public.incident_timeline_events (
    incident_id, actor_id, event_type, restricted_note
  ) values (
    p_incident_id, auth.uid(), 'evidence_manifest_viewed',
    'Reviewer opened metadata-only evidence manifest; no document path or content was returned.'
  );

  return query
  select
    evidence.id,
    evidence.evidence_type,
    evidence.evidence_status,
    evidence.content_type,
    evidence.byte_size,
    evidence.created_at,
    evidence.retention_delete_at,
    evidence.preserved_until is not null and evidence.preserved_until > now()
  from public.incident_evidence evidence
  where evidence.incident_id = p_incident_id
  order by evidence.created_at;
end;
$$;

revoke all on function public.get_identity_evidence_manifest(uuid)
from public, anon;
revoke all on function public.get_incident_evidence_manifest(uuid)
from public, anon;

grant execute on function public.get_identity_evidence_manifest(uuid)
to authenticated, service_role;
grant execute on function public.get_incident_evidence_manifest(uuid)
to authenticated, service_role;
