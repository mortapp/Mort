# MORT Profile Save Root Cause

## Failure

Completed users editing `/settings/profile` were sent through the onboarding
save RPC. `save_my_onboarding_profile` correctly returned
`onboarding_already_completed`, but the Flutter client had no field/code mapping
for that response and displayed a generic save failure. The old client then
performed username, role-detail, and progress writes separately, so a network
failure could leave partial state.

## Fix

Migration `20260802062226_video_profile_job_hardening.sql` adds
`save_my_profile_setup_v2(payload, request_id, complete_onboarding)` with:

- `auth.uid()` ownership and no caller-supplied user ID;
- atomic profile, role detail, username, progress, and audit writes;
- server DOB/age/role/username/location validation;
- immutable role and DOB after setup;
- role-specific normalization;
- an ungranted private request ledger for replay-safe idempotency;
- field and code payloads suitable for focusable client errors;
- authenticated/service-role execution only, with public/anon revoked.

Flutter now uses that RPC for onboarding and settings edits, retains a stable
request ID across retries, stores only encrypted owner-bound local drafts, maps
server fields to controls, focuses the first invalid control, clears drafts on
success, and returns from settings without re-entering onboarding.

## Evidence

- `node scripts/qa-video-profile-job-hardening.mjs`: pass, including setup,
  edit, replay, payload mismatch, immutable-role denial, anon denial, and cleanup.
- Focused profile/onboarding hosted QA: six scripts passed.
- Full hosted regression: 45 scripts passed in 334.7 seconds.
- Flutter: 276 passed, 2 intentional provider skips.

## Remaining Manual Coverage

No real credential was automated. Teen, Adult, and Guardian profile editing on
the exact signed APK remains a closed-test/physical-device checklist item.
