-- Synthetic provider-state regression only. No store purchases or lasting grants.
begin;
set local statement_timeout = '30s';

create function pg_temp.grace_event(
  uid uuid, kind text, product text, until_at timestamptz,
  occurred_at timestamptz, grace_at timestamptz default null
) returns jsonb language sql as $$
  select public.process_revenuecat_provider_event(
    'qa_grace_' || gen_random_uuid()::text, uid, kind, product, '{}', until_at,
    occurred_at, repeat('c', 64), jsonb_build_object('event', jsonb_build_object(
      'store', 'PLAY_STORE', 'grace_period_expiration_at_ms',
      case when grace_at is null then null else floor(extract(epoch from grace_at) * 1000) end
    )));
$$;

do $$
declare
  uid uuid := gen_random_uuid();
  clock_at timestamptz := date_trunc('milliseconds', now());
  paid_at timestamptz := clock_at - interval '1 minute';
  grace_at timestamptz := clock_at + interval '1 day';
  recovered_at timestamptz := clock_at + interval '1 month';
  result jsonb;
  flags record;
  state record;
begin
  insert into auth.users(id, aud, role, email, raw_app_meta_data, raw_user_meta_data)
  values(uid, 'authenticated', 'authenticated', 'qa-grace-' || uid || '@example.invalid',
    '{}', '{"display_name":"Synthetic Grace QA"}');
  update public.profiles set is_test_account = true, role = 'adult' where id = uid;
  perform set_config('request.jwt.claim.sub', uid::text, true);

  perform pg_temp.grace_event(uid, 'initial_purchase', 'mort_pro:monthly', paid_at,
    clock_at - interval '1 hour');
  select * into flags from public.get_my_entitlements();
  if flags.premium_active then raise exception 'Expired paid period retained access'; end if;
  result := pg_temp.grace_event(uid, 'billing_issue', 'mort_pro:monthly', grace_at,
    clock_at, grace_at);
  select * into flags from public.get_my_entitlements();
  if not flags.premium_active or not ('mort_pro' = any(flags.entitlements)) then
    raise exception 'Provider-confirmed grace did not retain Pro';
  end if;
  if not (result->>'state_changed')::boolean then raise exception 'Grace state did not update'; end if;

  perform pg_temp.grace_event(uid, 'cancellation', 'mort_pro:monthly', paid_at,
    clock_at + interval '1 second');
  select * into flags from public.get_my_entitlements();
  if not flags.premium_active then raise exception 'Cancellation removed grace'; end if;

  perform pg_temp.grace_event(uid, 'billing_issue', 'mort_pro:monthly', recovered_at,
    clock_at - interval '1 second', recovered_at);
  select * into state from public.revenuecat_product_states where user_id = uid and product_id = 'mort_pro:monthly';
  if state.active_until <> grace_at then raise exception 'Stale billing issue changed grace'; end if;

  perform pg_temp.grace_event(uid, 'renewal', 'mort_pro:monthly', recovered_at,
    clock_at + interval '2 seconds');
  select * into state from public.revenuecat_product_states where user_id = uid and product_id = 'mort_pro:monthly';
  if state.active_until <> recovered_at then raise exception 'Recovery did not use renewal period'; end if;

  -- Missing/mismatched/non-numeric provider grace must never extend a paid period.
  perform pg_temp.grace_event(uid, 'billing_issue', 'mort_pro:monthly', recovered_at + interval '1 month', clock_at + interval '3 seconds');
  perform pg_temp.grace_event(uid, 'billing_issue', 'mort_pro:monthly', recovered_at + interval '1 month', clock_at + interval '4 seconds', grace_at);
  perform public.process_revenuecat_provider_event('qa_grace_' || gen_random_uuid(), uid,
    'billing_issue', 'mort_pro:monthly', '{}', recovered_at + interval '1 month',
    clock_at + interval '5 seconds', repeat('d',64),
    '{"event":{"grace_period_expiration_at_ms":"invalid"}}');
  select * into state from public.revenuecat_product_states where user_id = uid and product_id = 'mort_pro:monthly';
  if state.active_until <> recovered_at then raise exception 'Unconfirmed grace extended access'; end if;

  perform pg_temp.grace_event(uid, 'revocation', 'mort_pro:monthly', null, clock_at + interval '6 seconds');
  perform pg_temp.grace_event(uid, 'billing_issue', 'mort_pro:monthly', recovered_at, clock_at + interval '7 seconds', recovered_at);
  perform pg_temp.grace_event(uid, 'billing_issue', 'mort_pro:annual', recovered_at, clock_at + interval '8 seconds', recovered_at);
  select * into flags from public.get_my_entitlements();
  if flags.premium_active then raise exception 'Grace resurrected revoked or absent subscription'; end if;
  if exists(select 1 from public.revenuecat_product_states where user_id = uid and product_id = 'mort_pro:annual') then
    raise exception 'Grace created a new subscription';
  end if;

  perform pg_temp.grace_event(uid, 'initial_purchase', 'mort_plus_monthly', paid_at, clock_at);
  perform pg_temp.grace_event(uid, 'billing_issue', 'mort_plus_monthly', grace_at, clock_at + interval '9 seconds', grace_at);
  select * into flags from public.get_my_entitlements();
  if not ('mort_plus' = any(flags.entitlements)) or 'mort_pro' = any(flags.entitlements) or flags.adult_pro_active then
    raise exception 'Plus grace was lost or granted Pro';
  end if;
  -- Time passing without any expiration webhook still ends grace access.
  update public.revenuecat_product_states set active_until = clock_at - interval '1 second' where user_id = uid;
  select * into flags from public.get_my_entitlements();
  if flags.premium_active then raise exception 'Expired grace retained access through stale cache'; end if;
  perform pg_temp.grace_event(uid, 'expiration', 'mort_plus_monthly', null, clock_at + interval '10 seconds');
  perform pg_temp.grace_event(uid, 'billing_issue', 'mort_plus_monthly', grace_at, clock_at + interval '11 seconds', grace_at);
  select * into flags from public.get_my_entitlements();
  if flags.premium_active then raise exception 'Grace resurrected an expired product'; end if;

  perform pg_temp.grace_event(uid, 'non_renewing_purchase', 'lifetime', null, clock_at);
  perform pg_temp.grace_event(uid, 'billing_issue', 'lifetime', grace_at, clock_at + interval '12 seconds', grace_at);
  select * into state from public.revenuecat_product_states where user_id = uid and product_id = 'lifetime';
  if not state.active or state.active_until is not null then raise exception 'Lifetime acquired finite grace expiry'; end if;

  if has_function_privilege('authenticated', 'public.process_revenuecat_provider_event(text,uuid,text,text,text[],timestamptz,timestamptz,text,jsonb)', 'EXECUTE')
    or has_function_privilege('anon', 'public.process_revenuecat_provider_event(text,uuid,text,text,text[],timestamptz,timestamptz,text,jsonb)', 'EXECUTE') then
    raise exception 'Client can call provider writer';
  end if;
end;
$$;
select 'PASS: provider grace, cancellation, stale events, recovery, invalid grace, revocation, Plus isolation, expiry, lifetime and privileges' as grace_regression;
rollback;
