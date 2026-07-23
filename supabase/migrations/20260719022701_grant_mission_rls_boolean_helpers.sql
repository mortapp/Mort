-- Required only for RLS evaluation. The private schema is not exposed through
-- the Data API, and this helper returns a boolean without queue data.
grant execute on function private.has_trust_admin_role(uuid, text[])
to authenticated;
