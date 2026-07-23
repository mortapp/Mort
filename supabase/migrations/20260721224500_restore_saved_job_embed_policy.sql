begin;

drop policy if exists jobs_select_visible on public.jobs;
create policy jobs_select_visible
on public.jobs for select to authenticated
using (
  private.can_view_marketplace_job(id)
  or exists (
    select 1
    from public.saved_jobs saved
    where saved.job_id = jobs.id
      and saved.user_id = (select auth.uid())
  )
);

comment on policy jobs_select_visible on public.jobs
is 'Server-gated marketplace visibility plus owner-isolated saved-job history for unavailable jobs.';

commit;
