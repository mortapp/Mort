-- BP-02: versioned sandbox financial policy and immutable pre-work funding
-- quote foundation. This migration performs no provider operation and leaves
-- every existing Stripe runtime/money-movement control unchanged.

create table private.stripe_financial_policy_versions (
  id uuid primary key default gen_random_uuid(),
  environment text not null check (environment in ('test', 'live')),
  policy_kind text not null check (policy_kind in (
    'service_fee', 'fair_pay', 'tip', 'cancellation', 'partial_compensation'
  )),
  scope_key text not null default 'global'
    check (char_length(btrim(scope_key)) between 1 and 120),
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  version text not null check (char_length(btrim(version)) between 1 and 80),
  effective_at timestamptz not null,
  expires_at timestamptz,
  active boolean not null default false,
  retired_at timestamptz,

  service_fee_bps integer,
  service_fee_min_cents integer,
  service_fee_max_cents integer,
  quote_ttl_seconds integer,

  recommended_min_cents integer,
  recommended_max_cents integer,
  hard_minimum_cents integer,
  yellow_may_continue boolean,

  tip_min_cents integer,
  tip_max_cents integer,
  late_tip_window_seconds integer,
  tip_teen_share_bps integer,
  tip_mort_fee_bps integer,
  tip_excluded_from_fair_pay boolean,

  configuration jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default statement_timestamp(),

  constraint stripe_financial_policy_window_check check (
    expires_at is null or expires_at > effective_at
  ),
  constraint stripe_financial_policy_retirement_check check (
    (active and retired_at is null) or not active
  ),
  constraint stripe_financial_policy_configuration_object_check check (
    jsonb_typeof(configuration) = 'object'
  ),
  constraint stripe_financial_policy_kind_fields_check check (
    (
      policy_kind = 'service_fee'
      and service_fee_bps between 0 and 10000
      and service_fee_min_cents >= 0
      and service_fee_max_cents >= service_fee_min_cents
      and quote_ttl_seconds between 1 and 86400
      and recommended_min_cents is null and recommended_max_cents is null
      and hard_minimum_cents is null and yellow_may_continue is null
      and tip_min_cents is null and tip_max_cents is null
      and late_tip_window_seconds is null and tip_teen_share_bps is null
      and tip_mort_fee_bps is null and tip_excluded_from_fair_pay is null
      and configuration = '{}'::jsonb
    ) or (
      policy_kind = 'fair_pay'
      and hard_minimum_cents >= 0
      and recommended_min_cents >= hard_minimum_cents
      and recommended_max_cents >= recommended_min_cents
      and yellow_may_continue is not null
      and service_fee_bps is null and service_fee_min_cents is null
      and service_fee_max_cents is null and quote_ttl_seconds is null
      and tip_min_cents is null and tip_max_cents is null
      and late_tip_window_seconds is null and tip_teen_share_bps is null
      and tip_mort_fee_bps is null and tip_excluded_from_fair_pay is null
      and configuration = '{}'::jsonb
    ) or (
      policy_kind = 'tip'
      and tip_min_cents >= 0
      and tip_max_cents >= tip_min_cents
      and late_tip_window_seconds > 0
      and tip_teen_share_bps = 10000
      and tip_mort_fee_bps = 0
      and tip_excluded_from_fair_pay
      and service_fee_bps is null and service_fee_min_cents is null
      and service_fee_max_cents is null and quote_ttl_seconds is null
      and recommended_min_cents is null and recommended_max_cents is null
      and hard_minimum_cents is null and yellow_may_continue is null
      and configuration = '{}'::jsonb
    ) or (
      policy_kind in ('cancellation', 'partial_compensation')
      and jsonb_typeof(configuration->'rules') = 'array'
      and jsonb_array_length(configuration->'rules') > 0
      and service_fee_bps is null and service_fee_min_cents is null
      and service_fee_max_cents is null and quote_ttl_seconds is null
      and recommended_min_cents is null and recommended_max_cents is null
      and hard_minimum_cents is null and yellow_may_continue is null
      and tip_min_cents is null and tip_max_cents is null
      and late_tip_window_seconds is null and tip_teen_share_bps is null
      and tip_mort_fee_bps is null and tip_excluded_from_fair_pay is null
    )
  ),
  unique (environment, policy_kind, currency_code, scope_key, version)
);

create unique index stripe_financial_policy_one_active_scope_idx
on private.stripe_financial_policy_versions (
  environment, policy_kind, currency_code, scope_key
)
where active;

create index stripe_financial_policy_effective_lookup_idx
on private.stripe_financial_policy_versions (
  environment, policy_kind, currency_code, scope_key, effective_at desc
)
where active;

create or replace function private.enforce_financial_policy_version_immutability_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'financial_policy_versions_are_append_only';
  end if;

  if (to_jsonb(new) - array['active', 'retired_at']::text[])
      is distinct from
     (to_jsonb(old) - array['active', 'retired_at']::text[]) then
    raise exception 'financial_policy_version_is_immutable';
  end if;

  if old.active and not new.active and old.retired_at is null and new.retired_at is not null then
    return new;
  end if;
  if not old.active and new.active and old.retired_at is null and new.retired_at is null then
    return new;
  end if;
  if old.active = new.active and old.retired_at is not distinct from new.retired_at then
    return new;
  end if;

  raise exception 'invalid_financial_policy_lifecycle_transition';
end;
$$;

create trigger stripe_financial_policy_immutable
before update or delete on private.stripe_financial_policy_versions
for each row execute function private.enforce_financial_policy_version_immutability_v1();

create or replace function private.resolve_financial_policy_v1(
  p_environment text,
  p_policy_kind text,
  p_currency_code text,
  p_scope_key text,
  p_at timestamptz default statement_timestamp()
)
returns setof private.stripe_financial_policy_versions
language sql
stable
security definer
set search_path = ''
as $$
  select policy.*
  from private.stripe_financial_policy_versions policy
  where policy.environment = p_environment
    and policy.policy_kind = p_policy_kind
    and policy.currency_code = upper(p_currency_code)
    and policy.scope_key = p_scope_key
    and policy.active
    and policy.effective_at <= p_at
    and (policy.expires_at is null or p_at < policy.expires_at)
  order by policy.effective_at desc, policy.created_at desc
  limit 1
$$;

create or replace function private.calculate_mort_service_fee_v1(
  p_base_cents integer,
  p_policy_id uuid
)
returns integer
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_policy private.stripe_financial_policy_versions%rowtype;
  v_percentage bigint;
begin
  if p_base_cents is null or p_base_cents < 0 then
    raise exception 'invalid_compensated_base_cents';
  end if;
  select * into v_policy
  from private.stripe_financial_policy_versions
  where id = p_policy_id and policy_kind = 'service_fee';
  if v_policy.id is null then
    raise exception 'service_fee_policy_missing';
  end if;
  if p_base_cents = 0 then
    return 0;
  end if;
  v_percentage := ((p_base_cents::bigint * v_policy.service_fee_bps::bigint) + 5000) / 10000;
  return greatest(
    v_policy.service_fee_min_cents,
    least(v_percentage::integer, v_policy.service_fee_max_cents)
  );
end;
$$;

create or replace function private.evaluate_fair_pay_v1(
  p_base_cents integer,
  p_environment text,
  p_currency_code text,
  p_scope_key text,
  p_at timestamptz default statement_timestamp()
)
returns table (
  policy_version_id uuid,
  policy_version text,
  decision text,
  may_continue boolean,
  recommended_min_cents integer,
  recommended_max_cents integer,
  hard_minimum_cents integer
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_policy private.stripe_financial_policy_versions%rowtype;
begin
  if p_base_cents is null or p_base_cents < 0 then
    raise exception 'invalid_fair_pay_base_cents';
  end if;
  select * into v_policy
  from private.resolve_financial_policy_v1(
    p_environment, 'fair_pay', upper(p_currency_code), p_scope_key, p_at
  );
  if v_policy.id is null then
    raise exception 'fair_pay_policy_missing';
  end if;

  policy_version_id := v_policy.id;
  policy_version := v_policy.version;
  recommended_min_cents := v_policy.recommended_min_cents;
  recommended_max_cents := v_policy.recommended_max_cents;
  hard_minimum_cents := v_policy.hard_minimum_cents;
  if p_base_cents >= v_policy.recommended_min_cents then
    decision := 'GREEN';
    may_continue := true;
  elsif p_base_cents >= v_policy.hard_minimum_cents then
    decision := 'YELLOW';
    may_continue := v_policy.yellow_may_continue;
  else
    decision := 'RED';
    may_continue := false;
  end if;
  return next;
end;
$$;

create or replace function private.evaluate_tip_policy_v1(
  p_tip_cents integer,
  p_environment text,
  p_currency_code text,
  p_scope_key text default 'global',
  p_at timestamptz default statement_timestamp()
)
returns table (
  policy_version_id uuid,
  policy_version text,
  may_continue boolean,
  outcome_code text,
  teen_share_cents integer,
  mort_fee_cents integer,
  excluded_from_fair_pay boolean,
  late_tip_window_seconds integer
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_policy private.stripe_financial_policy_versions%rowtype;
begin
  if p_tip_cents is null or p_tip_cents < 0 then
    raise exception 'invalid_tip_cents';
  end if;
  select * into v_policy
  from private.resolve_financial_policy_v1(
    p_environment, 'tip', upper(p_currency_code), p_scope_key, p_at
  );
  if v_policy.id is null then
    raise exception 'tip_policy_missing';
  end if;

  policy_version_id := v_policy.id;
  policy_version := v_policy.version;
  excluded_from_fair_pay := v_policy.tip_excluded_from_fair_pay;
  late_tip_window_seconds := v_policy.late_tip_window_seconds;
  mort_fee_cents := 0;
  if p_tip_cents < v_policy.tip_min_cents then
    may_continue := false;
    outcome_code := 'TIP_BELOW_MINIMUM';
    teen_share_cents := 0;
  elsif p_tip_cents > v_policy.tip_max_cents then
    may_continue := false;
    outcome_code := 'TIP_ABOVE_MAXIMUM';
    teen_share_cents := 0;
  else
    may_continue := true;
    outcome_code := 'TIP_ALLOWED';
    teen_share_cents := p_tip_cents;
  end if;
  return next;
end;
$$;

create or replace function private.evaluate_compensation_policy_v1(
  p_policy_kind text,
  p_environment text,
  p_currency_code text,
  p_scope_key text,
  p_outcome_code text,
  p_funded_base_cents integer,
  p_authoritative_facts jsonb,
  p_at timestamptz default statement_timestamp()
)
returns table (
  policy_version_id uuid,
  outcome_code text,
  compensated_base_cents integer,
  explanation_code text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_policy private.stripe_financial_policy_versions%rowtype;
  v_rule jsonb;
  v_match_count integer;
  v_award_kind text;
  v_award_value integer;
begin
  if p_policy_kind not in ('cancellation', 'partial_compensation') then
    raise exception 'invalid_compensation_policy_kind';
  end if;
  if p_funded_base_cents is null or p_funded_base_cents < 0 then
    raise exception 'invalid_funded_base_cents';
  end if;
  if jsonb_typeof(coalesce(p_authoritative_facts, '{}'::jsonb)) <> 'object' then
    raise exception 'invalid_authoritative_facts';
  end if;

  select * into v_policy
  from private.resolve_financial_policy_v1(
    p_environment, p_policy_kind, upper(p_currency_code), p_scope_key, p_at
  );
  if v_policy.id is null then
    raise exception '%_policy_missing', p_policy_kind;
  end if;

  select count(*)::integer
  into v_match_count
  from jsonb_array_elements(v_policy.configuration->'rules') rule(value)
  where rule.value->>'outcome_code' = p_outcome_code
    and coalesce(p_authoritative_facts, '{}'::jsonb)
      @> coalesce(rule.value->'required_facts', '{}'::jsonb);

  if v_match_count = 0 then
    raise exception 'compensation_policy_no_matching_rule';
  end if;
  if v_match_count > 1 then
    raise exception 'compensation_policy_ambiguous_rule';
  end if;

  select rule.value into v_rule
  from jsonb_array_elements(v_policy.configuration->'rules') rule(value)
  where rule.value->>'outcome_code' = p_outcome_code
    and coalesce(p_authoritative_facts, '{}'::jsonb)
      @> coalesce(rule.value->'required_facts', '{}'::jsonb)
  limit 1;

  v_award_kind := v_rule#>>'{award,kind}';
  begin
    v_award_value := (v_rule#>>'{award,value}')::integer;
  exception when others then
    raise exception 'invalid_compensation_award';
  end;
  if v_award_value < 0 then
    raise exception 'invalid_compensation_award';
  end if;

  if v_award_kind = 'basis_points' and v_award_value <= 10000 then
    compensated_base_cents := ((p_funded_base_cents::bigint * v_award_value::bigint + 5000) / 10000)::integer;
  elsif v_award_kind = 'fixed_cents' then
    compensated_base_cents := v_award_value;
  else
    raise exception 'invalid_compensation_award';
  end if;
  compensated_base_cents := greatest(0, least(compensated_base_cents, p_funded_base_cents));
  policy_version_id := v_policy.id;
  outcome_code := p_outcome_code;
  explanation_code := v_rule->>'explanation_code';
  if explanation_code is null or explanation_code = '' then
    raise exception 'compensation_explanation_required';
  end if;
  return next;
end;
$$;

create or replace function private.evaluate_cancellation_v1(
  p_environment text,
  p_currency_code text,
  p_scope_key text,
  p_outcome_code text,
  p_funded_base_cents integer,
  p_authoritative_facts jsonb,
  p_at timestamptz default statement_timestamp()
)
returns table (
  policy_version_id uuid,
  outcome_code text,
  compensated_base_cents integer,
  explanation_code text
)
language sql
stable
security definer
set search_path = ''
as $$
  select * from private.evaluate_compensation_policy_v1(
    'cancellation', p_environment, p_currency_code, p_scope_key,
    p_outcome_code, p_funded_base_cents, p_authoritative_facts, p_at
  )
$$;

create or replace function private.evaluate_partial_compensation_v1(
  p_environment text,
  p_currency_code text,
  p_scope_key text,
  p_outcome_code text,
  p_funded_base_cents integer,
  p_authoritative_facts jsonb,
  p_at timestamptz default statement_timestamp()
)
returns table (
  policy_version_id uuid,
  outcome_code text,
  compensated_base_cents integer,
  explanation_code text
)
language sql
stable
security definer
set search_path = ''
as $$
  select * from private.evaluate_compensation_policy_v1(
    'partial_compensation', p_environment, p_currency_code, p_scope_key,
    p_outcome_code, p_funded_base_cents, p_authoritative_facts, p_at
  )
$$;

create or replace function public.stripe_server_activate_financial_policy_v1(p_policy_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_policy private.stripe_financial_policy_versions%rowtype;
  v_control private.stripe_runtime_controls%rowtype;
begin
  perform private.require_stripe_service_role();
  select * into v_policy
  from private.stripe_financial_policy_versions
  where id = p_policy_id for update;
  if v_policy.id is null then raise exception 'financial_policy_not_found'; end if;
  if v_policy.active then
    return jsonb_build_object('ok', true, 'policy_version_id', v_policy.id, 'idempotent', true);
  end if;
  if v_policy.retired_at is not null then raise exception 'retired_financial_policy_cannot_reactivate'; end if;
  if v_policy.expires_at is not null and v_policy.expires_at <= statement_timestamp() then
    raise exception 'expired_financial_policy_cannot_activate';
  end if;
  if v_policy.environment = 'live' then
    select * into v_control from private.stripe_runtime_controls where singleton for share;
    if not v_control.stripe_live_mode_enabled or not v_control.live_owner_approved then
      raise exception 'production_financial_policy_not_approved';
    end if;
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    v_policy.environment || ':' || v_policy.policy_kind || ':' ||
    v_policy.currency_code || ':' || v_policy.scope_key, 0
  ));
  update private.stripe_financial_policy_versions
  set active = false, retired_at = statement_timestamp()
  where environment = v_policy.environment
    and policy_kind = v_policy.policy_kind
    and currency_code = v_policy.currency_code
    and scope_key = v_policy.scope_key
    and active;
  update private.stripe_financial_policy_versions
  set active = true
  where id = v_policy.id;
  return jsonb_build_object('ok', true, 'policy_version_id', v_policy.id, 'idempotent', false);
end;
$$;

insert into private.stripe_financial_policy_versions (
  environment, policy_kind, scope_key, currency_code, version,
  effective_at, active, service_fee_bps, service_fee_min_cents,
  service_fee_max_cents, quote_ttl_seconds
) values (
  'test', 'service_fee', 'global', 'USD', 'sandbox-2026-09-16-v1',
  '2026-09-16T00:00:00Z', true, 800, 100, 500, 900
);

create table private.stripe_job_funding_quotes (
  id uuid primary key default gen_random_uuid(),
  environment text not null check (environment in ('test', 'live')),
  payer_id uuid not null references auth.users(id) on delete restrict,
  worker_id uuid not null references auth.users(id) on delete restrict,
  job_id uuid not null references public.jobs(id) on delete restrict,
  contract_id uuid not null references public.job_contracts(id) on delete restrict,
  contract_version_id uuid not null references public.job_contract_versions(id) on delete restrict,
  obligation_id uuid not null references public.job_payment_obligations(id) on delete restrict,
  base_pay_cents integer not null check (base_pay_cents > 0),
  service_fee_cents integer not null check (service_fee_cents >= 0),
  authoritative_total_cents integer not null,
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  financial_policy_version_id uuid not null
    references private.stripe_financial_policy_versions(id) on delete restrict,
  fair_pay_policy_version_id uuid not null
    references private.stripe_financial_policy_versions(id) on delete restrict,
  fair_pay_decision text not null check (fair_pay_decision in ('GREEN', 'YELLOW')),
  connected_account_id uuid
    references private.stripe_connected_accounts(id) on delete restrict,
  connected_account_readiness text not null check (connected_account_readiness in (
    'NOT_STARTED', 'PENDING', 'ACTION_REQUIRED', 'RESTRICTED', 'READY_FOR_TRANSFER'
  )),
  payment_eligibility boolean not null,
  provider_availability text not null default 'NOT_CHECKED'
    check (provider_availability in ('NOT_CHECKED', 'AVAILABLE', 'UNAVAILABLE')),
  request_id uuid not null,
  request_payload_sha256 text not null check (request_payload_sha256 ~ '^[a-f0-9]{64}$'),
  state text not null default 'ACTIVE'
    check (state in ('ACTIVE', 'CONSUMED', 'SUPERSEDED', 'EXPIRED')),
  consumed_request_id uuid,
  created_at timestamptz not null,
  expires_at timestamptz not null,
  consumed_at timestamptz,
  superseded_at timestamptz,
  expired_at timestamptz,
  superseded_by_quote_id uuid
    references private.stripe_job_funding_quotes(id) on delete restrict,
  constraint stripe_job_funding_quote_amount_check check (
    authoritative_total_cents = base_pay_cents + service_fee_cents
    and authoritative_total_cents > 0
  ),
  constraint stripe_job_funding_quote_party_check check (payer_id <> worker_id),
  constraint stripe_job_funding_quote_expiry_check check (expires_at > created_at),
  constraint stripe_job_funding_quote_lifecycle_check check (
    (state = 'ACTIVE' and consumed_at is null and consumed_request_id is null
      and superseded_at is null and expired_at is null and superseded_by_quote_id is null)
    or (state = 'CONSUMED' and consumed_at is not null and consumed_request_id is not null
      and consumed_at < expires_at and superseded_at is null and expired_at is null
      and superseded_by_quote_id is null)
    or (state = 'SUPERSEDED' and superseded_at is not null and consumed_at is null
      and consumed_request_id is null and expired_at is null)
    or (state = 'EXPIRED' and expired_at is not null and consumed_at is null
      and consumed_request_id is null and superseded_at is null
      and superseded_by_quote_id is null)
  ),
  unique (environment, payer_id, request_id)
);

create unique index stripe_job_funding_quote_one_active_idx
on private.stripe_job_funding_quotes (environment, payer_id, contract_version_id)
where state = 'ACTIVE';

create index stripe_job_funding_quotes_worker_idx
on private.stripe_job_funding_quotes (worker_id, created_at desc);
create index stripe_job_funding_quotes_job_idx
on private.stripe_job_funding_quotes (job_id, created_at desc);
create index stripe_job_funding_quotes_contract_idx
on private.stripe_job_funding_quotes (contract_id, created_at desc);
create index stripe_job_funding_quotes_obligation_idx
on private.stripe_job_funding_quotes (obligation_id, created_at desc);
create index stripe_job_funding_quotes_financial_policy_idx
on private.stripe_job_funding_quotes (financial_policy_version_id);
create index stripe_job_funding_quotes_fair_pay_policy_idx
on private.stripe_job_funding_quotes (fair_pay_policy_version_id);
create index stripe_job_funding_quotes_connected_account_idx
on private.stripe_job_funding_quotes (connected_account_id)
where connected_account_id is not null;
create index stripe_job_funding_quotes_superseded_by_idx
on private.stripe_job_funding_quotes (superseded_by_quote_id)
where superseded_by_quote_id is not null;

create or replace function private.funding_quote_is_usable_v1(
  p_state text,
  p_expires_at timestamptz,
  p_at timestamptz
)
returns boolean
language sql
immutable
strict
set search_path = ''
as $$
  select p_state = 'ACTIVE' and p_at < p_expires_at
$$;

create or replace function private.enforce_job_funding_quote_immutability_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'job_funding_quotes_are_immutable';
  end if;
  if (to_jsonb(new) - array[
        'state', 'consumed_request_id', 'consumed_at', 'superseded_at',
        'expired_at', 'superseded_by_quote_id'
      ]::text[])
      is distinct from
     (to_jsonb(old) - array[
        'state', 'consumed_request_id', 'consumed_at', 'superseded_at',
        'expired_at', 'superseded_by_quote_id'
      ]::text[]) then
    raise exception 'job_funding_quote_snapshot_is_immutable';
  end if;
  if old.state = 'ACTIVE' and new.state in ('CONSUMED', 'SUPERSEDED', 'EXPIRED') then
    return new;
  end if;
  if old.state = 'SUPERSEDED' and new.state = 'SUPERSEDED'
     and old.superseded_by_quote_id is null and new.superseded_by_quote_id is not null then
    return new;
  end if;
  if to_jsonb(new) is not distinct from to_jsonb(old) then
    return new;
  end if;
  raise exception 'invalid_job_funding_quote_lifecycle_transition';
end;
$$;

create trigger stripe_job_funding_quote_immutable
before update or delete on private.stripe_job_funding_quotes
for each row execute function private.enforce_job_funding_quote_immutability_v1();

create or replace function private.job_funding_quote_dto_v1(
  p_quote private.stripe_job_funding_quotes
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'ok', true,
    'quote_id', p_quote.id,
    'contract_id', p_quote.contract_id,
    'contract_version_id', p_quote.contract_version_id,
    'obligation_id', p_quote.obligation_id,
    'base_pay_cents', p_quote.base_pay_cents,
    'service_fee_cents', p_quote.service_fee_cents,
    'authoritative_total_cents', p_quote.authoritative_total_cents,
    'currency_code', p_quote.currency_code,
    'financial_policy_version_id', p_quote.financial_policy_version_id,
    'policy_version', policy.version,
    'fair_pay_policy_version_id', p_quote.fair_pay_policy_version_id,
    'fair_pay_decision', p_quote.fair_pay_decision,
    'connected_account_readiness', p_quote.connected_account_readiness,
    'payment_eligibility', p_quote.payment_eligibility,
    'provider_availability', p_quote.provider_availability,
    'state', case
      when p_quote.state = 'ACTIVE' and statement_timestamp() >= p_quote.expires_at then 'EXPIRED'
      else p_quote.state
    end,
    'created_at', p_quote.created_at,
    'expires_at', p_quote.expires_at,
    'consumed_at', p_quote.consumed_at
  )
  from private.stripe_financial_policy_versions policy
  where policy.id = p_quote.financial_policy_version_id
$$;

create or replace function public.stripe_server_create_job_funding_quote_v1(
  p_payer_id uuid,
  p_contract_id uuid,
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_now timestamptz := clock_timestamp();
  v_control private.stripe_runtime_controls%rowtype;
  v_environment text;
  v_contract public.job_contracts%rowtype;
  v_job public.jobs%rowtype;
  v_obligation public.job_payment_obligations%rowtype;
  v_payer public.profiles%rowtype;
  v_worker public.profiles%rowtype;
  v_fee_policy private.stripe_financial_policy_versions%rowtype;
  v_fair record;
  v_account private.stripe_connected_accounts%rowtype;
  v_readiness text;
  v_fee integer;
  v_request_hash text;
  v_existing private.stripe_job_funding_quotes%rowtype;
  v_quote private.stripe_job_funding_quotes%rowtype;
  v_quote_id uuid := gen_random_uuid();
  v_superseded_id uuid;
begin
  perform private.require_stripe_service_role();
  if p_payer_id is null or p_contract_id is null or p_request_id is null then
    raise exception 'funding_quote_identifiers_required';
  end if;
  select * into v_control from private.stripe_runtime_controls where singleton for share;
  v_environment := private.stripe_environment_for_mode(v_control.mode);
  if v_environment is null then raise exception 'stripe_mode_disabled'; end if;
  if not v_control.stripe_payments_enabled or not v_control.stripe_job_funding_enabled then
    raise exception 'stripe_job_funding_disabled';
  end if;
  if v_environment = 'live' and (
    not v_control.stripe_live_mode_enabled or not v_control.live_owner_approved
  ) then
    raise exception 'stripe_live_disabled';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    v_environment || ':' || p_payer_id::text || ':' || p_contract_id::text, 0
  ));
  v_request_hash := encode(extensions.digest(
    convert_to(jsonb_build_object('contract_id', p_contract_id)::text, 'utf8'), 'sha256'
  ), 'hex');
  select * into v_existing
  from private.stripe_job_funding_quotes
  where environment = v_environment and payer_id = p_payer_id and request_id = p_request_id;
  if v_existing.id is not null then
    if v_existing.request_payload_sha256 <> v_request_hash then
      raise exception 'funding_quote_request_conflict';
    end if;
    return private.job_funding_quote_dto_v1(v_existing) || jsonb_build_object('idempotent', true);
  end if;

  select * into v_contract from public.job_contracts where id = p_contract_id for share;
  if v_contract.id is null or v_contract.adult_id is null or v_contract.adult_id <> p_payer_id then
    raise exception 'adult_contract_party_required' using errcode = '42501';
  end if;
  if v_contract.status <> 'active' or v_contract.active_version_id is null then
    raise exception 'active_contract_required';
  end if;
  select * into v_job from public.jobs where id = v_contract.job_id for share;
  if v_job.id is null or v_job.poster_id <> p_payer_id then
    raise exception 'fundable_job_required';
  end if;
  select * into v_payer from public.profiles where id = v_contract.adult_id;
  select * into v_worker from public.profiles where id = v_contract.teen_id;
  if v_payer.id is null or v_worker.id is null
     or v_payer.role <> 'adult' or v_worker.role <> 'teen'
     or v_payer.account_status <> 'active' or v_worker.account_status <> 'active' then
    raise exception 'eligible_contract_parties_required';
  end if;
  if v_environment = 'test' and (not v_payer.is_test_account or not v_worker.is_test_account) then
    raise exception 'sandbox_test_contract_required';
  end if;
  select * into v_obligation
  from public.job_payment_obligations
  where contract_id = v_contract.id
    and contract_version_id = v_contract.active_version_id
  for share;
  if v_obligation.id is null or v_obligation.amount_cents <= 0
     or v_obligation.obligated_poster_id <> p_payer_id
     or v_obligation.worker_id <> v_contract.teen_id then
    raise exception 'fundable_obligation_required';
  end if;
  if v_obligation.currency_code <> v_control.currency_code then
    raise exception 'funding_quote_currency_mismatch';
  end if;

  select * into v_fee_policy
  from private.resolve_financial_policy_v1(
    v_environment, 'service_fee', v_obligation.currency_code, 'global', v_now
  );
  if v_fee_policy.id is null then raise exception 'service_fee_policy_missing'; end if;
  select * into v_fair
  from private.evaluate_fair_pay_v1(
    v_obligation.amount_cents, v_environment, v_obligation.currency_code,
    v_job.category, v_now
  );
  if not v_fair.may_continue then raise exception 'fair_pay_rejected'; end if;

  v_fee := private.calculate_mort_service_fee_v1(v_obligation.amount_cents, v_fee_policy.id);
  if v_obligation.amount_cents + v_fee > 100000000 then
    raise exception 'payment_amount_limit_exceeded';
  end if;

  select * into v_account
  from private.stripe_connected_accounts
  where user_id = v_contract.teen_id and environment = v_environment;
  v_readiness := case
    when v_account.id is null then 'NOT_STARTED'
    when v_account.onboarding_status in ('restricted', 'disconnected')
      or v_account.requirements_status = 'restricted' then 'RESTRICTED'
    when v_account.onboarding_status = 'action_required'
      or v_account.requirements_status in ('currently_due', 'past_due') then 'ACTION_REQUIRED'
    when v_account.onboarding_status = 'complete'
      and v_account.details_submitted and v_account.payouts_enabled
      and v_account.transfers_capability_status = 'active'
      and v_account.requirements_status = 'satisfied'
      and v_account.guardian_requirement_status = 'provider_managed_satisfied'
      then 'READY_FOR_TRANSFER'
    else 'PENDING'
  end;

  update private.stripe_job_funding_quotes
  set state = 'EXPIRED', expired_at = v_now
  where environment = v_environment
    and payer_id = p_payer_id
    and contract_version_id = v_contract.active_version_id
    and state = 'ACTIVE'
    and expires_at <= v_now;

  update private.stripe_job_funding_quotes
  set state = 'SUPERSEDED', superseded_at = v_now
  where environment = v_environment
    and payer_id = p_payer_id
    and contract_version_id = v_contract.active_version_id
    and state = 'ACTIVE'
  returning id into v_superseded_id;

  insert into private.stripe_job_funding_quotes (
    id, environment, payer_id, worker_id, job_id, contract_id,
    contract_version_id, obligation_id, base_pay_cents, service_fee_cents,
    authoritative_total_cents, currency_code, financial_policy_version_id,
    fair_pay_policy_version_id, fair_pay_decision, connected_account_id,
    connected_account_readiness, payment_eligibility, provider_availability,
    request_id, request_payload_sha256, state, created_at, expires_at
  ) values (
    v_quote_id, v_environment, p_payer_id, v_contract.teen_id, v_contract.job_id,
    v_contract.id, v_contract.active_version_id, v_obligation.id,
    v_obligation.amount_cents, v_fee, v_obligation.amount_cents + v_fee,
    v_obligation.currency_code, v_fee_policy.id, v_fair.policy_version_id,
    v_fair.decision, v_account.id, v_readiness,
    v_readiness = 'READY_FOR_TRANSFER', 'NOT_CHECKED', p_request_id,
    v_request_hash, 'ACTIVE', v_now,
    v_now + pg_catalog.make_interval(secs => v_fee_policy.quote_ttl_seconds)
  ) returning * into v_quote;

  if v_superseded_id is not null then
    update private.stripe_job_funding_quotes
    set superseded_by_quote_id = v_quote.id
    where id = v_superseded_id;
  end if;
  return private.job_funding_quote_dto_v1(v_quote) || jsonb_build_object('idempotent', false);
end;
$$;

create or replace function public.stripe_server_consume_job_funding_quote_v1(
  p_payer_id uuid,
  p_quote_id uuid,
  p_attempt_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_now timestamptz := clock_timestamp();
  v_quote private.stripe_job_funding_quotes%rowtype;
begin
  perform private.require_stripe_service_role();
  if p_payer_id is null or p_quote_id is null or p_attempt_request_id is null then
    raise exception 'funding_quote_consumption_identifiers_required';
  end if;
  select * into v_quote
  from private.stripe_job_funding_quotes
  where id = p_quote_id
  for update;
  if v_quote.id is null or v_quote.payer_id <> p_payer_id then
    raise exception 'funding_quote_not_found' using errcode = '42501';
  end if;
  if v_quote.state = 'CONSUMED' then
    if v_quote.consumed_request_id <> p_attempt_request_id then
      raise exception 'funding_quote_already_consumed';
    end if;
    return private.job_funding_quote_dto_v1(v_quote) || jsonb_build_object('idempotent', true);
  end if;
  if v_quote.state <> 'ACTIVE' then
    raise exception 'funding_quote_not_active';
  end if;
  if not private.funding_quote_is_usable_v1(v_quote.state, v_quote.expires_at, v_now) then
    update private.stripe_job_funding_quotes
    set state = 'EXPIRED', expired_at = v_now
    where id = v_quote.id
    returning * into v_quote;
    return jsonb_build_object(
      'ok', false, 'code', 'funding_quote_expired',
      'quote_id', v_quote.id, 'expires_at', v_quote.expires_at
    );
  end if;
  update private.stripe_job_funding_quotes
  set state = 'CONSUMED', consumed_at = v_now,
      consumed_request_id = p_attempt_request_id
  where id = v_quote.id
  returning * into v_quote;
  return private.job_funding_quote_dto_v1(v_quote) || jsonb_build_object('idempotent', false);
end;
$$;

create or replace function public.get_my_job_funding_quote_v1(p_quote_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_quote private.stripe_job_funding_quotes%rowtype;
begin
  if auth.uid() is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  select * into v_quote
  from private.stripe_job_funding_quotes
  where id = p_quote_id and payer_id = auth.uid();
  if v_quote.id is null then
    raise exception 'funding_quote_not_found' using errcode = '42501';
  end if;
  return private.job_funding_quote_dto_v1(v_quote);
end;
$$;

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
      ('stripe_job_funding_quote'::text, 20, 3600),
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

alter table private.stripe_financial_policy_versions enable row level security;
alter table private.stripe_financial_policy_versions force row level security;
alter table private.stripe_job_funding_quotes enable row level security;
alter table private.stripe_job_funding_quotes force row level security;

revoke all on table private.stripe_financial_policy_versions from public, anon, authenticated;
revoke all on table private.stripe_job_funding_quotes from public, anon, authenticated;
grant select on table private.stripe_financial_policy_versions to service_role;
grant select on table private.stripe_job_funding_quotes to service_role;

revoke all on function private.enforce_financial_policy_version_immutability_v1() from public, anon, authenticated;
revoke all on function private.resolve_financial_policy_v1(text, text, text, text, timestamptz) from public, anon, authenticated;
revoke all on function private.calculate_mort_service_fee_v1(integer, uuid) from public, anon, authenticated;
revoke all on function private.evaluate_fair_pay_v1(integer, text, text, text, timestamptz) from public, anon, authenticated;
revoke all on function private.evaluate_tip_policy_v1(integer, text, text, text, timestamptz) from public, anon, authenticated;
revoke all on function private.evaluate_compensation_policy_v1(text, text, text, text, text, integer, jsonb, timestamptz) from public, anon, authenticated;
revoke all on function private.evaluate_cancellation_v1(text, text, text, text, integer, jsonb, timestamptz) from public, anon, authenticated;
revoke all on function private.evaluate_partial_compensation_v1(text, text, text, text, integer, jsonb, timestamptz) from public, anon, authenticated;
revoke all on function private.funding_quote_is_usable_v1(text, timestamptz, timestamptz) from public, anon, authenticated;
revoke all on function private.enforce_job_funding_quote_immutability_v1() from public, anon, authenticated;
revoke all on function private.job_funding_quote_dto_v1(private.stripe_job_funding_quotes) from public, anon, authenticated;

revoke all on function public.stripe_server_activate_financial_policy_v1(uuid) from public, anon, authenticated;
revoke all on function public.stripe_server_create_job_funding_quote_v1(uuid, uuid, uuid) from public, anon, authenticated;
revoke all on function public.stripe_server_consume_job_funding_quote_v1(uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function public.stripe_server_activate_financial_policy_v1(uuid) to service_role;
grant execute on function public.stripe_server_create_job_funding_quote_v1(uuid, uuid, uuid) to service_role;
grant execute on function public.stripe_server_consume_job_funding_quote_v1(uuid, uuid, uuid) to service_role;

revoke all on function public.get_my_job_funding_quote_v1(uuid) from public, anon;
grant execute on function public.get_my_job_funding_quote_v1(uuid) to authenticated, service_role;

comment on table private.stripe_financial_policy_versions is
  'Versioned server-authoritative financial policy. Live rows are not seeded or activated by BP-02.';
comment on column private.stripe_financial_policy_versions.quote_ttl_seconds is
  'Backend-configured quote lifetime. Sandbox initial value is 900 seconds and may be versioned later.';
comment on table private.stripe_job_funding_quotes is
  'Immutable pre-provider funding snapshot; only controlled lifecycle fields may change.';
