create or replace function public.submit_application_proof(
  p_proof_id uuid,
  p_application_id uuid,
  p_storage_path text,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_application public.applications%rowtype;
  v_job public.jobs%rowtype;
  v_proof public.proof_uploads%rowtype;
  v_path text := btrim(coalesce(p_storage_path, ''));
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_proof_id is null then
    return jsonb_build_object('ok', false, 'code', 'invalid_proof_submission');
  end if;
  if v_path = ''
     or v_path <> (auth.uid()::text || '/' || p_proof_id::text || '.jpg')
     or position('..' in v_path) > 0 then
    return jsonb_build_object('ok', false, 'code', 'invalid_proof_path');
  end if;

  select * into v_proof
  from public.proof_uploads
  where id = p_proof_id;
  if v_proof.id is not null then
    if v_proof.application_id <> p_application_id
       or v_proof.uploaded_by <> auth.uid()
       or v_proof.storage_path <> v_path then
      return jsonb_build_object('ok', false, 'code', 'unknown_permission_failure');
    end if;
    select * into v_application
    from public.applications
    where id = v_proof.application_id;
    select * into v_job
    from public.jobs
    where id = v_application.job_id;
    return jsonb_build_object(
      'ok', true,
      'idempotent', true,
      'proof', to_jsonb(v_proof),
      'application', to_jsonb(v_application),
      'job', to_jsonb(v_job)
    );
  end if;

  select * into v_application
  from public.applications
  where id = p_application_id
  for update;
  if v_application.id is null then
    return jsonb_build_object('ok', false, 'code', 'application_not_found');
  end if;
  if v_application.teen_id <> auth.uid() then
    return jsonb_build_object('ok', false, 'code', 'unknown_permission_failure');
  end if;
  if v_application.status <> 'in_progress' then
    return jsonb_build_object('ok', false, 'code', 'invalid_application_transition');
  end if;

  select * into v_job
  from public.jobs
  where id = v_application.job_id
  for update;
  if v_job.id is null or v_job.status <> 'in_progress' then
    return jsonb_build_object('ok', false, 'code', 'invalid_job_transition');
  end if;
  if not exists (
    select 1
    from storage.objects object
    where object.bucket_id = 'proof-uploads'
      and object.name = v_path
      and object.owner_id = auth.uid()::text
  ) then
    return jsonb_build_object('ok', false, 'code', 'proof_object_not_found');
  end if;

  insert into public.proof_uploads (
    id,
    application_id,
    uploaded_by,
    storage_path,
    note
  ) values (
    p_proof_id,
    p_application_id,
    auth.uid(),
    v_path,
    nullif(left(btrim(coalesce(p_note, '')), 500), '')
  ) returning * into v_proof;

  update public.applications
  set status = 'proof_submitted'
  where id = p_application_id
  returning * into v_application;

  update public.jobs
  set status = 'proof_submitted'
  where id = v_application.job_id
  returning * into v_job;

  return jsonb_build_object(
    'ok', true,
    'idempotent', false,
    'proof', to_jsonb(v_proof),
    'application', to_jsonb(v_application),
    'job', to_jsonb(v_job)
  );
end;
$$;

revoke execute on function public.submit_application_proof(uuid, uuid, text, text)
from public, anon;
grant execute on function public.submit_application_proof(uuid, uuid, text, text)
to authenticated, service_role;
