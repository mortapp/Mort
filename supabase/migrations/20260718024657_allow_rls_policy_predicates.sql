-- PostgreSQL checks EXECUTE privilege when an RLS expression invokes a
-- security-definer predicate. The private schema is not Data API exposed;
-- these helpers return authorization booleans and no restricted row data.

grant execute on function private.has_admin_safety_role(
  uuid,
  public.admin_safety_role[]
) to authenticated, service_role;

grant execute on function private.marketplace_identity_level(uuid)
to authenticated, service_role;

grant execute on function private.has_marketplace_identity(uuid)
to authenticated, service_role;

grant execute on function private.is_incident_participant(uuid, uuid)
to authenticated, service_role;

grant execute on function private.can_manage_incident(uuid)
to authenticated, service_role;

grant execute on function private.can_view_report(uuid, uuid)
to authenticated, service_role;

grant execute on function private.is_job_safety_participant(uuid, uuid)
to authenticated, service_role;

grant execute on function private.is_safety_circle_participant(uuid, uuid)
to authenticated, service_role;
