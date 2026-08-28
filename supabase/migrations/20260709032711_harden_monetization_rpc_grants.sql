-- Harden grants for monetization and username RPCs added after the initial
-- baseline revoke. New functions inherit EXECUTE for PUBLIC unless revoked.

revoke execute on function public.protect_direct_username_update() from public, anon;
revoke execute on function public.normalize_username(text) from public, anon;
revoke execute on function public.validate_username(text) from public, anon;
revoke execute on function public.get_username_change_status() from public, anon;
revoke execute on function public.request_username_change(text) from public, anon;
revoke execute on function public.consume_username_change_credit() from public, anon;
revoke execute on function public.admin_grant_username_change_credit(uuid, integer, text) from public, anon;
revoke execute on function public.record_feature_usage(text, text, boolean) from public, anon;
revoke execute on function public.get_job_boost_credit_status() from public, anon;
revoke execute on function public.consume_job_boost_credit(uuid) from public, anon;

grant execute on function public.normalize_username(text) to authenticated, service_role;
grant execute on function public.validate_username(text) to authenticated, service_role;
grant execute on function public.get_username_change_status() to authenticated, service_role;
grant execute on function public.request_username_change(text) to authenticated, service_role;
grant execute on function public.consume_username_change_credit() to authenticated, service_role;
grant execute on function public.admin_grant_username_change_credit(uuid, integer, text) to authenticated, service_role;
grant execute on function public.record_feature_usage(text, text, boolean) to authenticated, service_role;
grant execute on function public.get_job_boost_credit_status() to authenticated, service_role;
grant execute on function public.consume_job_boost_credit(uuid) to authenticated, service_role;
