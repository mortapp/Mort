# MORT Claude Divine Completion Progress

This is the current, canonical progress document for the ongoing autonomous
engineering effort on MORT. Older session reports are historical evidence
only — see `docs/archive/ai-runs/`. Do not treat their pass/fail claims as
current; only this file and fresh tool output reflect present state.

START_TIME: 2026-08-17T00:00:00-04:00 (session start, wall-clock approximate)
REPOSITORY: C:\Users\micha\Mort
BRANCH: feature/compact-onboarding-and-screen-polish
LAST_KNOWN_GOOD_COMMIT: f69914d341fd2139a4878cc949004c20da8f7e60
SUPABASE_PROJECT_REF: rakjydmgwwgtdislanbt
CURRENT_APP_VERSION: 0.9.15+106
WORKING_TREE_STATUS: CLEAN (verified via `git status --short` immediately before this update)

## CURRENT_PHASE

Baseline regression — IN PROGRESS.

Completed so far this phase:
- `flutter test` (full suite): 379 passed, 0 failed, 2 skipped. Fresh run against f69914d.
- `flutter analyze --no-pub`: No issues found.
- `dart format --set-exit-if-changed`: clean (the one violation found during cleanup was
  already fixed and committed in an earlier checkpoint).
- Support classifier regression via `scripts/qa-support-classifier.mjs` (local, offline,
  no network calls — imports `localClassification` from support_runtime.ts directly):
  TOTAL 543, PASSED 458, FAILED 85. Matches the historical high-water mark exactly, now
  independently reverified against current HEAD rather than trusted from an old report.
  Reviewed the direction of every failure: none under-classify a genuinely dangerous
  message to a lower safety level. All 85 are benign-vs-benign intent-routing confusion
  (e.g. "account_access" expected vs. "jobs_or_applications" actual) or safe-direction
  over-escalation. Largest cluster (24/85) is the `holdout_benign_25_plus` fixture group:
  benign questions that deliberately contain job/payment/guardian/PIN/privacy/safety
  keywords with no actual action request, testing that the classifier doesn't over-route
  on keyword presence alone. Root-caused to imprecise domain/action keyword heuristics.
  NOT hand-tuned this session: fixing 85 cases risks regressing the 458 that already pass,
  and this exact gap already consumed multiple prior sessions going 402->458; needs a
  dedicated, carefully-regressed pass, not a rushed one.

IMPORTANT CORRECTION vs. earlier assumption this session: `scripts/qa-support-classifier.mjs`
only exercises `localClassification`, the TypeScript mirror. Per support_runtime.ts:696-721,
that is NOT the primary production path -- the actual authority for live user-message
routing is the Postgres function `private.support_classify_message`, called via the
`support_classify_message_internal` RPC from `classifyForEvaluation`. `localClassification`
is only (a) a fallback if that RPC is unreachable, and (b) a second-pass scan of the AI
provider's own output for jailbreak leakage (`securityBoundaryClassification`). So the
458/543 number characterizes the fallback/output-scan path, not necessarily the real
production decision path.

IN PROGRESS: freshly verifying SQL/TS parity (whether `private.support_classify_message`
agrees with `localClassification` on all 543 cases, as migration 20260816010000 claimed to
fix) via a read-only batched query through the Supabase MCP `execute_sql` tool -- chosen
over the repo's own `scripts/qa-support-sql-ts-parity.mjs`, which requires a raw
`SUPABASE_DB_PASSWORD` superuser credential this session does not have and should not
acquire. Query is built (all 543 messages base64-encoded to avoid both SQL-escaping issues
and printing raw adversarial fixture text), calls only the `stable`/read-only classify
function, and is saved at
`.../scratchpad/parity_query.sql` (session-local temp path, not in the repo). Not yet
executed against the live project.

NOT YET DONE this phase: RLS/storage isolation spot checks, hosted Support gauntlet,
SQL/TS parity result, migration ledger re-diff after the new commits.

## PHASE LOG

### PHASE: REPOSITORY CLEANUP AND RECOVERY
STATUS: COMPLETE
START_HEAD: bf0f07c3fe5bccf972fb82f8abd56d4ff7908373

Findings:
- Working tree had ~58 modified tracked files and ~65 untracked paths, none committed since bf0f07c.
- CRITICAL: 15 Supabase migrations (20260811090000 through 20260816010000, Support AI
  hardening) were already applied live on the rakjydmgwwgtdislanbt project (verified via
  Supabase MCP `list_migrations` against the actual remote ledger) but had never been
  committed to git. This was the primary risk — production schema/policy history was
  unrecoverable from source control. Resolved by committing the files verbatim (no edits,
  per migration-immutability rule).
- Remaining dirty tree was real work, not debris: Support AI classifier runtime/eval-cases
  and ~24 QA/regression scripts, Flutter UI/onboarding/screen-polish fixes across ~30
  screens/services plus matching tests, and iOS/Android platform config + release-QA
  script updates (version already at 0.9.15+106, not bumped by this session).
- Actual debris (confirmed disposable, moved to session scratchpad, not deleted): stale
  `.tmp_eval_support.*` / `.tmp_grouped_failures.*` / `.tmp_single_check.ts` scratch
  scripts and outputs (dated 2026-08-13), two empty stray files (`=`, `root.attrib.get`
  — shell-redirect accidents), an unused empty `versionCode` file, and a stale
  `expanded-test-results.json` eval snapshot.
- Secret scan (categories: Supabase secret keys, JWTs, Google/generic API keys, private
  keys, GitHub/Slack tokens, hardcoded passwords) across all modified/untracked content:
  clean. Only benign matches were the literal Postgres role name `service_role` inside
  RLS grant/policy SQL and role checks — not key material.
- 8 prior-session report docs (PHASE_4_COMPLETION_REPORT.md,
  SECURITY_VERIFICATION_REPORT_20260812.md, ANTIGRAVITY_OVERNIGHT_PROGRESS.md,
  CODEX_DIVINE_FULL_DAY_PROGRESS.md, MORT_DIVINE_FULL_DAY_ENGINEERING_REPORT.md,
  session-2026-08-12/*.md) archived to `docs/archive/ai-runs/` — kept as historical
  evidence, not deleted, not treated as current-state truth.

Commits created (in order):
1. `4bbe16a` chore(supabase): commit production-applied Support AI hardening migrations
2. `69cad15` feat(support): commit Support AI classifier hardening and QA tooling
3. `9af1f92` fix(ui): polish onboarding, jobs, support, and profile screens
4. `8d2c9b5` chore(release): update iOS platform config and Android release QA scripts

Verification run during cleanup:
- `git diff --check` on every staged group: no conflict markers or corruption (only
  pre-existing CRLF/LF line-ending warnings and cosmetic trailing whitespace inside the
  immutable migrations, left untouched).
- `dart format --set-exit-if-changed lib test`: 1 file needed formatting
  (support_assistant_repository.dart, missing trailing newline) — fixed and re-verified.
- `flutter analyze --no-pub`: No issues found (301.5s).
- Full Flutter test suite, Support classifier regression, and RLS/security probes: NOT
  YET RE-RUN against this checkpoint. Historical pass/fail numbers in the archived
  reports are orientation only, not current evidence.

BLOCKERS: None.
NEXT_AUTOMATIC_PHASE: (superseded by the BASELINE REGRESSION phase log below — this line
kept for history.)

### PHASE: BASELINE REGRESSION
STATUS: IN_PROGRESS
START_HEAD: f69914d341fd2139a4878cc949004c20da8f7e60

See CURRENT_PHASE section above for full detail. Summary:
- Flutter test/analyze/format: PASS, freshly verified.
- Support classifier (TS fallback path): 458/543, freshly verified, no safety-direction
  failures, root cause documented, intentionally not hand-tuned this pass.
- Support classifier (SQL production path) parity: query built, not yet executed.
- RLS/storage isolation, hosted gauntlet: not yet started.

BLOCKERS: None.
NEXT_AUTOMATIC_PHASE: Execute the SQL/TS parity query via Supabase MCP `execute_sql`
(read-only, `stable` function, safe to run), record TOTAL/PARITY_PASSED/PARITY_FAILED/
SQL_EXPECTED_PASSED/SQL_EXPECTED_FAILED, then move to RLS/storage isolation spot checks
(Teen/Adult/Guardian/staff/anonymous cross-user access probes) before returning to any
UI/redesign work.

## EXTERNAL_GATES (unchanged, not evaluated this session)

- Google Play production eligibility / review
- Apple/Xcode, TestFlight, App Store (Windows environment cannot verify)
- Legal/privacy approval
- Payment/payout/identity-verification providers
- External AI provider enablement (Support fallback remains deterministic/disabled per
  prior reports — not reverified this session)
