-- Ensure all authenticated message sends use the idempotent safety RPC.
-- The legacy low-level SECURITY DEFINER function performs membership/block checks,
-- but direct callers can bypass the v2 request-id replay protection.

REVOKE INSERT, UPDATE, DELETE ON TABLE public.messages FROM anon, authenticated;
DROP POLICY IF EXISTS messages_insert_member ON public.messages;

REVOKE EXECUTE ON FUNCTION public.mort_send_message(uuid, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.mort_send_message(uuid, text) TO service_role;

-- send_safe_message_v2 remains the authenticated entry point and, as a postgres-owned
-- SECURITY DEFINER function, can invoke mort_send_message internally.
