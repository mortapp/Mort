-- saved_jobs previously checked public.jobs directly while the jobs SELECT
-- policy checked saved_jobs. That circular policy graph caused PostgreSQL to
-- reject legitimate saves. Keep the lookup caller-bound and outside the API
-- schema so the RLS predicate can inspect the job without recursively applying
-- the jobs policy.
create or replace function private.can_current_user_save_job(p_job_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, pg_temp
as $$
  select auth.uid() is not null
    and exists (
      select 1
      from public.jobs job
      where job.id = p_job_id
        and job.status = 'open'::public.job_status
        and (
          not job.is_test
          or exists (
            select 1
            from public.profiles profile
            where profile.id = auth.uid()
              and profile.is_test_account
          )
        )
    );
$$;

revoke all on function private.can_current_user_save_job(uuid)
from public, anon;
grant usage on schema private to authenticated, service_role;
grant execute on function private.can_current_user_save_job(uuid)
to authenticated, service_role;

alter policy saved_jobs_insert_own
on public.saved_jobs
to authenticated
with check (
  user_id = (select auth.uid())
  and public.current_profile_role() = 'teen'::public.user_role
  and private.can_current_user_save_job(job_id)
);

alter policy saved_jobs_update_own
on public.saved_jobs
to authenticated
using (user_id = (select auth.uid()))
with check (
  user_id = (select auth.uid())
  and public.current_profile_role() = 'teen'::public.user_role
  and private.can_current_user_save_job(job_id)
);
