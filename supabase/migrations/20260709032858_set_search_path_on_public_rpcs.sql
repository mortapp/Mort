-- Set immutable/stable public RPC search paths explicitly to satisfy the
-- Supabase security advisor and avoid role-dependent search path behavior.

alter function public.scan_message_body(text) set search_path = public;
alter function public.get_my_entitlements() set search_path = public;
alter function public.record_paywall_event(public.paywall_event_type, text, text, text, text, text) set search_path = public;
alter function public.record_ad_impression(text, public.ad_format, text, boolean) set search_path = public;
alter function public.get_ad_eligibility(text, public.ad_format) set search_path = public;
alter function public.get_boosted_jobs() set search_path = public;
alter function public.admin_monetization_overview() set search_path = public;
alter function public.normalize_username(text) set search_path = public;
alter function public.validate_username(text) set search_path = public;
