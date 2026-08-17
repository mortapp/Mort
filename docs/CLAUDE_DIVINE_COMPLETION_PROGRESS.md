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

SQL/TS parity result: BLOCKED, not failed. Attempted the read-only batched query
(150 safety-critical cases: emergency/trust_safety/adversarial/prompt+secret
extraction/sensitive_data_disclosure/urgent_mixed_intent) via Supabase MCP
`execute_sql` against `private.support_classify_message` directly -> permission
denied. Retried against the documented service-role wrapper
`public.support_classify_message_internal` -> also permission denied. Root cause:
the MCP connection authenticates as `supabase_read_only_user` (confirmed via
`select current_user`), a Postgres role with no `request.jwt.claims`/role GUC set,
and the function is deliberately `revoke all ... grant execute ... to service_role`
plus an internal `auth.role() <> 'service_role'` gate. This is the hardening working
as intended -- the classifier cannot be invoked by a low-privilege or credential-less
connection, including this one. NOT circumvented (no role/privilege escalation
attempted). Full SQL/TS parity re-verification requires either the service-role JWT
or the raw `SUPABASE_DB_PASSWORD` that `scripts/qa-support-sql-ts-parity.mjs` wants --
neither is available to this session and neither should be requested over chat.
Recorded as a credential gate, not a code defect.

RLS spot check (read-only, via the same restricted MCP role -- a reasonable stand-in
for "anonymous/no-JWT caller" since it has no auth context):
- `list_tables` confirms `rls_enabled = true` on all ~230 public tables. No table found
  with RLS disabled.
- Read actual `pg_policies` predicates (not just the enabled flag) for profiles,
  teen_profiles, guardian_connections, messages, safety_pings: all policies scope to
  `{authenticated}` only (no `anon`/`public` grants seen), predicates are
  self/admin/connected-guardian/thread-participant/job-poster scoped, using
  `auth.uid()` correctly and helper functions like `is_minor_teen()`,
  `guardian_is_connected_to_teen()`, `is_thread_participant()`. No `using (true)` or
  similarly overbroad predicate found in this sample.
- `job_private_locations` (exact job coordinates) has RLS enabled with ZERO table
  policies -- meaning no direct SELECT/INSERT/UPDATE/DELETE is possible for
  `authenticated` or `anon` at all; access must go through SECURITY DEFINER RPCs with
  their own authorization. This is the correct, maximally-restrictive shape for
  "exact internally, private externally" location data.
- NOT DONE: genuine cross-user impersonation testing (Teen A querying as Teen A vs.
  Teen B's data) -- requires creating and authenticating as two real test users, which
  needs the service-role admin API (the same credential gap as above). This is what
  the repo's own `scripts/feature-qa-helpers.mjs` `withQaUsers` helper is for, and it
  also requires `SUPABASE_SERVICE_ROLE_KEY`.

BLOCKERS:
- SQL/TS classifier parity and true cross-user RLS impersonation both require a
  service-role credential (JWT or DB password) not present in this session. Not a
  code defect; recorded as CREDENTIAL_GATE, not a blocker on other work.

NEXT_AUTOMATIC_PHASE: Continue engineering-controlled work not gated by that
credential -- candidates: static/manual review of RLS policies on remaining sensitive
tables (message_threads, conversation_participants, support_conversations,
support_messages, identity_verifications, incident_* tables), then move toward
UI/onboarding work or surface this status to the user given the scope of remaining
directive items (full redesign, website, iOS catch-up, physical Android QA, release
artifacts) each warrant their own dedicated pass.

## EXTERNAL_GATES (unchanged, not evaluated this session)

- Google Play production eligibility / review
- Apple/Xcode, TestFlight, App Store (Windows environment cannot verify)
- Legal/privacy approval
- Payment/payout/identity-verification providers
- External AI provider enablement (Support fallback remains deterministic/disabled per
  prior reports — not reverified this session)
