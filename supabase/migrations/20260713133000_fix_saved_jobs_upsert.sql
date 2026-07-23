create policy saved_jobs_update_own
on public.saved_jobs for update to authenticated
using (user_id = auth.uid())
with check (
  user_id = auth.uid()
  and public.current_profile_role() = 'teen'
  and exists (
    select 1
    from public.jobs j
    where j.id = job_id
      and j.status = 'open'
      and (not j.is_test or public.current_profile_is_test())
  )
);

grant update on public.saved_jobs to authenticated;

