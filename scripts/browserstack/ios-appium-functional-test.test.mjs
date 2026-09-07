import { test } from "node:test";
import assert from "node:assert/strict";

import {
  profileCheckpoints,
  isForbiddenQaAction,
  iosTextFieldPredicate,
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

test("iOS text field predicate matches the field by type plus label/value/placeholder", () => {
  assert.equal(
    iosTextFieldPredicate("Date of birth"),
    '-ios predicate string:type == "XCUIElementTypeTextField" AND ' +
      '(label == "Date of birth" OR value == "Date of birth" OR ' +
      'placeholderValue == "Date of birth")',
  );
});

test("iOS text field predicate escapes embedded double quotes", () => {
  assert.equal(
    iosTextFieldPredicate('Say "hi"'),
    '-ios predicate string:type == "XCUIElementTypeTextField" AND ' +
      '(label == "Say \\"hi\\"" OR value == "Say \\"hi\\"" OR ' +
      'placeholderValue == "Say \\"hi\\"")',
  );
});
