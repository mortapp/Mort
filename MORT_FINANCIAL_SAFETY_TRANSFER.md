# MORT Financial Safety — Forensic Inventory & Transfer

Read-only forensic inventory of the Financial Safety implementation preserved on the
untouched `feature/compact-onboarding-and-screen-polish` checkout (open PR #4), per
the completion program's explicit instruction. **PR #4 and its dirty checkout were
never modified, reset, cleaned, merged, or rebased** — only read from
(`cp`/`Read`/`Grep`, never `git` mutation commands) to build this branch's own copy.

## Inventory

| File | Lines | Classification |
|---|---|---|
| `flutter_mort/lib/core/utils/financial_math.dart` | 108 | SAFE_TRANSFER — zero dependencies |
| `flutter_mort/lib/data/models/financial_safety.dart` | 560 | SAFE_TRANSFER — zero dependencies, no name collisions |
| `flutter_mort/lib/data/repositories/financial_repository.dart` | 364 | SAFE_TRANSFER — RPC names verified to match the transferred migration |
| `flutter_mort/lib/features/financial/financial_export_service.dart` | 264 | SAFE_TRANSFER — needed 2 new pubspec deps (`pdf`, `share_plus`), no conflicts |
| `flutter_mort/lib/features/financial/financial_safety_center.dart` | 456 | CONFLICTING (minor) — referenced `atmosphereIntensity`/`MortAtmosphereIntensity`, part of the unrelated atmosphere-redesign UI work also on PR #4, not present on this branch. Removed the one reference (decorative-only, `MortScreen` works correctly without it); everything else transferred as-is. |
| `flutter_mort/lib/features/financial/financial_section_screens.dart` | 1595 | SAFE_TRANSFER — no atmosphere/unrelated-UI references found |
| `flutter_mort/test/financial_exports_test.dart` | 137 | SAFE_TRANSFER |
| `flutter_mort/test/financial_guide_routes_test.dart` | 52 | SAFE_TRANSFER (required two small additive edits elsewhere — see below) |
| `flutter_mort/test/financial_math_test.dart` | 215 | SAFE_TRANSFER |
| `flutter_mort/test/financial_screens_test.dart` | 679 | SAFE_TRANSFER |
| `supabase/migrations/20260831120000_mort_earnings_safety_v1.sql` | 1145 | SAFE_TRANSFER — see shared-function reconciliation below |
| `supabase/migrations/20260905180000_work_earnings_payment_status_guard.sql` | 52 | ALREADY_PRESENT as of this session — independently identified the same vulnerability was live on this branch too (shared ancestor table/policy) and transferred the fix in isolation *before* this larger transfer, as commit `e7b2b2b` (`supabase/migrations/20260907010000_work_earnings_payment_status_guard.sql`) |

## Shared-file reconciliation (the actual "conflict resolution" work)

Two backend functions and two Flutter files are touched by *both* branches
independently. Compared each byte-for-byte before transferring:

1. **`public.get_mort_guide_config()`** and **`public.support_get_config()`**
   (defined in `20260722042500_mort_guide_foundation.sql` /
   `20260729212722_mort_support_safety_priority_hardening.sql` on this branch): the
   financial migration's versions were **byte-for-byte identical** to this branch's
   current (already-hardened) versions except for one additive
   `'financial_safety': jsonb_build_object(...)` key appended to the returned JSON.
   The financial branch was built on top of the same hardened version, not a stale
   one — confirmed by diffing both bodies directly, not assumed. Copying the whole
   migration file (which `create or replace function`s both, in-place, after the
   existing definitions in migration-replay order) applies this correctly with zero
   manual patching needed.
2. **`lib/core/utils/safe_uri.dart`** (`safeInternalHelpRoute`): the only diff was two
   allowlist entries (`/financial`, `/financial/`) added to the existing `exact`/
   `prefixes` sets. Applied that exact two-line diff manually rather than copying the
   whole file (which would have required checking the rest of the file for unrelated
   drift — it was simpler and safer to apply the minimal delta directly).
3. **`lib/features/guide/mort_guide_screens.dart`**
   (`MortGuideSuggestedQuestions.questions`): the only diff was three additional
   suggested-question strings inserted into the existing list. Same approach — applied
   the minimal three-line delta, not a file copy.
4. **`lib/core/routing/app_router.dart`**: the surrounding context
   (`/teen/goals` immediately followed by `/teen/hustle-academy`) was byte-identical
   between both branches at the insertion point, confirming this section hadn't
   diverged. Inserted only the 8 new `_guarded(..., role: UserRole.teen)` route
   entries plus 2 import lines — not the unrelated route/import changes elsewhere in
   that file from PR #4's other UI work.
5. **`lib/data/repositories/providers.dart`**: same approach — the insertion points
   (`stripeMarketplaceRepositoryProvider` → `authStateProvider`, and
   `ref.invalidate(adminRepositoryProvider)`) were identical on both branches.
   Inserted only the financial provider block and its invalidation calls.
6. **`pubspec.yaml`**: added `pdf: ^3.13.0` and `share_plus: ^13.3.0` (exact versions
   used on PR #4) — the only two new dependencies this feature needs; `flutter pub
   get` resolved them without any version conflicts against this branch's existing
   dependency set.

## UNRELATED (explicitly not transferred)

- `lib/core/atmosphere/` (the whole atmosphere visual-effects system) and the one
  `atmosphereIntensity` reference to it inside `financial_safety_center.dart` —
  cosmetic background-effect work from a separate PR #4 initiative
  (`docs/superpowers/plans/2026-08-29-production-ui-atmosphere-redesign.md`),
  unrelated to Financial Safety's substance. `MortScreen` renders correctly without
  it (confirmed: its current constructor on this branch has no such parameter at
  all, so this was never optional wiring — it's cleanly absent).
- Any other uncommitted PR #4 files (onboarding/mascot/branding work) — not
  inspected further than confirming they aren't referenced by anything financial-
  related, since they're out of scope for this transfer entirely.

## Verification

- `flutter pub get`: resolved cleanly, 6 packages changed, no conflicts.
- `dart format`: clean, 0 changes needed on any transferred file.
- `flutter analyze`: found exactly 2 errors (both the `atmosphereIntensity` reference
  above, same root cause) — fixed, re-analyzing to confirm clean.
- Full `flutter test` regression: pending (see commit for final count).
