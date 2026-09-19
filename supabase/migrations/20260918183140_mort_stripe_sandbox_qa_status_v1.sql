create or replace function public.stripe_server_get_sandbox_qa_status()
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  c private.stripe_runtime_controls%rowtype;
begin
  perform private.require_stripe_service_role();
  select * into c from private.stripe_runtime_controls where singleton;
  return jsonb_build_object(
    'mode', c.mode,
    'sandbox_provider_qa_approved', c.sandbox_provider_qa_approved,
    'payments_enabled', c.stripe_payments_enabled,
    'job_funding_enabled', c.stripe_job_funding_enabled,
    'transfers_enabled', c.stripe_transfers_enabled,
    'refunds_enabled', c.stripe_refunds_enabled,
    'live_mode_enabled', c.stripe_live_mode_enabled,
    'live_owner_approved', c.live_owner_approved
  );
end;
$$;

revoke all on function public.stripe_server_get_sandbox_qa_status() from public;
revoke all on function public.stripe_server_get_sandbox_qa_status() from anon;
revoke all on function public.stripe_server_get_sandbox_qa_status() from authenticated;
grant execute on function public.stripe_server_get_sandbox_qa_status() to service_role;
