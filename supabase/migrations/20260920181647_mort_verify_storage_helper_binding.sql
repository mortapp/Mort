-- Bind Storage policy helper arguments to the authenticated caller so the
-- helpers cannot be repurposed as cross-account state probes.

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
  select
    auth.uid() is not null
    and auth.uid() = p_user_id
    and exists (
      select 1
      from private.teen_verification_sessions session
      where session.id = p_session_id
        and session.user_id = auth.uid()
        and session.status in (
          'created','school_email_required','document_required','document_submitted'
        )
        and private.teen_verification_submissions_enabled(auth.uid())
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
    auth.uid() is not null
    and auth.uid() = p_user_id
    and p_storage_path like auth.uid()::text || '/%'
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
  select
    auth.uid() is not null
    and auth.uid() = p_reviewer_id
    and exists (
      select 1
      from private.teen_school_id_documents document
      join private.teen_verification_review_assignments assignment
        on assignment.session_id = document.session_id
       and assignment.reviewer_id = auth.uid()
       and assignment.revoked_at is null
       and assignment.expires_at > now()
      join private.teen_school_id_access_grants access_grant
        on access_grant.document_id = document.id
       and access_grant.reviewer_id = auth.uid()
       and access_grant.revoked_at is null
       and access_grant.expires_at > now()
      where document.storage_path = p_storage_path
        and document.deleted_at is null
        and private.has_trust_admin_role(
          auth.uid(),
          array['verification_reviewer','senior_verification_reviewer']::text[]
        )
    );
$$;

revoke all on function private.can_upload_teen_school_id(uuid, uuid)
  from public, anon;
revoke all on function private.can_delete_unregistered_teen_school_id(text, uuid)
  from public, anon;
revoke all on function private.can_read_teen_school_id(text, uuid)
  from public, anon;
grant execute on function private.can_upload_teen_school_id(uuid, uuid)
  to authenticated, service_role;
grant execute on function private.can_delete_unregistered_teen_school_id(text, uuid)
  to authenticated, service_role;
grant execute on function private.can_read_teen_school_id(text, uuid)
  to authenticated, service_role;
