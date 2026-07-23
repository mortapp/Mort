# Profile Avatar Implementation

Implementation date: 2026-07-13

## Storage and access

Avatars use the private Supabase Storage bucket `profile-avatars`.

- Maximum source object size: 5 MB.
- Allowed bucket MIME types: JPEG, PNG, and WebP.
- Stored path: `<authenticated-user-id>/<random-uuid>.jpg`.
- Insert, update, and delete policies require the authenticated user's first path segment.
- Unrelated users cannot list or directly download the bucket.
- Owners create a signed URL directly; other authenticated profile viewers use the deployed `avatar-url` Edge Function, which checks session, profile visibility, account/moderation state, and signs for one hour.
- The Supabase service role exists only in the Edge Function server environment.

## Image privacy processing

`SafeImageProcessor.avatar` performs these operations before upload:

1. Rejects empty, oversized, or unsupported file signatures.
2. Decodes only JPEG, PNG, or WebP.
3. Bakes image orientation.
4. Center-crops to a square.
5. Resizes to 512x512.
6. Re-encodes as JPEG at quality 82.

Re-encoding does not preserve the original EXIF/GPS metadata. No facial recognition or sensitive-trait inference is used.

## Client behavior

`ProfileAvatarEditor` supports gallery selection, camera selection where the platform provides it, replace, and remove. It shows initials when there is no photo or a signed URL cannot be produced. Upload uses a randomized name and `upsert: false`.

The repository writes the new object, updates the profile path, rolls the new object back if the profile update fails, then removes the old object. This order avoids leaving the profile pointed at a missing object.

Avatar views are used in profiles, job/poster presentation, application cards, reviews, and Guardian Mode connections. Admin moderation can set the profile avatar moderation status through protected backend access.

## Verification

Remote QA passed these checks:

- private bucket configuration
- owner upload and owner-prefixed profile path
- unrelated overwrite, list, and direct-download denial
- signed URL through the Edge Function
- replace plus stale-object removal
- remove plus initials fallback

Flutter tests verify JPEG re-encoding, 512x512 square output, unsupported signatures, malformed decoder input, and oversized input.

## Remaining limitations

- The editor uses a deterministic center crop rather than an interactive crop/position modal.
- Upload progress is represented by a busy state, not a byte-level percentage.
- Camera and permission-denial behavior has not been tested on a physical iPhone.
- The report-user flow can report an inappropriate profile, but a dedicated avatar-specific report target is not yet modeled.
- Formal biometric/privacy, child-safety, retention, moderation SLA, and App Store review are still required.
