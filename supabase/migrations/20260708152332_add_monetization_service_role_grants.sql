-- Additive grants for trusted Supabase service role automation and QA.
-- RLS remains enabled; service_role is server-only and must never be used in Expo/mobile code.

grant usage on type public.monetization_event_source to authenticated, service_role;
grant usage on type public.ad_format to authenticated, service_role;
grant usage on type public.boost_status to authenticated, service_role;
grant usage on type public.paywall_event_type to authenticated, service_role;

grant select, insert, update, delete on
  public.monetization_entitlements_cache,
  public.revenuecat_events,
  public.user_subscription_status,
  public.user_ad_preferences,
  public.ad_impressions,
  public.ad_click_events,
  public.ad_frequency_caps,
  public.purchase_audit_logs,
  public.premium_feature_usage,
  public.boosted_jobs,
  public.boost_impressions,
  public.monetization_experiments,
  public.paywall_events
to service_role;

grant execute on function public.get_my_entitlements() to service_role;
grant execute on function public.record_paywall_event(public.paywall_event_type, text, text, text, text, text) to service_role;
grant execute on function public.record_ad_impression(text, public.ad_format, text, boolean) to service_role;
grant execute on function public.get_ad_eligibility(text, public.ad_format) to service_role;
grant execute on function public.get_boosted_jobs() to service_role;
grant execute on function public.admin_monetization_overview() to service_role;
