import Stripe from "npm:stripe@22.1.1";
import { createClient, SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2.110.1";

export type StripeEnvironment = "test" | "live";

export type StripeRuntime = {
  mode: "sandbox" | "live";
  environment: StripeEnvironment;
  secretKey: string;
  publishableKey: string;
  webhookSecret?: string;
  stripe: Stripe;
};

export type StripeContext = {
  user: User;
  accessToken: string;
  userClient: SupabaseClient;
  serviceClient: SupabaseClient;
};

const maximumBodyBytes = 32 * 1024;

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info, x-mort-operations-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

export function options(request: Request) {
  return request.method === "OPTIONS" ? new Response("ok", { headers: corsHeaders }) : null;
}

export async function authenticate(request: Request): Promise<StripeContext> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceRoleKey) throw new PublicError("server_not_configured", 503);

  const authorization = request.headers.get("Authorization") ?? "";
  const match = authorization.match(/^Bearer\s+(.+)$/i);
  if (!match) throw new PublicError("authentication_required", 401);
  const accessToken = match[1];

  const authClient = createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: `Bearer ${accessToken}` } },
  });
  const { data, error } = await authClient.auth.getUser(accessToken);
  if (error || !data.user) throw new PublicError("invalid_session", 401);

  const serviceClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  return { user: data.user, accessToken, userClient: authClient, serviceClient };
}

export async function readJson<T extends Record<string, unknown>>(request: Request): Promise<T> {
  const declaredLength = Number(request.headers.get("content-length") ?? "0");
  if (Number.isFinite(declaredLength) && declaredLength > maximumBodyBytes) {
    throw new PublicError("payload_too_large", 413);
  }
  const text = await request.text();
  if (new TextEncoder().encode(text).byteLength > maximumBodyBytes) throw new PublicError("payload_too_large", 413);
  try {
    return (text.trim() ? JSON.parse(text) : {}) as T;
  } catch {
    throw new PublicError("invalid_json", 400);
  }
}

export async function requireRateLimit(context: StripeContext, action: string, limit: number, windowSeconds: number) {
  const { data, error } = await context.userClient.rpc("check_rate_limit", {
    p_action: action,
    p_limit: limit,
    p_window_seconds: windowSeconds,
  });
  if (error) throw new PublicError("rate_limit_check_failed", 503);
  if (data !== true) throw new PublicError("rate_limit_exceeded", 429);
}

export async function runtime(context: StripeContext, needsWebhookSecret = false): Promise<StripeRuntime> {
  const mode = Deno.env.get("MORT_STRIPE_MODE") ?? "disabled";
  if (mode !== "sandbox" && mode !== "live") throw new PublicError("stripe_disabled", 503);
  const environment: StripeEnvironment = mode === "sandbox" ? "test" : "live";
  const secretKey = Deno.env.get(environment === "test" ? "STRIPE_TEST_SECRET_KEY" : "STRIPE_LIVE_SECRET_KEY");
  const publishableKey = Deno.env.get(environment === "test" ? "STRIPE_TEST_PUBLISHABLE_KEY" : "STRIPE_LIVE_PUBLISHABLE_KEY");
  const webhookSecret = Deno.env.get(environment === "test" ? "STRIPE_TEST_WEBHOOK_SECRET" : "STRIPE_LIVE_WEBHOOK_SECRET");
  if (!secretKey || !publishableKey || (needsWebhookSecret && !webhookSecret)) {
    throw new PublicError("stripe_server_not_configured", 503);
  }
  if (!secretKey.startsWith(environment === "test" ? "sk_test_" : "sk_live_")) throw new PublicError("stripe_key_mode_mismatch", 503);
  if (!publishableKey.startsWith(environment === "test" ? "pk_test_" : "pk_live_")) throw new PublicError("stripe_key_mode_mismatch", 503);
  if (needsWebhookSecret && !webhookSecret?.startsWith("whsec_")) throw new PublicError("stripe_webhook_not_configured", 503);

  const { data, error } = await context.userClient.rpc("get_stripe_runtime_status");
  if (error || data?.environment !== environment || data?.mode !== mode) throw new PublicError("stripe_runtime_mode_mismatch", 503);
  if (mode === "live" && data?.live_mode_enabled !== true) throw new PublicError("stripe_live_disabled", 503);

  return {
    mode,
    environment,
    secretKey,
    publishableKey,
    webhookSecret,
    stripe: new Stripe(secretKey, { maxNetworkRetries: 2, timeout: 20_000, telemetry: false }),
  };
}

export function webhookRuntime(): StripeRuntime {
  const mode = Deno.env.get("MORT_STRIPE_MODE") ?? "disabled";
  if (mode !== "sandbox" && mode !== "live") throw new PublicError("stripe_disabled", 503);
  const environment: StripeEnvironment = mode === "sandbox" ? "test" : "live";
  const secretKey = Deno.env.get(environment === "test" ? "STRIPE_TEST_SECRET_KEY" : "STRIPE_LIVE_SECRET_KEY");
  const publishableKey = Deno.env.get(environment === "test" ? "STRIPE_TEST_PUBLISHABLE_KEY" : "STRIPE_LIVE_PUBLISHABLE_KEY");
  const webhookSecret = Deno.env.get(environment === "test" ? "STRIPE_TEST_WEBHOOK_SECRET" : "STRIPE_LIVE_WEBHOOK_SECRET");
  if (!secretKey || !publishableKey || !webhookSecret) throw new PublicError("stripe_webhook_not_configured", 503);
  if (!secretKey.startsWith(environment === "test" ? "sk_test_" : "sk_live_") ||
      !publishableKey.startsWith(environment === "test" ? "pk_test_" : "pk_live_") ||
      !webhookSecret.startsWith("whsec_")) throw new PublicError("stripe_key_mode_mismatch", 503);
  return {
    mode,
    environment,
    secretKey,
    publishableKey,
    webhookSecret,
    stripe: new Stripe(secretKey, { maxNetworkRetries: 2, timeout: 20_000, telemetry: false }),
  };
}

export function serviceClient() {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) throw new PublicError("server_not_configured", 503);
  return createClient(supabaseUrl, serviceRoleKey, { auth: { persistSession: false, autoRefreshToken: false } });
}

export function requireOperationsSecret(request: Request) {
  const expected = Deno.env.get("MORT_STRIPE_OPERATIONS_SECRET");
  const supplied = request.headers.get("x-mort-operations-secret");
  if (!expected || !supplied || !constantTimeEqual(expected, supplied)) throw new PublicError("operations_authorization_required", 401);
}

export function validatedRedirectUrl(value: unknown, kind: "return" | "refresh") {
  if (typeof value !== "string" || value.length > 500) throw new PublicError(`invalid_${kind}_url`, 400);
  let url: URL;
  try {
    url = new URL(value);
  } catch {
    throw new PublicError(`invalid_${kind}_url`, 400);
  }
  const configured = (Deno.env.get("MORT_STRIPE_ALLOWED_REDIRECT_ORIGINS") ?? "https://mort-web.vercel.app")
    .split(",").map((origin) => origin.trim()).filter(Boolean);
  if (url.protocol !== "https:" || !configured.includes(url.origin)) throw new PublicError(`unapproved_${kind}_url`, 400);
  return url.toString();
}

export function providerStatus(status: string) {
  const allowed = new Set(["requires_payment_method", "requires_action", "processing", "succeeded", "canceled"]);
  return allowed.has(status) ? status : "requires_payment_method";
}

export function safeError(error: unknown) {
  if (error instanceof PublicError) return json({ ok: false, code: error.code }, error.status);
  if (error instanceof Stripe.errors.StripeError) {
    console.error("Stripe operation failed", { type: error.type, code: error.code });
    return json({ ok: false, code: "stripe_operation_failed", provider_code: safeProviderCode(error.code) }, 400);
  }
  console.error("Stripe function failed", { kind: error instanceof Error ? error.name : "unknown" });
  return json({ ok: false, code: "stripe_operation_failed" }, 500);
}

export class PublicError extends Error {
  constructor(public readonly code: string, public readonly status: number) {
    super(code);
  }
}

export function assertUuid(value: unknown, field: string) {
  if (typeof value !== "string" || !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value)) {
    throw new PublicError(`invalid_${field}`, 400);
  }
  return value;
}

export async function sha256(value: string) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest)).map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

function safeProviderCode(code?: string) {
  return typeof code === "string" && /^[a-z0-9_]{2,80}$/.test(code) ? code : undefined;
}

function constantTimeEqual(left: string, right: string) {
  const leftBytes = new TextEncoder().encode(left);
  const rightBytes = new TextEncoder().encode(right);
  let mismatch = leftBytes.length ^ rightBytes.length;
  const length = Math.max(leftBytes.length, rightBytes.length);
  for (let index = 0; index < length; index += 1) mismatch |= (leftBytes[index] ?? 0) ^ (rightBytes[index] ?? 0);
  return mismatch === 0;
}
