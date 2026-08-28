-- RLS policies execute this private predicate as the authenticated database
-- role. Grant only the predicate needed by policy evaluation; the private
-- schema remains outside the exposed API schemas and no DOB is returned.
revoke all on function private.is_minor_teen(uuid) from public, anon;
grant execute on function private.is_minor_teen(uuid) to authenticated, service_role;

comment on function private.is_minor_teen(uuid) is
'Private boolean age-band predicate used by Guardian Mode RLS. It does not return DOB or expose a PostgREST RPC.';
