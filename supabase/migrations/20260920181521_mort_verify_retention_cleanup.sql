-- MORT Verify retention cleanup: service-only discovery/finalization for
-- expired school-ID evidence. Raw Storage objects are deleted through the
-- Storage API before metadata is finalized.

alter table private.teen_school_id_documents
  add column if not exists preserved_until timestamptz;

create or replace function public.service_list_expired_teen_school_id_objects(
  p_limit integer default 100
)
returns table (
  document_id uuid,
  session_id uuid,
  bucket_id text,
  object_name text
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.role() <> 'service_role' then
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
  if auth.role() <> 'service_role' then
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
      session_id,
      document_id,
      actor_id,
      action,
      safe_code,
      event_data
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

revoke all on function public.service_list_expired_teen_school_id_objects(integer)
  from public, anon, authenticated;
revoke all on function public.service_finalize_teen_school_id_purge(uuid[])
  from public, anon, authenticated;

grant execute on function public.service_list_expired_teen_school_id_objects(integer)
  to service_role;
grant execute on function public.service_finalize_teen_school_id_purge(uuid[])
  to service_role;

comment on function public.service_list_expired_teen_school_id_objects(integer) is
  'Service-only retention queue for MORT Verify school-ID Storage objects.';
comment on function public.service_finalize_teen_school_id_purge(uuid[]) is
  'Service-only metadata finalization after expired MORT Verify objects are removed from Storage.';
