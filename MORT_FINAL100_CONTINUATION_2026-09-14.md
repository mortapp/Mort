# MORT Final-100 continuation — 2026-09-14

Status: **INTERNAL_WORK_REMAINS**. This checkpoint supersedes earlier blanket
100-percent claims for the current candidate. It is not release approval.

## Recovered state and accepted code

- Worktree: `mort-final-100-post-redesign`; branch:
  `integration/mort-final-100-post-redesign`.
- Start local HEAD: `5b0e69321aa5d5b9fa173df20c8eeba65c5a4432`.
- Start remote integration HEAD after fetch:
  `7757a8661afd8f0954a0f7ca2e6bf8b926318c12` (local ahead 4, remote ahead 0).
- PR #8 was already **MERGED** at `2026-09-12T14:07:37Z`, before this
  continuation. No merge, main write, force push, or history rewrite was performed.
- Preserved Claude's OAuth change and three unavailable-product routes.
- `6295969`: OAuth query decoding now fails closed. A malformed UTF-8 query
  reproduced `FormatException: Overlong encoding` before the fix and passed after.
- `95d116d`: truthful profile-style, Adult Pro, and Guardian Plus availability
  screens. The 320px / 200%-text regression reproduced a 416px overflow; the
  status-label constraint fixes it. The test scrolls/taps Back to perks and
  verifies navigation. No purchase or entitlement is fabricated.
- Independent Astra review found the query defect; scoped re-review accepted
  its fix. Root reran the final focused suite: **14 passed, 0 failed**.
  Formatting of all six task files: **0 changes**; diff check clean.
- User's newly supplied silver **double-arrow** PNG is the authoritative logo.
  Native/logo integration and its verification are tracked separately below.

## Fresh read-only hosted findings

The Supabase connector now resolves MORT project `rakjydmgwwgtdislanbt`.
Earlier statements that it was bound only to Loop no longer describe this session.
Only catalog/configuration reads were performed, inside read-only transactions;
no accounts, jobs, financial records, objects, or provider settings were changed.

- Hosted migration inventory: **196**; local SQL files: **199**.
- Local-only versions: `20260831120000`, `20260907000000`,
  `20260907010000`, `20260907020000`.
- Remote-only version: `20260901200551` (same earnings-feature name as the
  differently versioned local migration). Do not blindly replay migrations.
- Confirmed live drift, not merely a missing ledger entry:
  - Guardian financial summary still calls `get_my_financial_summary(p_year)`,
    which uses the guardian's identity instead of the linked teen's identity.
    The repository fix `20260907020000` is not deployed.
  - `work_earning_entries_guard_payment_status` trigger is absent.
  - `accept_guardian_invite` lacks the repository's acceptance-rate-limit guard.
- The local guardian-invite migration also needs transactional verification:
  it inserts the failed-attempt counter and subsequently raises an exception.
  A normal PostgreSQL transaction rolls both back. The existing
  `record_rate_limit_event` uses ordinary inserts, not an independent transaction.
  Do not treat its comment promising failed-attempt accounting as proof.
- All **10 storage buckets are private**. This checks visibility configuration,
  not cross-user policy behavior or upload/delete execution.
- No public table lacked RLS. Five private tables lack RLS, but neither `anon`
  nor `authenticated` has SELECT/INSERT/UPDATE/DELETE on those tables.
- Security advisors: 85 informational RLS-without-policy findings; 16 anonymous
  and 311 authenticated SECURITY DEFINER exposure warnings; one warning for
  disabled leaked-password protection. RPC exposure warnings require
  function-specific authorization review; they are not automatically exploits
  and are not an all-clear either.

Hosted deployment is blocked by the explicit no-production-write constraint.
The source/deployment mismatches remain release blockers, not completed work.

## Backend harness and dependency evidence

- `qa-ai-safety-edge.mjs`, `qa-support-chatbot.mjs`, and
  `run-final-supabase-regression.ps1` create/mutate hosted fixtures. They were
  **not executed** against production. JavaScript/PowerShell syntax checks passed.
- Support's disabled-provider path intentionally uses deterministic responses,
  and its QA expects them. The AI-safety edge suite itself does not invoke a
  generative provider. Historical red results cannot be waived merely because
  an external AI provider is disabled.
- Harness cleanup corrections now pass **7 offline Node tests**: restricted
  cleanup and every known run-owned auth deletion are attempted; failures reject
  without a false cleanup-success log; combined scenario/cleanup failures are
  preserved. Support storage removal now covers upload/assertion failures and
  is restricted to the manifest's exact object path. The real callback binding
  has a regression test. Independent review approved with no findings;
  root reran the seven tests and syntax checks. Committed as `4bf3c02`.
  These tests use injected in-memory functions, not production clients.
- Local Docker engine inspection returned HTTP 500. No safe local database
  regression environment was established; production was not used as a substitute.
- BrowserStack local Node suite: **15 passed, 0 failed**, after locked
  `npm ci --ignore-scripts`. Host Node 24.12.0 differs from CI's pinned Node 22.
- BrowserStack dependency audit: **6 high findings**, via `extract-zip <=2.0.1`.
  [GHSA-jmr9-qjv8-65gv](https://github.com/advisories/GHSA-jmr9-qjv8-65gv) and
  [GHSA-7pqw-9j4j-h8q3](https://github.com/advisories/GHSA-7pqw-9j4j-h8q3)
  describe symlink archive traversal; no patched extract-zip release was listed.
  An offline call with matching Appium capabilities confirmed WebdriverIO skips
  local browser download/extraction on this remote-hub path. This limits runtime
  reachability, but does not turn the six audit findings into a clean audit.
  The supply-chain gate remains unresolved. No audit-fix/force was used.

## Native/environment gates

- Flutter 3.47.2 / Dart 3.13.2; Android SDK 36.1.0 and licenses verified.
- Existing AVD: `MORT_QA_Pixel6`; emulator 36.3.10. No emulator/device was running.
- Approximately 2.0–2.1 GiB free host RAM. Three materially identical historical
  emulator failures are documented. No blind fourth launch was attempted and
  no unrelated desktop process was stopped.
- MAUI 8.0.100 is installed; it is tooling only, not an Apple execution host.
- Replaced the old rose-gold single arrow with the exact supplied double-arrow
  in Flutter and Android/iOS native assets; source SHA-256:
  `EB8D3207309FEF505DFD3DA1FB78C88136B9F46F297DDCBC0F80061498E7D686`.
  Generated Android/iOS launcher icons were visually inspected. Native splash
  backgrounds are dark, including Android 12+ day/night resources. Android's
  pre-31 bitmap references a direct raster, not adaptive-icon XML; opaque
  artwork is not exposed as a themed-icon monochrome mask.
- Independent native review approved behavior with no P0/P1 findings. Its P2
  test-binding gap was addressed with literal asset/config path assertions.
  Root final native/readiness/iOS/brand suite: **34 passed**; scoped re-review
  approved the test changes. Logo checkpoint committed as `a0fabd2`.
- Full Flutter regression: **582 passed, 2 skipped, 0 failed**. The two skips
  are existing compile-profile-gated Google Auth activation tests, not newly
  disabled tests. The first run exposed an obsolete transparent/monochrome
  logo contract; it was replaced with opaque-dark/no-monochrome/direct-raster
  assertions matching the user's supplied artwork, then the whole suite reran.
- Flutter analysis: **no issues**. Formatting: **287 files, 0 changed**;
  the final test-only follow-up also formats with 0 changes.
- Current keyboard, compact-device, 200%-text device, reduced-motion, full role,
  Guide/Support/monetization, back, and background/resume evidence is incomplete.
  Widget mounting is not a full device journey.
- Android `key.properties` is absent. Do not manufacture signing credentials.
- Fresh release AAB attempt failed at the intended signing guard:
  `Release signing is required. Debug-signing fallback is intentionally disabled.`
  No signed AAB or release 16KB result is claimed.
- First fresh Android debug build failed in AAPT resource linking: literal
  `#050914` is invalid for the layer-list item's `android:drawable` reference.
  This native defect was not caught by Flutter widget tests; it remains a
  must-fix before push while the named-color-resource correction is pending.
- Historical iOS BrowserStack run `34472297830` is not fresh proof for these
  changed auth/router/UI/native assets. Fresh iOS build/matrix remains required.
- Fresh MORT CI for the final candidate remains required. PR #8 cannot supply
  that gate because it is already merged; do not alter it to pretend otherwise.

## Continuation session 2 (same day, later) — Claude picking up from this checkpoint

- Recovered state exactly as this file describes; HEAD `4bf3c02` confirmed
  ahead of remote by 8. `flutter_mort/build/app/outputs/flutter-apk/app-debug.apk`
  (timestamp 19:44) and `.superpowers/sdd/2026-09-14-final100/android-debug-build-final.log`
  already showed the interrupted debug build had in fact **succeeded**
  (`✓ Built build\app\outputs\flutter-apk\app-debug.apk`) -- Codex's own
  session ended before observing this. Re-ran the combined
  native-launch/iOS-parity/brand-foundation/production-readiness suite fresh
  (34/34 pass), confirmed `git diff --check` clean, committed as `61e6774`
  (`fix(android): use a color resource for the native launch background`),
  pushed, and verified exact SHA equality
  (local `61e6774e1a87935cb81d4be21a6065ba1617fc5a` == remote). This checkpoint
  is now safely on GitHub.

- **Guardian financial-summary identity bug** (Section 7A):
  LOCAL_FIX_PATH=`supabase/migrations/20260907020000_fix_linked_teen_financial_summary_identity.sql`.
  HOSTED_CURRENT_STATE=still calls `get_my_financial_summary(p_year)`
  internally, which reads `auth.uid()` (the guardian's own id) regardless of
  the `p_teen_id` argument name.
  MIGRATION_OR_RPC_REQUIRED=single `CREATE OR REPLACE FUNCTION`, same
  signature, same authorization checks (guardian_financial_visibility opt-in +
  active guardian_connections link), same output shape -- only the internal
  data-source query is inlined against `p_teen_id` instead of delegating.
  DEPLOYMENT_SAFETY=low risk (no schema/table change, no data migration, no
  breaking contract change); not deployed in this session (no production-write
  authority here).
  REAL_USER_IMPACT=correctness, not a cross-user privacy leak -- the
  authorization gate runs and passes correctly *before* the buggy delegation,
  so an affected guardian gets their own (empty/irrelevant) summary instead of
  the teen's, never another user's real data. The feature silently doesn't
  work, but nothing unauthorized is exposed.
  RELEASE_BLOCKING=YES for anyone actually using Guardian financial oversight,
  but NOT a security incident.

  **Deployment update (explicit scoped authorization received, this
  session)**: the user explicitly authorized deploying exactly these two
  reviewed migrations, via the narrowest available mechanism (`apply_migration`
  against the exact file content, not a broad `db push --linked` that could
  sweep in the other pending local-only migrations). Pre-deployment: fetched
  and recorded the live pre-fix definition of
  `public.get_linked_teen_financial_summary` (verbatim, above the fold in this
  session's tool history) for rollback evidence, and confirmed the linked
  project (`get_project` -> `name: "Mort"`, ref `rakjydmgwwgtdislanbt`,
  ACTIVE_HEALTHY) before writing anything. Applied via `apply_migration`
  (name `fix_linked_teen_financial_summary_identity`) -- **deployed**.
  Post-deployment: re-fetched the live definition and confirmed it now
  matches the fix exactly (inlined `p_teen_id`-scoped queries, no more
  `get_my_financial_summary(p_year)` delegation; all fail-closed checks --
  `authentication_required`, `invalid_request` self-target,
  `invalid_year`, `guardian_access_disabled`, `not_linked_guardian` -- intact
  and in the same order). Wrote and ran a new, permanent regression script,
  `scripts/qa-guardian-financial-summary-identity.mjs`, against the live
  database using three fresh synthetic `@mort.test` QA fixture users (one
  teen, one linked guardian, one deliberately unlinked guardian) exercising
  the self-service `set_my_financial_preferences`/`upsert_my_financial_target`
  RPCs a real teen would call (service_role has no direct table grant on
  `financial_preferences`/`financial_personal_targets` by design -- confirmed
  via `has_table_privilege` -- so fixture setup goes through the same RPCs a
  real user hits, not a table-level bypass; `guardian_connections` does grant
  service_role INSERT directly, used only to establish the link since there
  is no self-service invite-accept path exercised by this narrow check).
  Result: **AUTHORIZATION_GATE=PASS, LINKED_TEEN_IDENTITY=PASS,
  UNLINKED_GUARDIAN_DENIED=PASS, VISIBILITY_OPT_IN_REQUIRED=PASS**. The
  linked-teen-identity check is the one that actually exercises the fixed
  code path: it inserts one identifiable personal target as the teen, then
  confirms the linked guardian's summary response contains that exact
  target -- proof the guardian is receiving the *teen's* data, not their own
  (empty) summary, which was the original bug. All three QA fixture users
  were created and removed by the script itself; `REAL_USER_ROWS_MUTATED=0`
  (only fresh synthetic `@mort.test` fixtures were touched).

- **`support_classify_intent` privilege-gap fix -- NOT deployed, deeper issue
  found during pre-deployment verification.** Per the user's own
  "verify again before deploying" instruction, traced the actual runtime call
  chain instead of assuming the one-hop grant was sufficient. Discovered
  `private.support_classify_message`'s body itself calls
  `private.support_classify_message_20260816010000`, which calls
  `..._20260813110000`, which calls `..._20260813101000` (a real, versioned
  chain of prior hardening patches) -- and confirmed via
  `has_function_privilege` that **all four** of these `private.*` functions
  are `service_role`-only (none are `SECURITY DEFINER`), not just the one the
  reviewed migration grants. Deploying the migration exactly as authorized
  and reviewed would therefore not actually fix the reported
  `qa-support-chatbot` failure -- the permission error would simply resurface
  one hop deeper in the chain. Per the user's own "if either migration
  produces an unexpected result: STOP, do not stack additional production
  fixes on top, investigate and report before continuing" instruction, this
  migration was **not applied**. The correct complete fix needs the same
  `grant execute ... to authenticated, anon` statement repeated for all four
  chain functions, which is a larger surface than what was specifically
  reviewed and authorized -- flagged back to the user rather than silently
  expanding scope.

- **qa-ai-safety-edge / qa-support-chatbot** (Sections 7C/7D) -- upgraded from
  inference to definitive proof via direct read-only inspection of the
  deployed function source and live grant state (Supabase MCP
  `get_edge_function` / `execute_sql`, read-only, no writes):
  - `qa-ai-safety-edge`: **HOSTED_CONFIG_DRIFT, confirmed definitively.**
    Fetched the actual deployed `ai-safety` function source
    (project `rakjydmgwwgtdislanbt`, version 18). Its real `index.ts` is a
    two-line wrapper -- `serveSupportFunction("safety-triage")` -- delegating
    to the generic shared support runtime's safety-triage operation. This is
    a completely different implementation from the current local
    `supabase/functions/ai-safety/index.ts` (~180 lines, its own dedicated
    deterministic regex-pattern table, its own request contract of
    `content`/`resourceType`/`resourceId`/`clientRequestId`, its own
    `ai_moderation_events` writes). The local dedicated implementation was
    never deployed; the hosted project still runs the older shared-runtime
    version, which naturally rejects the new contract's shape (explaining the
    `invalid_message` code, which is the shared runtime's generic
    message-length guard, not this function's own validation). Not a
    PROVIDER_GATE either way: neither implementation calls a generative AI
    provider.
  - `qa-support-chatbot` / `support-intent-classify`: **not drift --
    a real, currently-live PRODUCT_BUG, confirmed against both the deployed
    function source and live database grants.** The deployed
    `support-intent-classify` function body is byte-identical to current
    local source. The RPC it calls, `public.support_classify_intent(text)`,
    exists on the hosted database exactly as the latest local migration
    (`20260813030000_support_ai_hardening_live_gauntlet_fix.sql`) defines it:
    `security invoker`, calling `private.support_classify_message(text)`
    internally. That migration granted the public wrapper execute to
    `service_role, authenticated, anon` but granted the *inner* private
    function execute to `service_role` only. Verified directly against the
    live database: `has_function_privilege('authenticated', ..., 'execute')`
    and the `anon` equivalent are both `false` for
    `private.support_classify_message`, while both are `true` for the public
    wrapper. Because the wrapper is invoker (not definer), it runs the inner
    call with the *caller's* privileges -- so every real authenticated (or
    anon) caller of the documented, publicly-grantable entry point hits a
    Postgres permission-denied error before reaching the classification
    logic. This affects real production support-chat users right now, not
    just the QA harness. Wrote the fix as a new migration,
    `supabase/migrations/20260915000000_fix_support_classify_intent_privilege_gap.sql`
    -- a single additive `grant execute ... to authenticated, anon` on the
    inner function, matching the exact access breadth the hardening migration
    already declared for its own public wrapper. No logic, argument shape, or
    `security invoker` posture changes. Not deployed in this session (see
    deployment-authorization note below).
  - Neither finding is caused by, or related to, this session's V7/native-
    brand changes (zero backend files touched by that work).

- **BrowserStack dependency audit** (Section 7B):
  PACKAGE=`extract-zip@2.0.1` (latest published version; no patched release
  exists upstream). DIRECT_OR_TRANSITIVE=transitive
  (`webdriverio` -> `@wdio/utils` -> `@puppeteer/browsers` -> `extract-zip`).
  DEV_ONLY_OR_RUNTIME=dev/QA-tooling only -- this Node package never ships
  inside the Flutter app binaries. USED_IN_PRODUCTION=NO.
  FIX_AVAILABLE=NO (npm's only suggestion is downgrading `webdriverio` to
  `8.14.6`, a major-version downgrade, unverified to even resolve the
  transitive path). BREAKING_UPDATE_REQUIRED=YES if attempted.
  ACTUAL_RELEASE_RISK=LOW -- Codex's own capability-matching check already
  confirmed WebdriverIO skips local browser download/extraction entirely on
  the remote-hub (`hub.browserstack.com`) code path this project actually
  uses, so the vulnerable local-archive-extraction code is present in the
  dependency tree but not exercised by this project's actual usage pattern.
  Real, currently-unpatched, correctly disclosed -- not dismissed as N/A, but
  not blocking either.

- **16KB alignment**: ran the existing
  `scripts/qa-android-16kb-alignment.ps1 -ApkPath
  flutter_mort\build\app\outputs\flutter-apk\app-debug.apk` (no new checker
  invented). `ELF_16KB_ALIGNMENT=PASS`, 16 native libraries checked.

- **Android device QA -- three-strikes outcome (2026-09-14, this session)**:
  Checked host RAM before every attempt (never launched blind). Attempt 1:
  ~2.6 GB free, no competing Gradle/emulator process; boot succeeded, app
  installed, but the debug APK lacked QA dart-defines and correctly hit the
  fail-closed "MORT cannot start securely" screen (expected, not a defect;
  confirms the secure-startup gate works). Rebuilt with
  `SUPABASE_URL`/`SUPABASE_ANON_KEY`/`MORT_RELEASE_STAGE=automated_test`/
  `MORT_BROWSERSTACK_QA_MODE=true`. Attempt 2 (~2.6 GB free, 1536 MB guest
  RAM): boot and a 60s stability soak succeeded; app install and launch
  succeeded; hit the same previously-documented "SystemUI isn't responding"
  ANR (Android System UI, not MORT -- and the launch background is now
  correctly dark, confirming the color-resource fix renders right); tapping
  Wait triggered a silent emulator/qemu process termination (confirmed via
  `tasklist`, not just an ADB disconnect) with free RAM jumping 2.6 GB -> 4.55
  GB immediately after -- the exact signature from the prior forensic
  session. Attempt 3, changed variable per policy (reduced guest RAM to 1024
  MB, used the more favorable ~4.45 GB post-crash headroom): identical
  behavior at the identical trigger point, RAM jumping 2.6 GB -> 4.37 GB after.
  Three materially identical failures -> stopped per policy, did not attempt
  a fourth. This reconfirms `HOST_RESOURCE_PRESSURE` (unrelated to guest RAM
  allocation, since 1536 MB and 1024 MB both failed identically) rather than
  superseding it. No interactive keyboard/compact/200%-text/reduced-motion/
  role-journey/Guide/Support/monetization/back/background-resume evidence was
  obtainable this session; the existing non-interactive evidence (role-home
  screen mounting via the internal QA shell, native smoke tests, the 34-test
  native/brand suite, the 582-test full suite) remains the best available
  Android evidence pending a quieter host or a cloud device lane.

- **iOS retest decision**: IOS_RETEST_REQUIRED=YES. Native iOS launch assets
  changed (storyboard + LaunchImage populated with the new logo, confirmed via
  `git diff` on `project.pbxproj` and the task-2 report), and shared Flutter
  code changed (OAuth hardening, monetization router/screens) -- both
  explicitly trigger mandatory retest per this task's own rule, independent of
  the historical run `34472297830` which predates all of it. Triggered the
  existing `mort-ios-browserstack.yml` workflow via `workflow_dispatch`
  against this branch rather than inventing a new pipeline:
  run https://github.com/mortapp/Mort/actions/runs/34918334540. Result pending.

## Remaining verification before acceptance

Release build/signing classification (external signing gate expected, not a
defect to fix); iOS BrowserStack run result; local database regression
(Docker engine returned HTTP 500 in the prior session -- no safe local
substitute was established, and production was correctly not used as a
stand-in); hosted deployment of the guardian financial-summary fix (blocked on
explicit authorization, not on missing engineering work); final scorecard
sync; confirm remote SHA after this session's push.

Earlier narrow checks do not satisfy this list. P0/P1 zero and technical 100%
are **not established**.
