drop policy if exists proof_uploads_insert_accepted_teen
on public.proof_uploads;
create policy proof_uploads_insert_admin_only
on public.proof_uploads for insert to authenticated
with check (public.is_admin());

create or replace function public.submit_application_proof(
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
  select * into v_application
  from public.applications
  where id = p_application_id;
  if v_application.id is null then
    return jsonb_build_object('ok', false, 'code', 'application_not_found');
  end if;
  if v_application.teen_id <> auth.uid() then
    return jsonb_build_object('ok', false, 'code', 'unknown_permission_failure');
  end if;
  if v_application.status <> 'in_progress' then
    return jsonb_build_object('ok', false, 'code', 'invalid_application_transition');
  end if;
  if v_path = ''
     or v_path !~ ('^' || auth.uid()::text || '/[0-9a-f-]+\.jpg$')
     or position('..' in v_path) > 0 then
    return jsonb_build_object('ok', false, 'code', 'invalid_proof_path');
  end if;
  if not exists (
    select 1
    from storage.objects object
    where object.bucket_id = 'proof-uploads'
      and object.name = v_path
      and object.owner_id = auth.uid()
  ) then
    return jsonb_build_object('ok', false, 'code', 'proof_object_not_found');
  end if;

  insert into public.proof_uploads (
    application_id,
    uploaded_by,
    storage_path,
    note
  ) values (
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
    and status = 'in_progress'
  returning * into v_job;

  if v_job.id is null then
    raise exception using
      errcode = 'P0001',
      message = 'Job is not ready for proof submission.';
  end if;

  return jsonb_build_object(
    'ok', true,
    'proof', to_jsonb(v_proof),
    'application', to_jsonb(v_application),
    'job', to_jsonb(v_job)
  );
end;
$$;

revoke execute on function public.submit_application_proof(uuid, text, text)
from public, anon;
grant execute on function public.submit_application_proof(uuid, text, text)
to authenticated, service_role;
