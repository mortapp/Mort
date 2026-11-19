-- Exact statements from production ledger version 20261114180110
do $$
declare
  v_table text;
  v_tables text[] := array[
    'guardian_invite_accept_limits','guardian_invite_codes','job_execution_events','job_execution_sessions',
    'job_pin_confirmation_requests','job_private_location_access_events','job_private_location_history',
    'job_private_location_requests','job_private_locations','job_safety_agreement_history','message_moderation_log',
    'message_safety_rules','mort_edge_action_limits','mort_job_mutation_requests','mort_onboarding_safety',
    'school_email_domains','stripe_connected_accounts','stripe_customers','stripe_payment_intents',
    'stripe_runtime_controls','stripe_webhook_events','user_roles','verification_provider_allowlist',
    'verification_provider_ingestion_keys','verification_provider_results'
  ];
begin
  foreach v_table in array v_tables loop
    if exists (select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='private' and c.relname=v_table and c.relkind in ('r','p')) then
      execute format('drop policy if exists mort_private_deny_all on private.%I', v_table);
      execute format('create policy mort_private_deny_all on private.%I as restrictive for all to authenticated, anon, public using (false) with check (false)', v_table);
    end if;
  end loop;
end $$;
