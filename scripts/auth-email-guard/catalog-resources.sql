-- Runtime catalog inventory for this fixture's two exposed schemas.
SELECT coalesce(jsonb_agg(resource),'[]'::jsonb) FROM (
  SELECT jsonb_build_object('name',n.nspname||'.'||c.relname,
    'kind',CASE WHEN c.relkind IN('v','m') THEN 'view' ELSE 'table' END,
    'reachable',has_schema_privilege('authenticated',n.oid,'USAGE') AND
      (has_table_privilege('authenticated',c.oid,'SELECT,INSERT,UPDATE,DELETE') OR
       has_any_column_privilege('authenticated',c.oid,'SELECT,INSERT,UPDATE')),
    'rlsEnabled',c.relrowsecurity,'securityInvoker',coalesce(c.reloptions @> ARRAY['security_invoker=true'],false),
    'policyCount',(SELECT count(*) FROM pg_policies p WHERE p.schemaname=n.nspname AND p.tablename=c.relname)) resource
  FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname IN('mort_transport','storage') AND c.relkind IN('r','p','v','m','f')
  UNION ALL
  SELECT jsonb_build_object('name',p.oid::regprocedure::text,'kind','rpc',
    'reachable',has_schema_privilege('authenticated',n.oid,'USAGE') AND has_function_privilege('authenticated',p.oid,'EXECUTE'),
    'securityDefiner',p.prosecdef)
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname IN('mort_transport','storage') AND p.prokind='f'
) resources;
