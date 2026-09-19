create unique index if not exists stripe_job_payment_intents_quote_unique_idx
on private.stripe_job_payment_intents (environment, funding_quote_id);