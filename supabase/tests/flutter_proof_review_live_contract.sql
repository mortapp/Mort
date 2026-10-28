-- Run after the current-model Flutter proof workflow migration. This checks
-- schema and access contracts only; it does not inspect production user rows.
do $$
declare
  v_name text;
  v_oid oid;
  v_definition text;
  v_required text[] := array[
    'public.begin_application_proof_upload(uuid,uuid,text,text)',
    'public.submit_application_proof(uuid,uuid,text,text)',
    'public.abort_application_proof_upload(uuid,uuid)',
    'public.review_application_proof(uuid,text,text)',
    'public.complete_job_after_proof(uuid,uuid)'
  ];
begin
  if to_regclass('public.proof_uploads') is null then
    raise exception 'current-model proof upload table is missing';
  end if;
  if not (select relrowsecurity from pg_catalog.pg_class
          where oid = to_regclass('public.proof_uploads')) then
    raise exception 'proof uploads must have RLS enabled';
  end if;
  if pg_catalog.has_table_privilege('anon','public.proof_uploads','select')
     or pg_catalog.has_table_privilege('authenticated','public.proof_uploads','insert')
     or pg_catalog.has_table_privilege('authenticated','public.proof_uploads','update')
     or pg_catalog.has_table_privilege('authenticated','public.proof_uploads','delete') then
    raise exception 'proof rows must be read-only to clients';
  end if;
  if not pg_catalog.has_table_privilege('authenticated','public.proof_uploads','select') then
    raise exception 'participants need authorized proof reads';
  end if;

  if not exists (select 1 from storage.buckets
      where id='proof-uploads' and name='proof-uploads' and not public
        and file_size_limit=10485760
        and allowed_mime_types=array['image/jpeg']::text[]) then
    raise exception 'proof bucket must be private and limited to 10 MB JPEGs';
  end if;
  if not exists (select 1 from pg_catalog.pg_policies
      where schemaname='storage' and tablename='objects'
        and policyname='mort_proof_upload_owned_pending')
     or not exists (select 1 from pg_catalog.pg_policies
      where schemaname='storage' and tablename='objects'
        and policyname='mort_proof_read_participants')
     or not exists (select 1 from pg_catalog.pg_policies
      where schemaname='storage' and tablename='objects'
        and policyname='mort_proof_delete_owned_pending') then
    raise exception 'proof storage needs explicit pending-upload and participant policies';
  end if;

  foreach v_name in array v_required loop
    v_oid := pg_catalog.to_regprocedure(v_name);
    if v_oid is null then
      raise exception 'required proof RPC is missing: %', v_name;
    end if;
    if (select prosecdef from pg_catalog.pg_proc where oid=v_oid) then
      raise exception 'public proof wrapper must preserve caller privileges: %', v_name;
    end if;
    if pg_catalog.has_function_privilege('anon',v_oid,'execute')
       or not pg_catalog.has_function_privilege('authenticated',v_oid,'execute') then
      raise exception 'proof RPC grants are not authenticated-only: %', v_name;
    end if;
  end loop;

  foreach v_name in array array[
    'private.begin_application_proof_upload_internal(uuid,uuid,text,text)',
    'private.submit_application_proof_internal(uuid,uuid,text,text)',
    'private.abort_application_proof_upload_internal(uuid,uuid)',
    'private.review_application_proof_internal(uuid,text,text)',
    'private.complete_job_after_proof_internal(uuid,uuid)'
  ] loop
    v_oid := pg_catalog.to_regprocedure(v_name);
    if v_oid is null or not (select prosecdef from pg_catalog.pg_proc where oid=v_oid) then
      raise exception 'private proof implementation is missing or not SECURITY DEFINER: %',v_name;
    end if;
    if pg_catalog.has_function_privilege('anon',v_oid,'execute') then
      raise exception 'anon can execute private proof implementation: %',v_name;
    end if;
  end loop;

  v_definition := pg_catalog.pg_get_functiondef(
    'private.begin_application_proof_upload_internal(uuid,uuid,text,text)'::regprocedure
  );
  if v_definition not like '%30 minutes%' then
    raise exception 'stale pending proof uploads must not block retries forever';
  end if;

  v_definition := pg_catalog.pg_get_functiondef(
    'private.complete_job_after_proof_internal(uuid,uuid)'::regprocedure
  );
  if v_definition not like '%completion_pending_release%'
     or v_definition not like '%completion_review_window_open%' then
    raise exception 'job completion must preserve the server review window';
  end if;
end;
$$;
