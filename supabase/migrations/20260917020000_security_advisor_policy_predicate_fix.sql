-- Correct the participant predicate introduced by the advisor hardening
-- migration. The application subquery must be tied to this request's job;
-- comparing application.job_id to itself would expose requests for any job
-- to any participant of any application.
drop policy if exists job_management_requests_participant_select
on public.job_management_requests;

create policy job_management_requests_participant_select
on public.job_management_requests
for select
to authenticated
using (
  actor_id = (select auth.uid())
  or is_admin()
  or exists (
    select 1
    from public.jobs job
    where job.id = job_management_requests.job_id
      and job.poster_id = (select auth.uid())
  )
  or exists (
    select 1
    from public.applications application
    where application.job_id = job_management_requests.job_id
      and (
        (select auth.uid()) = application.teen_id
        or (select auth.uid()) = coalesce(application.guardian_id, application.teen_id)
      )
  )
);
