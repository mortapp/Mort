-- Keep financial documents immutable while allowing the owner FK's
-- ON DELETE SET NULL action to remove the direct account reference.
create or replace function private.prevent_financial_document_mutation_v1()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE'
     and old.owner_id is not null
     and new.owner_id is null
     and (pg_catalog.to_jsonb(old) - 'owner_id')
       = (pg_catalog.to_jsonb(new) - 'owner_id') then
    return new;
  end if;

  raise exception 'financial_document_immutable';
end;
$$;
