import { test } from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { mkdtemp } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import { join } from "node:path";
import { tmpdir } from "node:os";

test("workflow matrix guards node status under inherited bash -e and uploads diagnostics", async () => {
  const workflow = await readFile(new URL("../../.github/workflows/mort-ios-browserstack.yml", import.meta.url), "utf8");
  assert.match(workflow, /if BS_DEVICE_NAME=.*node ios-appium-functional-test\.mjs; then\s+rc=0\s+else\s+rc=\$\?\s+fi/s);
  assert.match(workflow, /browserstack-\*\.xml/);
  assert.match(workflow, /browserstack-\*\.json/);
  assert.match(workflow, /browserstack-session-\*\.json/);
});

test("workflow matrix runs all profiles under bash -e and aggregates failure", async (t) => {
  const bash = "C:/Program Files/Git/bin/bash.exe";
  const probe = spawnSync(bash, ["--version"], { encoding: "utf8" });
  if (probe.error) return t.skip("Git for Windows bash is unavailable");
  const workflow = await readFile(new URL("../../.github/workflows/mort-ios-browserstack.yml", import.meta.url), "utf8");
  const block = workflow.match(/          set -uo pipefail\n([\s\S]*?)          exit \$overall/)?.[1];
  assert.ok(block, "matrix shell block is present");
  const shell = block.split("\n").map((line) => line.slice(10)).join("\n");
  const cwd = await mkdtemp(join(tmpdir(), "mort-matrix-"));
  const result = spawnSync(bash, ["-c", `set -euo pipefail\nnode() { echo "$BS_QA_PROFILE" >> profiles.txt; [ "$BS_QA_PROFILE" != deep ]; }\n${shell}\nexit $overall`], { cwd, encoding: "utf8" });
  assert.equal(result.status, 1);
  const profiles = await readFile(join(cwd, "profiles.txt"), "utf8");
  assert.deepEqual(profiles.trim().split(/\r?\n/), ["deep", "limited", "floor"]);
});
