import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

import { delayUntilStableRateLimitWindowMs } from "../support-rate-limit-window.mjs";

test("quota burst runs when a full fixed window is available", () => {
  assert.equal(delayUntilStableRateLimitWindowMs(570), 0);
  assert.equal(delayUntilStableRateLimitWindowMs(571), 30_000);
});

test("quota burst waits past the next fixed-window boundary", () => {
  assert.equal(delayUntilStableRateLimitWindowMs(599.5), 1_500);
  assert.equal(delayUntilStableRateLimitWindowMs(600.5), 0);
});

test("support chat QA waits before its fixed-window quota burst", () => {
  const source = readFileSync(
    new URL("../qa-support-chatbot.mjs", import.meta.url),
    "utf8",
  );

  assert.equal(
    source.includes("await waitForStableSupportChatQuotaWindow()"),
    true,
    "the integration QA must keep its quota burst inside one fixed window",
  );
});
