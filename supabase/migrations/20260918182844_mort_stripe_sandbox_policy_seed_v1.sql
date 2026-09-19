-- Task 31 sandbox provider QA prerequisite.
-- Seeds TEST-only policy kinds that the original Stripe policy migration defined
-- but did not seed. No live policy row is created or activated.

insert into private.stripe_financial_policy_versions (
  environment, policy_kind, scope_key, currency_code, version,
  effective_at, active, recommended_min_cents, recommended_max_cents,
  hard_minimum_cents, yellow_may_continue
)
select 'test','fair_pay','yard help','USD','sandbox-2026-09-18-v1',
       statement_timestamp() - interval '1 second',true,2000,2800,1400,true
where not exists (
  select 1 from private.stripe_financial_policy_versions
  where environment='test' and policy_kind='fair_pay' and currency_code='USD'
    and scope_key='yard help' and active
);

insert into private.stripe_financial_policy_versions (
  environment, policy_kind, scope_key, currency_code, version,
  effective_at, active, tip_min_cents, tip_max_cents,
  late_tip_window_seconds, tip_teen_share_bps, tip_mort_fee_bps,
  tip_excluded_from_fair_pay
)
select 'test','tip','global','USD','sandbox-2026-09-18-v1',
       statement_timestamp() - interval '1 second',true,
       100,10000,604800,10000,0,true
where not exists (
  select 1 from private.stripe_financial_policy_versions
  where environment='test' and policy_kind='tip' and currency_code='USD'
    and scope_key='global' and active
);

insert into private.stripe_financial_policy_versions (
  environment, policy_kind, scope_key, currency_code, version,
  effective_at, active, configuration
)
select 'test','cancellation','global','USD','sandbox-2026-09-18-v1',
       statement_timestamp() - interval '1 second',true,
       jsonb_build_object(
         'service_fee_refund_bps',0,
         'rules',jsonb_build_array(
           jsonb_build_object('priority',10,'outcome_code','ADULT_CANCELS_BEFORE_WORK',
             'required_facts',jsonb_build_object('work_started',false),
             'award',jsonb_build_object('kind','basis_points','value',0),
             'explanation_code','NO_WORK_STARTED'),
           jsonb_build_object('priority',20,'outcome_code','ADULT_CANCELS_IN_PROGRESS',
             'required_facts',jsonb_build_object('work_started',true),
             'award',jsonb_build_object('kind','basis_points','value',5000),
             'explanation_code','HALF_SANDBOX_FIXTURE')
         )
       )
where not exists (
  select 1 from private.stripe_financial_policy_versions
  where environment='test' and policy_kind='cancellation' and currency_code='USD'
    and scope_key='global' and active
);

insert into private.stripe_financial_policy_versions (
  environment, policy_kind, scope_key, currency_code, version,
  effective_at, active, configuration
)
select 'test','partial_compensation','global','USD','sandbox-2026-09-18-v1',
       statement_timestamp() - interval '1 second',true,
       jsonb_build_object(
         'service_fee_refund_bps',0,
         'rules',jsonb_build_array(
           jsonb_build_object('priority',10,'outcome_code','ADULT_CANCELS_BEFORE_WORK',
             'required_facts',jsonb_build_object('work_started',false),
             'award',jsonb_build_object('kind','basis_points','value',0),
             'explanation_code','NO_WORK_STARTED'),
           jsonb_build_object('priority',20,'outcome_code','ADULT_CANCELS_IN_PROGRESS',
             'required_facts',jsonb_build_object('work_started',true),
             'award',jsonb_build_object('kind','basis_points','value',5000),
             'explanation_code','HALF_SANDBOX_FIXTURE'),
           jsonb_build_object('priority',30,'outcome_code','TEEN_ABANDONMENT',
             'required_facts',jsonb_build_object('worker_abandoned',true),
             'award',jsonb_build_object('kind','fixed_cents','value',0),
             'explanation_code','ABANDONED'),
           jsonb_build_object('priority',40,'outcome_code','SUCCESSFUL_COMPLETION',
             'required_facts',jsonb_build_object('completion_confirmed',true),
             'award',jsonb_build_object('kind','basis_points','value',10000),
             'explanation_code','FULL_COMPLETION'),
           jsonb_build_object('priority',50,'outcome_code','DISPUTED_COMPLETION',
             'required_facts',jsonb_build_object('dispute_open',true),
             'award',jsonb_build_object('kind','basis_points','value',0),
             'explanation_code','DISPUTE_FAIL_CLOSED')
         )
       )
where not exists (
  select 1 from private.stripe_financial_policy_versions
  where environment='test' and policy_kind='partial_compensation' and currency_code='USD'
    and scope_key='global' and active
);
