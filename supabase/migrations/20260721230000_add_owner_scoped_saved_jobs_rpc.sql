begin;

create or replace function public.list_my_saved_jobs()
returns setof public.jobs
language sql
stable
security definer
set search_path = ''
as $$
  select job.*
  from public.saved_jobs saved
  join public.jobs job on job.id = saved.job_id
  where saved.user_id = (select auth.uid())
  order by saved.created_at desc;
$$;

revoke all on function public.list_my_saved_jobs()
from public, anon;
grant execute on function public.list_my_saved_jobs()
to authenticated;

comment on function public.list_my_saved_jobs()
is 'Returns only the signed-in user saved jobs, including current unavailable status.';

commit;
