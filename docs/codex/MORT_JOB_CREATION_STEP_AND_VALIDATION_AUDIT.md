# MORT Job Creation Step and Validation Audit

## Authoritative Flow

`JobCreationStep` is the only source for the eight visible steps:

1. Basics
2. Schedule
3. Location
4. Safety
5. Pay
6. Eligibility
7. Review
8. Submit

The router renders the active enum value and derives progress from the same
list, removing the recorded missing-step sequence.

## Validation and Persistence

| Area | Client behavior | Server behavior |
| --- | --- | --- |
| Category | Searchable bottom sheet and required selection | Allowed/required values remain authoritative |
| Duration/workers/radius/age | Field errors and focus | Field-coded range errors |
| ZIP/location/environment | Format and required-state errors | Field-coded normalization/validation |
| Physical/proof/safety | Conditional controls | Contradiction and proof-policy validation |
| Pay/transport | Input review and truthful copy | Existing job contract remains authoritative |
| Draft | Encrypted owner-bound local recovery plus server draft | Stable idempotency ID and real draft row |
| Publish | No local success fabrication | Returns `open`, `pending_review`, or `not_open` |

The closed-pilot UI says `Saved for closed-pilot review. Applications remain
closed.` when the server does not open applications. It never substitutes a
fake `Job published` success.

## Evidence

- Hosted video hardening QA passed coded duration, ZIP, and proof errors; draft
  persistence; open-state truthfulness; anon denial; and cleanup.
- Hosted job lifecycle and applications QA passed.
- `video_profile_job_hardening_test.dart` and
  `secure_draft_storage_test.dart` passed in the full suite.
- Job draft serialization covers app-process recovery, malformed data, owner
  mismatch, and the 64 KB storage cap.

## Manual Gap

The eight screens were not completed under a credentialed Adult account on the
exact final APK in this run. That scenario remains unverified on emulator and
physical device even though its client/server contracts passed.
