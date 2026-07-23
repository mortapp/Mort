-- Correct the canonical avatar filename check without relying on an escaped dot.
-- The prior forward migration used two backslashes in a standard SQL string,
-- which rejected valid <owner>/<uuid>.jpg uploads.
drop policy if exists storage_profile_avatars_insert_own on storage.objects;

create policy storage_profile_avatars_insert_own
on storage.objects for insert to authenticated
with check (
  bucket_id = 'profile-avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and name ~ (
    '^' || (select auth.uid())::text ||
    '/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}[.]jpg$'
  )
);
