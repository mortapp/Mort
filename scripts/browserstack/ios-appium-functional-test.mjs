// Authoritative behavioral BrowserStack QA suite. Drives the real MORT
// onboarding, legal, safety, financial, settings, and permissions screens
// (mounted by BrowserStackQaApp, see flutter_mort/lib/features/qa) through
// their stable accessibility identifiers/names, on a real iPhone via
// BrowserStack App Automate.
//
// `ios-appium-smoke-test.mjs` remains a narrower launch-only diagnostic
// (does the app start without crashing); this script is the one that
// proves the QA screens actually work end to end and never trip a
// forbidden real-world action.
//
// Required env vars: BROWSERSTACK_USERNAME, BROWSERSTACK_ACCESS_KEY,
// BROWSERSTACK_APP_URL, BS_DEVICE_NAME, BS_OS_VERSION, BS_QA_PROFILE
// (one of "deep", "limited", "floor").

import { remote } from "webdriverio";
import assert from "node:assert/strict";
import { writeFile } from "node:fs/promises";

const CHECKPOINTS = Object.freeze({
  deep: Object.freeze([
    "home",
    "onboarding",
    "legal",
    "safety",
    "financial",
    "settings",
    "permissions",
  ]),
  limited: Object.freeze(["home", "onboarding", "legal", "safety"]),
  floor: Object.freeze(["home", "safety", "financial", "settings"]),
});

export function profileCheckpoints(profile) {
  const checkpoints = CHECKPOINTS[profile];
  if (!checkpoints) {
    throw new Error(`Unknown BrowserStack QA profile: ${profile}`);
  }
  return checkpoints;
}

// Real, visible labels on QA-reachable screens that would trigger a real
// native side effect, a real hosted mutation, or a real emergency/safety
// dispatch if actually tapped. No functional flow may tap any of these --
// the QA fixtures already reject the underlying calls (see
// browserstack_qa_fixtures.dart), but the Appium flows themselves must
// never even attempt them, so a fixture regression can't be masked by
// "Appium never clicked it anyway".
const FORBIDDEN_ACTION_SUBSTRINGS = Object.freeze([
  "safety ping",
  "call 911",
  "report a concern",
  "create a report",
  "block user",
  "block poster",
  "block participant",
  "add an expense",
  "edit expense",
  "choose photo",
  "take photo",
  "replace photo",
]);
const FORBIDDEN_ACTION_EXACT = Object.freeze(["remove"]);

export function isForbiddenQaAction(label) {
  const normalized = label.trim().toLowerCase();
  if (FORBIDDEN_ACTION_EXACT.includes(normalized)) return true;
  return FORBIDDEN_ACTION_SUBSTRINGS.some((needle) =>
    normalized.includes(needle),
  );
}

function assertAllowed(label) {
  if (isForbiddenQaAction(label)) {
    throw new Error(
      `Refusing to tap "${label}": it is on the forbidden real-action list.`,
    );
  }
}

const required = [
  "BROWSERSTACK_USERNAME",
  "BROWSERSTACK_ACCESS_KEY",
  "BROWSERSTACK_APP_URL",
  "BS_DEVICE_NAME",
  "BS_OS_VERSION",
  "BS_QA_PROFILE",
];
// Deferred to main() rather than evaluated at module load, so this file
// can be imported for unit-testing profileCheckpoints/isForbiddenQaAction
// without BrowserStack env vars ever being set.
let profile;
let basicAuth;
let activeCheckpoint = "session-start";
let activeSelector = null;

export function redactDiagnosticText(value, secrets = []) {
  let safe = String(value ?? "");
  safe = safe.replace(/\b((?:Proxy-)?Authorization\s*:\s*Basic)\s+[^\s,;]+/gi, "$1 [REDACTED]");
  safe = safe.replace(/\bBasic\s+[A-Za-z0-9+/=_-]+/gi, "Basic [REDACTED]");
  safe = safe.replace(/https?:\/\/[^\s"'<>]+/gi, (raw) => {
    try {
      const url = new URL(raw);
      url.username = "";
      url.password = "";
      if (url.search) url.search = "?[REDACTED]";
      return url.toString();
    } catch { return "[REDACTED_URL]"; }
  });
  for (const secret of secrets.filter(Boolean)) {
    safe = safe.split(String(secret)).join("[REDACTED]");
  }
  return safe;
}

function diagnosticSecrets() {
  return [process.env.BROWSERSTACK_USERNAME, process.env.BROWSERSTACK_ACCESS_KEY, basicAuth];
}

function initializeFromEnv() {
  for (const name of required) {
    if (!process.env[name]) {
      console.error(`Missing required env var: ${name}`);
      process.exit(1);
    }
  }

  profile = process.env.BS_QA_PROFILE;
  profileCheckpoints(profile); // throws early on an unknown profile

  basicAuth = Buffer.from(
    `${process.env.BROWSERSTACK_USERNAME}:${process.env.BROWSERSTACK_ACCESS_KEY}`,
  ).toString("base64");

  return {
    path: "/wd/hub",
    hostname: "hub.browserstack.com",
    port: 443,
    protocol: "https",
    user: process.env.BROWSERSTACK_USERNAME,
    key: process.env.BROWSERSTACK_ACCESS_KEY,
    logLevel: "warn",
    capabilities: {
      platformName: "iOS",
      "appium:automationName": "XCUITest",
      "appium:app": process.env.BROWSERSTACK_APP_URL,
      "appium:deviceName": process.env.BS_DEVICE_NAME,
      "appium:osVersion": process.env.BS_OS_VERSION,
      "appium:autoAcceptAlerts": true,
      "bstack:options": {
        projectName: "MORT",
        buildName: `mort-ios-qa-${process.env.GITHUB_SHA ?? "local"}`,
        sessionName: `functional-${profile}-${process.env.BS_DEVICE_NAME}-${process.env.BS_OS_VERSION}`,
      },
    },
  };
}

// Fetches this session's real status/reason and crash/device logs from
// BrowserStack's own API -- a failure is diagnosed from BrowserStack's
// authoritative record, not guessed at from the Appium client's error
// alone.
export async function downloadSessionDiagnostics({
  sessionId,
  qaProfile,
  fetchImpl = fetch,
  authorization = basicAuth ? `Basic ${basicAuth}` : undefined,
  writeFileImpl = writeFile,
}) {
  try {
    const res = await fetchImpl(
      `https://api-cloud.browserstack.com/app-automate/sessions/${sessionId}.json`,
      { headers: authorization ? { Authorization: authorization } : {} },
    );
    if (!res.ok) throw new Error(`session metadata HTTP ${res.status}`);
    const body = await res.json();
    const session = body.automation_session ?? body;
    console.log(`BROWSERSTACK_SESSION_STATUS=${session.status}`);
    console.log(`BROWSERSTACK_SESSION_REASON=${redactDiagnosticText(session.reason ?? "(none)", diagnosticSecrets())}`);
    const safeSession = {
      sessionId,
      status: session.status ?? null,
      reason: session.reason == null ? null : redactDiagnosticText(session.reason, diagnosticSecrets()),
      name: session.name == null ? null : redactDiagnosticText(session.name, diagnosticSecrets()),
      device: session.device ?? null,
      os: session.os ?? null,
      osVersion: session.os_version ?? null,
      duration: session.duration ?? null,
    };
    await isolatedDiagnostic("session metadata write", async () => {
      await writeFileImpl(`browserstack-session-${qaProfile}.json`, `${JSON.stringify(safeSession, null, 2)}\n`);
    });
    await isolatedDiagnostic("crash log", async () => {
      if (!session.crash_logs_url) return;
      const response = await fetchImpl(session.crash_logs_url, { headers: authorization ? { Authorization: authorization } : {} });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const text = await response.text();
      await writeFileImpl(`browserstack-crash-log-${qaProfile}.txt`, redactDiagnosticText(text, diagnosticSecrets()));
    });
    await isolatedDiagnostic("device log", async () => {
      if (!session.device_logs_url) return;
      const response = await fetchImpl(session.device_logs_url, { headers: authorization ? { Authorization: authorization } : {} });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const text = await response.text();
      const safeText = redactDiagnosticText(text, diagnosticSecrets());
      await writeFileImpl(`browserstack-device-log-${qaProfile}.txt`, safeText);
      const relevant = safeText.split("\n").filter((line) => /mortapp|crash|SIGABRT|SIGSEGV|Fatal|terminat|launchd|CrashReporter/i.test(line)).slice(0, 60);
      for (const line of relevant) console.log("  " + line);
    });
    await isolatedDiagnostic("Appium log", async () => {
      if (!session.appium_logs_url) return;
      const response = await fetchImpl(session.appium_logs_url, { headers: authorization ? { Authorization: authorization } : {} });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const text = await response.text();
      await writeFileImpl(`browserstack-appium-log-${qaProfile}.txt`, redactDiagnosticText(text, diagnosticSecrets()));
    });
  } catch (diagError) {
    console.error("Could not fetch BrowserStack session diagnostics:");
    console.error(redactDiagnosticText(diagError?.message ?? diagError, diagnosticSecrets()));
  }
}

async function isolatedDiagnostic(label, operation) {
  try {
    await operation();
  } catch (error) {
    console.error(`Diagnostic ${label} failed: ${redactDiagnosticText(error?.message ?? error, diagnosticSecrets())}`);
  }
}

export async function captureFailureDiagnostics({
  driver,
  checkpoint,
  error,
  qaProfile,
  deviceName,
  osVersion,
  selector = null,
  sensitiveValues = diagnosticSecrets(),
  writeFileImpl = writeFile,
}) {
  const stem = `browserstack-${qaProfile}-${checkpoint}`;
  const metadata = {
    checkpoint,
    selector: selector == null ? null : redactDiagnosticText(selector, sensitiveValues),
    error: {
      name: error?.name ?? "Error",
      message: redactDiagnosticText(error?.message ?? String(error), sensitiveValues),
      stack: error?.stack == null ? null : redactDiagnosticText(error.stack, sensitiveValues),
    },
    device: {
      name: redactDiagnosticText(deviceName, sensitiveValues),
      os: "iOS",
      osVersion: redactDiagnosticText(osVersion, sensitiveValues),
    },
    session: { id: driver.sessionId ?? null },
    contexts: [],
    nativeInputs: [],
  };
  await isolatedDiagnostic("failure screenshot", async () => {
    const png = await driver.takeScreenshot();
    await writeFileImpl(`${stem}-failure.png`, Buffer.from(png, "base64"));
  });
  await isolatedDiagnostic("page source", async () => {
    await writeFileImpl(`${stem}-page-source.xml`, redactDiagnosticText(await driver.getPageSource(), sensitiveValues));
  });
  await isolatedDiagnostic("contexts", async () => {
    metadata.contexts = await driver.getContexts();
  });
  await isolatedDiagnostic("native input metadata", async () => {
    const elements = (await driver.$$(
      '-ios predicate string:type == "XCUIElementTypeTextField" OR type == "XCUIElementTypeTextView"',
    )).slice(0, 10);
    for (const element of elements) {
      const item = {};
      for (const attribute of ["type", "label", "name", "value", "placeholderValue", "enabled", "visible", "accessible"]) {
        try {
          const value = await element.getAttribute(attribute);
          item[attribute] = value == null ? null : redactDiagnosticText(value, sensitiveValues);
        } catch { item[attribute] = null; }
      }
      try { item.rect = await element.getRect(); } catch { item.rect = null; }
      metadata.nativeInputs.push(item);
    }
  });
  await isolatedDiagnostic("metadata", async () => {
    await writeFileImpl(`${stem}-diagnostics.json`, `${JSON.stringify(metadata, null, 2)}\n`);
  });
}

async function screenshotCheckpoint(driver, checkpoint) {
  const png = await driver.takeScreenshot();
  const path = `browserstack-${profile}-${checkpoint}.png`;
  await writeFile(path, Buffer.from(png, "base64"));
  console.log(`Saved ${path}`);
}

async function waitForLandmark(driver, accessibilityId, timeoutMs = 20000) {
  activeSelector = `~${accessibilityId}`;
  const el = await driver.$(`~${accessibilityId}`);
  await el.waitForExist({ timeout: timeoutMs });
  return el;
}

async function tapByAccessibleName(driver, name, timeoutMs = 20000) {
  assertAllowed(name);
  activeSelector = `~${name}`;
  const el = await driver.$(`~${name}`);
  await el.waitForExist({ timeout: timeoutMs });
  await el.waitForDisplayed({ timeout: timeoutMs });
  await el.click();
}

// A plain accessibility-id lookup ("~label") for a Material TextField's
// InputDecoration.labelText finds a real semantics node on iOS, but that
// node isn't reliably the settable XCUIElementTypeTextField itself --
// elementSendKeys then fails with "element wasn't found" even though
// waitForExist just succeeded on the same selector (confirmed against a
// real device: BrowserStack session 6a02d2dcea33cebf9fe9895c7f9a840269bd0811,
// run 34167940220, "Date of birth"). Target the actual text field by an
// iOS predicate on its type plus label/value/placeholderValue instead,
// which is the documented, reliable way to hit a Flutter decorated
// TextField's input control under XCUITest.
export function iosTextFieldPredicate(label) {
  const escaped = label.replace(/"/g, '\\"');
  return (
    `-ios predicate string:type == "XCUIElementTypeTextField" AND ` +
    `(label CONTAINS "${escaped}" OR value CONTAINS "${escaped}" OR ` +
      `placeholderValue CONTAINS "${escaped}")`
  );
}

async function typeIntoField(driver, label, value, timeoutMs = 20000) {
  activeSelector = iosTextFieldPredicate(label);
  const el = await driver.$(activeSelector);
  await el.waitForExist({ timeout: timeoutMs });
  await el.click();
  await el.waitForDisplayed({ timeout: timeoutMs });
  await el.clearValue();
  await el.setValue(value);
  const entered = String(await el.getValue());
  if (entered !== value) {
    await el.clearValue();
    await el.setValue(value);
  }
  assert.equal(await el.getValue(), value, `Unable to enter ${label}`);
}

async function assertTextVisible(driver, text, timeoutMs = 20000) {
  activeSelector = `~${text}`;
  const el = await driver.$(`~${text}`);
  await el.waitForExist({ timeout: timeoutMs });
  return el;
}

async function goHome(driver) {
  await waitForLandmark(driver, "qa-home-landmark");
}

// Every QA route except onboarding-at-its-first-step renders a MortHeader,
// which auto-mounts a "Back" MortBackButton whenever the route can pop
// (see MortHeader/MortBackButton in mort_widgets.dart /
// mort_back_navigation.dart) -- so tapping "~Back" is reliable there.
// Onboarding's header explicitly passes showBackButton: false (its bottom
// bar's own step-back button reuses the same "Back" name for a different,
// in-wizard purpose), and step 0 has no visible leave affordance at all.
// The only way off that screen is the platform's real edge-swipe-to-pop
// gesture, which MortCupertinoPageTransitionsBuilder deliberately keeps
// enabled on iOS (mort_page_transitions.dart) -- so this simulates that
// exact real gesture rather than assuming a generic WebDriver "back"
// command means anything for a native iOS app.
async function swipeFromLeftEdgeToPop(driver) {
  const { width, height } = await driver.getWindowSize();
  const y = Math.round(height / 2);
  await driver.execute("mobile: swipe", {
    direction: "right",
    fromX: 2,
    fromY: y,
    toX: Math.round(width * 0.9),
    toY: y,
    duration: 1000,
  });
}

async function leaveToHome(driver, { viaHeaderBack }) {
  if (viaHeaderBack) {
    await tapByAccessibleName(driver, "Back");
  } else {
    await swipeFromLeftEdgeToPop(driver);
    const leaveSetup = await driver.$("~Leave setup");
    if (await leaveSetup.waitForExist({ timeout: 5000 })) {
      await leaveSetup.click();
    }
  }
  await goHome(driver);
}

async function checkpointHome(driver) {
  await goHome(driver);
  await screenshotCheckpoint(driver, "home");
}

async function checkpointOnboarding(driver) {
  await tapByAccessibleName(driver, "qa-open-onboarding");
  await typeIntoField(driver, "Date of birth", "01/01/1990");

  await assertTextVisible(driver, "qa-onboarding-account-adult");
  await assertTextVisible(driver, "qa-onboarding-account-guardian");

  await typeIntoField(driver, "Display name", "MORT QA");
  await typeIntoField(driver, "Username", "mort_qa_functional");
  await typeIntoField(driver, "City", "Indianapolis");
  await typeIntoField(driver, "State", "IN");

  // BrowserStack exposes the iOS keyboard's Done button on some OS/device
  // combinations but not others. Save account remains a native button, so
  // dismiss the keyboard opportunistically and continue when it is absent.
  const done = await driver.$("~Done");
  if (await done.isExisting()) {
    await done.click();
  }
  await screenshotCheckpoint(driver, "onboarding-account-filled");

  // Saving the account advances directly to the work-preferences step. The
  // production flow does not show a confirmation sheet here.
  await tapByAccessibleName(driver, "Save account");
  await assertTextVisible(driver, "Back");
  await screenshotCheckpoint(driver, "onboarding-post-save");

  // This "Back" is the wizard's own step-back control (advances step
  // 1 -> 0), not a screen-leaving control.
  await tapByAccessibleName(driver, "Back");
  await assertTextVisible(driver, "Profile photo (optional)");
  await screenshotCheckpoint(driver, "onboarding-back-to-account");

  await leaveToHome(driver, { viaHeaderBack: false });
}

async function checkpointLegal(driver) {
  await tapByAccessibleName(driver, "qa-open-legal");
  await assertTextVisible(driver, "qa-legal-summary-header");
  await screenshotCheckpoint(driver, "legal");
  await leaveToHome(driver, { viaHeaderBack: true });
}

async function checkpointSafety(driver) {
  await tapByAccessibleName(driver, "qa-open-safety");
  await assertTextVisible(driver, "qa-safety-no-dispatch");
  await screenshotCheckpoint(driver, "safety");
  await leaveToHome(driver, { viaHeaderBack: true });
}

async function checkpointFinancial(driver) {
  await tapByAccessibleName(driver, "qa-open-financial");
  await assertTextVisible(driver, "qa-financial-zero-state");
  await screenshotCheckpoint(driver, "financial");
  await leaveToHome(driver, { viaHeaderBack: true });
}

async function checkpointSettings(driver) {
  await tapByAccessibleName(driver, "qa-open-settings");
  await assertTextVisible(driver, "qa-settings-header");
  await screenshotCheckpoint(driver, "settings");
  await leaveToHome(driver, { viaHeaderBack: true });
}

async function checkpointPermissions(driver) {
  await tapByAccessibleName(driver, "qa-open-permissions");
  await assertTextVisible(driver, "qa-permissions-explanation");
  await screenshotCheckpoint(driver, "permissions");
  await leaveToHome(driver, { viaHeaderBack: true });
}

const CHECKPOINT_RUNNERS = {
  home: checkpointHome,
  onboarding: checkpointOnboarding,
  legal: checkpointLegal,
  safety: checkpointSafety,
  financial: checkpointFinancial,
  settings: checkpointSettings,
  permissions: checkpointPermissions,
};

export async function runFunctionalProfile(driver, qaProfile) {
  for (const checkpoint of profileCheckpoints(qaProfile)) {
    activeCheckpoint = checkpoint;
    console.log(`Running checkpoint: ${checkpoint}`);
    await CHECKPOINT_RUNNERS[checkpoint](driver);
    console.log(`RESULT_${checkpoint.toUpperCase()}=PASS`);
  }
}

async function main() {
  const opts = initializeFromEnv();
  console.log(
    `Starting BrowserStack functional session: profile="${profile}" device="${process.env.BS_DEVICE_NAME}" iOS ${process.env.BS_OS_VERSION}`,
  );
  const driver = await remote(opts);
  const sessionId = driver.sessionId;
  console.log(`BROWSERSTACK_SESSION_ID=${sessionId}`);
  console.log(
    `BROWSERSTACK_SESSION_URL=https://app-automate.browserstack.com/dashboard/v2/sessions/${sessionId}`,
  );

  let passed = false;
  try {
    // Real-device cold starts can be slower than a local simulator.
    await driver.pause(15000);
    await runFunctionalProfile(driver, profile);
    passed = true;
    console.log("RESULT=PASS");
  } catch (error) {
    console.error("RESULT=FAIL");
    console.error(redactDiagnosticText(error?.stack ?? error?.message ?? error, diagnosticSecrets()));
    await captureFailureDiagnostics({
      driver,
      checkpoint: activeCheckpoint,
      error,
      qaProfile: profile,
      deviceName: process.env.BS_DEVICE_NAME,
      osVersion: process.env.BS_OS_VERSION,
      selector: activeSelector,
    });
    process.exitCode = 1;
  } finally {
    try {
      await driver.deleteSession();
    } catch {
      // Session may already be dead; still fetch diagnostics below.
    }
    await downloadSessionDiagnostics({ sessionId, qaProfile: profile });
  }
  if (!passed) process.exitCode = 1;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main();
}
