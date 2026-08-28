# Four-Step Production Onboarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship exactly four server-authoritative onboarding screens whose resume and completion state is derived from canonical Supabase data.

**Architecture:** Add compatibility-safe v2 RPCs that project canonical profile, Guardian, legal-acceptance, and completion data without mutating the legacy checkpoint model. Refactor Flutter to render the v2 server projection, persist each role-specific step through caller-bound RPCs, and keep Expo reference-only for production.

**Tech Stack:** PostgreSQL/Supabase migrations and RLS, Node.js hosted/local QA scripts, Flutter/Dart/Riverpod, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-08-27-four-step-onboarding-design.md`

## Global Constraints

- Primary user-facing steps are exactly `account`, `work_preferences`, `safety_support`, and `review`; `complete` is terminal only.
- Completion and resume are derived from canonical server data, never client markers.
- Hosted Supabase is never reset and migration history is never rewritten.
- Legacy RPCs and state remain available during Release N.
- DOB and role remain server-immutable after their first valid save.
- Notification intent is distinct from native OS permission and permission is not a completion prerequisite.
- Existing published legal document/version/acceptance architecture remains authoritative.
- Safety, reporting, blocking, Safety Ping, and basic Guardian support remain free.
- No onboarding paywall, production publication, real-money purchase, or Play Console mutation.

---

### Task 1: Add an executable v2 backend contract test

**Files:**
- Create: `scripts/qa-four-step-onboarding-v2.mjs`
- Modify: `package.json`

**Interfaces:**
- Consumes: existing QA helpers in `scripts/feature-qa-helpers.mjs`
- Produces: `pnpm qa:onboarding-v2`, an end-to-end hostile-client contract for the four-step RPC surface

- [ ] **Step 1: Write the failing QA test**

Create fixtures for teen, adult, and guardian users and call `get_my_onboarding_progress_v2()`. Assert the literal states `account`, `work_preferences`, `safety_support`, `review`, and terminal `complete`. Add direct `profiles.onboarding_completed=true` UPDATE/UPSERT denials, missing canonical data, same-request replay, mismatched payload replay, cross-user request-ID isolation, stale revision, and concurrent double-Finish cases.

```js
const initial = assertRpc(await teen.client.rpc('get_my_onboarding_progress_v2'));
assertQa(initial.active_step === 'account', 'new account must resume at account');

const missingWork = await teen.client.rpc('complete_my_onboarding_v2', {
  p_payload: completionPayload,
  p_client_request_id: randomUUID(),
  p_payload_version: 1,
});
assertCode(missingWork, 'onboarding_work_preferences_required');
```

- [ ] **Step 2: Register and run the test to verify RED**

Add `"qa:onboarding-v2": "node scripts/qa-four-step-onboarding-v2.mjs"` to `package.json`, then run `pnpm qa:onboarding-v2` against the configured development QA environment. Expected: failure because `get_my_onboarding_progress_v2` does not exist.

- [ ] **Step 3: Commit the failing contract test**

```powershell
git add package.json scripts/qa-four-step-onboarding-v2.mjs
git commit -m "test(onboarding): define four-step server contract"
```

### Task 2: Implement the compatibility-safe server projection and writes

**Files:**
- Create via `supabase migration new four_step_onboarding_v2`: the exact CLI-generated `supabase/migrations/*_four_step_onboarding_v2.sql`
- Test: `scripts/qa-four-step-onboarding-v2.mjs`
- Test: `scripts/qa-resumable-onboarding.mjs`
- Test: `scripts/qa-orphaned-onboarding-progress.mjs`

**Interfaces:**
- Produces: `get_my_onboarding_progress_v2()`, `save_my_onboarding_account_v2(jsonb,uuid,integer)`, `save_my_onboarding_work_v2(jsonb,uuid,integer,text)`, `save_my_onboarding_safety_v2(jsonb,uuid,integer,text)`, and `complete_my_onboarding_v2(jsonb,uuid,integer,text)`
- Preserves: all legacy onboarding RPC signatures and state

- [ ] **Step 1: Create the forward-only migration with the CLI**

Run `pnpm exec supabase --version`, `pnpm exec supabase migration new four_step_onboarding_v2`, and record the generated path in the task checklist before editing it.

- [ ] **Step 2: Add the private request ledger and canonical evaluator**

Create `private.onboarding_v2_requests` keyed by `(user_id, operation, client_request_id)` with `step`, `payload_version`, `payload_hash`, `response`, and timestamps. Revoke direct access. Add `private.evaluate_onboarding_v2(uuid)` that validates canonical profile fields, role-specific teen work fields, Guardian state, current published legal acceptances, and `onboarding_completed`, returning the literal v2 projection.

```sql
create table private.onboarding_v2_requests (
  user_id uuid not null references auth.users(id) on delete cascade,
  operation text not null,
  client_request_id uuid not null,
  step text not null check (step in ('account','work_preferences','safety_support','review')),
  payload_version integer not null check (payload_version = 1),
  payload_hash text not null check (payload_hash ~ '^[0-9a-f]{64}$'),
  response jsonb,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  primary key (user_id, operation, client_request_id)
);
```

- [ ] **Step 3: Reuse the canonical profile and transportation write paths**

Have the account wrapper call `save_my_profile_setup_v2()` with existing work values merged from the locked profile so account edits cannot erase later data. Have the teen work wrapper use the existing profile update and `save_my_transportation_preferences()` validation/write logic in one transaction boundary. Adult and Guardian work wrappers record no invented fields and derive completion from their canonical role/account state.

- [ ] **Step 4: Implement safety intent and legal-version completion**

Store notification preference intent without any OS-granted claim. Reuse existing Guardian skip/invite status and `get_my_legal_requirements`/`submit_legal_acceptance` semantics. `complete_my_onboarding_v2()` locks the profile, reruns `private.evaluate_onboarding_v2`, requires active current legal versions, sets `mort.onboarding_completion` transaction-locally, and updates the profile once.

- [ ] **Step 5: Lock down public wrappers**

For every `security definer` function: `set search_path = ''`, check `auth.uid()`, allowlist payload keys, revoke `PUBLIC` and `anon`, then grant only `authenticated` and `service_role`. Preserve the existing completion trigger unchanged unless a failing hostile-client test proves a necessary hardening correction.

- [ ] **Step 6: Apply locally and verify GREEN**

Use the local Supabase workflow documented by `pnpm exec supabase --help`; apply migrations to local development only, then run `pnpm qa:onboarding-v2`, `pnpm qa:rls`, `node scripts/qa-resumable-onboarding.mjs`, and `node scripts/qa-orphaned-onboarding-progress.mjs`. Expected: v2 and legacy suites pass with no hosted reset.

- [ ] **Step 7: Commit the backend milestone**

```powershell
git add supabase/migrations scripts/qa-four-step-onboarding-v2.mjs package.json
git diff --cached --check
git commit -m "feat(onboarding): add server-derived four-step contract"
```

### Task 3: Model and repository v2 contract in Flutter

**Files:**
- Modify: `flutter_mort/lib/data/models/onboarding_progress.dart`
- Modify: `flutter_mort/lib/data/repositories/profile_repository.dart`
- Create: `flutter_mort/test/onboarding_v2_repository_test.dart`

**Interfaces:**
- Produces: `OnboardingStepV2`, `OnboardingProgressV2`, and repository methods matching the five v2 RPCs
- Consumes: literal server projection fields from Task 2

- [ ] **Step 1: Write failing model/repository tests**

Assert exact parsing of `completed`, `active_step`, `completed_steps`, `missing_requirements`, `role`, and revision; assert request payloads include stable request ID/version/revision and map coded field errors without exposing raw snake_case.

```dart
expect(progress.activeStep, OnboardingStepV2.workPreferences);
expect(progress.completedSteps, const [OnboardingStepV2.account]);
expect(progress.missingRequirements, const ['preferred_job_categories']);
```

- [ ] **Step 2: Run RED**

Run `flutter test test/onboarding_v2_repository_test.dart`. Expected: compile failure because v2 types/methods do not exist.

- [ ] **Step 3: Implement minimal v2 model and repository methods**

Keep legacy methods for compatibility tests, but make new onboarding consumers call only v2 methods. Preserve stable request IDs across retry and send the last server revision for mutable saves.

- [ ] **Step 4: Run GREEN and commit**

Run the focused test and `dart format` on changed Dart files, then commit as `feat(onboarding): add Flutter v2 server contract`.

### Task 4: Rebuild Flutter onboarding as exactly four screens

**Files:**
- Modify: `flutter_mort/lib/features/onboarding/compact_onboarding.dart`
- Create: `flutter_mort/lib/features/onboarding/onboarding_draft.dart`
- Create: `flutter_mort/lib/features/onboarding/onboarding_step_widgets.dart`
- Modify: `flutter_mort/test/compact_onboarding_test.dart`
- Modify: `flutter_mort/test/onboarding_persistence_test.dart`

**Interfaces:**
- Consumes: `OnboardingProgressV2` and repository v2 methods
- Produces: four role-aware screens and terminal navigation

- [ ] **Step 1: Rewrite widget tests first**

Replace five-step expectations with literal `Step 1 of 4` through `Step 4 of 4`. Add teen, adult, and guardian Step 2 assertions; DOB/role confirmation; server-progress resume; stale-session reload; optional guardian skip; one Finish CTA; Terms/Privacy/Safety return-to-review behavior; and double-Finish idempotency.

- [ ] **Step 2: Run focused tests to verify RED**

Run `flutter test test/compact_onboarding_test.dart test/onboarding_persistence_test.dart`. Expected: failures on five-step UI and legacy repository calls.

- [ ] **Step 3: Implement account and work screens**

Create the four-step coordinator and draft. Account confirms immutable DOB/role before save and uses Unicode-aware display-name validation messaging. Teen work persists categories, availability, and transportation. Adult/Guardian work screens remain concise and create no fake fields.

- [ ] **Step 4: Implement safety/support and review screens**

Persist notification intent only, resolve actual notification state from `NativePermissionsService`, keep accessibility optional, show free safety controls, use existing published legal requirements, distinguish job payments from Google Play digital purchases, and keep document links inside the fourth primary step.

- [ ] **Step 5: Reconcile after every save**

After each successful mutation call `getOnboardingProgressV2()`, accept server advancement, reject stale revisions with reload UX, and never derive completed steps from local controllers.

- [ ] **Step 6: Run GREEN and commit**

Run focused tests, format changed Dart files, run `flutter analyze`, and commit as `feat(onboarding): ship four-step production flow`.

### Task 5: Add shipping-copy and native-permission regressions

**Files:**
- Create: `flutter_mort/test/onboarding_production_copy_test.dart`
- Modify: `flutter_mort/test/compact_onboarding_test.dart`
- Modify: `flutter_mort/lib/services/native_permissions_service.dart` only if the failing behavior test requires a pure status mapper

**Interfaces:**
- Produces: behavior tests for user-facing notification labels and production onboarding copy

- [ ] **Step 1: Write failing behavior tests**

Pump real onboarding/status widgets for each server fixture and verify they render friendly labels, never the prohibited internal phrases or raw statuses. Test native notification states map to Enabled, Not enabled yet, Denied, and Needs Settings without server preference changing the OS result.

- [ ] **Step 2: Run RED, implement the minimal copy/status mapping, and run GREEN**

Run `flutter test test/onboarding_production_copy_test.dart test/compact_onboarding_test.dart`, change only user-facing copy/status mapping needed by failures, then rerun.

- [ ] **Step 3: Commit**

Commit as `fix(onboarding): remove internal copy and report permission truth`.

### Task 6: Neutralize the legacy Expo production path

**Files:**
- Modify: `app/onboarding.tsx`
- Modify: `app.config.ts`
- Modify: `.env.example`
- Create: `scripts/qa-production-client-contract.mjs`
- Modify: `package.json`
- Create: `docs/CURRENT_BUILD_STATUS.md`

**Interfaces:**
- Produces: an executable build contract proving Flutter is production and Expo cannot complete production onboarding

- [ ] **Step 1: Write the failing client-contract test**

Execute configuration for a production profile and assert the release client is Flutter and Expo production backend targeting is rejected. Exercise the Expo onboarding submit boundary and assert it cannot direct-upsert completion.

- [ ] **Step 2: Run RED**

Run `node scripts/qa-production-client-contract.mjs`. Expected: failure because Expo currently has no production-reference guard and still calls the direct upsert helper.

- [ ] **Step 3: Implement the reference-only guard**

Remove direct completion from the Expo route. In non-production reference mode, show a clear unsupported/reference state; in any attempted production Expo configuration, fail the build/config validation. Document Flutter as the supported production artifact.

- [ ] **Step 4: Run GREEN and commit**

Run the client contract, `pnpm check`, and relevant Expo smoke/export checks, then commit as `fix(onboarding): disable legacy Expo production completion`.

### Task 7: Full Stage 1 verification and recovery documentation

**Files:**
- Create: `docs/PRODUCTION_ONBOARDING_FINAL.md`
- Create: `docs/TEST_MATRIX.md`
- Create: `docs/KNOWN_ISSUES.md`
- Create: `docs/CURRENT_BUILD_STATUS.md`

**Interfaces:**
- Produces: evidence-backed Stage 1 status with external/device items clearly separated

- [ ] **Step 1: Run source verification**

Run Dart formatting check, focused onboarding tests, full `flutter test`, `flutter analyze`, `pnpm check`, production-client contract, `git diff --check`, and the repository secret scan.

- [ ] **Step 2: Run backend verification**

Run v2 onboarding QA, legacy onboarding QA, orphan repair, RLS, hostile-client, and migration-parity checks against the legitimate configured development environment. Run Supabase advisors where available and record exact failures rather than bypassing them.

- [ ] **Step 3: Build the QA APK**

Build a fresh QA APK using the repository's canonical Flutter Android build script, calculate SHA-256, and record its exact path/hash. Do not publish it.

- [ ] **Step 4: Run physical QA only if the Galaxy A14 is available**

Install the exact APK via existing wireless ADB configuration and test the four steps, bad/good names, teen DOB, roles, work fields, guardian skip, permissions, review, finish, 100%/150%, dark/light/system, Back, restart/resume, and logcat. Never confirm a real-money purchase. If unavailable, record the physical items as not executed.

- [ ] **Step 5: Update docs, verify, commit, and push**

Write only evidence observed in this run, run `git diff --check` and secret sanity, commit as `docs: certify four-step onboarding stage`, then push the current feature branch without force.
