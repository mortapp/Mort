import { readFileSync, realpathSync } from "node:fs";
import { isAbsolute, relative, resolve, sep } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

export const QA_PROJECT_REF = "ckcxakhxqlkhppsxxjhv";
const QA_URL = `https://${QA_PROJECT_REF}.supabase.co`;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const KNOWN_USERS = [
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
];

function decodeJwtPayload(token) {
  try {
    const parts = token.split(".");
    if (parts.length !== 3) return null;
    return JSON.parse(Buffer.from(parts[1], "base64url").toString("utf8"));
  } catch {
    return null;
  }
}

function isPublishableOrAnonKey(key) {
  if (typeof key !== "string" || key.length === 0) return false;
  if (key.startsWith("sb_publishable_")) return true;
  if (key.startsWith("sb_secret_")) return false;
  return decodeJwtPayload(key)?.role === "anon";
}

export function validateTarget({
  target,
  projectRef,
  url,
  anonKey,
  genericProjectRef,
  serviceRoleKey,
  allowServiceRole,
}) {
  if (target !== QA_PROJECT_REF || projectRef !== QA_PROJECT_REF) {
    throw new Error("Guardian API tests require the designated isolated QA project reference.");
  }
  if (url !== QA_URL) {
    throw new Error("Guardian API tests require the exact isolated QA API URL.");
  }
  if (genericProjectRef && genericProjectRef !== QA_PROJECT_REF) {
    throw new Error("A generic Supabase project reference conflicts with the isolated QA target.");
  }
  if (serviceRoleKey || allowServiceRole) {
    throw new Error("Guardian API tests refuse service-role keys and service-role opt-in flags.");
  }
  if (!isPublishableOrAnonKey(anonKey)) {
    throw new Error("Provide a publishable or anon API key; service-role and secret keys are refused.");
  }
  return QA_PROJECT_REF;
}

function assertUuid(value, description) {
  if (typeof value !== "string" || !UUID.test(value)) {
    throw new Error(`Fixture ${description} must be a UUID.`);
  }
}

export function validateFixture(fixture) {
  if (!fixture || fixture.schemaVersion !== 1 || fixture.projectRef !== QA_PROJECT_REF) {
    throw new Error("Fixture file must use schemaVersion 1 and the isolated QA project reference.");
  }
  if (!fixture.users || typeof fixture.users !== "object") {
    throw new Error("Fixture file is missing authenticated persona credentials.");
  }
  for (const [persona, user] of Object.entries(fixture.users)) {
    if (!KNOWN_USERS.includes(persona)) throw new Error(`Fixture contains an unsupported persona ${persona}.`);
    if (!user || typeof user.email !== "string" || !user.email.includes("@") ||
        typeof user.password !== "string" || user.password.length === 0) {
      throw new Error(`Fixture credentials are missing for persona ${persona}.`);
    }
    assertUuid(user.userId, `userId for ${persona}`);
  }
  const userIds = Object.values(fixture.users).map((user) => user.userId.toLowerCase());
  if (new Set(userIds).size !== userIds.length) {
    throw new Error("Fixture user IDs must be unique across personas.");
  }
  if (!fixture.applications || typeof fixture.applications !== "object") {
    throw new Error("Fixture file is missing application IDs.");
  }
  const knownApplications = ["teenA", "teenB", "poster"];
  for (const [name, applicationId] of Object.entries(fixture.applications)) {
    if (!knownApplications.includes(name)) throw new Error(`Fixture contains an unsupported application key ${name}.`);
    assertUuid(applicationId, `application ID for ${name}`);
  }
  const applicationIds = Object.values(fixture.applications).map((id) => String(id).toLowerCase());
  if (new Set(applicationIds).size !== applicationIds.length) {
    throw new Error("Fixture application IDs must be distinct.");
  }
  if (fixture.expiredSessionToken !== undefined) {
    const expired = decodeJwtPayload(fixture.expiredSessionToken);
    if (!expired || expired.role !== "authenticated" || !UUID.test(expired.sub ?? "") ||
        !Number.isFinite(expired.exp) || expired.exp >= Math.floor(Date.now() / 1000)) {
      throw new Error("Optional expired-session fixture must be an expired authenticated-user JWT.");
    }
  }
  return fixture;
}

function buildCaseCatalog(fixture) {
  const guardianId = fixture.users.linkedGuardian?.userId;
  const cases = [
    { name: "teen A reads own application", persona: "teenA", application: "teenA", allowed: true, guardianId, replayKey: "teenA:teenA" },
    { name: "teen A repeated request preserves the same result", persona: "teenA", application: "teenA", allowed: true, guardianId, replayOf: "teenA:teenA" },
    { name: "teen A cannot read teen B application", persona: "teenA", application: "teenB", allowed: false },
    { name: "teen B cannot read teen A application", persona: "teenB", application: "teenA", allowed: false },
    { name: "linked Guardian reads linked application", persona: "linkedGuardian", application: "teenA", allowed: true, guardianId, replayKey: "linkedGuardian:teenA" },
    { name: "linked Guardian repeated request preserves the same result", persona: "linkedGuardian", application: "teenA", allowed: true, guardianId, replayOf: "linkedGuardian:teenA" },
    { name: "linked Guardian cannot read another teen application", persona: "linkedGuardian", application: "teenB", allowed: false },
    { name: "unlinked Guardian receives no application data", persona: "unlinkedGuardian", application: "teenA", allowed: false },
    { name: "revoked Guardian receives no application data", persona: "revokedGuardian", application: "teenA", allowed: false },
    { name: "suspended Guardian receives no application data", persona: "suspendedGuardian", application: "teenA", allowed: false },
    { name: "Guardian with missing teen consent receives no application data", persona: "missingTeenConsentGuardian", application: "teenA", allowed: false },
    { name: "Guardian with missing Guardian consent receives no application data", persona: "missingGuardianConsentGuardian", application: "teenA", allowed: false },
    { name: "wrong-role adult receives no application data", persona: "wrongRoleAdult", application: "teenA", allowed: false },
    { name: "poster reads own job application with Guardian ID masked", persona: "poster", application: "poster", allowed: true, guardianId: null },
    { name: "poster cannot read another poster application", persona: "poster", application: "teenA", allowed: false },
    // The documented production reader is participant-scoped (applicant,
    // poster, linked Guardian); it does not add an administrator bypass.
    { name: "administrator receives no data through the participant-only reader", persona: "administrator", application: "teenA", allowed: false },
    { name: "anonymous caller receives no application data", persona: null, application: "teenA", allowed: false },
  ].map((entry) => ({
    ...entry,
    applicationId: fixture.applications[entry.application],
    expectedApplicationId: entry.allowed ? fixture.applications[entry.application] : null,
    expectedGuardianId: entry.allowed ? entry.guardianId : undefined,
  }));
  return cases;
}

function caseSkipReason(entry, fixture) {
  if (!fixture.applications[entry.application]) return `missing application fixture ${entry.application}`;
  if (entry.persona && !fixture.users[entry.persona]) return `missing authenticated persona ${entry.persona}`;
  return null;
}

export function buildCasePlan(fixture) {
  validateFixture(fixture);
  const cases = buildCaseCatalog(fixture);
  const runnable = cases.filter((entry) => !caseSkipReason(entry, fixture));
  if (fixture.expiredSessionToken) {
    if (fixture.applications.teenA) runnable.push({
      name: "expired session receives no application data",
      persona: null,
      application: "teenA",
      applicationId: fixture.applications.teenA,
      allowed: false,
      accessToken: fixture.expiredSessionToken,
    });
  }
  return runnable;
}

export function classifyApplicationResponse({ status, body }) {
  const items = Array.isArray(body?.items) ? body.items : [];
  const hasData = items.length > 0;
  if (hasData) return { denied: false, hasData: true, items };
  if (status === 401 || status === 403) return { denied: true, hasData: false, items };
  if (status >= 200 && status < 300 && body?.ok === true && Array.isArray(body.items) && body.items.length === 0) {
    return { denied: true, hasData: false, items };
  }
  if (status >= 200 && status < 300 && body?.ok === false && body?.code === "active_account_required") {
    return { denied: true, hasData: false, items };
  }
  return { denied: false, hasData: false, items, invalidResponse: true };
}

export function loadRuntimeConfig(env) {
  const target = env.MORT_QA_TARGET;
  const projectRef = env.MORT_QA_PROJECT_REF;
  const url = env.MORT_QA_SUPABASE_URL;
  const anonKey = env.MORT_QA_ANON_KEY;
  validateTarget({
    target,
    projectRef,
    url,
    anonKey,
    genericProjectRef: env.MORT_SUPABASE_PROJECT_REF,
    serviceRoleKey: env.MORT_QA_SERVICE_ROLE_KEY || env.SUPABASE_SERVICE_ROLE_KEY,
    allowServiceRole: env.MORT_QA_ALLOW_SERVICE_ROLE,
  });

  const fixturePath = env.MORT_QA_GUARDIAN_FIXTURE_FILE;
  if (!fixturePath || !isAbsolute(fixturePath)) {
    throw new Error("Set MORT_QA_GUARDIAN_FIXTURE_FILE to an absolute path outside the repository.");
  }
  let resolvedPath;
  let fixture;
  try {
    resolvedPath = realpathSync(fixturePath);
    fixture = JSON.parse(readFileSync(resolvedPath, "utf8"));
  } catch {
    throw new Error("Guardian QA fixture file is unavailable or invalid JSON.");
  }
  const repoRoot = resolve(fileURLToPath(new URL("..", import.meta.url)));
  const relativePath = relative(repoRoot, resolvedPath);
  if (relativePath === "" || (relativePath !== ".." && !relativePath.startsWith(`..${sep}`) && !isAbsolute(relativePath))) {
    throw new Error("Guardian QA fixture file must be stored outside the repository.");
  }
  validateFixture(fixture);
  return { target, projectRef, url, anonKey, fixture };
}

async function requestJson(fetchImpl, url, options) {
  try {
    const response = await fetchImpl(url, options);
    let body = null;
    try { body = await response.json(); } catch { /* Response details are intentionally not logged. */ }
    return { status: response.status, body };
  } catch {
    throw new Error("Network request failed; raw transport details were suppressed.");
  }
}

async function authenticate(fetchImpl, config, persona) {
  const user = config.fixture.users[persona];
  const result = await requestJson(fetchImpl, `${config.url}/auth/v1/token?grant_type=password`, {
    method: "POST",
    headers: { apikey: config.anonKey, "content-type": "application/json" },
    body: JSON.stringify({ email: user.email, password: user.password }),
  });
  if (result.status !== 200 || typeof result.body?.access_token !== "string" ||
      result.body?.user?.id?.toLowerCase() !== user.userId.toLowerCase()) {
    throw new Error(`Authentication failed for persona ${persona} (HTTP ${result.status}); response body suppressed.`);
  }
  return result.body.access_token;
}

async function signOut(fetchImpl, config, accessToken) {
  if (!accessToken) return;
  await requestJson(fetchImpl, `${config.url}/auth/v1/logout`, {
    method: "POST",
    headers: { apikey: config.anonKey, authorization: `Bearer ${accessToken}` },
  });
}

async function callReader(fetchImpl, config, caseEntry, accessToken) {
  const headers = { apikey: config.anonKey, "content-type": "application/json" };
  if (accessToken) headers.authorization = `Bearer ${accessToken}`;
  return requestJson(fetchImpl, `${config.url}/rest/v1/rpc/get_my_job_applications`, {
    method: "POST",
    headers,
    body: JSON.stringify({ p_application_id: caseEntry.applicationId }),
  });
}

function evaluateCase(caseEntry, response) {
  const result = classifyApplicationResponse(response);
  if (!caseEntry.allowed) {
    return result.denied && !result.hasData
      ? { pass: true }
      : { pass: false, reason: "unauthorized caller received application data or no explicit denial" };
  }
  if (response.status < 200 || response.status >= 300 || response.body?.ok !== true ||
      !Array.isArray(response.body?.items) || response.body.items.length !== 1) {
    return { pass: false, reason: "authorized caller did not receive exactly one application" };
  }
  const item = response.body.items[0];
  if (item.id?.toLowerCase() !== caseEntry.expectedApplicationId.toLowerCase()) {
    return { pass: false, reason: "response application did not match the requested fixture" };
  }
  if (caseEntry.expectedGuardianId !== undefined) {
    const actual = item.guardian_id == null ? null : String(item.guardian_id).toLowerCase();
    const expected = caseEntry.expectedGuardianId == null ? null : String(caseEntry.expectedGuardianId).toLowerCase();
    if (actual !== expected) return { pass: false, reason: "Guardian ID visibility did not match the fixture policy" };
  }
  return { pass: true };
}

export async function runGuardianApiChecks(config, fetchImpl = fetch, log = console.log) {
  const tokens = new Map();
  const failures = [];
  const replayFingerprints = new Map();
  const catalog = buildCaseCatalog(config.fixture);
  const skippedCases = catalog.filter((entry) => caseSkipReason(entry, config.fixture))
    .map((entry) => ({ name: entry.name, reason: caseSkipReason(entry, config.fixture) }));
  const cases = catalog.filter((entry) => !caseSkipReason(entry, config.fixture));
  if (config.fixture.expiredSessionToken && config.fixture.applications.teenA) {
    cases.push({
      name: "expired session receives no application data",
      persona: null,
      application: "teenA",
      applicationId: config.fixture.applications.teenA,
      allowed: false,
      accessToken: config.fixture.expiredSessionToken,
    });
  } else {
    skippedCases.push({ name: "expired session receives no application data", reason: "expired JWT fixture not supplied" });
  }
  for (const entry of skippedCases) log(`SKIP ${entry.name}: ${entry.reason}`);
  try {
    for (const entry of cases) {
      let token = entry.accessToken ?? null;
      if (entry.persona) {
        if (!tokens.has(entry.persona)) {
          try {
            tokens.set(entry.persona, await authenticate(fetchImpl, config, entry.persona));
          } catch (error) {
            tokens.set(entry.persona, error);
          }
        }
        const stored = tokens.get(entry.persona);
        if (stored instanceof Error) {
          failures.push(entry.name);
          log(`FAIL ${entry.name}: ${stored.message}`);
          continue;
        }
        token = stored;
      }

      try {
        const response = await callReader(fetchImpl, config, entry, token);
        const result = evaluateCase(entry, response);
        const items = Array.isArray(response.body?.items) ? response.body.items : [];
        const fingerprint = items.length === 1
          ? JSON.stringify({ id: items[0].id, guardian_id: items[0].guardian_id ?? null, status: items[0].status })
          : null;
        if (result.pass && entry.replayOf && replayFingerprints.get(entry.replayOf) !== fingerprint) {
          result.pass = false;
          result.reason = "replayed request changed its authorized result";
        }
        if (result.pass && entry.replayKey) replayFingerprints.set(entry.replayKey, fingerprint);
        if (result.pass) {
          log(`PASS ${entry.name} (HTTP ${response.status}; rows ${response.body?.items?.length ?? 0})`);
        } else {
          failures.push(entry.name);
          log(`FAIL ${entry.name}: ${result.reason} (HTTP ${response.status})`);
        }
      } catch (error) {
        failures.push(entry.name);
        log(`FAIL ${entry.name}: ${error.message}`);
      }
    }
  } finally {
    for (const token of tokens.values()) {
      if (typeof token === "string") await signOut(fetchImpl, config, token);
    }
  }
  return { passed: cases.length - failures.length, failed: failures.length, skipped: skippedCases.length, skippedCases };
}

async function main() {
  const config = loadRuntimeConfig(process.env);
  const result = await runGuardianApiChecks(config);
  console.log(`[qa-guardian-application-reader-api] ${result.passed} passed, ${result.failed} failed, ${result.skipped} skipped.`);
  if (result.failed > 0) process.exitCode = 1;
}

if (process.argv[1] && pathToFileURL(resolve(process.argv[1])).href === import.meta.url) {
  main().catch((error) => {
    console.error(`[qa-guardian-application-reader-api] BLOCKED/FAILED: ${error.message}`);
    process.exitCode = 1;
  });
}
