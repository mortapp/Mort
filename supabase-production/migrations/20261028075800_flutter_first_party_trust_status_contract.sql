-- Keep the Flutter trust-status surface backed by the current production
-- release controls. Provider-dependent capabilities remain explicitly off
-- until a real provider and its launch gates are configured.
create or replace function public.get_first_party_trust_status()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_marketplace_enabled boolean;
  v_maintenance_mode boolean;
  v_real_document_collection boolean;
  v_payments_enabled boolean;
  v_updated_at timestamptz;
begin
  if auth.uid() is null then
    raise exception using
      errcode = '42501',
      message = 'authentication_required';
  end if;

  select
    release.public_marketplace_enabled,
    release.maintenance_mode,
    release.real_document_collection,
    stripe.mode = 'live'
      and stripe.payments_enabled
      and stripe.job_funding_enabled,
    greatest(release.updated_at, stripe.updated_at)
  into
    v_marketplace_enabled,
    v_maintenance_mode,
    v_real_document_collection,
    v_payments_enabled,
    v_updated_at
  from public.mort_release_control as release
  cross join private.stripe_runtime_controls as stripe
  where release.is_primary and stripe.singleton;

  if not found then
    return jsonb_build_object(
      'ok', false,
      'real_document_collection_enabled', false,
      'external_web_reuse_enabled', false,
      'real_live_presence_enabled', false,
      'real_appearance_review_enabled', false,
      'synthetic_qa_only', true,
      'authoritative_identity_provider_connected', false,
      'public_marketplace_open', false,
      'payments_enabled', false,
      'maintenance_mode', true,
      'document_quality_is_identity', false,
      'web_reuse_is_authenticity', false,
      'liveness_is_legal_identity', false,
      'device_biometric_is_legal_identity', false,
      'guardian_mode_optional', true,
      'status_updated_at', null
    );
  end if;

  return jsonb_build_object(
    'ok', true,
    'real_document_collection_enabled', v_real_document_collection,
    'external_web_reuse_enabled', false,
    'real_live_presence_enabled', false,
    'real_appearance_review_enabled', false,
    'synthetic_qa_only', true,
    'authoritative_identity_provider_connected', false,
    'public_marketplace_open', v_marketplace_enabled and not v_maintenance_mode,
    'payments_enabled', v_payments_enabled,
    'maintenance_mode', v_maintenance_mode,
    'document_quality_is_identity', false,
    'web_reuse_is_authenticity', false,
    'liveness_is_legal_identity', false,
    'device_biometric_is_legal_identity', false,
    'guardian_mode_optional', true,
    'status_updated_at', v_updated_at
  );
end;
$function$;

revoke all on function public.get_first_party_trust_status() from public, anon;
grant execute on function public.get_first_party_trust_status() to authenticated;

comment on function public.get_first_party_trust_status() is
  'Returns the current release and payment capability state to signed-in Flutter clients; provider-dependent trust capabilities fail closed.';

