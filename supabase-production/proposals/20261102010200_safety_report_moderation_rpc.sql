-- Staff-only, optimistic-concurrency-safe safety-report moderation.
-- Proposal only: validate against an isolated production-equivalent schema before apply.
begin;

create or replace function public.mort_review_safety_report(
  p_report_id uuid,
  p_action text,
  p_reason text,
  p_assigned_to uuid default null,
  p_expected_updated_at timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_actor uuid := auth.uid();
  v_report public.safety_reports%rowtype;
  v_new_status text;
  v_new_assignee uuid;
  v_resolved_at timestamptz;
  v_now timestamptz := clock_timestamp();
begin
  if v_actor is null
     or not private.has_staff_role(array['admin','moderator']::public.mort_role[])
     or not exists (
       select 1 from public.profiles actor
       where actor.id = v_actor and actor.account_status = 'active'
     ) then
    raise exception 'Authorized safety moderation role required' using errcode = '42501';
  end if;

  if p_report_id is null
     or p_action is null
     or p_action not in ('triage','investigate','resolve','dismiss','reopen','assign','unassign')
     or p_reason is null
     or char_length(btrim(p_reason)) not between 10 and 1000
     or p_expected_updated_at is null then
    return jsonb_build_object('ok', false, 'code', 'invalid_moderation_request');
  end if;

  select * into v_report
  from public.safety_reports report
  where report.id = p_report_id
  for update;

  if not found then
    return jsonb_build_object('ok', false, 'code', 'safety_report_not_available');
  end if;

  if v_report.updated_at is distinct from p_expected_updated_at then
    return jsonb_build_object('ok', false, 'code', 'safety_report_changed_refresh');
  end if;

  v_new_status := v_report.status;
  v_new_assignee := v_report.assigned_to;
  v_resolved_at := v_report.resolved_at;

  case p_action
    when 'triage' then
      if v_report.status <> 'open' then
        return jsonb_build_object('ok', false, 'code', 'safety_report_transition_not_allowed');
      end if;
      v_new_status := 'triaged';
      v_new_assignee := coalesce(p_assigned_to, v_actor);
      v_resolved_at := null;
    when 'investigate' then
      if v_report.status not in ('open','triaged','investigating') then
        return jsonb_build_object('ok', false, 'code', 'safety_report_transition_not_allowed');
      end if;
      v_new_status := 'investigating';
      v_new_assignee := coalesce(p_assigned_to, v_report.assigned_to, v_actor);
      v_resolved_at := null;
    when 'resolve' then
      if v_report.status not in ('open','triaged','investigating') then
        return jsonb_build_object('ok', false, 'code', 'safety_report_transition_not_allowed');
      end if;
      v_new_status := 'resolved';
      v_resolved_at := v_now;
    when 'dismiss' then
      if v_report.status not in ('open','triaged','investigating') then
        return jsonb_build_object('ok', false, 'code', 'safety_report_transition_not_allowed');
      end if;
      v_new_status := 'dismissed';
      v_resolved_at := v_now;
    when 'reopen' then
      if v_report.status not in ('resolved','dismissed') then
        return jsonb_build_object('ok', false, 'code', 'safety_report_transition_not_allowed');
      end if;
      v_new_status := 'open';
      v_new_assignee := coalesce(p_assigned_to, v_actor);
      v_resolved_at := null;
    when 'assign' then
      v_new_assignee := coalesce(p_assigned_to, v_actor);
    when 'unassign' then
      v_new_assignee := null;
  end case;

  if v_new_assignee is distinct from v_report.assigned_to
     and v_new_assignee is not null and not exists (
    select 1
    from public.profiles assignee
    join private.user_roles staff_role on staff_role.user_id = assignee.id
    where assignee.id = v_new_assignee
      and assignee.account_status = 'active'
      and staff_role.role in ('admin'::public.mort_role, 'moderator'::public.mort_role)
  ) then
    return jsonb_build_object('ok', false, 'code', 'safety_report_assignee_not_available');
  end if;

  update public.safety_reports
  set status = v_new_status,
      assigned_to = v_new_assignee,
      resolved_at = v_resolved_at,
      updated_at = v_now
  where id = v_report.id;

  insert into public.admin_audit_log(
    actor_id, action, target_type, target_id, reason, metadata
  ) values (
    v_actor,
    'safety_report_' || p_action,
    'safety_report',
    v_report.id::text,
    btrim(p_reason),
    jsonb_build_object(
      'previous_status', v_report.status,
      'new_status', v_new_status,
      'previous_assignee', v_report.assigned_to,
      'new_assignee', v_new_assignee,
      'severity', v_report.severity,
      'immediate_danger', v_report.immediate_danger
    )
  );

  return jsonb_build_object(
    'ok', true,
    'report_id', v_report.id,
    'status', v_new_status,
    'assigned_to', v_new_assignee,
    'updated_at', v_now
  );
end;
$function$;

revoke all on function public.mort_review_safety_report(uuid,text,text,uuid,timestamptz)
  from public, anon, authenticated;
grant execute on function public.mort_review_safety_report(uuid,text,text,uuid,timestamptz)
  to authenticated;

commit;
