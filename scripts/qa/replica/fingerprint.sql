with objs as (
  select 'function' cat, n.nspname||'.'||p.proname||'('||pg_get_function_identity_arguments(p.oid)||')' obj,
         md5(pg_get_functiondef(p.oid)||(select string_agg(case when a.grantee=0 then 'PUBLIC' else pg_get_userbyid(a.grantee) end||':'||a.privilege_type, ',' order by (case when a.grantee=0 then 'PUBLIC' else pg_get_userbyid(a.grantee) end||':'||a.privilege_type)) from aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a where a.grantee=0 or pg_get_userbyid(a.grantee) in ('anon','authenticated','service_role'))||p.prosecdef::text||coalesce(array_to_string(p.proconfig,','),'')) h
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname in ('public','private') and p.prokind in ('f','p')
    and not exists (select 1 from pg_depend d where d.objid=p.oid and d.deptype='e')
  union all
  select 'policy', schemaname||'.'||tablename||'.'||policyname, md5(cmd||roles::text||coalesce(qual,'')||coalesce(with_check,'')||permissive)
  from pg_policies where schemaname in ('public','private','storage')
  union all
  select 'grant', table_schema||'.'||table_name||':'||grantee, md5(string_agg(privilege_type, ',' order by privilege_type))
  from information_schema.role_table_grants
  where table_schema in ('public','private','storage') and grantee in ('anon','authenticated','service_role','PUBLIC')
    and table_name not in ('bucket_lifecycle_states','lifecycle_abandoned_artifacts','migrations','s3_multipart_uploads','s3_multipart_uploads_parts','buckets_analytics','prefixes','buckets_vectors','vector_indexes','iceberg_namespaces','iceberg_tables')
  group by 1,2
  union all
  select 'column', table_schema||'.'||table_name, md5(string_agg(column_name||':'||data_type||':'||coalesce(column_default,'')||':'||is_nullable, ',' order by column_name))
  from information_schema.columns where table_schema in ('public','private') group by 1,2
  union all
  select 'trigger', n.nspname||'.'||c.relname||'.'||t.tgname, md5(pg_get_triggerdef(t.oid))
  from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace
  where not t.tgisinternal and n.nspname in ('public','private')
  union all
  select 'rls', n.nspname||'.'||c.relname, md5(c.relrowsecurity::text||c.relforcerowsecurity::text)
  from pg_class c join pg_namespace n on n.oid=c.relnamespace where c.relkind in ('r','p') and n.nspname in ('public','private')
  union all
  select 'bucket', id, md5(public::text||coalesce(file_size_limit::text,'')||coalesce(allowed_mime_types::text,'')) from storage.buckets
  union all
  select 'routine_grant', routine_schema||'.'||routine_name||':'||grantee, md5(string_agg(privilege_type, ',' order by privilege_type))
  from information_schema.role_routine_grants where routine_schema in ('public','private') and grantee in ('anon','authenticated','PUBLIC') group by 1,2
)
select cat, count(*) n, md5(string_agg(obj||'='||h, '|' order by obj)) agg from objs group by cat order by cat
