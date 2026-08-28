# MORT Profile Avatar System

Status: implemented and remotely authorization-tested; cross-device physical-device QA remains.

- Database authority is the stable `profiles.avatar_path`, never a signed URL.
- `avatar_version`, update time, moderation state, and visibility support cache invalidation and moderation.
- Private bucket: `profile-avatars`, 5 MB, canonical JPEG only.
- Canonical object path: `<owner_uuid>/<generated_uuid>.jpg`.
- Flutter decodes, square-crops, resizes, re-encodes JPEG, and therefore strips source EXIF/geolocation metadata.
- Replacement updates the database before old-object deletion. Removal clears the path and object.
- `avatar-url` authenticates the bearer token, calls `authorize_profile_avatar_url`, respects blocks and participant relationships, rate-limits requests, and returns a short-lived URL.
- Other users cannot list, overwrite, or directly download avatar originals.

QA evidence: `qa-avatar-storage.mjs`, `qa-complete-multi-user-isolation.mjs`, Flutter avatar contract/widget tests. The 2026-07-22 worker identifier collision was fixed and the function redeployed before the final 26-script pass.
