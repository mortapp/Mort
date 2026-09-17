-- These SECURITY DEFINER helpers are implementation details used by policies,
-- triggers, and server-side routines. They are not API entry points and do
-- not need anonymous execution privileges. Keep authenticated execution
-- available for policy helpers that can be invoked during authenticated RLS
-- evaluation.
revoke execute on function private.can_view_support_member_record(uuid, uuid)
from public, anon;
revoke execute on function private.deactivate_push_on_deletion_request()
from public, anon;
revoke execute on function private.enforce_active_fcm_device_limit()
from public, anon;
revoke execute on function private.guard_work_earning_payment_status()
from public, anon;
revoke execute on function private.is_active_support_circle_member(uuid, uuid)
from public, anon;
revoke execute on function private.is_support_circle_owner(uuid, uuid)
from public, anon;
revoke execute on function private.push_quiet_until(
  public.notification_preferences,
  text,
  timestamptz
)
from public, anon;
revoke execute on function private.support_apply_response_targets()
from public, anon;
revoke execute on function private.take_push_rate_limit(uuid, text, integer, integer)
from public, anon;
revoke execute on function private.valid_timezone(text)
from public, anon;
