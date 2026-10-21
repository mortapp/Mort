# MORT School Identity + Focused Onboarding Design

## Goal

Make teen onboarding easier to complete on a phone while strengthening school identity and affiliation verification. The UI should stay simple while the backend binds a teen to a canonical school record and a separately reviewed school-email domain.

## Product behavior

Teen onboarding becomes focused progressive disclosure instead of one large account form. The user moves through age, school, school-email verification, MORT identity, general area, work preferences/transport, safety/support, and review. Existing adult/guardian behavior remains supported and does not require school verification.

The teen flow must preserve the core safety rule: a listed school does not prove a student attends it. School-record verification and student-affiliation verification are distinct states.

## Canonical school identity

`public.schools.id` remains the stable internal identifier. Add authoritative metadata without exposing it as a user-facing credential:

- `nces_school_id text` for public-school NCES identifiers, preserving leading zeroes;
- `state_school_id text`, scoped by `state`;
- explicit grade-offered booleans for grades 7-12 plus derived `lowest_grade` / `highest_grade` display fields;
- source metadata and `school_record_verified` / verification-source fields.

Duplicate display names remain distinct when canonical IDs/location differ.

## School email domains

Reuse the existing `public.school_domains` + `private.school_domain_assignments` architecture. Do not put a single mutable domain string directly on `public.schools`.

Domain matching remains exact after normalization. Similar school names do not imply domain sharing. Herron mappings must be:

- Herron High School -> `herron.org`
- Herron-Riverside High School -> `herronriverside.org`

A shared domain may map to multiple schools, but the selected school remains authoritative and email validation must not silently change campuses.

## Verification states

1. `school_record_verified`: the institution record has authoritative/vetted identity evidence.
2. `school_affiliation_verified`: the authenticated user proved control of an approved school-issued email for the selected canonical school.
3. Existing MORT Verify school-ID/document review remains an optional additional affiliation/age signal; do not create a duplicate upload system.

NCES/state IDs never by themselves prove student attendance.

## Onboarding UX

The current account step is overloaded. Split it into focused client steps while preserving the existing server-side onboarding APIs and completion state where possible.

Teen visual steps:

1. Age
2. School
3. Verify school email
4. Your MORT identity
5. General area
6. Work preferences and transportation
7. Safety and support
8. Review and finish

Adult/guardian users skip teen-only school steps after age routing.

Each screen should have one primary purpose. Keyboard-visible content and CTA placement must remain usable on small Android screens. Back navigation preserves entered values.

## Privacy

School email, NCES/state identifiers, and exact school affiliation must not be added to public profile/leaderboard/share-card analytics payloads. Normal user-facing surfaces should show status such as `School verified`, not repeatedly display the school email.

## Error copy

Domain mismatch copy should name the selected school but not reveal another school's allowed domain:

`That email doesn't match <school>. Use the school-issued email for this school, or change your school.`

## Test requirements

- Herron-Riverside accepts only its approved domain; Herron High accepts only its own.
- suffix attack domains fail.
- shared-domain school selection remains stable.
- canonical school records can share display names but remain distinct.
- school-record verification does not imply affiliation verification.
- onboarding age screen no longer renders profile/location/transport fields.
- school-email screen does not render unrelated onboarding fields.
- small-screen/keyboard contract remains usable.

## Constraints

- additive migrations only;
- no hosted Supabase changes in this pass;
- preserve email-guard/session-live work;
- no production rollout/release rebuild;
- no new school-ID upload subsystem;
- no weakening of under-13, teen, guardian, MORT Verify, RLS, privacy, moderation, or account-deletion controls.
