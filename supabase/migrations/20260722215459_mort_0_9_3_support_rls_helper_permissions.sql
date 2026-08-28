-- These security-definer boolean helpers are referenced by RLS policies. The
-- policy caller needs EXECUTE, while the private schema itself remains hidden.
grant execute on function private.can_access_support_ticket(uuid, uuid)
to authenticated;
grant execute on function private.can_access_support_evidence(uuid, uuid)
to authenticated;
