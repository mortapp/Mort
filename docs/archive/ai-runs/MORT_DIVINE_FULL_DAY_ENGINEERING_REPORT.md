# MORT Divine Full-Day Engineering Report

Generated from the final verified source and artifacts on 2026-08-16. This is a closed-test engineering report, not a production-readiness claim.

## Source

- Branch: `feature/compact-onboarding-and-screen-polish`
- HEAD: `370437b4218724eb5d9eec38ec98c7d337feddb5`
- Version: `0.9.15+106`
- Worktree: DIRTY (117 tracked/untracked paths at the final checkpoint)
- Diff whitespace check: PASS
- Source state: validated but not committed by this shift; inherited work was preserved

## Bugs

- Fixed urgent mixed-intent, extraction, reporting, Guardian, job, and billing structure in the canonical Support classifier without changing locked expected labels for convenience.
- Restored canonical `ai-safety` and `ai-support` Edge contracts.
- Fixed native auth callback aliases, five-step onboarding persistence, precise-location honesty, and privacy-safe general-area persistence.
- Fixed overlapping job-progress polling, expired PIN countdown churn, accessibility announcement churn, proof URL churn, duplicate account fetches, unbounded job caching, oversized image decode, message burst sorting, and repeated mark-read RPCs.
- Fixed reduced-motion route behavior, bottom-safe-area sheets, exact signer checks, iOS CocoaPods integration, iOS sensitive-route privacy shielding, and platform location-accuracy parity.
- Physical QA found and fixed a legal-route defect: Terms opened from onboarding incorrectly said `Back to settings` and routed to `/settings`; final QA now shows `Back` and returns to the invoking onboarding route.
- Remaining measured gap: 85 of 543 locked Support expected-label fixtures conflict with canonical mixed-domain/duplicate semantics. The deployed SQL and TypeScript implementations still agree on all six compared fields for all 543 cases, and hosted hard failures are zero.

## Support

- Fresh baseline: 392/543.
- Current locked expected-label score: 458/543; high-water improvement: +66.
- Urgent false negatives: 0.
- SQL/TypeScript parity: 543/543 across level, triage, category, intent, action, and provider permission.
- Hosted gauntlet: 294 total, 285 passed, 9 monitored warnings, 0 hard failures, 0 unexecuted rate-limited cases, 0 harness errors.
- Provider status: external AI remains disabled; deterministic Support fallback remains enabled. Privileged state changes remain server-authorized and deterministic.

## Backend

- Supabase project ref: `rakjydmgwwgtdislanbt`.
- Migration ledger: aligned through `20260816010000`; applied migrations were not rewritten.
- RLS and isolation: executed Teen, Adult, Guardian, staff, admin, message, application, notification, Support, storage, and location probes passed.
- Jobs/applications/PIN: lifecycle, concurrency, expiration, replay, idempotency, and no-money completion probes passed.
- Safety/Guardian/moderation/deletion: executed non-destructive probes passed; public marketplace and provider verification remain fail-closed.
- Account-deletion processor: destructive worker QA was not run because `ACCOUNT_DELETION_WORKER_SECRET` was absent.
- Notifications: foundation checks passed, but remote push remains disabled and no uncontrolled notification was sent.

## Location

- Precise/reduced/unknown/unavailable accuracy is represented honestly.
- Compact onboarding stores a general city/state label and discards raw coordinates.
- Server-side privacy probes passed for private coordinates, addresses, and unrelated-user access.
- Manual/reduced-permission UI paths are source-tested. Physical precise/coarse/denied variants were not all executed on the final Samsung journey.

## UI

- Canonical onyx, rose-gold, emerald, and baby-blue design tokens remain shared across repaired screens.
- Shared reduced-motion route behavior and safe-area sheets are regression-tested.
- Onboarding legal controls remain reachable above Samsung system navigation at 1080x2408 and density 450.
- The final Terms route and system-Back behavior were physically verified.
- This shift did not claim a complete visual review of every role-specific screen.

## Performance

- Removed or bounded known N+1, polling, signed-URL, duplicate-fetch, cache-growth, image-decode, full-list-sort, and realtime-RPC hot paths.
- Final signed APK physical cold-start samples: 428, 340, 335, 354, and 329 ms.
- Background resume sample: 103 ms.
- Final journey logcat had zero invalid-matrix, old predictive-Back warning, secure-startup, fatal, Flutter, platform, security, OOM, or ANR-token findings.
- Broad scroll/GPU/memory profiling across every dashboard remains manual device work.

## Flutter

- `flutter analyze --no-pub`: PASS, no issues (116.1 seconds).
- Focused legal/navigation regression: PASS, 19/19.
- Final full Flutter suite: PASS, 372 tests passed, 2 intentional skips, 0 failures.
- Source secret scan: PASS.
- Git-history scan: PASS; 70 commits, 125 candidate blobs, 4 configured sensitive values, 0 findings.

## Android

- Package: `com.mortapp.mobile`.
- Version: `0.9.15+106`.
- minSdk: 24; targetSdk: 36.
- Predictive Back: enabled; old manifest warning absent in final logs.
- Signing: PASS against the repository-pinned MORT upload certificate.
- 16 KB alignment: PASS for 18 native libraries in the APK.
- Device: physical Samsung SM-A146U over wireless ADB, Android 15/API 35.
- Physical journey passed: install, secure startup, session restoration to guarded onboarding, scrolling, Terms navigation, system Back, five cold starts, and background resume.
- Not claimed: final exact-APK Google OAuth, role dashboards, jobs, messages, or all location permission variants.

## iOS

- IOS_SHARED_SOURCE_PARITY: PASS at source-contract level for auth callbacks, reduced motion, location accuracy, sensitive-route shielding, and shared design behavior.
- IOS_CONFIG_STATUS: iOS 15 deployment target and canonical CocoaPods Flutter integration restored.
- XCODE_VERIFICATION: EXTERNAL_GATE.
- PHYSICAL_IPHONE: EXTERNAL_GATE.
- TESTFLIGHT: EXTERNAL_GATE.
- APP_STORE_REVIEW: EXTERNAL_GATE.

## Security

- Source, history, and exact APK/AAB secret scans passed without exposing configured values.
- No service-role credential is present in Flutter configuration.
- RLS/cross-user isolation and server-side location privacy probes passed.
- Public marketplace, production identity verification, payments, ads/IAP, external AI, remote push, and crash reporting remain fail-closed in the built profile.
- Legal documents are versioned `draft-2026-07` and require qualified legal/privacy/teen-safety review.

## Artifacts

- APK: `C:\Users\micha\Mort\build\play\mort-closed-test-0.9.15-106.apk`
- APK size: 69,483,818 bytes.
- APK SHA-256: `38ECD85E35D5082E20CDAFAD75AD2935DD566094FE9441BF0601D6DDEBE94BBF`.
- AAB: `C:\Users\micha\Mort\build\play\mort-closed-test-0.9.15-106.aab`
- AAB size: 52,220,325 bytes.
- AAB SHA-256: `6272A79BC858D6C6FCE9A7EC33E00788331E36BB4A942FC4E6DC8FCAFC4E3283`.
- Symbols: `C:\Users\micha\MortSymbols\android\0.9.15+106`.
- Physical evidence: `C:\Users\micha\Mort\artifacts\divine-full-day-0.9.15+106`.
- Build manifests truthfully record `gitDirty: true`.

## External Gates

- Verify that Play Console versionCode 106 is unused before upload.
- Commit/review the validated source so artifacts are reproducible from an approved clean revision.
- Complete qualified legal, privacy, child/teen-safety, UGC, App Store, and Play policy review.
- Complete the final signed-APK physical matrix for OAuth, each role, jobs, messaging, Safety, Support, and location permission variants using controlled QA accounts.
- Configure and approve production identity verification, marketplace activation, remote push/crash reporting, and any eventual money movement before enabling them.
- Confirm moderation, Support, incident response, and escalation staffing before real users.
- Complete macOS/Xcode signing, physical iPhone QA, TestFlight, and App Store review later.

## Verdict

- SAFE_TO_UPLOAD = NO
- ENGINEERING_STATUS = PASS WITH EXTERNAL GATES
- ANDROID_STATUS = VERIFIED FOR THE EXECUTED CLOSED-TEST BUILD AND PHYSICAL JOURNEY
- IOS_STATUS = SOURCE CAUGHT UP; XCODE/TESTFLIGHT EXTERNAL
- PUBLIC_PRODUCTION_STATUS = CLOSED

The signed artifacts are valid engineering outputs, but the dirty source state, unverified Play versionCode, draft legal documents, incomplete final-device role matrix, and intentionally disabled production providers prevent an upload or public-production claim.
