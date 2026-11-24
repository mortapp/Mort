import Stripe from "npm:stripe@22.1.1";
import { createClient } from "npm:@supabase/supabase-js@2.110.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const maximumBodyBytes = 16 * 1024;

class PublicError extends Error {
  constructor(readonly code: string, readonly status: number) {
    super(code);
  }
}

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function safeError(error: unknown) {
  if (error instanceof PublicError) return json({ ok: false, code: error.code }, error.status);
  console.error("stripe_onboarding_link_failed", error instanceof Error ? error.name : "unknown");
  return json({ ok: false, code: "stripe_operation_failed" }, 502);
}

function validatedRedirectUrl(value: unknown, kind: "return" | "refresh") {
  if (typeof value !== "string" || value.length > 500) {
    throw new PublicError(`invalid_${kind}_url`, 400);
  }
  let url: URL;
  try {
    url = new URL(value);
  } catch {
    throw new PublicError(`invalid_${kind}_url`, 400);
  }
  const configured = (Deno.env.get("MORT_STRIPE_ALLOWED_REDIRECT_ORIGINS") ?? "https://mort-web.vercel.app")
    .split(",").map((origin) => origin.trim()).filter(Boolean);
  if (url.protocol !== "https:" || !configured.includes(url.origin)) {
    throw new PublicError(`unapproved_${kind}_url`, 400);
  }
  return url.toString();
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ ok: false, code: "post_required" }, 405);

  try {
    const declaredLength = Number(request.headers.get("content-length") ?? "0");
    if (Number.isFinite(declaredLength) && declaredLength > maximumBodyBytes) {
      throw new PublicError("payload_too_large", 413);
    }
    const rawBody = await request.text();
    if (new TextEncoder().encode(rawBody).byteLength > maximumBodyBytes) {
      throw new PublicError("payload_too_large", 413);
    }
    let payload: Record<string, unknown>;
    try {
      payload = rawBody.trim() ? JSON.parse(rawBody) : {};
    } catch {
      throw new PublicError("invalid_json", 400);
    }
    const returnUrl = validatedRedirectUrl(payload.return_url, "return");
    const refreshUrl = validatedRedirectUrl(payload.refresh_url, "refresh");

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      throw new PublicError("server_not_configured", 503);
    }
    const authorization = request.headers.get("Authorization") ?? "";
    const match = authorization.match(/^Bearer\s+(.+)$/i);
    if (!match) throw new PublicError("authentication_required", 401);
    const accessToken = match[1];

    const userClient = createClient(supabaseUrl, anonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
      global: { headers: { Authorization: `Bearer ${accessToken}` } },
    });
    const { data: authData, error: authError } = await userClient.auth.getUser(accessToken);
    if (authError || !authData.user) throw new PublicError("invalid_session", 401);
    const serviceClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: rateAllowed, error: rateError } = await userClient.rpc(
      "consume_my_edge_action_limit",
      { p_action: "stripe_onboarding_link" },
    );
    if (rateError) throw new PublicError("rate_limit_check_failed", 503);
    if (rateAllowed !== true) throw new PublicError("rate_limit_exceeded", 429);

    if (Deno.env.get("MORT_STRIPE_MODE") !== "sandbox") {
      throw new PublicError("stripe_connect_guardian_review_required", 403);
    }
    const secretKey = Deno.env.get("STRIPE_TEST_SECRET_KEY");
    const publishableKey = Deno.env.get("STRIPE_TEST_PUBLISHABLE_KEY");
    if (!secretKey || !publishableKey) throw new PublicError("stripe_server_not_configured", 503);
    if (!secretKey.startsWith("sk_test_") || !publishableKey.startsWith("pk_test_")) {
      throw new PublicError("stripe_key_mode_mismatch", 503);
    }

    const { data: featureStatus, error: featureError } = await serviceClient.rpc(
      "get_runtime_feature_status",
    );
    if (featureError || featureStatus?.ok !== true) {
      throw new PublicError("runtime_controls_unavailable", 503);
    }
    if (featureStatus.maintenance_mode === true) {
      throw new PublicError("maintenance_mode_active", 503);
    }
    const { data: stripeStatus, error: stripeStatusError } = await userClient.rpc(
      "get_stripe_runtime_status",
    );
    if (
      stripeStatusError || stripeStatus?.mode !== "sandbox" ||
      stripeStatus?.environment !== "test"
    ) {
      throw new PublicError("stripe_runtime_mode_mismatch", 503);
    }

    const { data: prepared, error: prepareError } = await serviceClient.rpc(
      "stripe_server_prepare_connected_account",
      { p_user_id: authData.user.id, p_environment: "test" },
    );
    if (prepareError) {
      const message = String(prepareError.message ?? "");
      if (message.includes("sandbox_provider_qa_not_approved")) {
        throw new PublicError("sandbox_provider_qa_not_approved", 403);
      }
      if (message.includes("stripe_connected_onboarding_disabled")) {
        throw new PublicError("stripe_connected_onboarding_disabled", 403);
      }
      if (message.includes("sandbox_test_account_required")) {
        throw new PublicError("sandbox_test_account_required", 403);
      }
      if (message.includes("eligible_teen_required") || message.includes("teen_age_required")) {
        throw new PublicError("eligible_teen_required", 403);
      }
      throw new PublicError("connected_account_preparation_failed", 503);
    }
    if (!prepared.provider_account_id) {
      throw new PublicError("connected_account_required", 409);
    }

    const stripe = new Stripe(secretKey, {
      maxNetworkRetries: 2,
      timeout: 20_000,
      telemetry: false,
    });
    const link = await stripe.v2.core.accountLinks.create({
      account: prepared.provider_account_id,
      use_case: {
        type: "account_onboarding",
        account_onboarding: {
          refresh_url: refreshUrl,
          return_url: returnUrl,
        },
      },
    });

    const expires = Date.parse(link.expires_at);
    let linkUrl: URL | undefined;
    try {
      linkUrl = new URL(link.url);
    } catch {
      // Reject missing or malformed provider URLs below.
    }
    if (
      link.livemode !== false || link.account !== prepared.provider_account_id ||
      !Number.isFinite(expires) || expires <= Date.now() ||
      linkUrl?.origin !== "https://connect.stripe.com" || linkUrl.username || linkUrl.password
    ) {
      throw new PublicError("stripe_connect_sandbox_response_mismatch", 502);
    }

    const { error: recordError } = await serviceClient.rpc(
      "stripe_server_record_onboarding_session",
      {
        p_user_id: authData.user.id,
        p_environment: "test",
        p_provider_account_link_id: null,
        p_return_url_origin: new URL(returnUrl).origin,
        p_refresh_url_origin: new URL(refreshUrl).origin,
        p_expires_at: new Date(expires).toISOString(),
      },
    );
    if (recordError) throw new PublicError("onboarding_session_record_failed", 503);
    return json({
      ok: true,
      onboarding_url: link.url,
      expires_at: new Date(expires).toISOString(),
    });
  } catch (error) {
    return safeError(error);
  }
});
