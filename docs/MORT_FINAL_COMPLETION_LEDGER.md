# MORT Final Completion Ledger

Updated: 2026-08-08 (America/Indianapolis)

This ledger records the active final completion pass. Repository source, hosted
Supabase state, test output, and signed-artifact inspection remain the sources of
truth. Historical reports are evidence only when they still match current source.

## Current State

- Branch: `feature/compact-onboarding-and-screen-polish`
- Current checkpoint: `214ed2a` (`Complete Safety Center and route action audit`)
- Private Samsung/navigation captures are preserved outside distributable
  artifacts under ignored `backups/private-qa-evidence/`.
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
| Safety and action audit | Verified checkpoint | `214ed2a`; durable Safety Center retry, free emergency access, role-scoped Safety Ping, universal guarded route, and generated route/action inventory |
| Hosted backend regression | Verified | 45/45 scripts passed in 511.7 seconds; one transient hosted fetch retried once; isolated QA users removed |
| Dependency/security pass | Verified with upstream limits | Expo SDK 57 patches applied; four transitive advisories patched by compatible overrides; two unpatched Metro `image-size` advisories and one non-reachable Xcode `uuid` advisory remain documented |

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

## Latest Verification

- Linked Supabase migration parity: PASS through `20260808010000`; push dry-run
  reports the remote database is up to date.
- Linked `public,private` schema lint: PASS, no errors.
- Supabase advisors: PASS with no error-level findings. Leaked-password screening
  remains `DEFERRED - PLAN-LIMITED SECURITY ENHANCEMENT` on the Free plan.
- Source secret scan: PASS. Sensitive-file scan: PASS, 1,964 files and 57 known
  app-media files checked. Git-history scan: PASS, 30 commits and 45 candidate
  blobs inspected with zero findings.
- Expo reference app: frozen install PASS; dependency compatibility PASS;
  Expo Doctor 20/20; TypeScript PASS; lint PASS; 48-route web export PASS.
- Flutter dependency lock refreshed within existing constraints; 34 compatible
  package updates resolved successfully.
- Dart format: PASS, 226 files and zero changes required.
- Flutter analyzer: PASS, zero issues before the final navigation repair.
- Focused secure-startup/navigation regression: PASS, 19 tests.
- Full Flutter suite after repair: PASS, 349 tests; two intentional
  provider-configuration skips; zero failures.
- `git diff --check`: PASS.

## Remaining Code-Controlled Work

1. Rerun final analyzer/format checks after the secure-startup navigation repair.
2. Reconcile current Google Play requirements against official sources and
   update Play/privacy/child-safety/reviewer documentation without inventing
   legal or staffing approval.
3. Commit current source, build protected-signed APK/AAB, verify package,
   version, signing, permissions, target API, 16 KB alignment, provenance,
   sizes, and SHA-256 hashes.
4. Use the connected Samsung only through authorized ADB access for the required
   synthetic journeys; preserve screenshots/logcat and classify physical results
   separately from automated results.
5. Clean generated root files, update final reports, and organize release
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

Run the final post-repair analyzer/format gates, commit the verified source, then
reconcile current Google Play requirements and prepare the protected-signed
`0.9.14+104` APK/AAB release candidate.
