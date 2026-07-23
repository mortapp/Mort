-- Later profile-column grant hardening made this caller-bound RPC unable to
-- read its own server inputs. Preserve auth.uid() ownership while allowing the
-- function to read only the rows needed for a minimized eligibility result.

alter function public.get_ad_eligibility(text, public.ad_format)
security definer;

alter function public.get_ad_eligibility(text, public.ad_format)
set search_path = public, pg_temp;

revoke execute on function public.get_ad_eligibility(text, public.ad_format)
from public, anon;

grant execute on function public.get_ad_eligibility(text, public.ad_format)
to authenticated, service_role;
