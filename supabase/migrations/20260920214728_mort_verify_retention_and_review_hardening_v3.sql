
create or replace function public.service_list_expired_mort_verify_documents(
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
  from private.mort_verify_documents document
  where document.status <> 'deleted'
    and document.retention_delete_at <= now()
    and (document.preserved_until is null or document.preserved_until <= now())
    and not exists (
      select 1
      from private.mort_verify_review_assignments assignment
      where assignment.session_id = document.session_id
        and assignment.revoked_at is null
        and assignment.expires_at > now()
    )
  order by document.retention_delete_at, document.id
  limit least(greatest(coalesce(p_limit, 100), 1), 500);
end;
$$;

revoke all on function public.service_list_expired_mort_verify_documents(integer)
from public, anon, authenticated;
grant execute on function public.service_list_expired_mort_verify_documents(integer)
to service_role;

create or replace function public.service_finalize_mort_verify_document_purge(
  p_document_ids uuid[]
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer := 0;
  v_document private.mort_verify_documents%rowtype;
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
    from private.mort_verify_documents document
    where document.id = any(p_document_ids)
      and document.status <> 'deleted'
      and document.retention_delete_at <= now()
      and (document.preserved_until is null or document.preserved_until <= now())
      and not exists (
        select 1
        from private.mort_verify_review_assignments assignment
        where assignment.session_id = document.session_id
          and assignment.revoked_at is null
          and assignment.expires_at > now()
      )
    for update
  loop
    update private.mort_verify_documents
    set status = 'deleted'
    where id = v_document.id;

    insert into private.mort_verify_audit_events(
      session_id,user_id,actor_id,action,safe_metadata
    ) values (
      v_document.session_id,
      v_document.user_id,
      null,
      'school_id_retention_purged',
      jsonb_build_object(
        'document_id', v_document.id,
        'retention_delete_at', v_document.retention_delete_at,
        'preservation_active', false
      )
    );

    v_count := v_count + 1;
  end loop;

  return jsonb_build_object('ok', true, 'purged', v_count);
end;
$$;

revoke all on function public.service_finalize_mort_verify_document_purge(uuid[])
from public, anon, authenticated;
grant execute on function public.service_finalize_mort_verify_document_purge(uuid[])
to service_role;

create or replace function public.admin_mort_verify_decide(
  p_session_id uuid,
  p_action text,
  p_reason_code text,
  p_student_identity_verified boolean default false,
  p_school_affiliation_verified boolean default false,
  p_age_band text default null,
  p_age_evidence_kind text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session private.mort_verify_sessions%rowtype;
  v_action text := lower(btrim(coalesce(p_action,'')));
  v_has_assignment boolean;
  v_has_front_document boolean;
begin
  if auth.uid() is null
     or not private.has_admin_safety_role(
       auth.uid(),
       array['verification_reviewer','senior_safety_moderator']::public.admin_safety_role[]
     ) then
    return jsonb_build_object('ok', false, 'code', 'verification_reviewer_required');
  end if;

  select * into v_session
  from private.mort_verify_sessions session
  where session.id = p_session_id
    and session.status in ('manual_review','needs_age_evidence')
  for update;

  if v_session.id is null then
    return jsonb_build_object('ok', false, 'code', 'review_session_not_found');
  end if;

  select exists (
    select 1 from private.mort_verify_review_assignments assignment
    where assignment.session_id = p_session_id
      and assignment.reviewer_id = auth.uid()
      and assignment.revoked_at is null
      and assignment.expires_at > now()
  ) into v_has_assignment;

  if not v_has_assignment then
    return jsonb_build_object('ok', false, 'code', 'active_review_assignment_required');
  end if;

  if char_length(btrim(coalesce(p_reason_code,''))) not between 2 and 120 then
    return jsonb_build_object('ok', false, 'code', 'decision_reason_required');
  end if;

  select exists (
    select 1
    from private.mort_verify_documents document
    where document.session_id = p_session_id
      and document.side = 'front'
      and document.status = 'active'
  ) into v_has_front_document;

  if v_action in ('approve_school_only','approve_age_and_school') then
    if v_session.school_email_verified_at is null then
      return jsonb_build_object('ok', false, 'code', 'school_email_required');
    end if;
    if not v_has_front_document then
      return jsonb_build_object('ok', false, 'code', 'school_id_front_required');
    end if;
  end if;

  if v_action = 'request_recapture' then
    update private.mort_verify_documents
    set review_result='recapture_required',
        reviewed_at=now(),
        reviewer_id=auth.uid()
    where session_id=p_session_id and status='active';

    update private.mort_verify_sessions
    set status='document_pending', decision_code=p_reason_code,
        reviewer_id=auth.uid(), reviewed_at=now(), updated_at=now()
    where id=p_session_id;

    update public.identity_verifications
    set status='additional_information_required', rejection_code=p_reason_code,
        reviewer_id=auth.uid(), reviewed_at=now(), updated_at=now()
    where id=v_session.identity_verification_id;

  elsif v_action = 'reject' then
    update private.mort_verify_documents
    set review_result='rejected',
        status='rejected',
        reviewed_at=now(),
        reviewer_id=auth.uid()
    where session_id=p_session_id and status='active';

    update private.mort_verify_sessions
    set status='rejected', decision_code=p_reason_code,
        reviewer_id=auth.uid(), reviewed_at=now(), updated_at=now()
    where id=p_session_id;

    update public.identity_verifications
    set status='verification_rejected', verification_level=0,
        rejection_code=p_reason_code, reviewer_id=auth.uid(),
        reviewed_at=now(), updated_at=now()
    where id=v_session.identity_verification_id;

  elsif v_action = 'approve_school_only' then
    if not p_student_identity_verified or not p_school_affiliation_verified then
      return jsonb_build_object('ok', false, 'code', 'school_identity_signals_required');
    end if;

    update private.mort_verify_documents
    set review_result='accepted',
        reviewed_at=now(),
        reviewer_id=auth.uid()
    where session_id=p_session_id and status='active';

    update private.mort_verify_sessions
    set status='needs_age_evidence',
        school_affiliation_verified_at=coalesce(school_affiliation_verified_at,now()),
        student_identity_verified_at=coalesce(student_identity_verified_at,now()),
        decision_code=p_reason_code,
        reviewer_id=auth.uid(), reviewed_at=now(), updated_at=now()
    where id=p_session_id;

    update public.identity_verifications
    set status='additional_information_required',
        identity_match_result='school_id_and_email_consistent',
        email_verification_result='school_email_verified',
        rejection_code=null, reviewer_id=auth.uid(),
        reviewed_at=now(), updated_at=now()
    where id=v_session.identity_verification_id;

  elsif v_action = 'approve_age_and_school' then
    if not p_student_identity_verified
       or not p_school_affiliation_verified
       or p_age_band not in ('13_15','16_17')
       or p_age_evidence_kind not in (
         'school_id_dob','school_record','government_id_age_only','manual_exception'
       ) then
      return jsonb_build_object('ok', false, 'code', 'verified_age_evidence_required');
    end if;

    if p_age_evidence_kind = 'manual_exception'
       and not private.has_admin_safety_role(
         auth.uid(),
         array['senior_safety_moderator']::public.admin_safety_role[]
       ) then
      return jsonb_build_object(
        'ok', false, 'code', 'senior_review_required_for_age_exception'
      );
    end if;

    update private.mort_verify_documents
    set review_result='accepted',
        reviewed_at=now(),
        reviewer_id=auth.uid()
    where session_id=p_session_id and status='active';

    update private.mort_verify_sessions
    set status='verified',
        school_affiliation_verified_at=coalesce(school_affiliation_verified_at,now()),
        student_identity_verified_at=coalesce(student_identity_verified_at,now()),
        age_verified_at=now(),
        verified_age_band=p_age_band,
        age_evidence_kind=p_age_evidence_kind,
        decision_code=p_reason_code,
        reviewer_id=auth.uid(), reviewed_at=now(), updated_at=now()
    where id=p_session_id;

    update public.identity_verifications
    set status='verified',
        verification_level=1,
        identity_match_result='school_id_and_email_consistent',
        email_verification_result='school_email_verified',
        liveness_result='not_checked',
        reviewed_at=now(),
        verified_at=now(),
        expires_at=now() + interval '1 year',
        reviewer_id=auth.uid(),
        rejection_code=null,
        decision_source='mort_verify_manual_review',
        risk_flags = risk_flags || jsonb_build_object(
          'age_verified', true,
          'age_band', p_age_band,
          'age_evidence_kind', p_age_evidence_kind,
          'school_affiliation_verified', true,
          'legal_identity_claimed', false
        ),
        updated_at=now()
    where id=v_session.identity_verification_id;

    insert into public.trust_signal_events(
      user_id,signal_type,category,status,environment,source_kind,
      source_reference,public_label,what_was_checked,what_was_not_checked,
      checked_at,expires_at,public_visibility,grants_marketplace_access,
      metadata,created_by
    ) values (
      v_session.user_id,
      'school_affiliation',
      'affiliation',
      'verified',
      v_session.environment,
      'mort_verify',
      p_session_id::text,
      'School affiliation verified',
      'A confirmed approved school email and reviewed current school ID were consistent.',
      'This does not establish a government-issued legal identity.',
      now(),now()+interval '1 year',false,false,
      jsonb_build_object('age_band_verified',p_age_band,'first_party',true),
      auth.uid()
    );
  else
    return jsonb_build_object('ok', false, 'code', 'unsupported_review_action');
  end if;

  update private.mort_verify_review_assignments
  set revoked_at=now()
  where session_id=p_session_id and reviewer_id=auth.uid() and revoked_at is null;

  insert into private.mort_verify_audit_events(
    session_id,user_id,actor_id,action,safe_metadata
  ) values (
    p_session_id,v_session.user_id,auth.uid(),'review_decision',
    jsonb_build_object(
      'action',v_action,
      'reason_code',p_reason_code,
      'student_identity_verified',p_student_identity_verified,
      'school_affiliation_verified',p_school_affiliation_verified,
      'age_band',p_age_band,
      'age_evidence_kind',p_age_evidence_kind
    )
  );

  return jsonb_build_object('ok',true,'status',(
    select session.status from private.mort_verify_sessions session
    where session.id=p_session_id
  ));
end;
$$;

revoke all on function public.admin_mort_verify_decide(
  uuid,text,text,boolean,boolean,text,text
)
from public, anon;
grant execute on function public.admin_mort_verify_decide(
  uuid,text,text,boolean,boolean,text,text
)
to authenticated;
