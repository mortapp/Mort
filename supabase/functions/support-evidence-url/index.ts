import { createClient } from "https://esm.sh/@supabase/supabase-js@2.110.1";
import {
  correlatedJson,
  correlationId,
  structuredLog,
} from "../_shared/observability.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const anonKey = Deno.env.get("SUPABASE_ANON_KEY");

if (!supabaseUrl || !serviceRoleKey || !anonKey) {
  throw new Error("Supabase server environment is not configured.");
}

const admin = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const maximumBodyBytes = 8 * 1024;

Deno.serve(async (request: Request) => {
  const traceId = correlationId(request);
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return response({ ok: false, code: "post_required" }, 405, traceId);

  const token = (request.headers.get("authorization") ?? "").replace(/^Bearer\s+/i, "").trim();
  if (!token) return response({ ok: false, code: "authentication_required" }, 401, traceId);

  const { data: userData, error: userError } = await admin.auth.getUser(token);
  if (userError || !userData.user) return response({ ok: false, code: "authentication_required" }, 401, traceId);

  let evidenceId = "";
  try {
    const body = await readJson(request);
    evidenceId = typeof body?.evidenceId === "string" ? body.evidenceId : "";
  } catch (error) {
    const code = error instanceof PayloadError ? error.code : "invalid_json";
    const status = error instanceof PayloadError ? error.status : 400;
    return response({ ok: false, code }, status, traceId);
  }
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(evidenceId)) {
    return response({ ok: false, code: "valid_evidence_id_required" }, 400, traceId);
  }

  const scoped = createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
  const { data: authorization, error: authorizationError } = await scoped.rpc(
    "authorize_support_evidence_url",
    { p_evidence_id: evidenceId },
  );
  if (authorization?.code === "signed_url_rate_limited") {
    return response({ ok: false, code: "signed_url_rate_limited" }, 429, traceId);
  }
  if (authorizationError || authorization?.ok !== true) {
    if (authorizationError) {
      structuredLog("warn", "support_evidence.authorization_failed", traceId, {
        databaseCode: authorizationError.code,
      });
    }
    return response({ ok: false, code: "evidence_not_authorized" }, 403, traceId);
  }

  const { data: signed, error: signedError } = await admin.storage
    .from(String(authorization.bucket_id))
    .createSignedUrl(String(authorization.object_path), 300);
  if (signedError || !signed?.signedUrl) {
    structuredLog("error", "support_evidence.signed_url_failed", traceId, {
      storageCode: signedError?.name ?? "missing_url",
    });
    return response({ ok: false, code: "evidence_preview_unavailable" }, 503, traceId);
  }
  return response({
    ok: true,
    signedUrl: signed.signedUrl,
    expiresAt: new Date(Date.now() + 300_000).toISOString(),
  }, 200, traceId);
});

async function readJson(request: Request) {
  const declaredLength = Number(request.headers.get("content-length") ?? "0");
  if (Number.isFinite(declaredLength) && declaredLength > maximumBodyBytes) {
    throw new PayloadError("payload_too_large", 413);
  }
  const text = await request.text();
  if (new TextEncoder().encode(text).byteLength > maximumBodyBytes) {
    throw new PayloadError("payload_too_large", 413);
  }
  const value = JSON.parse(text);
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new PayloadError("invalid_json", 400);
  }
  return value as Record<string, unknown>;
}

function response(
  body: Record<string, unknown>,
  status = 200,
  traceId = crypto.randomUUID(),
) {
  return correlatedJson(body, status, traceId, {
    ...corsHeaders,
    "Cache-Control": "private, no-store",
  });
}

class PayloadError extends Error {
  constructor(readonly code: string, readonly status: number) {
    super(code);
  }
}
