-- Use assignment-then-proof row locks everywhere so upload/review races do not
-- deadlock when a client retries submission while an adult reviews it.
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

  select proof.* into v_proof from public.proof_uploads proof where proof.id=p_proof_id;
  if not found then return jsonb_build_object('ok',false,'code','proof_upload_not_found'); end if;
  select assignment.* into v_assignment from public.job_assignments assignment
   where assignment.id=v_proof.assignment_id for update;
  if not found or v_assignment.adult_user_id<>auth.uid() then return jsonb_build_object('ok',false,'code','job_participant_required'); end if;
  select proof.* into v_proof from public.proof_uploads proof
   where proof.id=p_proof_id and proof.assignment_id=v_assignment.id for update;
  if not found then return jsonb_build_object('ok',false,'code','proof_upload_not_found'); end if;
  if v_proof.status<>'submitted' then return jsonb_build_object('ok',false,'code','proof_not_awaiting_review'); end if;
  if v_assignment.status<>'awaiting_confirmation' then return jsonb_build_object('ok',false,'code','job_not_awaiting_review'); end if;

  update public.proof_uploads set status=p_action,reviewed_by=auth.uid(),review_note=v_note,reviewed_at=now(),updated_at=now()
   where id=p_proof_id returning * into v_proof;
  return jsonb_build_object('ok',true,'proof',to_jsonb(v_proof));
end;
$function$;
