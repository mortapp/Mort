import { test } from "node:test";
import assert from "node:assert/strict";

import {
  profileCheckpoints,
  isForbiddenQaAction,
} from "./ios-appium-functional-test.mjs";

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
