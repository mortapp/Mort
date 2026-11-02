-- Fixture-free negative behavior checks for a disposable local PostgreSQL 17
-- replay. This file is not a migration and must not run against production.
begin;
do $test$
declare
  v_result jsonb;
begin
  v_result := public.get_job_application_eligibility(null);
  if v_result->>'eligible' <> 'false'
     or v_result->>'code' <> 'authentication_required' then
    raise exception 'eligibility must fail closed without an authenticated user';
  end if;

  v_result := public.schedule_active_job_checkin(null, 60, extensions.gen_random_uuid());
  if v_result->>'ok' <> 'false'
     or v_result->>'code' <> 'authentication_required' then
    raise exception 'check-in scheduling must fail closed without an authenticated user';
  end if;

  v_result := public.complete_active_job_checkin(extensions.gen_random_uuid(), extensions.gen_random_uuid());
  if v_result->>'ok' <> 'false'
     or v_result->>'code' <> 'authentication_required' then
    raise exception 'check-in completion must fail closed without an authenticated user';
  end if;

  begin
    perform public.mort_accept_job_application(extensions.gen_random_uuid());
    raise exception 'test_failed: unauthenticated acceptance unexpectedly succeeded';
  exception when others then
    if sqlerrm = 'test_failed: unauthenticated acceptance unexpectedly succeeded'
       or sqlerrm <> 'Authentication required' then
      raise;
    end if;
  end;

  begin
    perform public.mort_review_verification_case(
      extensions.gen_random_uuid(), 'verified'::public.mort_verification_status, null, null
    );
    raise exception 'test_failed: unauthenticated verification review unexpectedly succeeded';
  exception when others then
    if sqlerrm = 'test_failed: unauthenticated verification review unexpectedly succeeded'
       or sqlerrm <> 'Authorized verification reviewer required' then
      raise;
    end if;
  end;

  if has_function_privilege('anon', 'public.mort_review_verification_case(uuid,public.mort_verification_status,text,timestamptz)', 'EXECUTE')
     or has_function_privilege('anon', 'public.mort_accept_job_application(uuid)', 'EXECUTE')
     or has_function_privilege('anon', 'public.schedule_active_job_checkin(uuid,integer,uuid)', 'EXECUTE')
     or has_function_privilege('anon', 'public.complete_active_job_checkin(uuid,uuid)', 'EXECUTE') then
    raise exception 'anon must not execute privileged safety RPCs';
  end if;

  if (select count(*) from private.verification_provider_allowlist) <> 0 then
    raise exception 'proposal must not seed or invent an approved provider';
  end if;

  if has_table_privilege('authenticated', 'private.verification_provider_results', 'SELECT')
     or has_table_privilege('authenticated', 'private.verification_provider_results', 'INSERT')
     or has_table_privilege('anon', 'private.verification_provider_results', 'SELECT')
     or not has_table_privilege('service_role', 'private.verification_provider_results', 'INSERT')
     or has_table_privilege('service_role', 'private.verification_provider_results', 'UPDATE')
     or has_table_privilege('service_role', 'private.verification_provider_allowlist', 'INSERT') then
    raise exception 'verification ledgers have unexpected table grants';
  end if;

  if not (select relrowsecurity from pg_class where oid='private.verification_provider_allowlist'::regclass)
     or not (select relrowsecurity from pg_class where oid='private.verification_provider_results'::regclass) then
    raise exception 'verification provider ledgers must have RLS enabled';
  end if;

  if exists (
    select 1 from pg_proc function_row
    where function_row.oid in (
      'public.mort_review_verification_case(uuid,public.mort_verification_status,text,timestamptz)'::regprocedure,
      'public.mort_accept_job_application(uuid)'::regprocedure,
      'public.get_job_application_eligibility(uuid)'::regprocedure,
      'public.schedule_active_job_checkin(uuid,integer,uuid)'::regprocedure,
      'public.complete_active_job_checkin(uuid,uuid)'::regprocedure
    )
      and (not function_row.prosecdef or not coalesce(function_row.proconfig, array[]::text[]) @> array['search_path=""'])
  ) then
    raise exception 'SECURITY DEFINER or fixed empty search_path changed';
  end if;

end;
$test$;
rollback;
