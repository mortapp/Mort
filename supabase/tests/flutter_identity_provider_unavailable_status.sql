do $test$
declare
  v_function oid := to_regprocedure('public.get_my_identity_verification_v2()');
  v_is_security_definer boolean;
  v_definition text;
  v_status jsonb;
  v_auth_rejected boolean := false;
begin
  if v_function is null then
    raise exception 'get_my_identity_verification_v2() is missing';
  end if;

  select p.prosecdef, pg_get_functiondef(p.oid)
  into v_is_security_definer, v_definition
  from pg_proc as p
  where p.oid = v_function;

  if v_is_security_definer then
    raise exception 'identity status endpoint should not run with elevated privileges';
  end if;
  if has_function_privilege('anon', v_function, 'EXECUTE') then
    raise exception 'anonymous callers must not execute identity status RPC';
  end if;
  if not has_function_privilege('authenticated', v_function, 'EXECUTE') then
    raise exception 'authenticated callers must execute identity status RPC';
  end if;
  if position('auth.uid() is null' in v_definition) = 0 then
    raise exception 'identity status RPC must require a signed-in caller';
  end if;

  perform set_config(
    'request.jwt.claims',
    '{"sub":"00000000-0000-4000-8000-000000000000","role":"authenticated"}',
    true
  );
  v_status := public.get_my_identity_verification_v2();
  if v_status->>'ok' is distinct from 'true'
     or v_status->>'verification_mode' is distinct from 'disabled'
     or v_status->>'status' is distinct from 'unverified'
     or v_status->>'failure_code' is distinct from 'production_provider_unavailable'
     or (v_status->>'production_provider_available')::boolean
     or (v_status->>'submissions_enabled')::boolean
     or (v_status->>'production_verified')::boolean
     or (v_status->>'marketplace_enabled')::boolean
     or (v_status->>'documents_collected_by_mort')::boolean then
    raise exception 'identity status must report provider absence without enabling verification';
  end if;

  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);
  begin
    perform public.get_my_identity_verification_v2();
  exception when insufficient_privilege then
    v_auth_rejected := true;
  end;
  if not v_auth_rejected then
    raise exception 'identity status RPC must reject callers without an authenticated user';
  end if;
end;
$test$;
