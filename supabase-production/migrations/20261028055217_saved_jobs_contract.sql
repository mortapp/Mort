create table if not exists public.saved_jobs(user_id uuid not null references public.profiles(id) on delete cascade,job_id uuid not null references public.jobs(id) on delete cascade,created_at timestamptz not null default now(),primary key(user_id,job_id));
create index if not exists saved_jobs_user_created_idx on public.saved_jobs(user_id,created_at desc);
create index if not exists saved_jobs_job_idx on public.saved_jobs(job_id);
alter table public.saved_jobs enable row level security;
revoke all on public.saved_jobs from public,anon,authenticated;
grant select,insert,delete on public.saved_jobs to authenticated;
drop policy if exists saved_jobs_select_own on public.saved_jobs;
create policy saved_jobs_select_own on public.saved_jobs for select to authenticated using(user_id=(select auth.uid()));
drop policy if exists saved_jobs_insert_own on public.saved_jobs;
create policy saved_jobs_insert_own on public.saved_jobs for insert to authenticated with check(user_id=(select auth.uid()) and private.current_role()='teen'::public.mort_role and private.is_active_user() and exists(select 1 from public.jobs job where job.id=saved_jobs.job_id and job.status='open'::public.mort_job_status and job.safety_review_status='approved' and job.applications_open and (job.expires_at is null or job.expires_at>now())));
drop policy if exists saved_jobs_delete_own on public.saved_jobs;
create policy saved_jobs_delete_own on public.saved_jobs for delete to authenticated using(user_id=(select auth.uid()));
create or replace function public.save_my_job_v1(p_job_id uuid) returns jsonb language plpgsql security invoker set search_path to '' as $function$
declare user_id uuid:=auth.uid(); profile public.profiles%rowtype; job public.jobs%rowtype;
begin
if user_id is null then return jsonb_build_object('ok',false,'code','authentication_required'); end if;
if p_job_id is null then return jsonb_build_object('ok',false,'code','job_id_required'); end if;
select * into profile from public.profiles where id=user_id;
if not found or profile.role<>'teen'::public.mort_role or profile.account_status<>'active' then return jsonb_build_object('ok',false,'code','active_teen_account_required'); end if;
select * into job from public.jobs candidate where candidate.id=p_job_id and candidate.status='open'::public.mort_job_status and candidate.safety_review_status='approved' and candidate.applications_open and (candidate.expires_at is null or candidate.expires_at>now());
if not found then return jsonb_build_object('ok',false,'code','job_not_available'); end if;
if profile.date_of_birth is not null and (extract(year from age(current_date,profile.date_of_birth))::integer<job.age_min or extract(year from age(current_date,profile.date_of_birth))::integer>job.age_max) then return jsonb_build_object('ok',false,'code','job_not_eligible'); end if;
insert into public.saved_jobs(user_id,job_id) values(user_id,p_job_id) on conflict(user_id,job_id) do nothing;
return jsonb_build_object('ok',true,'job_id',p_job_id);
end;$function$;
revoke all on function public.save_my_job_v1(uuid) from public,anon,authenticated;
grant execute on function public.save_my_job_v1(uuid) to authenticated;
create or replace function public.list_my_saved_jobs() returns setof jsonb language sql stable security invoker set search_path to '' as $function$
select (to_jsonb(job)-array['exact_address','location_notes','neighborhood','zip_code','travel_radius_miles','transportation_considerations','safety_review_status','pay_amount','remote_allowed','age_min','age_max'])
|| jsonb_build_object('location_text',case when job.remote_allowed then 'Remote' else concat_ws(', ',job.city,job.region) end,'state',job.region,'adult_job_amount_cents',round(job.pay_amount*100)::integer,'pay_amount_cents',round(job.pay_amount*100)::integer,'pay_label',null,'profiles',jsonb_build_object('display_name',null,'verification_status',null,'avatar_path',null),'is_test',false,'teen_min_age',job.age_min,'teen_max_age',job.age_max,'distance_status','unavailable','transportation_match',null,'match_explanation',null,'neighborhood',null,'zip_code',null,'travel_radius_miles',null,'transportation_considerations',null)
from public.saved_jobs saved join public.jobs job on job.id=saved.job_id join public.profiles profile on profile.id=(select auth.uid())
where saved.user_id=(select auth.uid()) and profile.role='teen'::public.mort_role and profile.account_status='active' and job.status='open'::public.mort_job_status and job.safety_review_status='approved' and job.applications_open and (job.expires_at is null or job.expires_at>now()) and (profile.date_of_birth is null or extract(year from age(current_date,profile.date_of_birth)) between job.age_min and job.age_max)
order by saved.created_at desc;
$function$;
revoke all on function public.list_my_saved_jobs() from public,anon,authenticated;
grant execute on function public.list_my_saved_jobs() to authenticated;