drop policy if exists jobs_select_visible on public.jobs;
create policy jobs_select_visible
on public.jobs for select to authenticated
using (
  (
    status = 'open'
    and (
      not is_test
      or poster_id = auth.uid()
      or public.is_admin()
      or exists (
        select 1
        from public.profiles p
        where p.id = auth.uid() and p.is_test_account
      )
    )
  )
  or poster_id = auth.uid()
  or public.is_admin()
  or exists (
    select 1
    from public.applications a
    where a.job_id = jobs.id
      and public.is_application_participant(a.id)
  )
);

