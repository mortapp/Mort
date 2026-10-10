-- Disposable exact-owned fixture only. No applied migration or hosted resource.
CREATE OR REPLACE FUNCTION mort_fixture.native_guard_enabled()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT enabled FROM mort_fixture.pre_request_control
$$;
REVOKE ALL ON FUNCTION mort_fixture.native_guard_enabled() FROM public;
GRANT EXECUTE ON FUNCTION mort_fixture.native_guard_enabled() TO authenticated;
CREATE TABLE IF NOT EXISTS mort_transport.native_published(id uuid PRIMARY KEY,owner uuid NOT NULL,value text NOT NULL);
ALTER TABLE mort_transport.native_published ENABLE ROW LEVEL SECURITY;
ALTER TABLE mort_transport.native_published REPLICA IDENTITY FULL;
GRANT SELECT,INSERT,UPDATE,DELETE ON mort_transport.native_published TO authenticated;
CREATE POLICY guard_native_owner_table ON mort_transport.native_published FOR ALL TO authenticated
 USING(owner=(SELECT auth.uid())) WITH CHECK(owner=(SELECT auth.uid()));
CREATE POLICY guard_native_published_live ON mort_transport.native_published AS RESTRICTIVE FOR ALL TO authenticated
 USING(NOT (SELECT mort_fixture.native_guard_enabled()) OR (SELECT mort_fixture.session_is_live()))
 WITH CHECK(NOT (SELECT mort_fixture.native_guard_enabled()) OR (SELECT mort_fixture.session_is_live()));
ALTER PUBLICATION supabase_realtime ADD TABLE mort_transport.native_published;
CREATE POLICY guard_native_owner_read ON storage.objects FOR SELECT TO authenticated
 USING(bucket_id IN('financial-receipts','identity-evidence','incident-evidence','mort-document-vault','mort-verify-evidence','proof-uploads','support-attachments','support-evidence','teen-school-id','verification-uploads','profile-avatars') AND (storage.foldername(name))[1]=(SELECT auth.uid())::text);
CREATE POLICY guard_native_owner_write ON storage.objects FOR INSERT TO authenticated
 WITH CHECK(bucket_id IN('financial-receipts','identity-evidence','incident-evidence','mort-document-vault','mort-verify-evidence','proof-uploads','support-attachments','support-evidence','teen-school-id','verification-uploads','profile-avatars') AND (storage.foldername(name))[1]=(SELECT auth.uid())::text);
CREATE POLICY guard_native_storage_live ON storage.objects AS RESTRICTIVE FOR ALL TO authenticated
 USING(bucket_id NOT IN('mort-fixture','financial-receipts','identity-evidence','incident-evidence','mort-document-vault','mort-verify-evidence','proof-uploads','support-attachments','support-evidence','teen-school-id','verification-uploads','profile-avatars') OR NOT (SELECT mort_fixture.native_guard_enabled()) OR (SELECT mort_fixture.session_is_live()))
 WITH CHECK(bucket_id NOT IN('mort-fixture','financial-receipts','identity-evidence','incident-evidence','mort-document-vault','mort-verify-evidence','proof-uploads','support-attachments','support-evidence','teen-school-id','verification-uploads','profile-avatars') OR NOT (SELECT mort_fixture.native_guard_enabled()) OR (SELECT mort_fixture.session_is_live()));
CREATE POLICY guard_native_channel_owner_read ON realtime.messages FOR SELECT TO authenticated
 USING(realtime.topic()='guard-native:'||(SELECT auth.uid())::text);
CREATE POLICY guard_native_channel_owner_write ON realtime.messages FOR INSERT TO authenticated
 WITH CHECK(realtime.topic()='guard-native:'||(SELECT auth.uid())::text);
CREATE POLICY guard_native_channel_live ON realtime.messages AS RESTRICTIVE FOR ALL TO authenticated
 USING(realtime.topic() NOT LIKE 'guard-native:%' OR NOT (SELECT mort_fixture.native_guard_enabled()) OR (SELECT mort_fixture.session_is_live()))
 WITH CHECK(realtime.topic() NOT LIKE 'guard-native:%' OR NOT (SELECT mort_fixture.native_guard_enabled()) OR (SELECT mort_fixture.session_is_live()));
NOTIFY pgrst,'reload schema';
