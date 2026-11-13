import { createClient } from "npm:@supabase/supabase-js@2.110.1";
import {
  correlatedJson,
  correlationId,
  safeErrorKind,
  structuredLog,
} from "../_shared/observability.ts";
import {
  parseHibpRangeResponse,
  sha1Hex,
} from "../_shared/leaked_password.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const anonKey = Deno.env.get("SUPABASE_ANON_KEY");

if (!supabaseUrl || (!serviceRoleKey && !anonKey)) {
  throw new Error("Supabase server environment is not configured.");
}

const admin = createClient(supabaseUrl, serviceRoleKey || anonKey!, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-correlation-id",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const maximumBodyBytes = 2 * 1024;
const maximumPasswordLength = 512;
const hibpTimeoutMs = 4000;
const hibpRangeUrl = "https://api.pwnedpasswords.com/range/";

// Best-effort per-isolate throttle. It is not a substitute for a shared
// distributed rate limiter, but prevents a single authenticated session
// from using one warm isolate as an unrestricted HIBP proxy.
const perUserCalls = new Map<string, { windowStart: number; count: number }>();
const rateWindowMs = 60_000;
const rateWindowMax = 10;

function rateLimited(userId: string): boolean {
  const now = Date.now();
  const entry = perUserCalls.get(userId);
  if (!entry || now - entry.windowStart >= rateWindowMs) {
    perUserCalls.set(userId, { windowStart: now, count: 1 });
  } else {
    entry.count += 1;
    if (entry.count > rateWindowMax) return true;
  }

  if (perUserCalls.size > 10_000) {
    for (const [id, value] of perUserCalls) {
      if (now - value.windowStart >= rateWindowMs) perUserCalls.delete(id);
    }
  }
  return false;
}

Deno.serve(async (request) => {
  const traceId = correlationId(request);
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405, traceId, {
      Allow: "POST, OPTIONS",
    });
  }

  const authorizationHeader = request.headers.get("authorization") ?? "";
  const token = authorizationHeader.replace(/^Bearer\s+/i, "").trim();
  if (!token) {
    return json({ error: "unauthorized" }, 401, traceId);
  }

  let userId: string;
  try {
    const { data, error } = await admin.auth.getUser(token);
    if (error || !data.user) {
      return json({ error: "unauthorized" }, 401, traceId);
    }
    userId = data.user.id;
  } catch {
    return json({ error: "unauthorized" }, 401, traceId);
  }

  if (rateLimited(userId)) {
    return json({ error: "rate_limited" }, 429, traceId);
  }

  let password: string;
  try {
    const body = await readJson(request);
    if (
      typeof body.password !== "string" ||
      body.password.length < 1 ||
      body.password.length > maximumPasswordLength
    ) {
      return json({ error: "invalid_password_payload" }, 400, traceId);
    }
    password = body.password;
  } catch {
    return json({ error: "invalid_request" }, 400, traceId);
  }

  let leaked = false;
  let checkUnavailable = false;
  try {
    const digest = await sha1Hex(password);
    const prefix = digest.slice(0, 5);
    const suffix = digest.slice(5);
    const response = await fetch(`${hibpRangeUrl}${prefix}`, {
      method: "GET",
      headers: {
        "Add-Padding": "true",
        "User-Agent": "MORT-Leaked-Password-Check/1.0",
      },
      cache: "no-store",
      signal: AbortSignal.timeout(hibpTimeoutMs),
    });
    if (!response.ok) throw new Error("hibp_range_failed");

    const parsed = parseHibpRangeResponse(await response.text(), suffix);
    if (!parsed.valid) throw new Error("hibp_range_invalid");
    leaked = parsed.leaked;
  } catch (error) {
    checkUnavailable = true;
    structuredLog("warn", "hibp_check_unavailable", traceId, {
      error_kind: safeErrorKind(error),
    });
  }

  // Never log the password, its digest, the HIBP prefix, or response rows.
  structuredLog("info", "leaked_password_check_completed", traceId, {
    leaked,
    check_unavailable: checkUnavailable,
  });

  return json(
    { leaked, ...(checkUnavailable ? { check_unavailable: true } : {}) },
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

function json(
  body: Record<string, unknown>,
  status: number,
  traceId: string,
  extraHeaders: HeadersInit = {},
) {
  return correlatedJson(body, status, traceId, {
    ...corsHeaders,
    ...extraHeaders,
    "Cache-Control": "private, no-store",
  });
}
