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

## Remaining verification before acceptance

Android debug build;
release build/signing classification; candidate 16KB inspection; current device
matrix/session/screenshots; local database regression and deployment
reconciliation; dependency gate; final independent review; scorecard/ledger
update; normal integration push and exact remote SHA verification.

Earlier narrow checks do not satisfy this list. P0/P1 zero and technical 100%
are **not established**.
