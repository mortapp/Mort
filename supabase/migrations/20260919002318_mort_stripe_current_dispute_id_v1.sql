alter table private.stripe_job_disputes
  drop constraint if exists stripe_job_disputes_provider_dispute_id_check;

alter table private.stripe_job_disputes
  add constraint stripe_job_disputes_provider_dispute_id_check
  check (provider_dispute_id ~ '^(dp|du)_[A-Za-z0-9]+$');
