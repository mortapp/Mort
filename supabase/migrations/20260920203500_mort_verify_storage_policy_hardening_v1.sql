-- MORT Verify storage policy hardening.
-- Storage RLS policies must not directly read private tables in the
-- authenticated caller's privilege context because PostgreSQL evaluates all
-- applicable storage.objects policies, including for unrelated buckets.

create or replace function private.mort_verify_storage_upload_allowed(
  p_object_name text
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_parts text[];
  v_session_id uuid;
begin
  if v_user_id is null or p_object_name is null then
    return false;
  end if;

  v_parts := string_to_array(p_object_name, '/');
  if coalesce(array_length(v_parts, 1), 0) <> 4
     or v_parts[1] <> v_user_id::text
     or v_parts[2] !~ '^[0-9a-fA-F-]{36}$'
     or v_parts[3] not in ('front', 'back')
     or v_parts[4] !~ '^[0-9a-fA-F-]{36}[.](jpg|jpeg|png|pdf)$' then
    return false;
  end if;

  begin
    v_session_id := v_parts[2]::uuid;
  exception when invalid_text_representation then
    return false;
  end;

  return exists (
    select 1
    from private.mort_verify_sessions session
    where session.id = v_session_id
      and session.user_id = v_user_id
      and session.status in ('school_id_required', 'document_pending')
      and session.expires_at > now()
  );
end;
$$;

revoke all on function private.mort_verify_storage_upload_allowed(text)
from public, anon;
grant execute on function private.mort_verify_storage_upload_allowed(text)
to authenticated;

create or replace function private.mort_verify_storage_delete_unregistered_allowed(
  p_object_name text
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null or p_object_name is null then
    return false;
  end if;

  if split_part(p_object_name, '/', 1) <> v_user_id::text then
    return false;
  end if;

  return not exists (
    select 1
    from private.mort_verify_documents document
    where document.storage_path = p_object_name
      and document.status = 'active'
  );
end;
$$;

revoke all on function private.mort_verify_storage_delete_unregistered_allowed(text)
from public, anon;
grant execute on function private.mort_verify_storage_delete_unregistered_allowed(text)
to authenticated;

drop policy if exists mort_verify_owner_upload on storage.objects;
create policy mort_verify_owner_upload
on storage.objects for insert to authenticated
with check (
  bucket_id = 'mort-verify-evidence'
  and name !~ '(^|/)\\.\\.(/|$)'
  and lower(storage.extension(name)) in ('jpg', 'jpeg', 'png', 'pdf')
  and private.mort_verify_storage_upload_allowed(name)
);

drop policy if exists mort_verify_owner_delete_unregistered on storage.objects;
create policy mort_verify_owner_delete_unregistered
on storage.objects for delete to authenticated
using (
  bucket_id = 'mort-verify-evidence'
  and owner_id = (select auth.uid())::text
  and private.mort_verify_storage_delete_unregistered_allowed(name)
);
