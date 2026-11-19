import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const deletedProjectRefs = [["rakjydmg", "wwgtdislanbt"].join("")];
const qaProjectRef = "ckcxakhxqlkhppsxxjhv";

const sandboxScript = await readFile(new URL("./stripe-sandbox-e2e.ps1", import.meta.url), "utf8");
const gateScript = await readFile(new URL("./stripe-pre-provider-test-gate.ps1", import.meta.url), "utf8");
assert.match(sandboxScript, new RegExp(`\\$ProjectRef = '${qaProjectRef}'`));
assert.match(gateScript, new RegExp(`\\$ProjectRef = '${qaProjectRef}'`));

for (const path of [
  "./create-old-project-test-users.mjs",
  "./delete-old-project-storage.mjs",
  "./qa-old-project-rls.mjs",
  "./qa-old-project-smoke.mjs",
]) {
  const source = await readFile(new URL(path, import.meta.url), "utf8");
  for (const deletedRef of deletedProjectRefs) assert.equal(source.includes(deletedRef), false, `${path} contains ${deletedRef}`);
  assert.match(source, /retired/i, `${path} must remain explicitly retired`);
}

console.log(JSON.stringify({ status: "PASS", qa_project_ref: qaProjectRef, deleted_project_executable_targets: 0 }));
