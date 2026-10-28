-- Production-critical child-side indexes for frequently reconciled records.
do $$
begin
  if to_regclass('private.stripe_payment_intents_payer_id_idx') is null
    or to_regclass('private.stripe_payment_intents_payee_id_idx') is null
    or to_regclass('public.guardian_links_revoked_by_idx') is null
    or to_regclass('public.job_applications_guardian_id_idx') is null then
    raise exception 'production_foreign_key_indexes_missing';
  end if;
end;
$$;
