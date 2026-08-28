# MORT Profile Persistence Fix

## Canonical write paths

- `save_my_onboarding_profile`: creates or updates only the caller's incomplete onboarding profile, derives eligibility from the server date, and prevents role or DOB changes after first assignment.
- `update_my_profile`: accepts a JSON patch containing only explicitly mutable fields, locks the caller's row, supports optimistic conflict detection, records idempotent request IDs, and returns the committed profile.
- `complete_my_onboarding`: validates and completes only the caller's profile through existing server constraints and triggers.

All three functions use `auth.uid()`, return structured codes, and audit field names without storing submitted values. Public and anonymous execution is revoked.

## Flutter behavior

`ProfileRepository` no longer directly updates or upserts `profiles`. It parses the profile returned by the RPC and throws a coded error if the server does not return `ok: true` with a complete persisted row. The UI invalidates the profile provider only after that response. Recoverable failures retain controller text, and `_busy` prevents duplicate taps.

Avatar upload remains compensating: if the profile reference fails, the newly uploaded object is removed. Previous avatar cleanup happens only after the server accepts the new reference.

## Verified QA

- Persistence after a fresh server read and sign-out/sign-in
- Idempotent duplicate request replay
- Stale-write conflict response
- Role, DOB, verification, account, test-account, and onboarding forgery rejection
- Cross-user direct and RPC update isolation
- One auth user to one profile row
- Directory projection excludes exact DOB, private location, account state, and payment preference
- Private avatar upload, replacement, cleanup, and cross-user denial
