create or replace function private.can_delete_unregistered_incident_object(
  p_storage_path text,
  p_incident_id text,
  p_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null
    and auth.uid() = p_user_id
    and p_incident_id ~ '^[0-9a-fA-F-]{36}$'
    and exists (
      select 1
      from public.incident_participants participant
      where participant.incident_id::text = p_incident_id
        and participant.user_id = p_user_id
        and participant.can_submit_evidence
    )
    and not exists (
      select 1
      from public.incident_evidence evidence
      where evidence.storage_path = p_storage_path
    );
$$;

revoke all on function private.can_delete_unregistered_incident_object(text, text, uuid)
from public, anon;
grant execute on function private.can_delete_unregistered_incident_object(text, text, uuid)
to authenticated, service_role;

drop policy if exists incident_evidence_delete_unregistered
on storage.objects;

create policy incident_evidence_delete_unregistered
on storage.objects for delete to authenticated
using (
  bucket_id = 'incident-evidence'
  and owner_id = (select auth.uid())::text
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and private.can_delete_unregistered_incident_object(
    name,
    (storage.foldername(name))[2],
    (select auth.uid())
  )
);
