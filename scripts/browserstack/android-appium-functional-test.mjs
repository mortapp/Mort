// Real-device Android QA for MORT's internal deterministic BrowserStack shell.
// This suite never signs into a real account and never performs hosted/provider
// mutations. It verifies the remaining device-interaction gaps on real Android
// hardware: keyboard/IME behavior, compact layout, reduced motion, role-home
// surfaces, and core QA screens.

import { remote } from "webdriverio";
import assert from "node:assert/strict";
import { writeFile } from "node:fs/promises";
import {
  isForbiddenQaAction,
  redactDiagnosticText,
} from "./ios-appium-functional-test.mjs";

const PROFILES = Object.freeze({
  deep: Object.freeze([
    "home",
    "onboarding-keyboard",
    "financial",
    "settings",
    "reduced-motion",
    "roles",
    "permissions",
  ]),
  compact: Object.freeze([
    "home",
    "onboarding-keyboard",
    "financial",
    "settings",
    "roles",
  ]),
});

export function androidProfileCheckpoints(profile) {
  const value = PROFILES[profile];
  if (!value) throw new Error(`Unknown Android BrowserStack QA profile: ${profile}`);
  return value;
}

const required = [
  "BROWSERSTACK_USERNAME",
  "BROWSERSTACK_ACCESS_KEY",
  "BROWSERSTACK_ANDROID_APP_URL",
  "BS_DEVICE_NAME",
  "BS_OS_VERSION",
  "BS_QA_PROFILE",
];

let profile;
let activeCheckpoint = "session-start";
let activeSelector = null;

function secrets() {
  return [
    process.env.BROWSERSTACK_USERNAME,
    process.env.BROWSERSTACK_ACCESS_KEY,
    process.env.BROWSERSTACK_ANDROID_APP_URL,
  ].filter(Boolean);
}

function safe(value) {
  return redactDiagnosticText(value, secrets());
}

function initializeFromEnv() {
  for (const name of required) {
    if (!process.env[name]) throw new Error(`Missing required env var: ${name}`);
  }
  profile = process.env.BS_QA_PROFILE;
  androidProfileCheckpoints(profile);
  return {
    path: "/wd/hub",
    hostname: "hub.browserstack.com",
    port: 443,
    protocol: "https",
    user: process.env.BROWSERSTACK_USERNAME,
    key: process.env.BROWSERSTACK_ACCESS_KEY,
    logLevel: "warn",
    capabilities: {
      platformName: "Android",
      "appium:automationName": "UiAutomator2",
      "appium:app": process.env.BROWSERSTACK_ANDROID_APP_URL,
      "appium:deviceName": process.env.BS_DEVICE_NAME,
      "appium:osVersion": process.env.BS_OS_VERSION,
      "appium:autoGrantPermissions": false,
      "appium:disableWindowAnimation": false,
      "bstack:options": {
        projectName: "MORT",
        buildName: `mort-android-qa-${process.env.GITHUB_SHA ?? "local"}`,
        sessionName: `functional-${profile}-${process.env.BS_DEVICE_NAME}-${process.env.BS_OS_VERSION}`,
      },
    },
  };
}

function uiEscape(value) {
  return String(value).replace(/\\/g, "\\\\").replace(/"/g, '\\"');
}

async function firstDisplayed(driver, selectors, timeoutMs = 20000) {
  let lastError;
  for (const selector of selectors) {
    try {
      activeSelector = selector;
      const el = await driver.$(selector);
      await el.waitForExist({ timeout: Math.min(timeoutMs, 6000) });
      if (await el.isDisplayed()) return el;
    } catch (error) {
      lastError = error;
    }
  }
  throw new Error(
    `No Android selector resolved: ${selectors.join(" | ")}; last error=${safe(lastError?.message ?? lastError)}`,
  );
}

async function byLabel(driver, label, timeoutMs = 20000) {
  const escaped = uiEscape(label);
  try {
    return await firstDisplayed(
      driver,
      [
        `~${label}`,
        `android=new UiSelector().resourceId("${escaped}")`,
        `android=new UiSelector().descriptionContains("${escaped}")`,
        `android=new UiSelector().textContains("${escaped}")`,
        `//*[@resource-id="${escaped}"]`,
      ],
      timeoutMs,
    );
  } catch (initialError) {
    // Flutter exposes only the currently visible portion of many ScrollViews
    // to UiAutomator. Scroll semantics into view before declaring a checkpoint
    // missing so lower settings/role actions are tested instead of false-failed.
    try {
      return await firstDisplayed(
        driver,
        [
          `android=new UiScrollable(new UiSelector().scrollable(true)).scrollIntoView(new UiSelector().resourceId("${escaped}"))`,
          `android=new UiScrollable(new UiSelector().scrollable(true)).scrollIntoView(new UiSelector().descriptionContains("${escaped}"))`,
          `android=new UiScrollable(new UiSelector().scrollable(true)).scrollIntoView(new UiSelector().textContains("${escaped}"))`,
        ],
        timeoutMs,
      );
    } catch (scrollError) {
      throw new Error(
        `No Android label resolved after scroll fallback: ${label}; initial=${safe(initialError?.message ?? initialError)}; scroll=${safe(scrollError?.message ?? scrollError)}`,
      );
    }
  }
}

async function tapLabel(driver, label) {
  if (isForbiddenQaAction(label)) {
    throw new Error(`Refusing forbidden QA action: ${label}`);
  }

  // Human-readable labels can collide with non-clickable section headers
  // (for example "Accessibility" inside Settings). Prefer a clickable
  // semantic node first so navigation taps do not silently hit a heading.
  if (!label.startsWith("qa-")) {
    const escaped = uiEscape(label);
    try {
      const actionable = await firstDisplayed(
        driver,
        [
          `//*[@clickable="true" and (contains(@content-desc,"${escaped}") or contains(@text,"${escaped}"))]`,
        ],
        6000,
      );
      await actionable.click();
      return;
    } catch {}
  }

  const el = await byLabel(driver, label);
  await el.click();
}

async function screenshot(driver, name) {
  const png = await driver.takeScreenshot();
  const path = `browserstack-android-${profile}-${name}.png`;
  await writeFile(path, Buffer.from(png, "base64"));
  console.log(`Saved ${path}`);
}

async function goHome(driver) {
  await byLabel(driver, "qa-home-landmark", 30000);
}

async function backToHome(driver) {
  for (let attempt = 0; attempt < 3; attempt += 1) {
    const home = await driver.$("~qa-home-landmark");
    if (await home.isExisting()) return;
    await driver.back();
    await driver.pause(700);
    const leave = await driver.$("~Leave setup");
    if (await leave.isExisting()) {
      await leave.click();
      await driver.pause(700);
    }
  }
  await goHome(driver);
}

async function androidTextField(driver, label) {
  const escaped = uiEscape(label);
  return firstDisplayed(driver, [
    `android=new UiSelector().className("android.widget.EditText").descriptionContains("${escaped}")`,
    `android=new UiSelector().className("android.widget.EditText").textContains("${escaped}")`,
    `//android.widget.EditText[contains(@content-desc,"${escaped}") or contains(@text,"${escaped}")]`,
  ]);
}

async function checkpointHome(driver) {
  await goHome(driver);
  await screenshot(driver, "home");
}

async function checkpointOnboardingKeyboard(driver) {
  await tapLabel(driver, "qa-open-onboarding");

  // The DOB control exposes an EditText semantic node but intentionally behaves
  // like a date control on newer Android versions, so it is not a reliable IME
  // target. Use the ordinary Display name field to prove real soft-keyboard
  // behavior while still exercising the same onboarding screen.
  activeSelector = "(//android.widget.EditText)[2]";
  const displayName = await firstDisplayed(driver, [activeSelector]);
  await displayName.click();
  await driver.pause(900);

  const keyboardShown = await driver.isKeyboardShown();
  assert.equal(
    keyboardShown,
    true,
    "Android keyboard did not become visible for onboarding Display name",
  );

  await displayName.setValue("MORT QA");
  await driver.pause(400);
  const entered =
    String(await displayName.getText()).trim() ||
    String(await displayName.getAttribute("text") ?? "").trim();
  assert.ok(
    entered.includes("MORT QA"),
    `Display name field did not retain typed input; value="${safe(entered)}"`,
  );

  await screenshot(driver, "keyboard-visible");
  try {
    await driver.hideKeyboard();
  } catch {}
  await driver.pause(400);
  assert.equal(
    await driver.isKeyboardShown(),
    false,
    "Android keyboard remained visible after hideKeyboard",
  );

  await screenshot(driver, "onboarding-keyboard-dismissed");
  await backToHome(driver);
}

async function checkpointFinancial(driver) {
  await tapLabel(driver, "qa-open-financial");

  // Prove the real product surface loaded first, then prefer the QA semantics
  // identifier when Android exports it. Some Flutter/UiAutomator combinations
  // do not expose Semantics.identifier consistently, so fall back to the
  // deterministic user-visible zero-state copy instead of false-failing.
  await byLabel(driver, "Financial Safety");
  try {
    await byLabel(driver, "qa-financial-zero-state", 8000);
  } catch {
    await byLabel(
      driver,
      "Your financial record starts when you complete work.",
      12000,
    );
  }

  await screenshot(driver, "financial");
  await backToHome(driver);
}

async function checkpointSettings(driver) {
  await tapLabel(driver, "qa-open-settings");
  await byLabel(driver, "qa-settings-header");
  for (const label of ["Profile", "Accessibility", "Job & payment history"]) {
    await byLabel(driver, label);
  }
  await screenshot(driver, "settings");
  await backToHome(driver);
}

async function checkpointReducedMotion(driver) {
  await tapLabel(driver, "qa-open-settings");
  await tapLabel(driver, "Accessibility");
  const toggle = await byLabel(driver, "Reduce motion");
  const before = String(await toggle.getAttribute("checked") ?? "").toLowerCase();
  if (before !== "true") await toggle.click();
  await driver.pause(500);

  const refreshed = await byLabel(driver, "Reduce motion");
  const after = String(await refreshed.getAttribute("checked") ?? "").toLowerCase();
  assert.equal(after, "true", "Reduce motion switch did not report checked=true");
  await screenshot(driver, "reduced-motion-enabled");

  await driver.back();
  await driver.pause(500);
  await tapLabel(driver, "Accessibility");
  const persisted = await byLabel(driver, "Reduce motion");
  const persistedState = String(await persisted.getAttribute("checked") ?? "").toLowerCase();
  assert.equal(persistedState, "true", "Reduce motion preference did not persist after navigation");
  await driver.back();
  await backToHome(driver);
}

async function assertRole(driver, homeButton, expectedLabels, name) {
  await tapLabel(driver, homeButton);
  for (const label of expectedLabels) await byLabel(driver, label, 30000);
  await screenshot(driver, `role-${name}`);
  await driver.back();
  await goHome(driver);
}

async function checkpointRoles(driver) {
  await assertRole(
    driver,
    "qa-open-teen",
    ["Browse jobs", "Applications", "Profile", "Messages"],
    "teen",
  );
  await assertRole(
    driver,
    "qa-open-adult",
    ["Post a job", "My jobs", "Applicants", "Messages", "Settings"],
    "adult",
  );
  await assertRole(
    driver,
    "qa-open-guardian",
    ["Review approvals", "Linked teens", "Permissions", "Settings"],
    "guardian",
  );
  await assertRole(
    driver,
    "qa-open-admin",
    ["Review reports", "Jobs", "Payment operations", "Support"],
    "admin",
  );
}

async function checkpointPermissions(driver) {
  await tapLabel(driver, "qa-open-permissions");
  await byLabel(driver, "qa-permissions-explanation");
  await screenshot(driver, "permissions");
  await backToHome(driver);
}

const runners = {
  home: checkpointHome,
  "onboarding-keyboard": checkpointOnboardingKeyboard,
  financial: checkpointFinancial,
  settings: checkpointSettings,
  "reduced-motion": checkpointReducedMotion,
  roles: checkpointRoles,
  permissions: checkpointPermissions,
};

async function sessionDiagnostics(sessionId, qaProfile) {
  const auth = Buffer.from(
    `${process.env.BROWSERSTACK_USERNAME}:${process.env.BROWSERSTACK_ACCESS_KEY}`,
  ).toString("base64");
  const headers = { Authorization: `Basic ${auth}` };
  const result = { overflowDetected: false, fatalDetected: false };
  try {
    const metaRes = await fetch(
      `https://api-cloud.browserstack.com/app-automate/sessions/${sessionId}.json`,
      { headers },
    );
    if (!metaRes.ok) throw new Error(`session metadata HTTP ${metaRes.status}`);
    const body = await metaRes.json();
    const session = body.automation_session ?? body;
    const safeMeta = {
      sessionId,
      status: session.status ?? null,
      reason: session.reason == null ? null : safe(session.reason),
      device: session.device ?? null,
      os: session.os ?? null,
      osVersion: session.os_version ?? null,
      duration: session.duration ?? null,
    };
    await writeFile(
      `browserstack-android-session-${qaProfile}.json`,
      `${JSON.stringify(safeMeta, null, 2)}\n`,
    );

    if (session.device_logs_url) {
      const logRes = await fetch(session.device_logs_url, { headers });
      if (logRes.ok) {
        const raw = safe(await logRes.text());
        await writeFile(`browserstack-android-device-log-${qaProfile}.txt`, raw);
        result.overflowDetected = /A RenderFlex overflowed|overflowed by .* pixels|RenderFlex.*overflow/i.test(raw);
        result.fatalDetected = /FATAL EXCEPTION|AndroidRuntime.*FATAL|Process: com\.mortapp\.mobile.*has died/i.test(raw);
      }
    }
    if (session.appium_logs_url) {
      const appiumRes = await fetch(session.appium_logs_url, { headers });
      if (appiumRes.ok) {
        await writeFile(
          `browserstack-android-appium-log-${qaProfile}.txt`,
          safe(await appiumRes.text()),
        );
      }
    }
  } catch (error) {
    console.error(`Diagnostics failed: ${safe(error?.message ?? error)}`);
  }
  return result;
}

async function captureFailure(driver, error) {
  const stem = `browserstack-android-${profile}-${activeCheckpoint}`;
  try {
    const png = await driver.takeScreenshot();
    await writeFile(`${stem}-failure.png`, Buffer.from(png, "base64"));
  } catch {}
  try {
    await writeFile(`${stem}-page-source.xml`, safe(await driver.getPageSource()));
  } catch {}
  await writeFile(
    `${stem}-diagnostics.json`,
    `${JSON.stringify({
      checkpoint: activeCheckpoint,
      selector: activeSelector,
      message: safe(error?.message ?? error),
      device: process.env.BS_DEVICE_NAME,
      osVersion: process.env.BS_OS_VERSION,
    }, null, 2)}\n`,
  );
}

async function main() {
  const opts = initializeFromEnv();
  console.log(
    `Starting Android BrowserStack QA: profile=${profile} device=${process.env.BS_DEVICE_NAME} Android ${process.env.BS_OS_VERSION}`,
  );
  const driver = await remote(opts);
  const sessionId = driver.sessionId;
  let failed = false;

  try {
    await driver.pause(12000);
    for (const checkpoint of androidProfileCheckpoints(profile)) {
      activeCheckpoint = checkpoint;
      console.log(`Running checkpoint: ${checkpoint}`);
      await runners[checkpoint](driver);
      console.log(`RESULT_${checkpoint.toUpperCase().replaceAll("-", "_")}=PASS`);
    }
  } catch (error) {
    failed = true;
    console.error("RESULT=FAIL");
    console.error(safe(error?.stack ?? error?.message ?? error));
    await captureFailure(driver, error);
  } finally {
    try { await driver.deleteSession(); } catch {}
  }

  const diagnostics = await sessionDiagnostics(sessionId, profile);
  assert.equal(diagnostics.fatalDetected, false, "Fatal Android process evidence found in BrowserStack device log");
  assert.equal(diagnostics.overflowDetected, false, "Flutter layout overflow evidence found in BrowserStack device log");

  if (failed) process.exitCode = 1;
  else console.log("RESULT=PASS");
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch((error) => {
    console.error("RESULT=FAIL");
    console.error(safe(error?.stack ?? error?.message ?? error));
    process.exitCode = 1;
  });
}
