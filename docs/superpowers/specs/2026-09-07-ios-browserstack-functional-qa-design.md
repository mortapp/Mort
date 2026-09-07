# iOS BrowserStack functional QA design

## Context

The completed BrowserStack matrix proves that the unsigned internal iOS IPA
uploads and launches on three real iPhones. It intentionally performs only a
launch/no-crash assertion. Functional checks cannot safely use real MORT
accounts, real jobs, payments, guardians, or production provider credentials.

The internal BrowserStack build currently has neither public Supabase
configuration nor a deterministic authenticated session. Its normal startup
gate therefore prevents protected production surfaces from being exercised.

## Decision

Add an explicitly internal-only, compile-time QA mode to the BrowserStack
artifact. It must never be enabled by production, pilot, closed-test, or
ordinary development builds.

The QA mode will:

1. Enable the existing local Google Play reviewer experience for role-specific
   synthetic workflow coverage.
2. Provide a deterministic local QA navigation/session surface for the real
   onboarding, safety, financial safety, settings, legal, and native-permission
   views. It uses fixed in-memory data and disabled-provider responses only;
   it makes no network, account, payment, safety-ping, or permission-changing
   mutations.
3. Preserve the normal startup, routing, repository, and release-gate behavior
   for every non-QA build.

## Testability contract

* Prefer visible, accessible names for Appium locators.
* Add stable Flutter semantic identifiers only at the QA entry point and on
  controls whose visible label is genuinely ambiguous. Identifier names are
  product-neutral and documented beside the test.
* The harness must assert a screen-specific ready landmark before interacting,
  capture a screenshot at significant states, and retain BrowserStack session
  diagnostics on failure.
* Permission coverage stops at the in-app explanation/denial state. It must
  not approve, alter, or depend on real device permissions.
* Financial coverage verifies the empty-record and informational safety
  language. It never creates transactions, targets, exports, or receipts.
* Safety coverage verifies the no-emergency-dispatch boundary. It never sends
  a Safety Ping, opens a dialer, or creates a report.

## Appium suite

One Node ESM suite will expose named flows and allow the CI matrix to choose a
deep or reduced profile:

* `deep` (iPhone 15 / iOS 17): boot and QA entry; onboarding account role
  choices, step back, and legal navigation/back; local teen navigation to
  Safety, Financial Safety, and Settings; provider-disabled and empty-record
  assertions; permission-denial explanation; reviewer synthetic role and PIN
  interaction.
* `limited` (iPhone 17 / iOS 26): boot, QA entry, onboarding/legal back path,
  safety boundary, and a reviewer role-selection check.
* `floor` (iPhone SE 2022 / iOS 15): boot, QA entry, narrow-layout landmark
  checks, and navigation to safety/financial/settings.

The existing green launch-only matrix is historical evidence and will not be
repeated. A fresh QA tag will run the new functional matrix after implementation.

## Tooling and CI

`scripts/browserstack` will own a minimal `package.json` and committed lockfile
for WebdriverIO. CI will use `npm ci`, not `npm install --no-save`. Dependency
audit output will be reviewed without `--force`; any unresolved issue will be
recorded accurately rather than hidden.

The BrowserStack workflow will build a QA-only artifact with the explicit
compile-time mode, run each named profile, preserve screenshots and logs with
device/profile names, and report BrowserStack session IDs.

## Non-goals and external gates

This work does not create production identities, configure Supabase, approve
native permissions, add Apple distribution signing, create Android signing,
provision iOS AdMob, enable payments/identity providers, or merge PR #8.
Those gates remain external and must continue to be reported as such.

## Acceptance criteria

1. QA-only behavior is impossible unless the explicit internal Dart define is
   present, and regression tests prove normal profiles cannot enable it.
2. Widget/unit coverage proves the harness exposes only synthetic data and
   rejects mutating actions.
3. The Appium suite has deterministic, bounded waits and produces actionable
   failure diagnostics.
4. Node dependencies are reproducible through `npm ci` and audited without
   suppressing findings.
5. The deep, limited, and floor real-device profiles pass on a fresh
   BrowserStack upload, or any device-specific failure is investigated and
   fixed with a regression loop.
6. Scorecard, external-gate record, PR body, and final report distinguish the
   new functional evidence from remaining external release gates.
