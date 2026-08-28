drop policy if exists saved_jobs_insert_own on public.saved_jobs;
create policy saved_jobs_insert_own
on public.saved_jobs for insert to authenticated
with check (
  user_id = auth.uid()
  and public.current_profile_role() = 'teen'
  and exists (
    select 1
    from public.jobs j
    where j.id = job_id
      and j.status = 'open'
      and (
        not j.is_test
        or exists (
          select 1
          from public.profiles p
          where p.id = auth.uid() and p.is_test_account
        )
      )
  )
);

