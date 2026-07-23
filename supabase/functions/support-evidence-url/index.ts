import { createClient } from "https://esm.sh/@supabase/supabase-js@2.110.1";

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

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return response({ ok: false, code: "post_required" }, 405);

  const token = (request.headers.get("authorization") ?? "").replace(/^Bearer\s+/i, "").trim();
  if (!token) return response({ ok: false, code: "authentication_required" }, 401);

  const { data: userData, error: userError } = await admin.auth.getUser(token);
  if (userError || !userData.user) return response({ ok: false, code: "authentication_required" }, 401);

  let evidenceId = "";
  try {
    const body = await request.json();
    evidenceId = typeof body?.evidenceId === "string" ? body.evidenceId : "";
  } catch {
    return response({ ok: false, code: "invalid_json" }, 400);
  }
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(evidenceId)) {
    return response({ ok: false, code: "valid_evidence_id_required" }, 400);
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
    return response({ ok: false, code: "signed_url_rate_limited" }, 429);
  }
  if (authorizationError || authorization?.ok !== true) {
    return response({ ok: false, code: "evidence_not_authorized" }, 403);
  }

  const { data: signed, error: signedError } = await admin.storage
    .from(String(authorization.bucket_id))
    .createSignedUrl(String(authorization.object_path), 300);
  if (signedError || !signed?.signedUrl) {
    return response({ ok: false, code: "evidence_preview_unavailable" }, 503);
  }
  return response({
    ok: true,
    signedUrl: signed.signedUrl,
    expiresAt: new Date(Date.now() + 300_000).toISOString(),
  });
});

function response(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      "Cache-Control": "private, no-store",
    },
  });
}
