create or replace function private.can_upload_identity_evidence(
  p_verification_id text,
  p_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_verification_id ~ '^[0-9a-fA-F-]{36}$'
    and exists (
      select 1
      from public.identity_verifications verification
      where verification.id::text = p_verification_id
        and verification.user_id = p_user_id
        and verification.status in (
          'verification_started',
          'additional_information_required'
        )
    );
$$;

create or replace function private.can_delete_unregistered_identity_object(
  p_storage_path text,
  p_verification_id text,
  p_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_verification_id ~ '^[0-9a-fA-F-]{36}$'
    and exists (
      select 1
      from public.identity_verifications verification
      where verification.id::text = p_verification_id
        and verification.user_id = p_user_id
        and verification.status in (
          'verification_started',
          'additional_information_required'
        )
    )
    and not exists (
      select 1
      from public.identity_verification_evidence evidence
      where evidence.storage_path = p_storage_path
    );
$$;

grant execute on function private.can_upload_identity_evidence(text, uuid)
to authenticated, service_role;
grant execute on function private.can_delete_unregistered_identity_object(text, text, uuid)
to authenticated, service_role;

drop policy if exists identity_evidence_upload_started_attempt
on storage.objects;

create policy identity_evidence_upload_started_attempt
on storage.objects for insert to authenticated
with check (
  bucket_id = 'identity-evidence'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and name !~ '(^|/)\.\.(/|$)'
  and lower(storage.extension(name)) in ('jpg', 'jpeg', 'png', 'pdf')
  and private.can_upload_identity_evidence(
    (storage.foldername(name))[2],
    (select auth.uid())
  )
);

drop policy if exists identity_evidence_delete_unregistered
on storage.objects;

create policy identity_evidence_delete_unregistered
on storage.objects for delete to authenticated
using (
  bucket_id = 'identity-evidence'
  and owner_id = (select auth.uid())::text
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and private.can_delete_unregistered_identity_object(
    name,
    (storage.foldername(name))[2],
    (select auth.uid())
  )
);
