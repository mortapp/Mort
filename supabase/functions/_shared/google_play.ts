import { GoogleAuth } from "npm:google-auth-library@10.9.0";
import { createClient, SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2.110.1";

export const packageName = "com.mortapp.mobile";
export const subscriptionProductId = "mort_plus";
export const allowedProductIds = new Set([
  subscriptionProductId,
  "mort_theme_neon_pack",
  "mort_theme_midnight_pack",
  "mort_profile_frames_pack_01",
  "mort_portfolio_layouts_pack_01",
]);

export class PublicError extends Error {
  constructor(readonly code: string, readonly status: number) {
    super(code);
  }
}

export type BillingContext = {
  user: User;
  userClient: SupabaseClient;
  serviceClient: SupabaseClient;
};

export type VerifiedPurchase = {
  productId: string;
  basePlanId: string | null;
  state: "pending" | "purchased" | "cancelled" | "expired" | "refunded" | "revoked" | "on_hold" | "grace_period" | "paused";
  acknowledgementState: "pending" | "acknowledged" | "not_required" | "failed";
  orderId: string | null;
  purchasedAt: string | null;
  expiresAt: string | null;
  obfuscatedAccountId: string | null;
  environment: "license_test" | "production";
  raw: Record<string, unknown>;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
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

export function safeError(error: unknown) {
  if (error instanceof PublicError) return json({ ok: false, code: error.code }, error.status);
  console.error("Google Play Billing request failed", { kind: error instanceof Error ? error.name : "unknown" });
  return json({ ok: false, code: "google_play_request_failed" }, 500);
}

export async function authenticate(request: Request): Promise<BillingContext> {
  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceKey) throw new PublicError("server_not_configured", 503);
  const token = request.headers.get("Authorization")?.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!token) throw new PublicError("authentication_required", 401);
  const userClient = createClient(url, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
  const { data, error } = await userClient.auth.getUser(token);
  if (error || !data.user) throw new PublicError("invalid_session", 401);
  const serviceClient = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  return { user: data.user, userClient, serviceClient };
}

export function serviceClient() {
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) throw new PublicError("server_not_configured", 503);
  return createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
}

export async function sha256(value: string) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest)).map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

export function assertUuid(value: unknown, field: string) {
  if (typeof value !== "string" || !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value)) {
    throw new PublicError(`invalid_${field}`, 400);
  }
  return value;
}

export async function providerAccessToken() {
  const raw = Deno.env.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON");
  if (!raw) throw new PublicError("google_play_provider_not_configured", 503);
  let credentials: { client_email?: string; private_key?: string };
  try {
    credentials = JSON.parse(raw);
  } catch {
    throw new PublicError("google_play_credentials_invalid", 503);
  }
  if (!credentials.client_email || !credentials.private_key) throw new PublicError("google_play_credentials_invalid", 503);
  const auth = new GoogleAuth({
    credentials,
    scopes: ["https://www.googleapis.com/auth/androidpublisher"],
  });
  const client = await auth.getClient();
  const access = await client.getAccessToken();
  if (!access.token) throw new PublicError("google_play_auth_failed", 503);
  return access.token;
}

async function providerJson(url: string, accessToken: string, init?: RequestInit) {
  const response = await fetch(url, {
    ...init,
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
      ...(init?.headers ?? {}),
    },
  });
  if (!response.ok) {
    console.error("Google Play API rejected request", { status: response.status });
    if (response.status === 404) throw new PublicError("purchase_not_found", 404);
    if (response.status === 401 || response.status === 403) throw new PublicError("google_play_authorization_failed", 503);
    throw new PublicError("google_play_provider_error", 503);
  }
  if (response.status === 204) return {};
  return await response.json() as Record<string, unknown>;
}

function stringValue(value: unknown) {
  return typeof value === "string" && value.length > 0 ? value : null;
}

export async function verifyWithGoogle(productId: string, purchaseToken: string): Promise<VerifiedPurchase> {
  if (!allowedProductIds.has(productId)) throw new PublicError("wrong_product", 400);
  if (purchaseToken.length < 20 || purchaseToken.length > 4096) throw new PublicError("invalid_purchase_token", 400);
  const accessToken = await providerAccessToken();
  const encodedToken = encodeURIComponent(purchaseToken);
  const root = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packageName}/purchases`;

  if (productId === subscriptionProductId) {
    const raw = await providerJson(`${root}/subscriptionsv2/tokens/${encodedToken}`, accessToken);
    const lineItems = Array.isArray(raw.lineItems) ? raw.lineItems as Record<string, unknown>[] : [];
    const lineItem = lineItems.find((item) => item.productId === productId) ?? lineItems[0];
    if (!lineItem || lineItem.productId !== productId) throw new PublicError("wrong_product", 400);
    const offerDetails = (lineItem.offerDetails ?? {}) as Record<string, unknown>;
    const externalIds = (raw.externalAccountIdentifiers ?? {}) as Record<string, unknown>;
    const subscriptionState = String(raw.subscriptionState ?? "");
    const state = subscriptionState === "SUBSCRIPTION_STATE_ACTIVE" ? "purchased"
      : subscriptionState === "SUBSCRIPTION_STATE_IN_GRACE_PERIOD" ? "grace_period"
      : subscriptionState === "SUBSCRIPTION_STATE_ON_HOLD" ? "on_hold"
      : subscriptionState === "SUBSCRIPTION_STATE_PAUSED" ? "paused"
      : subscriptionState === "SUBSCRIPTION_STATE_PENDING" ? "pending"
      : subscriptionState === "SUBSCRIPTION_STATE_EXPIRED" ? "expired"
      : subscriptionState === "SUBSCRIPTION_STATE_CANCELED" ? "cancelled"
      : "revoked";
    return {
      productId,
      basePlanId: stringValue(offerDetails.basePlanId),
      state,
      acknowledgementState: raw.acknowledgementState === "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED" ? "acknowledged" : "pending",
      orderId: stringValue(raw.latestOrderId),
      purchasedAt: stringValue(raw.startTime),
      expiresAt: stringValue(lineItem.expiryTime),
      obfuscatedAccountId: stringValue(externalIds.obfuscatedExternalAccountId),
      environment: raw.testPurchase == null ? "production" : "license_test",
      raw,
    };
  }

  const raw = await providerJson(`${root}/productsv2/tokens/${encodedToken}`, accessToken);
  const lineItems = Array.isArray(raw.productLineItem) ? raw.productLineItem as Record<string, unknown>[] : [];
  if (!lineItems.some((item) => item.productId === productId)) throw new PublicError("wrong_product", 400);
  const stateContext = (raw.purchaseStateContext ?? {}) as Record<string, unknown>;
  const providerState = String(stateContext.purchaseState ?? "");
  const state = providerState === "PURCHASED" ? "purchased" : providerState === "PENDING" ? "pending" : "cancelled";
  return {
    productId,
    basePlanId: null,
    state,
    acknowledgementState: raw.acknowledgementState === "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED" ? "acknowledged" : "pending",
    orderId: stringValue(raw.orderId),
    purchasedAt: stringValue(raw.purchaseCompletionTime),
    expiresAt: null,
    obfuscatedAccountId: stringValue(raw.obfuscatedExternalAccountId),
    environment: raw.testPurchaseContext == null ? "production" : "license_test",
    raw,
  };
}

export async function acknowledgeWithGoogle(productId: string, purchaseToken: string) {
  const accessToken = await providerAccessToken();
  const encodedProduct = encodeURIComponent(productId);
  const encodedToken = encodeURIComponent(purchaseToken);
  const kind = productId === subscriptionProductId ? "subscriptions" : "products";
  const url = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packageName}/purchases/${kind}/${encodedProduct}/tokens/${encodedToken}:acknowledge`;
  await providerJson(url, accessToken, { method: "POST", body: "{}" });
}

export async function persistVerification(
  service: SupabaseClient,
  userId: string,
  purchaseToken: string,
  clientRequestId: string,
  purchase: VerifiedPurchase,
) {
  const { data, error } = await service.rpc("record_google_play_purchase_verification", {
    p_user_id: userId,
    p_product_id: purchase.productId,
    p_base_plan_id: purchase.basePlanId,
    p_package_name: packageName,
    p_environment: purchase.environment,
    p_purchase_token: purchaseToken,
    p_client_request_id: clientRequestId,
    p_purchase_state: purchase.state,
    p_acknowledgement_state: purchase.acknowledgementState,
    p_provider_order_id: purchase.orderId,
    p_purchased_at: purchase.purchasedAt,
    p_expires_at: purchase.expiresAt,
    p_raw_payload: JSON.stringify(purchase.raw),
  });
  if (error) throw new PublicError("purchase_persistence_failed", 503);
  if (data?.ok !== true) throw new PublicError(String(data?.code ?? "purchase_rejected"), 400);
  return data;
}

export function constantTimeEqual(left: string, right: string) {
  const a = new TextEncoder().encode(left);
  const b = new TextEncoder().encode(right);
  let mismatch = a.length ^ b.length;
  for (let i = 0; i < Math.max(a.length, b.length); i += 1) mismatch |= (a[i] ?? 0) ^ (b[i] ?? 0);
  return mismatch === 0;
}
