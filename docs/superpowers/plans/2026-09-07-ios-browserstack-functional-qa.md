# iOS BrowserStack Functional QA Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a reproducible, local-data-only iOS BrowserStack functional smoke suite that exercises critical MORT screens on real iPhones without using accounts, providers, money, or device-permission mutations.

**Architecture:** A compile-time `MORT_BROWSERSTACK_QA_MODE` flag is accepted only by the `automated_test` / `internal_test` build profile. In that mode bootstrap runs a dedicated `BrowserStackQaApp`, whose nested Riverpod scope supplies deterministic fake repositories and whose small router mounts the real onboarding, safety, financial, settings, legal, and permission widgets. WebdriverIO drives the harness with accessible landmarks and records evidence for deep, limited, and floor device profiles.

**Tech Stack:** Flutter/Dart 3.11, Riverpod 3, GoRouter 17, GitHub Actions, BrowserStack App Automate, Node 22, WebdriverIO 9.31.6.

**Spec:** `docs/superpowers/specs/2026-09-07-ios-browserstack-functional-qa-design.md`

## Global Constraints

* `MORT_BROWSERSTACK_QA_MODE` is valid only with `MORT_RELEASE_PROFILE=automated_test` and `MORT_RELEASE_STAGE=internal_test`.
* QA mode must have all networked providers, marketplace, payments, remote push, crash reporting, ads, IAP, and reviewer mode disabled.
* QA fixture repositories return fixed local data and throw `StateError('BrowserStack QA mode does not permit mutations.')` for every mutator.
* The application must never issue a real permission request, create a report or Safety Ping, open a dialer, create financial data, export files, or contact a hosted backend in this mode.
* Prefer visible accessible names; use stable semantic identifiers only on the QA-shell landmarks and route controls.
* Use `npm ci` in CI; do not use `npm install --no-save`, `npm audit fix`, or `--force`.
* Keep PR #8 open and do not change main, PR #4, `feature/compact-onboarding-and-screen-polish`, or the untracked `work/` directory.

---

### Task 1: Make the QA build mode explicit and fail closed

**Files:**
- Modify: `flutter_mort/lib/core/config/app_config.dart`
- Modify: `flutter_mort/lib/core/config/release_profile.dart`
- Modify: `flutter_mort/lib/main.dart`
- Modify: `flutter_mort/test/release_profile_test.dart`
- Test: `flutter_mort/test/browserstack_qa_mode_test.dart`

**Interfaces:**
- Produces `AppConfig.browserStackQaMode` and `MortReleaseConfiguration.browserStackQaMode`.
- Produces `BrowserStackQaApp` bootstrap selection in `MortBootstrap`.
- Consumes `MORT_BROWSERSTACK_QA_MODE` as a boolean Dart define.

- [ ] **Step 1: Write the failing release-policy tests**

Add `browserStackQaMode` to the `configuration` helper and assert these exact outcomes:

```dart
test('BrowserStack QA mode is isolated to the internal automated-test profile', () {
  expect(
    configuration(
      profile: MortReleaseProfile.automatedTest,
      releaseStage: 'internal_test',
      browserStackQaMode: true,
    ).validationErrors,
    isEmpty,
  );
  expect(
    configuration(
      profile: MortReleaseProfile.production,
      releaseStage: 'production_public',
      browserStackQaMode: true,
      publicMarketplaceEnabled: true,
      identityVerificationEnabled: true,
      remotePushEnabled: true,
      crashReportingEnabled: true,
      productionActivationApproved: true,
      termsVersion: 'terms-2026-08-approved',
      privacyVersion: 'privacy-2026-08-approved',
      communityVersion: 'community-2026-08-approved',
      safetyVersion: 'safety-2026-08-approved',
    ).validationErrors,
    contains('BrowserStack QA mode is valid only for internal automated tests'),
  );
});
```

In `browserstack_qa_mode_test.dart`, source-inspect `main.dart` and assert the QA branch appears before `SupabaseService.initializeIfConfigured`.

- [ ] **Step 2: Run the focused tests and verify they fail**

Run: `flutter test test/release_profile_test.dart test/browserstack_qa_mode_test.dart`

Expected: FAIL because the configuration field and QA bootstrap branch do not exist.

- [ ] **Step 3: Add the minimal configuration and bootstrap implementation**

Define the flag in `AppConfig` and pass it into `MortReleaseConfiguration`:

```dart
static const browserStackQaMode = bool.fromEnvironment(
  'MORT_BROWSERSTACK_QA_MODE',
  defaultValue: false,
);
```

Add `required this.browserStackQaMode` to `MortReleaseConfiguration`. Its validation must add exactly `BrowserStack QA mode is valid only for internal automated tests` unless `profile == MortReleaseProfile.automatedTest && releaseStage == 'internal_test'`. In the automated-test branch, reject the flag if any existing external-system flag is enabled. In `AppConfig.validationErrors`, bypass the generic hosted-Supabase requirement only when this flag is true.

At the start of `MortBootstrap._initializeSafely`, validate configuration and return without initializing Supabase, analytics, push, or ads when QA mode is enabled. In `MortBootstrap.build`, return `const BrowserStackQaApp()` once that successful QA initialization completes; all other configurations continue returning `const MortApp()`.

- [ ] **Step 4: Run focused tests and static analysis**

Run: `flutter test test/release_profile_test.dart test/browserstack_qa_mode_test.dart && flutter analyze --no-pub`

Expected: PASS with no analyzer diagnostics.

- [ ] **Step 5: Commit the isolated mode**

```bash
git add flutter_mort/lib/core/config/app_config.dart flutter_mort/lib/core/config/release_profile.dart flutter_mort/lib/main.dart flutter_mort/test/release_profile_test.dart flutter_mort/test/browserstack_qa_mode_test.dart
git commit -m "feat: isolate BrowserStack QA build mode"
```

### Task 2: Build the deterministic QA shell around real screen widgets

**Files:**
- Create: `flutter_mort/lib/features/qa/browserstack_qa_app.dart`
- Create: `flutter_mort/lib/features/qa/browserstack_qa_fixtures.dart`
- Create: `flutter_mort/test/browserstack_qa_app_test.dart`
- Modify: `flutter_mort/lib/features/onboarding/compact_onboarding.dart`
- Modify: `flutter_mort/lib/features/mort_screens.dart`
- Modify: `flutter_mort/lib/features/financial/financial_safety_center.dart`

**Interfaces:**
- Produces `BrowserStackQaApp extends StatelessWidget`.
- Produces `browserStackQaFixtureOverrides()` returning `List<Override>`.
- Produces the accessibility identifiers `qa-home-landmark`, `qa-open-onboarding`, `qa-open-safety`, `qa-open-financial`, `qa-open-settings`, `qa-open-permissions`, and `qa-open-legal`.
- Consumes `CompactOnboardingScreen`, `SafetyCenterScreen`, `FinancialSafetyCenterScreen`, `SettingsScreen`, `NativePermissionsScreen`, and `TeenTermsSummaryScreen`.

- [ ] **Step 1: Write failing widget tests for the shell and fixtures**

Create a helper that pumps `const BrowserStackQaApp()` and assert:

```dart
expect(find.bySemanticsLabel('qa-home-landmark'), findsOneWidget);
expect(find.text('BrowserStack functional QA'), findsOneWidget);
await tester.tap(find.bySemanticsLabel('qa-open-financial'));
await tester.pumpAndSettle();
expect(find.text('Financial Safety'), findsOneWidget);
expect(find.text('Your financial record starts when you complete work.'), findsOneWidget);
expect(find.textContaining(r'$'), findsNothing);
```

Add assertions that Safety shows `MORT does not dispatch physical help`, Legal shows `Teen terms summary`, Settings shows `Control your account`, and the fixture mutation methods throw the exact `StateError` message.

- [ ] **Step 2: Run the shell test and verify it fails**

Run: `flutter test test/browserstack_qa_app_test.dart`

Expected: FAIL because `BrowserStackQaApp` and fixture overrides do not exist.

- [ ] **Step 3: Implement local-only fixture repositories**

In `browserstack_qa_fixtures.dart`, use the established fake-repository pattern from `test/compact_onboarding_test.dart` and `test/financial_screens_test.dart`:

```dart
const browserStackQaMutationMessage =
    'BrowserStack QA mode does not permit mutations.';

Never _mutate() => throw StateError(browserStackQaMutationMessage);

class BrowserStackQaFinancialRepository extends FinancialRepository {
  @override
  Future<FinancialSummary> getFinancialSummary(int year) async => FinancialSummary(
    year: year,
    grossTrackedCents: 0,
    jobsCompleted: 0,
    methodBreakdown: const [],
    expensesCents: 0,
    expenseCount: 0,
    receiptsCount: 0,
    personalTargets: const [],
    disclaimer: 'Recordkeeping estimate — not a tax return or tax determination.',
  );

  @override
  Future<FinancialEvaluation> evaluateAlerts(int year) async => FinancialEvaluation(
    year: year,
    grossTrackedCents: 0,
    alerts: const [],
    workStatus: 'unaffected',
    notice: 'Financial checks are informational. They never block or limit your ability to keep working.',
  );
}
```

Override every financial mutator used by mounted screens (`createExpense`, `updateExpense`, `deleteExpense`, `attachReceipt`, `removeReceipt`, `upsertTarget`, and `setPreferences`) to call `_mutate`. Add a profile fixture that returns the account onboarding step and advances only its in-memory progress when the existing `Save account` confirmation is used. Add a safety fixture that returns no check-ins and the exact non-dispatch guidance; its report, block, ping, and check-in mutators call `_mutate`. Override `currentProfileProvider`, `profileRepositoryProvider`, `financialRepositoryProvider`, `safetyRepositoryProvider`, and `legalContractRepositoryProvider` in one function.

- [ ] **Step 4: Implement the shell router and stable landmarks**

Use a nested `ProviderScope` with the fixture overrides and a local `GoRouter` with these exact paths: `/qa`, `/qa/onboarding`, `/qa/safety`, `/qa/financial`, `/qa/settings`, `/qa/permissions`, and `/qa/legal`.

The `/qa` screen must show a `MortHeader` titled `BrowserStack functional QA`, explain `Local synthetic data. No account or provider is contacted.`, and expose one `Semantics(identifier: ...)` wrapped `MortButton` per route using the identifiers listed above. Routes must mount the real product widgets. Add only a semantic `identifier` to the onboarding account-type choice controls, Safety's no-dispatch boundary, Financial's zero-state, Settings header, permission explanation, and legal summary header; preserve their visible labels and existing behavior.

- [ ] **Step 5: Run widget tests and format**

Run: `dart format lib/features/qa lib/features/onboarding/compact_onboarding.dart lib/features/mort_screens.dart lib/features/financial/financial_safety_center.dart test/browserstack_qa_app_test.dart && flutter test test/browserstack_qa_app_test.dart test/compact_onboarding_test.dart test/financial_screens_test.dart test/settings_experience_test.dart`

Expected: PASS. The test output must prove only zero financial data is rendered and every mutation fixture rejects.

- [ ] **Step 6: Commit the functional shell**

```bash
git add flutter_mort/lib/features/qa flutter_mort/lib/features/onboarding/compact_onboarding.dart flutter_mort/lib/features/mort_screens.dart flutter_mort/lib/features/financial/financial_safety_center.dart flutter_mort/test/browserstack_qa_app_test.dart
git commit -m "feat: add local BrowserStack functional QA shell"
```

### Task 3: Make BrowserStack Appium dependencies and flows reproducible

**Files:**
- Create: `scripts/browserstack/package.json`
- Create: `scripts/browserstack/package-lock.json`
- Create: `scripts/browserstack/ios-appium-functional-test.mjs`
- Modify: `scripts/browserstack/ios-appium-smoke-test.mjs`
- Test: `scripts/browserstack/ios-appium-functional-test.test.mjs`

**Interfaces:**
- Produces `runFunctionalProfile(driver, profile)` for `deep`, `limited`, and `floor`.
- Consumes `BS_QA_PROFILE`, BrowserStack credentials, uploaded app URL, and the QA semantic identifiers.
- Produces named PNG evidence: `browserstack-<profile>-<checkpoint>.png`.

- [ ] **Step 1: Write failing Node tests for profile selection and forbidden actions**

Export pure helpers from the new module and assert:

```js
assert.deepEqual(profileCheckpoints('deep'), [
  'home', 'onboarding', 'legal', 'safety', 'financial', 'settings', 'permissions',
]);
assert.deepEqual(profileCheckpoints('limited'), ['home', 'onboarding', 'legal', 'safety']);
assert.deepEqual(profileCheckpoints('floor'), ['home', 'safety', 'financial', 'settings']);
assert.throws(() => profileCheckpoints('unknown'), /Unknown BrowserStack QA profile/);
assert.equal(isForbiddenQaAction('Send Safety Ping'), true);
assert.equal(isForbiddenQaAction('Add an expense'), true);
```

- [ ] **Step 2: Run Node tests and verify they fail**

Run: `node --test scripts/browserstack/ios-appium-functional-test.test.mjs`

Expected: FAIL because the module does not exist.

- [ ] **Step 3: Add the pinned package manifest and lockfile**

Create this manifest exactly:

```json
{
  "name": "mort-browserstack-qa",
  "private": true,
  "type": "module",
  "engines": { "node": ">=22 <23" },
  "dependencies": { "webdriverio": "9.31.6" }
}
```

From `scripts/browserstack`, run `npm install --package-lock-only --ignore-scripts`, inspect the generated lockfile for only expected WebdriverIO transitive dependencies, then run `npm ci --ignore-scripts` and `npm audit --omit=dev`. Record the exact audit result; do not modify packages through audit tooling.

- [ ] **Step 4: Implement bounded, diagnostic Appium flows**

Keep connection setup and `reportSessionDiagnostics` from the launch script in a shared module or retain them in both scripts. The functional script must use a 20-second `waitForExist` per named landmark, screenshot after each checkpoint, and include `BS_QA_PROFILE` in BrowserStack `sessionName`.

`deep` must tap `qa-open-onboarding`, enter an adult DOB, verify both account-type labels, advance through the local confirmation, use the back control to return to account, open and return from legal summary, then verify the Safety non-dispatch text, Financial empty-record text, Settings title, and permission explanation. `limited` omits settings and permissions. `floor` never fills a form and only verifies the narrow-layout route landmarks. No profile may tap a control identified by `isForbiddenQaAction`.

Keep `ios-appium-smoke-test.mjs` as a launch-only diagnostic command but update its header to say that `ios-appium-functional-test.mjs` is the authoritative behavioral suite.

- [ ] **Step 5: Run Node checks and audit**

Run: `npm ci --ignore-scripts && node --test ios-appium-functional-test.test.mjs && npm audit --omit=dev`

Expected: tests PASS. If audit reports advisories, preserve its exit/output in the implementation report and update the exact pinned dependency only after checking its release notes; do not suppress the result.

- [ ] **Step 6: Commit tooling and tests**

```bash
git add scripts/browserstack/package.json scripts/browserstack/package-lock.json scripts/browserstack/ios-appium-functional-test.mjs scripts/browserstack/ios-appium-functional-test.test.mjs scripts/browserstack/ios-appium-smoke-test.mjs
git commit -m "test: add reproducible BrowserStack functional flows"
```

### Task 4: Wire the fresh functional device matrix into CI

**Files:**
- Modify: `.github/workflows/mort-ios-browserstack.yml`
- Test: `flutter_mort/test/ios_platform_parity_test.dart`

**Interfaces:**
- Consumes `MORT_BROWSERSTACK_QA_MODE=true` at iOS build time.
- Consumes `scripts/browserstack/package-lock.json` through `npm ci`.
- Produces deep, limited, and floor session records and evidence artifacts.

- [ ] **Step 1: Write failing workflow-contract assertions**

Add a test that reads the workflow and requires all of these literals:

```dart
expect(workflow, contains('--dart-define=MORT_BROWSERSTACK_QA_MODE=true'));
expect(workflow, contains('npm ci --ignore-scripts'));
expect(workflow, contains('ios-appium-functional-test.mjs'));
expect(workflow, contains('iPhone 15|17|deep'));
expect(workflow, contains('iPhone 17|26|limited'));
expect(workflow, contains('iPhone SE 2022|15|floor'));
```

- [ ] **Step 2: Run the contract test and verify it fails**

Run: `flutter test test/ios_platform_parity_test.dart`

Expected: FAIL because the workflow still installs WebdriverIO ad hoc and runs launch-only sessions.

- [ ] **Step 3: Update the workflow**

Keep existing IPA upload behavior. Add `--dart-define=MORT_BROWSERSTACK_QA_MODE=true` to its QA artifact build and replace the install step with `npm ci --ignore-scripts` in `scripts/browserstack`. Replace the loop entries with:

```bash
devices=(
  "iPhone 15|17|deep"
  "iPhone 17|26|limited"
  "iPhone SE 2022|15|floor"
)
```

For each entry, set `BS_DEVICE_NAME`, `BS_OS_VERSION`, and `BS_QA_PROFILE`, invoke `node ios-appium-functional-test.mjs`, and rename all checkpoint PNGs, crash logs, and device logs with device, OS, and profile. Upload `browserstack-*-*.png` alongside the existing diagnostic files.

- [ ] **Step 4: Run workflow-contract and affected Flutter tests**

Run: `flutter test test/ios_platform_parity_test.dart test/release_profile_test.dart test/browserstack_qa_mode_test.dart test/browserstack_qa_app_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit CI integration**

```bash
git add .github/workflows/mort-ios-browserstack.yml flutter_mort/test/ios_platform_parity_test.dart
git commit -m "ci: run BrowserStack functional iOS profiles"
```

### Task 5: Verify, publish evidence, and update release records

**Files:**
- Modify: `MORT_FINAL_100_SCORECARD.md`
- Modify: `MORT_EXTERNAL_RELEASE_GATES.md`
- Modify: GitHub PR #8 body

**Interfaces:**
- Consumes the fresh BrowserStack run ID, uploaded app URL, per-device session IDs, screenshots, diagnostics, package audit output, and final local regression output.
- Produces an accurate technical-readiness and external-gates record.

- [ ] **Step 1: Run local regression before a device tag**

Run, from `flutter_mort`:

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter build apk --debug --dart-define=MORT_RELEASE_STAGE=internal_test --dart-define=MORT_RELEASE_PROFILE=automated_test --dart-define=MORT_OPERATIONAL_MODE=automated_test --dart-define=MORT_BROWSERSTACK_QA_MODE=true --dart-define=ADS_ENABLED=false --dart-define=IAP_ENABLED=false
```

Expected: formatting/analyzer clean; all Flutter tests pass; debug Android build succeeds. Also run root tests affected by the final diff.

- [ ] **Step 2: Push and run a fresh QA tag**

Push the integration branch, then create and push a fresh unique `ios-qa-YYYYMMDD-NNN` tag. Wait for the matching GitHub Actions workflow to finish. Do not rerun or relabel the completed launch-only tag `ios-qa-20260907-017`.

- [ ] **Step 3: Investigate every failed real-device session before reporting**

For any failed matrix cell, download its BrowserStack evidence, inspect screenshot/page source/device/crash logs, reproduce the corresponding widget-level expectation, add a regression test, make the minimal repair, rerun all affected local checks, push a new commit and fresh tag, and wait for the replacement matrix. Do not classify an uninvestigated failure as a platform flake.

- [ ] **Step 4: Update release documents and PR body**

Record the successful fresh run URL, exact commit SHA, app URL, all three device/OS/profile/session IDs, audit result, screenshots, and the fact that BrowserStack functional iOS QA is no longer an external blocker. Preserve external gates for Apple distribution signing, Android production signing, hosted Supabase configuration, production iOS AdMob, payments, identity, legal approval, and live staffing. Update PR #8 description to distinguish this functional matrix from the historic launch-only run.

- [ ] **Step 5: Commit documents and wait for PR checks**

```bash
git add MORT_FINAL_100_SCORECARD.md MORT_EXTERNAL_RELEASE_GATES.md
git commit -m "docs: record BrowserStack functional QA evidence"
git push origin integration/mort-final-100-readiness
```

Wait for all PR #8 checks at the final commit; leave the PR open.

## Plan self-review

* **Spec coverage:** Task 1 gates QA mode to the internal automated profile; Task 2 supplies real screen widgets with mutation-rejecting local data; Task 3 supplies deterministic Appium flows and locked dependencies; Task 4 creates the requested deep/limited/floor device matrix; Task 5 requires fresh evidence and documents external gates.
* **Placeholder scan:** No deferred implementation markers or generic test instructions remain. Every task names files, interfaces, commands, exact test behavior, and commit boundary.
* **Type consistency:** `AppConfig.browserStackQaMode` feeds `MortReleaseConfiguration.browserStackQaMode`; `BrowserStackQaApp` is selected by bootstrap; `browserStackQaFixtureOverrides()` feeds its nested `ProviderScope`; `profileCheckpoints()` drives Appium profile selection.
