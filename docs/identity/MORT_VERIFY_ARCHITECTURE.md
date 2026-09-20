# MORT Verify architecture

Last audited: 2026-09-20

## Canonical verification path

MORT Verify is a first-party teen school-affiliation and age-assurance flow. Production collection is fail-closed. The canonical path is:

1. The authenticated teen enters an approved school email.
2. The `mort-verify` Edge Function starts a server-gated session.
3. An eight-digit school-email challenge is generated in the Edge Function. Only an HMAC-SHA256 digest is stored; raw codes are not stored in Postgres.
4. After the school-email challenge succeeds, the teen may upload a school ID to the private `mort-verify-evidence` Storage bucket.
5. Upload paths are bound to `{user_id}/{session_id}/{front|back}/{uuid}.{ext}`. The server validates object ownership, byte size, extension, magic bytes, MIME type, and SHA-256 before registering evidence.
6. The teen submits the session for manual review.
7. An authorized reviewer claims a short-lived assignment. Raw evidence is exposed only through a five-minute signed URL, and the server re-checks the reviewer's current safety role when that URL is requested.
8. Review decisions keep three claims separate: school affiliation, student identity consistency, and age assurance. A school email alone never proves age.
9. A verified age result is restricted to the 13–15 or 16–17 bands. A `manual_exception` age decision requires a current senior safety moderator role.
10. Verification does not claim a government-issued legal identity and does not itself grant marketplace access.

## Fail-closed controls

`private.mort_verify_control` defaults to:

- `mode = disabled`
- `school_email_enabled = false`
- `school_id_enabled = false`
- `manual_review_enabled = false`
- `production_document_collection_approved = false`

Production collection therefore requires an explicit server-side activation decision after legal, privacy, reviewer-operations, and release gates are complete.

## Evidence access

Raw school IDs are not public profile data. Authenticated users receive no read policy on the canonical evidence bucket. Review access requires both:

- a current `verification_reviewer` or `senior_safety_moderator` role; and
- a live, unrevoked review assignment.

The service helper re-validates both conditions before document metadata is returned to the Edge Function for signed-URL creation.

## Retention

Canonical raw school-ID evidence has a default 14-day retention deadline. A scheduled protected worker removes Storage objects after expiration and then marks their metadata deleted, unless a preservation hold or active review assignment blocks deletion.

The older `teen_verification_*` implementation is retained only for historical records and cleanup compatibility. Its authenticated client/reviewer RPCs and Storage policies are revoked, its control row is disabled, and only service-role retention cleanup remains available.

## Canonical components

- Flutter repository: `flutter_mort/lib/data/repositories/mort_verify_repository.dart`
- Flutter flow: `flutter_mort/lib/features/trust/teen_verification_screens.dart`
- Edge Function: `supabase/functions/mort-verify/index.ts`
- Retention worker: `supabase/functions/teen-verification-retention-processor/index.ts`
- Canonical migrations: `20260920201000`, `20260920203500`, `20260920205000`, `20260920214100`, `20260920214728`
