-- Depends on 20261122151000. Keep worker scheduling off during rollout.
--
-- A database CASCADE is referential behavior, not a retention decision.
-- Treat all unreviewed MORT application cascades as holds, including new
-- relations added after this migration. Auth-managed children are outside
-- this application inventory; profile deletion itself is required.
create function private.mort_deletion_unapproved_application_cascades(p_user_id uuid)
returns text[] language plpgsql stable security definer set search_path = '' as $$
declare
  fk record;
  populated boolean;
  blockers text[] := '{}';
begin
  for fk in
    select distinct n.nspname sch, child.relname tbl, attr.attname col
    from pg_catalog.pg_constraint c
    join pg_catalog.pg_class child on child.oid = c.conrelid
    join pg_catalog.pg_namespace n on n.oid = child.relnamespace
    join pg_catalog.pg_attribute parent_attr
      on parent_attr.attrelid = c.confrelid and parent_attr.attname = 'id'
    left join pg_catalog.pg_attribute attr
      on attr.attrelid = child.oid
      and attr.attnum = c.conkey[array_position(c.confkey,parent_attr.attnum)]
    where c.contype = 'f' and c.confdeltype = 'c'
      and c.confrelid in ('auth.users'::regclass, 'public.profiles'::regclass)
      and n.nspname in ('public','private')
      and not coalesce((
        c.confrelid = 'auth.users'::regclass and c.conrelid = 'public.profiles'::regclass
        and cardinality(c.conkey) = 1 and attr.attname = 'id'
      ),false)
      and not coalesce((
        c.confrelid = 'public.profiles'::regclass and cardinality(c.conkey) = 1
        and (n.nspname, child.relname, attr.attname) in (
          ('public','notification_preferences','user_id'),
          ('public','saved_jobs','user_id')
        )
      ),false)
  loop
    if fk.col is null then
      -- A new FK that doesn't reference UUID id needs an explicit disposition.
      execute format('select exists (select 1 from %I.%I)', fk.sch, fk.tbl) into populated;
    else
      execute format('select exists (select 1 from %I.%I where %I = $1)', fk.sch, fk.tbl, fk.col)
        into populated using p_user_id;
    end if;
    if populated then blockers := array_append(blockers, fk.sch || '.' || fk.tbl); end if;
  end loop;
  return (select coalesce(array_agg(distinct item order by item), '{}') from unnest(blockers) item);
end;
$$;
revoke all on function private.mort_deletion_unapproved_application_cascades(uuid) from public, anon, authenticated;

-- Retain explicit protection if an existing FK's referential action changes.
create or replace function private.mort_deletion_protected_history(p_user_id uuid)
returns text[] language plpgsql stable security definer set search_path = '' as $$
declare
  target record;
  has_records boolean;
  blockers text[] := private.mort_deletion_unapproved_application_cascades(p_user_id);
begin
  if exists (select 1 from private.account_deletion_legal_holds h
      where h.subject_id = p_user_id and h.released_at is null) then
    blockers := array_append(blockers,'private.account_deletion_legal_holds');
  end if;
  for target in select * from (values
    ('private','verification_provider_results','user_id'),
    ('public','verification_cases','user_id'),
    ('public','consents','user_id'),
    ('public','job_safety_checkins','adult_user_id'),
    ('public','job_safety_checkins','teen_user_id'),
    ('public','role_requests','user_id'),
    ('public','team_hustles','poster_id')
  ) as protected(sch,tbl,col)
  loop
    execute format('select exists (select 1 from %I.%I where %I = $1)',target.sch,target.tbl,target.col)
      into has_records using p_user_id;
    if has_records then blockers := array_append(blockers,target.sch || '.' || target.tbl); end if;
  end loop;
  return (select coalesce(array_agg(distinct item order by item), '{}') from unnest(blockers) item);
end;
$$;
revoke all on function private.mort_deletion_protected_history(uuid) from public, anon, authenticated;

-- Check before any Auth FK cascade can run. The profile trigger remains in
-- place to protect legal holds and profile deletion from other paths.
create function private.mort_deletion_protect_auth_history()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if exists (select 1 from public.account_deletion_requests r
      where r.processor_user_id = old.id and r.status = 'processing')
    and cardinality(private.mort_deletion_protected_history(old.id)) > 0
  then
    raise exception 'account_deletion_protected_history' using errcode = '23503';
  end if;
  return old;
end;
$$;
revoke all on function private.mort_deletion_protect_auth_history() from public, anon, authenticated;
create trigger mort_deletion_protect_auth_history before delete on auth.users
  for each row execute function private.mort_deletion_protect_auth_history();

notify pgrst, 'reload schema';
