import assert from "node:assert/strict";
import test from "node:test";

import {
  buildCasePlan,
  classifyApplicationResponse,
  getCliExitCode,
  runGuardianApiChecks,
  validateFixture,
  validateTarget,
} from "./qa-guardian-application-reader-api.mjs";

const qaRef = "ckcxakhxqlkhppsxxjhv";
const anonKey = "sb_publishable_test-only";
const secretKeyPrefix = ["sb", "secret", "_"].join("");
const uuid = (n) => `00000000-0000-4000-8000-${String(n).padStart(12, "0")}`;

function connection(overrides = {}) {
  return {
    target: qaRef,
    projectRef: qaRef,
    url: `https://${qaRef}.supabase.co`,
    anonKey,
    ...overrides,
  };
}

function fixture() {
  const users = {};
  for (const [index, role] of [
    "teenA",
    "teenB",
    "linkedGuardian",
    "unlinkedGuardian",
    "revokedGuardian",
    "suspendedGuardian",
    "missingTeenConsentGuardian",
    "missingGuardianConsentGuardian",
    "wrongRoleAdult",
    "poster",
    "administrator",
  ].entries()) {
    users[role] = {
      email: `${role}@qa.example.test`,
      password: "fixture-only-not-a-secret",
      userId: uuid(index + 1),
    };
  }
  return {
    schemaVersion: 1,
    projectRef: qaRef,
    users,
    applications: {
      teenA: uuid(101),
      teenB: uuid(102),
      poster: uuid(103),
    },
  };
}

function apiMock(testFixture, options = {}) {
  const tokenUsers = new Map();
  const rpcReads = new Map();
  const applicationIds = new Map(Object.entries(testFixture.applications).map(([name, id]) => [id, name]));
  const userByEmail = new Map(Object.entries(testFixture.users).map(([name, user]) => [user.email, { name, user }]));
  const fetchImpl = async (url, init = {}) => {
    const parsed = new URL(url);
    if (parsed.pathname === "/auth/v1/token") {
      const credentials = JSON.parse(init.body);
      const found = userByEmail.get(credentials.email);
      if (options.authFailurePersona === found?.name) {
        return Response.json({ error_description: "private-auth-detail-do-not-log" }, { status: 400 });
      }
      const token = `private-token-${found.name}`;
      tokenUsers.set(token, found.name);
      return Response.json({ access_token: token, user: { id: found.user.userId } });
    }
    if (parsed.pathname === "/rest/v1/rpc/get_my_job_applications") {
      const payload = JSON.parse(init.body);
      const persona = tokenUsers.get((init.headers.authorization ?? "").replace(/^Bearer /, "")) ?? null;
      const application = applicationIds.get(payload.p_application_id);
      const readKey = `${persona}:${application}`;
      const readCount = (rpcReads.get(readKey) ?? 0) + 1;
      rpcReads.set(readKey, readCount);
      const allowed = (persona === "teenA" && application === "teenA") ||
        (persona === "linkedGuardian" && application === "teenA") ||
        (persona === "poster" && application === "poster");
      if (!allowed) {
        if (options.maskedUnauthorizedRow && persona === "teenB" && application === "teenA") {
          return Response.json({ ok: true, items: [{ id: payload.p_application_id, guardian_id: null }] });
        }
        return Response.json({ ok: true, items: [] });
      }
      const status = options.changeReplay && readKey === "teenA:teenA" && readCount > 1 ? "changed" : "pending";
      const guardianId = persona === "poster" ? null : testFixture.users.linkedGuardian?.userId ?? null;
      return Response.json({ ok: true, items: [{ id: payload.p_application_id, guardian_id: guardianId, status }] });
    }
    if (parsed.pathname === "/auth/v1/logout") return new Response(null, { status: 204 });
    throw new Error(`Unexpected mock request path ${parsed.pathname}`);
  };
  return { fetchImpl };
}

test("target validation accepts only the designated isolated QA project and an anon key", () => {
  assert.equal(validateTarget(connection()), qaRef);
  const encoded = (value) => Buffer.from(JSON.stringify(value)).toString("base64url");
  const qaJwt = `${encoded({ alg: "HS256", typ: "JWT" })}.${encoded({ role: "anon", ref: qaRef })}.fixture-signature`;
  const productionJwt = `${encoded({ alg: "HS256", typ: "JWT" })}.${encoded({ role: "anon", ref: "jxbnrkasktbhtiujkhay" })}.fixture-signature`;
  assert.equal(validateTarget(connection({ anonKey: qaJwt })), qaRef);
  assert.throws(() => validateTarget(connection({ anonKey: productionJwt })), /publishable or anon/);
});

test("target validation rejects production, local, deleted, and mismatched endpoints", () => {
  assert.throws(() => validateTarget(connection({ target: "production" })), /isolated QA/);
  assert.throws(() => validateTarget(connection({ projectRef: "jxbnrkasktbhtiujkhay" })), /project reference/);
  assert.throws(() => validateTarget(connection({ url: "https://jxbnrkasktbhtiujkhay.supabase.co" })), /URL/);
  assert.throws(() => validateTarget(connection({ url: "http://127.0.0.1:54321" })), /URL/);
});

test("target validation refuses service-role credentials and service-role opt-in flags", () => {
  assert.throws(() => validateTarget(connection({ anonKey: `${secretKeyPrefix}test-only` })), /publishable or anon/);
  assert.throws(() => validateTarget(connection({ serviceRoleKey: "present" })), /service-role/);
  assert.throws(() => validateTarget(connection({ allowServiceRole: "LOCAL_OR_STAGING_ONLY" })), /service-role/);
  const serviceJwt = `x.${Buffer.from(JSON.stringify({ role: "service_role" })).toString("base64url")}.x`;
  assert.throws(() => validateTarget(connection({ anonKey: serviceJwt })), /publishable or anon/);
});

test("fixture validation accepts only distinct supported authenticated personas and application fixtures", () => {
  assert.equal(validateFixture(fixture()).projectRef, qaRef);
  const incomplete = fixture();
  delete incomplete.users.revokedGuardian;
  assert.equal(validateFixture(incomplete).projectRef, qaRef);
  assert.throws(() => validateFixture({ ...fixture(), projectRef: "jxbnrkasktbhtiujkhay" }), /project reference/);
});

test("fixture validation accepts only available supported states so runnable personas are not blocked by missing fixtures", () => {
  const partial = fixture();
  partial.users = { teenA: partial.users.teenA };
  partial.applications = { teenA: partial.applications.teenA };
  const plan = buildCasePlan(partial);
  assert.deepEqual(plan.map((entry) => entry.name), [
    "teen A reads own application",
    "teen A repeated request preserves the same result",
    "anonymous caller receives no application data",
  ]);
});

test("fixture validation rejects malformed UUIDs and missing passwords without echoing values", () => {
  const malformed = fixture();
  malformed.applications.teenA = "not-a-uuid";
  assert.throws(() => validateFixture(malformed), /application ID/);
  const noPassword = fixture();
  noPassword.users.teenA.password = "";
  assert.throws(() => validateFixture(noPassword), /credentials/);
});

test("case plan exercises applicant, guardian, poster, admin, cross-account, and anonymous reads", () => {
  const plan = buildCasePlan(fixture());
  const names = new Set(plan.map((entry) => entry.name));
  for (const required of [
    "teen A reads own application",
    "teen A cannot read teen B application",
    "teen B cannot read teen A application",
    "linked Guardian reads linked application",
    "unlinked Guardian receives no application data",
    "revoked Guardian receives no application data",
    "suspended Guardian receives no application data",
    "Guardian with missing teen consent receives no application data",
    "Guardian with missing Guardian consent receives no application data",
    "wrong-role adult receives no application data",
    "poster reads own job application with Guardian ID masked",
    "poster cannot read another poster application",
    "administrator receives no data through the participant-only reader",
    "anonymous caller receives no application data",
    "teen A repeated request preserves the same result",
    "linked Guardian repeated request preserves the same result",
  ]) assert.ok(names.has(required), `missing case: ${required}`);
});

test("unauthorized response with any application row fails even when guardian_id is masked", () => {
  const result = classifyApplicationResponse({
    status: 200,
    body: { ok: true, items: [{ id: uuid(101), guardian_id: null }] },
  });
  assert.equal(result.denied, false);
  assert.equal(result.items.length, 1);
});

test("empty or explicitly denied RPC responses contain no application data", () => {
  assert.equal(classifyApplicationResponse({ status: 200, body: { ok: true, items: [] } }).denied, true);
  assert.equal(classifyApplicationResponse({ status: 200, body: { ok: false, code: "active_account_required" } }).denied, true);
  assert.equal(classifyApplicationResponse({ status: 403, body: { code: "42501" } }).denied, true);
});

test("allowed-response assertions can require exact guardian visibility or null masking", () => {
  const plan = buildCasePlan(fixture());
  const linked = plan.find((entry) => entry.name === "linked Guardian reads linked application");
  assert.equal(linked.expectedGuardianId, fixture().users.linkedGuardian.userId);
  const poster = plan.find((entry) => entry.name === "poster reads own job application with Guardian ID masked");
  assert.equal(poster.expectedGuardianId, null);
});

test("runtime target check refuses inherited generic production targeting and service-role environment", async () => {
  const { loadRuntimeConfig } = await import("./qa-guardian-application-reader-api.mjs");
  assert.throws(() => loadRuntimeConfig({
    MORT_QA_TARGET: qaRef,
    MORT_QA_PROJECT_REF: qaRef,
    MORT_QA_SUPABASE_URL: `https://${qaRef}.supabase.co`,
    MORT_QA_ANON_KEY: anonKey,
    MORT_SUPABASE_PROJECT_REF: "jxbnrkasktbhtiujkhay",
    MORT_QA_GUARDIAN_FIXTURE_FILE: "C:\\secure\\fixture.json",
  }), /generic Supabase project reference/);
  assert.throws(() => loadRuntimeConfig({
    MORT_QA_TARGET: qaRef,
    MORT_QA_PROJECT_REF: qaRef,
    MORT_QA_SUPABASE_URL: `https://${qaRef}.supabase.co`,
    MORT_QA_ANON_KEY: anonKey,
    SUPABASE_SERVICE_ROLE_KEY: "present",
    MORT_QA_GUARDIAN_FIXTURE_FILE: "C:\\secure\\fixture.json",
  }), /service-role/);
});

test("API harness exercises all planned personas, stable replay, and never logs credentials", async () => {
  const testFixture = fixture();
  const { fetchImpl } = apiMock(testFixture);
  const logs = [];
  const config = {
    url: `https://${qaRef}.supabase.co`,
    anonKey,
    fixture: testFixture,
  };
  const result = await runGuardianApiChecks(config, fetchImpl, (line) => logs.push(line));
  assert.equal(result.failed, 0);
  assert.equal(result.passed, buildCasePlan(testFixture).length);
  assert.equal(result.skipped, 1);
  assert.ok(logs.some((line) => line.includes("PASS teen A repeated request")));
  assert.ok(logs.some((line) => line.includes("PASS linked Guardian repeated request")));
  const logText = logs.join("\n");
  for (const secret of ["fixture-only-not-a-secret", "private-token-", "@qa.example.test"]) {
    assert.equal(logText.includes(secret), false, `logs exposed ${secret}`);
  }
});

test("API harness fails closed if an unauthorized masked row is returned", async () => {
  const testFixture = fixture();
  const { fetchImpl } = apiMock(testFixture, { maskedUnauthorizedRow: true });
  const logs = [];
  const result = await runGuardianApiChecks({ url: `https://${qaRef}.supabase.co`, anonKey, fixture: testFixture }, fetchImpl, (line) => logs.push(line));
  assert.equal(result.failed, 1);
  assert.ok(logs.some((line) => line.includes("FAIL teen B cannot read teen A application")));
  assert.equal(logs.join("\n").includes("guardian_id"), false);
});

test("API harness detects a replay response that changes after an identical request", async () => {
  const testFixture = fixture();
  const { fetchImpl } = apiMock(testFixture, { changeReplay: true });
  const logs = [];
  const result = await runGuardianApiChecks({ url: `https://${qaRef}.supabase.co`, anonKey, fixture: testFixture }, fetchImpl, (line) => logs.push(line));
  assert.equal(result.failed, 1);
  assert.ok(logs.some((line) => line.includes("FAIL teen A repeated request")));
});

test("API harness suppresses authentication response details", async () => {
  const testFixture = fixture();
  const { fetchImpl } = apiMock(testFixture, { authFailurePersona: "teenA" });
  const logs = [];
  const result = await runGuardianApiChecks({ url: `https://${qaRef}.supabase.co`, anonKey, fixture: testFixture }, fetchImpl, (line) => logs.push(line));
  assert.ok(result.failed >= 2);
  const logText = logs.join("\n");
  assert.equal(logText.includes("private-auth-detail-do-not-log"), false);
  assert.equal(logText.includes("teenA@qa.example.test"), false);
});

test("API harness counts unavailable role fixtures as skipped, never passed", async () => {
  const partialFixture = fixture();
  partialFixture.users = { teenA: partialFixture.users.teenA };
  partialFixture.applications = { teenA: partialFixture.applications.teenA };
  const { fetchImpl } = apiMock(partialFixture);
  const result = await runGuardianApiChecks({ url: `https://${qaRef}.supabase.co`, anonKey, fixture: partialFixture }, fetchImpl, () => {});
  assert.equal(result.passed, 3);
  assert.equal(result.failed, 0);
  assert.equal(result.skipped, 15);
  assert.ok(result.skippedCases.some((entry) => entry.name === "linked Guardian reads linked application" && entry.reason.includes("linkedGuardian")));
  assert.ok(result.skippedCases.some((entry) => entry.name === "expired session receives no application data"));
  assert.equal(getCliExitCode(result), 2);
});

test("API CLI exit status distinguishes clean pass, blocked coverage, and failures", () => {
  assert.equal(getCliExitCode({ passed: 1, failed: 0, skipped: 0 }), 0);
  assert.equal(getCliExitCode({ passed: 1, failed: 0, skipped: 1 }), 2);
  assert.equal(getCliExitCode({ passed: 0, failed: 1, skipped: 0 }), 1);
});
