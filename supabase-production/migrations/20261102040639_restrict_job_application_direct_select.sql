-- Applied to production project jxbnrkasktbhtiujkhay on 2026-11-02.
-- Close direct table reads that expose Guardian identifiers.
-- The supported application reader is public.get_my_job_applications(uuid),
-- a SECURITY DEFINER RPC owned by postgres. Flutter reads applications
-- through that RPC; no Realtime publication includes this table.
begin;

revoke select on table public.job_applications from anon, authenticated;
drop policy if exists applications_select_parties on public.job_applications;

commit;
