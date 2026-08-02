-- Avoid referencing public.profiles from its own RLS policy. Minor status is
-- evaluated through the private security-definer predicate instead.
alter policy profiles_select_visible on public.profiles
to authenticated
using (
  id = (select auth.uid())
  or public.is_admin()
  or exists (
    select 1
    from public.guardian_connections connection
    where connection.status = 'active'
      and private.is_minor_teen(connection.teen_id)
      and (
        (connection.teen_id = profiles.id and connection.guardian_id = (select auth.uid()))
        or (connection.guardian_id = profiles.id and connection.teen_id = (select auth.uid()))
      )
  )
  or exists (
    select 1
    from public.applications application
    join public.jobs job on job.id = application.job_id
    where application.teen_id = profiles.id
      and job.poster_id = (select auth.uid())
  )
);
