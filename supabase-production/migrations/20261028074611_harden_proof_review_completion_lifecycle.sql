-- Preserve the established execution review window, retire abandoned upload
-- manifests after 30 minutes, and keep payment release separate from work
-- completion.

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

  update public.proof_uploads set status='abandoned',updated_at=now()
   where application_id=p_application_id and status='uploading'
     and created_at < now() - interval '30 minutes';

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
  -- Keep the assignment in the existing completion-review state. A requested
  -- replacement proof uses the same completion PIN/session and review window.
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
  v_session private.job_execution_sessions%rowtype;
begin
  if auth.uid() is null then return jsonb_build_object('ok',false,'code','authentication_required'); end if;
  select assignment.* into v_assignment from public.job_assignments assignment
   where assignment.application_id=p_application_id;
  if not found or v_assignment.adult_user_id<>auth.uid() then return jsonb_build_object('ok',false,'code','job_participant_required'); end if;
  if v_assignment.status='completed' then return jsonb_build_object('ok',true,'application_id',p_application_id,'status','completed'); end if;
  if v_assignment.status<>'awaiting_confirmation' then return jsonb_build_object('ok',false,'code','job_not_awaiting_confirmation'); end if;

  select session.* into v_session from private.job_execution_sessions session
   where session.assignment_id=v_assignment.id for update;
  if not found or v_session.execution_state<>'completion_pending_release'
     or v_session.review_window_ends_at is null then
    return jsonb_build_object('ok',false,'code','job_execution_review_required');
  end if;
  if v_session.review_window_ends_at>now() then
    return jsonb_build_object('ok',false,'code','completion_review_window_open',
      'review_window_ends_at',v_session.review_window_ends_at);
  end if;

  select assignment.* into v_assignment from public.job_assignments assignment
   where assignment.id=v_assignment.id for update;
  if not found or v_assignment.status<>'awaiting_confirmation'
     or v_assignment.adult_user_id<>auth.uid() then
    return jsonb_build_object('ok',false,'code','job_not_awaiting_confirmation');
  end if;

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
  -- Leave the execution session in completion_pending_release: financial
  -- release is a separate server-controlled workflow and this RPC moves no money.
  return jsonb_build_object('ok',true,'application_id',p_application_id,
    'status','completed','financial_release_pending',true);
end;
$function$;

