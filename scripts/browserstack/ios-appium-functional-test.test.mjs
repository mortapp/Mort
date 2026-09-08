import { test } from "node:test";
import assert from "node:assert/strict";

import {
  captureFailureDiagnostics,
  downloadSessionDiagnostics,
  redactDiagnosticText,
  profileCheckpoints,
  isForbiddenQaAction,
  iosTextFieldPredicate,
} from "./ios-appium-functional-test.mjs";

test("diagnostic redaction removes credentials, Basic auth, and signed URL data", () => {
  const raw = "user qa-user key access-secret Authorization: Basic dXNlcjprZXk= https://name:pass@example.test/log?token=signed&x=1";
  const safe = redactDiagnosticText(raw, ["qa-user", "access-secret"]);
  assert.doesNotMatch(safe, /qa-user|access-secret|dXNlcjprZXk=|name:pass|token=signed/);
  assert.match(safe, /\[REDACTED\]/);
});

test("failure diagnostics isolate captures and preserve safe metadata", async () => {
  const writes = new Map();
  const driver = {
    sessionId: "session-123",
    takeScreenshot: async () => "cG5n",
    getPageSource: async () => "<App secret=\"access-secret\"><TextField label=\"Date of birth\"/></App>",
    getContexts: async () => ["NATIVE_APP"],
    $$: async () => [{
      getAttribute: async (name) => ({ type: "XCUIElementTypeTextField", label: "Date of birth", value: "MM/DD/YYYY", enabled: "true", visible: "true" })[name],
    }],
  };
  await captureFailureDiagnostics({
    driver,
    checkpoint: "onboarding",
    error: new Error("element wasn't found"),
    qaProfile: "deep",
    deviceName: "iPhone 15",
    osVersion: "17",
    selector: "safe-selector",
    sensitiveValues: ["access-secret"],
    writeFileImpl: async (path, value) => writes.set(path, value),
  });
  assert.ok(writes.has("browserstack-deep-onboarding-failure.png"));
  assert.match(String(writes.get("browserstack-deep-onboarding-page-source.xml")), /TextField/);
  assert.doesNotMatch(String(writes.get("browserstack-deep-onboarding-page-source.xml")), /access-secret/);
  const metadata = JSON.parse(String(writes.get("browserstack-deep-onboarding-diagnostics.json")));
  assert.deepEqual(metadata.contexts, ["NATIVE_APP"]);
  assert.equal(metadata.error.message, "element wasn't found");
  assert.equal(metadata.device.name, "iPhone 15");
  assert.equal(metadata.session.id, "session-123");
  assert.equal(metadata.nativeInputs[0].label, "Date of birth");
});

test("one failed diagnostic does not suppress remaining captures", async () => {
  const writes = [];
  await captureFailureDiagnostics({
    driver: {
      sessionId: "s",
      takeScreenshot: async () => { throw new Error("screenshot unavailable"); },
      getPageSource: async () => "<App/>",
      getContexts: async () => ["NATIVE_APP"],
      $$: async () => [],
    },
    checkpoint: "home",
    error: new Error("original functional failure"),
    qaProfile: "deep",
    deviceName: "iPhone 15",
    osVersion: "17",
    writeFileImpl: async (path) => writes.push(path),
  });
  assert.ok(writes.includes("browserstack-deep-home-page-source.xml"));
  assert.ok(writes.includes("browserstack-deep-home-diagnostics.json"));
});

test("session diagnostics whitelist metadata and reject unsuccessful optional logs", async () => {
  const writes = new Map();
  const responses = [
    { ok: true, status: 200, json: async () => ({ automation_session: { status: "failed", reason: "test", device: "iPhone", os_version: "17", device_logs_url: "https://signed.invalid/secret", access_key: "DO-NOT-SAVE" } }) },
    { ok: false, status: 404, text: async () => "<Error>NoSuchKey</Error>" },
  ];
  await downloadSessionDiagnostics({
    sessionId: "safe-id",
    qaProfile: "deep",
    fetchImpl: async () => responses.shift(),
    authorization: "Basic secret",
    writeFileImpl: async (path, value) => writes.set(path, value),
  });
  const saved = String(writes.get("browserstack-session-deep.json"));
  assert.match(saved, /\"status\": \"failed\"/);
  assert.doesNotMatch(saved, /signed\.invalid|DO-NOT-SAVE/);
  assert.equal(writes.has("browserstack-device-log-deep.txt"), false);
});

test("session diagnostics download successful Appium logs without persisting its signed URL", async () => {
  const writes = new Map();
  const responses = [
    { ok: true, status: 200, json: async () => ({ automation_session: { status: "failed", appium_logs_url: "https://signed.invalid/appium?token=secret" } }) },
    { ok: true, status: 200, text: async () => "Appium failure without secrets" },
  ];
  await downloadSessionDiagnostics({
    sessionId: "safe-id",
    qaProfile: "deep",
    fetchImpl: async () => responses.shift(),
    authorization: "Basic secret",
    writeFileImpl: async (path, value) => writes.set(path, value),
  });
  assert.equal(String(writes.get("browserstack-appium-log-deep.txt")), "Appium failure without secrets");
  assert.doesNotMatch(String(writes.get("browserstack-session-deep.json")), /signed\.invalid|token=secret/);
});

test("session metadata write failure does not suppress Appium log download", async () => {
  const writes = [];
  const responses = [
    { ok: true, status: 200, json: async () => ({ automation_session: { status: "failed", appium_logs_url: "https://logs.invalid/appium" } }) },
    { ok: true, status: 200, text: async () => "appium" },
  ];
  await downloadSessionDiagnostics({
    sessionId: "safe-id",
    qaProfile: "deep",
    fetchImpl: async () => responses.shift(),
    writeFileImpl: async (path) => {
      if (path.includes("session")) throw new Error("disk failed");
      writes.push(path);
    },
  });
  assert.ok(writes.includes("browserstack-appium-log-deep.txt"));
});

test("relevant device-log console lines redact known credentials", async () => {
  const previousKey = process.env.BROWSERSTACK_ACCESS_KEY;
  process.env.BROWSERSTACK_ACCESS_KEY = "access-secret";
  const lines = [];
  const previousLog = console.log;
  console.log = (...values) => lines.push(values.join(" "));
  try {
    const responses = [
      { ok: true, status: 200, json: async () => ({ automation_session: { status: "failed", device_logs_url: "https://logs.invalid/device" } }) },
      { ok: true, status: 200, text: async () => "Fatal crash access-secret" },
    ];
    await downloadSessionDiagnostics({
      sessionId: "safe-id",
      qaProfile: "deep",
      fetchImpl: async () => responses.shift(),
      writeFileImpl: async () => {},
    });
  } finally {
    console.log = previousLog;
    if (previousKey === undefined) delete process.env.BROWSERSTACK_ACCESS_KEY;
    else process.env.BROWSERSTACK_ACCESS_KEY = previousKey;
  }
  assert.match(lines.join("\n"), /Fatal crash \[REDACTED\]/);
  assert.doesNotMatch(lines.join("\n"), /access-secret/);
});

test("deep profile covers every QA checkpoint", () => {
  assert.deepEqual(profileCheckpoints("deep"), [
    "home",
    "onboarding",
    "legal",
    "safety",
    "financial",
    "settings",
    "permissions",
  ]);
});

test("limited profile covers a reduced checkpoint set", () => {
  assert.deepEqual(profileCheckpoints("limited"), [
    "home",
    "onboarding",
    "legal",
    "safety",
  ]);
});

test("floor profile covers the narrow-layout checkpoint set", () => {
  assert.deepEqual(profileCheckpoints("floor"), [
    "home",
    "safety",
    "financial",
    "settings",
  ]);
});

test("an unknown profile throws instead of silently running nothing", () => {
  assert.throws(
    () => profileCheckpoints("unknown"),
    /Unknown BrowserStack QA profile/,
  );
});

test("forbidden QA actions are recognized regardless of profile", () => {
  assert.equal(isForbiddenQaAction("Send Safety Ping"), true);
  assert.equal(isForbiddenQaAction("Add an expense"), true);
  assert.equal(isForbiddenQaAction("Call 911"), true);
  assert.equal(isForbiddenQaAction("Choose photo"), true);
  assert.equal(isForbiddenQaAction("Take photo"), true);
  assert.equal(isForbiddenQaAction("Remove"), true);
  assert.equal(isForbiddenQaAction("Create a report"), true);
  assert.equal(isForbiddenQaAction("Block user"), true);
});

test("ordinary navigation actions are never forbidden", () => {
  assert.equal(isForbiddenQaAction("Back"), false);
  assert.equal(isForbiddenQaAction("Save account"), false);
  assert.equal(isForbiddenQaAction("Financial"), false);
});

test("iOS text field predicate matches decorated labels containing the field name", () => {
  assert.equal(
    iosTextFieldPredicate("Date of birth"),
    '-ios predicate string:type == "XCUIElementTypeTextField" AND ' +
      '(label CONTAINS "Date of birth" OR value CONTAINS "Date of birth" OR ' +
      'placeholderValue CONTAINS "Date of birth")',
  );
});

test("iOS text field predicate escapes embedded double quotes", () => {
  assert.equal(
    iosTextFieldPredicate('Say "hi"'),
    '-ios predicate string:type == "XCUIElementTypeTextField" AND ' +
      '(label CONTAINS "Say \\"hi\\"" OR value CONTAINS "Say \\"hi\\"" OR ' +
      'placeholderValue CONTAINS "Say \\"hi\\"")',
  );
});
