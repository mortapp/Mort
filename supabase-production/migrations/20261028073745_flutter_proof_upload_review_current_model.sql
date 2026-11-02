-- Current-model completion proof workflow. Evidence is private, written only
-- after a server-created upload manifest, and reviewed by the assigned adult.

create table public.proof_uploads (
  id uuid primary key,
  assignment_id uuid not null references public.job_assignments(id) on delete restrict,
  application_id uuid not null references public.job_applications(id) on delete restrict,
  uploaded_by uuid not null references public.profiles(id) on delete restrict,
  storage_path text not null unique,
  status text not null default 'uploading',
  note text,
  reviewed_by uuid references public.profiles(id) on delete restrict,
  review_note text,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint proof_uploads_status_check check (status in (
    'uploading', 'submitted', 'approved', 'resubmission_requested',
    'rejected', 'abandoned'
  )),
  constraint proof_uploads_path_check check (
    storage_path ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.jpg$'
  ),
  constraint proof_uploads_note_check check (
    note is null or char_length(note) <= 500
  ),
  constraint proof_uploads_review_note_check check (
    review_note is null or char_length(review_note) <= 500
  ),
  constraint proof_uploads_review_state_check check (
    (status in ('approved','resubmission_requested','rejected')
      and reviewed_by is not null and reviewed_at is not null)
    or status not in ('approved','resubmission_requested','rejected')
  )
);

create index proof_uploads_application_created_idx
  on public.proof_uploads(application_id, created_at desc);
create index proof_uploads_assignment_status_idx
  on public.proof_uploads(assignment_id, status, created_at desc);

alter table public.proof_uploads enable row level security;
revoke all on public.proof_uploads from public, anon, authenticated;
grant select on public.proof_uploads to authenticated;
create policy proof_uploads_participants_read
  on public.proof_uploads for select to authenticated
  using (exists (
    select 1 from public.job_assignments assignment
     where assignment.id = assignment_id
       and auth.uid() in (assignment.teen_user_id, assignment.adult_user_id)
  ));

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('proof-uploads', 'proof-uploads', false, 10485760, array['image/jpeg']::text[])
on conflict (id) do nothing;

do $bucket$
begin
  if not exists (
    select 1 from storage.buckets
     where id = 'proof-uploads' and name = 'proof-uploads' and not public
       and file_size_limit = 10485760
       and allowed_mime_types = array['image/jpeg']::text[]
  ) then
    raise exception 'proof-uploads bucket already exists with incompatible settings';
  end if;
end;
$bucket$;

create policy mort_proof_upload_owned_pending
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'proof-uploads'
    and exists (
      select 1 from public.proof_uploads proof
       where proof.storage_path = name and proof.uploaded_by = auth.uid()
         and proof.status = 'uploading'
    )
  );

create policy mort_proof_read_participants
  on storage.objects for select to authenticated
  using (
    bucket_id = 'proof-uploads'
    and exists (
      select 1 from public.proof_uploads proof
      join public.job_assignments assignment on assignment.id = proof.assignment_id
       where proof.storage_path = name
         and proof.status in ('submitted','approved','resubmission_requested','rejected')
         and auth.uid() in (assignment.teen_user_id, assignment.adult_user_id)
    )
  );

create policy mort_proof_delete_owned_pending
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'proof-uploads'
    and exists (
      select 1 from public.proof_uploads proof
       where proof.storage_path = name and proof.uploaded_by = auth.uid()
         and proof.status in ('uploading','abandoned')
    )
  );

create or replace function private.begin_application_proof_upload_internal(
  p_proof_id uuid, p_application_id uuid, p_storage_path text, p_note text
) returns jsonb
language plpgsql security definer set search_path = '' as $function$
declare
  v_assignment public.job_assignments%rowtype;
  v_existing public.proof_uploads%rowtype;
  v_note text := nullif(btrim(p_note), '');
  v_expected_path text;
begin
  if auth.uid() is null then return jsonb_build_object('ok',false,'code','authentication_required'); end if;
  if p_proof_id is null or p_application_id is null then return jsonb_build_object('ok',false,'code','invalid_proof_submission'); end if;
  v_expected_path := auth.uid()::text || '/' || p_proof_id::text || '.jpg';
  if p_storage_path is distinct from v_expected_path then return jsonb_build_object('ok',false,'code','invalid_proof_path'); end if;
  if v_note is not null and char_length(v_note) > 500 then return jsonb_build_object('ok',false,'code','proof_note_too_long'); end if;

  select assignment.* into v_assignment
    from public.job_assignments assignment
   where assignment.application_id = p_application_id
   for update;
  if not found or v_assignment.teen_user_id <> auth.uid() then return jsonb_build_object('ok',false,'code','job_participant_required'); end if;
  if v_assignment.status not in ('in_progress','awaiting_confirmation') then return jsonb_build_object('ok',false,'code','job_not_ready_for_proof'); end if;

  select proof.* into v_existing from public.proof_uploads proof where proof.id = p_proof_id for update;
  if found then
    if v_existing.application_id = p_application_id
       and v_existing.uploaded_by = auth.uid()
       and v_existing.storage_path = p_storage_path
       and v_existing.status in ('uploading','submitted') then
      return jsonb_build_object('ok',true,'proof_id',v_existing.id,'storage_path',v_existing.storage_path,'status',v_existing.status);
    end if;
    if v_existing.status = 'abandoned' and v_existing.uploaded_by = auth.uid()
       and v_existing.application_id = p_application_id and v_existing.storage_path = p_storage_path then
      update public.proof_uploads set status='uploading', note=v_note, updated_at=now() where id=p_proof_id;
      return jsonb_build_object('ok',true,'proof_id',p_proof_id,'storage_path',p_storage_path,'status','uploading');
    end if;
    return jsonb_build_object('ok',false,'code','proof_submission_conflict');
  end if;

  if exists (select 1 from public.proof_uploads proof
              where proof.application_id=p_application_id
                and proof.status in ('uploading','submitted')) then
    return jsonb_build_object('ok',false,'code','proof_already_pending');
  end if;
  if exists (select 1 from public.proof_uploads proof
              where proof.application_id=p_application_id and proof.status='approved') then
    return jsonb_build_object('ok',false,'code','proof_already_approved');
  end if;

  insert into public.proof_uploads(id,assignment_id,application_id,uploaded_by,storage_path,status,note)
  values (p_proof_id,v_assignment.id,p_application_id,auth.uid(),p_storage_path,'uploading',v_note);
  return jsonb_build_object('ok',true,'proof_id',p_proof_id,'storage_path',p_storage_path,'status','uploading');
end;
$function$;

create or replace function private.submit_application_proof_internal(
  p_proof_id uuid, p_application_id uuid, p_storage_path text, p_note text
) returns jsonb
language plpgsql security definer set search_path = '' as $function$
declare
  v_assignment public.job_assignments%rowtype;
  v_proof public.proof_uploads%rowtype;
  v_note text := nullif(btrim(p_note), '');
begin
  if auth.uid() is null then return jsonb_build_object('ok',false,'code','authentication_required'); end if;
  select assignment.* into v_assignment from public.job_assignments assignment
   where assignment.application_id=p_application_id for update;
  if not found or v_assignment.teen_user_id <> auth.uid() then return jsonb_build_object('ok',false,'code','job_participant_required'); end if;
  if v_assignment.status not in ('in_progress','awaiting_confirmation') then return jsonb_build_object('ok',false,'code','job_not_ready_for_proof'); end if;
  select proof.* into v_proof from public.proof_uploads proof
   where proof.id=p_proof_id and proof.application_id=p_application_id for update;
  if not found or v_proof.uploaded_by <> auth.uid() or v_proof.storage_path <> p_storage_path then
    return jsonb_build_object('ok',false,'code','proof_upload_not_found');
  end if;
  if v_proof.status='submitted' then return jsonb_build_object('ok',true,'proof',to_jsonb(v_proof)); end if;
  if v_proof.status <> 'uploading' then return jsonb_build_object('ok',false,'code','proof_upload_not_pending'); end if;
  if v_note is not null and char_length(v_note)>500 then return jsonb_build_object('ok',false,'code','proof_note_too_long'); end if;
  if not exists (select 1 from storage.objects object
                  where object.bucket_id='proof-uploads' and object.name=p_storage_path) then
    return jsonb_build_object('ok',false,'code','proof_file_missing');
  end if;

  update public.proof_uploads set status='submitted', note=v_note, updated_at=now()
   where id=p_proof_id returning * into v_proof;
  update public.job_assignments set status='awaiting_confirmation', completed_by_teen_at=coalesce(completed_by_teen_at,now())
   where id=v_assignment.id and status in ('in_progress','awaiting_confirmation');
  update public.jobs set status='under_review', updated_at=now()
   where id=v_assignment.job_id and status in ('in_progress','under_review');
  return jsonb_build_object('ok',true,'proof',to_jsonb(v_proof));
end;
$function$;

create or replace function private.abort_application_proof_upload_internal(
  p_proof_id uuid, p_application_id uuid
) returns jsonb
language plpgsql security definer set search_path = '' as $function$
begin
  if auth.uid() is null then return jsonb_build_object('ok',false,'code','authentication_required'); end if;
  update public.proof_uploads proof set status='abandoned',updated_at=now()
   where proof.id=p_proof_id and proof.application_id=p_application_id
     and proof.uploaded_by=auth.uid() and proof.status='uploading';
  return jsonb_build_object('ok',true);
end;
$function$;

create or replace function private.review_application_proof_internal(
  p_proof_id uuid, p_action text, p_note text
) returns jsonb
language plpgsql security definer set search_path = '' as $function$
declare
  v_proof public.proof_uploads%rowtype;
  v_assignment public.job_assignments%rowtype;
  v_note text := nullif(btrim(p_note), '');
begin
  if auth.uid() is null then return jsonb_build_object('ok',false,'code','authentication_required'); end if;
  if p_action is null or p_action not in ('approved','resubmission_requested','rejected') then return jsonb_build_object('ok',false,'code','invalid_proof_review_action'); end if;
  if p_action<>'approved' and (v_note is null or char_length(v_note)<10) then return jsonb_build_object('ok',false,'code','proof_review_note_required'); end if;
  if v_note is not null and char_length(v_note)>500 then return jsonb_build_object('ok',false,'code','proof_review_note_too_long'); end if;

  select proof.* into v_proof from public.proof_uploads proof where proof.id=p_proof_id for update;
  if not found then return jsonb_build_object('ok',false,'code','proof_upload_not_found'); end if;
  select assignment.* into v_assignment from public.job_assignments assignment
   where assignment.id=v_proof.assignment_id for update;
  if not found or v_assignment.adult_user_id<>auth.uid() then return jsonb_build_object('ok',false,'code','job_participant_required'); end if;
  if v_proof.status<>'submitted' then return jsonb_build_object('ok',false,'code','proof_not_awaiting_review'); end if;
  if v_assignment.status<>'awaiting_confirmation' then return jsonb_build_object('ok',false,'code','job_not_awaiting_review'); end if;

  update public.proof_uploads set status=p_action,reviewed_by=auth.uid(),review_note=v_note,reviewed_at=now(),updated_at=now()
   where id=p_proof_id returning * into v_proof;
  if p_action<>'approved' then
    update public.job_assignments set status='in_progress' where id=v_assignment.id;
    update public.jobs set status='in_progress',updated_at=now() where id=v_assignment.job_id and status='under_review';
  end if;
  return jsonb_build_object('ok',true,'proof',to_jsonb(v_proof));
end;
$function$;

create or replace function private.complete_job_after_proof_internal(
  p_application_id uuid, p_proof_id uuid
) returns jsonb
language plpgsql security definer set search_path = '' as $function$
declare
  v_assignment public.job_assignments%rowtype;
  v_job public.jobs%rowtype;
begin
  if auth.uid() is null then return jsonb_build_object('ok',false,'code','authentication_required'); end if;
  select assignment.* into v_assignment from public.job_assignments assignment
   where assignment.application_id=p_application_id for update;
  if not found or v_assignment.adult_user_id<>auth.uid() then return jsonb_build_object('ok',false,'code','job_participant_required'); end if;
  if v_assignment.status='completed' then return jsonb_build_object('ok',true,'application_id',p_application_id,'status','completed'); end if;
  if v_assignment.status<>'awaiting_confirmation' then return jsonb_build_object('ok',false,'code','job_not_awaiting_confirmation'); end if;
  select job.* into v_job from public.jobs job where job.id=v_assignment.job_id for update;
  if not found then return jsonb_build_object('ok',false,'code','job_not_available'); end if;
  if v_job.status<>'under_review' then return jsonb_build_object('ok',false,'code','job_not_awaiting_confirmation'); end if;
  if v_job.proof_expected and not exists (
    select 1 from public.proof_uploads proof
     where proof.id=p_proof_id and proof.assignment_id=v_assignment.id
       and proof.application_id=p_application_id and proof.status='approved'
  ) then return jsonb_build_object('ok',false,'code','proof_approval_required'); end if;
  if p_proof_id is not null and not exists (
    select 1 from public.proof_uploads proof
     where proof.id=p_proof_id and proof.assignment_id=v_assignment.id and proof.status='approved'
  ) then return jsonb_build_object('ok',false,'code','proof_approval_required'); end if;

  update public.job_assignments set status='completed',completed_by_adult_at=now(),closed_at=now()
   where id=v_assignment.id;
  update public.jobs set status='completed',completed_at=now(),updated_at=now()
   where id=v_job.id;
  update public.job_contracts set status='completed',closed_at=now()
   where application_id=p_application_id and status in ('active','change_pending');
  return jsonb_build_object('ok',true,'application_id',p_application_id,'status','completed');
end;
$function$;

revoke all on function private.begin_application_proof_upload_internal(uuid,uuid,text,text),
  private.submit_application_proof_internal(uuid,uuid,text,text),
  private.abort_application_proof_upload_internal(uuid,uuid),
  private.review_application_proof_internal(uuid,text,text),
  private.complete_job_after_proof_internal(uuid,uuid)
  from public, anon;
grant usage on schema private to authenticated;
grant execute on function private.begin_application_proof_upload_internal(uuid,uuid,text,text),
  private.submit_application_proof_internal(uuid,uuid,text,text),
  private.abort_application_proof_upload_internal(uuid,uuid),
  private.review_application_proof_internal(uuid,text,text),
  private.complete_job_after_proof_internal(uuid,uuid)
  to authenticated;

create or replace function public.begin_application_proof_upload(
  p_proof_id uuid,p_application_id uuid,p_storage_path text,p_note text
) returns jsonb language sql security invoker set search_path = '' as $function$
  select private.begin_application_proof_upload_internal($1,$2,$3,$4)
$function$;
create or replace function public.submit_application_proof(
  p_proof_id uuid,p_application_id uuid,p_storage_path text,p_note text
) returns jsonb language sql security invoker set search_path = '' as $function$
  select private.submit_application_proof_internal($1,$2,$3,$4)
$function$;
create or replace function public.abort_application_proof_upload(
  p_proof_id uuid,p_application_id uuid
) returns jsonb language sql security invoker set search_path = '' as $function$
  select private.abort_application_proof_upload_internal($1,$2)
$function$;
create or replace function public.review_application_proof(
  p_proof_id uuid,p_action text,p_note text
) returns jsonb language sql security invoker set search_path = '' as $function$
  select private.review_application_proof_internal($1,$2,$3)
$function$;
create or replace function public.complete_job_after_proof(
  p_application_id uuid,p_proof_id uuid
) returns jsonb language sql security invoker set search_path = '' as $function$
  select private.complete_job_after_proof_internal($1,$2)
$function$;

revoke all on function public.begin_application_proof_upload(uuid,uuid,text,text),
  public.submit_application_proof(uuid,uuid,text,text),
  public.abort_application_proof_upload(uuid,uuid),
  public.review_application_proof(uuid,text,text),
  public.complete_job_after_proof(uuid,uuid)
  from public, anon;
grant execute on function public.begin_application_proof_upload(uuid,uuid,text,text),
  public.submit_application_proof(uuid,uuid,text,text),
  public.abort_application_proof_upload(uuid,uuid),
  public.review_application_proof(uuid,text,text),
  public.complete_job_after_proof(uuid,uuid)
  to authenticated;

