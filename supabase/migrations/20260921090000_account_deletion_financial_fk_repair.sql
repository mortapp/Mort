-- Financial records remain available for retention and dispute purposes after
-- an eligible account deletion, while their direct user identifiers are
-- severed. The guards keep this repair safe on partial development histories;
-- the production migration history contains all three tables.

do $$
begin
  if to_regclass('private.financial_documents') is not null then
    alter table private.financial_documents
      drop constraint if exists financial_documents_owner_id_fkey;
    alter table private.financial_documents alter column owner_id drop not null;
    alter table private.financial_documents
      add constraint financial_documents_owner_id_fkey
      foreign key (owner_id) references auth.users(id) on delete set null;
  end if;

  if to_regclass('private.stripe_job_funding_quotes') is not null then
    alter table private.stripe_job_funding_quotes
      drop constraint if exists stripe_job_funding_quotes_payer_id_fkey;
    alter table private.stripe_job_funding_quotes
      drop constraint if exists stripe_job_funding_quotes_worker_id_fkey;
    alter table private.stripe_job_funding_quotes alter column payer_id drop not null;
    alter table private.stripe_job_funding_quotes alter column worker_id drop not null;
    alter table private.stripe_job_funding_quotes
      add constraint stripe_job_funding_quotes_payer_id_fkey
      foreign key (payer_id) references auth.users(id) on delete set null;
    alter table private.stripe_job_funding_quotes
      add constraint stripe_job_funding_quotes_worker_id_fkey
      foreign key (worker_id) references auth.users(id) on delete set null;
  end if;

  if to_regclass('private.stripe_tip_attempts') is not null then
    alter table private.stripe_tip_attempts
      drop constraint if exists stripe_tip_attempts_payer_id_fkey;
    alter table private.stripe_tip_attempts
      drop constraint if exists stripe_tip_attempts_worker_id_fkey;
    alter table private.stripe_tip_attempts alter column payer_id drop not null;
    alter table private.stripe_tip_attempts alter column worker_id drop not null;
    alter table private.stripe_tip_attempts
      add constraint stripe_tip_attempts_payer_id_fkey
      foreign key (payer_id) references auth.users(id) on delete set null;
    alter table private.stripe_tip_attempts
      add constraint stripe_tip_attempts_worker_id_fkey
      foreign key (worker_id) references auth.users(id) on delete set null;
  end if;
end;
$$;
