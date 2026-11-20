import { assert, assertEquals } from "jsr:@std/assert@1";
import { evaluatePasswordPolicy } from "../_shared/password_policy.ts";
import {
  mintAttestation,
  stripAttestation,
  verifyAttestation,
} from "../_shared/password_attestation.ts";
import { sha1Hex } from "../_shared/leaked_password.ts";
import { createPasswordGuardHandler } from "./handler.ts";

const SECRET = "test-secret-0123456789abcdef0123456789abcdef";
const STRONG = "Plum-Orbit-Kettle-73";
const LEAKED = "Password123!Leaked";

Deno.test("policy: weak passwords are rejected with specific codes", () => {
  assertEquals(evaluatePasswordPolicy(""), {
    ok: false,
    code: "password_required",
  });
  assertEquals(evaluatePasswordPolicy(undefined), {
    ok: false,
    code: "password_required",
  });
  assertEquals(evaluatePasswordPolicy("Short1!"), {
    ok: false,
    code: "password_too_short",
  });
  assertEquals(evaluatePasswordPolicy("alllowercase123!"), {
    ok: false,
    code: "password_complexity_required",
  });
  assertEquals(evaluatePasswordPolicy("NoDigitsHere!!!"), {
    ok: false,
    code: "password_complexity_required",
  });
  assertEquals(evaluatePasswordPolicy("NoSymbols12345"), {
    ok: false,
    code: "password_complexity_required",
  });
  assertEquals(evaluatePasswordPolicy("Aa1!" + "x".repeat(69)), {
    ok: false,
    code: "password_too_long",
  });
  assertEquals(evaluatePasswordPolicy("Tab\there-Pass1"), {
    ok: false,
    code: "password_invalid_characters",
  });
  assertEquals(
    evaluatePasswordPolicy("Xjordan.smith9!", "jordan.smith@example.org"),
    { ok: false, code: "password_contains_email" },
  );
});

Deno.test("policy: acceptable password passes", () => {
  assertEquals(evaluatePasswordPolicy(STRONG, "someone@example.org"), {
    ok: true,
  });
  assertEquals(evaluatePasswordPolicy("Aa1!" + "x".repeat(68)), { ok: true }); // exactly 72 bytes
});

Deno.test("attestation: verifies only for the same purpose, subject, and unexpired window", async () => {
  const now = 1_800_000_000;
  const t = await mintAttestation(SECRET, "signup", " Teen@Example.org ", now);
  assert(/^v1\.signup\.[0-9a-f]{32}\.\d+\.[0-9a-f]{64}$/.test(t));
  assert(await verifyAttestation(SECRET, t, "signup", "teen@example.org", now));
  assert(
    !(await verifyAttestation(
      SECRET,
      t,
      "update_password",
      "teen@example.org",
      now,
    )),
  );
  assert(
    !(await verifyAttestation(SECRET, t, "signup", "other@example.org", now)),
  );
  assert(
    !(await verifyAttestation(
      SECRET,
      t,
      "signup",
      "teen@example.org",
      now + 301,
    )),
  );
  assert(
    !(await verifyAttestation(
      "x".repeat(40),
      t,
      "signup",
      "teen@example.org",
      now,
    )),
  );
  const tampered = t.slice(0, -1) + (t.endsWith("0") ? "1" : "0");
  assert(
    !(await verifyAttestation(
      SECRET,
      tampered,
      "signup",
      "teen@example.org",
      now,
    )),
  );
});

Deno.test("attestation: refuses a short or missing secret", async () => {
  let threw = false;
  try {
    await mintAttestation("short", "signup", "a@b.co");
  } catch {
    threw = true;
  }
  assert(threw);
});

Deno.test("stripAttestation removes the token everywhere", () => {
  const out = stripAttestation({
    user: {
      user_metadata: { mort_password_attestation: "x", a: 1 },
      identities: [{ identity_data: { mort_password_attestation: "y" } }],
    },
  });
  assertEquals(
    JSON.stringify(out).includes("mort_password_attestation"),
    false,
  );
});

async function fakeFetchFactory(
  opts: { hibp?: "ok" | "down" | "malformed" } = {},
) {
  const leakedHash = await sha1Hex(LEAKED);
  const calls: { url: string; init?: RequestInit }[] = [];
  const fetchImpl =
    (async (input: string | URL | Request, init?: RequestInit) => {
      const url = String(input);
      calls.push({ url, init });
      if (url.startsWith("https://hibp.test/range/")) {
        if (opts.hibp === "down") return new Response("", { status: 503 });
        if (opts.hibp === "malformed") {
          return new Response("<html>", { status: 200 });
        }
        const prefix = url.slice(-5);
        const lines = ["0000000000000000000000000000000000A:0"];
        if (leakedHash.startsWith(prefix)) {
          lines.push(`${leakedHash.slice(5)}:42`);
        }
        return new Response(lines.join("\r\n"), { status: 200 });
      }
      if (url.startsWith("https://auth.test/auth/v1/signup")) {
        const body = JSON.parse(String(init?.body));
        return new Response(
          JSON.stringify({
            id: "u1",
            user_metadata: body.data,
            identities: [{ identity_data: body.data }],
          }),
          { status: 200 },
        );
      }
      if (
        url === "https://auth.test/auth/v1/user" &&
        (!init?.method || init.method === "GET")
      ) {
        const auth = new Headers(init?.headers).get("authorization");
        return auth === "Bearer user-jwt"
          ? new Response(
            JSON.stringify({
              id: "11111111-1111-1111-1111-111111111111",
              email: "adult@example.org",
            }),
            { status: 200 },
          )
          : new Response(JSON.stringify({ msg: "invalid" }), { status: 401 });
      }
      if (url === "https://auth.test/auth/v1/user" && init?.method === "PUT") {
        const body = JSON.parse(String(init?.body));
        return new Response(
          JSON.stringify({
            id: "11111111-1111-1111-1111-111111111111",
            user_metadata: body.data,
          }),
          { status: 200 },
        );
      }
      return new Response("unexpected", { status: 500 });
    }) as typeof fetch;
  return { fetchImpl, calls };
}

function guard(
  fetchImpl: typeof fetch,
  secret: string | undefined = SECRET,
  quota: (
    key: string,
    limit: number,
    windowSeconds: number,
  ) => Promise<boolean> = async () => true,
) {
  return createPasswordGuardHandler({
    supabaseUrl: "https://auth.test",
    anonKey: "anon-key",
    attestationSecret: secret,
    hibpRangeUrl: "https://hibp.test/range/",
    fetchImpl,
    rateLimitPerMinute: 1000,
    consumeSignupQuota: quota,
  });
}

const post = (body: unknown, headers: Record<string, string> = {}) =>
  new Request("https://fn.test/password-guard", {
    method: "POST",
    headers: { "content-type": "application/json", ...headers },
    body: JSON.stringify(body),
  });

const signup = (password: string) => ({
  action: "signup",
  email: "new.user@example.org",
  password,
  date_of_birth: "2009-04-02",
});

Deno.test("signup: weak password rejected before quota or Auth are called", async () => {
  const { fetchImpl, calls } = await fakeFetchFactory();
  const seen: string[] = [];
  const res = await guard(fetchImpl, SECRET, async (key) => {
    seen.push(key);
    return true;
  })(post(signup("weakpass")));
  assertEquals(res.status, 422);
  assertEquals((await res.json()).code, "password_too_short");
  assertEquals(seen.length, 0);
  assertEquals(calls.length, 0);
});

Deno.test("signup: leaked password rejected before quota; only a 5-char prefix leaves the function", async () => {
  const { fetchImpl, calls } = await fakeFetchFactory();
  const seen: string[] = [];
  const res = await guard(fetchImpl, SECRET, async (key) => {
    seen.push(key);
    return true;
  })(post(signup(LEAKED)));
  assertEquals(res.status, 422);
  assertEquals((await res.json()).code, "leaked_password_compromised");
  assertEquals(seen.length, 0);
  assertEquals(calls.length, 1);
  assert(/\/range\/[0-9A-F]{5}$/.test(calls[0].url));
});

Deno.test("signup: HIBP outage or malformed response fails closed", async () => {
  for (const hibp of ["down", "malformed"] as const) {
    const { fetchImpl, calls } = await fakeFetchFactory({ hibp });
    const res = await guard(fetchImpl)(post(signup(STRONG)));
    assertEquals(res.status, 503);
    assertEquals((await res.json()).code, "leaked_password_check_unavailable");
    assert(!calls.some((c) => c.url.includes("/auth/v1/")));
  }
});

Deno.test("signup: invalid input rejected", async () => {
  const { fetchImpl } = await fakeFetchFactory();
  const h = guard(fetchImpl);
  assertEquals(
    (await (await h(post({ ...signup(STRONG), email: "nope" }))).json()).code,
    "email_invalid",
  );
  assertEquals(
    (await (await h(post({ ...signup(STRONG), date_of_birth: "04/02/2009" })))
      .json()).code,
    "dob_invalid",
  );
  assertEquals(
    (await (await h(post({ action: "other" }))).json()).code,
    "action_invalid",
  );
  const big = await h(
    new Request("https://fn.test", { method: "POST", body: "x".repeat(5000) }),
  );
  assertEquals(big.status, 413);
  assertEquals(
    (await h(new Request("https://fn.test", { method: "GET" }))).status,
    405,
  );
});

Deno.test("signup: acceptable password is forwarded with anon key, DOB and attestation; response is stripped", async () => {
  const { fetchImpl, calls } = await fakeFetchFactory();
  const res = await guard(fetchImpl)(
    post({
      ...signup(STRONG),
      display_name: "Sam",
      redirect_to: "mort://auth-callback",
    }),
  );
  assertEquals(res.status, 200);
  const out = await res.json();
  assertEquals(out.ok, true);
  assertEquals(
    JSON.stringify(out).includes("mort_password_attestation"),
    false,
  );
  const authCall = calls.find((c) => c.url.includes("/auth/v1/signup"))!;
  assertEquals(
    authCall.url,
    "https://auth.test/auth/v1/signup?redirect_to=mort%3A%2F%2Fauth-callback",
  );
  const headers = new Headers(authCall.init?.headers);
  assertEquals(headers.get("apikey"), "anon-key");
  assertEquals(headers.get("authorization"), null);
  const sent = JSON.parse(String(authCall.init?.body));
  assertEquals(sent.data.date_of_birth, "2009-04-02");
  assertEquals(sent.data.display_name, "Sam");
  assert(
    await verifyAttestation(
      SECRET,
      sent.data.mort_password_attestation,
      "signup",
      "new.user@example.org",
    ),
  );
});

Deno.test("signup: role metadata is forwarded only for supported roles", async () => {
  const { fetchImpl, calls } = await fakeFetchFactory();
  const res = await guard(fetchImpl)(
    post({ ...signup(STRONG), role: "guardian" }),
  );
  assertEquals(res.status, 200);
  const authCall = calls.find((c) => c.url.includes("/auth/v1/signup"))!;
  const sent = JSON.parse(String(authCall.init?.body));
  assertEquals(sent.data.role, "guardian");
  const { fetchImpl: fetch2, calls: calls2 } = await fakeFetchFactory();
  await guard(fetch2)(post({ ...signup(STRONG), role: "admin" }));
  const authCall2 = calls2.find((c) => c.url.includes("/auth/v1/signup"))!;
  const sent2 = JSON.parse(String(authCall2.init?.body));
  assertEquals("role" in sent2.data, false);
});

Deno.test("signup: shared quotas block Auth calls and quota outages fail closed", async () => {
  const { fetchImpl } = await fakeFetchFactory();
  const seen: Array<{ key: string; limit: number; seconds: number }> = [];
  const quota = async (key: string, limit: number, seconds: number) => {
    seen.push({ key, limit, seconds });
    return true;
  };
  const ok = await guard(fetchImpl, SECRET, quota)(post(signup(STRONG)));
  assertEquals(ok.status, 200);
  assertEquals(seen.length, 3);
  assertEquals(seen[0], { key: "signup:global", limit: 20, seconds: 3600 });
  assert(seen[1].key.startsWith("signup:ip:"));
  assert(seen[2].key.startsWith("signup:email:"));
  assertEquals(seen[1].key.length, "signup:ip:".length + 64);
  assertEquals(seen[2].key.length, "signup:email:".length + 64);

  const { fetchImpl: blockedFetch, calls: blockedCalls } =
    await fakeFetchFactory();
  const blocked = await guard(
    blockedFetch,
    SECRET,
    async (key) => key !== "signup:global",
  )(post(signup(STRONG)));
  assertEquals(blocked.status, 429);
  assertEquals((await blocked.json()).code, "rate_limited");
  assertEquals(
    blockedCalls.some((c) => c.url.includes("/auth/v1/signup")),
    false,
  );

  const { fetchImpl: failedFetch, calls: failedCalls } =
    await fakeFetchFactory();
  const failed = await guard(failedFetch, SECRET, async () => {
    throw new Error("db unavailable");
  })(post(signup(STRONG)));
  assertEquals(failed.status, 503);
  assertEquals((await failed.json()).code, "rate_limiter_unavailable");
  assertEquals(
    failedCalls.some((c) => c.url.includes("/auth/v1/signup")),
    false,
  );
});

Deno.test("guard refuses to run without an attestation secret", async () => {
  const { fetchImpl, calls } = await fakeFetchFactory();
  const res = await guard(fetchImpl, "")(post(signup(STRONG)));
  assertEquals(res.status, 503);
  assertEquals((await res.json()).code, "password_guard_unconfigured");
  assertEquals(calls.length, 0);
});

Deno.test("update_password: requires a user session", async () => {
  const { fetchImpl } = await fakeFetchFactory();
  const h = guard(fetchImpl);
  assertEquals(
    (await h(post({ action: "update_password", password: STRONG }))).status,
    401,
  );
  assertEquals(
    (await h(
      post({ action: "update_password", password: STRONG }, {
        authorization: "Bearer anon-key",
      }),
    )).status,
    401,
  );
  assertEquals(
    (await h(
      post({ action: "update_password", password: STRONG }, {
        authorization: "Bearer forged",
      }),
    )).status,
    401,
  );
});

Deno.test("update_password: weak, leaked, email-derived rejected; acceptable forwarded with user token", async () => {
  const { fetchImpl, calls } = await fakeFetchFactory();
  const h = guard(fetchImpl);
  const auth = { authorization: "Bearer user-jwt" };
  assertEquals(
    (await (await h(
      post({ action: "update_password", password: "short" }, auth),
    )).json()).code,
    "password_too_short",
  );
  assertEquals(
    (await (await h(
      post({ action: "update_password", password: LEAKED }, auth),
    )).json()).code,
    "leaked_password_compromised",
  );
  assertEquals(
    (await (await h(
      post({ action: "update_password", password: "Adult-2026-pass!" }, auth),
    )).json()).code,
    "password_contains_email",
  );
  const ok = await h(
    post({ action: "update_password", password: STRONG }, auth),
  );
  assertEquals(ok.status, 200);
  assertEquals(
    JSON.stringify(await ok.json()).includes("mort_password_attestation"),
    false,
  );
  const put = calls.find((c) => c.init?.method === "PUT")!;
  assertEquals(
    new Headers(put.init?.headers).get("authorization"),
    "Bearer user-jwt",
  );
  const sent = JSON.parse(String(put.init?.body));
  assert(
    await verifyAttestation(
      SECRET,
      sent.data.mort_password_attestation,
      "update_password",
      "11111111-1111-1111-1111-111111111111",
    ),
  );
});
