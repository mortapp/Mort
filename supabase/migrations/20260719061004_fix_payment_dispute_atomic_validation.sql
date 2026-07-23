-- Validate every fallible reviewer input before recording a payment-dispute decision.

create or replace function public.review_payment_dispute(
  p_dispute_id uuid,
  p_decision_type text,
  p_rationale text,
  p_recommended_amount_cents integer default null,
  p_restrict_poster boolean default false,
  p_restriction_type text default 'block_new_job_publication',
  p_restriction_expires_at timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_dispute public.payment_disputes%rowtype;
  v_obligation public.job_payment_obligations%rowtype;
  v_decision public.payment_dispute_decisions%rowtype;
  v_status text;
begin
  select *
  into v_dispute
  from public.payment_disputes
  where id = p_dispute_id
  for update;

  if v_dispute.id is null then
    return jsonb_build_object('ok', false, 'code', 'payment_dispute_not_found');
  end if;
  if not private.is_assigned_payment_dispute_reviewer(v_dispute.id, auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'assigned_ready_reviewer_required');
  end if;

  select *
  into v_obligation
  from public.job_payment_obligations
  where id = v_dispute.obligation_id;

  if v_obligation.id is null then
    return jsonb_build_object('ok', false, 'code', 'payment_obligation_not_found');
  end if;
  if p_decision_type not in (
    'recommend_payment',
    'recommend_partial_payment',
    'request_more_evidence',
    'no_platform_determination',
    'confirm_payment_received'
  ) then
    return jsonb_build_object('ok', false, 'code', 'unsupported_platform_decision');
  end if;
  if char_length(btrim(coalesce(p_rationale, ''))) < 20 then
    return jsonb_build_object('ok', false, 'code', 'substantive_rationale_required');
  end if;
  if p_recommended_amount_cents is not null
    and (p_recommended_amount_cents < 0 or p_recommended_amount_cents > v_obligation.amount_cents)
  then
    return jsonb_build_object('ok', false, 'code', 'invalid_recommended_amount');
  end if;
  if coalesce(p_restrict_poster, false)
    and p_decision_type = 'no_platform_determination'
  then
    return jsonb_build_object('ok', false, 'code', 'restriction_requires_preliminary_evidence_basis');
  end if;
  if coalesce(p_restrict_poster, false)
    and p_restriction_type not in (
      'block_new_job_publication',
      'block_new_application_acceptance',
      'pause_repeat_worker_invites'
    )
  then
    return jsonb_build_object('ok', false, 'code', 'unsupported_restriction_type');
  end if;
  if coalesce(p_restrict_poster, false)
    and (
      p_restriction_expires_at is null
      or p_restriction_expires_at <= now()
      or p_restriction_expires_at > now() + interval '30 days'
    )
  then
    return jsonb_build_object('ok', false, 'code', 'bounded_restriction_expiry_required');
  end if;

  insert into public.payment_dispute_decisions (
    dispute_id,
    reviewer_id,
    decision_type,
    rationale,
    recommended_amount_cents
  ) values (
    v_dispute.id,
    auth.uid(),
    p_decision_type,
    left(btrim(p_rationale), 4000),
    p_recommended_amount_cents
  )
  returning * into v_decision;

  v_status := case p_decision_type
    when 'recommend_payment' then 'resolved_payment_recommended'
    when 'recommend_partial_payment' then 'resolved_partial_payment_recommended'
    when 'request_more_evidence' then 'resolved_more_evidence'
    when 'confirm_payment_received' then 'closed_confirmed_paid'
    else 'resolved_no_platform_determination'
  end;

  update public.payment_disputes
  set
    status = v_status,
    closed_at = case when p_decision_type = 'request_more_evidence' then null else now() end
  where id = v_dispute.id;

  if p_decision_type = 'confirm_payment_received' then
    update public.job_payment_obligations
    set status = 'worker_confirmed_received', satisfied_at = now()
    where id = v_obligation.id;
  end if;

  if coalesce(p_restrict_poster, false) then
    insert into public.poster_payment_restrictions (
      poster_id,
      dispute_id,
      restriction_type,
      private_reason,
      imposed_by,
      expires_at
    ) values (
      v_dispute.poster_id,
      v_dispute.id,
      p_restriction_type,
      'Temporary private restriction based on assigned reviewer preliminary evidence assessment; appeal available.',
      auth.uid(),
      p_restriction_expires_at
    );
  end if;

  insert into public.payment_dispute_timeline (
    dispute_id,
    actor_id,
    event_type,
    event_summary
  ) values (
    v_dispute.id,
    auth.uid(),
    'platform_review_decision',
    'Assigned reviewer recorded a private platform recommendation. This is not a court judgment or criminal finding.'
  );

  return jsonb_build_object(
    'ok', true,
    'decision_id', v_decision.id,
    'status', v_status,
    'court_judgment', false,
    'criminal_finding', false,
    'appeal_available', true
  );
end;
$$;

revoke all on function public.review_payment_dispute(
  uuid,
  text,
  text,
  integer,
  boolean,
  text,
  timestamptz
) from public, anon;
grant execute on function public.review_payment_dispute(
  uuid,
  text,
  text,
  integer,
  boolean,
  text,
  timestamptz
) to authenticated, service_role;
