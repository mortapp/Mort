import { handleEmailGuard } from "./handler.ts";
import { Admission } from "../_shared/auth_email_guard/admission.ts";
import {
  makeSecret,
  secretDigest,
} from "../_shared/auth_email_guard/crypto.ts";
const check = (v: unknown, message: string) => {
  if (!v) throw new Error(message);
};
const bytes = new TextEncoder();
const source = (n: number) => n.toString(16).padStart(64, "0");
const failure = { ok: false, message: "That request is not valid." };
Deno.test("malformed-query denial remains inside the source/global admission budget", async () => {
  const { deps, request } = await setup();
  const first = handleEmailGuard(request({}, "/continue?invalid=1"), deps);
  const second = handleEmailGuard(request({}, "/continue?invalid=2"), deps);
  const third = await handleEmailGuard(
    request({}, "/continue?invalid=3"),
    deps,
  );
  check(
    third.status === 429,
    "Malformed denial must not allocate unbounded delayed tasks",
  );
  await Promise.all([first, second]);
  check(
    deps.admission.snapshot().active === 0,
    "Malformed denial releases admission",
  );
});
async function setup() {
  let calls = 0, dispatches = 0;
  const codeKey = await crypto.subtle.importKey(
    "raw",
    crypto.getRandomValues(new Uint8Array(32)),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const id = crypto.randomUUID(),
    secret = makeSecret(),
    verifier = makeSecret();
  const payload = {
    itemId: id,
    linkSecret: secret,
    verifierHash: await secretDigest(verifier),
  };
  const deps = {
    mode: "local_fixture" as "local_fixture" | "disabled",
    sourceHash: source(1),
    admission: new Admission(),
    allowedOrigins: ["https://mortapp.org"],
    codeKey,
    store: {
      consume: async (
        _input: unknown,
        _material: unknown,
        _signal: AbortSignal,
      ) => {
        calls++;
        return failure as Record<string, unknown>;
      },
      reserve: async (_input: unknown, _signal: AbortSignal) => {
        calls++;
        return failure as Record<string, unknown>;
      },
    },
    dispatch: async (_operation: unknown, _password: string) => {
      dispatches++;
      return "committed" as "committed" | "pending" | "fenced";
    },
  };
  const request = (
    body: unknown = payload,
    path = "/continue",
    extra: Record<string, string> = {},
  ) =>
    new Request("http://127.0.0.1:55426" + path, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        origin: "https://mortapp.org",
        ...extra,
      },
      body: JSON.stringify(body),
    });
  return {
    deps,
    payload,
    request,
    secret,
    verifier,
    counts: () => ({ calls, dispatches }),
  };
}
Deno.test("gateway rejects disabled, arbitrary routes/methods/query/Origin and ambiguous bodies without authority", async () => {
  const { deps, request, payload, counts } = await setup();
  deps.mode = "disabled";
  check(
    (await handleEmailGuard(request(), deps)).status === 503,
    "Disabled route must fail closed",
  );
  deps.mode = "local_fixture";
  for (
    const r of [
      new Request("http://127.0.0.1:55426/continue"),
      request(payload, "/peek"),
      request(payload, "/continue?account=other"),
      request(payload, "/continue", { origin: "https://untrusted.invalid" }),
      request({ ...payload, email: "arbitrary@example.invalid" }),
      request({ ...payload, code: "00000000" }),
      request("x".repeat(16385)),
    ]
  ) {
    check(
      (await handleEmailGuard(r, deps)).status !== 200,
      "Malformed or unsupported operation must deny",
    );
  }
  check(
    counts().calls === 0 && counts().dispatches === 0,
    "Rejected requests must never invoke store/provider",
  );
  deps.sourceHash = "";
  check(
    (await handleEmailGuard(
      request(payload, "/continue", { "x-forwarded-for": "127.0.0.1" }),
      deps,
    )).status === 503,
    "Untrusted forwarding cannot replace owned ingress",
  );
});
Deno.test("canonical failures share response and 350ms schedule; success returns only bounded committed capability", async () => {
  const { deps, request, secret, verifier } = await setup();
  for (let i = 0; i < 3; i++) {
    const start = performance.now(),
      r = await handleEmailGuard(request(), deps);
    check(
      r.status === 400 &&
        JSON.stringify(await r.json()) === JSON.stringify(failure),
      "Failure shape must be uniform",
    );
    check(
      performance.now() - start >= 330 && performance.now() - start < 650,
      "Generic denial must use 350ms deadline",
    );
  }
  deps.store.consume = async (input, material) => {
    const i = input as Record<string, unknown>,
      m = material as Record<string, unknown>;
    check(
      !Object.values(i).includes(secret) &&
        !Object.values(i).includes(verifier) && !("capabilitySecret" in m),
      "Store may receive only digested authority",
    );
    return {
      ok: true,
      purpose: "recovery",
      maskedRecipient: "q***@example.invalid",
      familyExpiresAt: new Date(Date.now() + 600000).toISOString(),
      capabilityExpiresAt: new Date(Date.now() + 300000).toISOString(),
      internal: "omit",
    };
  };
  const r = await handleEmailGuard(request(), deps), out = await r.json();
  check(
    r.status === 200 && typeof out.capability === "string" &&
      out.capability.length === 43 && !("internal" in out),
    "Only committed capability and sanitized state may escape",
  );
  check(
    r.headers.get("cache-control") === "no-store" &&
      r.headers.get("access-control-allow-origin") === "https://mortapp.org",
    "Fixed containment headers",
  );
});
Deno.test("owned-source saturation cannot block source B; same challenge has one checker; release restores admission", async () => {
  const { deps, request, payload } = await setup();
  let unblock: () => void = () => {};
  deps.store.consume = async () => {
    await new Promise<void>((r) => {
      unblock = r;
    });
    return failure;
  };
  const first = handleEmailGuard(request(), deps);
  await new Promise((r) => setTimeout(r, 20));
  check(
    (await handleEmailGuard(request(), deps)).status === 429,
    "Concurrent same challenge gets non-charged Busy",
  );
  const held = deps.admission.acquire(source(1));
  check(held, "Source slot must remain for independent request");
  check(
    (await handleEmailGuard(
      request({ ...payload, itemId: crypto.randomUUID() }),
      deps,
    )).status === 429,
    "Source third request gets Busy",
  );
  const other = {
    ...deps,
    sourceHash: source(2),
    store: { ...deps.store, consume: async () => failure },
  };
  check(
    (await handleEmailGuard(
      request({ ...payload, itemId: crypto.randomUUID() }),
      other,
    )).status === 400,
    "Independent source remains live",
  );
  held?.release();
  unblock();
  await first;
  check(deps.admission.snapshot().active === 0, "Every route releases tickets");
});
Deno.test("250ms store deadline aborts active work and returns Busy without raw credentials or dispatcher use", async () => {
  const { deps, request, counts } = await setup();
  let aborted = false;
  deps.store.consume = async (_i, _m, signal) =>
    await new Promise<Record<string, unknown>>((_, reject) =>
      signal.addEventListener("abort", () => {
        aborted = true;
        reject(new Error("private failure"));
      }, { once: true })
    );
  const start = performance.now(),
    r = await handleEmailGuard(request(), deps),
    out = await r.json();
  check(
    r.status === 429 && out.retryAfterSeconds === 1 && aborted &&
      performance.now() - start < 550,
    "Store timeout is bounded non-charged Busy",
  );
  check(
    counts().dispatches === 0 && deps.admission.snapshot().active === 0,
    "Deadline releases authority/resources",
  );
});
Deno.test("password policy is revealed only after verifier possession; raw password never reaches SQL; pending is not success", async () => {
  const { deps, request, secret, verifier, counts } = await setup();
  const weak = { capability: secret, verifier, password: "weak" };
  check(
    (await handleEmailGuard(request(weak, "/password"), deps)).status === 400,
    "Invalid possession returns generic denial",
  );
  deps.store.reserve = async (input) => {
    const i = input as Record<string, unknown>;
    check(
      !("password" in i) && !Object.values(i).includes(secret) &&
        !Object.values(i).includes(verifier),
      "No raw password/capability/verifier in store",
    );
    return i.passwordValid
      ? {
        ok: true,
        operationId: crypto.randomUUID(),
        accountId: crypto.randomUUID(),
        purpose: "recovery",
        expiresAt: new Date(Date.now() + 300000).toISOString(),
      }
      : { ok: false, policy: true };
  };
  const policy =
    await (await handleEmailGuard(request(weak, "/password"), deps)).json();
  check(
    policy.message === "Choose a password that meets the requirements." &&
      counts().dispatches === 0,
    "Possession-only policy denial cannot reserve or dispatch",
  );
  const good = { ...weak, password: "Good!Password7" };
  check(
    (await (await handleEmailGuard(request(good, "/password"), deps)).json())
      .ok === true,
    "Committed supported provider dispatch must succeed",
  );
  deps.dispatch = async () => "pending";
  const pending =
    await (await handleEmailGuard(request(good, "/password"), deps)).json();
  check(
    pending.ok === false,
    "Unknown provider outcome must never claim success",
  );
});
