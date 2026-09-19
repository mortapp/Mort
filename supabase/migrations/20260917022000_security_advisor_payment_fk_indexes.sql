-- Add indexes for payment foreign keys that are used by joins and deletes but
-- are not the leading column of an existing composite index.
create index if not exists financial_documents_settlement_id_idx
on private.financial_documents (settlement_id);

create index if not exists financial_documents_tip_attempt_id_idx
on private.financial_documents (tip_attempt_id);

create index if not exists stripe_financial_ledger_events_payment_intent_id_idx
on private.stripe_financial_ledger_events (payment_intent_id);

create index if not exists stripe_financial_ledger_events_settlement_id_idx
on private.stripe_financial_ledger_events (settlement_id);

create index if not exists stripe_job_funding_quotes_contract_version_id_idx
on private.stripe_job_funding_quotes (contract_version_id);

create index if not exists stripe_job_funding_quotes_payer_id_idx
on private.stripe_job_funding_quotes (payer_id);

create index if not exists stripe_job_payment_attempts_initiated_by_idx
on private.stripe_job_payment_attempts (initiated_by);

create index if not exists stripe_job_payment_intents_funding_quote_id_idx
on private.stripe_job_payment_intents (funding_quote_id);

create index if not exists stripe_job_payment_intents_obligation_id_idx
on private.stripe_job_payment_intents (obligation_id);

create index if not exists stripe_job_settlements_contract_id_idx
on private.stripe_job_settlements (contract_id);

create index if not exists stripe_job_settlements_funding_quote_id_idx
on private.stripe_job_settlements (funding_quote_id);

create index if not exists stripe_job_settlements_policy_version_id_idx
on private.stripe_job_settlements (policy_version_id);

create index if not exists stripe_job_transfers_connected_account_id_idx
on private.stripe_job_transfers (connected_account_id);

create index if not exists stripe_tip_attempts_job_id_idx
on private.stripe_tip_attempts (job_id);

create index if not exists stripe_tip_attempts_payer_id_idx
on private.stripe_tip_attempts (payer_id);

create index if not exists stripe_tip_attempts_policy_version_id_idx
on private.stripe_tip_attempts (policy_version_id);

create index if not exists stripe_tip_attempts_settlement_id_idx
on private.stripe_tip_attempts (settlement_id);

create index if not exists stripe_tip_attempts_worker_id_idx
on private.stripe_tip_attempts (worker_id);

create index if not exists stripe_tip_transfers_connected_account_id_idx
on private.stripe_tip_transfers (connected_account_id);
