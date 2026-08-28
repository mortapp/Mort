-- Phase 13/14 moderation and legal activation completion.
-- This migration does not publish legal text, approve staff, connect identity,
-- or open the public marketplace. Every external gate remains false.

-- Moderation writes must use narrow, reasoned RPCs. Posters already use the
-- server-owned job lifecycle RPCs, so no authenticated client needs direct
-- UPDATE access to every job column.
drop policy if exists jobs_insert_admin_only on public.jobs;
drop policy if exists jobs_update_admin_only on public.jobs;
drop policy if exists jobs_delete_admin_only on public.jobs;

-- Audit rows are server-authored. A client-created log entry could otherwise
-- disguise or dilute a real moderation action.
drop policy if exists admin_action_logs_insert_admin on public.admin_action_logs;
drop policy if exists admin_action_logs_select_admin on public.admin_action_logs;
create policy admin_action_logs_select_senior_safety
on public.admin_action_logs for select to authenticated
using (
  private.has_admin_safety_role(
    (select auth.uid()),
    array['senior_safety_moderator', 'incident_manager']::public.admin_safety_role[]
  )
);

create or replace function public.admin_moderate_job(
  p_job_id uuid,
  p_action text,
  p_reason_code text,
  p_note text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job public.jobs%rowtype;
  v_action text := lower(btrim(coalesce(p_action, '')));
  v_reason_code text := lower(btrim(coalesce(p_reason_code, '')));
  v_status public.job_status;
begin
  if auth.uid() is null or not private.has_admin_safety_role(
    auth.uid(),
    array['moderator', 'senior_safety_moderator', 'child_safety_specialist', 'incident_manager']::public.admin_safety_role[]
  ) then
    return jsonb_build_object('ok', false, 'code', 'content_moderator_required');
  end if;
  if v_action not in ('reject', 'remove') then
    return jsonb_build_object('ok', false, 'code', 'job_moderation_action_invalid');
  end if;
  if v_reason_code not in (
    'prohibited_job', 'scam_fraud', 'unsafe_contact', 'harassment',
    'child_safety', 'duplicate_spam', 'policy_violation'
  ) then
    return jsonb_build_object('ok', false, 'code', 'job_moderation_reason_code_invalid');
  end if;
  if char_length(btrim(coalesce(p_note, ''))) not between 10 and 1000 then
    return jsonb_build_object('ok', false, 'code', 'job_moderation_note_required');
  end if;

  select * into v_job from public.jobs where id = p_job_id for update;
  if v_job.id is null then
    return jsonb_build_object('ok', false, 'code', 'job_not_found');
  end if;
  if v_action = 'reject' and v_job.status not in ('draft', 'pending_review', 'open', 'paused') then
    return jsonb_build_object('ok', false, 'code', 'job_rejection_state_invalid');
  end if;
  if v_action = 'remove' and v_job.status in (
    'assigned', 'in_progress', 'proof_submitted', 'completion_pending_release'
  ) then
    return jsonb_build_object('ok', false, 'code', 'active_job_requires_incident_workflow');
  end if;
  v_status := case v_action
    when 'reject' then 'rejected'::public.job_status
    else 'removed'::public.job_status
  end;

  update public.jobs
  set status = v_status,
      applications_open = false
  where id = v_job.id;

  insert into public.admin_action_logs (
    admin_id, action, target_table, target_id, details
  ) values (
    auth.uid(), 'reasoned_job_' || v_action, 'jobs', v_job.id,
    jsonb_build_object(
      'previous_status', v_job.status,
      'new_status', v_status,
      'reason_code', v_reason_code,
      'note', btrim(p_note)
    )
  );

  return jsonb_build_object(
    'ok', true,
    'job_id', v_job.id,
    'status', v_status,
    'action', v_action
  );
end;
$$;

create or replace function public.admin_moderate_review(
  p_review_id uuid,
  p_action text,
  p_reason_code text,
  p_note text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_review public.reviews%rowtype;
  v_action text := lower(btrim(coalesce(p_action, '')));
  v_reason_code text := lower(btrim(coalesce(p_reason_code, '')));
  v_status text;
begin
  if auth.uid() is null or not private.has_admin_safety_role(
    auth.uid(),
    array['moderator', 'senior_safety_moderator', 'child_safety_specialist', 'incident_manager']::public.admin_safety_role[]
  ) then
    return jsonb_build_object('ok', false, 'code', 'content_moderator_required');
  end if;
  if v_action not in ('approve', 'reject', 'remove') then
    return jsonb_build_object('ok', false, 'code', 'review_moderation_action_invalid');
  end if;
  if v_reason_code not in (
    'content_review_completed', 'harassment', 'sexual_content',
    'personal_information', 'threats', 'scam_fraud', 'discrimination',
    'retaliation', 'policy_violation'
  ) then
    return jsonb_build_object('ok', false, 'code', 'review_moderation_reason_code_invalid');
  end if;
  if char_length(btrim(coalesce(p_note, ''))) not between 10 and 1000 then
    return jsonb_build_object('ok', false, 'code', 'review_moderation_note_required');
  end if;

  select * into v_review from public.reviews where id = p_review_id for update;
  if v_review.id is null then
    return jsonb_build_object('ok', false, 'code', 'review_not_found');
  end if;
  v_status := case v_action
    when 'approve' then 'approved'
    when 'reject' then 'rejected'
    else 'removed'
  end;

  update public.reviews set moderation_status = v_status where id = v_review.id;
  insert into public.admin_action_logs (
    admin_id, action, target_table, target_id, details
  ) values (
    auth.uid(), 'reasoned_review_' || v_action, 'reviews', v_review.id,
    jsonb_build_object(
      'previous_status', v_review.moderation_status,
      'new_status', v_status,
      'reason_code', v_reason_code,
      'note', btrim(p_note)
    )
  );

  return jsonb_build_object(
    'ok', true,
    'review_id', v_review.id,
    'status', v_status,
    'action', v_action
  );
end;
$$;

revoke all on function public.admin_moderate_job(uuid, text, text, text)
from public, anon, authenticated;
revoke all on function public.admin_moderate_review(uuid, text, text, text)
from public, anon, authenticated;
grant execute on function public.admin_moderate_job(uuid, text, text, text)
to authenticated, service_role;
grant execute on function public.admin_moderate_review(uuid, text, text, text)
to authenticated, service_role;

-- Sensitive moderation detail reads join the existing append-only private-data
-- access audit. Identity responses remain redacted and require the production
-- reviewer boundary even though the provider is currently disabled.
create or replace function public.admin_get_moderation_record(
  p_record_type text,
  p_record_id uuid
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_record jsonb;
  v_record_type text := lower(btrim(coalesce(p_record_type, '')));
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;

  if v_record_type = 'report' then
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
  elsif v_record_type = 'identity_verification' then
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

  insert into public.private_data_access_events (
    actor_id, resource_type, resource_id, action, reason
  ) values (
    auth.uid(), 'moderation_' || v_record_type, p_record_id, 'read',
    'Authorized staff opened a restricted redacted moderation detail record.'
  );

  return jsonb_build_object('ok', true, 'record', v_record);
end;
$$;

-- Safety roles granted after this migration must expire. Existing legacy rows
-- remain visible as an explicit public-activation blocker until reviewed.
alter table public.admin_role_assignments
  add column if not exists expires_at timestamptz,
  add column if not exists revoked_by uuid references public.profiles(id) on delete set null,
  add column if not exists revocation_reason text;

alter table public.admin_role_assignments
  drop constraint if exists admin_role_assignment_expiry_check,
  drop constraint if exists admin_role_assignment_revocation_reason_check;
alter table public.admin_role_assignments
  add constraint admin_role_assignment_expiry_check check (
    expires_at is null or expires_at > created_at
  ),
  add constraint admin_role_assignment_revocation_reason_check check (
    revocation_reason is null or char_length(btrim(revocation_reason)) between 10 and 500
  );

create index if not exists admin_role_assignments_expiry_idx
on public.admin_role_assignments(expires_at)
where revoked_at is null;

create or replace function private.has_admin_safety_role(
  p_user_id uuid,
  p_allowed public.admin_safety_role[]
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles profile
    join public.admin_role_assignments assignment
      on assignment.user_id = profile.id
     and assignment.revoked_at is null
     and (assignment.expires_at is null or assignment.expires_at > now())
    where profile.id = p_user_id
      and profile.role = 'admin'
      and profile.account_status = 'active'
      and (
        assignment.role = 'super_admin'
        or assignment.role = any(p_allowed)
      )
  );
$$;

create or replace function public.admin_set_safety_role(
  p_user_id uuid,
  p_role text,
  p_enabled boolean,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role public.admin_safety_role;
  v_changed integer := 0;
begin
  if auth.uid() is null or not private.has_admin_safety_role(
    auth.uid(), array['super_admin']::public.admin_safety_role[]
  ) then
    return jsonb_build_object('ok', false, 'code', 'super_admin_required');
  end if;
  if char_length(btrim(coalesce(p_reason, ''))) < 10 then
    return jsonb_build_object('ok', false, 'code', 'role_change_reason_required');
  end if;
  if p_enabled then
    return jsonb_build_object('ok', false, 'code', 'expiring_assignment_required');
  end if;
  begin
    v_role := lower(btrim(p_role))::public.admin_safety_role;
  exception when invalid_text_representation then
    return jsonb_build_object('ok', false, 'code', 'invalid_admin_safety_role');
  end;
  if v_role = 'super_admin' and (
    select count(*)
    from public.admin_role_assignments assignment
    join public.profiles profile on profile.id = assignment.user_id
    where assignment.role = 'super_admin'
      and assignment.revoked_at is null
      and (assignment.expires_at is null or assignment.expires_at > now())
      and profile.role = 'admin'
      and profile.account_status = 'active'
  ) <= 1 then
    return jsonb_build_object('ok', false, 'code', 'last_super_admin_cannot_be_removed');
  end if;

  update public.admin_role_assignments
  set revoked_at = now(),
      revoked_by = auth.uid(),
      revocation_reason = left(btrim(p_reason), 500)
  where user_id = p_user_id and role = v_role and revoked_at is null;
  get diagnostics v_changed = row_count;

  insert into public.verification_audit_events (
    actor_id, action, access_reason, event_data
  ) values (
    auth.uid(), 'admin_safety_role_disabled', left(btrim(p_reason), 500),
    jsonb_build_object('target_user_id', p_user_id, 'role', v_role, 'changed_rows', v_changed)
  );
  return jsonb_build_object(
    'ok', true, 'user_id', p_user_id, 'role', v_role,
    'enabled', false, 'changed_rows', v_changed
  );
end;
$$;

create or replace function public.admin_set_safety_role_v2(
  p_user_id uuid,
  p_role text,
  p_reason text,
  p_expires_at timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role public.admin_safety_role;
  v_target public.profiles%rowtype;
  v_assignment_id uuid;
begin
  if auth.uid() is null or not private.has_admin_safety_role(
    auth.uid(), array['super_admin']::public.admin_safety_role[]
  ) then
    return jsonb_build_object('ok', false, 'code', 'super_admin_required');
  end if;
  if char_length(btrim(coalesce(p_reason, ''))) not between 10 and 500 then
    return jsonb_build_object('ok', false, 'code', 'role_change_reason_required');
  end if;
  if p_expires_at is null or p_expires_at <= now() + interval '1 hour'
     or p_expires_at > now() + interval '30 days' then
    return jsonb_build_object('ok', false, 'code', 'bounded_role_expiry_required');
  end if;
  begin
    v_role := lower(btrim(p_role))::public.admin_safety_role;
  exception when invalid_text_representation then
    return jsonb_build_object('ok', false, 'code', 'invalid_admin_safety_role');
  end;
  if v_role = 'super_admin' then
    return jsonb_build_object('ok', false, 'code', 'super_admin_grant_requires_reviewed_server_migration');
  end if;
  select * into v_target from public.profiles where id = p_user_id;
  if v_target.id is null or v_target.role <> 'admin' or v_target.account_status <> 'active' then
    return jsonb_build_object('ok', false, 'code', 'active_admin_profile_required');
  end if;

  insert into public.admin_role_assignments (
    user_id, role, granted_by, grant_reason, expires_at
  ) values (
    p_user_id, v_role, auth.uid(), btrim(p_reason), p_expires_at
  )
  on conflict (user_id, role) where revoked_at is null
  do update set
    granted_by = excluded.granted_by,
    grant_reason = excluded.grant_reason,
    expires_at = excluded.expires_at
  returning id into v_assignment_id;

  insert into public.verification_audit_events (
    actor_id, action, access_reason, event_data
  ) values (
    auth.uid(), 'admin_safety_role_enabled_expiring', btrim(p_reason),
    jsonb_build_object(
      'assignment_id', v_assignment_id,
      'target_user_id', p_user_id,
      'role', v_role,
      'expires_at', p_expires_at
    )
  );
  return jsonb_build_object(
    'ok', true,
    'assignment_id', v_assignment_id,
    'user_id', p_user_id,
    'role', v_role,
    'expires_at', p_expires_at
  );
end;
$$;

revoke all on function public.admin_set_safety_role_v2(uuid, text, text, timestamptz)
from public, anon, authenticated;
grant execute on function public.admin_set_safety_role_v2(uuid, text, text, timestamptz)
to authenticated, service_role;

-- Account bans require an independent, assigned, expiring appeal review. The
-- ordinary account status RPC may still restore a suspension, never a ban.
create table public.account_ban_appeals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete restrict,
  source_enforcement_log_id uuid references public.admin_action_logs(id) on delete set null,
  reason text not null,
  status text not null default 'submitted',
  assigned_reviewer_id uuid references public.profiles(id) on delete set null,
  assignment_expires_at timestamptz,
  review_reason text,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '30 days'),
  constraint account_ban_appeal_reason_check check (
    char_length(btrim(reason)) between 20 and 2000
  ),
  constraint account_ban_appeal_status_check check (
    status in ('submitted', 'assigned', 'approved', 'denied', 'expired')
  ),
  constraint account_ban_appeal_expiry_check check (
    expires_at > created_at and expires_at <= created_at + interval '90 days'
  ),
  constraint account_ban_appeal_assignment_check check (
    (assigned_reviewer_id is null and assignment_expires_at is null)
    or (assigned_reviewer_id is not null and assignment_expires_at is not null)
  ),
  constraint account_ban_appeal_review_check check (
    (status in ('approved', 'denied') and reviewed_at is not null
      and char_length(btrim(coalesce(review_reason, ''))) between 10 and 1000)
    or (status not in ('approved', 'denied') and reviewed_at is null)
  )
);

create unique index account_ban_appeals_one_open_idx
on public.account_ban_appeals(user_id)
where status in ('submitted', 'assigned');
create index account_ban_appeals_queue_idx
on public.account_ban_appeals(status, created_at);
create index account_ban_appeals_reviewer_idx
on public.account_ban_appeals(assigned_reviewer_id, assignment_expires_at)
where status = 'assigned';

alter table public.account_ban_appeals enable row level security;
alter table public.account_ban_appeals force row level security;

create policy account_ban_appeals_select_owner_or_reviewer
on public.account_ban_appeals for select to authenticated
using (
  user_id = (select auth.uid())
  or private.has_admin_safety_role(
    (select auth.uid()),
    array['senior_safety_moderator', 'incident_manager']::public.admin_safety_role[]
  )
);

revoke all on public.account_ban_appeals from public, anon, authenticated;
grant select on public.account_ban_appeals to authenticated;
grant all on public.account_ban_appeals to service_role;

create or replace function public.submit_account_ban_appeal(p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile public.profiles%rowtype;
  v_appeal public.account_ban_appeals%rowtype;
  v_source_log_id uuid;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if char_length(btrim(coalesce(p_reason, ''))) not between 20 and 2000 then
    return jsonb_build_object('ok', false, 'code', 'ban_appeal_reason_invalid');
  end if;
  select * into v_profile from public.profiles where id = auth.uid() for update;
  if v_profile.id is null or v_profile.account_status <> 'banned' then
    return jsonb_build_object('ok', false, 'code', 'banned_account_required');
  end if;

  update public.account_ban_appeals
  set status = 'expired'
  where user_id = auth.uid()
    and status in ('submitted', 'assigned')
    and expires_at <= now();
  if exists (
    select 1 from public.account_ban_appeals
    where user_id = auth.uid() and status in ('submitted', 'assigned')
  ) then
    return jsonb_build_object('ok', false, 'code', 'ban_appeal_already_open');
  end if;

  select log.id into v_source_log_id
  from public.admin_action_logs log
  where log.target_table = 'profiles'
    and log.target_id = auth.uid()
    and (
      log.details ->> 'new_status' = 'banned'
      or log.details ->> 'newStatus' = 'banned'
    )
  order by log.created_at desc
  limit 1;

  insert into public.account_ban_appeals (
    user_id, source_enforcement_log_id, reason
  ) values (
    auth.uid(), v_source_log_id, btrim(p_reason)
  ) returning * into v_appeal;

  return jsonb_build_object(
    'ok', true,
    'appeal_id', v_appeal.id,
    'status', v_appeal.status,
    'expires_at', v_appeal.expires_at,
    'access_restored', false
  );
end;
$$;

create or replace function public.admin_claim_account_ban_appeal(
  p_appeal_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_appeal public.account_ban_appeals%rowtype;
  v_original_admin uuid;
begin
  if auth.uid() is null or not private.has_admin_safety_role(
    auth.uid(),
    array['senior_safety_moderator', 'incident_manager']::public.admin_safety_role[]
  ) then
    return jsonb_build_object('ok', false, 'code', 'ban_appeal_reviewer_required');
  end if;
  if char_length(btrim(coalesce(p_reason, ''))) not between 10 and 500 then
    return jsonb_build_object('ok', false, 'code', 'assignment_reason_required');
  end if;
  select * into v_appeal
  from public.account_ban_appeals where id = p_appeal_id for update;
  if v_appeal.id is null then
    return jsonb_build_object('ok', false, 'code', 'ban_appeal_not_found');
  end if;
  if v_appeal.expires_at <= now() then
    update public.account_ban_appeals set status = 'expired' where id = v_appeal.id;
    return jsonb_build_object('ok', false, 'code', 'ban_appeal_expired');
  end if;
  if v_appeal.status not in ('submitted', 'assigned') then
    return jsonb_build_object('ok', false, 'code', 'ban_appeal_not_open');
  end if;
  select log.admin_id into v_original_admin
  from public.admin_action_logs log where log.id = v_appeal.source_enforcement_log_id;
  if v_original_admin = auth.uid() then
    return jsonb_build_object('ok', false, 'code', 'independent_reviewer_required');
  end if;
  if v_appeal.status = 'assigned'
     and v_appeal.assigned_reviewer_id <> auth.uid()
     and v_appeal.assignment_expires_at > now() then
    return jsonb_build_object('ok', false, 'code', 'appeal_assigned_to_another_reviewer');
  end if;

  update public.account_ban_appeals
  set status = 'assigned',
      assigned_reviewer_id = auth.uid(),
      assignment_expires_at = now() + interval '2 hours'
  where id = v_appeal.id
  returning * into v_appeal;

  insert into public.admin_action_logs (
    admin_id, action, target_table, target_id, details
  ) values (
    auth.uid(), 'ban_appeal_claimed', 'account_ban_appeals', v_appeal.id,
    jsonb_build_object(
      'assignment_expires_at', v_appeal.assignment_expires_at,
      'reason', btrim(p_reason)
    )
  );
  return jsonb_build_object(
    'ok', true,
    'appeal_id', v_appeal.id,
    'status', v_appeal.status,
    'assignment_expires_at', v_appeal.assignment_expires_at
  );
end;
$$;

create or replace function public.admin_review_account_ban_appeal(
  p_appeal_id uuid,
  p_decision text,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_appeal public.account_ban_appeals%rowtype;
  v_decision text := lower(btrim(coalesce(p_decision, '')));
  v_original_admin uuid;
begin
  if auth.uid() is null or not private.has_admin_safety_role(
    auth.uid(),
    array['senior_safety_moderator', 'incident_manager']::public.admin_safety_role[]
  ) then
    return jsonb_build_object('ok', false, 'code', 'ban_appeal_reviewer_required');
  end if;
  if v_decision not in ('approve', 'deny') then
    return jsonb_build_object('ok', false, 'code', 'ban_appeal_decision_invalid');
  end if;
  if char_length(btrim(coalesce(p_reason, ''))) not between 10 and 1000 then
    return jsonb_build_object('ok', false, 'code', 'ban_appeal_review_reason_required');
  end if;
  select * into v_appeal
  from public.account_ban_appeals where id = p_appeal_id for update;
  if v_appeal.id is null then
    return jsonb_build_object('ok', false, 'code', 'ban_appeal_not_found');
  end if;
  if v_appeal.status <> 'assigned'
     or v_appeal.assigned_reviewer_id <> auth.uid()
     or v_appeal.assignment_expires_at <= now()
     or v_appeal.expires_at <= now() then
    return jsonb_build_object('ok', false, 'code', 'active_assigned_review_required');
  end if;
  select log.admin_id into v_original_admin
  from public.admin_action_logs log where log.id = v_appeal.source_enforcement_log_id;
  if v_original_admin = auth.uid() then
    return jsonb_build_object('ok', false, 'code', 'independent_reviewer_required');
  end if;

  if v_decision = 'approve' then
    update public.profiles
    set account_status = 'active', blocked_until = null
    where id = v_appeal.user_id and account_status = 'banned';
    if not found then
      return jsonb_build_object('ok', false, 'code', 'banned_account_required');
    end if;
  end if;

  update public.account_ban_appeals
  set status = case when v_decision = 'approve' then 'approved' else 'denied' end,
      review_reason = btrim(p_reason),
      reviewed_at = now()
  where id = v_appeal.id
  returning * into v_appeal;

  insert into public.admin_action_logs (
    admin_id, action, target_table, target_id, details
  ) values (
    auth.uid(), 'ban_appeal_' || v_decision, 'account_ban_appeals', v_appeal.id,
    jsonb_build_object(
      'target_user_id', v_appeal.user_id,
      'reason', btrim(p_reason),
      'account_restored', v_decision = 'approve'
    )
  );
  return jsonb_build_object(
    'ok', true,
    'appeal_id', v_appeal.id,
    'status', v_appeal.status,
    'account_restored', v_decision = 'approve'
  );
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
  if v_previous = 'banned' and v_status <> 'banned' then
    return jsonb_build_object('ok', false, 'code', 'ban_reversal_independent_review_required');
  end if;

  update public.profiles
  set account_status = v_status,
      blocked_until = case
        when v_status = 'active' then null
        when v_status = 'suspended' then now() + interval '24 hours'
        else null
      end
  where id = p_user_id;
  insert into public.admin_action_logs (
    admin_id, action, target_table, target_id, details
  ) values (
    auth.uid(), 'reasoned_account_status_update', 'profiles', p_user_id,
    jsonb_build_object(
      'previous_status', v_previous,
      'new_status', v_status,
      'reason_code', 'legacy_reasoned_action',
      'reason', btrim(p_reason),
      'restriction_expires_at', case when v_status = 'suspended' then now() + interval '24 hours' else null end
    )
  );
  return jsonb_build_object(
    'ok', true,
    'status', v_status,
    'restriction_expires_at', case when v_status = 'suspended' then now() + interval '24 hours' else null end
  );
end;
$$;

create or replace function public.admin_set_account_status_v2(
  p_user_id uuid,
  p_status text,
  p_reason_code text,
  p_reason text,
  p_expires_at timestamptz default null
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
  v_reason_code text := lower(btrim(coalesce(p_reason_code, '')));
begin
  if auth.uid() is null or not private.can_manage_incident(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'active_incident_manager_required');
  end if;
  if p_user_id = auth.uid() then
    return jsonb_build_object('ok', false, 'code', 'admin_self_restriction_blocked');
  end if;
  if p_status not in ('active', 'suspended', 'banned') then
    return jsonb_build_object('ok', false, 'code', 'account_status_invalid');
  end if;
  if v_reason_code not in (
    'safety_report_related', 'harassment', 'grooming_sexual_safety',
    'scam_fraud', 'prohibited_job', 'identity_risk', 'retaliation',
    'policy_violation', 'appeal_correction'
  ) then
    return jsonb_build_object('ok', false, 'code', 'account_action_reason_code_invalid');
  end if;
  if char_length(btrim(coalesce(p_reason, ''))) not between 10 and 1000 then
    return jsonb_build_object('ok', false, 'code', 'decision_reason_required');
  end if;
  v_status := p_status::public.account_status;
  if v_status = 'suspended' and (
    p_expires_at is null or p_expires_at <= now() + interval '15 minutes'
    or p_expires_at > now() + interval '30 days'
  ) then
    return jsonb_build_object('ok', false, 'code', 'bounded_suspension_expiry_required');
  end if;
  if v_status <> 'suspended' and p_expires_at is not null then
    return jsonb_build_object('ok', false, 'code', 'expiry_only_allowed_for_suspension');
  end if;

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
  if v_previous = 'banned' and v_status <> 'banned' then
    return jsonb_build_object('ok', false, 'code', 'ban_reversal_independent_review_required');
  end if;

  update public.profiles
  set account_status = v_status,
      blocked_until = case when v_status = 'suspended' then p_expires_at else null end
  where id = p_user_id;
  insert into public.admin_action_logs (
    admin_id, action, target_table, target_id, details
  ) values (
    auth.uid(), 'coded_account_status_update', 'profiles', p_user_id,
    jsonb_build_object(
      'previous_status', v_previous,
      'new_status', v_status,
      'reason_code', v_reason_code,
      'reason', btrim(p_reason),
      'restriction_expires_at', p_expires_at
    )
  );
  return jsonb_build_object(
    'ok', true, 'status', v_status, 'restriction_expires_at', p_expires_at
  );
end;
$$;

revoke all on function public.submit_account_ban_appeal(text)
from public, anon, authenticated;
revoke all on function public.admin_claim_account_ban_appeal(uuid, text)
from public, anon, authenticated;
revoke all on function public.admin_review_account_ban_appeal(uuid, text, text)
from public, anon, authenticated;
revoke all on function public.admin_set_account_status_v2(uuid, text, text, text, timestamptz)
from public, anon, authenticated;
grant execute on function public.submit_account_ban_appeal(text)
to authenticated, service_role;
grant execute on function public.admin_claim_account_ban_appeal(uuid, text)
to authenticated, service_role;
grant execute on function public.admin_review_account_ban_appeal(uuid, text, text)
to authenticated, service_role;
grant execute on function public.admin_set_account_status_v2(uuid, text, text, text, timestamptz)
to authenticated, service_role;

-- Separate, versionable legal drafts. They remain inactive and have no
-- effective date, publication date, or counsel approval reference.
insert into public.legal_documents (
  document_key, title, document_category, publication_status,
  guardian_mode_independent
) values
  ('mort_community_guidelines', 'MORT Community Guidelines Draft', 'conduct', 'draft_attorney_review', true),
  ('mort_safety_rules', 'MORT Safety Rules Draft', 'safety', 'draft_attorney_review', true),
  ('mort_guardian_terms', 'MORT Guardian Terms Draft', 'role_terms', 'draft_attorney_review', true)
on conflict (document_key) do update
set title = excluded.title,
    document_category = excluded.document_category,
    publication_status = 'draft_attorney_review',
    guardian_mode_independent = true;

with versions(document_key, content_hash, content_path) as (
  values
    ('mort_community_guidelines', 'ce5a733e00a6eeea3371ac469fdf9c6741812a75937977454a59565b2d006912', 'docs/legal/MORT_COMMUNITY_GUIDELINES_DRAFT.md'),
    ('mort_safety_rules', 'd6b2e10f36155a11bd2b8af19ff368d782c3d41aa441ddbffd732883624b9d26', 'docs/legal/MORT_SAFETY_RULES_DRAFT.md'),
    ('mort_guardian_terms', '4c258d4be011c0e2af017999b93850229570a18e44f8d14ae6b19ca6c3ea1106', 'docs/legal/MORT_GUARDIAN_TERMS_DRAFT.md')
)
insert into public.legal_document_versions (
  document_id, version_label, content_hash, content_path,
  material_revision, publication_status, language_code,
  jurisdiction_policy, acceptance_ui_version
)
select
  document.id,
  '2026-08-01-attorney-draft-1',
  version.content_hash,
  version.content_path,
  true,
  'draft_attorney_review',
  'en-US',
  'requires_jurisdiction_specific_attorney_review',
  'legal-clickwrap-v1'
from versions version
join public.legal_documents document on document.document_key = version.document_key
on conflict (document_id, version_label) do update
set content_hash = excluded.content_hash,
    content_path = excluded.content_path,
    publication_status = 'draft_attorney_review',
    effective_at = null,
    published_at = null,
    attorney_reviewed_at = null,
    approved_by_counsel_reference = null;

with role_requirements(document_key, role, required, priority) as (
  values
    ('mort_community_guidelines', 'teen'::public.user_role, true, 45),
    ('mort_community_guidelines', 'adult'::public.user_role, true, 45),
    ('mort_community_guidelines', 'guardian'::public.user_role, true, 45),
    ('mort_community_guidelines', 'admin'::public.user_role, true, 45),
    ('mort_safety_rules', 'teen'::public.user_role, true, 46),
    ('mort_safety_rules', 'adult'::public.user_role, true, 46),
    ('mort_safety_rules', 'guardian'::public.user_role, true, 46),
    ('mort_safety_rules', 'admin'::public.user_role, true, 46),
    ('mort_guardian_terms', 'guardian'::public.user_role, true, 47),
    ('mort_guardian_terms', 'teen'::public.user_role, false, 900)
)
insert into public.legal_role_requirements (
  document_id, role, age_band, required, priority
)
select document.id, requirement.role, 'all', requirement.required, requirement.priority
from role_requirements requirement
join public.legal_documents document on document.document_key = requirement.document_key
on conflict (document_id, role, age_band) do update
set required = excluded.required, priority = excluded.priority;

insert into public.legal_jurisdiction_requirements (
  document_id, country_code, region_code, requirement_status,
  guardian_legal_consent_required, configured_separately_from_guardian_mode
)
select
  document.id, 'US', '*', 'legal_review_required',
  null, true
from public.legal_documents document
where document.document_key in (
  'mort_community_guidelines', 'mort_safety_rules', 'mort_guardian_terms'
)
on conflict (document_id, country_code, region_code) do update
set requirement_status = 'legal_review_required',
    guardian_legal_consent_required = null,
    configured_separately_from_guardian_mode = true,
    legal_review_reference = null,
    effective_at = null;

-- No client or ordinary admin RPC can set these approvals. A future reviewed
-- server migration must record real owner, counsel, policy, contact, and
-- staffing evidence before the activation predicate can ever become true.
create table private.public_release_legal_controls (
  singleton boolean primary key default true check (singleton),
  owner_approved boolean not null default false,
  owner_approved_by uuid references public.profiles(id) on delete set null,
  owner_approved_at timestamptz,
  attorney_package_approved boolean not null default false,
  counsel_reference text,
  child_safety_contact_approved boolean not null default false,
  privacy_contact_approved boolean not null default false,
  support_contact_approved boolean not null default false,
  play_declarations_approved boolean not null default false,
  moderation_staffing_approved boolean not null default false,
  incident_on_call_approved boolean not null default false,
  approved_document_set_hash text,
  approved_locale text not null default 'en-US',
  updated_at timestamptz not null default now(),
  constraint public_release_owner_approval_check check (
    (not owner_approved and owner_approved_by is null and owner_approved_at is null)
    or (owner_approved and owner_approved_by is not null and owner_approved_at is not null)
  ),
  constraint public_release_attorney_approval_check check (
    (not attorney_package_approved and counsel_reference is null)
    or (attorney_package_approved and char_length(btrim(coalesce(counsel_reference, ''))) between 8 and 500)
  ),
  constraint public_release_document_hash_check check (
    approved_document_set_hash is null or approved_document_set_hash ~ '^[a-f0-9]{64}$'
  ),
  constraint public_release_locale_check check (
    approved_locale ~ '^[a-z]{2}-[A-Z]{2}$'
  )
);

insert into private.public_release_legal_controls (singleton)
values (true)
on conflict (singleton) do nothing;

alter table private.public_release_legal_controls enable row level security;
alter table private.public_release_legal_controls force row level security;
revoke all on private.public_release_legal_controls from public, anon, authenticated;
grant all on private.public_release_legal_controls to service_role;

create or replace function private.required_public_legal_document_keys()
returns text[]
language sql
immutable
security definer
set search_path = ''
as $$
  select array[
    'mort_terms_of_service',
    'mort_terms_of_use',
    'mort_privacy_policy',
    'mort_community_guidelines',
    'mort_safety_rules',
    'mort_guardian_terms',
    'mort_data_retention_and_deletion',
    'mort_location_and_meeting_policy',
    'mort_identity_review_disclosure',
    'mort_moderation_and_appeals_policy',
    'mort_prohibited_work_policy',
    'mort_payment_dispute_policy',
    'ai_support_disclosure_0_9_3_draft'
  ]::text[];
$$;

create or replace function private.public_release_legal_ready()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select
      control.owner_approved
      and control.owner_approved_by is not null
      and control.owner_approved_at is not null
      and control.attorney_package_approved
      and control.counsel_reference is not null
      and control.child_safety_contact_approved
      and control.privacy_contact_approved
      and control.support_contact_approved
      and control.play_declarations_approved
      and control.moderation_staffing_approved
      and control.incident_on_call_approved
      and control.approved_document_set_hash is not null
      and not exists (
        select 1
        from unnest(private.required_public_legal_document_keys()) required(document_key)
        where not exists (
          select 1
          from public.legal_documents document
          join public.legal_document_versions version on version.document_id = document.id
          where document.document_key = required.document_key
            and document.publication_status = 'published'
            and version.publication_status = 'published'
            and version.language_code = control.approved_locale
            and version.effective_at <= now()
            and version.published_at is not null
            and version.retired_at is null
            and version.attorney_reviewed_at is not null
            and version.approved_by_counsel_reference is not null
            and char_length(coalesce(version.content_markdown, '')) >= 200
        )
      )
      and not exists (
        select 1
        from unnest(private.required_public_legal_document_keys()) required(document_key)
        join public.legal_documents document on document.document_key = required.document_key
        where not exists (
          select 1
          from public.legal_jurisdiction_requirements jurisdiction
          where jurisdiction.document_id = document.id
            and jurisdiction.country_code = 'US'
            and jurisdiction.region_code in ('IN', '*')
            and jurisdiction.requirement_status = 'approved'
            and jurisdiction.legal_review_reference is not null
            and jurisdiction.effective_at <= now()
        )
      )
    from private.public_release_legal_controls control
    where control.singleton
  ), false);
$$;

create or replace function private.public_marketplace_activation_ready()
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_policy private.pilot_policy_versions%rowtype;
begin
  select * into v_policy from private.current_pilot_policy();
  return private.public_release_legal_ready()
    and private.production_identity_ready()
    and v_policy.id is not null
    and v_policy.release_mode = 'production_public'
    and v_policy.unrestricted_public_access_enabled
    and not exists (
      select 1
      from public.admin_role_assignments assignment
      where assignment.revoked_at is null
        and assignment.expires_at is null
    );
end;
$$;

revoke all on function private.required_public_legal_document_keys()
from public, anon, authenticated;
revoke all on function private.public_release_legal_ready()
from public, anon, authenticated;
revoke all on function private.public_marketplace_activation_ready()
from public, anon, authenticated;
grant execute on function private.required_public_legal_document_keys() to service_role;
grant execute on function private.public_release_legal_ready() to service_role;
grant execute on function private.public_marketplace_activation_ready() to service_role;

create or replace function public.get_public_release_readiness()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_control private.public_release_legal_controls%rowtype;
  v_policy private.pilot_policy_versions%rowtype;
  v_missing_documents jsonb;
  v_legacy_unbounded_roles integer;
begin
  select * into v_control from private.public_release_legal_controls where singleton;
  select * into v_policy from private.current_pilot_policy();
  select coalesce(jsonb_agg(required.document_key order by required.document_key), '[]'::jsonb)
  into v_missing_documents
  from unnest(private.required_public_legal_document_keys()) required(document_key)
  where not exists (
    select 1
    from public.legal_documents document
    join public.legal_document_versions version on version.document_id = document.id
    where document.document_key = required.document_key
      and document.publication_status = 'published'
      and version.publication_status = 'published'
      and version.language_code = coalesce(v_control.approved_locale, 'en-US')
      and version.effective_at <= now()
      and version.retired_at is null
      and version.attorney_reviewed_at is not null
      and version.approved_by_counsel_reference is not null
  );
  select count(*) into v_legacy_unbounded_roles
  from public.admin_role_assignments assignment
  where assignment.revoked_at is null and assignment.expires_at is null;

  return jsonb_build_object(
    'ok', true,
    'public_marketplace_open', false,
    'activation_ready', private.public_marketplace_activation_ready(),
    'legal_ready', private.public_release_legal_ready(),
    'owner_approved', coalesce(v_control.owner_approved, false),
    'attorney_package_approved', coalesce(v_control.attorney_package_approved, false),
    'child_safety_contact_approved', coalesce(v_control.child_safety_contact_approved, false),
    'privacy_contact_approved', coalesce(v_control.privacy_contact_approved, false),
    'support_contact_approved', coalesce(v_control.support_contact_approved, false),
    'play_declarations_approved', coalesce(v_control.play_declarations_approved, false),
    'moderation_staffing_approved', coalesce(v_control.moderation_staffing_approved, false),
    'incident_on_call_approved', coalesce(v_control.incident_on_call_approved, false),
    'identity_provider_ready', private.production_identity_ready(),
    'release_policy_public', coalesce(v_policy.release_mode = 'production_public' and v_policy.unrestricted_public_access_enabled, false),
    'missing_published_document_keys', v_missing_documents,
    'legacy_unbounded_role_assignments', v_legacy_unbounded_roles
  );
end;
$$;

revoke all on function public.get_public_release_readiness()
from public, anon, authenticated;
grant execute on function public.get_public_release_readiness()
to authenticated, service_role;

alter table private.runtime_feature_controls
  drop constraint if exists runtime_public_marketplace_closed_check;

create or replace function private.enforce_public_marketplace_activation_gate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not new.public_marketplace_closed
     and not private.public_marketplace_activation_ready() then
    raise exception 'public_marketplace_activation_gate_incomplete';
  end if;
  return new;
end;
$$;

drop trigger if exists runtime_public_marketplace_activation_gate
on private.runtime_feature_controls;
create trigger runtime_public_marketplace_activation_gate
before insert or update
on private.runtime_feature_controls
for each row execute function private.enforce_public_marketplace_activation_gate();

revoke all on function private.enforce_public_marketplace_activation_gate()
from public, anon, authenticated;
grant execute on function private.enforce_public_marketplace_activation_gate()
to service_role;

create or replace function public.admin_update_runtime_feature_controls(
  p_maintenance_mode boolean,
  p_ai_provider_disabled boolean,
  p_payments_disabled boolean,
  p_new_job_publishing_disabled boolean,
  p_public_marketplace_closed boolean,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_before private.runtime_feature_controls%rowtype;
  v_after private.runtime_feature_controls%rowtype;
begin
  if v_actor is null or not private.has_admin_safety_role(
    v_actor,
    array['incident_manager', 'super_admin']::public.admin_safety_role[]
  ) then
    return jsonb_build_object('ok', false, 'code', 'incident_manager_role_required');
  end if;
  if char_length(btrim(coalesce(p_reason, ''))) not between 12 and 500 then
    return jsonb_build_object('ok', false, 'code', 'control_change_reason_required');
  end if;
  if not p_public_marketplace_closed
     and not private.public_marketplace_activation_ready() then
    return jsonb_build_object('ok', false, 'code', 'public_marketplace_activation_gate_incomplete');
  end if;

  select * into v_before
  from private.runtime_feature_controls
  where singleton
  for update;

  update private.runtime_feature_controls
  set maintenance_mode = p_maintenance_mode,
      ai_provider_disabled = p_ai_provider_disabled,
      payments_disabled = p_payments_disabled,
      new_job_publishing_disabled = p_new_job_publishing_disabled,
      public_marketplace_closed = p_public_marketplace_closed,
      updated_by = v_actor,
      update_reason = btrim(p_reason),
      updated_at = now()
  where singleton
  returning * into v_after;

  insert into public.admin_action_logs (
    admin_id, action, target_table, details
  ) values (
    v_actor,
    'runtime_feature_controls_updated',
    'private.runtime_feature_controls',
    jsonb_build_object(
      'maintenance_mode', jsonb_build_array(v_before.maintenance_mode, v_after.maintenance_mode),
      'ai_provider_disabled', jsonb_build_array(v_before.ai_provider_disabled, v_after.ai_provider_disabled),
      'payments_disabled', jsonb_build_array(v_before.payments_disabled, v_after.payments_disabled),
      'new_job_publishing_disabled', jsonb_build_array(v_before.new_job_publishing_disabled, v_after.new_job_publishing_disabled),
      'public_marketplace_closed', jsonb_build_array(v_before.public_marketplace_closed, v_after.public_marketplace_closed),
      'reason', btrim(p_reason)
    )
  );

  return jsonb_build_object('ok', true, 'updated_at', v_after.updated_at);
end;
$$;

-- Final assertions: drafts and activation controls must remain fail-closed.
do $$
begin
  if exists (
    select 1
    from public.legal_documents document
    join public.legal_document_versions version on version.document_id = document.id
    where document.document_key in (
      'mort_community_guidelines', 'mort_safety_rules', 'mort_guardian_terms'
    ) and (
      document.publication_status <> 'draft_attorney_review'
      or version.publication_status <> 'draft_attorney_review'
      or version.effective_at is not null
      or version.published_at is not null
      or version.attorney_reviewed_at is not null
      or version.approved_by_counsel_reference is not null
    )
  ) then
    raise exception 'Phase 13/14 legal drafts must remain inactive pending qualified review';
  end if;
  if exists (
    select 1 from private.runtime_feature_controls
    where not public_marketplace_closed
  ) then
    raise exception 'Public marketplace must remain closed in Phase 13/14';
  end if;
  if private.public_release_legal_ready()
     or private.public_marketplace_activation_ready() then
    raise exception 'External legal, staffing, owner, identity, and release gates must remain incomplete';
  end if;
end $$;
