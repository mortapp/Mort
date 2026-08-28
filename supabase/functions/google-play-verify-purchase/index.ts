import {
  acknowledgeWithGoogle,
  allowedProductIds,
  assertUuid,
  authenticate,
  json,
  options,
  persistVerification,
  PublicError,
  safeError,
  sha256,
  verifyWithGoogle,
} from "../_shared/google_play.ts";

Deno.serve(async (request: Request) => {
  const preflight = options(request);
  if (preflight) return preflight;
  if (request.method !== "POST") return json({ ok: false, code: "post_required" }, 405);
  try {
    const context = await authenticate(request);
    const body = await request.json().catch(() => ({}));
    const productId = typeof body.product_id === "string" ? body.product_id : "";
    const purchaseToken = typeof body.purchase_token === "string" ? body.purchase_token : "";
    const clientRequestId = assertUuid(body.client_request_id, "client_request_id");
    if (!allowedProductIds.has(productId)) throw new PublicError("wrong_product", 400);

    const { data: config, error: configError } = await context.userClient.rpc("get_play_billing_config");
    if (configError || config?.ok !== true) throw new PublicError("billing_config_unavailable", 503);
    if (config.billing_enabled !== true || config.provider_verification_enabled !== true) {
      throw new PublicError("billing_provider_disabled", 503);
    }

    const purchase = await verifyWithGoogle(productId, purchaseToken);
    if (purchase.environment !== config.mode) throw new PublicError("wrong_environment", 400);
    const expectedAccount = await sha256(context.user.id);
    if (!purchase.obfuscatedAccountId || purchase.obfuscatedAccountId !== expectedAccount) {
      throw new PublicError("wrong_user", 403);
    }
    if (purchase.state === "purchased" && purchase.acknowledgementState === "pending") {
      await acknowledgeWithGoogle(productId, purchaseToken);
      purchase.acknowledgementState = "acknowledged";
    }
    const result = await persistVerification(
      context.serviceClient,
      context.user.id,
      purchaseToken,
      clientRequestId,
      purchase,
    );
    return json({
      ok: true,
      purchase_state: purchase.state,
      entitlement_status: result.entitlement_status,
      provider_verified: true,
    });
  } catch (error) {
    return safeError(error);
  }
});
