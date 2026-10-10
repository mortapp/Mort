# MORT School Identity + Focused Onboarding Implementation Plan

> **For agentic workers:** implement sequentially in this same agent/session. TDD is required; do not spawn sub-agents.

**Goal:** Separate school identity from student affiliation, correct Herron domain mapping, add canonical school identifiers/grade span, and split teen onboarding into focused phone-friendly steps.

**Architecture:** Keep `public.schools` as the canonical institution table and reuse the existing private school-domain assignment gate. Add authoritative metadata through one additive migration and expose only non-sensitive school-search fields. Refactor `CompactOnboardingScreen` into focused client steps while preserving existing server-side onboarding APIs and role routing.

**Tech Stack:** PostgreSQL/Supabase migrations + SQL tests; Flutter/Dart + Riverpod; GitHub Actions MORT CI.

**Spec:** `docs/superpowers/specs/2026-10-10-school-identity-onboarding-design.md`

## Global Constraints

- No hosted changes, production rollout, or release rebuild.
- Preserve email-guard/session-live work and unrelated branch behavior.
- Additive migrations only.
- Exact domain matching; no suffix-based trust.
- `school_record_verified` never implies `school_affiliation_verified`.
- Reuse existing MORT Verify school-ID/document review.
- Teen school email and institutional IDs stay out of public surfaces.

## Review Focus

- Similar-school/domain confusion must fail closed.
- Shared-domain campuses must not silently switch school identity.
- Grade-span metadata must not depend on school-name text.
- Back/keyboard behavior must preserve entered values on small screens.
- Legacy users must not lose access merely because authoritative metadata is absent.

---

### Task 1: Add RED school identity/domain tests

**Files:**
- Modify: `supabase/tests/classic_school_email_gate.sql`
- Create: `flutter_mort/test/school_identity_contract_test.dart`

- [ ] Add SQL assertions for Herron vs Herron-Riverside exact-domain separation and suffix-attack rejection.
- [ ] Add Flutter contract assertions for canonical identifier/grade-span parsing.
- [ ] Run PR CI and confirm RED because the metadata/mapping does not exist yet.

### Task 2: Add canonical school metadata + Herron mappings

**Files:**
- Create: `supabase/migrations/20261010090000_school_identity_metadata_and_domains.sql`
- Modify: `flutter_mort/lib/data/models/school_directory_entry.dart`

- [ ] Add NCES/state/source/grade-span fields and constraints/indexes.
- [ ] Extend `search_schools` output with verified-record and grade-span fields, not sensitive identifiers.
- [ ] Add independently reviewed Herron domain assignments without exposing private mappings to clients.
- [ ] Re-run focused SQL/Flutter tests to GREEN.

### Task 3: Add explicit school-record vs affiliation status contract

**Files:**
- Modify migration from Task 2.
- Modify: `flutter_mort/lib/data/repositories/school_directory_repository.dart`

- [ ] Make signup preflight return safe status codes distinguishing unverified school record from email mismatch where appropriate without revealing another school's domain.
- [ ] Keep actual affiliation binding dependent on confirmed account email + selected-school approved assignment.
- [ ] Add tests proving school-record verification alone cannot create affiliation.

### Task 4: Split onboarding into focused client steps

**Files:**
- Modify: `flutter_mort/lib/features/onboarding/compact_onboarding.dart`
- Modify: `flutter_mort/test/compact_onboarding_test.dart`
- Modify: `flutter_mort/test/small_screen_pressure_test.dart`

- [ ] Add RED widget tests proving age no longer co-renders identity/location/transport and school-email is isolated.
- [ ] Refactor local visual step routing while preserving server-side save APIs and role behavior.
- [ ] Keep keyboard-visible CTA/content and entered-state preservation.
- [ ] Run focused widget tests to GREEN.

### Task 5: Improve school picker disambiguation

**Files:**
- Modify: `flutter_mort/lib/features/auth/school_directory_picker.dart`
- Modify: relevant picker tests.

- [ ] Show canonical display name + city/state + grade span.
- [ ] Preserve canonical school UUID selection.
- [ ] Keep request-school fallback and do not surface NCES/state IDs to users.

### Task 6: Full verification and push evidence

- [ ] Review full diff and run `git diff --check` via CI/static checks.
- [ ] Run Flutter format/analyze/full tests in GitHub Actions.
- [ ] Run local Supabase regression job from PR CI where configured.
- [ ] Run secret scanning.
- [ ] Perform sequential Believer/Skeptic/Operations/Judge review over exact HEAD.
- [ ] Push final exact HEAD and report unresolved hosted/device gates without claiming deployment.
