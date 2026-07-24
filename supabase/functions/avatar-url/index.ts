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

  let profileId = "";
  let requestedPath = "";
  try {
    const body = await readJson(request);
    profileId = typeof body?.profileId === "string" ? body.profileId : "";
    requestedPath = typeof body?.avatarPath === "string" ? body.avatarPath : "";
  } catch (error) {
    const code = error instanceof PayloadError ? error.code : "invalid_json";
    const status = error instanceof PayloadError ? error.status : 400;
    return json({ ok: false, code }, status, traceId);
  }
  if (!profileId.match(/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i)) {
    return json({ ok: false, code: "valid_profile_id_required" }, 400, traceId);
  }
  if (requestedPath.length > 512) {
    return json({ ok: false, code: "invalid_avatar_path" }, 400, traceId);
  }

  const scoped = createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
  const { data: avatarAuthorization, error: authorizationError } = await scoped.rpc(
    "authorize_profile_avatar_url",
    { p_profile_id: profileId, p_requested_path: requestedPath || null },
  );
  if (authorizationError) {
    structuredLog("error", "avatar.authorization_lookup_failed", traceId, {
      databaseCode: authorizationError.code,
    });
    return json({ ok: false, code: "avatar_lookup_failed" }, 503, traceId);
  }
  if (avatarAuthorization?.code === "signed_url_rate_limited") {
    return json({ ok: false, code: "signed_url_rate_limited" }, 429, traceId);
  }
  if (avatarAuthorization?.ok !== true) {
    return json({ ok: false, code: "avatar_not_authorized" }, 403, traceId);
  }
  const objectPath = typeof avatarAuthorization.object_path === "string"
    ? avatarAuthorization.object_path
    : null;
  if (!objectPath) return json({ ok: true, signedUrl: null }, 200, traceId);

  const { data: signed, error: signedError } = await admin.storage
    .from("profile-avatars")
    .createSignedUrl(objectPath, 3600);
  if (signedError) {
    structuredLog("error", "avatar.signed_url_failed", traceId, {
      storageCode: signedError.name,
    });
    return json({ ok: false, code: "avatar_preview_unavailable" }, 503, traceId);
  }
  return json({
    ok: true,
    signedUrl: signed.signedUrl,
    expiresAt: new Date(Date.now() + 3600_000).toISOString(),
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

function json(body: Record<string, unknown>, status: number, traceId: string) {
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
