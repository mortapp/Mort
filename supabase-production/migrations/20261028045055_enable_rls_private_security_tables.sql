-- These tables are implementation details in the private schema and are not
-- exposed through the Supabase Data API. Keep RLS enabled as defense in depth.
-- No client policies are added: application access is mediated by the existing
-- SECURITY DEFINER functions, whose owner retains access because FORCE RLS is
-- intentionally not enabled.
alter table private.user_roles enable row level security;
alter table private.mort_job_mutation_requests enable row level security;