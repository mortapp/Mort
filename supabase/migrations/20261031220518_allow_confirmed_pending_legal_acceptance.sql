-- Permit confirmed accounts to complete required legal clickwrap while still pending.
-- No activation, marketplace, publishing, verification, or payment access is granted.
-- This migration supports both the newer production-style profile predicate and
-- the older reference schema used by the local regression reset.

do $migration$
declare
  v_definition text;
  v_old text;
  v_new text;
begin
  v_definition := pg_catalog.pg_get_functiondef(
    'public.get_my_legal_requirements()'::regprocedure
  );
  v_old := '      and profile.account_status = ''active''' || chr(10) ||
    '      and profile.role <> ''pending''';
  v_new := '      and (' || chr(10) ||
    '        profile.account_status = ''active''' || chr(10) ||
    '        or (' || chr(10) ||
    '          profile.account_status = ''pending''' || chr(10) ||
    '          and exists (' || chr(10) ||
    '            select 1 from auth.users auth_user' || chr(10) ||
    '            where auth_user.id = profile.id' || chr(10) ||
    '              and auth_user.email_confirmed_at is not null' || chr(10) ||
    '          )' || chr(10) ||
    '        )' || chr(10) ||
    '      )' || chr(10) ||
    '      and profile.role <> ''pending''';

  if pg_catalog.strpos(v_definition, v_old) > 0 then
    v_definition := pg_catalog.replace(v_definition, v_old, v_new);
  elsif pg_catalog.strpos(v_definition, 'where profile.id = auth.uid()') > 0 then
    -- Legacy reference schema has no account_status predicate in this RPC.
    -- Keep the actor bound to auth.uid() and require a confirmed Auth email.
    v_old := 'where profile.id = auth.uid()';
    v_new := 'where profile.id = auth.uid() and exists (' ||
      'select 1 from auth.users auth_user where auth_user.id = profile.id ' ||
      'and auth_user.email_confirmed_at is not null)';
    if pg_catalog.strpos(v_definition, v_old) = 0 then
      raise exception 'Legacy get_my_legal_requirements actor predicate changed; refusing migration';
    end if;
    v_definition := pg_catalog.replace(v_definition, v_old, v_new);
  elsif pg_catalog.strpos(v_definition, 'auth_user.email_confirmed_at is not null') = 0 then
    raise exception 'Unrecognized get_my_legal_requirements actor predicate; refusing migration';
  end if;
  execute v_definition;

  v_definition := pg_catalog.pg_get_functiondef(
    'public.submit_legal_acceptance(uuid,boolean,boolean,text,text,text,text)'::regprocedure
  );
  v_old := '    and account_status = ''active''' || chr(10) || '  for share;';
  v_new := '    and (' || chr(10) ||
    '      account_status = ''active''' || chr(10) ||
    '      or (' || chr(10) ||
    '        account_status = ''pending''' || chr(10) ||
    '        and exists (' || chr(10) ||
    '          select 1 from auth.users auth_user' || chr(10) ||
    '          where auth_user.id = public.profiles.id' || chr(10) ||
    '            and auth_user.email_confirmed_at is not null' || chr(10) ||
    '        )' || chr(10) ||
    '      )' || chr(10) ||
    '    )' || chr(10) ||
    '  for share;';

  if pg_catalog.strpos(v_definition, v_old) > 0 then
    v_definition := pg_catalog.replace(v_definition, v_old, v_new);
  elsif pg_catalog.strpos(v_definition, 'from public.profiles where id = auth.uid() for share;') > 0 then
    -- Legacy reference schema already requires an authenticated actor and a
    -- completed role; add the confirmed-email condition without broadening it.
    v_old := 'from public.profiles where id = auth.uid() for share;';
    v_new := 'from public.profiles where id = auth.uid() and exists (' ||
      'select 1 from auth.users auth_user where auth_user.id = public.profiles.id ' ||
      'and auth_user.email_confirmed_at is not null) for share;';
    v_definition := pg_catalog.replace(v_definition, v_old, v_new);
  elsif pg_catalog.strpos(v_definition, 'auth_user.email_confirmed_at is not null') = 0 then
    raise exception 'Unrecognized submit_legal_acceptance actor predicate; refusing migration';
  end if;
  execute v_definition;
end
$migration$;

-- Existing EXECUTE grants are preserved by CREATE OR REPLACE FUNCTION.
