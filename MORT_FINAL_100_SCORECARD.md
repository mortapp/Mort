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

### Re-attempt check (2026-09-12, later same day)

Checked host conditions before deciding whether to retry, per the diagnose-don't-
retry-blind policy: `Get-CimInstance Win32_OperatingSystem` reported **1.37 GB free
of 15.45 GB total** -- worse than every reading in the forensic session above (which
ranged 1-4 GB). Checked for any leftover process from this session's own work
(`node`, `next`, `lighthouse`, `qemu`, `emulator`, `java`, `gradle`) that could be
reclaimed first: the only `node` processes found were 10-21 MB each, not a lingering
dev server -- this session's own `next start` instances and Lighthouse's headless
Chrome had already exited cleanly. The top memory consumers (`Get-Process | Sort
WorkingSet64`) were six independent `chrome` processes (~450 MB each), two `Code`
(VS Code) instances, `Discord`, `MsMpEng` (Windows Defender), and `Memory
Compression` already active at 566 MB -- all the user's own concurrent desktop
session, not anything this task spawned or can reclaim.

Did not attempt another emulator boot: current free RAM is strictly worse than the
conditions that produced 3 prior crashes at the identical trigger, and forcing a 4th
attempt risks destabilizing the user's active desktop session for a near-certain
repeat failure rather than new information. This re-confirms
`ANDROID_ENVIRONMENT_BLOCKER=HOST_RESOURCE_PRESSURE` rather than superseding it.
Unchanged recommendation: retry after a reboot/quiet host, or move interactive
Android QA to a cloud device lane (BrowserStack) as already done for iOS.

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

## Web + mobile launch integrity pass (2026-09-12)

Companion to a security/quality sweep of the separate `mortapp/mort-web` repo (see
PR https://github.com/mortapp/mort-web/pull/1, not merged). Fresh spot-checks against
the current migration state in *this* repo, done in parallel while that PR was under
independent review:

- QA_ESCAPE_GATE=PASS — `MORT_BROWSERSTACK_QA_MODE` is a Dart `bool.fromEnvironment`
  compile-time constant (cannot be toggled by any runtime input); `release_profile.dart`
  additionally throws a hard `StateError` at startup (`assertValidReleaseConfiguration`,
  called from `main.dart`) if it's ever set outside `automated_test`/`internal_test`.
  Same compile-time-constant pattern independently confirmed for
  `identityVerificationEnabled` and the ads/IAP gates.
- DEBUG_UI=PASS — `kDebugMode`-gated code (`app_config.dart:173-174`) only controls a
  visible "Debug" badge and diagnostics text (the same badge visible in this session's
  own emulator screenshots), never a navigable route or auth bypass; `kDebugMode` is
  `false` in any real release build by Flutter SDK guarantee, not app-level toggle.
- STORAGE_BUCKET_PRIVACY=PASS — every one of the 8 `storage.buckets` insert statements
  across all migrations (`proof-uploads`, `profile-avatars`, `identity-evidence`,
  `incident-evidence`, `mort-document-vault`, `support-evidence`, `support-attachments`,
  `financial-receipts`) explicitly sets `public = false`. Checked all 8 directly, not
  sampled.
- RATE_LIMITING=PASS (spot-checked) — `submit_safety_report_v2` enforces both an
  immediate-danger-specific throttle (`urgent_safety_rate_limited`) and a general cap
  (15) via `safety_report_rate_limited`, generous enough not to block a genuinely
  distressed user while preventing spam. Confirmed alongside the previously-recorded
  `check_rate_limit()` coverage for guardian invites/acceptance, support tickets,
  account deletion, and auth identity events.
- GUARDIAN_RLS_TIGHTENING=VERIFIED_NO_BYPASS — `20260711170513_...sql` explicitly
  `drop policy if exists guardian_connections_insert_teen` /
  `..._update_guardian_or_admin` *before* creating the replacement admin-only
  policies. Confirmed this wasn't a case of an old permissive policy coexisting
  alongside a new restrictive one (Postgres RLS policies are additive/OR'd for
  permissive policies, so a stale drop-less "tightening" migration would have been a
  real, silent bypass -- it is not the case here).
- PAYMENTS_LIVE_GATE=PASS (re-verified) — `stripe_runtime_phase12_live_gate` CHECK
  constraint still requires `mode <> 'live'` unless all ~13 explicit approval flags
  (owner/legal/privacy/tax/minor-payout/retention/receipts/reconciliation/etc.) are
  simultaneously true. Unweakened since the last audit.
- OPEN_REDIRECT / SSRF (mobile)=PASS — `lib/core/utils/safe_uri.dart`'s
  `safeInternalHelpRoute` rejects any URI with a scheme or authority (blocks both
  absolute URLs and `//host`-style protocol-relative redirects) and path-traversal
  segments, using an allowlist (not a blocklist) of exact/prefix paths.
  `safeExternalHttpsUri` rejects localhost/private/link-local hosts; the only caller
  (`safeStripeConnectUri`) additionally pins the host to exactly `connect.stripe.com`.
- PRIVATE_API_KEYS (mobile client)=PASS — zero references to any service-role key
  pattern anywhere in `flutter_mort/lib/`.

## Real CI evidence for this branch (2026-09-12)

`mort-ci.yml`'s `on.push.branches` allowlist (`main`, `mort-supreme-production-readiness`)
does not include `integration/mort-final-100-post-redesign`, and no PR previously existed
for it -- meaning zero real CI evidence existed for this branch's history before today.
Opened PR https://github.com/mortapp/Mort/pull/9 (base `main`, head this branch, title
"DO NOT MERGE — CI evidence only") solely to trigger the `pull_request` workflow trigger.
**This PR must not be merged** -- same role as PR #8 for the prior branch.

Run https://github.com/mortapp/Mort/actions/runs/34692994883 — all three real jobs pass:
- `expo-reference` = PASS (1m37s)
- `flutter-authoritative` = PASS (4m18s)
- `public-site` = PASS (18s)

Vercel check on the same PR reports `fail` (`dpl_52pQHUSEjC9r1SdmtGXhjzXLh9E8`,
`Error: supabaseUrl is required.` thrown inside `@expo/router-server`'s static export of
the legacy Expo reference app). Root-caused as a **pre-existing Vercel project
configuration gap** (the Preview environment for this Vercel project is missing an
`EXPO_PUBLIC_SUPABASE_URL`-equivalent env var), not a regression from this branch's
changes: PR #8 (a different, earlier branch, already fully reviewed and accepted) shows
the byte-for-byte identical `Deployment has failed` / `supabaseUrl is required` failure
mode while its own three GitHub Actions jobs all pass. Classified as an **external
gate** (Vercel dashboard project-settings access, not a code fix) -- flagging for
whoever owns the Vercel project rather than attempting to "fix" it by touching app code.

Re-confirmed on the docs-only follow-up push (`bf2f63a`): run
https://github.com/mortapp/Mort/actions/runs/34693880624 -- `expo-reference` PASS (2m21s),
`flutter-authoritative` PASS (3m42s), `public-site` PASS (22s). Vercel check
(`dpl_3ooHP82UbNSf1qxM9sFo26Csa88L`) failed again with the byte-for-byte identical
`Metro error: supabaseUrl is required.` / `pnpm run build exited with 1` signature,
confirming this is a stable, reproducible pre-existing gate rather than a flaky or
branch-specific regression.

Re-confirmed a third time on the next docs-only push (`39e0bcd`): run
https://github.com/mortapp/Mort/actions/runs/34695155304 -- all three real jobs PASS
again (`expo-reference` 1m28s, `flutter-authoritative` 3m47s, `public-site` 29s); Vercel
(`dpl_J8YGzDDZBh8XH4uGgf8aYPthL99k`) failed with the same `supabaseUrl is required.`
signature. No new information -- recording only to confirm the pattern hasn't changed.

## mort-web independent-reviewer fixes (2026-09-12)

A fresh, read-only reviewer subagent independently re-verified all 9 claims in
`mortapp/mort-web` PR #1 against `main` (separate repo, separate Vercel/CI surface from
the Mort mobile/backend monorepo). All 9 claims held up under independent re-test
(CVE counts, zero-vulns-after-fix, live security headers, route titles, robots/sitemap,
custom 404, dynamic copyright year). It also found two real, previously-missed gaps,
both fixed and re-verified in this session before the reviewer's findings were closed
out:
- CSP/font conflict: `app/globals.css` imports Google Fonts (`fonts.googleapis.com`
  stylesheet, `fonts.gstatic.com` font files), but the new CSP's `style-src`/`font-src`
  only allowed `'self'` -- contradicting the `next.config.ts` comment's own claim that no
  other external origin is referenced anywhere in `app/`. Fixed by adding both origins
  to the relevant directives; rebuilt with real Supabase env vars and confirmed via a
  live `curl -D -` that the served CSP header now includes both. `npm run build` and the
  full `npm test` suite (5/5) still pass after the change.
- Icon consistency: a raw `←` glyph appears in front of link text in three back-navigation
  links (`app/app/support/[id]/page.tsx`, `app/app/messages/[id]/page.tsx`,
  `app/app/teen/jobs/[id]/page.tsx`) -- a consistent, intentional pattern across all
  three, not the isolated inconsistency the reviewer's 5-file sample suggested, but
  still lacking `aria-hidden` (a screen reader would announce "left arrow" ahead of the
  destination name, which the destination text alone already conveys). Fixed by wrapping
  the glyph in `<span aria-hidden="true">` in all three locations rather than forcing it
  through the `Icon` SVG component (which has no left-arrow path defined and is meant for
  standalone/leading decorative icons, not inline text-adjacent glyphs).

Both fixes were committed (`1e35573`) and pushed to `audit/final-100-launch-integrity`.
**Before that push's CI could be checked, PR #1 was merged into `main` by the `mortapp`
account** (`mergedAt=2026-09-12T01:57:24Z`, `mergedBy.login=mortapp`, `is_bot=false`,
`autoMergeRequest=null` -- a direct merge, not an auto-merge queue) -- not an action taken
by this session; no `gh pr merge` was ever run here. `main`'s HEAD (`67c8e62`) was at
`11dde0c`, i.e. *before* the font-CSP fix, so `main` briefly shipped with `style-src`/
`font-src` blocking the site's own Google Fonts import.

## mort-web: second real regression found + PR #2 opened (2026-09-12)

Ran Lighthouse (`npx lighthouse`, real headless Chrome, real production build + real
Supabase env vars) against the merged `main` state as an extra check beyond the
independent reviewer's manual pass. Accessibility=100, SEO=100, but Performance=41 and
`errors-in-console` failed best-practices with:
`CompileError: WebAssembly.instantiate(): ... violates ... script-src 'self' 'unsafe-inline'`.

Root cause: `@react-three/rapier`'s physics engine (compiled to WebAssembly, used by
`components/mort/scene/world.tsx`, mounted from `MortAtmosphere` for the homepage's
animated hero scene) cannot instantiate under a CSP with no WASM allowance -- a real
regression from this session's own earlier `next.config.ts` CSP-hardening commit,
undetected until this Lighthouse run because prior verification only checked that
headers were *present*, not that every page's actual client-side functionality still
worked under them.

Fixed by adding `'wasm-unsafe-eval'` to `script-src` (narrower than `'unsafe-eval'`:
permits only WASM module instantiation, not arbitrary JS `eval()`). Re-ran Lighthouse
after the fix: best-practices 92->100, the console-error audit now passes, LCP improved
8.9s->3.7s. Total-blocking-time got *worse* (8.6s->19.7s) after the fix -- expected, not
a regression: previously the physics scene was silently failing (less real work), now it
correctly runs. Verified this is an accepted, already-mitigated design tradeoff rather
than an unmitigated defect: `MortAtmosphere` (`components/mort-atmosphere.tsx`) defaults
`reduced=true` and never mounts the WASM scene unless `prefers-reduced-motion` explicitly
allows motion, feature-detects WebGL2 with a static CSS fallback (`SceneBoundary` error
boundary too), pauses on `document.visibilitychange`, and exposes a manual
pause/resume control with `aria-pressed`/`aria-label` (satisfying WCAG 2.2.2 Pause, Stop,
Hide). Did not rework the scene itself -- it's a deliberate brand/design asset, out of
scope for a CSP correctness fix.

Committed (`1431129`), pushed to `audit/final-100-launch-integrity`, `npm run build` /
`npm test` (5/5) / `npm run lint` all re-verified passing. Since PR #1 was already merged,
opened a fresh PR https://github.com/mortapp/mort-web/pull/2 (base `main`) carrying both
post-merge fix commits (font-CSP + wasm-unsafe-eval). Its Vercel check passes
(`dpl_2FU3GeUFD8B7KKteGmNuvvhRMRmK`). **Not merged** -- left open for explicit owner
review/merge per the standing "no merge to main without explicit authorization" rule.

## Keyboard-navigation / manual accessibility pass -- honest scope limitation

Chrome browser automation (`claude-in-chrome`) was unavailable in this environment this
session ("Browser extension is not connected"), so a live, interactive keyboard-tab-order
and screen-reader pass could not be performed and is not claimed here. What was verified
instead, all via static analysis and Lighthouse's automated accessibility audit (which
covers a meaningful subset of WCAG 2.x success criteria via axe-core rules, including
color-contrast, but is not equivalent to manual testing):
- Lighthouse accessibility category = 100 on the homepage (post-CSP-fix build).
- `skip-link` element present (`app/globals.css`/layout), `main` elements carry
  `id="main-content" tabIndex={-1}` across pages, consistent with skip-to-content support.
- No `tabindex` values greater than `0` found via grep across `app/` and `components/`
  (positive tabindex values are a common keyboard-trap/order-scrambling anti-pattern).
NOT_APPLICABLE / NOT_DONE: full manual keyboard-only navigation through signup/login/job
flows, and screen-reader (NVDA/VoiceOver) verification, remain undone this session --
recorded honestly rather than claimed.

## Color-contrast spot-check against WCAG AA (2026-09-12)

Since a live browser wasn't available to sample rendered pixels, computed real WCAG 2.x
relative-luminance contrast ratios (not eyeballed) for `app/globals.css`'s primary
text/button token pairs, including alpha-blended backgrounds composited against the page
canvas where relevant:

| Pair | Ratio | AA (4.5:1 text / 3:1 UI) |
|---|---|---|
| body text `--text` on `--bg` | 18.40:1 | PASS |
| muted text `--muted` on `--bg` | 6.77:1 | PASS |
| secondary muted `--muted2` on `--bg` (also `.btn.ghost` text) | 12.67:1 | PASS |
| `.btn.primary` text on gradient (lightest point) | 18.75:1 | PASS |
| `.btn.primary` text on gradient (darkest point) | 14.86:1 | PASS |
| `.btn.info` text on `--accent-blue` | 8.66:1 | PASS |
| `.btn.sos` text on gradient (lightest point) | 6.95:1 | PASS |
| `.btn.sos` text on gradient (darkest point) | 5.93:1 | PASS |
| `.btn.danger` text on its own tint background | 7.23:1 (or 6.42:1 over a card surface) | PASS |

Every sampled pair clears AA with real margin; most also clear AAA's 7:1 (the two
exceptions -- `--muted` at 6.77:1 and `.btn.sos` darkest-point at 5.93:1 -- still clear
AA comfortably). No contrast defect found in this spot-check. This does not replace a
full page-by-page audit (only the primary design-system tokens were sampled, not every
one-off inline color in the codebase), but is a genuine computed result, not a fabricated
pass.

**Correction (2026-09-12, later same day):** the table above used `--text`/`--muted`/
`--muted2`/`--accent-blue` as declared in `app/globals.css`'s `:root`. During the
anti-vibecode pass below, it turned out `app/cinematic.css` declares its own `:root`
block that redefines several of the *same* custom-property names (`--bg`, `--text`,
`--muted`, `--muted2`, `--primary*`, `--accent-blue`, `--accent-pink`, `--purple`), and
because `layout.tsx` imports `cinematic.css` *after* `globals.css`, its values win the
cascade everywhere -- so the numbers above were computed from shadowed, non-rendering
values. Recomputed with the actual cascade-resolved values: body text 17.96:1, muted
text 8.22:1 (higher margin than first reported, not lower), muted2 11.63:1, `.btn.info`
text-on-accent-blue 9.40:1, `.btn.danger` text-on-tint 6.90:1. `.btn.sos` is unaffected
(its colors aren't in `cinematic.css`'s override list). **The conclusion is unchanged
and if anything stronger -- every pair still clears AA with real margin -- but the
specific figures above should be read as superseded by these.** See the "Cascade
duplication" finding below for the underlying `:root`-shadowing issue itself.

## Mobile app (flutter_mort): anti-vibe-code + accessibility spot-check (2026-09-12)

Companion pass to the mort-web checks above, applying the same launch-integrity
checklist to the Flutter app in this worktree. All findings below are from actual
grep/read evidence against `flutter_mort/lib`, not inferred:

- Purple gradients / off-brand color: NOT_FOUND. `grep -i 'purple|violet'` across
  `lib/core/theme` returns nothing. `mort_colors.dart` is a deliberate monochrome
  palette (black/white/silver family) plus one restrained cool-blue accent reserved
  for "information, safety, location, and verified system state" per its own doc
  comment -- consistent with the "converged monochrome theme" already recorded above,
  not a vibe-coded default.
- Emoji-as-UI-icon: NOT_FOUND as a pattern. The one emoji-range character match in
  `lib/features/mort_screens.dart` is a `★` rendered inline with a real computed
  value (`'${rank.averageRating.toStringAsFixed(1)}★ avg'`) -- a data-driven rating
  display, not a decorative icon substitute.
- Fabricated social proof: NOT_FOUND. Grepped for "trusted by", "thousands of",
  hardcoded user/download counts, testimonial-quote patterns, "verified reviewer" --
  no matches. The only counts rendered in the UI (leaderboard rank, completed-job
  totals, review averages) are sourced from live repository/provider calls, not
  hardcoded strings.
- AI-slop marketing copy: NOT_FOUND. Grepped for "revolutionary", "game-changing",
  "industry-leading", "100% safe", "guaranteed", "#1" and similar superlative-claim
  patterns -- no matches in `lib/`.
- Icon-button accessibility: systemic, not spot-luck. All 43 `IconButton`/
  `MortIconButton` occurrences sampled across 24 files carry an explicit `tooltip:`;
  the shared `MortIconButton` widget (`lib/core/widgets/mort_widgets.dart:499-504`)
  makes `tooltip` a compiler-enforced `required` constructor parameter, so a new
  icon button without one fails to build rather than silently shipping unlabeled.
- Touch targets: `MortSpacing.minTouchTarget = 48.0` (logical px), referenced
  directly in interactive widget constraints (e.g. `mort_liquid_glass.dart:367`) --
  meets the standard 44-48dp minimum target size guidance.
- Reduced motion: genuinely systemic, not a single opt-out. Motion-reduction
  handling (`disableAnimations`/`AccessibilityFeatures`) appears in 10 separate
  files spanning onboarding, core widgets, brand/liquid-glass components, page
  transitions, and `app.dart` itself -- not confined to one screen.
- Color contrast (computed, not eyeballed) for the monochrome theme's real
  text/status pairs against the two darkest surfaces in use:

| Pair | Ratio | AA (4.5:1 text) |
|---|---|---|
| `text` (godWhite) on `bg` (godBlack) | 19.00:1 | PASS |
| `textSoft` on `bg` | 15.64:1 | PASS |
| `textMuted` on `bg` | 6.55:1 | PASS |
| `textMuted` on `card` | 5.93:1 | PASS |
| `success` on `bg` | 7.97:1 | PASS |
| `warning` on `bg` | 8.29:1 | PASS |
| `danger` on `bg` | 4.80:1 | PASS (narrow margin -- closest to the 4.5:1 floor of anything sampled; fine at normal text size, worth keeping in mind before darkening further) |
| `textDisabled` on `bg` | 2.77:1 | Below AA, but WCAG explicitly exempts disabled-control text from the contrast requirement -- correctly not a defect. |

No anti-vibe-code or accessibility defect found in this mobile spot-check. As with
the web contrast check, this samples the shared design-system tokens, not every
one-off inline color across ~62 screen files -- a genuine result at the scope
actually covered, not a claim of exhaustive coverage.

## MORT anti-vibecode / anti-template visual quality gate (2026-09-12)

Note on process: mid-way through this pass, `mortapp/mort-web` PR #2 and `mortapp/Mort`
PRs #8 and #9 were merged into their respective `main` branches by the repo owner
(outside this session -- confirmed via `gh pr view --json mergedBy`, `is_bot=false`,
not a `gh pr merge` run here). Checked the blast radius before continuing: PR #8's
branch was already a full ancestor of PR #9's (post-redesign was built on top of
readiness), so that merge added zero new content; PR #9's merge is CI-green
(`https://github.com/mortapp/Mort/actions/runs/34698368559`, success) and its content
is everything already audited and pushed in this engagement. `mort-web`'s production
deployment was confirmed live and correct post-merge (`mortapp.org` serves the fixed
CSP header). Since both `main` branches are now ahead of the branches this session had
been working on, the fixes below are on fresh branches
(`anti-vibecode-final-100-pass`) off current `main` in both repos, each opened as its
own PR and **not merged**, per the standing "no merge without explicit authorization"
rule.

### Methodology

Source audit (grep/read against real files) -> live-render audit (real production
builds, Lighthouse headless-Chrome runs including genuine full-page screenshots) ->
fix concrete findings only -> second independent source pass -> second live-render
confirmation. Chrome browser automation (`claude-in-chrome`) was unavailable this
session, so "live" evidence for the website is Lighthouse's real rendered
screenshots/scores/computed-accessibility-audit rather than interactive manual
testing; this is disclosed everywhere it's relied on, not presented as more than it
is. iOS evidence reuses the already-accepted BrowserStack run
`IOS_BROWSERSTACK_WORKFLOW_RUN=34472297830` per the gate's own instruction not to
rerun solely for prettier screenshots. Android live/interactive evidence remains
blocked by host RAM (checked again this session: 2.26 GB free, still well under what
the prior 3-crash forensic session needed; see the "Re-attempt check" above) --
recorded as a genuine, disclosed gap, not fabricated.

### Findings and fixes (mort-web)

1. **Dead "gradient orb + glass card" CSS (`app/globals.css`).** `.hero`,
   `.hero::before/::after`, `.hero-grid`, `.hero-visual`, `.hero-visual-glow` (a
   `radial-gradient` + `filter: blur(30px)` "blob", explicitly self-labeled in its own
   code comment as "gradient-to-solid blob"), and `.hero-card`/`.hero-card-back`/
   `.hero-card-front` (rotated, `backdrop-filter: blur(14px)` floating cards) were all
   dead code -- zero references in any `.tsx` file, confirmed by grep across `app/`
   and `components/`. The live hero (`components/mort-hero.tsx`, class `cinema-hero`)
   was built later on a completely different class vocabulary and never used these.
   **FIXED**: removed the entire block (was providing zero value and is exactly the
   "gradient orb" + "glassmorphic floating card" signature this gate targets).
2. **Dead "gradient hero text" utility (`app/globals.css`).** `.gradient-text`
   (`background: var(--primary-gradient); background-clip: text; color: transparent`)
   -- also zero references anywhere in `.tsx`. **FIXED**: removed.
3. **Real color-token cascade bug: `.role-badge.guardian`/`.level-badge.l4`.**
   Hardcoded a literal pink background (`rgba(255,179,209,...)`) while using
   `var(--accent-pink)` for text. Traced the actual cascade (see finding 4) and
   confirmed `--accent-pink` resolves to a cool ice-blue-gray (`#bfc9d5`), not pink --
   so the real rendered badge was a pink chip with mismatched blue-gray text.
   **FIXED**: background now derives from `var(--accent-pink-tint)`/`var(--accent-pink)`
   so text and background are always coherent regardless of which stylesheet's
   palette is active.
4. **`app/cinematic.css` silently shadows a large subset of `app/globals.css`'s
   `:root` tokens.** Both files declare an unscoped `:root { ... }` block with several
   identical custom-property names (`--bg`, `--text`, `--muted`, `--muted2`,
   `--primary`, `--primary-gradient`, `--primary-tint-bg`, `--accent-blue`,
   `--accent-pink`, `--purple`, `--purple-tint`, `--accent-pink-tint`, `--radius*`,
   `--border*`), and since `layout.tsx` imports `globals.css` then `cinematic.css`
   then `world-chapters.css` (all three global, unscoped), `cinematic.css`'s values
   always win for anything it redeclares. Its own header comment says it's "Shared
   material system: neutral metal, black glass, restrained ice-blue accents" -- a
   deliberate, documented convergence, and its actual values (`--purple: #bac6d4`,
   `--accent-pink: #bfc9d5` -- both cool grays, not purple/pink at all) are exactly
   the restrained on-palette system the gate wants. **This means the word "purple" or
   "pink" appearing as a variable *name* in `globals.css` is a false-positive trap for
   a naive text search** -- the actual rendered color is neutral gray-blue. Not fixed
   (would require auditing every one of ~15 shadowed properties across both files for
   safe consolidation -- real cleanup work, but broader than a "fix only concrete
   findings" pass should take on unprompted; flagging for deliberate follow-up rather
   than a blind mid-audit refactor). This also means the WCAG contrast correction
   above exists because of this exact issue.
5. **`role-badge.admin`'s "purple" is not visually purple.** Direct consequence of
   finding 4: `--purple`/`--purple-tint` resolve to `cinematic.css`'s `#bac6d4` (cool
   gray), so the one deliberate semantic role-color badge that reads "purple" in
   source never actually renders as purple. ANTI_VIBECODE_01 target is met even more
   solidly than a first read of `globals.css` alone would suggest.
6. **Authenticated app shell (`app/app/**`, i.e. adult/guardian/admin/teen
   dashboards) grepped separately for the same signatures** (purple/violet/indigo,
   `backdrop-filter`, `.gradient-text`, marquee, bento, `whileInView`) -- zero matches.
   Also grepped `app/app/admin` specifically for fabricated charts/live-indicator
   patterns (`chart`, `online now`, `people viewing`) -- zero matches. The
   authenticated surfaces share the same restrained system as the public marketing
   pages; no divergent "generic B2B SaaS dashboard" style found.
7. **Hero badge-like element checked and cleared.** The small `YOUR NEXT CHAPTER
   STARTS NEARBY` line above the hero headline (visible in the screenshot below) is
   an `.eyeline` element: plain flat monospace text with a 5x5px dot marker, no
   background, no border-radius, no pill shape (confirmed in `cinematic.css`). It's
   part of a consistent "chapter/crossing" editorial kicker device used identically
   elsewhere on the page (`01 -- LOCAL OPPORTUNITY`, `MORT / THE FIRST CROSSING`), not
   a generic "NEW" / "Introducing X" decorative startup badge.
8. **No shadcn/Radix/Lucide dependency at all** -- grepped `package.json`, zero
   matches. Icons are a hand-rolled `Icon` component with a fixed, small SVG path
   vocabulary (`components/mort/icon.tsx`), not a generic icon-library catalog look.
9. **No Inter, no Space Grotesk, no Instrument Serif, no italic-serif accents** --
   the site uses Plus Jakarta Sans exclusively (one `@import`, now correctly
   allowlisted in the CSP from the earlier launch-integrity pass). Grepped for
   `font-style: italic` in every `.css` file: zero matches.
10. **No grain/noise texture assets anywhere in the repo.**
11. **The one "beam" grep hit** (`components/mort/scene/environment/weather.tsx`) is
    a GLSL shader variable name for an atmospheric light-shaft effect inside the 3D
    weather/atmosphere scene -- unrelated to a cursor-following interactive gimmick.
    No cursor/spotlight/magnetic-cursor code found anywhere.
12. **No decorative scroll-reveal.** The only `IntersectionObserver` use
    (`components/mort-voyage.tsx`) pauses an animated/interactive scene when it's
    scrolled out of view (a performance optimization paired with a
    `prefers-reduced-motion` media-query sync and a `MutationObserver` on scene
    state) -- not a "fade content in on scroll" decoration.
13. **"Three items in a row" sections checked and found content-driven, not
    generic.** The homepage's `.principle-list` (MOVE / CONNECT / BUILD) uses no
    icons at all -- just a number, a specific heading, and a specific sentence per
    item, thematically tied to the site's actual job-lifecycle narrative. The
    `.role-editorial` teen/adult/guardian section represents three real, distinct
    product audiences (a genuine informational necessity for a multi-role
    marketplace), each with unique copy and its own CTA -- not interchangeable
    generic benefit cards.
14. **Em-dash usage checked across marketing/legal copy**: 3-7 per page on pages with
    substantial text (privacy policy, safety page). Read every instance in context --
    each is either a real clarifying clause ("never random direct messages -- ...")
    or a standard "Page Title -- MORT" title-separator convention, not filler
    connecting vague buzzwords. Not an overuse pattern; did not strip legitimate
    punctuation.
15. **Buzzword grep** (seamless/revolutionary/game-changing/cutting-edge/
    next-generation/transformative/empowering/unlock/reimagine/"future of"/
    one-stop/effortlessly/"innovative platform") returned exactly one hit: "earn XP,
    unlock badges, and level up your hustle" -- a literal, specific description of a
    real in-app gamification mechanic (XP/badges/leveling), not vague filler.
16. **Shape-language spot-check**: a real token scale exists (`--radius-sm: 12px`,
    `--radius: 16px`, `--radius-lg: 22px`, `--radius-pill: 999px`) used consistently
    for cards/panels/chips. Small icon-tile boxes (32-56px) use proportionally-scaled
    radii (9-16px) rather than the token scale directly -- a defensible, common
    technique (corner radius scaled to a small fixed box's own size), not "every
    control turned into a random capsule."
17. **Live-render evidence.** Real Lighthouse run against a real production build
    (`localhost`, real Supabase env vars) after the fixes above:
    performance=67 (up from 41 before the earlier CSP/WASM fixes), accessibility=100,
    best-practices=100, SEO=100, 0 console errors. Also ran against `/safety`:
    accessibility=100, 0 failed audits. Captured and visually reviewed a real
    full-page-render screenshot of the homepage hero (saved via Lighthouse's
    `final-screenshot` trace, not fabricated) -- see below for what it shows.

Homepage hero screenshot review (real render, not a mockup): deep near-black
background with a custom, bespoke 3D atmosphere scene (mountains, water reflection,
a faceted gem/diamond centerpiece) -- not a generic gradient blob or stock
illustration; a plain white "Start your crossing" pill CTA plus one plain-text
secondary link, not a wall of competing CTAs; a monospace "MORT / THE FIRST CROSSING"
coordinate label and small eyeline kicker text (checked above, not a decorative
badge); a visible "Pause atmosphere" control confirming the accessibility affordance
found in code is real and rendered; minimal nav (wordmark + menu icon only). Reads as
distinctive and intentional, not a generic AI-SaaS template.

### Findings (flutter_mort, mobile) -- carried forward from the spot-check above, plus new this pass

18. **`mort_liquid_glass.dart` (the app's one remaining "liquid glass" component
    family) assessed in depth**, since the directive explicitly states MORT's
    liquid-glass direction is no longer the final identity. Read the full
    `LiquidGlassContainer` implementation: blur is **disabled entirely on web**,
    **disabled by default on Android** (opt-in only per call site via
    `allowAndroidBlur`), disabled under `MediaQuery.highContrastOf` and a real
    user-facing `reducedTransparency` preference, and even when active uses a low
    base alpha (8-20%) layered under the blur with a solid 82-92%-opaque fallback
    everywhere it's off. Wrapped in `RepaintBoundary` for GPU isolation. Used in 10
    files including the Teen shell's nav bar/header, the auth screen, profile
    surfaces, and settings -- real breadth, not confined to one screen, but every
    non-blurred fallback state already matches the gate's own stated ideal ("dark,
    solid/near-solid, controlled translucency, thin restrained borders"), and the
    live-blur variant mimics iOS's own native translucent nav-chrome convention
    (platform-appropriate, not a copied web trend) rather than decorating content
    cards indiscriminately. **Classified as legitimate, already-restrained usage,
    not fixed** -- ripping it out would be exactly the "broad redesign" this gate's
    own rules say not to do without a concrete defect, and the fallback state already
    satisfies the accessibility-first requirement (section 62: accessibility wins).
19. **Shape-language token scale confirmed** (`MortRadii.small/medium/card/sheet/
    pill` = 10/14/16/20/999, `MortSpacing` similarly tokenized) -- consistent,
    canonical, not one-off values.
20. Purple/emoji-heading/fake-social-proof/buzzword/touch-target/reduced-motion/
    contrast findings from the earlier spot-check (see above) stand unchanged after
    this second look -- re-grepped the same patterns fresh and got identical
    zero-match results.

### Second independent pass

Re-ran the core signature greps (`purple|violet|indigo`, `backdrop-filter`,
`gradient-text`, `shadcn|lucide-react`, `marquee|bento`, `whileInView`) against both
repos fresh, after the fixes above, rather than only trusting the first pass's notes:
`MISSED_SIGNATURES=0` -- no new active template signature turned up that the first
pass missed. The `--accent-pink`/`--purple` cascade-shadowing discovery (finding 4)
itself came from this kind of re-verification (re-tracing a variable's *actual*
resolved value instead of trusting its declared value in the first file read) --
exactly the case this gate's two-pass requirement exists to catch.

### Cross-platform coherence

Website and mobile independently converge on the same underlying philosophy: a dark,
near-black canvas; a restricted, restrained cool-blue/neutral-gray accent instead of a
saturated brand hue; a real typographic and spacing token scale rather than
ad hoc values; systemic (not spot-lucky) accessibility affordances (tooltips,
reduced-motion, touch targets, contrast); and a shared "restrained, not generic"
design philosophy -- reached independently on each platform (mobile's monochrome
convergence documented in `mort_colors.dart`'s own comments; web's in
`cinematic.css`'s own comment) rather than copy-pasted, but landing in the same place.
Neither platform uses shadcn/Lucide/Inter/Space-Grotesk-plus-Instrument-Serif/grain
textures/cursor gimmicks. This reads as one coherent brand family, not two
independently-styled products that happen to share a name.

### Final 20-point report

```
ANTI_VIBECODE_01_PURPLE_BLUE_GRADIENT=PASS (one semantic admin-badge token named
  "purple" exists but its cascade-resolved color is a neutral gray, not purple; no
  primary gradient anywhere)
ANTI_VIBECODE_02_GRADIENT_HERO_TEXT=FIXED (dead .gradient-text utility removed;
  live hero never used it)
ANTI_VIBECODE_03_HEADING_EMOJIS=PASS (none found on web or mobile; the one emoji-
  range mobile match is a data-driven rating "★", not a decorative heading icon)
ANTI_VIBECODE_04_GENERIC_INTER_EVERYWHERE=NOT_APPLICABLE (site uses Plus Jakarta
  Sans exclusively; mobile uses its own MORT typography system)
ANTI_VIBECODE_05_COLORED_BORDER_CARDS=PASS (role-badge system is semantic --
  4 real user roles, each one deliberate color -- not decorative rainbow cards)
ANTI_VIBECODE_06_GLASSMORPHISM=PASS (web: dead glass-card block removed, surviving
  backdrop-filter uses are scoped to nav/header/auth-panel chrome, not "everywhere";
  mobile: restrained, accessibility-gated, disabled on web/default-Android, solid
  fallback matches the gate's own stated ideal)
ANTI_VIBECODE_07_LOW_CONTRAST_DARK=PASS (computed WCAG ratios, corrected for the
  real cascade winner on web; all pairs clear AA on both platforms with real margin)
ANTI_VIBECODE_08_THREE_ICON_BOX_ROW=PASS (the two 3-item sections are icon-free,
  content-specific, and narratively tied to the actual product, not generic filler)
ANTI_VIBECODE_09_HERO_BADGE=PASS (the hero's small kicker line is plain text with
  a 5px dot marker, no pill/background, part of a consistent editorial device)
ANTI_VIBECODE_10_GENERIC_LUCIDE_USAGE=NOT_APPLICABLE (no icon library dependency
  at all on web; mobile uses Material icons through app-specific widgets, not a
  raw unmodified icon catalog)
ANTI_VIBECODE_11_UNTOUCHED_SHADCN=NOT_APPLICABLE (zero shadcn/Radix dependency)
ANTI_VIBECODE_12_SCROLL_FADE_OVERUSE=PASS (the one IntersectionObserver use is a
  performance pause, not decorative reveal; no framer-motion whileInView usage
  found anywhere)
ANTI_VIBECODE_13_CURSOR_BEAM=PASS (no cursor-following/spotlight/magnetic-cursor
  code; the one "beam" grep hit is an unrelated GLSL shader variable name)
ANTI_VIBECODE_14_OPACITY_ONLY_BUTTON_HOVER=PASS (confirmed in the earlier
  launch-integrity pass: .btn:hover changes background+border+color together)
ANTI_VIBECODE_15_INCONSISTENT_SPACING=PASS (real spacing/radius token scales exist
  and are used consistently on both platforms; small proportionally-scaled icon-tile
  radii are a deliberate technique, not unexplained drift)
ANTI_VIBECODE_16_EM_DASH_OVERUSE=PASS (3-7 per page on long-copy pages, every
  instance read in context and found to be a genuine clarifying clause or a
  standard title separator, not AI-pattern filler)
ANTI_VIBECODE_17_GENERIC_BUZZWORDS=PASS (one buzzword-adjacent grep hit was a
  literal, specific description of a real gamification feature)
ANTI_VIBECODE_18_SERIF_ITALIC_TREND=NOT_APPLICABLE (no italic serif usage found)
ANTI_VIBECODE_19_TREND_FONT_PAIRING=NOT_APPLICABLE (no Space Grotesk, no
  Instrument Serif, anywhere in either codebase)
ANTI_VIBECODE_20_GRAIN_GRADIENT=FIXED (the one gradient-blob-plus-blur element
  found was dead code; removed. No grain/noise texture assets exist.)
```

### Additional report

```
BENTO_GRID=NOT_FOUND
FAKE_LOGO_WALL=NOT_FOUND
FAKE_DASHBOARD_CHARTS=NOT_FOUND (admin surface grepped specifically; no fabricated
  chart/metric patterns)
FAKE_NOTIFICATIONS=NOT_FOUND
FAKE_LIVE_ACTIVITY=NOT_FOUND (no "online now"/"people viewing" patterns; the app's
  real notification-count badges are provider-driven, not decorative)
GENERIC_DEVICE_MOCKUPS=NOT_FOUND (no phone-frame/device-mockup usage found in the
  removed dead hero block or elsewhere)
GENERIC_SAAS_LAYOUT=NOT_FOUND (authenticated app shell grepped separately from
  public marketing pages; shares the same restrained system, no generic-dashboard
  divergence)
GENERIC_AI_COPY=PASS (buzzword/formulaic-structure grep clean; copy is specific to
  MORT's actual mechanics throughout)
UNMODIFIED_COMPONENT_LIBRARY_STYLE=NOT_APPLICABLE (no component library dependency
  to be unmodified from)
ICON_LANGUAGE=CONSISTENT (web: one hand-rolled Icon component, fixed vocabulary;
  mobile: Material icons routed through app-specific widgets with enforced tooltips)
TYPOGRAPHY_LANGUAGE=CONSISTENT (one font family per platform, real size/weight
  scale, no random one-off heading styles found)
SPACING_LANGUAGE=CONSISTENT (real token scales on both platforms)
SHAPE_LANGUAGE=CONSISTENT (real radius token scales on both platforms; the few
  non-token values are proportionally-justified icon-tile exceptions)
COLOR_LANGUAGE=PASS_WITH_ONE_FLAGGED_CLEANUP (every active color has a semantic
  reason on both platforms; the cinematic.css/globals.css :root-shadowing overlap
  on web -- finding 4 above -- is real duplication worth a deliberate follow-up
  cleanup, not touched in this pass since it's broader than a surgical fix)
MOTION_LANGUAGE=RESTRAINED (no scroll-jacking, no cursor gimmicks, no
  fade-in-everywhere on web; systemic prefers-reduced-motion support spanning 10
  files on mobile and the web's animated scene pauses when off-screen/hidden)
CROSS_PLATFORM_BRAND_COHERENCE=PASS (see "Cross-platform coherence" above)
```

### Final acceptance

```
ACTIVE_TEMPLATE_SIGNATURES=0 (2 dead/unused template-signature CSS blocks found and
  removed; everything else classified as PASS, NOT_APPLICABLE, or legitimate
  documented usage)
P0_VISUAL=0
P1_VISUAL=0 (one real but low-severity item -- the guardian/level-4 badge color
  mismatch -- found and fixed; the cinematic.css/globals.css token-shadowing
  duplication is flagged as a real cleanup item but did not produce any currently-
  visible defect beyond that one badge case)
P0_ACCESSIBILITY=0
P1_ACCESSIBILITY=0
WEBSITE_BRAND_COHERENCE=PASS
ANDROID_BRAND_COHERENCE=PASS (source-audited; live/interactive render remains
  blocked by host RAM, unchanged from the earlier forensic diagnosis -- not
  re-claimed as visually verified beyond what the source audit supports)
IOS_BRAND_COHERENCE=PASS (per the existing accepted BrowserStack evidence,
  run 34472297830 -- not rerun, per this gate's own instruction)
CROSS_PLATFORM_COHERENCE=PASS
MORT_ANTI_VIBECODE_GATE=PASS (with two disclosed, non-blocking follow-ups noted
  above: the cinematic.css/globals.css token-duplication cleanup, and a genuine
  interactive Android render pass once host RAM conditions allow or a cloud device
  lane is used)
```

No mistake-impossibility claim is made. This is a two-pass, evidence-based
verification (source audit -> live render -> fix -> second source pass -> second
live-render confirmation) with disclosed scope limits (no interactive browser
automation this session; Android live render still blocked), not a guarantee that
zero issues exist beyond what was checked.

Fixes for both repos are on their own branches
(`anti-vibecode-final-100-pass` in each), each opened as its own PR
(`mortapp/mort-web#3`, and this commit's PR in `mortapp/Mort`) and **not merged** --
left for explicit owner review per the standing rule, especially given the merge
timing issue noted at the top of this section.
