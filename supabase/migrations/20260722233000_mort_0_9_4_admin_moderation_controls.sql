-- Redacted moderation details and reasoned, audited admin actions.

create or replace function public.admin_get_moderation_record(
  p_record_type text,
  p_record_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_record jsonb;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;

  if p_record_type = 'report' then
    if not private.can_manage_incident(auth.uid()) then
      return jsonb_build_object('ok', false, 'code', 'incident_manager_required');
    end if;
    select jsonb_build_object(
      'id', report.id,
      'status', report.status,
      'category', report.category,
      'severity', report.severity,
      'reason', report.reason,
      'details', report.details,
      'immediate_danger', report.immediate_danger,
      'reporter_id', report.reporter_id,
      'target_user_id', report.target_user_id,
      'target_job_id', report.target_job_id,
      'target_message_id', report.target_message_id,
      'target_review_id', report.target_review_id,
      'incident_id', report.incident_id,
      'created_at', report.created_at,
      'updated_at', report.updated_at
    ) into v_record
    from public.reports report
    where report.id = p_record_id;
  elsif p_record_type = 'identity_verification' then
    if not private.is_production_identity_reviewer(auth.uid()) then
      return jsonb_build_object('ok', false, 'code', 'production_identity_reviewer_required');
    end if;
    select jsonb_build_object(
      'id', verification.id,
      'user_id', verification.user_id,
      'account_role', verification.account_role,
      'environment', verification.environment,
      'status', verification.status,
      'evidence_route', verification.evidence_route,
      'verification_level', verification.verification_level,
      'identity_match_result', verification.identity_match_result,
      'liveness_result', verification.liveness_result,
      'email_verification_result', verification.email_verification_result,
      'phone_verification_result', verification.phone_verification_result,
      'address_validation_result', verification.address_validation_result,
      'appeal_status', verification.appeal_status,
      'rejection_code', verification.rejection_code,
      'submitted_at', verification.submitted_at,
      'reviewed_at', verification.reviewed_at,
      'expires_at', verification.expires_at,
      'raw_evidence_included', false
    ) into v_record
    from public.identity_verifications verification
    where verification.id = p_record_id;
  else
    return jsonb_build_object('ok', false, 'code', 'unsupported_record_type');
  end if;

  if v_record is null then
    return jsonb_build_object('ok', false, 'code', 'moderation_record_not_found');
  end if;
  return jsonb_build_object('ok', true, 'record', v_record);
end;
$$;

create or replace function public.admin_update_report_status(
  p_report_id uuid,
  p_status text,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status public.report_status;
  v_previous public.report_status;
begin
  if auth.uid() is null or not private.can_manage_incident(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'incident_manager_required');
  end if;
  if p_status not in ('reviewing', 'resolved', 'dismissed') then
    return jsonb_build_object('ok', false, 'code', 'report_status_invalid');
  end if;
  if char_length(btrim(coalesce(p_reason, ''))) not between 10 and 500 then
    return jsonb_build_object('ok', false, 'code', 'decision_reason_required');
  end if;
  v_status := p_status::public.report_status;

  select report.status into v_previous
  from public.reports report
  where report.id = p_report_id
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'report_not_found');
  end if;

  update public.reports set status = v_status where id = p_report_id;
  insert into public.admin_action_logs (
    admin_id, action, target_table, target_id, details
  ) values (
    auth.uid(), 'reasoned_report_status_update', 'reports', p_report_id,
    jsonb_build_object(
      'previous_status', v_previous,
      'new_status', v_status,
      'reason', btrim(p_reason)
    )
  );
  return jsonb_build_object('ok', true, 'status', v_status);
end;
$$;

create or replace function public.admin_set_account_status(
  p_user_id uuid,
  p_status text,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status public.account_status;
  v_previous public.account_status;
  v_target_role public.user_role;
begin
  if auth.uid() is null or not private.can_manage_incident(auth.uid()) or not exists (
    select 1 from public.profiles profile
    where profile.id = auth.uid()
      and profile.role = 'admin'
      and profile.account_status = 'active'
  ) then
    return jsonb_build_object('ok', false, 'code', 'active_admin_required');
  end if;
  if p_user_id = auth.uid() then
    return jsonb_build_object('ok', false, 'code', 'admin_self_restriction_blocked');
  end if;
  if p_status not in ('active', 'suspended', 'banned') then
    return jsonb_build_object('ok', false, 'code', 'account_status_invalid');
  end if;
  if char_length(btrim(coalesce(p_reason, ''))) not between 10 and 500 then
    return jsonb_build_object('ok', false, 'code', 'decision_reason_required');
  end if;
  v_status := p_status::public.account_status;

  select profile.account_status, profile.role
  into v_previous, v_target_role
  from public.profiles profile
  where profile.id = p_user_id
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'target_user_not_found');
  end if;
  if v_target_role = 'admin' then
    return jsonb_build_object('ok', false, 'code', 'peer_admin_action_blocked');
  end if;

  update public.profiles
  set account_status = v_status,
      blocked_until = case when v_status = 'active' then null else blocked_until end
  where id = p_user_id;
  insert into public.admin_action_logs (
    admin_id, action, target_table, target_id, details
  ) values (
    auth.uid(), 'reasoned_account_status_update', 'profiles', p_user_id,
    jsonb_build_object(
      'previous_status', v_previous,
      'new_status', v_status,
      'reason', btrim(p_reason)
    )
  );
  return jsonb_build_object('ok', true, 'status', v_status);
end;
$$;

revoke all on function public.admin_get_moderation_record(text, uuid) from public, anon, authenticated;
revoke all on function public.admin_update_report_status(uuid, text, text) from public, anon, authenticated;
revoke all on function public.admin_set_account_status(uuid, text, text) from public, anon, authenticated;

grant execute on function public.admin_get_moderation_record(text, uuid) to authenticated;
grant execute on function public.admin_update_report_status(uuid, text, text) to authenticated;
grant execute on function public.admin_set_account_status(uuid, text, text) to authenticated;
