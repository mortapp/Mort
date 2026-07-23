-- Preserve the 0.9.3 cancellation workflow while making the enum assignment
-- explicit. PostgreSQL otherwise infers the CASE branches as text in PL/pgSQL.
create or replace function public.request_adult_job_cancellation(
  p_application_id uuid,
  p_reason text,
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
  v_obligation public.job_payment_obligations%rowtype;
  v_control private.job_execution_runtime_controls%rowtype;
  v_record public.job_execution_cancellations%rowtype;
  v_stage text;
  v_bps integer;
  v_review jsonb;
begin
  select * into v_control from private.job_execution_runtime_controls where singleton;
  select * into v_handshake from public.job_arrival_handshakes where application_id = p_application_id for update;
  select * into v_contract from public.job_contracts where application_id = p_application_id for update;
  select * into v_obligation from public.job_payment_obligations where contract_id = v_contract.id and contract_version_id = v_contract.active_version_id for update;
  if v_handshake.id is null or v_handshake.adult_id <> auth.uid() then return jsonb_build_object('ok', false, 'code', 'job_poster_required'); end if;
  if char_length(btrim(coalesce(p_reason, ''))) not between 3 and 2000 then return jsonb_build_object('ok', false, 'code', 'cancellation_reason_required'); end if;
  select * into v_record from public.job_execution_cancellations where actor_id = auth.uid() and client_request_id = p_client_request_id;
  if v_record.id is not null then return jsonb_build_object('ok', true, 'replayed', true, 'cancellation', to_jsonb(v_record), 'money_moved', false); end if;
  v_stage := case when v_handshake.start_pin_used_at is null then 'before_start' else 'after_start' end;
  v_bps := case when v_stage = 'before_start' then v_control.pre_start_compensation_bps else v_control.post_start_compensation_bps end;
  if v_obligation.id is not null then
    v_review := private.open_execution_review_case(p_application_id, 'job_cancellation', 'Adult job cancellation review', btrim(p_reason), 'payment_dispute');
  else
    v_review := public.create_support_conversation('job_cancellation', 'Adult job cancellation', btrim(p_reason), 'human_support', v_handshake.job_id, p_application_id, v_contract.id, null, gen_random_uuid());
  end if;
  insert into public.job_execution_cancellations(
    application_id, contract_id, actor_id, actor_role, cancellation_stage, reason,
    recommended_compensation_cents, compensation_policy_bps, execution_status,
    support_ticket_id, dispute_id, client_request_id
  ) values (
    p_application_id, v_contract.id, auth.uid(), 'adult', v_stage, btrim(p_reason),
    coalesce(v_obligation.amount_cents, 0) * v_bps / 10000, v_bps,
    'disabled_pending_review',
    coalesce(nullif(v_review#>>'{support,ticket,id}', '')::uuid, nullif(v_review#>>'{ticket,id}', '')::uuid),
    nullif(v_review->>'dispute_id', '')::uuid, p_client_request_id
  ) returning * into v_record;
  update public.job_arrival_handshakes set execution_state = case when v_obligation.id is null then 'cancelled' else 'disputed' end, start_pin_hash = null, finish_pin_hash = null, updated_at = now() where id = v_handshake.id;
  update public.applications
  set status = case
      when v_obligation.id is null then 'withdrawn'::public.application_status
      else 'disputed'::public.application_status
    end,
    updated_at = now()
  where id = p_application_id;
  update public.jobs set status = case when v_obligation.id is null then 'cancelled' else status end, updated_at = now() where id = v_handshake.job_id;
  update public.job_contracts set status = case when v_obligation.id is null then 'cancelled' else 'disputed' end, closed_at = case when v_obligation.id is null then now() else closed_at end where id = v_contract.id;
  insert into public.job_execution_events(application_id, contract_id, contract_version_id, actor_id, event_type, from_state, to_state, request_id, safe_metadata)
  values (p_application_id, v_contract.id, v_contract.active_version_id, auth.uid(), 'adult_cancelled', v_handshake.execution_state,
    case when v_obligation.id is null then 'cancelled' else 'disputed' end, p_client_request_id,
    jsonb_build_object('stage', v_stage, 'compensation_policy_bps', v_bps, 'provider_execution_enabled', v_control.production_compensation_execution_enabled));
  return jsonb_build_object('ok', true, 'replayed', false, 'cancellation', to_jsonb(v_record), 'money_moved', false, 'human_review_required', v_obligation.id is not null);
end;
$$;

revoke all on function public.request_adult_job_cancellation(uuid,text,uuid) from public, anon;
grant execute on function public.request_adult_job_cancellation(uuid,text,uuid) to authenticated, service_role;
