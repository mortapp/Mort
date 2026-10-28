import { createClient } from "https://esm.sh/@supabase/supabase-js@2.110.1";

const headers = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};
const response = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), { status, headers });

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers });
  if (request.method !== "POST") return response({ ok: false, code: "post_required" }, 405);
  try {
    const url = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const authorization = request.headers.get("Authorization") ?? "";
    const token = authorization.match(/^Bearer\s+(.+)$/i)?.[1];
    if (!url || !anonKey) return response({ ok: false, code: "server_not_configured" }, 503);
    if (!token) return response({ ok: false, code: "authentication_required" }, 401);
    const client = createClient(url, anonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
      global: { headers: { Authorization: `Bearer ${token}` } },
    });
    const { data: userData, error: authError } = await client.auth.getUser(token);
    if (authError || !userData.user) return response({ ok: false, code: "invalid_session" }, 401);
    const [{ data: databaseStatus, error: stripeError }, { data: releaseStatus, error: releaseError }] = await Promise.all([
      client.rpc("get_stripe_runtime_status"),
      client.rpc("get_release_mode_status"),
    ]);
    if (stripeError || releaseError || !databaseStatus || !releaseStatus) {
      return response({ ok: false, code: "runtime_controls_unavailable" }, 503);
    }
    const mode = Deno.env.get("MORT_STRIPE_MODE") ?? "disabled";
    const environment = mode === "sandbox" ? "test" : mode === "live" ? "live" : null;
    const secret = environment
      ? Deno.env.get(environment === "test" ? "STRIPE_TEST_SECRET_KEY" : "STRIPE_LIVE_SECRET_KEY")
      : null;
    const publishable = environment
      ? Deno.env.get(environment === "test" ? "STRIPE_TEST_PUBLISHABLE_KEY" : "STRIPE_LIVE_PUBLISHABLE_KEY")
      : null;
    const webhook = environment
      ? Deno.env.get(environment === "test" ? "STRIPE_TEST_WEBHOOK_SECRET" : "STRIPE_LIVE_WEBHOOK_SECRET")
      : null;
    const prefixMatches = environment === "test"
      ? secret?.startsWith("sk_test_") === true && publishable?.startsWith("pk_test_") === true
      : environment === "live"
      ? secret?.startsWith("sk_live_") === true && publishable?.startsWith("pk_live_") === true
      : false;
    const credentialsConfigured = prefixMatches && webhook?.startsWith("whsec_") === true;
    const controlModeMatches = databaseStatus.mode === mode && databaseStatus.environment === environment;
    const paymentPathReady = credentialsConfigured && controlModeMatches &&
      databaseStatus.payments_enabled === true && databaseStatus.job_funding_enabled === true &&
      releaseStatus.maintenance_mode !== true && releaseStatus.public_marketplace_enabled === true &&
      (mode !== "live" || databaseStatus.live_mode_enabled === true);
    return response({
      ok: true,
      ...databaseStatus,
      configured: credentialsConfigured,
      credentials_configured: credentialsConfigured,
      environment,
      payment_path_ready: paymentPathReady,
      public_marketplace_enabled: releaseStatus.public_marketplace_enabled === true,
      maintenance_mode: releaseStatus.maintenance_mode === true,
    });
  } catch {
    return response({ ok: false, code: "stripe_status_unavailable" }, 500);
  }
});
