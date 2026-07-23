create or replace function public.current_profile_is_test()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce((
    select p.is_test_account
    from public.profiles p
    where p.id = auth.uid()
  ), false);
$$;

revoke execute on function public.current_profile_is_test() from public, anon;
grant execute on function public.current_profile_is_test()
to authenticated, service_role;

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
      and (not j.is_test or public.current_profile_is_test())
  )
);

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
      or public.current_profile_is_test()
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
  or exists (
    select 1
    from public.saved_jobs sj
    where sj.job_id = jobs.id and sj.user_id = auth.uid()
  )
);

