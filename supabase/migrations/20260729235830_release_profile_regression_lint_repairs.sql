-- PostgreSQL classifies the regular-expression path as stable. Match the
-- declared volatility to the implementation so planner assumptions stay true.
alter function private.support_classify_message(text) stable;

-- Preserve the deployed RevenueCat function body and replace only the two
-- local empty-array initializers that plpgsql otherwise infers as text.
do $migration$
declare
  v_signature regprocedure :=
    'public.process_revenuecat_provider_event(text,uuid,text,text,text[],timestamptz,timestamptz,text,jsonb)'::regprocedure;
  v_definition text;
  v_persistent_old constant text :=
    'v_persistent_entitlements text[] := ''{}'';';
  v_persistent_new constant text :=
    'v_persistent_entitlements text[] := ''{}''::text[];';
  v_next_old constant text :=
    'v_next_entitlements text[] := ''{}'';';
  v_next_new constant text :=
    'v_next_entitlements text[] := ''{}''::text[];';
begin
  select pg_get_functiondef(v_signature)
  into v_definition;

  if v_definition is null
    or strpos(v_definition, v_persistent_old) = 0
    or strpos(v_definition, v_next_old) = 0
  then
    raise exception using
      errcode = '55000',
      message = 'RevenueCat function definition did not match the reviewed initializer repair.';
  end if;

  v_definition := replace(v_definition, v_persistent_old, v_persistent_new);
  v_definition := replace(v_definition, v_next_old, v_next_new);
  execute v_definition;
end;
$migration$;

revoke all on function public.process_revenuecat_provider_event(
  text, uuid, text, text, text[], timestamptz, timestamptz, text, jsonb
) from public, anon, authenticated;
grant execute on function public.process_revenuecat_provider_event(
  text, uuid, text, text, text[], timestamptz, timestamptz, text, jsonb
) to service_role;
