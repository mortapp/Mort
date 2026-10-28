-- Public, non-sensitive runtime status used by the Flutter release dashboard.
-- This project uses mort_release_control and stripe_runtime_controls; do not
-- restore the retired closed-pilot runtime_feature_controls table.
create or replace function public.get_runtime_feature_status()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $function$
  select coalesce(
    (
      select jsonb_build_object(
        'ok', true,
        'maintenance_mode', release.maintenance_mode,
        -- AI is fail-closed until a production provider is configured.
        'ai_provider_disabled', true,
        'payments_disabled', not (
          stripe.mode = 'live'
          and stripe.payments_enabled
          and stripe.job_funding_enabled
        ),
        'new_job_publishing_disabled',
          not release.public_marketplace_enabled or release.maintenance_mode,
        'public_marketplace_closed', not release.public_marketplace_enabled,
        'real_document_collection', release.real_document_collection,
        'status_updated_at', greatest(release.updated_at, stripe.updated_at),
        'maintenance_message', case
          when release.maintenance_mode then
            'MORT is temporarily unavailable while safety or reliability work is completed.'
          else null
        end
      )
      from public.mort_release_control as release
      cross join private.stripe_runtime_controls as stripe
      where release.is_primary and stripe.singleton
    ),
    jsonb_build_object(
      'ok', false,
      'maintenance_mode', true,
      'ai_provider_disabled', true,
      'payments_disabled', true,
      'new_job_publishing_disabled', true,
      'public_marketplace_closed', true,
      'real_document_collection', false,
      'status_updated_at', null,
      'maintenance_message',
        'MORT runtime controls are unavailable. Operations are fail-closed.'
    )
  );
$function$;

revoke all on function public.get_runtime_feature_status() from public;
grant execute on function public.get_runtime_feature_status()
  to anon, authenticated, service_role;

comment on function public.get_runtime_feature_status() is
  'Returns non-sensitive production runtime gates from release and Stripe controls for the Flutter app; missing controls fail closed.';
