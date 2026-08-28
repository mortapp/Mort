-- RevenueCat webhook fulfillment additions.
-- Adds a server-side job boost credit ledger and tightens boosted job creation
-- so paid boosts require a backend credit before becoming pending review.

create table if not exists public.job_boost_credits (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  available_credits integer not null default 0 check (available_credits >= 0),
  used_credits integer not null default 0 check (used_credits >= 0),
  last_revenuecat_event_id text,
  updated_at timestamptz not null default now()
);

create trigger job_boost_credits_set_updated_at before update on public.job_boost_credits
for each row execute function public.set_updated_at();

alter table public.job_boost_credits enable row level security;

create policy job_boost_credits_select_own_or_admin on public.job_boost_credits
for select to authenticated
using (user_id = (select auth.uid()) or public.is_admin());

create policy job_boost_credits_admin_write on public.job_boost_credits
for all to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists boosted_jobs_insert_job_owner on public.boosted_jobs;
drop policy if exists boosted_jobs_update_owner_pending_or_admin on public.boosted_jobs;

create policy boosted_jobs_insert_admin_only on public.boosted_jobs
for insert to authenticated
with check (public.is_admin());

create policy boosted_jobs_update_owner_cancel_pending_or_admin on public.boosted_jobs
for update to authenticated
using (public.is_admin() or (purchaser_id = (select auth.uid()) and status = 'pending'))
with check (public.is_admin() or (purchaser_id = (select auth.uid()) and status = 'cancelled'));

create or replace function public.get_job_boost_credit_status()
returns table (
  available_credits integer,
  used_credits integer
)
language sql
security definer
set search_path = public
stable
as $$
  select
    coalesce(jbc.available_credits, 0),
    coalesce(jbc.used_credits, 0)
  from (select (select auth.uid()) as user_id) me
  left join public.job_boost_credits jbc on jbc.user_id = me.user_id;
$$;

create or replace function public.consume_job_boost_credit(p_job_id uuid)
returns public.boosted_jobs
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_credits public.job_boost_credits%rowtype;
  v_boost public.boosted_jobs%rowtype;
begin
  if v_user_id is null then
    raise exception 'Authentication required.';
  end if;

  if p_job_id is null then
    raise exception 'Job id is required.';
  end if;

  if not exists (
    select 1
    from public.jobs j
    where j.id = p_job_id
      and j.poster_id = v_user_id
      and j.status = 'open'
  ) then
    raise exception 'Only the adult/business poster can boost an eligible job.';
  end if;

  insert into public.job_boost_credits (user_id)
  values (v_user_id)
  on conflict (user_id) do nothing;

  select * into v_credits
  from public.job_boost_credits
  where user_id = v_user_id
  for update;

  if coalesce(v_credits.available_credits, 0) < 1 then
    raise exception 'No job boost credits available.';
  end if;

  update public.job_boost_credits
  set available_credits = available_credits - 1,
      used_credits = used_credits + 1
  where user_id = v_user_id;

  insert into public.boosted_jobs (job_id, purchaser_id, revenuecat_product_id, status)
  values (p_job_id, v_user_id, 'mort_job_boost_1', 'pending')
  returning * into v_boost;

  insert into public.purchase_audit_logs (user_id, source, action, product_id, details)
  values (
    v_user_id,
    'app',
    'job_boost_credit_consumed',
    'mort_job_boost_1',
    jsonb_build_object('job_id', p_job_id, 'boost_id', v_boost.id)
  );

  return v_boost;
end;
$$;

grant select on public.job_boost_credits to authenticated;
grant select, insert, update, delete on public.job_boost_credits to service_role;

grant execute on function public.get_job_boost_credit_status() to authenticated, service_role;
grant execute on function public.consume_job_boost_credit(uuid) to authenticated, service_role;
