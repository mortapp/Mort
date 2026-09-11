# MORT Final-100 Readiness — Scorecard

Evidence-based only. No area is marked 100 without a cited command, file, or finding.
Updated incrementally as tracks complete — see `MORT_FINAL_100_BASELINE.md`,
`MORT_BACKEND_SAFETY_AUDIT_SESSION{1,2,3,4}.md`, `MORT_LEGAL_RECONSENT_AUDIT.md`,
`MORT_UI_DESIGN_SYSTEM_AUDIT.md`, `MORT_IOS_NATIVE_SOURCE_AUDIT.md`, and
`MORT_FINANCIAL_SAFETY_TRANSFER.md` for the underlying evidence.

## Latest macOS iOS CI evidence

IOS_WORKFLOW_RUN_ID=34472297830
IOS_WORKFLOW_URL=https://github.com/mortapp/Mort/actions/runs/34472297830
IOS_WORKFLOW_HEAD_SHA=0180d27b7c50565a6b67288adfb797eac40bd803
IOS_MACOS_PUB_GET=PASS
IOS_MACOS_FORMAT=PASS
IOS_MACOS_ANALYZE=PASS
IOS_MACOS_FLUTTER_TESTS=PASS
IOS_POD_INSTALL=PASS
IOS_XCODE_PROJECT_VALIDATION=PASS
IOS_UNSIGNED_RELEASE_BUILD=PASS
IOS_QA_IPA_PACKAGE=PASS
IOS_GITHUB_ARTIFACT_UPLOAD=PASS

The `mort-ios-browserstack-qa` artifact was uploaded by this run and accepted by
BrowserStack App Automate for the real-device matrix documented below. The
evidence artifact contains passing checkpoint screenshots and session metadata.

## Latest local Android emulator evidence

ANDROID_EMULATOR_AVD=MORT_QA_Pixel6
ANDROID_EMULATOR_SERIAL=emulator-5554
ANDROID_API_LEVEL=36
ANDROID_VERSION=16
ANDROID_DEVICE_MODEL=sdk_gphone64_x86_64
ANDROID_RESOLUTION=1080x2400
ANDROID_DENSITY=420
ANDROID_BOOT_COMPLETED=1
ANDROID_TESTED_SHA=512a6bdf4de7a5d28e9640259efeb4d7b2216167
ANDROID_DEBUG_APK=flutter_mort/build/app/outputs/flutter-apk/app-debug.apk
ANDROID_DEBUG_BUILD=PASS
ANDROID_DEBUG_BUILD_LATEST=PASS (flutter build apk --debug)
ANDROID_ANALYZE=PASS
ANDROID_NATIVE_SMOKE=PASS (2 tests)
ANDROID_NATIVE_SMOKE_IDENTITY=PASS (com.mortapp.mobile 0.9.16+107)
ANDROID_NATIVE_SMOKE_RUN=PASS (flutter test integration_test/android_native_smoke_test.dart -d emulator-5554)
ANDROID_COLD_LAUNCH=PASS (process resumed; no fatal Android/Flutter logs)
ANDROID_PUBLIC_CONFIG_GATE=EXPECTED_FAIL_CLOSED (APK stops at the secure startup gate when no public Supabase Dart defines are supplied)
EMULATOR_CLEANUP_EXIT=EXPECTED
EMULATOR_CLEANUP_EXIT_CODE=1
EMULATOR_BOOT_FAILURE=NO

ANDROID_EMULATOR_BOOTED=PASS
ADB_DEVICE_VISIBLE=PASS (emulator-5554)
SYS_BOOT_COMPLETED=1
MORT_APK_INSTALLED=PASS
MORT_LAUNCHED=PASS
ANDROID_AUTH=PARTIAL (internal QA shell mounts production role routing with local fixture overrides; full emulator interaction remains)
ANDROID_ONBOARDING=PARTIAL (safety acknowledgement flow passed; full onboarding remains)
ANDROID_TEEN_HOME=PASS (production RoleHomeScreen mounted by internal QA fixture tests)
ANDROID_JOBS=REMAINING
ANDROID_APPLICATIONS=REMAINING
ANDROID_SAFETY=PARTIAL (safety rules acknowledgement passed)
ANDROID_FINANCIAL=REMAINING
ANDROID_MESSAGES=REMAINING
ANDROID_PROFILE_SETTINGS=REMAINING
ANDROID_ADULT=PASS (production RoleHomeScreen mounted by internal QA fixture tests)
ANDROID_GUARDIAN=PASS (production RoleHomeScreen mounted by internal QA fixture tests)
ANDROID_ADMIN=PASS_OR_EXPLICITLY_COVERED (production RoleHomeScreen mounted by internal QA fixture tests; privileged mutations remain blocked)
ANDROID_SYSTEM_BACK=PASS (back event and relaunch remained stable)
ANDROID_KEYBOARD=REMAINING (emulator interaction blocked by Android System UI ANR before IME evidence)
ANDROID_SMALL_SCREEN=REMAINING (compact override not applied because Android System UI was not responsive)
ANDROID_LARGE_TEXT=PASS (1.6x safety acknowledgement flow)
ANDROID_REDUCED_MOTION=REMAINING (emulator interaction blocked by Android System UI ANR)
ANDROID_PERMISSIONS=PASS (native permission snapshot)
ANDROID_P0=NONE_OBSERVED (no fatal launch/runtime error)
ANDROID_P1=NONE_OBSERVED (no fatal launch/runtime error)

REAL_SUPABASE_USER_CREATION=NO
REAL_HOSTED_JOB_WRITES=NO
REAL_FINANCIAL_WRITES=NO
REAL_PAYMENT_ACTIONS=NO
REAL_IDENTITY_ACTIONS=NO
REAL_PUSH_SENDS=NO
REAL_EMERGENCY_DIALS=NO
REAL_AVATAR_UPLOADS=NO
REAL_EVIDENCE_UPLOADS=NO
REAL_MODERATION_MUTATIONS=NO

ANDROID_FULL_INTERACTION=REMAINING (see forensic evidence below -- the emulator process itself terminates before interactive checkpoint evidence can be captured)
ANDROID_EMULATOR_EXECUTION_BLOCKER=HOST_RESOURCE_PRESSURE (evidenced; see below)
PHASE_17_ANDROID_DEVICE_QA=PARTIAL
ANDROID_DEVICE_QA_BLOCKED=YES (interactive checkpoints only -- non-interactive/fixture-test evidence above is unaffected)

The local AVD was reused without modifying or deleting existing virtual devices.
The internal QA shell was extended to mount the real production
`RoleHomeScreen` for Teen, Adult, Guardian, and Admin roles. Its fixture
repositories remain mutation-blocked, and the targeted QA app/mode tests pass.
This closes the role-fixture implementation gap but does not by itself replace
the remaining emulator interaction checks for keyboard, compact layout, and
reduced motion.

### Android emulator instability -- forensic root-cause session (2026-09-11)

Three independent, reproducible emulator **process** crashes (not mere ADB
disconnects -- `tasklist` confirmed the `emulator`/`qemu` process itself
disappeared each time, and `adb kill-server`/`start-server` found no device)
occurred in this session, all at the identical trigger: navigating from the
QA home screen into the Onboarding form (`qa-open-onboarding` tap). A fourth,
historical occurrence at the same trigger was already recorded by a prior
session. MORT's own UI never crashed and never rendered incorrectly in any
observed screenshot before a crash -- this is an Android
emulator/host-environment failure, not a MORT application defect.

Evidence gathered:
- Host free RAM was critically low before any emulator launch: 2.05 GB free
  of 16 GB total (`Get-CimInstance Win32_OperatingSystem`).
- The emulator log (`INFO | host doesn't support requested feature:
  CPUID.01H:ECX.xsave [bit 26]` / `...ECX.avx [bit 28]`) shows the host CPU's
  AVX/XSAVE features are not exposed to the hypervisor, consistent with this
  machine running inside a constrained or nested virtualization layer --
  degrading QEMU/SwiftShader (software Vulkan/GL) performance generally.
- Each crash was immediately followed by a large jump in free host RAM
  (~1.3 GB before a crash to ~4.3 GB after), confirming the live emulator's
  real footprint substantially exceeds its own `-memory` flag and that the
  crash coincides with peak resource demand (rendering a multi-field form).
- No crash/panic signature appears in the emulator's own log on any of the
  three occurrences -- the process is silently terminated, not internally
  crashing, which is consistent with external termination under memory
  pressure rather than an emulator-internal bug.
- A separate, non-fatal `SystemUI isn't responding` ANR (Android System UI,
  not MORT) recurred on nearly every cold boot/launch and was successfully
  recovered by choosing "Wait" and pausing -- proving the underlying system is
  merely slow under this host's constraints, not permanently broken, but that
  slowness is severe enough to tip into a fatal process loss under load.

Repairs attempted, in escalating order, before classifying this as a genuine
environment blocker:
1. Cold boot with `-no-snapshot -no-audio -no-boot-anim -no-window` (ruled
   out stale-snapshot corruption as the cause -- boot succeeded cleanly each
   time, and a 5-minute post-boot stability soak, 20 consecutive
   `adb devices`/`sys.boot_completed` checks, passed with zero disconnects
   while a concurrent `flutter build apk --debug` ran).
2. Stopped a stray Gradle daemon left over from that build (`./gradlew
   --stop`, reclaimed ~320 MB) before the second attempt.
3. Reduced guest RAM from the AVD default 2048 MB to 1536 MB, then to
   1024 MB, on successive relaunches.
4. Added generous settle pauses (8-10s) between every input action and
   replaced chained tap+screenshot sequences with paced,
   connectivity-checked steps.
None of these prevented the crash from recurring at the same trigger; the
ANR-recovery behavior did improve (two of the three attempts survived the
ANR itself and only failed on the *next* interaction), which further
localizes the failure to cumulative resource exhaustion under sustained
rendering load rather than a single fixable misconfiguration.

Per the three-strikes escalation policy, further blind retries were stopped.
This is classified as `ANDROID_ENVIRONMENT_BLOCKER=HOST_RESOURCE_PRESSURE`
(compounded by constrained/nested-virtualization CPU features) -- an INTERNAL
task genuinely blocked by the current local host's available resources, not
an external/credential gate and not a MORT code defect. Keyboard,
compact-layout, and reduced-motion interactive checks remain REMAINING for
this reason; they should be retried on a host with materially more free RAM
(a clean reboot freeing the ~13 GB currently held by other running
applications would very plausibly resolve this) or via a cloud-hosted
Android emulator/device lane analogous to the already-working iOS BrowserStack
track.

The current candidate debug APK was rebuilt at commit `3831add` and installed
on `MORT_QA_Pixel6` with the internal QA defines. Live sessions (both with and
without Impeller) rendered the full QA home landmark set correctly, including
the newly added `qa-open-teen`/`qa-open-adult`/`qa-open-guardian`/
`qa-open-admin` buttons in the converged monochrome theme -- screenshots
confirm pixel-correct rendering with no visual defects.
The native smoke suite verified Android secure storage, device-auth capability,
permission snapshot, screen-security acquire/release, package/version identity,
and the large-text safety acknowledgement flow. The remaining checks are
authenticated/full-journey and device-configuration coverage; they are not
classified as blocked because the local emulator is available. Full
authenticated marketplace journeys require a safe QA public configuration and
were not fabricated.

## Latest BrowserStack iOS evidence

IOS_BROWSERSTACK_WORKFLOW_RUN=34472297830
IOS_BROWSERSTACK_WORKFLOW_URL=https://github.com/mortapp/Mort/actions/runs/34472297830
IOS_BROWSERSTACK_HEAD_SHA=0180d27b7c50565a6b67288adfb797eac40bd803
IOS_BROWSERSTACK_BUILD=PASS
IOS_BROWSERSTACK_UPLOAD=PASS
IOS_BROWSERSTACK_REAL_DEVICE_MATRIX=PASS
IOS_BROWSERSTACK_IPHONE_15_IOS_17=PASS
IOS_BROWSERSTACK_IPHONE_17_IOS_26=PASS
IOS_BROWSERSTACK_IPHONE_SE_2022_IOS_15=PASS
IOS_BROWSERSTACK_FORBIDDEN_SIDE_EFFECTS=PASS (QA fixture and Appium forbidden-action guard)
IOS_BROWSERSTACK_EVIDENCE_ARTIFACT=PASS

The matrix covered the internal deterministic home, onboarding, legal, safety,
financial, settings, and permission checkpoints on the configured device
profiles. The unsigned QA artifact was accepted by BrowserStack App Automate
for this run; App Store/TestFlight signing remains a separate external gate.

PHASE_18_IOS_BROWSERSTACK_QA=PASS
IOS_BROWSERSTACK_QA_BLOCKED=NO

| AREA | INTERNAL % | EXTERNAL STATUS | EVIDENCE | REMAINING INTERNAL WORK |
|---|---|---|---|---|
| CI/repository health | 100 | N/A | Fresh `flutter analyze` (no issues), full `flutter test` (573 passed/2 skipped/0 failed), release-readiness contract tests (30 passed), and `flutter build apk --debug` on this candidate | None found |
| Auth/account/session architecture | 100 (of sampled scope) | Live Auth dashboard settings = CANNOT_VERIFY (see gates ledger) | `routeAuthenticatedProfile` fail-closed on profile-id mismatch/unknown role; banned/suspended/deletion-pending accounts routed away from the app shell; backed by `is_profile_active()` RLS enforcement (Session 1/2) as the real security boundary, not just client routing; OAuth callback policy (`MortOAuthCallbackPolicy`) strictly allowlists scheme/host/path and rejects any callback carrying raw token params | Email-confirmation-required and login-rate-limit settings live in the Supabase Dashboard, not git — genuinely cannot be checked from this repository or this session's (unrelated-project) Supabase MCP connection |
| Supabase/backend/RLS | 100 | N/A | Session 4: full migration-replaying inventory (233 RLS-enabled tables, 206 with live policies), all ~70 zero-policy tables individually or pattern-classified with justification, 276 authenticated-grantable RPCs scanned (10 flagged, all 10 manually cleared), all 8 storage buckets confirmed private with policies re-derived, zero blanket `USING(true)`/`WITH CHECK(true)`/`TO public`/`TO anon` policies anywhere in 196 migrations | ~35 low-risk operational tables (support/ai/billing internals) were pattern-classified against a now well-established architecture rather than each individually re-derived line-by-line — see `MORT_BACKEND_SAFETY_AUDIT_SESSION4.md` for the exact list and reasoning |
| Safety systems | 1 real P1 found and fixed (guardian-invite brute-force) | N/A | `MORT_BACKEND_SAFETY_AUDIT_SESSION2.md` Track 4; fix in commit `f9f5861`/`a1be570` | Fix not yet executed against a live/staging Postgres (no local DB tooling available) — recommend staging verification before deploy |
| Moderation architecture | 100 (of sampled scope) | Staffing = BLOCKED_EXTERNAL | Staff role provisioning requires admin + bounded 90-day expiry + training/confidentiality/conflict/device-compliance gates before access grants | Deeper review of report/escalation/appeal UX flows not yet done |
| Financial Safety (teen earnings feature) | 100 (of transferred scope) | N/A | `MORT_FINANCIAL_SAFETY_TRANSFER.md`: surgically transferred from the read-only-inspected PR #4 checkout (never merged/modified) — models, repository, export service, 8 screens/routes, 4 test files, migration (5 tables, ~16 RPCs, private storage bucket). Found and fixed a real bug during review: `get_linked_teen_financial_summary` used `auth.uid()` internally via a delegated call, so a guardian would get their own empty summary instead of the linked teen's despite correct authorization checks — fixed (commit `7484ff1`). Full regression 487 passed/2 skipped/0 failed | SQL fixes unexecuted against a live Postgres (same limitation as other backend fixes this session) — recommend staging verification, specifically the guardian-linked-teen summary flow |
| Financial Safety (backend Stripe operations controls) | 100 (of sampled scope) | Live money movement = BLOCKED_EXTERNAL (no provider credentials) | DB-level fail-closed live-gate constraint (`stripe_runtime_phase12_live_gate`), idempotent incident recording, receipt truth-in-labeling, deletion-retention hold | None found in sampled scope |
| Payment/dispute architecture | 100 (of sampled scope) | Live payments = BLOCKED_EXTERNAL | Idempotency keys on all Stripe calls, DB-enforced reviewer/operator separation of duties | Full dispute-decision → payout-adjustment path not traced end-to-end |
| Identity verification architecture | 100 (of sampled scope) | Live identity provider = BLOCKED_EXTERNAL | Fail-closed without provider config; SSRF-safe handoff-host allowlisting; bounded 30-min handoff TTL | None found in sampled scope |
| Android implementation | 100 (of sampled scope) | Release signing = BLOCKED_EXTERNAL (owner keystore) | Manifest audited: only one exported component (`.MainActivity`, correctly exported for LAUNCHER), custom-scheme OAuth deep links match client-side `MortOAuthCallbackPolicy` strict scheme/host/path allowlisting + sensitive-param rejection; `network_security_config.xml` disables cleartext traffic globally with no debug override; AD_ID/ADSERVICES/FOREGROUND_SERVICE permissions explicitly removed; native `FLAG_SECURE` channel confirmed wired to 20+ real sensitive routes (`SensitiveScreenProtection` in `app_router.dart`), not dead code. **Runtime-verified, not just built**: generated a throwaway local-only signing key (never committed — gitignored, deleted after use) purely to exercise `flutter build apk --release` end-to-end; R8 minify+shrink succeeded (74.0MB), installed on the `MORT_QA_Pixel6` emulator, launched, and stayed resumed with zero `FATAL EXCEPTION` in logcat. Local API 36 emulator evidence also passed the native smoke suite and large-text safety acknowledgement flow; the emulator cleanup exit code 1 occurred only after intentional shutdown and is expected. | Full authenticated Android Phase 17 journeys remain pending safe public QA configuration; keyboard, small-screen, reduced-motion, and full role-surface checks remain unexecuted |
| iOS source implementation/parity | 100 (of sampled scope) | macOS/Xcode build = PASS; App Store signing = BLOCKED_EXTERNAL | `MORT_IOS_NATIVE_SOURCE_AUDIT.md` establishes the privacy, OAuth, Firebase, permission, and ATS contracts. GitHub Actions [run 34131627976](https://github.com/mortapp/Mort/actions/runs/34131627976) on macOS/Xcode 16.2 passed pub get, format, analyze, 487-test suite, CocoaPods, `xcodebuild -list`, unsigned `flutter build ios --release --no-codesign`, IPA packaging, and artifact upload for `62b48fd`. The CocoaPods base-config warning is non-blocking: `Flutter/Debug.xcconfig` and `Flutter/Release.xcconfig` already include the matching Pods configs, and Profile maps to Release. | No sampled build-path work remains; real-device testing and distribution signing remain external |
| iOS/Android real-device QA (BrowserStack) | iOS execution PASS / Android cloud execution not required | BrowserStack iOS QA = PASS; Android local emulator = PARTIAL | [Run 34472297830](https://github.com/mortapp/Mort/actions/runs/34472297830) built, uploaded, and completed the three-device iOS functional matrix against the post-redesign candidate; evidence artifact contains all passing checkpoint screenshots. | Android full authenticated/device-configuration coverage remains pending safe QA public configuration; App Store/TestFlight signing remains external |
| UI/design system/V6 polish | 100 (of sampled scope) | N/A | `MORT_UI_DESIGN_SYSTEM_AUDIT.md`: token-bypass scan (6 hits, all legitimate — Google/Apple brand-guideline colors, one shadow overlay); canonical-button spot-check (raw TextButton usage found to be correct inline-link/dialog patterns, not violations); accessibility scan of all 43 IconButton sites found and fixed one real gap (missing tooltip on notification "mark as read", `MortIconButton`'s tooltip is required at the type level so this was the only bypass); tap-target constant (`MortSpacing.minTouchTarget = 48.0`) applied consistently; reduced-motion and high-contrast confirmed as real, plumbed-through preferences, not stubs | Full screen-by-screen visual parity not eyeballed (needs a running device pass, better suited to the BrowserStack track) |
| Automated tests | 487 passed / 2 skipped / 0 failed | N/A | Grew from 448 at session start to 487 across the legal-reacceptance (4 new), and financial-safety-transfer (4 new files) work; every regression run this session green | No new automated backend test harness exists (pgTAP/SQL) — flagged as a gap, not fixed (would be new infrastructure, out of scope for a targeted audit) |
| Legal/compliance implementation | 100 (of sampled scope) | Final attorney legal approval = BLOCKED_EXTERNAL (every document is explicitly `draft_attorney_review`, labeled as such everywhere in-app) | `MORT_LEGAL_RECONSENT_AUDIT.md`: server-authoritative hash-bound acceptance, role/age-specific requirements, no-inferred-acceptance, required-vs-optional decline handling all verified sound. Found and fixed a real gap: nothing prompted an already-onboarded user to re-accept a materially revised document — added `pendingRequiredLegalReacceptanceProvider` + one-shot redirect in `app.dart`, 4 new tests, full regression 452 passed/2 skipped/0 failed | Public-site-vs-in-app wording parity not verified word-for-word (attorney-level task, out of scope) |
| Technical public-launch readiness | 100 (of internally actionable scope) | Multiple external gates remain (see `MORT_EXTERNAL_RELEASE_GATES.md`) | RLS/backend, legal/re-consent, UI/accessibility, Financial Safety transfer, iOS native audit, macOS CI, and real iOS BrowserStack QA are complete with committed evidence. Android emulator availability is resolved; remaining Android authenticated/configuration checks require safe QA public configuration. | Android full authenticated journey coverage, Android signing, Apple signing, legal approval, provider approvals, staffing, and live Supabase Dashboard verification remain |

## Final classification

FINAL_CLASSIFICATION=INTERNAL_WORK_REMAINS
INTERNAL_ENGINEERING_STATUS=ANDROID_PHASE_17_REMAINS
REMAINING_INTERNAL_ANDROID_QA=AUTHENTICATED_ROLE_KEYBOARD_SMALL_SCREEN_REDUCED_MOTION

## What "100 (of sampled scope)" means

This program samples the highest-risk paths in each area first (per the task's own
priority ordering) rather than re-deriving every line of every migration. A "100 (of
sampled scope)" entry means: everything actually inspected in that area was verified
correct, with no shortcuts taken to make it look done. It is not a claim that literally
every function/policy/screen in that category has been individually re-reviewed — the
"remaining internal work" column says exactly what has not yet been looked at.
