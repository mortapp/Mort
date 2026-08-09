# MORT Final Completion Ledger

Updated: 2026-08-08 (America/Indianapolis)

This ledger records the active final completion pass. Repository source, hosted
Supabase state, test output, and signed-artifact inspection remain the sources of
truth. Historical reports are evidence only when they still match current source.

## Current State

- Branch: `feature/compact-onboarding-and-screen-polish`
- Current checkpoint: `ef1cbdd` (`Complete protected messaging context and recovery`)
- Worktree after checkpoint: clean; root navigation screenshots/XML preserved in
  ignored `artifacts/qa-evidence/public-navigation-2026-08-08/`
- Flutter application: `flutter_mort/`
- Android package: `com.mortapp.mobile`
- Hosted Supabase project: `rakjydmgwwgtdislanbt`
- Public marketplace: fail-closed until real production identity verification,
  legal approval, and staffed safety operations exist

## Completed In This Pass

| Area | Status | Evidence |
|---|---|---|
| Public Back stack | Verified checkpoint | `bf37a9d`; physical navigation evidence preserved under `artifacts/qa-evidence/` |
| Shared Liquid Glass system | Verified checkpoint | `91904ed`; selective blur, reduced-transparency fallback, semantic rose/blue/success states |
| Teen routed destinations | Verified checkpoint | `a322e62`, `042116b`; StatefulShellRoute destinations and production flows |
| Unified authentication UI | Verified checkpoint | `08684c5`; sign-in/sign-up routes share one accessible screen |
| Role dashboards | Verified checkpoint | `6545efc`; Adult, Guardian, and Admin grouped production routes; focused tests pass |
| Settings and device preferences | Verified checkpoint | `d487135`; persisted motion, transparency, contrast, haptic preferences and grouped routes |
| Messaging completion | Hosted and local verified | `ef1cbdd`; safe participant/job context, keyset pagination, realtime cancellation, unread state, report/block, visible retry, text-only boundary |

## Hosted Messaging Evidence

- Migration `20260808010000_message_thread_context_and_pagination.sql` is applied
  locally and remotely.
- Pre-apply schema backup:
  `backups/remote-feature-schema-rakjydmgwwgtdislanbt-2026-08-09T00-56-04-482Z.json`
  (5,776,825 bytes; SHA-256
  `85DD49BFC5DDF491BE238602EA850E2D64DA4787E7E2D4E6B772B5E0FF44CEC7`).
- Linked schema lint: no error-level findings.
- Direct PostgreSQL JWT/RLS QA: participant context passed; private helper,
  outsider, and anonymous access denied; transaction rolled back.
- Hosted authenticated API QA: teen/adult context, search, unread count, message
  summary, outsider denial, and anonymous denial passed; ephemeral users removed.

## Latest Local Verification

- `flutter analyze --no-pub`: PASS, no issues.
- Focused messaging/settings/dashboard/navigation/auth suite: PASS, 29 tests.
- `git diff --check`: PASS.
- Note: one earlier aggregate command referenced nonexistent
  `test/back_navigation_test.dart`; the corrected repository file is
  `test/mort_back_navigation_test.dart`, and the rerun passed.

## Remaining Code-Controlled Work

1. Reconcile Safety Center and profile/admin/support surfaces against the final
   directive and add only missing production states or tests.
2. Regenerate and inspect the route/action inventory; repair dead buttons,
   unguarded routes, placeholder production actions, and missing failure states.
3. Run format, analyzer, complete Flutter tests, backend regression, RLS/storage/
   Edge Function audits, secret scans, and dependency/security checks.
4. Reconcile current Google Play requirements against official sources and
   update Play/privacy/child-safety/reviewer documentation without inventing
   legal or staffing approval.
5. Commit current source, build protected-signed APK/AAB, verify package,
   version, signing, permissions, target API, 16 KB alignment, provenance,
   sizes, and SHA-256 hashes.
6. Use the connected Samsung only through authorized ADB access for the required
   synthetic journeys; preserve screenshots/logcat and classify physical results
   separately from automated results.
7. Clean generated root files, update final reports, and organize release
   artifacts without overwriting immutable historical artifacts.

## External Gates

- Production identity-verification provider contract, credentials, and real-ID
  collection remain unavailable; sandbox verification is QA-only.
- Attorney, child-safety, privacy, tax/payment, and insurance decisions remain
  human responsibilities.
- Real moderation/support/on-call staffing and escalation commitments remain
  unverified.
- Production push/crash/payment provider activation remains credential/provider
  gated where runtime flags are fail-closed.
- Play Console declarations, production access, and review decisions remain
  external.
- iPhone/Xcode/TestFlight/App Store verification cannot be completed on this
  Windows host and must not be reported as passed.

## Next Exact Step

Audit Safety Center routes, interactions, loading/empty/error states, and focused
tests; then run the generated route/action inventory against every production
destination.
