-- Assignment payment state is visible only to its authenticated payer/payee.
do $$
begin
  if to_regprocedure('public.get_my_assignment_payment_status(text)') is null
    or to_regprocedure('public.stripe_server_apply_assignment_payment_webhook(text,text,uuid,uuid,text,text,integer,text,timestamptz)') is null then
    raise exception 'stripe_assignment_status_rpc_missing';
  end if;
  if has_function_privilege('anon', 'public.get_my_assignment_payment_status(text)', 'EXECUTE') then
    raise exception 'anonymous_payment_status_exposed';
  end if;
  if has_function_privilege('authenticated', 'public.stripe_server_apply_assignment_payment_webhook(text,text,uuid,uuid,text,text,integer,text,timestamptz)', 'EXECUTE') then
    raise exception 'stripe_webhook_mutation_exposed';
  end if;
  if position('auth.uid() in (payer_id, payee_id)' in
    pg_get_functiondef('public.get_my_assignment_payment_status(text)'::regprocedure)) = 0 then
    raise exception 'payment_status_participant_guard_missing';
  end if;
end;
$$;
