-- Consolidate MORT Verify on the newer first-party workflow and fail closed
-- on the superseded teen_verification_* client surface.
update private.teen_verification_control
set mode = 'disabled',
    legal_approved = false,
    privacy_approved = false,
    trained_reviewers_ready = false,
    production_enabled = false,
    updated_at = now()
where singleton;

drop policy if exists teen_school_id_insert_own on storage.objects;
drop policy if exists teen_school_id_delete_unregistered_own on storage.objects;
drop policy if exists teen_school_id_reviewer_read on storage.objects;

revoke execute on function public.get_my_teen_verification() from authenticated, service_role;
revoke execute on function public.start_my_teen_verification() from authenticated, service_role;
revoke execute on function public.sync_my_teen_school_affiliation(uuid) from authenticated, service_role;
revoke execute on function public.register_my_teen_school_id(uuid,text,text) from authenticated, service_role;
revoke execute on function public.submit_my_teen_verification() from authenticated, service_role;
revoke execute on function public.get_teen_verification_review_queue(text,text) from authenticated, service_role;
revoke execute on function public.claim_teen_verification_review(uuid,text,text) from authenticated, service_role;
revoke execute on function public.authorize_teen_school_id_access(uuid,text,text) from authenticated, service_role;
revoke execute on function public.review_teen_verification(
  uuid,text,boolean,boolean,boolean,boolean,text,boolean,text,text,text
) from authenticated, service_role;

-- Keep legacy retention cleanup service-only while residual sandbox evidence ages out.
create or replace function public.service_list_expired_teen_school_id_objects(
  p_limit integer default 100
)
returns table(document_id uuid, session_id uuid, bucket_id text, object_name text)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then
    raise insufficient_privilege using message = 'service_role_required';
  end if;

  return query
  select
    document.id,
    document.session_id,
    document.bucket_id,
    document.storage_path
  from private.teen_school_id_documents document
  where document.deleted_at is null
    and document.retention_delete_at <= now()
    and (document.preserved_until is null or document.preserved_until <= now())
    and not exists (
      select 1
      from private.teen_verification_review_assignments assignment
      where assignment.session_id = document.session_id
        and assignment.revoked_at is null
        and assignment.expires_at > now()
    )
    and not exists (
      select 1
      from private.teen_school_id_access_grants access_grant
      where access_grant.document_id = document.id
        and access_grant.revoked_at is null
        and access_grant.expires_at > now()
    )
  order by document.retention_delete_at, document.id
  limit least(greatest(coalesce(p_limit, 100), 1), 500);
end;
$$;

revoke all on function public.service_list_expired_teen_school_id_objects(integer)
from public, anon, authenticated;
grant execute on function public.service_list_expired_teen_school_id_objects(integer)
to service_role;

create or replace function public.service_finalize_teen_school_id_purge(
  p_document_ids uuid[]
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer := 0;
  v_document private.teen_school_id_documents%rowtype;
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then
    return jsonb_build_object('ok', false, 'code', 'service_role_required');
  end if;
  if p_document_ids is null or cardinality(p_document_ids) = 0 then
    return jsonb_build_object('ok', true, 'purged', 0);
  end if;
  if cardinality(p_document_ids) > 500 then
    return jsonb_build_object('ok', false, 'code', 'purge_batch_too_large');
  end if;

  for v_document in
    select document.*
    from private.teen_school_id_documents document
    where document.id = any(p_document_ids)
      and document.deleted_at is null
      and document.retention_delete_at <= now()
      and (document.preserved_until is null or document.preserved_until <= now())
      and not exists (
        select 1
        from private.teen_verification_review_assignments assignment
        where assignment.session_id = document.session_id
          and assignment.revoked_at is null
          and assignment.expires_at > now()
      )
      and not exists (
        select 1
        from private.teen_school_id_access_grants access_grant
        where access_grant.document_id = document.id
          and access_grant.revoked_at is null
          and access_grant.expires_at > now()
      )
    for update
  loop
    insert into private.teen_verification_audit_events (
      session_id, document_id, actor_id, action, safe_code, event_data
    ) values (
      v_document.session_id,
      v_document.id,
      null,
      'teen_school_id_retention_purged',
      'retention_expired',
      jsonb_build_object(
        'retention_delete_at', v_document.retention_delete_at,
        'preservation_active', false
      )
    );

    delete from private.teen_school_id_documents
    where id = v_document.id;

    v_count := v_count + 1;
  end loop;

  return jsonb_build_object('ok', true, 'purged', v_count);
end;
$$;

revoke all on function public.service_finalize_teen_school_id_purge(uuid[])
from public, anon, authenticated;
grant execute on function public.service_finalize_teen_school_id_purge(uuid[])
to service_role;

-- Re-check reviewer authority at the moment a raw-ID signed URL is requested.
-- An unexpired assignment must not outlive revocation/expiry of the staff role.
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

  if p_reviewer_id is null
     or not private.has_admin_safety_role(
       p_reviewer_id,
       array['verification_reviewer','senior_safety_moderator']::public.admin_safety_role[]
     ) then
    return jsonb_build_object('ok',false,'code','verification_reviewer_required');
  end if;

  if p_side not in ('front','back') then
    return jsonb_build_object('ok',false,'code','invalid_document_side');
  end if;

  if not exists (
    select 1
    from private.mort_verify_review_assignments assignment
    where assignment.session_id = p_session_id
      and assignment.reviewer_id = p_reviewer_id
      and assignment.revoked_at is null
      and assignment.expires_at > now()
  ) then
    return jsonb_build_object('ok',false,'code','active_review_assignment_required');
  end if;

  select * into v_document
  from private.mort_verify_documents document
  where document.session_id = p_session_id
    and document.side = p_side
    and document.status = 'active'
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
