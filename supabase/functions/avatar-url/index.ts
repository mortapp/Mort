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

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return json({ error: "POST required" }, 405);
  }

  const authorizationHeader = request.headers.get("authorization") ?? "";
  const token = authorizationHeader.replace(/^Bearer\s+/i, "").trim();
  if (!token) return json({ error: "Authentication required" }, 401);

  const { data: userData, error: userError } = await admin.auth.getUser(token);
  if (userError || !userData.user) {
    return json({ error: "Authentication required" }, 401);
  }

  let profileId = "";
  let requestedPath = "";
  try {
    const body = await request.json();
    profileId = typeof body?.profileId === "string" ? body.profileId : "";
    requestedPath = typeof body?.avatarPath === "string" ? body.avatarPath : "";
  } catch {
    return json({ error: "Request body must be valid JSON" }, 400);
  }
  if (!profileId.match(/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i)) {
    return json({ error: "Valid profileId required" }, 400);
  }

  const scoped = createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
  const { data: avatarAuthorization, error: authorizationError } = await scoped.rpc(
    "authorize_profile_avatar_url",
    { p_profile_id: profileId, p_requested_path: requestedPath || null },
  );
  if (authorizationError) return json({ error: "Avatar lookup failed" }, 500);
  if (avatarAuthorization?.code === "signed_url_rate_limited") {
    return json({ error: "Avatar requests are temporarily limited" }, 429);
  }
  if (avatarAuthorization?.ok !== true) {
    return json({ error: "Avatar lookup failed" }, 403);
  }
  const objectPath = typeof avatarAuthorization.object_path === "string"
    ? avatarAuthorization.object_path
    : null;
  if (!objectPath) return json({ signedUrl: null }, 200);

  const { data: signed, error: signedError } = await admin.storage
    .from("profile-avatars")
    .createSignedUrl(objectPath, 3600);
  if (signedError) return json({ error: "Avatar preview failed" }, 500);
  return json({ signedUrl: signed.signedUrl, expiresAt: new Date(Date.now() + 3600_000).toISOString() }, 200);
});

function json(body: Record<string, unknown>, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json", "Cache-Control": "private, no-store" },
  });
}
