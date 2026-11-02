-- Read execution progress from the live job_assignments model. The historic
-- execution RPCs target a removed public.applications schema and are not safe
-- to replay against production.
create or replace function public.get_job_execution_status(p_application_id uuid)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_assignment public.job_assignments%rowtype;
  v_contract public.job_contracts%rowtype;
  v_payment_status text;
  v_state text;
  v_contract_ready boolean := false;
  v_safety_ready boolean := false;
  v_live_payment_enabled boolean := false;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.' using errcode = '28000';
  end if;

  select assignment.*
    into v_assignment
    from public.job_assignments as assignment
   where assignment.application_id = p_application_id
     and v_user_id in (assignment.teen_user_id, assignment.adult_user_id);

  if not found then
    raise exception 'Job participant required.' using errcode = '42501';
  end if;

  select contract.*
    into v_contract
    from public.job_contracts as contract
   where contract.application_id = p_application_id
     and v_user_id in (contract.teen_id, contract.adult_id);

  if not found then
    raise exception 'The accepted job agreement is unavailable.' using errcode = 'P0002';
  end if;

  select payment.status
    into v_payment_status
    from public.payment_records as payment
   where payment.assignment_id = v_assignment.id
     and v_user_id in (payment.payer_id, payment.payee_id)
   order by payment.updated_at desc, payment.created_at desc
   limit 1;

  select count(*) = 2
    into v_contract_ready
    from public.job_contract_acceptances as acceptance
   where acceptance.contract_id = v_contract.id
     and acceptance.contract_version_id = v_contract.active_version_id
     and acceptance.content_hash = (
       select version.content_hash
         from public.job_contract_versions as version
        where version.id = v_contract.active_version_id
          and version.contract_id = v_contract.id
          and version.status = 'active'
     )
     and acceptance.affirmative_checkbox;

  select agreement.status = 'confirmed'
         and agreement.teen_confirmed_version = agreement.agreement_version
         and agreement.adult_confirmed_version = agreement.agreement_version
    into v_safety_ready
    from public.job_safety_agreements as agreement
   where agreement.application_id = p_application_id
     and agreement.teen_id = v_assignment.teen_user_id
     and agreement.adult_id = v_assignment.adult_user_id
   order by agreement.updated_at desc
   limit 1;
  v_safety_ready := coalesce(v_safety_ready, false);

  v_state := case
    when v_assignment.status = 'awaiting_confirmation' then 'completion_pending_release'
    when v_assignment.status = 'completed' then 'completed'
    when v_assignment.status = 'cancelled' then 'cancelled'
    when v_assignment.status = 'disputed' then 'disputed'
    when v_assignment.status = 'in_progress' then 'in_progress'
    else 'awaiting_start'
  end;

  v_live_payment_enabled := coalesce(
    not ((public.get_runtime_feature_status() ->> 'payments_disabled')::boolean),
    false
  );

  return pg_catalog.jsonb_build_object(
    'ok', true,
    'application_id', v_assignment.application_id,
    'job_id', v_assignment.job_id,
    'contract_id', v_contract.id,
    'role', case when v_user_id = v_assignment.teen_user_id then 'teen' else 'adult' end,
    'state', v_state,
    'funding_status', case when v_payment_status = 'succeeded' then 'funded'
                           else coalesce(v_payment_status, 'missing') end,
    'start_pin_active', false,
    'finish_pin_active', false,
    'live_payment_enabled', v_live_payment_enabled,
    'start_pin_expires_at', null,
    'finish_pin_expires_at', null,
    'started_at', v_assignment.started_at,
    'completion_pending_at', coalesce(
      v_assignment.completed_by_teen_at,
      v_assignment.completed_by_adult_at
    ),
    'review_window_ends_at', null,
    'contract_ready', coalesce(v_contract_ready, false),
    'safety_ready', v_safety_ready,
    'execution_actions_enabled', false,
    'execution_actions_reason', 'execution_backend_incomplete'
  );
end;
$function$;

revoke all on function public.get_job_execution_status(uuid)
  from public, anon;
grant execute on function public.get_job_execution_status(uuid)
  to authenticated;

