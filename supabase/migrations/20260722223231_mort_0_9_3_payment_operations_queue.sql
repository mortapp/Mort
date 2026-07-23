-- Safe queue projection for separately assigned payment reviewers/operators.
-- Provider identifiers, party contact data, bank data, and identity evidence
-- are intentionally excluded.
create or replace function public.get_my_payment_operations_queue()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reviewer boolean;
  v_operator boolean;
  v_disputes jsonb;
  v_resolutions jsonb;
begin
  if auth.uid() is null or not public.is_profile_active(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  v_reviewer := private.has_stripe_financial_role(auth.uid(), array['payment_reviewer']);
  v_operator := private.has_stripe_financial_role(auth.uid(), array['payment_operations']);
  if not v_reviewer and not v_operator then
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
    and resolution.status in ('reviewed_pending_financial_execution', 'financial_execution_started', 'provider_processing', 'failed')
    and (v_operator or resolution.reviewer_id = auth.uid());

  return jsonb_build_object(
    'ok', true,
    'environment', 'test',
    'can_review', v_reviewer,
    'can_execute', v_operator,
    'provider_operation_requires_confirmation', true,
    'disputes', v_disputes,
    'resolutions', v_resolutions
  );
end;
$$;

revoke all on function public.get_my_payment_operations_queue() from public, anon;
grant execute on function public.get_my_payment_operations_queue() to authenticated, service_role;
