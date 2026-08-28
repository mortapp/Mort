-- Correct the abandonment workflow before 0.9.3 release. A participant report
-- is an allegation, never a final finding or an automatic penalty.

alter table public.teen_abandonment_reports
  add column if not exists reported_by_adult_id uuid references public.profiles(id) on delete restrict,
  add column if not exists teen_response text,
  add column if not exists teen_responded_at timestamptz,
  add column if not exists decision_status text not null default 'reported',
  add column if not exists decision_reason text,
  add column if not exists decided_by uuid references public.profiles(id) on delete restrict,
  add column if not exists decided_at timestamptz,
  add column if not exists confirmed_non_safety_abandonment boolean not null default false,
  add column if not exists safety_related boolean not null default false,
  add column if not exists cooldown_applied_at timestamptz;

alter table public.teen_abandonment_reports
  drop constraint if exists teen_abandonment_decision_status_check;
alter table public.teen_abandonment_reports
  add constraint teen_abandonment_decision_status_check check (
    decision_status in (
      'reported', 'teen_responded', 'request_more_information',
      'resolved_no_payout', 'resolved_partial_payout', 'resolved_full_payout',
      'resolved_safety_cancellation', 'resolved_insufficient_evidence'
    )
  );
alter table public.teen_abandonment_reports
  drop constraint if exists teen_abandonment_response_length_check;
alter table public.teen_abandonment_reports
  add constraint teen_abandonment_response_length_check check (
    teen_response is null or char_length(btrim(teen_response)) between 10 and 2000
  );
alter table public.teen_abandonment_reports
  drop constraint if exists teen_abandonment_decision_reason_length_check;
alter table public.teen_abandonment_reports
  add constraint teen_abandonment_decision_reason_length_check check (
    decision_reason is null or char_length(btrim(decision_reason)) between 10 and 2000
  );

drop policy if exists teen_abandonment_reports_select_owner_admin on public.teen_abandonment_reports;
create policy teen_abandonment_reports_select_participants_admin
on public.teen_abandonment_reports for select to authenticated
using (
  teen_id = (select auth.uid())
  or reported_by_adult_id = (select auth.uid())
  or public.is_admin()
);

alter table public.job_execution_events drop constraint if exists job_execution_event_type_check;
alter table public.job_execution_events add constraint job_execution_event_type_check check (
  event_type in (
    'start_pin_generated', 'start_pin_generation_replayed', 'start_pin_failed_attempt',
    'start_pin_locked', 'start_confirmed', 'finish_pin_generated',
    'finish_pin_generation_replayed', 'finish_pin_failed_attempt', 'finish_pin_locked',
    'finish_confirmed', 'finish_pin_unavailable_reported', 'person_mismatch_reported',
    'adult_cancelled', 'teen_abandonment_reported', 'teen_abandonment_response',
    'teen_abandonment_decided', 'completion_review_started'
  )
);

create or replace function public.report_possible_teen_abandonment(
  p_application_id uuid,
  p_statement text,
  p_client_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_handshake public.job_arrival_handshakes%rowtype;
  v_contract public.job_contracts%rowtype;
  v_report public.teen_abandonment_reports%rowtype;
  v_review jsonb;
begin
  select * into v_handshake from public.job_arrival_handshakes
  where application_id = p_application_id for update;
  select * into v_contract from public.job_contracts
  where application_id = p_application_id for update;
  if v_handshake.id is null or v_handshake.adult_id <> auth.uid() then
    return jsonb_build_object('ok', false, 'code', 'job_poster_required');
  end if;
  if v_handshake.execution_state not in ('in_progress', 'finish_pin_active')
     or v_handshake.start_pin_used_at is null then
    return jsonb_build_object('ok', false, 'code', 'in_progress_start_confirmation_required');
  end if;
  if char_length(btrim(coalesce(p_statement, ''))) not between 10 and 2000 then
    return jsonb_build_object('ok', false, 'code', 'abandonment_statement_required');
  end if;
  select * into v_report from public.teen_abandonment_reports
  where reported_by_adult_id = auth.uid() and client_request_id = p_client_request_id;
  if v_report.id is not null then
    return jsonb_build_object(
      'ok', true, 'replayed', true, 'report', to_jsonb(v_report),
      'cooldown_applied', false, 'money_moved', false
    );
  end if;
  v_review := private.open_execution_review_case(
    p_application_id,
    'teen_abandonment',
    'Possible teen abandonment report',
    btrim(p_statement),
    'payment_dispute'
  );
  insert into public.teen_abandonment_reports(
    application_id, contract_id, teen_id, statement,
    final_non_safety_confirmation, cooldown_until,
    support_ticket_id, dispute_id, client_request_id,
    reported_by_adult_id, decision_status
  ) values (
    p_application_id, v_contract.id, v_handshake.teen_id, btrim(p_statement),
    true, null,
    nullif(v_review#>>'{support,ticket,id}', '')::uuid,
    nullif(v_review->>'dispute_id', '')::uuid,
    p_client_request_id, auth.uid(), 'reported'
  ) returning * into v_report;
  update public.job_arrival_handshakes
  set execution_state = 'disputed', finish_pin_hash = null,
      finish_pin_expires_at = null, updated_at = now()
  where id = v_handshake.id;
  update public.applications set status = 'disputed', updated_at = now()
  where id = p_application_id;
  insert into public.job_execution_events(
    application_id, contract_id, contract_version_id, actor_id,
    event_type, from_state, to_state, request_id,
    safe_metadata
  ) values (
    p_application_id, v_contract.id, v_contract.active_version_id, auth.uid(),
    'teen_abandonment_reported', v_handshake.execution_state, 'disputed',
    p_client_request_id,
    jsonb_build_object('allegation_only', true, 'cooldown_applied', false)
  );
  perform public.enqueue_notification(
    v_handshake.teen_id,
    'Response requested for a job report',
    'The adult reported possible abandonment. This is not a finding or automatic penalty. You can respond, open support, or use Safety Center.',
    jsonb_build_object('applicationId', p_application_id, 'route', '/jobs/progress/' || p_application_id::text)
  );
  return jsonb_build_object(
    'ok', true, 'replayed', false, 'report', to_jsonb(v_report),
    'cooldown_applied', false, 'money_moved', false,
    'human_review_required', true
  );
end;
$$;

create or replace function public.respond_to_teen_abandonment(
  p_application_id uuid,
  p_statement text,
  p_safety_related boolean,
  p_client_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_handshake public.job_arrival_handshakes%rowtype;
  v_contract public.job_contracts%rowtype;
  v_report public.teen_abandonment_reports%rowtype;
begin
  select * into v_handshake from public.job_arrival_handshakes
  where application_id = p_application_id for update;
  select * into v_contract from public.job_contracts
  where application_id = p_application_id;
  if v_handshake.id is null or v_handshake.teen_id <> auth.uid() then
    return jsonb_build_object('ok', false, 'code', 'assigned_worker_required');
  end if;
  if char_length(btrim(coalesce(p_statement, ''))) not between 10 and 2000 then
    return jsonb_build_object('ok', false, 'code', 'abandonment_statement_required');
  end if;
  select * into v_report from public.teen_abandonment_reports
  where application_id = p_application_id
    and decision_status in ('reported', 'teen_responded', 'request_more_information')
  order by created_at desc limit 1 for update;
  if v_report.id is null then
    return jsonb_build_object('ok', false, 'code', 'adult_report_required');
  end if;
  if exists (
    select 1 from public.job_execution_events
    where application_id = p_application_id
      and event_type = 'teen_abandonment_response'
      and actor_id = auth.uid() and request_id = p_client_request_id
  ) then
    return jsonb_build_object(
      'ok', true, 'replayed', true, 'report_id', v_report.id,
      'cooldown_applied', false, 'money_moved', false
    );
  end if;
  update public.teen_abandonment_reports
  set teen_response = btrim(p_statement), teen_responded_at = now(),
      safety_related = coalesce(p_safety_related, false),
      decision_status = 'teen_responded'
  where id = v_report.id returning * into v_report;
  insert into public.job_execution_events(
    application_id, contract_id, contract_version_id, actor_id,
    event_type, from_state, to_state, request_id,
    safe_metadata
  ) values (
    p_application_id, v_contract.id, v_contract.active_version_id, auth.uid(),
    'teen_abandonment_response', v_handshake.execution_state,
    v_handshake.execution_state, p_client_request_id,
    jsonb_build_object('safety_related', coalesce(p_safety_related, false))
  );
  perform public.enqueue_notification(
    v_handshake.adult_id,
    'A response was added to the job report',
    'The teen responded. No payment or penalty decision has been made.',
    jsonb_build_object('applicationId', p_application_id, 'route', '/jobs/progress/' || p_application_id::text)
  );
  return jsonb_build_object(
    'ok', true, 'replayed', false, 'report_id', v_report.id,
    'safety_route_recommended', v_report.safety_related,
    'cooldown_applied', false, 'money_moved', false
  );
end;
$$;

-- Preserve the initial function name for 0.9.3 clients, but make it a response
-- to an adult report. It no longer creates a finding or applies a cooldown.
create or replace function public.submit_teen_abandonment(
  p_application_id uuid,
  p_statement text,
  p_safety_related boolean,
  p_final_confirmation boolean,
  p_client_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not coalesce(p_final_confirmation, false) then
    return jsonb_build_object('ok', false, 'code', 'response_confirmation_required');
  end if;
  return public.respond_to_teen_abandonment(
    p_application_id, p_statement, p_safety_related, p_client_request_id
  );
end;
$$;

create or replace function public.staff_finalize_teen_abandonment(
  p_report_id uuid,
  p_decision_status text,
  p_reason text,
  p_confirmed_non_safety_abandonment boolean,
  p_client_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_report public.teen_abandonment_reports%rowtype;
  v_control private.job_execution_runtime_controls%rowtype;
  v_cooldown timestamptz;
begin
  if not private.has_support_role(auth.uid(), array['support_manager', 'safety_reviewer']) then
    return jsonb_build_object('ok', false, 'code', 'authorized_reviewer_required');
  end if;
  if p_decision_status not in (
    'request_more_information', 'resolved_no_payout',
    'resolved_partial_payout', 'resolved_full_payout',
    'resolved_safety_cancellation', 'resolved_insufficient_evidence'
  ) then return jsonb_build_object('ok', false, 'code', 'invalid_decision_status'); end if;
  if char_length(btrim(coalesce(p_reason, ''))) not between 10 and 2000 then
    return jsonb_build_object('ok', false, 'code', 'decision_reason_required');
  end if;
  if coalesce(p_confirmed_non_safety_abandonment, false)
     and p_decision_status not in ('resolved_no_payout', 'resolved_partial_payout') then
    return jsonb_build_object('ok', false, 'code', 'confirmed_abandonment_decision_mismatch');
  end if;
  select * into v_report from public.teen_abandonment_reports
  where id = p_report_id for update;
  if v_report.id is null then return jsonb_build_object('ok', false, 'code', 'report_not_found'); end if;
  if v_report.decided_at is not null then
    return jsonb_build_object(
      'ok', true, 'replayed', true, 'report_id', v_report.id,
      'decision_status', v_report.decision_status,
      'cooldown_until', v_report.cooldown_until, 'money_moved', false
    );
  end if;
  if p_decision_status = 'resolved_safety_cancellation'
     and coalesce(p_confirmed_non_safety_abandonment, false) then
    return jsonb_build_object('ok', false, 'code', 'safety_cancellation_cannot_be_penalized');
  end if;
  select * into v_control from private.job_execution_runtime_controls where singleton;
  v_cooldown := case
    when coalesce(p_confirmed_non_safety_abandonment, false)
      and not v_report.safety_related
      and v_control.closed_test_mode
    then now() + make_interval(secs => v_control.teen_abandonment_cooldown_seconds)
    else null
  end;
  update public.teen_abandonment_reports
  set decision_status = p_decision_status,
      decision_reason = btrim(p_reason), decided_by = auth.uid(),
      decided_at = case when p_decision_status = 'request_more_information' then null else now() end,
      confirmed_non_safety_abandonment = coalesce(p_confirmed_non_safety_abandonment, false),
      cooldown_until = v_cooldown,
      cooldown_applied_at = case when v_cooldown is null then null else now() end
  where id = v_report.id returning * into v_report;
  insert into public.job_execution_events(
    application_id, contract_id, actor_id, event_type,
    from_state, to_state, request_id, safe_metadata
  ) values (
    v_report.application_id, v_report.contract_id, auth.uid(),
    'teen_abandonment_decided', 'disputed', 'disputed', p_client_request_id,
    jsonb_build_object(
      'decision_status', p_decision_status,
      'confirmed_non_safety_abandonment', coalesce(p_confirmed_non_safety_abandonment, false),
      'closed_test_cooldown_applied', v_cooldown is not null
    )
  );
  return jsonb_build_object(
    'ok', true, 'replayed', false, 'report_id', v_report.id,
    'decision_status', v_report.decision_status,
    'cooldown_until', v_report.cooldown_until,
    'money_moved', false
  );
end;
$$;

do $$
declare signature text;
begin
  foreach signature in array array[
    'public.report_possible_teen_abandonment(uuid,text,uuid)',
    'public.respond_to_teen_abandonment(uuid,text,boolean,uuid)',
    'public.submit_teen_abandonment(uuid,text,boolean,boolean,uuid)',
    'public.staff_finalize_teen_abandonment(uuid,text,text,boolean,uuid)'
  ] loop
    execute format('revoke all on function %s from public, anon', signature);
    execute format('grant execute on function %s to authenticated, service_role', signature);
  end loop;
end $$;
