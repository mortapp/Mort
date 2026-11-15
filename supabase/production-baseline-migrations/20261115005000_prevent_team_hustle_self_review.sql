-- Require an independent administrator for team-hustle review and make an
-- identical completed review safely replayable after an uncertain response.
BEGIN;

create or replace function public.admin_review_team_hustle_v1(
  p_hustle_id uuid,
  p_decision text,
  p_reason text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user uuid := auth.uid();
  v_status text;
  v_reviewed_by uuid;
  v_existing_note text;
  v_target_status text;
  v_poster_id uuid;
  v_reason text := nullif(btrim(coalesce(p_reason,'')), '');
begin
  if v_user is null or not private.is_active_user()
     or not private.has_staff_role(array['admin']::public.mort_role[]) then
    return jsonb_build_object('ok', false, 'code', 'admin_required');
  end if;
  if p_hustle_id is null or p_decision is null
     or p_decision not in ('approve','reject') then
    return jsonb_build_object('ok', false, 'code', 'review_decision_invalid');
  end if;
  if p_decision = 'reject' and (v_reason is null or length(v_reason) < 3) then
    return jsonb_build_object('ok', false, 'code', 'rejection_reason_required');
  end if;
  if v_reason is not null and length(v_reason) > 1000 then
    return jsonb_build_object('ok', false, 'code', 'review_reason_too_long');
  end if;

  select th.review_status, th.reviewed_by, th.review_note, th.poster_id
    into v_status, v_reviewed_by, v_existing_note, v_poster_id
  from public.team_hustles th where th.id = p_hustle_id for update;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'team_hustle_not_found');
  end if;
  if v_poster_id = v_user then
    return jsonb_build_object('ok', false, 'code', 'admin_self_review_not_allowed');
  end if;

  v_target_status := case when p_decision = 'approve' then 'approved' else 'rejected' end;
  if v_status <> 'pending' then
    if v_status = v_target_status and v_reviewed_by = v_user
       and v_existing_note is not distinct from v_reason then
      return jsonb_build_object('ok', true, 'review_status', v_status, 'replayed', true);
    end if;
    return jsonb_build_object('ok', false, 'code', 'team_hustle_not_pending_review');
  end if;

  update public.team_hustles
  set review_status = v_target_status,
      reviewed_at = now(),
      reviewed_by = v_user,
      review_note = v_reason
  where id = p_hustle_id and review_status = 'pending';
  if not found then
    return jsonb_build_object('ok', false, 'code', 'team_hustle_not_pending_review');
  end if;

  insert into public.admin_audit_log (actor_id, action, target_type, target_id, reason, metadata)
  values (v_user, 'team_hustle_reviewed', 'team_hustle', p_hustle_id::text, v_reason,
          jsonb_build_object('decision', v_target_status));
  return jsonb_build_object('ok', true, 'review_status', v_target_status, 'replayed', false);
end;
$function$;

revoke all on function public.admin_review_team_hustle_v1(uuid,text,text) from public, anon;
grant execute on function public.admin_review_team_hustle_v1(uuid,text,text) to authenticated, service_role;

COMMIT;
