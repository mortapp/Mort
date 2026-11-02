-- Permit email-confirmed pending accounts to complete required legal clickwrap.
-- This does not activate accounts or grant marketplace, publishing, verification,
-- or payment access. The actor must still have an eligible server-derived role
-- and age band. Unconfirmed and restricted accounts remain ineligible.

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

  if pg_catalog.strpos(v_definition, v_old) = 0 then
    raise exception 'Expected get_my_legal_requirements actor predicate not found; refusing migration';
  end if;
  v_definition := pg_catalog.replace(v_definition, v_old, v_new);
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

  if pg_catalog.strpos(v_definition, v_old) = 0 then
    raise exception 'Expected submit_legal_acceptance actor predicate not found; refusing migration';
  end if;
  v_definition := pg_catalog.replace(v_definition, v_old, v_new);
  execute v_definition;
end
$migration$;

-- Existing EXECUTE grants are preserved by CREATE OR REPLACE FUNCTION.
