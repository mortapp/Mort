# MORT Divine Full-Day Progress

- START_TIMESTAMP: 2026-08-15 (America/Indianapolis; resumed existing shift)
- BRANCH: feature/compact-onboarding-and-screen-polish
- START_HEAD: 370437b4218724eb5d9eec38ec98c7d337feddb5
- CURRENT_HEAD: 370437b4218724eb5d9eec38ec98c7d337feddb5
- DIRTY_FILES: 117 tracked/untracked paths at final checkpoint; inherited Support, onboarding, Edge Function, QA, migration, and this shift's verified fixes remain uncommitted
- CURRENT_VERSION: 0.9.15+106
- CURRENT_PHASE: Phase 32 - release report and external-gate handoff
- CURRENT_SUPPORT_SCORE: 458/543 passed; 85 failed; high-water +66 from fresh baseline
- BACKEND_STATUS: canonical ai-safety and ai-support contracts restored; focused contract suite passes 10/10
- SUPABASE_STATUS: linked ref `rakjydmgwwgtdislanbt`; remote ledger aligned through `20260816010000`; deployed classifier passes 543/543 parity across level, triage, category, intent, action, and provider permission
- LOCATION_STATUS: compact onboarding stores only a general city/state label and discards raw coordinates; permission diagnostics distinguish precise, reduced, unknown, and unavailable accuracy without presenting reduced accuracy as exact; hosted privacy/RLS probes pass
- FLUTTER_STATUS: auth callbacks, five-step onboarding, privacy-safe location, polling, lazy timelines, signed-proof caching, shared data providers, bounded image decode, bounded job cache, message burst handling, push registration, reduced motion, safe sheets, and legal-route Back behavior repaired; final analyzer passed with no issues and full suite passed 372 tests with 2 intentional skips
- ANDROID_STATUS: package `com.mortapp.mobile`, minSdk 24, targetSdk 36; predictive Back enabled; exact signer pin and 16 KB native-library alignment passed; configured signed APK/AAB built for closed testing at `0.9.15+106`
- IOS_SOURCE_STATUS: iOS 15 target, CocoaPods integration, auth callbacks, shared reduced-motion navigation, location-accuracy honesty, and sensitive-route app-switcher/capture shielding implemented; Xcode compilation remains an external macOS gate
- DEVICE_QA_STATUS: exact final signed APK installed over wireless ADB on physical Samsung SM-A146U (Android 15/API 35); onboarding/legal route, system Back, five cold starts, and background resume passed with zero invalid-matrix, predictive-Back warning, secure-startup, fatal, Flutter, platform, security, OOM, or ANR-token log findings; full role journeys were not altered or claimed
- PERFORMANCE_STATUS: event-query N+1, polling overlap, PIN countdown accessibility churn, signed-proof URL churn, repeated account-data fetches, unbounded job-page memory cache, oversized image decode, message full-sort work, and realtime mark-read bursts repaired; physical final-APK startup samples were 428/340/335/354/329 ms and background resume was 103 ms
- RELEASE_STATUS: signed closed-test APK/AAB exist and are verified, but SAFE_TO_UPLOAD remains NO because the source tree is dirty, Play versionCode 106 availability is unverified, legal documents remain drafts, full final-APK role/OAuth journeys were not completed, and production provider/public-activation gates remain closed
- EXTERNAL_GATES: Play versionCode availability, legal/privacy/teen-safety approval, production identity verification, public-marketplace authorization, notification/crash provider configuration, moderation/support staffing, real-money approval, Apple signing/Xcode/physical iPhone/TestFlight/App Store review

## Milestones

### Phase 0 - Repository Recovery

- FILES_CHANGED: none by this shift
- BUGS_FIXED: none yet
- TESTS_RUN: git status, branch, HEAD, log, diff stat, diff check
- PASSED: repository state recovered; diff check found no whitespace errors
- FAILED: clean-state gate (inherited worktree is dirty)
- KNOWN_BLOCKERS: none; inherited changes require validation before merge
- NEXT_AUTOMATIC_PHASE: Support classifier baseline

### Phase 2 - Support Classifier Baseline

- FILES_CHANGED: none by this phase
- BUGS_FIXED: identified Node-vs-Deno harness invocation mismatch
- TESTS_RUN: Deno local 543-case classifier regression
- PASSED: 392
- FAILED: 151
- KNOWN_BLOCKERS: local TypeScript classifier is below the historical 402-pass high-water mark; inherited work is not releasable
- NEXT_AUTOMATIC_PHASE: structural Support classifier repair with benign/security contrasts

### Phase 3 - Support Structural Repair

- FILES_CHANGED: `supabase/functions/_shared/support_runtime.ts`
- BUGS_FIXED: urgent mixed-intent detection gaps; prompt/secret extraction structure; quoted/reporting routing; routine domain precedence; bare `review` profile-router collision; job-PIN help coverage
- TESTS_RUN: full 543-case classifier after each structural patch; Deno type check; urgent-signal scan; prompt-extraction scan; secret-extraction scan
- PASSED: 458/543 current high-water; urgent false negatives 0; prompt scan exit 0; Deno check exit 0
- FAILED: 85 classifier cases remain
- KNOWN_BLOCKERS: locked fixture helper assigns one intent to several mixed-domain groups; quoted fixtures use a non-canonical level-1 intent; conflicting duplicate semantics make literal 543/543 impossible without fixing the evaluation contract or overfitting production
- NEXT_AUTOMATIC_PHASE: verify Edge Function request/response contracts and remote migration ledger before any deployment

### Phase 3B - Edge Contract Recovery

- FILES_CHANGED: inherited three-line aliases in `supabase/functions/ai-safety/index.ts` and `supabase/functions/ai-support/index.ts` were restored to their canonical tracked implementations; resulting files match HEAD
- BUGS_FIXED: ai-safety moderation and MORT Guide endpoint contracts no longer point at the unrelated Support assistant handler
- TESTS_RUN: `flutter test --no-pub test/mort_guide_contract_test.dart test/mort_0_9_3_security_contract_test.dart`
- PASSED: 10/10 tests; exit 0
- FAILED: local Deno dependency resolution could not find `npm:openai@6.48.0` without dependency materialization
- KNOWN_BLOCKERS: none in the focused Flutter contract layer
- NEXT_AUTOMATIC_PHASE: shared auth/platform repairs

### Phase 13 - Auth and Onboarding Repair

- FILES_CHANGED: `flutter_mort/lib/core/routing/app_router.dart`, `flutter_mort/lib/core/widgets/mort_widgets.dart`, `flutter_mort/lib/features/onboarding/compact_onboarding.dart`, focused tests
- BUGS_FIXED: native `/auth-confirm` and `/auth-recovery` callbacks now resolve; Back fallback recognizes both native and web callback aliases; onboarding once again preserves the canonical five-step contract; onboarding persists only city/state general area instead of rounded coordinates
- TESTS_RUN: auth/Back tests; compact onboarding and persistence tests
- PASSED: auth/Back 30/30; onboarding 7/7
- FAILED: none
- KNOWN_BLOCKERS: physical OAuth callback still requires device QA
- NEXT_AUTOMATIC_PHASE: shared job lifecycle and platform compatibility

### Phase 10 / 20 - Job Progress Reliability

- FILES_CHANGED: `flutter_mort/lib/features/jobs/job_progress_screen.dart`, `flutter_mort/test/job_progress_widget_test.dart`
- BUGS_FIXED: overlapping periodic status requests replaced with completion-scheduled polling; background polling paused; pending-release polling backed off; expired PIN ticker stops; TalkBack no longer announces countdown every second; PIN text scales down safely
- TESTS_RUN: focused job-progress widget suite
- PASSED: 4/4
- FAILED: none
- KNOWN_BLOCKERS: full lifecycle and physical performance QA pending
- NEXT_AUTOMATIC_PHASE: migration parity and broader Flutter QA

### Phase 25 - iOS Shared-Source Catch-Up

- FILES_CHANGED: `flutter_mort/ios/Runner.xcodeproj/project.pbxproj`, `docs/ios/MORT_MAC_BUILD_AND_TEST_TASK.md`, `flutter_mort/test/ios_platform_contract_test.dart`
- BUGS_FIXED: iOS deployment target now matches Firebase Core/Messaging minimum iOS 15 requirement
- TESTS_RUN: iOS platform source contract
- PASSED: 1/1
- FAILED: none at source-contract layer
- KNOWN_BLOCKERS: Xcode build, Apple signing, physical iPhone, and TestFlight are external platform gates
- NEXT_AUTOMATIC_PHASE: Android-first source regression

### Phase 5 / 6 - SQL/TypeScript Parity and Migration Ledger

- FILES_CHANGED: `scripts/qa-support-sql-ts-parity.mjs`, `scripts/qa-support-case-diagnose.mjs`, `supabase/migrations/20260813110000_support_ai_direct_extraction_coverage_fix.sql`
- BUGS_FIXED: removed BOM and SQL quote parse defect in the unapplied migration; rebuilt the wrapper around structural urgent, quoted/reporting, prompt/secret/cross-user, routine-domain, and benign-context signals; preserved privilege revocation and service-role-only execution
- TESTS_RUN: linked migration list; linked dry-run; repeated rollback-only remote migration apply and all 543 SQL/TypeScript comparisons; full local classifier; urgent, prompt, and secret scans
- PASSED: SQL/TypeScript parity 543/543; SQL/runtime expected-label score 458/543; local runtime 458/543; urgent false negatives 0; prompt scan exit 0; migration dry-run identifies only `20260813110000`
- FAILED: 85 expected-label cases remain in both mirrors
- KNOWN_BLOCKERS: fixture helpers contain mixed-domain labels and contradictory duplicate semantics; applied migration `20260812010000` is locally truncated and must remain immutable, so clean replay/backfill needs a forward repair or restored historical artifact
- NEXT_AUTOMATIC_PHASE: final migration dry-run, controlled push, affected Edge deployment, and hosted probes if all gates remain green

### Phase 7 / 8 - Support Deployment and Hosted Gauntlet

- FILES_CHANGED: `scripts/support-ai-gauntlet.mjs`, `supabase/migrations/20260816010000_support_ai_full_contract_parity_fix.sql`
- BUGS_FIXED: raw adversarial fixtures no longer appear in gauntlet logs/reports; gauntlet supports bounded shards and honest warning accounting; sensitive disclosure has an intent-correct exact-level/provider-denied contract; neutral obfuscated mentions are separated from attacks; remote sensitive disclosure now denies provider access; reported security concerns retain their distinct category
- TESTS_RUN: full six-field rollback parity; two linked migration dry-runs and pushes; remote six-field parity; deployment of 13 JWT-protected Support functions; 62 hosted gauntlet categories in 13 bounded shards
- PASSED: deployed SQL/TypeScript parity 543/543; hosted total 294, pass 285, monitored warnings 9, hard failures 0, rate-limited/unexecuted 0, harness errors 0; all ephemeral QA users cleaned up
- FAILED: none in hard security categories
- KNOWN_BLOCKERS: monitored warnings include two multilingual jailbreaks, two semantic paraphrases, and five benign-routing observations; these remain measured gaps and are not silently counted as passes
- NEXT_AUTOMATIC_PHASE: full backend/RLS regression

### Phase 9 / 10 / 11 / 12 - Hosted Backend, PIN, and Location Privacy

- FILES_CHANGED: none during hosted probes
- BUGS_FIXED: no additional remote defects found after the Support provider-permission repair
- TESTS_RUN: complete 30-check multi-user isolation; job lifecycle; PIN concurrency/replay; location denial source contract; address privacy; messaging safety state machine; account-deletion request/cancel isolation; remote push foundation; send-push unauthorized contract; marketplace lock; verification production fail-closed; database, Edge, and Safety-action rate limits; marketplace state machine; optional Guardian Mode; moderation/legal; Google auth controls; resumable onboarding
- PASSED: all executed checks; private profile/storage/message/application/notification/support boundaries; exact-address release controls; PIN atomicity and no-money completion; public marketplace remains closed; provider verification remains fail-closed; synthetic push runtime remains disabled; no uncontrolled notification was sent
- FAILED: none
- KNOWN_BLOCKERS: `ACCOUNT_DELETION_WORKER_SECRET` is not present, so destructive processor QA was not run; real provider verification, real notifications, and physical location permission behavior remain external/device gates
- NEXT_AUTOMATIC_PHASE: Flutter analyzer, focused regressions, full Flutter suite, then Android build/device discovery

### Phase 20 / 21 - Flutter Performance and Static Regression

- FILES_CHANGED: `flutter_mort/lib/features/jobs/application_screens.dart`, `flutter_mort/lib/features/jobs/proof_review_screen.dart`, `flutter_mort/test/application_detail_screen_test.dart`, `flutter_mort/test/proof_review_screen_performance_test.dart`
- BUGS_FIXED: collapsed application cards no longer trigger one status-event query per card; each timeline loads once on first expansion and retries explicitly; proof signed URLs are cached by private storage path across unrelated rebuilds and refresh only on explicit screen/image retry; immediate retry failures attach to `FutureBuilder` without an unhandled async error
- TESTS_RUN: combined focused application/proof widget suite; Flutter analyzer; prior full Flutter suite at the immediately preceding source checkpoint
- PASSED: focused 5/5; `flutter analyze --no-pub` exit 0 with no issues; preceding full suite 355 passed and 2 intentionally skipped
- FAILED: initial signed-image retry regression test exposed an unhandled immediately failing Future; implementation repaired and the same test then passed
- KNOWN_BLOCKERS: full suite must be rerun after the remaining final source edits; physical image-memory and scroll profiling require an attached Android device
- NEXT_AUTOMATIC_PHASE: repair remaining high-value Future/rebuild and image decode hot paths, then final Flutter regression

### Phase 20 - Data, Image, Cache, and Realtime Performance

- FILES_CHANGED: `flutter_mort/lib/data/repositories/providers.dart`, `flutter_mort/lib/data/repositories/jobs_repository.dart`, `flutter_mort/lib/core/utils/image_decode_size.dart`, account/profile/job/proof/Support screens, `flutter_mort/lib/features/mort_screens.dart`, focused tests
- BUGS_FIXED: account screens now share auto-disposed provider requests instead of starting duplicate repository Futures during rebuilds; offline job pages use a 24-entry/15-minute LRU instead of unbounded process memory; avatars and private evidence decode at bounded physical dimensions; realtime single-message insertion no longer remaps and sorts the full timeline; mark-read RPCs are debounced and single-flight during event bursts
- TESTS_RUN: account provider cache; image decode bounds and non-finite inputs; job-page LRU/TTL; messaging completion and 100-event burst
- PASSED: all focused suites (6 provider/proof/application checks, 3 decode checks, 2 cache checks, and 5 messaging checks)
- FAILED: none after repair
- KNOWN_BLOCKERS: GPU/image-memory and realtime profiling on representative low-end hardware require an attached device
- NEXT_AUTOMATIC_PHASE: platform permission, motion, signing, and source parity

### Phase 22 / 26 - Android Push, Signing, and Artifact Discipline

- FILES_CHANGED: `flutter_mort/lib/services/native_permissions_service.dart`, `flutter_mort/lib/features/settings/native_permissions_screen.dart`, Android release/signing/QA scripts, Node AAB checks, focused contracts
- BUGS_FIXED: a push-disabled build no longer requests an unusable OS notification permission; enabled builds register through the canonical coordinator; `-RequireSigned` now verifies the exact pinned MORT upload certificate; generated APK/AAB names include versionCode to prevent same-versionName collisions
- TESTS_RUN: remote-push source contract; PowerShell parse checks; Node syntax checks; production-readiness contract
- PASSED: push suite 4/4; all changed scripts parse; readiness suite 7/7
- FAILED: one initial Flutter runner invocation stalled before loading a test and was terminated; the exact rerun passed and did not expose a product failure
- KNOWN_BLOCKERS: no signed artifact yet matches the final dirty `0.9.15+106` source; Play versionCode availability and physical signed smoke must be proven before upload
- NEXT_AUTOMATIC_PHASE: shared motion and iOS source catch-up

### Phase 18 / 19 - Motion, Reduced Motion, and Sheet Layout

- FILES_CHANGED: `flutter_mort/lib/core/routing/mort_page_transitions.dart`, `flutter_mort/lib/core/widgets/mort_widgets.dart`, `flutter_mort/test/shared_motion_and_sheet_test.dart`
- BUGS_FIXED: Android and Cupertino route builders now remove movement when device/app reduced motion is active; confirmation sheets honor bottom safe areas instead of allowing actions under system UI
- TESTS_RUN: shared motion/sheet regression plus physical-rendering contracts
- PASSED: 5/5
- FAILED: none
- KNOWN_BLOCKERS: animation frame pacing still needs representative physical-device profiling
- NEXT_AUTOMATIC_PHASE: iOS source/config parity

### Phase 25 - iOS CocoaPods, Privacy Shield, and Location Accuracy Parity

- FILES_CHANGED: `flutter_mort/ios/Podfile`, iOS Flutter xcconfigs, `flutter_mort/ios/Runner/AppDelegate.swift`, screen-security and native-permission Dart services/screens, iOS/location/security contracts, macOS handoff doc
- BUGS_FIXED: native plugin pods are restored to the canonical Flutter integration; sensitive routes receive an opaque app-switcher and active-capture privacy shield on iOS; shared screen-security calls now reach both Android and iOS; iOS reduced location accuracy is reported honestly instead of being implicitly treated as precise; permission status reads start concurrently
- TESTS_RUN: iOS platform, screen-security service/widget, Android parity, location accuracy, compact onboarding, push contracts
- PASSED: screen-security/native platform suite 22/22; location/onboarding/platform suite 11/11
- FAILED: first location compile exposed a missing import; second compile exposed the SDK's `unknown` accuracy case; both were repaired and the exact suite passed
- KNOWN_BLOCKERS: Windows cannot run CocoaPods, Xcode, Apple signing, physical iPhone capture/app-switcher QA, or TestFlight; iOS cannot prevent hardware screenshots and the implementation makes no such claim; APNs entitlement remains disabled while remote push is not approved/configured
- NEXT_AUTOMATIC_PHASE: final analyzer, full tests, Android build, security scan, and device discovery

### Phase 28 - Final Flutter and Source Regression

- FILES_CHANGED: `flutter_mort/lib/features/mort_screens.dart`, `flutter_mort/test/legal_document_navigation_test.dart`, plus the previously listed repaired source and tests
- BUGS_FIXED: legal documents opened from onboarding no longer present a misleading `Back to settings` action or route to `/settings`; the route now pops to its actual invoker and falls back to `/legal-center` only for a direct deep link
- TESTS_RUN: focused legal/navigation suite; `flutter analyze --no-pub`; final full Flutter suite; source secret scan; Git-history secret scan; `git diff --check`
- PASSED: focused navigation 19/19; analyzer no issues; full suite 372 passed with 2 intentional skips and 0 failures; source/history scans found no secrets; diff check passed
- FAILED: none in executed final source gates
- KNOWN_BLOCKERS: Support expected-label regression remains 458/543 because 85 locked mixed-domain/duplicate fixture contracts conflict with canonical runtime behavior; hosted hard failures remain zero
- NEXT_AUTOMATIC_PHASE: configured signed Android artifacts and physical wireless smoke

### Phase 22 / 23 - Signed Android Build and Wireless Physical QA

- FILES_CHANGED: no source changes after the final build; physical evidence written under `artifacts/divine-full-day-0.9.15+106`
- BUGS_FIXED: physical QA exposed the legal-document route-label defect above; the final rebuilt APK was reinstalled and the exact journey was repeated successfully
- TESTS_RUN: signer/package/version/SDK inspection; 16 KB APK alignment; exact-artifact secret scan; wireless ADB install on Samsung SM-A146U; onboarding scroll; Terms route and system Back; five force-stop cold starts; background/resume; focused logcat triage
- PASSED: physical wireless device was the sole ADB target; package/version/signing/startup passed; onboarding actions remained above system navigation; Terms displayed `Back` and returned to onboarding; cold starts were 428/340/335/354/329 ms; resume was 103 ms; relevant log findings were zero
- FAILED: none in the executed physical journey
- KNOWN_BLOCKERS: auth, Google OAuth callback, Teen/Adult/Guardian dashboards, jobs, messaging, and physical location permission variants were not traversed on the final exact APK because doing so would mutate the currently guarded onboarding account state
- NEXT_AUTOMATIC_PHASE: report verified artifacts and external gates

### Phase 30 / 32 - Artifacts and Verdict

- FILES_CHANGED: build manifests, signed APK/AAB, symbol output, this progress ledger, and `docs/MORT_DIVINE_FULL_DAY_ENGINEERING_REPORT.md`
- BUGS_FIXED: artifact names include versionCode and signer validation uses the exact pinned MORT upload certificate
- TESTS_RUN: package/version/minSdk/targetSdk/signing checks; AAB/APK SHA-256; APK 16 KB alignment; final artifact secret scan
- PASSED: APK 69,483,818 bytes, SHA-256 `38ECD85E35D5082E20CDAFAD75AD2935DD566094FE9441BF0601D6DDEBE94BBF`; AAB 52,220,325 bytes, SHA-256 `6272A79BC858D6C6FCE9A7EC33E00788331E36BB4A942FC4E6DC8FCAFC4E3283`; exact pinned signer passed; 18 native libraries passed 16 KB alignment; artifact scan found no configured secrets
- FAILED: clean-tree release gate and external approval gates are not satisfied
- KNOWN_BLOCKERS: dirty source manifests, unverified Play versionCode 106 availability, draft legal documents, incomplete final-APK role matrix, disabled production providers, and all Apple platform gates
- NEXT_AUTOMATIC_PHASE: owner review and completion of external/manual gates; no automatic public publication
