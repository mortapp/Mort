-- Phase 12 completes code-controlled financial policy and operations boundaries.
-- All provider execution remains disabled. These controls do not approve money
-- movement, fees, minor payouts, tax treatment, or legal compliance.

alter table private.stripe_runtime_controls
  add column if not exists payment_collection_strategy text not null
    default 'separate_charges_and_transfers'
    check (payment_collection_strategy = 'separate_charges_and_transfers'),
  add column if not exists capture_strategy text not null
    default 'automatic_capture_before_job_start'
    check (capture_strategy = 'automatic_capture_before_job_start'),
  add column if not exists transfer_release_strategy text not null
    default 'post_completion_human_gated'
    check (transfer_release_strategy = 'post_completion_human_gated'),
  add column if not exists sandbox_provider_qa_approved boolean not null default false,
  add column if not exists provider_use_case_approved boolean not null default false,
  add column if not exists legal_financial_approved boolean not null default false,
  add column if not exists privacy_financial_approved boolean not null default false,
  add column if not exists minor_payout_flow_approved boolean not null default false,
  add column if not exists tax_reporting_approved boolean not null default false,
  add column if not exists negative_balance_plan_approved boolean not null default false,
  add column if not exists financial_retention_approved boolean not null default false,
  add column if not exists receipts_policy_approved boolean not null default false,
  add column if not exists reconciliation_schedule_approved boolean not null default false,
  add column if not exists monitoring_on_call_approved boolean not null default false,
  add column if not exists partial_compensation_policy_version text,
  add column if not exists production_release_approved boolean not null default false,
  add column if not exists production_approved_at timestamptz;

alter table private.stripe_runtime_controls
  drop constraint if exists stripe_runtime_partial_policy_version_check,
  add constraint stripe_runtime_partial_policy_version_check check (
    partial_compensation_policy_version is null
    or partial_compensation_policy_version ~ '^[a-z0-9][a-z0-9._-]{2,63}$'
  ),
  drop constraint if exists stripe_runtime_production_approval_time_check,
  add constraint stripe_runtime_production_approval_time_check check (
    (not production_release_approved and production_approved_at is null)
    or (production_release_approved and production_approved_at is not null)
  ),
  drop constraint if exists stripe_runtime_phase12_live_gate,
  add constraint stripe_runtime_phase12_live_gate check (
    mode <> 'live'
    or (
      stripe_live_mode_enabled
      and live_owner_approved
      and connected_accounts_approved
      and payouts_approved
      and provider_use_case_approved
      and legal_financial_approved
      and privacy_financial_approved
      and minor_payout_flow_approved
      and tax_reporting_approved
      and negative_balance_plan_approved
      and financial_retention_approved
      and receipts_policy_approved
      and reconciliation_schedule_approved
      and monitoring_on_call_approved
      and partial_compensation_policy_version is not null
      and production_release_approved
      and production_approved_at is not null
    )
  );

create or replace function private.stripe_live_financial_ready()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select
      control.mode = 'live'
      and control.stripe_live_mode_enabled
      and control.live_owner_approved
      and control.connected_accounts_approved
      and control.payouts_approved
      and control.provider_use_case_approved
      and control.legal_financial_approved
      and control.privacy_financial_approved
      and control.minor_payout_flow_approved
      and control.tax_reporting_approved
      and control.negative_balance_plan_approved
      and control.financial_retention_approved
      and control.receipts_policy_approved
      and control.reconciliation_schedule_approved
      and control.monitoring_on_call_approved
      and control.partial_compensation_policy_version is not null
      and control.production_release_approved
      and control.production_approved_at is not null
    from private.stripe_runtime_controls control
    where control.singleton
  ), false)
$$;

revoke all on function private.stripe_live_financial_ready()
from public, anon, authenticated;
grant execute on function private.stripe_live_financial_ready() to service_role;

create table if not exists private.stripe_financial_incidents (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null,
  environment text not null check (environment in ('test', 'live')),
  category text not null check (category in (
    'negative_balance', 'reserve_shortfall', 'chargeback_exposure',
    'refund_failure', 'transfer_failure', 'transfer_reversal',
    'payout_failure', 'tax_reporting', 'reconciliation_mismatch',
    'provider_outage', 'webhook_integrity'
  )),
  severity text not null check (severity in ('low', 'medium', 'high', 'critical')),
  subject_type text not null check (subject_type in (
    'platform', 'payment', 'transfer', 'refund', 'payout',
    'dispute', 'connected_account', 'reconciliation'
  )),
  subject_id uuid,
  amount_cents integer check (amount_cents is null or amount_cents >= 0),
  currency_code text check (currency_code is null or currency_code ~ '^[A-Z]{3}$'),
  safe_code text not null check (safe_code ~ '^[a-z][a-z0-9_]{2,63}$'),
  payload_sha256 text not null check (payload_sha256 ~ '^[A-F0-9]{64}$'),
  status text not null default 'open'
    check (status in ('open', 'assigned', 'monitoring', 'resolved', 'closed')), 
  requires_two_person_review boolean not null default true,
  detected_at timestamptz not null default now(),
  assigned_to uuid references auth.users(id) on delete set null,
  assignment_expires_at timestamptz,
  resolved_by uuid references auth.users(id) on delete set null,
  resolved_at timestamptz,
  resolution_code text check (
    resolution_code is null or resolution_code ~ '^[a-z][a-z0-9_]{2,63}$'
  ),
  updated_at timestamptz not null default now(),
  unique (environment, request_id),
  check (
    (status in ('resolved', 'closed') and resolved_at is not null and resolution_code is not null)
    or (status not in ('resolved', 'closed') and resolved_at is null)
  )
);

create index if not exists stripe_financial_incidents_queue_idx
on private.stripe_financial_incidents(environment, status, severity, detected_at);

alter table private.stripe_financial_incidents enable row level security;
alter table private.stripe_financial_incidents force row level security;

revoke all on table private.stripe_financial_incidents
from public, anon, authenticated;
grant select, insert, update on table private.stripe_financial_incidents to service_role;

create or replace function public.stripe_server_record_financial_incident(
  p_request_id uuid,
  p_environment text,
  p_category text,
  p_severity text,
  p_subject_type text,
  p_subject_id uuid,
  p_amount_cents integer,
  p_currency_code text,
  p_safe_code text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_payload_sha256 text;
  v_existing private.stripe_financial_incidents%rowtype;
  v_incident private.stripe_financial_incidents%rowtype;
begin
  perform private.require_stripe_service_role();
  if p_request_id is null then
    return jsonb_build_object('ok', false, 'code', 'request_id_required');
  end if;
  if p_environment not in ('test', 'live')
     or p_category not in (
       'negative_balance', 'reserve_shortfall', 'chargeback_exposure',
       'refund_failure', 'transfer_failure', 'transfer_reversal',
       'payout_failure', 'tax_reporting', 'reconciliation_mismatch',
       'provider_outage', 'webhook_integrity'
     )
     or p_severity not in ('low', 'medium', 'high', 'critical')
     or p_subject_type not in (
       'platform', 'payment', 'transfer', 'refund', 'payout',
       'dispute', 'connected_account', 'reconciliation'
     )
     or p_safe_code !~ '^[a-z][a-z0-9_]{2,63}$'
     or p_amount_cents < 0
     or (p_currency_code is not null and p_currency_code !~ '^[A-Z]{3}$') then
    return jsonb_build_object('ok', false, 'code', 'invalid_financial_incident');
  end if;

  v_payload_sha256 := upper(encode(extensions.digest(
    concat_ws('|', p_environment, p_category, p_severity, p_subject_type,
      coalesce(p_subject_id::text, ''), coalesce(p_amount_cents::text, ''),
      coalesce(p_currency_code, ''), p_safe_code),
    'sha256'
  ), 'hex'));

  select incident.* into v_existing
  from private.stripe_financial_incidents incident
  where incident.environment = p_environment
    and incident.request_id = p_request_id;

  if v_existing.id is not null then
    if v_existing.payload_sha256 <> v_payload_sha256 then
      return jsonb_build_object('ok', false, 'code', 'financial_incident_replay_conflict');
    end if;
    return jsonb_build_object(
      'ok', true,
      'idempotent', true,
      'incident_id', v_existing.id,
      'status', v_existing.status
    );
  end if;

  insert into private.stripe_financial_incidents (
    request_id, environment, category, severity, subject_type, subject_id,
    amount_cents, currency_code, safe_code, payload_sha256
  ) values (
    p_request_id, p_environment, p_category, p_severity, p_subject_type,
    p_subject_id, p_amount_cents, p_currency_code, p_safe_code,
    v_payload_sha256
  ) returning * into v_incident;

  insert into private.stripe_financial_audit_events (
    environment, event_type, subject_type, subject_id, safe_reason_code,
    field_names
  ) values (
    p_environment, 'financial_incident_recorded', p_subject_type, p_subject_id,
    p_safe_code, array['category', 'severity', 'amount_cents', 'currency_code']
  );

  return jsonb_build_object(
    'ok', true,
    'idempotent', false,
    'incident_id', v_incident.id,
    'status', v_incident.status
  );
end;
$$;

revoke all on function public.stripe_server_record_financial_incident(
  uuid, text, text, text, text, uuid, integer, text, text
) from public, anon, authenticated;
grant execute on function public.stripe_server_record_financial_incident(
  uuid, text, text, text, text, uuid, integer, text, text
) to service_role;

create or replace function public.get_my_job_payment_receipt(
  p_contract_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_summary jsonb;
begin
  v_summary := public.get_job_payment_summary(p_contract_id);
  return v_summary || jsonb_build_object(
    'receipt_type', 'provider_status_summary',
    'not_tax_receipt', true,
    'not_escrow', true,
    'provider_receipt_available', false,
    'payment_processing_enabled', false,
    'message', 'MORT does not process job payments in this release. This is a status summary, not proof of bank deposit or a tax receipt.'
  );
end;
$$;

revoke all on function public.get_my_job_payment_receipt(uuid)
from public, anon;
grant execute on function public.get_my_job_payment_receipt(uuid)
to authenticated, service_role;

create or replace function public.get_my_payment_operations_queue()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reviewer boolean;
  v_operator boolean;
  v_support boolean;
  v_financial_admin boolean;
  v_disputes jsonb;
  v_resolutions jsonb;
  v_incidents jsonb;
begin
  if auth.uid() is null or not public.is_profile_active(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  v_reviewer := private.has_stripe_financial_role(auth.uid(), array['payment_reviewer']);
  v_operator := private.has_stripe_financial_role(auth.uid(), array['payment_operations']);
  v_support := private.has_stripe_financial_role(auth.uid(), array['payment_support']);
  v_financial_admin := private.has_stripe_financial_role(
    auth.uid(), array['financial_admin', 'super_admin']
  );
  if not v_reviewer and not v_operator and not v_support and not v_financial_admin then
    return jsonb_build_object('ok', false, 'code', 'payment_operations_role_required');
  end if;
  if not public.check_rate_limit('payment_operations_queue', 120, 3600) then
    return jsonb_build_object('ok', false, 'code', 'rate_limit_exceeded');
  end if;
  perform public.record_rate_limit_event('payment_operations_queue');

  if v_reviewer then
    select coalesce(jsonb_agg(jsonb_build_object(
      'dispute_id', dispute.id,
      'status', dispute.status,
      'classification_status', dispute.classification_status,
      'allegation_type', dispute.allegation_type,
      'opened_at', dispute.opened_at,
      'assignment_expires_at', assignment.expires_at,
      'amount_cents', obligation.amount_cents,
      'currency_code', obligation.currency_code,
      'latest_decision_type', decision.decision_type,
      'latest_recommended_amount_cents', decision.recommended_amount_cents,
      'latest_decided_at', decision.decided_at
    ) order by dispute.updated_at desc), '[]'::jsonb)
    into v_disputes
    from public.payment_dispute_assignments assignment
    join public.payment_disputes dispute on dispute.id = assignment.dispute_id
    join public.job_payment_obligations obligation on obligation.id = dispute.obligation_id
    left join lateral (
      select item.decision_type, item.recommended_amount_cents, item.decided_at
      from public.payment_dispute_decisions item
      where item.dispute_id = dispute.id
      order by item.decided_at desc limit 1
    ) decision on true
    where assignment.reviewer_id = auth.uid()
      and assignment.status = 'active'
      and assignment.expires_at > now();
  else
    v_disputes := '[]'::jsonb;
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'resolution_id', resolution.id,
    'dispute_id', resolution.dispute_id,
    'contract_id', resolution.contract_id,
    'resolution_source', resolution.resolution_source,
    'eligibility_path', resolution.eligibility_path,
    'transfer_amount_cents', resolution.transfer_amount_cents,
    'refund_amount_cents', resolution.refund_amount_cents,
    'currency_code', resolution.currency_code,
    'status', resolution.status,
    'reviewed_at', resolution.reviewed_at,
    'reviewed_by_current_user', resolution.reviewer_id = auth.uid(),
    'operator_separation_required', resolution.reviewer_id = auth.uid(),
    'safe_failure_code', resolution.safe_failure_code
  ) order by resolution.updated_at desc), '[]'::jsonb)
  into v_resolutions
  from private.stripe_payment_resolutions resolution
  where resolution.environment = 'test'
    and resolution.status in (
      'reviewed_pending_financial_execution', 'financial_execution_started',
      'provider_processing', 'failed'
    )
    and (v_operator or v_financial_admin or resolution.reviewer_id = auth.uid());

  select coalesce(jsonb_agg(jsonb_build_object(
    'incident_id', incident.id,
    'environment', incident.environment,
    'category', incident.category,
    'severity', incident.severity,
    'subject_type', incident.subject_type,
    'subject_id', incident.subject_id,
    'amount_cents', incident.amount_cents,
    'currency_code', incident.currency_code,
    'safe_code', incident.safe_code,
    'status', incident.status,
    'requires_two_person_review', incident.requires_two_person_review,
    'detected_at', incident.detected_at,
    'assignment_expires_at', incident.assignment_expires_at
  ) order by incident.severity desc, incident.detected_at)
  , '[]'::jsonb)
  into v_incidents
  from private.stripe_financial_incidents incident
  where incident.status in ('open', 'assigned', 'monitoring')
    and (
      v_operator or v_financial_admin or v_support
      or incident.assigned_to = auth.uid()
    );

  return jsonb_build_object(
    'ok', true,
    'environment', 'test',
    'can_review', v_reviewer,
    'can_execute', v_operator,
    'can_view_financial_incidents', v_operator or v_support or v_financial_admin,
    'provider_operation_requires_confirmation', true,
    'disputes', v_disputes,
    'resolutions', v_resolutions,
    'incidents', v_incidents
  );
end;
$$;

revoke all on function public.get_my_payment_operations_queue()
from public, anon;
grant execute on function public.get_my_payment_operations_queue()
to authenticated, service_role;

create or replace function public.stripe_server_update_controls(
  p_stripe_payments_enabled boolean,
  p_stripe_connected_onboarding_enabled boolean,
  p_stripe_job_funding_enabled boolean,
  p_stripe_transfers_enabled boolean,
  p_stripe_refunds_enabled boolean,
  p_reason_code text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_control private.stripe_runtime_controls%rowtype;
  v_enabling boolean := coalesce(p_stripe_payments_enabled, false)
    or coalesce(p_stripe_connected_onboarding_enabled, false)
    or coalesce(p_stripe_job_funding_enabled, false)
    or coalesce(p_stripe_transfers_enabled, false)
    or coalesce(p_stripe_refunds_enabled, false);
begin
  perform private.require_stripe_service_role();
  if char_length(btrim(coalesce(p_reason_code, ''))) < 8 then
    raise exception 'control_change_reason_required';
  end if;
  select * into v_control
  from private.stripe_runtime_controls control
  where control.singleton
  for update;

  if v_enabling and v_control.mode = 'sandbox'
     and not v_control.sandbox_provider_qa_approved then
    raise exception 'stripe_sandbox_qa_not_approved';
  end if;
  if v_enabling and v_control.mode = 'live'
     and not private.stripe_live_financial_ready() then
    raise exception 'stripe_live_financial_gates_incomplete';
  end if;

  update private.stripe_runtime_controls
  set stripe_payments_enabled = p_stripe_payments_enabled,
      stripe_connected_onboarding_enabled = p_stripe_connected_onboarding_enabled,
      stripe_job_funding_enabled = p_stripe_job_funding_enabled,
      stripe_transfers_enabled = p_stripe_transfers_enabled,
      stripe_refunds_enabled = p_stripe_refunds_enabled,
      updated_at = now()
  where singleton
  returning * into v_control;

  insert into private.stripe_financial_audit_events(
    environment, event_type, subject_type, safe_reason_code, field_names
  ) values (
    private.stripe_environment_for_mode(v_control.mode),
    'runtime_controls_changed', 'stripe_runtime_controls',
    left(p_reason_code, 120),
    array[
      'stripe_payments_enabled', 'stripe_connected_onboarding_enabled',
      'stripe_job_funding_enabled', 'stripe_transfers_enabled',
      'stripe_refunds_enabled'
    ]
  );

  return jsonb_build_object(
    'ok', true,
    'mode', v_control.mode,
    'payments_enabled', v_control.stripe_payments_enabled,
    'connected_onboarding_enabled', v_control.stripe_connected_onboarding_enabled,
    'job_funding_enabled', v_control.stripe_job_funding_enabled,
    'transfers_enabled', v_control.stripe_transfers_enabled,
    'refunds_enabled', v_control.stripe_refunds_enabled
  );
end;
$$;

create or replace function public.get_stripe_live_readiness()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_control private.stripe_runtime_controls%rowtype;
begin
  if auth.uid() is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  select * into v_control
  from private.stripe_runtime_controls control
  where control.singleton;

  return jsonb_build_object(
    'ready', private.stripe_live_financial_ready(),
    'mode', v_control.mode,
    'payment_collection_strategy', v_control.payment_collection_strategy,
    'capture_strategy', v_control.capture_strategy,
    'transfer_release_strategy', v_control.transfer_release_strategy,
    'sandbox_provider_qa_approved', v_control.sandbox_provider_qa_approved,
    'live_mode_enabled', v_control.stripe_live_mode_enabled,
    'owner_approved', v_control.live_owner_approved,
    'connected_accounts_approved', v_control.connected_accounts_approved,
    'payouts_approved', v_control.payouts_approved,
    'provider_use_case_approved', v_control.provider_use_case_approved,
    'legal_financial_approved', v_control.legal_financial_approved,
    'privacy_financial_approved', v_control.privacy_financial_approved,
    'minor_payout_flow_approved', v_control.minor_payout_flow_approved,
    'tax_reporting_approved', v_control.tax_reporting_approved,
    'negative_balance_plan_approved', v_control.negative_balance_plan_approved,
    'financial_retention_approved', v_control.financial_retention_approved,
    'receipts_policy_approved', v_control.receipts_policy_approved,
    'reconciliation_schedule_approved', v_control.reconciliation_schedule_approved,
    'monitoring_on_call_approved', v_control.monitoring_on_call_approved,
    'partial_compensation_policy_version', v_control.partial_compensation_policy_version,
    'production_release_approved', v_control.production_release_approved,
    'external_review_required', true,
    'physical_android_test_required', true,
    'legal_review_required', true,
    'minor_payout_confirmation_required', true
  );
end;
$$;

create or replace function private.stripe_financial_retention_required(
  p_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_user_id is not null and (
    exists (
      select 1 from private.stripe_connected_accounts account
      where account.user_id = p_user_id
    )
    or exists (
      select 1 from private.stripe_customers customer
      where customer.user_id = p_user_id
    )
    or exists (
      select 1 from private.stripe_job_payment_intents payment
      where p_user_id in (payment.adult_id, payment.teen_id)
    )
  )
$$;

revoke all on function private.stripe_financial_retention_required(uuid)
from public, anon, authenticated;
grant execute on function private.stripe_financial_retention_required(uuid)
to service_role;

create or replace function public.service_check_account_deletion_financial_retention(
  p_user_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_required boolean;
begin
  perform private.require_stripe_service_role();
  v_required := private.stripe_financial_retention_required(p_user_id);
  return jsonb_build_object(
    'ok', true,
    'retention_review_required', v_required,
    'code', case when v_required then 'financial_retention_review_required' else 'clear' end
  );
end;
$$;

revoke all on function public.service_check_account_deletion_financial_retention(uuid)
from public, anon, authenticated;
grant execute on function public.service_check_account_deletion_financial_retention(uuid)
to service_role;

alter table public.account_deletion_requests
  drop constraint if exists account_deletion_status_check,
  add constraint account_deletion_status_check check (
    status in (
      'requested', 'processing', 'retry_pending', 'retention_review',
      'completed', 'cancelled', 'failed'
    )
  );

drop index if exists public.account_deletion_one_open_request_idx;
create unique index account_deletion_one_open_request_idx
on public.account_deletion_requests(user_id)
where user_id is not null
  and status in ('requested', 'processing', 'retry_pending', 'retention_review');

create or replace function public.service_hold_account_deletion_for_financial_retention(
  p_request_id uuid,
  p_processor_lock_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request public.account_deletion_requests%rowtype;
begin
  perform private.require_stripe_service_role();

  update public.account_deletion_requests request
  set status = 'retention_review',
      last_error_code = 'financial_retention_review_required',
      retention_summary = 'Financial records exist. Ordinary deletion is paused before data removal pending approved retention and de-identification review.',
      processor_lock_id = null
  where request.id = p_request_id
    and request.status = 'processing'
    and request.processor_lock_id = p_processor_lock_id
    and private.stripe_financial_retention_required(request.user_id)
  returning request.* into v_request;

  if v_request.id is null then
    return jsonb_build_object('ok', false, 'code', 'deletion_lock_or_retention_mismatch');
  end if;
  return jsonb_build_object(
    'ok', true,
    'request_id', v_request.id,
    'status', v_request.status
  );
end;
$$;

revoke all on function public.service_hold_account_deletion_for_financial_retention(
  uuid, uuid
) from public, anon, authenticated;
grant execute on function public.service_hold_account_deletion_for_financial_retention(
  uuid, uuid
) to service_role;
