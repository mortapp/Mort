# MORT Codex Overnight State

- Updated: 2026-08-09 (America/Indianapolis)
- Branch: `feature/compact-onboarding-and-screen-polish`
- Runtime artifact source:
  `79630b195098a2c5428a30104b55cfec27ea764f`
- Version: `0.9.15+105`
- Package: `com.mortapp.mobile`

## Current Verdict

**ANDROID CLOSED-TEST ENGINEERING CANDIDATE VERIFIED - OWNER LEGAL AND STORE
APPROVALS REMAIN**

MORT is not production-ready. Public marketplace access, real identity
verification, real payments, and public activation remain fail-closed.

## Completed

- Applied and remotely verified the orphaned-onboarding-progress repair through
  migration `20260809040544` without creating legal acknowledgements.
- Replaced legacy predictive-Back handling with `PopScope`, corrected the
  server onboarding order, and physically passed Profile/Skills and all safe
  onboarding Back transitions.
- Corrected legal-reference navigation so all four Safety links return to the
  invoking Safety step. The replacement APK passed all four physical checks.
- Performed exactly one authorized local-data reset on the Samsung SM-A146U and
  completed the real Google/Supabase PKCE flow with the authorized QA account.
  Private chooser evidence remains ignored under `artifacts/`.
- Physically verified the final signed APK callback, authenticated account
  status, and server-persisted Safety resume path. Final callback logs contain
  zero invalid matrices, Flutter errors, crashes, ANRs, router failures,
  overflows, or predictive-back warnings.
- Fixed the post-OAuth route mismatch that sent incomplete users into an old
  compact wizard. Focused regression: 44 passed; analyzer: zero issues; final
  full Flutter suite: 352 passed and two provider-gated skips.
- Final post-OAuth cold starts: 5/5 `COLD`, 5/5 Safety resume, no OAuth reopen,
  blank screen, route error, crash, or secure-startup error.
- Earlier `0.9.15` physical checks passed Home/resume x3 and Safety at 1.3 text
  scale; font scale was restored to `1.0`. Screen off/on preserved the process,
  then correctly stopped at Samsung's secure keyguard.
- Expanded hosted Supabase regression passed all 46 scripts. Linked migration
  parity, schema/storage lint, security advisors, RLS, and storage checks pass.
- Final signed APK/AAB pass package, version, permission, upload-signing,
  binary-secret, and 18/18 native-library 16 KB checks.

## Final Artifacts

- APK: `artifacts/release-0.9.15+105/mort-closed-test-0.9.15.apk`
  - 69,287,402 bytes
  - SHA-256
    `A4578C163638A952B8C1B9F6BE8CC190B3F38D1C7B927A5F4AEA200C6E918E10`
- AAB: `artifacts/release-0.9.15+105/mort-closed-test-0.9.15.aab`
  - 52,164,950 bytes
  - SHA-256
    `84758C39817B42129282CBD74BD9FAC2B37854CCEA04EC4CA81946793DFFA144`

## Human And External Gates

- The authorized role is Teen and onboarding is paused at owner-controlled
  safety/legal acknowledgements. No legal, DOB, identity, address, guardian, or
  payment declaration was fabricated.
- Teen dashboard, Messages, and Settings physical role journeys remain behind
  that legal step. Adult Back was not applicable to this account.
- Physical offline cold start was not attempted because wireless-only ADB would
  lose the device. Screen-on visual resume requires the owner's Samsung unlock.
- Legal/privacy/child-safety approval, provider contracts, staffed moderation
  and support, Play Console declarations/review, and public activation remain
  external.
- iPhone, Xcode, TestFlight, App Store privacy manifests, and App Store review
  were not performed.

## Next Exact Step

The owner should review and personally complete the Safety acknowledgements on
the QA account. Then run the Teen dashboard, Messages, Safety, Notifications,
Profile, and Settings physical matrix before expanding the closed-test cohort.
