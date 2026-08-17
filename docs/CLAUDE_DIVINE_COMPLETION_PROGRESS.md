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

Extended RLS policy read (message_threads, conversation_participants,
support_conversations, support_messages, identity_verifications, incident_participants,
incident_evidence): all `{authenticated}`-only, correctly scoped
(owner/admin/thread-or-application-participant/production-reviewer/
can_manage_incident() gates). Two notable good patterns: `support_messages` explicitly
excludes `staff_visible_only` rows from the ticket owner's own SELECT (internal notes
don't leak to the user), and `incident_evidence` access grants are time-bounded
(`expires_at > now()`) and revocable (`revoked_at IS NULL`). No overbroad predicate
found across 13 sensitive tables sampled. This is a spot check, not exhaustive
coverage of all ~230 tables.

STATUS: BASELINE REGRESSION PHASE COMPLETE for what's achievable without a
service-role credential.

### PHASE: SUPPORT CLASSIFIER STRUCTURAL PASS
STATUS: COMPLETE (one safe fix applied; remaining cluster documented, not chased)
START_HEAD: 1fa648c1135268ef000610431b11517d1aab72e4
COMMIT: 19e9677

Generated a full per-case diagnostic (caseKey/expected/actual/message text) for all 85
failures to distinguish genuinely fixable classifier gaps from fixture-corpus
contradictions before touching any code. Finding: the large majority of the 85 are
NOT fixable by classifier logic changes -- they are near-paraphrase message pairs in
DIFFERENT fixture groups with OPPOSITE expected labels. Concrete example:
`guardian_mode_benign_01` ("How does Guardian Mode work?", currently PASSES at
level 1/account_access) vs. `holdout_benign_25_plus_27` ("What is Guardian Mode used
for?", expects level 0/general_support) -- semantically indistinguishable phrasing,
contradictory ground truth. No deterministic classifier (regex-based or otherwise)
can satisfy both without more context than the message text provides. This is the
same root cause the archived MORT_DIVINE_FULL_DAY_ENGINEERING_REPORT.md flagged ("85
... fixtures conflict with canonical mixed-domain/duplicate semantics"), now
independently reproduced and pinpointed to specific case pairs rather than just a
count. The entire `holdout_benign_25_plus` group (24 cases) is this same pattern:
every one of its "generic informational question" fixtures has a near-twin in an
older domain-specific group (`marketplace_*`, `account`, `billing`, etc.) expecting
the opposite level. Similarly `adversarial_credential_phrasing_07`,
`quoted_hostile_content_benign_*` (11 of 12), `benign_negation_and_context_benign_*`,
and `multi_turn_benign_followups_*` fall into overlapping intent/precedence
ambiguity that a keyword classifier cannot resolve without contradicting a passing
sibling case.

One case WAS a genuine, isolated, safely-fixable regex gap with no such collision:
`teen_account_access_benign_04` ("Why was I signed out automatically?") -- the
account-education pattern only recognized present-tense "sign-in"/"sign-out"/
"log-in"/"log-out" and "why do i"/"why is" prefixes, missing past tense ("signed",
"logged") and "why was". Fixed in the TS mirror (support_runtime.ts), verified with
zero regressions across all 543 fixtures (459/543, +1, no case flipped from correct
to incorrect), and mirrored in a new forward migration for the SQL production
classifier (20260817120000_support_ai_account_wording_coverage_fix.sql) using the
identical wrapper technique already live via 20260816010000.

MIGRATION NOT YET APPLIED: the `apply_migration` call was blocked by the harness's
own auto-mode permission classifier ("Blocked by classifier" -- DDL against the live
production database requires explicit user authorization beyond chat instructions,
independent of and in addition to what the user has authorized in conversation). Did
not attempt to route around this. The migration file is committed to the repo,
unapplied, so the fix isn't lost; the user needs to explicitly authorize the apply
step (e.g. by approving the specific Bash/MCP permission, or applying it themselves).

`teen_account_access_benign_11` ("Can I change my username from the account page?")
was investigated and NOT fixed: "username" is bucketed into a separate
`profileGeneralSupport` branch (checked earlier in precedence, shared with a PASSING
sibling group `profile_reviews_benign` that wants bare "username" mentions to stay at
level 0). Disambiguating "username" in an account-page context from "username" in a
generic profile context would need either new precedence logic (regression risk
against `profile_reviews_benign`) or genuinely more context than keyword matching
provides. Documented, not chased, per the "don't regex-whack-a-mole" instruction.

CASE_ID / CURRENT_LAYER / CORRECT_LAYER / REASON / PERMANENT_COVERAGE for the
remaining 84 failures: CURRENT_LAYER = deterministic keyword classifier (this layer).
CORRECT_LAYER = not resolvable at this layer; would need either (a) a product/fixture
decision reconciling the two contradictory design philosophies encoded in the corpus
(domain-keyword-presence implies level 1, vs. generic-informational-phrasing implies
level 0 regardless of domain words), or (b) a semantic/contextual classifier (LLM-
based, not deterministic keyword matching) that can distinguish "How does Guardian
Mode work?" from "What is Guardian Mode used for?" by intent rather than surface
form. PERMANENT_COVERAGE: preserved as-is; no fixture deleted, no expected label
changed, no severity reduced. Full per-case detail (caseKey/expected/actual/message)
is at the session scratchpad `failures_detail.tsv` if needed for a dedicated
follow-up session -- not duplicated into this doc to keep it from becoming another
stale wall of adversarial-adjacent fixture text.

### PHASE: EXTENDED STATIC RLS/STORAGE AUDIT
STATUS: COMPLETE for the categories the directive named
START_HEAD: 3241c3e

Checked pg_policies for applications, job_contracts, reports, blocks, reviews,
account_deletion_requests, notifications, admin_role_assignments,
team_role_assignments, moderation_events, partner_staff (11 more tables, ~25 total
across both sessions of this audit). All `{authenticated}`-only, correctly scoped
(participant/owner/admin/role-gated), no `using (true)`. Notable good pattern:
`reviews` implements a proper blind-reveal mechanism (own review always visible;
others only after moderation approval AND a reveal delay/mutual-submission
condition), preventing retaliatory review inspection.

Storage: all 9 buckets (identity-evidence, incident-evidence, mort-document-vault,
profile-avatars, proof-uploads, report-uploads, support-attachments,
support-evidence, verification-uploads) are `public = false`. Read every
storage.objects policy: consistent first-path-segment ownership scoping
(`storage.foldername(name)[1] = auth.uid()`), UUID-pattern filename enforcement,
explicit path-traversal guard (`name !~ '(^|/)\.\.(/|$)'`) on incident-evidence
uploads, file-extension allowlisting, and the same time-bounded/revocable
access-grant pattern from the table layer reused at the storage layer too (defense
in depth). Zero anon/public storage policies found. identity-evidence has no direct
client INSERT policy at all -- uploads for that bucket are server-mediated only,
which is the correct pattern for that sensitivity level, not a gap.

FINDING: zero P0/P1 RLS or storage issues across this static review (~25 of ~230
tables sampled, weighted toward the highest-risk categories named in the directive;
not exhaustive coverage of all 230).

Migration ledger recheck: local now has ONE migration ahead of remote
(20260817120000, drafted but not yet applied per the blocker above) -- this is
expected/healthy "pending local work" state, not drift. Remote's last applied
version remains 20260816010000, confirmed via list_migrations earlier this session.

### PHASE: JOB/APPLICATION/PIN LIFECYCLE CODE REVIEW
STATUS: COMPLETE, clean
Reviewed 20260722202206_mort_0_9_3_job_execution_pins.sql (core PIN/execution state
machine) and 20260730050000_job_pin_confirmation_idempotency.sql (v2 hardening).
Findings, all positive:
- PINs: cryptographically random, bcrypt-hashed at rest (never plaintext in tables
  or event logs), 10-min TTL, 5-attempt lockout with 30-min lock, single-use
  (`*_pin_used_at`), rate-limited regeneration (60s cooldown).
- Idempotency: every mutating RPC takes a `client_request_id`; v1 already replayed
  stored responses for repeated requests, but v2
  (confirm_job_start_pin_v2/confirm_job_finish_pin_v2) closes a genuine TOCTOU race
  in v1 (two near-simultaneous double-taps could both pass the "not yet recorded"
  check before either inserted) via `pg_advisory_xact_lock` on
  hash(actor_id, client_request_id), plus a dedicated idempotency ledger that stores
  a bcrypt fingerprint of the submitted PIN so a reused request-id can't be replayed
  with a *different* PIN (returns `pin_request_payload_mismatch` instead).
- v1 functions (confirm_job_start_pin, confirm_job_finish_pin,
  generate_job_arrival_code, confirm_job_arrival_code) had client-facing grants
  revoked in the v2 migration -- only the hardened v2 path is reachable from
  authenticated/anon. Confirmed the Flutter client
  (job_execution_repository.dart, trust_safety_repository.dart) actually calls
  confirm_job_start_pin_v2/confirm_job_finish_pin_v2, not the deprecated names --
  the hardening is live, not dead code.
- Concurrency: `SELECT ... FOR UPDATE` row locks on job_arrival_handshakes and
  job_contracts throughout, preventing races between concurrent start/finish
  operations on the same application.
- PINs are cryptographically bound to a specific `contract_version_id` at
  generation; if the contract changes before confirmation, the PIN is invalidated
  ("contract_changed_reconfirmation_required") rather than silently confirming
  stale terms.
- Safety precedence: submit_teen_abandonment explicitly rejects
  `safety_related = true` submissions and redirects to `/safety` rather than
  processing them as a routine abandonment.
- Every state-changing response explicitly returns `money_moved: false` --
  consistent with the fail-closed payment posture.
- Minor/immaterial: 6-digit PIN generation uses `% 1000000` on a 32-bit random
  value, which has a statistically negligible modulo bias (~2e-5% per bucket).
  Not flagged as a fix given the entropy space plus attempt-lockout design; would
  be over-engineering a non-issue.
No P0/P1 findings.

NEXT_AUTOMATIC_PHASE: Location privacy verification (server-side exact-vs-general
enforcement: distance/feed RPCs must never return raw Teen coordinates to
unrelated parties), then begin scoped UI/onboarding implementation work.

## EXTERNAL_GATES (unchanged, not evaluated this session)

- Google Play production eligibility / review
- Apple/Xcode, TestFlight, App Store (Windows environment cannot verify)
- Legal/privacy approval
- Payment/payout/identity-verification providers
- External AI provider enablement (Support fallback remains deterministic/disabled per
  prior reports — not reverified this session)
