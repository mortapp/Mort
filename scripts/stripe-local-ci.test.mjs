import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import { allocatePorts, close, isolatedConfig, listen, localEnvironment, portCount } from "./stripe-local-ci.mjs";

const id = "mort-stripe-ci-abcdef123456";
const ports = Array.from({ length: portCount }, (_, i) => 41234 + i);
const db = "postgresql://postgres:postgres@127.0.0.1:41235/postgres";
const api = "http://127.0.0.1:41234";
const config = readFileSync(new URL("../supabase/config.toml", import.meta.url), "utf8");

test("isolated config replaces all host ports and preserves application settings", () => {
  const changed = isolatedConfig(id, ports)(config);
  assert.match(changed, /^project_id = "mort-stripe-ci-abcdef123456"/);
  assert.match(changed, /\[db\][^\[]*port = 41235\nshadow_port = 41236/);
  assert.match(changed, /\[db.pooler\]\nport = 41237/);
  assert.match(changed, /\[inbucket\]\nport = 41239\nsmtp_port = 41240\npop3_port = 41241/);
  assert.match(changed, /\[edge_runtime\][^\[]*policy = "per_worker"[^\[]*inspector_port = 41243/);
  assert.match(changed, /\[functions\.identity-verification-webhook\]\nverify_jwt = false/);
  assert.doesNotMatch(changed, /\b5432[123]\b|project_id = "mort-mobile"/);
  assert.equal(new Set([...changed.matchAll(/(?:^|_)port = (\d+)/gm)].map((match) => match[1])).size, portCount);
});

test("validates the project namespace and ports and refuses a duplicate section", () => {
  assert.throws(() => isolatedConfig("mort-mobile", ports), /Invalid/);
  assert.throws(() => isolatedConfig(id, Array(portCount).fill(54322)), /Invalid/);
  assert.throws(() => isolatedConfig(id, ports)(`${config}\n[db]\nport=54322`), /Duplicate/);
});

test("allocates distinct host ports without touching an occupied port", async () => {
  const blocker = await listen();
  const occupied = blocker.address().port;
  try {
    await assert.rejects(listen(occupied), { code: "EADDRINUSE" });
    const selected = await allocatePorts();
    assert.equal(new Set(selected).size, portCount);
    assert.ok(!selected.includes(occupied));
    await assert.rejects(listen(occupied), { code: "EADDRINUSE" });
  } finally {
    await close(blocker);
  }
});

test("status accepts only exact local endpoints and both local keys", () => {
  const status = `API_URL="${api}"\nDB_URL="${db}"\nANON_KEY="local-anon"\nSERVICE_ROLE_KEY="local-service"\n`;
  assert.equal(localEnvironment(status, ports).MORT_QA_LOCAL_SUPABASE, "true");
  assert.throws(() => localEnvironment(status.replace(api, "https://example.test"), ports), /expected local endpoints/);
  assert.throws(() => localEnvironment(status.replace(db, db.replace("41235", "54322")), ports), /expected local endpoints/);
  assert.throws(() => localEnvironment(status.replace("local-service", ""), ports), /endpoints and keys/);
});
