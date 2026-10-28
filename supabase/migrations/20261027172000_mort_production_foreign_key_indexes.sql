-- Add child-side indexes for production reconciliation and guardian audit lookups.
create index if not exists stripe_payment_intents_payer_id_idx
  on private.stripe_payment_intents (payer_id);

create index if not exists stripe_payment_intents_payee_id_idx
  on private.stripe_payment_intents (payee_id);

create index if not exists guardian_links_revoked_by_idx
  on public.guardian_links (revoked_by);

create index if not exists job_applications_guardian_id_idx
  on public.job_applications (guardian_id);
