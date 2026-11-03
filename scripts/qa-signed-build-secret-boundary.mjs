import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const workflowPath = new URL("../.github/workflows/mort-public-production-aab.yml", import.meta.url);
const workflow = await readFile(workflowPath, "utf8");
const buildStep = workflow.match(
  /- name: Build and verify public production AAB[\s\S]*?(?=\n      - uses:|\n      - name:|$)/,
);
const containsServiceRoleReference = (source) =>
  /SUPABASE_SERVICE_ROLE_KEY/u.test(source);

assert.ok(buildStep, "signed public production build step must exist");
assert.equal(
  containsServiceRoleReference(
    [
      "jobs:",
      "  signed-android:",
      "    env:",
      "      SUPABASE_SERVICE_ROLE_KEY: configured-secret",
    ].join("\n"),
  ),
  true,
  "the boundary check must detect a job-level inherited service-role key",
);
assert.equal(
  containsServiceRoleReference(workflow),
  false,
  "the workflow must not reference the service-role key at any scope",
);
assert.ok(
  !buildStep[0].includes("SUPABASE_SERVICE_ROLE_KEY"),
  "signed production artifact build must not receive the Supabase service-role key",
);

console.log("PASS signed public production workflow has no service-role key at any scope");
