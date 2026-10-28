-- Return an explicit, authenticated, fail-closed status while no production
-- identity provider or signed session endpoint is configured.
create or replace function public.get_my_identity_verification_v2()
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $function$
begin
  if auth.uid() is null then
    raise exception using
      errcode = '42501',
      message = 'authentication_required';
  end if;

  return jsonb_build_object(
    'ok', true,
    'id', null,
    'role', null,
    'status', 'unverified',
    'evidence_route', null,
    'verification_level', 0,
    'marketplace_enabled', false,
    'guardian_mode_optional', true,
    'verification_mode', 'disabled',
    'production_verified', false,
    'sandbox_eligible', false,
    'test_mode', false,
    'submissions_enabled', false,
    'production_provider_available', false,
    'can_retry', false,
    'support_escalation_available', false,
    'documents_collected_by_mort', false,
    'provider', null,
    'provider_reference', null,
    'decision_source', null,
    'failure_code', 'production_provider_unavailable',
    'public_message', 'Identity verification is unavailable until an approved production provider is configured.',
    'evidence_types', '[]'::jsonb
  );
end;
$function$;

revoke all on function public.get_my_identity_verification_v2() from public, anon;
grant execute on function public.get_my_identity_verification_v2() to authenticated;

comment on function public.get_my_identity_verification_v2() is
  'Returns a fail-closed identity verification status for the signed-in user while no production provider is configured; it collects no identity data.';
