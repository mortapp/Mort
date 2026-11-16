-- Explicit deny-all RLS policies for the private-schema tables that currently
-- have RLS enabled but no policies.
--
-- These tables are already unreachable by API clients:
--   * the `private` schema is not exposed through the API gateway, and
--   * no table privileges are granted to `anon`/`authenticated`/`public`.
--
-- RLS with no policies denies every row by default, so this change is
-- semantically a no-op. It documents the deliberate lockout in the catalog
-- (defense-in-depth: policy layer on top of the schema/grant lockout) and
-- resolves the "RLS Enabled No Policy" advisor finding for these tables.

do $$
declare
  v_table text;
  v_tables text[] := array[
    'guardian_invite_accept_limits',
    'guardian_invite_codes',
    'job_execution_events',
    'job_execution_sessions',
    'job_pin_confirmation_requests',
    'job_private_location_access_events',
    'job_private_location_history',
    'job_private_location_requests',
    'job_private_locations',
    'job_safety_agreement_history',
    'message_moderation_log',
    'message_safety_rules',
    'mort_edge_action_limits',
    'mort_job_mutation_requests',
    'mort_onboarding_safety',
    'school_email_domains',
    'stripe_connected_accounts',
    'stripe_customers',
    'stripe_payment_intents',
    'stripe_runtime_controls',
    'stripe_webhook_events',
    'user_roles',
    'verification_provider_allowlist',
    'verification_provider_ingestion_keys',
    'verification_provider_results'
  ];
begin
  foreach v_table in array v_tables loop
    execute format(
      'drop policy if exists mort_private_deny_all on private.%I', v_table
    );
    execute format(
      'create policy mort_private_deny_all on private.%I
         as restrictive
         for all
         to authenticated, anon, public
         using (false)
         with check (false)',
      v_table
    );
  end loop;
end $$;
