import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const workflowPath = new URL("../.github/workflows/mort-signed-closed-test.yml", import.meta.url);
const workflow = await readFile(workflowPath, "utf8");
const buildStep = workflow.match(
  /- name: Build and verify signed APK and AAB[\s\S]*?(?=\n      - uses:|\n      - name:|$)/,
);
const containsServiceRoleReference = (source) =>
  /SUPABASE_SERVICE_ROLE_KEY/u.test(source);

assert.ok(buildStep, "signed closed-test build step must exist");
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
  "signed artifact build must not receive the Supabase service-role key",
);

console.log("PASS signed workflow has no service-role key at any scope");