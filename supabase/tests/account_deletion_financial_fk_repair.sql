do $$
declare
  bad_fk_count integer;
  nonnullable_count integer;
begin
  select count(*) into bad_fk_count
  from pg_constraint constraint_row
  join pg_class table_row on table_row.oid = constraint_row.conrelid
  join pg_namespace schema_row on schema_row.oid = table_row.relnamespace
  where constraint_row.contype = 'f'
    and schema_row.nspname = 'private'
    and table_row.relname in (
      'financial_documents',
      'stripe_job_funding_quotes',
      'stripe_tip_attempts'
    )
    and constraint_row.confrelid = 'auth.users'::regclass
    and constraint_row.confdeltype <> 'n';

  if bad_fk_count <> 0 then
    raise exception 'financial user foreign keys are not all ON DELETE SET NULL';
  end if;

  select count(*) into nonnullable_count
  from information_schema.columns
  where table_schema = 'private'
    and (
      (table_name = 'financial_documents' and column_name = 'owner_id')
      or (table_name in ('stripe_job_funding_quotes', 'stripe_tip_attempts')
        and column_name in ('payer_id', 'worker_id'))
    )
    and is_nullable <> 'YES';

  if nonnullable_count <> 0 then
    raise exception 'financial user columns are not all nullable';
  end if;
end;
$$;

insert into auth.users (id) values
  ('10000000-0000-0000-0000-000000000001'),
  ('10000000-0000-0000-0000-000000000002');

insert into private.financial_documents (id, owner_id) values
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001');
insert into private.stripe_job_funding_quotes (id, payer_id, worker_id) values
  ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002');
insert into private.stripe_tip_attempts (id, payer_id, worker_id) values
  ('20000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002');

delete from auth.users where id = '10000000-0000-0000-0000-000000000001';

do $$
begin
  if (select owner_id is not null from private.financial_documents limit 1) then
    raise exception 'financial document owner was not deidentified';
  end if;
  if (select payer_id is not null or worker_id is null from private.stripe_job_funding_quotes limit 1) then
    raise exception 'funding quote user links were not deidentified selectively';
  end if;
  if (select payer_id is not null or worker_id is null from private.stripe_tip_attempts limit 1) then
    raise exception 'tip attempt user links were not deidentified selectively';
  end if;
end;
$$;

select 'account deletion financial FK repair certification passed' as result;
