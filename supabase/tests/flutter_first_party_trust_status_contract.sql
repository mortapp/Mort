do $test$
declare
  v_function oid := to_regprocedure('public.get_first_party_trust_status()');
  v_is_security_definer boolean;
  v_is_stable boolean;
  v_definition text;
  v_status jsonb;
  v_runtime jsonb;
  v_auth_rejected boolean := false;
begin
  if v_function is null then
    raise exception 'get_first_party_trust_status() is missing';
  end if;

  select p.prosecdef, p.provolatile = 's', pg_get_functiondef(p.oid)
  into v_is_security_definer, v_is_stable, v_definition
  from pg_proc as p
  where p.oid = v_function;

  if not v_is_security_definer or not v_is_stable then
    raise exception 'trust status RPC must be stable and security definer';
  end if;
  if has_function_privilege('anon', v_function, 'EXECUTE') then
    raise exception 'anonymous callers must not execute trust status RPC';
  end if;
  if not has_function_privilege('authenticated', v_function, 'EXECUTE') then
    raise exception 'authenticated callers must execute trust status RPC';
  end if;
  if position('auth.uid() is null' in v_definition) = 0 then
    raise exception 'trust status RPC must require an authenticated user';
  end if;
  if position('external_web_reuse_enabled' in v_definition) = 0
     or position('public_marketplace_open' in v_definition) = 0
     or position('payments_enabled' in v_definition) = 0 then
    raise exception 'trust status RPC is missing fields consumed by the app';
  end if;

  perform set_config(
    'request.jwt.claims',
    '{"sub":"00000000-0000-4000-8000-000000000000","role":"authenticated"}',
    true
  );
  v_status := public.get_first_party_trust_status();
  v_runtime := public.get_runtime_feature_status();
  if v_status->>'ok' is distinct from 'true'
     or jsonb_typeof(v_status->'public_marketplace_open') is distinct from 'boolean'
     or jsonb_typeof(v_status->'payments_enabled') is distinct from 'boolean'
     or (v_status->>'public_marketplace_open')::boolean is distinct from
        (not coalesce((v_runtime->>'public_marketplace_closed')::boolean, true)
         and not coalesce((v_runtime->>'maintenance_mode')::boolean, true))
     or (v_status->>'payments_enabled')::boolean is distinct from
        (not coalesce((v_runtime->>'payments_disabled')::boolean, true))
     or (v_status->>'real_document_collection_enabled')::boolean is distinct from
        coalesce((v_runtime->>'real_document_collection')::boolean, false) then
    raise exception 'trust status RPC does not match current production controls';
  end if;

  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);
  begin
    perform public.get_first_party_trust_status();
  exception when insufficient_privilege then
    v_auth_rejected := true;
  end;
  if not v_auth_rejected then
    raise exception 'trust status RPC must reject calls without an authenticated user';
  end if;
end;
$test$;
