-- MORT private Storage setup.
-- Run only after the main MORT migration, because these policies reference public.is_admin()
-- and public.is_application_participant().

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('proof-uploads', 'proof-uploads', false, 10485760, array['image/jpeg', 'image/png', 'image/heic', 'image/webp']),
  ('verification-uploads', 'verification-uploads', false, 10485760, array['image/jpeg', 'image/png', 'image/heic', 'image/webp']),
  ('report-uploads', 'report-uploads', false, 10485760, array['image/jpeg', 'image/png', 'image/heic', 'image/webp'])
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname = 'storage_mort_owner_insert') then
    create policy storage_mort_owner_insert on storage.objects
    for insert with check (
      bucket_id in ('proof-uploads', 'verification-uploads', 'report-uploads')
      and (storage.foldername(name))[1] = auth.uid()::text
    );
  end if;

  if not exists (select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname = 'storage_mort_owner_select') then
    create policy storage_mort_owner_select on storage.objects
    for select using (
      bucket_id in ('proof-uploads', 'verification-uploads', 'report-uploads')
      and (
        (storage.foldername(name))[1] = auth.uid()::text
        or public.is_admin()
        or (
          bucket_id = 'proof-uploads'
          and exists (
            select 1
            from public.proof_uploads pu
            where pu.storage_path = storage.objects.name
              and public.is_application_participant(pu.application_id)
          )
        )
      )
    );
  end if;

  if not exists (select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname = 'storage_mort_owner_update') then
    create policy storage_mort_owner_update on storage.objects
    for update using (
      bucket_id in ('proof-uploads', 'verification-uploads', 'report-uploads')
      and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin())
    )
    with check (
      bucket_id in ('proof-uploads', 'verification-uploads', 'report-uploads')
      and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin())
    );
  end if;
end $$;
