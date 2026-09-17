create table private.financial_document_sequences (
  document_date date primary key,
  next_sequence integer not null default 1 check (next_sequence > 0)
);

create table private.financial_documents (
  id uuid primary key default gen_random_uuid(),
  document_type text not null check (document_type in (
    'ADULT_JOB_PAYMENT', 'TEEN_EARNINGS', 'STORE_PURCHASE', 'TIP',
    'FULL_REFUND', 'PARTIAL_REFUND', 'ADJUSTMENT', 'REVERSAL'
  )),
  owner_id uuid not null references auth.users(id) on delete restrict,
  owner_role text not null check (owner_role in ('adult', 'teen', 'operator')),
  source_type text not null check (source_type in ('job_payment', 'tip', 'refund', 'store_purchase', 'adjustment', 'reversal')),
  source_id uuid not null,
  settlement_id uuid references private.stripe_job_settlements(id) on delete restrict,
  tip_attempt_id uuid references private.stripe_tip_attempts(id) on delete restrict,
  receipt_id text not null unique check (receipt_id ~ '^[A-HJ-KM-NP-Z]-[0-9]{6}-[0-9]{5}$'),
  order_number text not null check (order_number ~ '^[0-9]{4}$'),
  document_date date not null,
  amount_cents integer not null check (amount_cents >= 0),
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  status text not null check (status in ('pending', 'succeeded', 'failed', 'refunded', 'reversed', 'adjusted')),
  masked_provider_reference text check (
    masked_provider_reference is null or masked_provider_reference ~ '^[A-Za-z0-9_*.-]{4,32}$'
  ),
  immutable_snapshot jsonb not null check (jsonb_typeof(immutable_snapshot) = 'object'),
  linked_document_refs jsonb not null default '[]'::jsonb check (jsonb_typeof(linked_document_refs) = 'array'),
  created_at timestamptz not null default statement_timestamp(),
  unique (owner_id, source_type, source_id, document_type)
);

create index financial_documents_owner_created_idx
  on private.financial_documents(owner_id, created_at desc, id);
create index financial_documents_owner_date_idx
  on private.financial_documents(owner_id, document_date desc, id);

create or replace function private.prevent_financial_document_mutation_v1()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'financial_document_immutable';
end;
$$;

create trigger financial_documents_immutable
before update or delete on private.financial_documents
for each row execute function private.prevent_financial_document_mutation_v1();

create or replace function public.stripe_server_issue_financial_document_v1(
  p_document_type text,
  p_owner_id uuid,
  p_owner_role text,
  p_source_type text,
  p_source_id uuid,
  p_settlement_id uuid,
  p_tip_attempt_id uuid,
  p_amount_cents integer,
  p_currency_code text,
  p_status text,
  p_masked_provider_reference text,
  p_immutable_snapshot jsonb,
  p_linked_document_refs jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_date date := (statement_timestamp() at time zone 'UTC')::date;
  v_sequence integer;
  v_order_number text;
  v_receipt_id text;
  v_document private.financial_documents%rowtype;
  v_forbidden text[] := array[
    'legal_name', 'exact_address', 'email', 'phone', 'bank_account',
    'identity_details', 'client_secret', 'secret_key', 'webhook_secret'
  ];
  v_key text;
begin
  perform private.require_stripe_service_role();
  if p_amount_cents is null or p_amount_cents < 0 or p_currency_code !~ '^[A-Z]{3}$'
     or jsonb_typeof(coalesce(p_immutable_snapshot, '{}'::jsonb)) <> 'object'
     or jsonb_typeof(coalesce(p_linked_document_refs, '[]'::jsonb)) <> 'array' then
    raise exception 'financial_document_inputs_invalid';
  end if;
  foreach v_key in array v_forbidden loop
    if p_immutable_snapshot ? v_key then raise exception 'financial_document_privacy_violation'; end if;
  end loop;

  select * into v_document
    from private.financial_documents
   where owner_id = p_owner_id
     and source_type = p_source_type
     and source_id = p_source_id
     and document_type = p_document_type;
  if v_document.id is not null then
    return jsonb_build_object('ok', true, 'document_id', v_document.id, 'receipt_id', v_document.receipt_id, 'idempotent', true);
  end if;

  insert into private.financial_document_sequences(document_date, next_sequence)
  values (v_date, 2)
  on conflict (document_date) do update set next_sequence = private.financial_document_sequences.next_sequence + 1
  returning next_sequence - 1 into v_sequence;
  if v_sequence > 9999 then raise exception 'daily_receipt_sequence_exhausted'; end if;
  v_order_number := lpad((v_sequence % 10000)::text, 4, '0');
  v_receipt_id := substr('ABCDEFGHJKMNPQRSTUVWXYZ', 1 + floor(random() * 23)::integer, 1)
    || '-' || to_char(v_date, 'YYMMDD') || '-' || lpad(v_sequence::text, 5, '0');

  insert into private.financial_documents (
    document_type, owner_id, owner_role, source_type, source_id, settlement_id,
    tip_attempt_id, receipt_id, order_number, document_date, amount_cents,
    currency_code, status, masked_provider_reference, immutable_snapshot, linked_document_refs
  )
  values (
    p_document_type, p_owner_id, p_owner_role, p_source_type, p_source_id, p_settlement_id,
    p_tip_attempt_id, v_receipt_id, v_order_number, v_date, p_amount_cents,
    p_currency_code, p_status, p_masked_provider_reference, p_immutable_snapshot, p_linked_document_refs
  )
  returning * into v_document;
  return jsonb_build_object('ok', true, 'document_id', v_document.id,
    'receipt_id', v_document.receipt_id, 'order_number', v_document.order_number, 'idempotent', false);
end;
$$;

create or replace function public.stripe_server_issue_settlement_documents_v1(
  p_settlement_id uuid,
  p_adult_snapshot jsonb,
  p_teen_snapshot jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  settlement private.stripe_job_settlements%rowtype;
  payment private.stripe_job_payment_intents%rowtype;
  adult_document jsonb;
  teen_document jsonb;
begin
  perform private.require_stripe_service_role();
  select * into settlement from private.stripe_job_settlements where id = p_settlement_id for share;
  if settlement.id is null then raise exception 'settlement_not_found'; end if;
  select * into payment from private.stripe_job_payment_intents where id = settlement.payment_intent_id for share;
  select public.stripe_server_issue_financial_document_v1(
    'ADULT_JOB_PAYMENT', payment.adult_id, 'adult', 'job_payment', payment.id,
    settlement.id, null, payment.total_amount_cents, payment.currency_code, 'succeeded',
    case when payment.provider_charge_id is null then null else 'ch_' || right(payment.provider_charge_id, 4) end,
    p_adult_snapshot, '[]'::jsonb
  ) into adult_document;
  select public.stripe_server_issue_financial_document_v1(
    'TEEN_EARNINGS', payment.teen_id, 'teen', 'job_payment', payment.id,
    settlement.id, null, settlement.compensated_base_cents, payment.currency_code, 'succeeded',
    case when payment.provider_charge_id is null then null else 'ch_' || right(payment.provider_charge_id, 4) end,
    p_teen_snapshot, jsonb_build_array(adult_document->>'receipt_id')
  ) into teen_document;
  return jsonb_build_object('ok', true, 'adult', adult_document, 'teen', teen_document);
end;
$$;

create or replace function public.get_my_financial_document_v1(p_receipt_id text)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select to_jsonb(document)
    from (
      select id, document_type, receipt_id, order_number, document_date,
        amount_cents, currency_code, status, masked_provider_reference,
        immutable_snapshot, linked_document_refs, created_at
      from private.financial_documents
      where owner_id = auth.uid() and receipt_id = p_receipt_id
    ) document
$$;


create or replace function public.get_my_financial_history_v1(
  p_cursor timestamptz default null,
  p_year integer default null,
  p_category text default null,
  p_search text default null,
  p_limit integer default 50
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select jsonb_build_object(
    'items', coalesce(jsonb_agg(to_jsonb(page) order by page.created_at desc, page.id desc), '[]'::jsonb),
    'next_cursor', max(page.created_at)
  )
  from (
    select
      id, document_type, receipt_id, order_number, document_date,
      amount_cents, currency_code, status, masked_provider_reference,
      immutable_snapshot, linked_document_refs, created_at
    from private.financial_documents
    where owner_id = auth.uid()
      and (p_cursor is null or created_at < p_cursor)
      and (p_year is null or extract(year from document_date) = p_year)
      and (p_category is null or p_category = 'All' or lower(document_type) like '%' || lower(p_category) || '%')
      and (
        p_search is null
        or receipt_id ilike '%' || p_search || '%'
        or order_number ilike '%' || p_search || '%'
        or immutable_snapshot->>'job_title' ilike '%' || p_search || '%'
        or immutable_snapshot->>'display_username' ilike '%' || p_search || '%'
      )
    order by created_at desc, id desc
    limit greatest(1, least(coalesce(p_limit, 50), 100))
  ) page
$$;

revoke all on function public.stripe_server_issue_financial_document_v1(
  text, uuid, text, text, uuid, uuid, uuid, integer, text, text, text, jsonb, jsonb
) from public, anon, authenticated;
grant execute on function public.stripe_server_issue_financial_document_v1(
  text, uuid, text, text, uuid, uuid, uuid, integer, text, text, text, jsonb, jsonb
) to service_role;
revoke all on function public.stripe_server_issue_settlement_documents_v1(uuid, jsonb, jsonb)
  from public, anon, authenticated;
grant execute on function public.stripe_server_issue_settlement_documents_v1(uuid, jsonb, jsonb)
  to service_role;
revoke all on function public.get_my_financial_history_v1(timestamptz, integer, text, text, integer)
  from public, anon;
grant execute on function public.get_my_financial_history_v1(timestamptz, integer, text, text, integer)
  to authenticated;
revoke all on function public.get_my_financial_document_v1(text) from public, anon;
grant execute on function public.get_my_financial_document_v1(text) to authenticated;