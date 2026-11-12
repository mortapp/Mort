-- MORT production storage policies (mort p, jxbnrkasktbhtiujkhay)
-- Generated from pg_policies on 2026-11-12. Part of the production baseline recovery set.

drop policy if exists mort_profile_avatar_delete_own_folder on storage.objects;
create policy mort_profile_avatar_delete_own_folder on storage.objects as PERMISSIVE for DELETE to authenticated using (((bucket_id = 'profile-avatars'::text) AND ((storage.foldername(name))[1] = (( SELECT auth.uid() AS uid))::text)));

drop policy if exists mort_profile_avatar_read_own_folder on storage.objects;
create policy mort_profile_avatar_read_own_folder on storage.objects as PERMISSIVE for SELECT to authenticated using (((bucket_id = 'profile-avatars'::text) AND ((storage.foldername(name))[1] = (( SELECT auth.uid() AS uid))::text)));

drop policy if exists mort_profile_avatar_update_own_folder on storage.objects;
create policy mort_profile_avatar_update_own_folder on storage.objects as PERMISSIVE for UPDATE to authenticated using (((bucket_id = 'profile-avatars'::text) AND ((storage.foldername(name))[1] = (( SELECT auth.uid() AS uid))::text))) with check (((bucket_id = 'profile-avatars'::text) AND ((storage.foldername(name))[1] = (( SELECT auth.uid() AS uid))::text)));

drop policy if exists mort_profile_avatar_upload_own_folder on storage.objects;
create policy mort_profile_avatar_upload_own_folder on storage.objects as PERMISSIVE for INSERT to authenticated with check (((bucket_id = 'profile-avatars'::text) AND ((storage.foldername(name))[1] = (( SELECT auth.uid() AS uid))::text)));

drop policy if exists mort_proof_delete_owned_pending on storage.objects;
create policy mort_proof_delete_owned_pending on storage.objects as PERMISSIVE for DELETE to authenticated using (((bucket_id = 'proof-uploads'::text) AND (EXISTS ( SELECT 1
   FROM proof_uploads proof
  WHERE ((proof.storage_path = objects.name) AND (proof.uploaded_by = auth.uid()) AND (proof.status = ANY (ARRAY['uploading'::text, 'abandoned'::text])))))));

drop policy if exists mort_proof_read_participants on storage.objects;
create policy mort_proof_read_participants on storage.objects as PERMISSIVE for SELECT to authenticated using (((bucket_id = 'proof-uploads'::text) AND (EXISTS ( SELECT 1
   FROM (proof_uploads proof
     JOIN job_assignments assignment ON ((assignment.id = proof.assignment_id)))
  WHERE ((proof.storage_path = objects.name) AND (proof.status = ANY (ARRAY['submitted'::text, 'approved'::text, 'resubmission_requested'::text, 'rejected'::text])) AND ((auth.uid() = assignment.teen_user_id) OR (auth.uid() = assignment.adult_user_id)))))));

drop policy if exists mort_proof_upload_owned_pending on storage.objects;
create policy mort_proof_upload_owned_pending on storage.objects as PERMISSIVE for INSERT to authenticated with check (((bucket_id = 'proof-uploads'::text) AND (EXISTS ( SELECT 1
   FROM proof_uploads proof
  WHERE ((proof.storage_path = objects.name) AND (proof.uploaded_by = auth.uid()) AND (proof.status = 'uploading'::text))))));

drop policy if exists mort_verification_evidence_insert_own_folder on storage.objects;
create policy mort_verification_evidence_insert_own_folder on storage.objects as PERMISSIVE for INSERT to authenticated with check (((bucket_id = 'verification-evidence'::text) AND ((storage.foldername(name))[1] = (( SELECT auth.uid() AS uid))::text)));

drop policy if exists mort_verification_evidence_read_own_or_staff on storage.objects;
create policy mort_verification_evidence_read_own_or_staff on storage.objects as PERMISSIVE for SELECT to authenticated using (((bucket_id = 'verification-evidence'::text) AND (((storage.foldername(name))[1] = (( SELECT auth.uid() AS uid))::text) OR private.has_staff_role(ARRAY['admin'::mort_role, 'moderator'::mort_role]))));

-- Production storage bucket definitions (mort p), idempotent, from the 2026-11-12 snapshot.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('chat-attachments', 'chat-attachments', false, 10485760, array['image/jpeg', 'image/png', 'image/webp', 'application/pdf']),
  ('dispute-evidence', 'dispute-evidence', false, 26214400, array['image/jpeg', 'image/png', 'image/webp', 'application/pdf', 'video/mp4']),
  ('job-evidence', 'job-evidence', false, 26214400, array['image/jpeg', 'image/png', 'image/webp', 'application/pdf', 'video/mp4']),
  ('profile-avatars', 'profile-avatars', false, 5242880, array['image/jpeg', 'image/png', 'image/webp']),
  ('proof-uploads', 'proof-uploads', false, 10485760, array['image/jpeg']),
  ('verification-evidence', 'verification-evidence', false, 10485760, array['image/jpeg', 'image/png', 'image/webp', 'application/pdf', 'image/heic'])
on conflict (id) do update set name = excluded.name, public = excluded.public, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;
