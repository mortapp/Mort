import { createClient } from "npm:@supabase/supabase-js@2.110.1";
import {
  correlatedJson,
  correlationId,
  structuredLog,
} from "../_shared/observability.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!supabaseUrl || !serviceRoleKey) {
  throw new Error("Supabase server environment is not configured.");
}

const admin = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const maximumBodyBytes = 2 * 1024;
const hibpTimeoutMs = 4000;
const hibpRangeUrl = "https://api.pwnedpasswords.com/range/";

// Lightweight per-isolate rate limit so the function cannot be used as an
// open HIBP proxy. Best effort only; the edge is horizontally scaled.
const perUserCalls = new Map<string, { windowStart: number; count: number }>();
const rateWindowMs = 60_000;
const rateWindowMax = 10;

function rateLimited(userId: string): boolean {
  const now = Date.now();
  const entry = perUserCalls.get(userId);
  if (!entry || now - entry.windowStart >= rateWindowMs) {
    perUserCalls.set(userId, { windowStart: now, count: 1 });
    return false;
  }
  entry.count += 1;
  return entry.count > rateWindowMax;
}

Deno.serve(async (request) => {
  const traceId = correlationId(request);
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return json({ ok: false, code: "post_required" }, 405, traceId);
  }

  const authorizationHeader = request.headers.get("authorization") ?? "";
  const token = authorizationHeader.replace(/^Bearer\s+/i, "").trim();
  if (!token) return json({ ok: false, code: "authentication_required" }, 401, traceId);

  const { data: userData, error: userError } = await admin.auth.getUser(token);
  if (userError || !userData.user) {
    return json({ ok: false, code: "authentication_required" }, 401, traceId);
  }
  const userId = userData.user.id;

  if (rateLimited(userId)) {
    return json({ ok: false, code: "rate_limited" }, 429, traceId);
  }

  let sha1Prefix = "";
  try {
    const body = await readJson(request);
    sha1Prefix = typeof body?.sha1Prefix === "string" ? body.sha1Prefix : "";
  } catch (error) {
    return json({ ok: false, code: "invalid_request" }, 400, traceId);
  }
  if (!/^[0-9A-Fa-f]{5}$/.test(sha1Prefix)) {
    return json({ ok: false, code: "sha1_prefix_invalid" }, 400, traceId);
  }
  const prefix = sha1Prefix.toUpperCase();

  // Availability policy (matches the web app's lib/leaked-password.ts):
  // fail open on HIBP network/API errors so a third-party outage cannot
  // lock users out, but never report a confirmed breach suffix as clean.
  let suffixes: string[] = [];
  let degraded = false;
  try {
    const res = await fetch(`${hibpRangeUrl}${prefix}`, {
      headers: { "Add-Padding": "true" },
      cache: "no-store",
      signal: AbortSignal.timeout(hibpTimeoutMs),
    });
    if (res.ok) {
      const body = await res.text();
      suffixes = body
        .split("\n")
        .map((line) => line.trim().split(":")[0])
        .filter((suffix) => /^[0-9A-F]{35}$/.test(suffix));
    } else {
      degraded = true;
    }
  } catch (error) {
    structuredLog("warn", "leaked_password_check_hibp_unavailable", {
      trace_id: traceId,
      error: String(error),
    });
    degraded = true;
  }

  return json(
    { ok: true, degraded, suffixes },
    200,
    traceId,
  );
});

async function readJson(request: Request) {
  const declaredLength = Number(request.headers.get("content-length") ?? "0");
  if (Number.isFinite(declaredLength) && declaredLength > maximumBodyBytes) {
    throw new Error("payload_too_large");
  }
  const text = await request.text();
  if (new TextEncoder().encode(text).byteLength > maximumBodyBytes) {
    throw new Error("payload_too_large");
  }
  const value = JSON.parse(text);
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("invalid_json");
  }
  return value as Record<string, unknown>;
}

function json(body: Record<string, unknown>, status: number, traceId: string) {
  return correlatedJson(body, status, traceId, {
    ...corsHeaders,
    "Cache-Control": "private, no-store",
  });
}
