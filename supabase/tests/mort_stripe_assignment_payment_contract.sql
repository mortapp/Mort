-- Stripe's assignment payment path is service-only and fail-closed by default.
do $$
declare
  controls private.stripe_runtime_controls%rowtype;
begin
  if to_regclass('private.mort_edge_action_limits') is null then
    raise exception 'edge_action_limit_table_missing';
  end if;
  if to_regprocedure('public.consume_my_edge_action_limit(text)') is null
    or to_regprocedure('public.stripe_server_prepare_assignment_payment(uuid,uuid)') is null
    or to_regprocedure('public.stripe_server_record_assignment_payment_intent(uuid,text,text,timestamptz)') is null then
    raise exception 'stripe_assignment_payment_rpc_missing';
  end if;
  if has_function_privilege('authenticated', 'public.stripe_server_prepare_assignment_payment(uuid,uuid)', 'EXECUTE')
    or has_function_privilege('authenticated', 'public.stripe_server_record_assignment_payment_intent(uuid,text,text,timestamptz)', 'EXECUTE') then
    raise exception 'stripe_assignment_service_rpc_exposed';
  end if;
  if not has_function_privilege('authenticated', 'public.consume_my_edge_action_limit(text)', 'EXECUTE') then
    raise exception 'edge_action_limit_rpc_not_granted';
  end if;
  if (select relrowsecurity from pg_class where oid='private.mort_edge_action_limits'::regclass) is not true then
    raise exception 'edge_action_limits_rls_required';
  end if;
  select * into strict controls from private.stripe_runtime_controls where singleton;
  if controls.mode <> 'disabled' or controls.payments_enabled or controls.job_funding_enabled
    or controls.transfers_enabled or controls.refunds_enabled or controls.live_mode_enabled then
    raise exception 'stripe_must_remain_disabled_until_external_gates_pass';
  end if;
end;
$$;
