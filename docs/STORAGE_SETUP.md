# Storage Setup

MORT uses private Supabase Storage buckets only.

Required buckets:

- `proof-uploads`
- `verification-uploads`
- `report-uploads`

## Apply

The main migration creates these buckets and policies. If Storage needs to be repaired after the migration, review and run:

```powershell
supabase db query --file supabase/storage_setup.sql
```

Run this only after the main migration because the policies reference MORT helper functions.

## Bucket Rules

- Buckets must remain `public = false`.
- Do not use `getPublicUrl` for proof, verification, or report files.
- Do not make bucket-wide public read policies.
- Keep file size and MIME allow-lists narrow.

## Upload Rules

- Proof upload: the teen on an accepted application uploads to `proof-uploads/<auth.uid()>/...`, then the app inserts a `proof_uploads` row tied to that application.
- Verification upload: an adult uploads to `verification-uploads/<auth.uid()>/...`, then submits a `business_verifications` row.
- Report evidence upload: a user uploads to `report-uploads/<auth.uid()>/...`; report evidence should be tied to moderation records before production expansion.

## View Rules

- Owners can select their own objects.
- Admins can select MORT private upload objects.
- Proof application participants can select proof objects linked through `proof_uploads.storage_path`, which allows signed preview URLs.
- Verification and report evidence are not public; admins review them through trusted/admin flows.

## Signed URL Preview

The app calls `createSignedUrl` for proof previews. Signed URLs should be short-lived and generated only after RLS confirms the user can select the object.
