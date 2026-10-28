-- Run after the additive Stripe foundation migration.
-- This contract intentionally checks fail-closed production defaults and
-- service-only persistence; it contains no fabricated customer/payment rows.
do $$
declare
  controls private.stripe_runtime_controls%rowtype;
  function_acl text;
begin
  if to_regclass('private.stripe_runtime_controls') is null
    or to_regclass('private.stripe_customers') is null
    or to_regclass('private.stripe_connected_accounts') is null
    or to_regclass('private.stripe_payment_intents') is null
    or to_regclass('private.stripe_webhook_events') is null then
    raise exception 'stripe_foundation_tables_missing';
  end if;

  select * into strict controls
  from private.stripe_runtime_controls
  where singleton;

  if controls.mode <> 'disabled'
    or controls.payments_enabled
    or controls.connected_onboarding_enabled
    or controls.job_funding_enabled
    or controls.transfers_enabled
    or controls.refunds_enabled
    or controls.live_mode_enabled then
    raise exception 'stripe_runtime_must_start_disabled';
  end if;

  if (select relrowsecurity from pg_class where oid='private.stripe_customers'::regclass) is not true
    or (select relrowsecurity from pg_class where oid='private.stripe_connected_accounts'::regclass) is not true
    or (select relrowsecurity from pg_class where oid='private.stripe_payment_intents'::regclass) is not true
    or (select relrowsecurity from pg_class where oid='private.stripe_webhook_events'::regclass) is not true then
    raise exception 'stripe_private_tables_rls_required';
  end if;

  select pg_get_functiondef('public.get_stripe_runtime_status()'::regprocedure)
  into function_acl;
  if position('configured' in function_acl) = 0 then
    raise exception 'stripe_runtime_status_contract_missing';
  end if;
end;
$$;
