# MORT Verify privacy and retention

Last audited: 2026-09-20

## Data minimization

MORT Verify separates school affiliation, student identity consistency, and age assurance. Public trust output does not expose the raw school ID, school email, date of birth, document path, or reviewer notes.

A verified school-affiliation signal explicitly states that it does not establish a government-issued legal identity.

## Raw school-ID evidence

Canonical evidence is stored in the private `mort-verify-evidence` bucket. The default raw-document retention period is 14 days and is server-configurable only within the bounded control-table constraint.

Reviewer links are signed for five minutes. Authenticated clients do not receive a general raw-evidence read policy.

A preservation hold may extend retention. An active review assignment also blocks scheduled deletion so a review cannot lose its evidence mid-session.

## Scheduled deletion

The protected retention worker processes both:

- historical `teen-school-id` evidence; and
- canonical `mort-verify-evidence` evidence.

For each eligible object it removes the Storage object first, then finalizes the database record. Canonical document metadata is marked `deleted` and a non-document audit event records the retention purge.

The worker requires a valid JWT at the Edge gateway and performs a constant-time comparison against the service-role bearer token before using service privileges.

## Legacy path

The superseded `teen_verification_*` client/reviewer API surface is disabled. Its Storage access policies are removed. Legacy retention service functions remain available solely so historical sandbox evidence can age out safely.

## Production gate

Production document collection remains disabled. Enabling it requires an explicit server-side change after legal/privacy review and operational reviewer readiness; no Flutter client flag can independently activate collection.
