-- Participant-safe chronological financial history with stable tuple cursors.
-- This is additive: v1 remains available for compatibility while Edge/mobile
-- move to v2. Provider/customer/account identifiers are never selected.

create or replace function public.get_my_financial_history_v2(
  p_cursor_at timestamptz default null,
  p_cursor_id uuid default null,
  p_year integer default null,
  p_category text default null,
  p_search text default null,
  p_limit integer default 50
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  v_limit integer := greatest(1, least(coalesce(p_limit, 50), 50));
  v_category text := lower(nullif(btrim(coalesce(p_category, '')), ''));
  v_search text := lower(nullif(btrim(coalesce(p_search, '')), ''));
begin
  if actor is null then raise exception 'authentication_required' using errcode = '42501'; end if;
  if (p_cursor_at is null) <> (p_cursor_id is null) then raise exception 'financial_history_cursor_invalid'; end if;
  if p_year is not null and (p_year < 2000 or p_year > 2100) then raise exception 'financial_history_year_invalid'; end if;
  if v_search is not null and length(v_search) > 80 then raise exception 'financial_history_search_invalid'; end if;
  if v_category is not null and v_category not in (
    'all','jobs','payments','receipts','earnings','tips','refunds','failed','adjustments','disputed'
  ) then raise exception 'financial_history_category_invalid'; end if;

  return (
    with events as (
      select d.id as event_id, 'receipt'::text as event_kind, d.document_type as event_type,
        case d.document_type
          when 'ADULT_JOB_PAYMENT' then 'Job payment receipt'
          when 'TEEN_EARNINGS' then 'Earnings receipt'
          when 'TIP' then 'Tip receipt'
          when 'REFUND' then 'Refund receipt'
          when 'ADJUSTMENT' then 'Adjustment receipt'
          when 'REVERSAL' then 'Reversal receipt'
          else 'Financial receipt'
        end as title,
        coalesce(d.immutable_snapshot->>'job_title', d.immutable_snapshot->>'display_username') as display_subtitle,
        d.created_at as occurred_at, d.status, d.amount_cents, d.currency_code,
        d.receipt_id, d.order_number, false as no_receipt, d.document_type, null::text as safe_code
      from private.financial_documents d where d.owner_id = actor
      union all
      select a.id, 'payment_attempt', a.operation_kind,
        case when a.normalized_state in ('DECLINED','FAILED','CANCELLED') then 'Job funding attempt'
             when a.normalized_state = 'SUCCEEDED' then 'Job funded' else 'Job funding pending' end,
        null::text, a.created_at, coalesce(a.normalized_state, a.outcome),
        p.total_amount_cents, p.currency_code, doc.receipt_id, doc.order_number,
        doc.receipt_id is null, null::text, a.safe_failure_code
      from private.stripe_job_payment_attempts a
      join private.stripe_job_payment_intents p on p.id = a.payment_intent_id
      left join lateral (
        select d.receipt_id, d.order_number from private.financial_documents d
        where d.owner_id = actor and d.source_id = p.id
        order by d.created_at desc, d.id desc limit 1
      ) doc on true
      where actor in (p.adult_id, p.teen_id)
      union all
      select l.id, 'ledger', l.event_type,
        case l.event_type
          when 'job_funding_principal' then 'Job funding' when 'service_fee' then 'MORT service fee'
          when 'worker_compensation' then 'Job earnings' when 'adult_refund' then 'Customer refund'
          when 'tip_principal' then 'Tip' when 'transfer' then 'Earnings transfer'
          when 'provider_refund' then 'Provider refund' when 'adjustment' then 'Payment adjustment'
          when 'reversal' then 'Payment reversal' else 'Payment activity' end,
        null::text, l.created_at, l.direction, l.amount_cents, l.currency_code,
        doc.receipt_id, doc.order_number, doc.receipt_id is null, null::text, null::text
      from private.stripe_financial_ledger_events l
      join private.stripe_job_payment_intents p on p.id = l.payment_intent_id
      left join lateral (
        select d.receipt_id, d.order_number from private.financial_documents d
        where d.owner_id = actor and (d.source_id = p.id or d.settlement_id = l.settlement_id)
        order by d.created_at desc, d.id desc limit 1
      ) doc on true
      where (p.adult_id = actor and l.event_type in (
          'job_funding_principal','service_fee','adult_refund','provider_refund','adjustment','reversal'
        )) or (p.teen_id = actor and l.event_type in (
          'worker_compensation','tip_principal','transfer','adjustment','reversal'
        ))
      union all
      select t.id, 'tip', 'tip',
        case when t.payer_id = actor then 'Tip payment' else 'Tip received' end,
        null::text, t.created_at, t.normalized_state, t.amount_cents, t.currency_code,
        doc.receipt_id, doc.order_number, doc.receipt_id is null, null::text, null::text
      from private.stripe_tip_attempts t
      left join lateral (
        select d.receipt_id, d.order_number from private.financial_documents d
        where d.owner_id = actor and d.tip_attempt_id = t.id
        order by d.created_at desc, d.id desc limit 1
      ) doc on true
      where actor in (t.payer_id, t.worker_id)
      union all
      select d.id, 'dispute', 'dispute', 'Payment dispute', null::text,
        d.opened_at, d.status, d.amount_cents, d.currency_code, null::text,
        null::text, true, null::text, d.reason_code
      from private.stripe_job_disputes d
      join private.stripe_job_payment_intents p on p.id = d.payment_intent_id
      where actor in (p.adult_id, p.teen_id)
      union all
      select po.id, 'payout', 'payout', 'Stripe payout',
        case when po.destination_last4 is null then po.destination_type
             else coalesce(po.destination_type, 'destination') || ' ending ' || po.destination_last4 end,
        po.created_at, po.status, po.amount_cents, po.currency_code, null::text,
        null::text, true, null::text, po.failure_code
      from private.stripe_payout_events po
      join private.stripe_connected_accounts ca on ca.id = po.connected_account_id
      where ca.user_id = actor
    ),
    filtered as (
      select e.* from events e
      where (p_cursor_at is null or (e.occurred_at, e.event_id) < (p_cursor_at, p_cursor_id))
        and (p_year is null or extract(year from e.occurred_at) = p_year)
        and (
          v_category is null or v_category = 'all'
          or (v_category = 'jobs' and e.event_kind in ('payment_attempt','receipt','ledger'))
          or (v_category = 'payments' and (e.event_kind = 'payment_attempt'
            or (e.event_kind = 'ledger' and e.event_type in ('job_funding_principal','service_fee'))))
          or (v_category = 'receipts' and e.receipt_id is not null)
          or (v_category = 'earnings' and (e.event_kind = 'payout'
            or (e.event_kind = 'ledger' and e.event_type in ('worker_compensation','transfer'))
            or e.document_type = 'TEEN_EARNINGS'))
          or (v_category = 'tips' and (e.event_kind = 'tip' or e.event_type = 'tip_principal'))
          or (v_category = 'refunds' and e.event_kind = 'ledger' and e.event_type in ('adult_refund','provider_refund'))
          or (v_category = 'failed' and upper(coalesce(e.status,'')) in ('DECLINED','FAILED','CANCELLED','FUNDING_FAILED'))
          or (v_category = 'adjustments' and e.event_kind = 'ledger' and e.event_type in ('adjustment','reversal'))
          or (v_category = 'disputed' and e.event_kind = 'dispute')
        )
        and (v_search is null
          or lower(coalesce(e.title,'')) like '%' || v_search || '%'
          or lower(coalesce(e.display_subtitle,'')) like '%' || v_search || '%'
          or lower(coalesce(e.receipt_id,'')) like '%' || v_search || '%'
          or lower(coalesce(e.order_number,'')) like '%' || v_search || '%')
    ),
    page as (
      select f.*, row_number() over (order by f.occurred_at desc, f.event_id desc) as rn
      from filtered f order by f.occurred_at desc, f.event_id desc limit v_limit + 1
    ),
    visible as (select * from page where rn <= v_limit)
    select jsonb_build_object(
      'items', coalesce(jsonb_agg(to_jsonb(visible) - 'rn'
        order by visible.occurred_at desc, visible.event_id desc), '[]'::jsonb),
      'next_cursor_at', case when (select count(*) from page) > v_limit
        then (select occurred_at from visible order by rn desc limit 1) else null end,
      'next_cursor_id', case when (select count(*) from page) > v_limit
        then (select event_id from visible order by rn desc limit 1) else null end
    ) from visible
  );
end;
$$;

revoke all on function public.get_my_financial_history_v2(
  timestamptz, uuid, integer, text, text, integer
) from public, anon;
grant execute on function public.get_my_financial_history_v2(
  timestamptz, uuid, integer, text, text, integer
) to authenticated;
