# MORT progression final certification report

Date: September 21, 2026

## Verdict

`PASS_CODE_COMPLETE_EXTERNAL_GATES_REMAIN`

The progression implementation and its release hardening pass local certification. Production remains unchanged. Hosted migration deployment, hosted JWT attacks, exact-head CI, and macOS/iOS build and device validation remain external gates.

## Exact Git state

- Repository: `C:\Users\micha\Mort`
- Branch: `feature/compact-onboarding-and-screen-polish`
- HEAD: `fe9c3110c2ae8c501e136714b1072b616826fbaa`
- The checkout contained a large mixed uncommitted UI, UX, platform, and backend worktree before this pass. It was preserved without reset or merge.
- No hosted migration was applied.
- Database ordering was validated in the isolated complete-history worktree `C:\Users\micha\Mort\.worktrees\mort-progression-db-validation` because the UI branch is missing 53 hosted migration versions.

## Progression and security

- Server-authoritative XP covers completed work, first completion, first category completion, complete safety sequences, and eligible post-job reviews.
- Fifty levels map only to Bronze, Silver, Gold, Platinum, and Diamond. Level 50 is the cap.
- Deterministic event keys, account row locks, exact event/source/XP constraints, and request UUIDs prevent award and spend replay.
- Every crossed level receives its token reward; multi-level corrections record crossed levels and rank transitions.
- Motion Tokens are noncash, nontransferable, and spendable only on the private allowlisted cosmetic catalog.
- Private progression tables have RLS, no client policies, and no client table grants. Internal award functions remain unavailable to anonymous and authenticated users.
- Public RPCs bind to `auth.uid()`. The admin correction RPC additionally requires an authenticated admin, a teen target, a bounded reason, a request UUID, and bounded positive XP.
- Leaderboard participation defaults to hidden. Public responses use the approved field allowlist only.
- Progression has no trigger or award source for payment amount, tips, refunds, disputes, subscriptions, ads, verification, reports, blocks, or login frequency.

## Database evidence

- PostgreSQL 17 clean baseline migration execution: passed.
- Full `supabase/tests/progression_v1.sql`: passed.
- Second progression migration application: expected one-shot rejection.
- Level boundaries 1, 10, 11, 20, 21, 30, 31, 40, 41, and 50: passed below, at, and above thresholds.
- First qualifying job: exactly 235 XP; replay: 0 XP.
- Review: 15 XP once; duplicate source: 0 XP.
- Second completion in the same category: no category bonus.
- Incomplete safety: no safety XP and current streak reset.
- Admin correction crossing 30 levels: expected rank transitions and 60 tokens; replay: no-op.
- Direct writes, internal calls, cross-user access, malformed UUIDs, invalid cosmetics, duplicate keys/badges, negative balance, invalid rank/level, and non-admin corrections: rejected.
- Concurrent spending: one winner, idempotent replay, 12 unaffordable burst requests denied, final balance zero.
- Complete-history linked dry run reports exactly two pending migrations:
  - `20260920235334_mort_progression_v1.sql`
  - `20260921090000_account_deletion_financial_fk_repair.sql`

## Regression evidence

- Cross-user RLS, jobs, applications, messaging, optional Guardian Mode, reporting, avatars, reviews, moderation/legal controls, and verification storage passed.
- Five later financial foreign keys using `RESTRICT` were repaired with a guarded migration. Disposable PostgreSQL proved deletion succeeds while retained financial records are deidentified.
- All 25 Stripe regression scripts passed.
- RevenueCat configuration, live API inventory, atomic fulfillment, entitlement forgery, token replay, review entitlement, and free-core boundaries passed. Live webhook replay remains gated by the unavailable protected `REVENUECAT_WEBHOOK_AUTH_HEADER`.
- AdMob disabled mode, future test mode, sensitive placement, and teen treatment passed. Runtime ads default off, AD_ID is stripped, teen decisions are non-personalized, and ads cannot mutate progression.

## Flutter test forensics

- Merge base and current HEAD: 88 Dart test files.
- Working tree: 109 Dart test files: 108 unit/widget files and 1 Android integration file.
- Relative to HEAD: 21 new test files and 0 deleted test files.
- Ordinary Flutter suite: 566 passed, 2 skipped, 0 failed.
- Intentional skips: `closed-test compile configuration activates approved Google Auth`; `Continue with Google is visible and enabled`.
- Android integration: 2 passed, 0 failed.
- Formatting: 309 Dart files, 0 changes.
- Analyzer: no issues.

## Android release certification

- Upload-signed closed-test APK: `C:\Users\micha\Mort\build\play\mort-closed-test-0.9.16-107.apk`
- APK SHA-256: `F1D2E91430CFAD83A40102A8B3FFF6B39DA501E26273ABEE3001831B31656681`
- Upload-signed closed-test AAB: `C:\Users\micha\Mort\build\play\mort-closed-test-0.9.16-107.aab`
- AAB SHA-256: `8F98F3A3E1D479618B37D400A6030052AA109C31BF5703090302BA822E324B0F`
- Package, version, SDK, permissions, signature, exported components, forbidden capabilities, and all 18 native library 16 KB alignments passed.
- Signed release installed and launched on the Pixel 6 emulator with `MainActivity` foreground and no fatal/plugin exceptions.
- Device integration passed secure storage, authentication capability, permissions, screen security, package/version, and six safety acknowledgements at 160% text scale.

## iOS and privacy

- Added and project-wired `PrivacyInfo.xcprivacy` with tracking disabled and progression represented as product interaction data.
- Added Release/Profile push entitlements without changing Debug signing behavior.
- Rank, token, and badge asset directories are bundled.
- App Store privacy and Google Play Data Safety preparation include progression data.
- Xcode, CocoaPods, archive signing, physical iPhone, and TestFlight remain macOS external gates.

## Defects repaired

- Fixed invalid PL/pgSQL syntax and an inverted privacy assertion exposed by PostgreSQL execution.
- Added correct multi-level token accounting, correction authority, and event/metadata/catalog constraints.
- Tightened safety sequence validation.
- Added missing iOS privacy and release entitlement files.
- Updated stale AdMob, RevenueCat, and free-core QA assumptions.
- Fixed the AAB verifier for exact system-permission-protected WorkManager components.
- Fixed the Android integration test's perpetual-animation wait and stale five-checkbox expectation.
- Repaired five later account-deletion financial foreign keys.

## External gates

- Apply both migrations to an approved non-production Supabase project, then run hosted progression and leaderboard attacks with real QA JWTs.
- Reconcile the UI branch with 53 hosted migration files before production deployment.
- Back up and review production before applying migrations.
- Supply the protected RevenueCat webhook header for live replay testing.
- Run exact-head CI from a clean committed branch. The mixed pre-existing worktree was not committed or pushed because that would combine unrelated unreviewed changes.
- Complete macOS/Xcode archive, signing, and iPhone/TestFlight validation.