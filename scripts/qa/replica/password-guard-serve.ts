// Serves supabase/functions/password-guard locally against the production
// replica (never a hosted project). HIBP_MODE=fixture (default, deterministic
// for CI) answers range queries from a fixture list; HIBP_MODE=real uses
// api.pwnedpasswords.com.
import { createPasswordGuardHandler } from "../../../supabase/functions/password-guard/handler.ts";
import { sha1Hex } from "../../../supabase/functions/_shared/leaked_password.ts";

const supabaseUrl = Deno.env.get("API_URL")!;
const supabaseHost = new URL(supabaseUrl).hostname;
if (!["127.0.0.1", "localhost", "::1"].includes(supabaseHost)) {
  throw new Error("refusing non-local API_URL " + supabaseHost);
}

// This process is launched only by build-and-test.sh after supabase start
// and sourcing that local replica's supabase status -o env output. Keep the
// service-role credential in this test server; never expose it to the client.
const serviceRoleKey = Deno.env.get("SERVICE_ROLE_KEY");
if (!serviceRoleKey) {
  throw new Error(
    "SERVICE_ROLE_KEY is required from the local replica environment",
  );
}

const attestationActive = async (): Promise<boolean> => {
  const response = await fetch(
    `${
      supabaseUrl.replace(/\/+$/, "")
    }/rest/v1/rpc/mort_password_attestation_is_active`,
    {
      method: "POST",
      headers: {
        apikey: serviceRoleKey,
        Authorization: "Bearer " + serviceRoleKey,
        "Content-Type": "application/json",
      },
      body: "{}",
    },
  );
  return response.ok && await response.json() === true;
};

const consumeSignupQuota = async (
  bucketKey: string,
  limit: number,
  windowSeconds: number,
): Promise<boolean> => {
  const response = await fetch(
    supabaseUrl.replace(/\/+$/, "") +
      "/rest/v1/rpc/mort_consume_password_guard_rate_limit",
    {
      method: "POST",
      headers: {
        apikey: serviceRoleKey,
        Authorization: "Bearer " + serviceRoleKey,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        p_bucket_key: bucketKey,
        p_limit: limit,
        p_window_seconds: windowSeconds,
      }),
    },
  );
  if (!response.ok) {
    const detail = await response.text();
    throw new Error(
      "local signup quota RPC failed (" + response.status + "): " +
        detail.slice(0, 300),
    );
  }
  const allowed: unknown = await response.json();
  if (typeof allowed !== "boolean") {
    throw new Error("local signup quota RPC returned a non-boolean result");
  }
  return allowed;
};

const LEAKED_FIXTURES = ["Password123!", "Summer2024!!", "P@ssw0rd1234"];
const leakedHashes = await Promise.all(LEAKED_FIXTURES.map(sha1Hex));
let hibpDown = false;

const fixtureFetch: typeof fetch = async (input, init) => {
  const url = String(input instanceof Request ? input.url : input);
  if (url.startsWith("https://hibp.fixture/range/")) {
    if (hibpDown) return new Response("unavailable", { status: 503 });
    const prefix = url.slice(-5).toUpperCase();
    const lines = leakedHashes.filter((h) => h.startsWith(prefix)).map((h) =>
      `${h.slice(5)}:1000`
    );
    lines.push("00000000000000000000000000000000000:0");
    return new Response(lines.join("\r\n"));
  }
  return fetch(input, init);
};

const real = Deno.env.get("HIBP_MODE") === "real";
const handler = createPasswordGuardHandler({
  supabaseUrl,
  anonKey: Deno.env.get("ANON_KEY")!,
  attestationSecret: Deno.env.get("MORT_PASSWORD_ATTESTATION_SECRET"),
  attestationActive,
  hibpRangeUrl: real ? undefined : "https://hibp.fixture/range/",
  fetchImpl: real ? fetch : fixtureFetch,
  rateLimitPerMinute: Number(Deno.env.get("GUARD_RATE_LIMIT") ?? "1000"),
  consumeSignupQuota,
});

const port = Number(Deno.env.get("PASSWORD_GUARD_PORT") ?? "55399");
Deno.serve({
  hostname: "127.0.0.1",
  port,
  onListen: () =>
    console.log(
      `password-guard on ${port} (hibp=${real ? "real" : "fixture"})`,
    ),
}, (req) => {
  const path = new URL(req.url).pathname;
  // Test-only control to simulate an HIBP outage in fixture mode.
  if (!real && path === "/__test/hibp-down") {
    hibpDown = true;
    return new Response("down");
  }
  if (!real && path === "/__test/hibp-up") {
    hibpDown = false;
    return new Response("up");
  }
  return handler(req);
});
