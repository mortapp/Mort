-- Defense-in-depth hardening for Stripe financial tables added after the
-- earlier financial access pass. Client access remains through caller-bound
-- RPCs/Edge Functions; no direct anon/authenticated table access is added.

alter table private.stripe_job_settlements enable row level security;
alter table private.stripe_job_settlements force row level security;
alter table private.stripe_financial_ledger_events enable row level security;
alter table private.stripe_financial_ledger_events force row level security;
alter table private.stripe_tip_attempts enable row level security;
alter table private.stripe_tip_attempts force row level security;
alter table private.stripe_tip_transfers enable row level security;
alter table private.stripe_tip_transfers force row level security;
alter table private.financial_document_sequences enable row level security;
alter table private.financial_document_sequences force row level security;
alter table private.financial_documents enable row level security;
alter table private.financial_documents force row level security;

revoke all on table private.stripe_job_settlements from public, anon, authenticated;
revoke all on table private.stripe_financial_ledger_events from public, anon, authenticated;
revoke all on table private.stripe_tip_attempts from public, anon, authenticated;
revoke all on table private.stripe_tip_transfers from public, anon, authenticated;
revoke all on table private.financial_document_sequences from public, anon, authenticated;
revoke all on table private.financial_documents from public, anon, authenticated;
