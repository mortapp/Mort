-- Guardian relationships must only be created or transitioned by guarded RPCs.
-- Direct client INSERT allowed callers to pre-populate both consent timestamps,
-- then activate a guardian link without the teen completing the invite flow.

REVOKE INSERT, UPDATE, DELETE ON TABLE public.guardian_links FROM anon, authenticated;
DROP POLICY IF EXISTS guardian_links_insert_initiator ON public.guardian_links;

-- Keep SELECT for participants/staff through the existing RLS policy.
-- SECURITY DEFINER RPCs owned by postgres retain the controlled write path:
-- create_guardian_invite_v2, accept_guardian_invite, mort_set_guardian_consent,
-- cancel_guardian_invite, and unlink_guardian.
