-- Actual fixture buckets, policies, grants and publication membership; no repo regex inventory.
SELECT coalesce(jsonb_agg(resource),'[]'::jsonb) FROM (
 SELECT jsonb_build_object('name','storage.bucket.'||b.id,'kind','private_bucket','reachable',true,'public',b.public,
  'sessionGuardCovered',EXISTS(SELECT 1 FROM pg_policies p WHERE p.schemaname='storage' AND p.tablename='objects'
   AND p.permissive='RESTRICTIVE' AND p.roles=ARRAY['authenticated']::name[]
   AND ((p.policyname='guard_native_storage_live' AND position(quote_literal(b.id) IN p.qual)>0 AND position('native_guard_enabled' IN p.qual)>0 AND position('session_is_live' IN p.qual)>0)
    OR (b.id='mort-fixture' AND p.policyname='guard_fixture_live_storage' AND position('session_is_live' IN p.qual)>0)))) resource
 FROM storage.buckets b
 UNION ALL
 SELECT jsonb_build_object('name','realtime.topic.guard-native','kind','private_channel','reachable',true,
 'privateOnly',EXISTS(SELECT 1 FROM pg_policies p WHERE p.schemaname='realtime' AND p.tablename='messages' AND p.policyname='guard_native_channel_live' AND position('guard-native:%' IN p.qual)>0),
 'sessionGuardCovered',EXISTS(SELECT 1 FROM pg_policies p WHERE p.schemaname='realtime' AND p.tablename='messages' AND p.policyname='guard_native_channel_live' AND p.permissive='RESTRICTIVE' AND p.roles=ARRAY['authenticated']::name[] AND position('native_guard_enabled' IN p.qual)>0 AND position('session_is_live' IN p.qual)>0))
 UNION ALL
 SELECT jsonb_build_object('name',t.schemaname||'.'||t.tablename,'kind','published_table',
 'reachable',has_schema_privilege('authenticated',t.schemaname,'USAGE') AND has_table_privilege('authenticated',c.oid,'SELECT'),
 'rlsEnabled',c.relrowsecurity,
 'sessionGuardCovered',EXISTS(SELECT 1 FROM pg_policies p WHERE p.schemaname=t.schemaname AND p.tablename=t.tablename AND p.policyname='guard_native_published_live' AND p.permissive='RESTRICTIVE' AND p.roles=ARRAY['authenticated']::name[] AND position('native_guard_enabled' IN p.qual)>0 AND position('session_is_live' IN p.qual)>0))
 FROM pg_publication_tables t JOIN pg_namespace n ON n.nspname=t.schemaname JOIN pg_class c ON c.relnamespace=n.oid AND c.relname=t.tablename
 WHERE t.pubname='supabase_realtime' AND t.schemaname='mort_transport'
) inventory;
