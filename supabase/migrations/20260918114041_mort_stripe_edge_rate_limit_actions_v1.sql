-- Register rate-limit actions for Edge routes added after the original Stripe
-- policy/funding migration. Keep the historical migration immutable.

create or replace function public.consume_my_edge_action_limit(p_action text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_action text := lower(btrim(coalesce(p_action, '')));
  v_limit integer;
  v_window_seconds integer;
  v_count integer;
begin
  if v_user_id is null then return false; end if;
  select limits.maximum, limits.window_seconds
  into v_limit, v_window_seconds
  from (
    values
      ('stripe_connected_account_create'::text, 3, 3600),
      ('stripe_job_payment_intent'::text, 10, 3600),
      ('stripe_job_payment_status'::text, 60, 3600),
      ('stripe_job_funding_quote'::text, 20, 3600),
      ('stripe_financial_document'::text, 60, 3600),
      ('stripe_financial_history'::text, 60, 3600),
      ('stripe_job_resolution'::text, 20, 3600),
      ('stripe_connected_account_status'::text, 20, 3600),
      ('stripe_onboarding_link'::text, 5, 3600),
      ('ai_safety_scan'::text, 60, 3600)
  ) as limits(action, maximum, window_seconds)
  where limits.action = v_action;
  if v_limit is null then return false; end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_user_id::text || ':' || v_action, 0)
  );
  select count(*)::integer into v_count
  from public.rate_limit_events event
  where event.user_id = v_user_id
    and event.action = v_action
    and event.created_at >= statement_timestamp()
      - pg_catalog.make_interval(secs => v_window_seconds);
  if v_count >= v_limit then return false; end if;
  insert into public.rate_limit_events (user_id, action, ip_address)
  values (v_user_id, v_action, null);
  insert into public.user_action_counters (user_id, action, count, last_action_at)
  values (v_user_id, v_action, 1, statement_timestamp())
  on conflict (user_id, action) do update
  set count = public.user_action_counters.count + 1,
      last_action_at = excluded.last_action_at,
      updated_at = statement_timestamp();
  return true;
end;
$$;
