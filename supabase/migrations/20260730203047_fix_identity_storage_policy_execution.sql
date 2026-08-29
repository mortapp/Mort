-- Phase 11 recreated this broad Storage SELECT policy with a direct call to a
-- private helper. PostgreSQL may evaluate that branch for non-identity rows,
-- so ordinary authenticated avatar replacement could fail before DELETE.
-- Use the existing SECURITY DEFINER current-user wrapper intended for RLS.
drop policy if exists storage_mort_owner_select on storage.objects;

create policy storage_mort_owner_select
on storage.objects for select to authenticated
using (
  (
    bucket_id = any (array['proof-uploads', 'report-uploads'])
    and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or public.is_admin()
      or (
        bucket_id = 'proof-uploads'
        and exists (
          select 1 from public.proof_uploads proof
          where proof.storage_path = storage.objects.name
            and public.is_application_participant(proof.application_id)
        )
      )
    )
  )
  or (
    bucket_id = 'verification-uploads'
    and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or public.current_user_is_production_identity_reviewer()
    )
  )
);

-- COMMENT ON POLICY requires literal ownership of storage.objects. Hosted
-- Supabase grants that; local Supabase CLI's Postgres image does not (it only
-- grants policy CREATE/DROP), so make this metadata-only annotation tolerant
-- of that local-only ownership gap instead of aborting the whole replay.
do $$
begin
  execute $ddl$comment on policy storage_mort_owner_select on storage.objects is
    'Owner/participant access for proof and report files plus the RLS-safe current-user reviewer wrapper for retained legacy verification files.'$ddl$;
exception
  when insufficient_privilege then
    null;
end;
$$;
