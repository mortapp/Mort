begin;

create table public.job_interests (
  user_id uuid not null references auth.users (id) on delete cascade,
  job_id uuid not null references public.jobs (id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint job_interests_pkey primary key (user_id, job_id)
);

create index job_interests_job_id_idx
  on public.job_interests (job_id);

alter table public.job_interests enable row level security;

revoke all on table public.job_interests from anon, authenticated;
grant select, insert, update, delete on table public.job_interests to authenticated;

create policy job_interests_owner_teen_only
  on public.job_interests
  for all
  to authenticated
  using (
    user_id = (select auth.uid())
    and (select private."current_role"()) = 'teen'::public.mort_role
    and (select private.is_active_user())
  )
  with check (
    user_id = (select auth.uid())
    and (select private."current_role"()) = 'teen'::public.mort_role
    and (select private.is_active_user())
  );

commit;