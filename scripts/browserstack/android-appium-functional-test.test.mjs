import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

import { androidProfileCheckpoints } from "./android-appium-functional-test.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../..");

test("deep Android profile covers the remaining device interaction gates", () => {
  assert.deepEqual(androidProfileCheckpoints("deep"), [
    "home",
    "onboarding-keyboard",
    "financial",
    "settings",
    "reduced-motion",
    "roles",
    "permissions",
  ]);
});

test("compact Android profile exercises layout-sensitive surfaces", () => {
  assert.deepEqual(androidProfileCheckpoints("compact"), [
    "home",
    "onboarding-keyboard",
    "financial",
    "settings",
    "roles",
  ]);
});

test("unknown Android QA profile fails closed", () => {
  assert.throws(
    () => androidProfileCheckpoints("unknown"),
    /Unknown Android BrowserStack QA profile/,
  );
});

test("BrowserStack APK build mode remains explicit and opt-in", async () => {
  const source = await readFile(
    path.join(root, "scripts", "build-android-device-test-apk.ps1"),
    "utf8",
  );
  assert.match(source, /\[switch\]\$BrowserStackQa/);
  assert.match(source, /MORT_BROWSERSTACK_QA_MODE=true/);
  assert.match(source, /if \(\$BrowserStackQa\)/);
});

test("QA router exposes the accessibility screen used for reduced-motion proof", async () => {
  const source = await readFile(
    path.join(
      root,
      "flutter_mort",
      "lib",
      "features",
      "qa",
      "browserstack_qa_app.dart",
    ),
    "utf8",
  );
  assert.match(source, /path: '\/settings\/accessibility'/);
  assert.match(source, /ExperienceSettingsScreen/);
});

test("Android selector fallback scrolls offscreen Flutter semantics into view", async () => {
  const source = await readFile(
    path.join(root, "scripts", "browserstack", "android-appium-functional-test.mjs"),
    "utf8",
  );
  assert.match(source, /UiSelector\(\)\.resourceId/);
  assert.match(source, /UiScrollable\(new UiSelector\(\)\.scrollable\(true\)\)/);
  assert.match(source, /scrollIntoView\(new UiSelector\(\)\.resourceId/);
  assert.match(source, /scrollIntoView\(new UiSelector\(\)\.descriptionContains/);
  assert.match(source, /scrollIntoView\(new UiSelector\(\)\.textContains/);
});


test("financial checkpoint falls back to deterministic visible zero-state copy", async () => {
  const source = await readFile(
    path.join(root, "scripts", "browserstack", "android-appium-functional-test.mjs"),
    "utf8",
  );
  assert.match(source, /byLabel\(driver, "Financial Safety"\)/);
  assert.match(source, /qa-financial-zero-state/);
  assert.match(
    source,
    /Your financial record starts when you complete work\./,
  );
});


test("tapLabel prefers clickable Android semantics over section headings", async () => {
  const source = await readFile(
    path.join(root, "scripts", "browserstack", "android-appium-functional-test.mjs"),
    "utf8",
  );
  assert.match(source, /label\.startsWith\("qa-"\)/);
  assert.match(
    source,
    /\*\[@clickable="true" and \(contains\(@content-desc,/,
  );
  assert.match(source, /await actionable\.click\(\)/);
});
