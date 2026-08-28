begin;

create or replace function private.can_view_marketplace_job(p_job_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_job public.jobs%rowtype;
  v_profile public.profiles%rowtype;
begin
  if v_user_id is null then
    return false;
  end if;

  select * into v_job from public.jobs job where job.id = p_job_id;
  select * into v_profile from public.profiles profile where profile.id = v_user_id;
  if v_job.id is null or v_profile.id is null or v_profile.account_status <> 'active' then
    return false;
  end if;

  if v_profile.role = 'admin' or v_job.poster_id = v_user_id then
    return true;
  end if;

  if exists (
    select 1
    from public.applications application
    where application.job_id = p_job_id
      and (
        application.teen_id = v_user_id
        or application.guardian_id = v_user_id
      )
  ) then
    return true;
  end if;

  if exists (
    select 1
    from public.saved_jobs saved
    where saved.job_id = p_job_id
      and saved.user_id = v_user_id
  ) then
    return true;
  end if;

  if v_job.status <> 'open' then
    return false;
  end if;

  if v_profile.is_test_account then
    return v_job.is_test
      and private.has_current_sandbox_identity(v_user_id)
      and private.has_current_sandbox_identity(v_job.poster_id);
  end if;

  return not v_job.is_test
    and private.production_identity_ready()
    and private.has_current_production_identity(v_user_id)
    and private.has_current_production_identity(v_job.poster_id);
end;
$$;

revoke all on function private.can_view_marketplace_job(uuid)
from public, anon;
grant execute on function private.can_view_marketplace_job(uuid)
to authenticated, service_role;

comment on function private.can_view_marketplace_job(uuid)
is 'Server-owned job visibility including participant access and owner-isolated saved-job history.';

commit;
