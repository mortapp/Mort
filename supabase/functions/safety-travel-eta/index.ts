import { createClient } from "https://esm.sh/@supabase/supabase-js@2.110.1";
import {
  computeSafetyDuration,
  readSafetyRouteApplication,
} from "../_shared/safety_route.ts";

const headers = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Content-Type": "application/json",
  "Cache-Control": "no-store",
};
const json = (code: string, status = 200) =>
  new Response(JSON.stringify({ ok: code === "updated", code }), {
    status,
    headers,
  });

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers });
  if (request.method !== "POST") return json("post_required", 405);
  const url = Deno.env.get("SUPABASE_URL"),
    service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !service) return json("safety_service_unavailable", 503);
  const token = (request.headers.get("authorization") ?? "").replace(
    /^Bearer\s+/i,
    "",
  ).trim();
  if (!token) return json("authentication_required", 401);
  const admin = createClient(url, service, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const user = await admin.auth.getUser(token);
  if (user.error || !user.data.user) {
    return json("authentication_required", 401);
  }
  let application: string;
  try {
    application = await readSafetyRouteApplication(request);
  } catch (_) {
    return json("invalid_route_request", 400);
  }
  const key = Deno.env.get("GOOGLE_ROUTES_API_KEY");
  // Provider enablement requires an explicit server flag and credential.
  if (Deno.env.get("MORT_SAFETY_ROUTE_ETA_ENABLED") !== "true" || !key) {
    return json("route_provider_disabled");
  }
  try {
    const claimed = await admin.rpc("safety_server_claim_route", {
      p_actor_id: user.data.user.id,
      p_application_id: application,
    });
    if (claimed.error || claimed.data?.ok !== true) {
      return json("route_unavailable");
    }
    const seconds = await computeSafetyDuration(claimed.data, key);
    const recorded = await admin.rpc("safety_server_record_route", {
      p_actor_id: user.data.user.id,
      p_application_id: application,
      p_request_id: claimed.data.request_id,
      p_duration_seconds: seconds,
    });
    return json(
      !recorded.error && recorded.data?.ok === true
        ? "updated"
        : "trip_changed",
    );
  } catch (_) {
    return json("route_provider_unavailable");
  }
});
