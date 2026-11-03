begin;

create extension if not exists pgtap with schema extensions;
set local search_path = extensions, public;

select plan(7);

select ok(
  (
    select count(*) = 5
    from pg_constraint fk
    join pg_class table_row on table_row.oid = fk.conrelid
    join pg_namespace schema_row on schema_row.oid = table_row.relnamespace
    where fk.contype = 'f'
      and schema_row.nspname = 'private'
      and table_row.relname in (
        'financial_documents',
        'stripe_job_funding_quotes',
        'stripe_tip_attempts'
      )
      and fk.confrelid = 'auth.users'::regclass
      and fk.confdeltype = 'n'
  )
  and (
    select count(*) = 5
    from information_schema.columns
    where table_schema = 'private'
      and is_nullable = 'YES'
      and (
        (table_name = 'financial_documents' and column_name = 'owner_id')
        or (table_name in ('stripe_job_funding_quotes', 'stripe_tip_attempts')
          and column_name in ('payer_id', 'worker_id'))
      )
  )
  and exists (
    select 1
    from information_schema.columns column_row
    where column_row.table_schema = 'private'
      and column_row.table_name = 'financial_documents'
      and column_row.column_name = 'owner_id'
      and column_row.is_nullable = 'YES'
  ),
  'all financial user references are nullable and deidentify on account deletion'
);

insert into auth.users (id) values
  ('10000000-0000-0000-0000-000000000001'),
  ('10000000-0000-0000-0000-000000000002');

insert into private.financial_documents (
  id,
  document_type,
  owner_id,
  owner_role,
  source_type,
  source_id,
  receipt_id,
  order_number,
  document_date,
  amount_cents,
  currency_code,
  status,
  immutable_snapshot
) values (
  '20000000-0000-0000-0000-000000000001',
  'ADULT_JOB_PAYMENT',
  '10000000-0000-0000-0000-000000000001',
  'adult',
  'job_payment',
  '30000000-0000-0000-0000-000000000001',
  'A-000001-00001',
  '0001',
  current_date,
  123,
  'USD',
  'succeeded',
  '{"source":"account-deletion-test"}'::jsonb
);

delete from auth.users
where id = '10000000-0000-0000-0000-000000000001';

select is(
  (select owner_id from private.financial_documents
   where id = '20000000-0000-0000-0000-000000000001'),
  null::uuid,
  'account deletion nulls the financial document owner'
);

select throws_ok(
  $$
    update private.financial_documents
    set amount_cents = 124
    where id = '20000000-0000-0000-0000-000000000001'
  $$,
  'P0001',
  'financial_document_immutable',
  'financial document contents remain immutable'
);

select throws_ok(
  $$
    update private.financial_documents
    set owner_id = '10000000-0000-0000-0000-000000000002'
    where id = '20000000-0000-0000-0000-000000000001'
  $$,
  'P0001',
  'financial_document_immutable',
  'financial document ownership cannot be reassigned'
);

select throws_ok(
  $$
    delete from private.financial_documents
    where id = '20000000-0000-0000-0000-000000000001'
  $$,
  'P0001',
  'financial_document_immutable',
  'financial documents cannot be deleted'
);

select is(
  (select amount_cents from private.financial_documents
   where id = '20000000-0000-0000-0000-000000000001'),
  123,
  'owner deidentification does not weaken financial document immutability'
);

select is(
  (select immutable_snapshot->>'source' from private.financial_documents
   where id = '20000000-0000-0000-0000-000000000001'),
  'account-deletion-test',
  'the immutable financial snapshot survives account deletion'
);

select * from finish();
rollback;
