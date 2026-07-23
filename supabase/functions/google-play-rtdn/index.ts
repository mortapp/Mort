import {
  constantTimeEqual,
  persistVerification,
  PublicError,
  safeError,
  serviceClient,
  sha256,
  verifyWithGoogle,
} from "../_shared/google_play.ts";

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") return Response.json({ ok: false, code: "post_required" }, { status: 405 });
  try {
    const expectedSecret = Deno.env.get("MORT_GOOGLE_PLAY_RTDN_SECRET");
    const suppliedSecret = request.headers.get("x-mort-rtdn-secret");
    if (!expectedSecret || !suppliedSecret || !constantTimeEqual(expectedSecret, suppliedSecret)) {
      throw new PublicError("rtdn_authorization_required", 401);
    }
    const envelope = await request.json().catch(() => ({}));
    const encoded = envelope?.message?.data;
    if (typeof encoded !== "string" || encoded.length > 16384) throw new PublicError("invalid_rtdn_message", 400);
    let notification: Record<string, unknown>;
    try {
      notification = JSON.parse(atob(encoded));
    } catch {
      throw new PublicError("invalid_rtdn_message", 400);
    }
    if (notification.packageName !== "com.mortapp.mobile") throw new PublicError("wrong_package", 400);
    const subscription = notification.subscriptionNotification as Record<string, unknown> | undefined;
    const oneTime = notification.oneTimeProductNotification as Record<string, unknown> | undefined;
    const purchaseToken = String(subscription?.purchaseToken ?? oneTime?.purchaseToken ?? "");
    if (purchaseToken.length < 20) throw new PublicError("invalid_purchase_token", 400);
    const tokenHash = await sha256(purchaseToken);
    const service = serviceClient();
    const { data: record, error: recordError } = await service
      .from("purchase_records")
      .select("user_id,product_id")
      .eq("token_hash", tokenHash)
      .maybeSingle();
    if (recordError || !record) throw new PublicError("unknown_purchase_token", 404);
    const providerEventHash = await sha256(JSON.stringify(notification));
    const { data: duplicate } = await service
      .from("billing_notification_events")
      .select("id")
      .eq("provider_event_hash", providerEventHash)
      .maybeSingle();
    if (duplicate) return Response.json({ ok: true, replayed: true });

    const purchase = await verifyWithGoogle(record.product_id, purchaseToken);
    const environment = purchase.environment;
    await service.from("billing_notification_events").insert({
      provider_event_hash: providerEventHash,
      environment,
      notification_type: subscription ? "subscription" : "one_time",
      token_hash: tokenHash,
      package_name: "com.mortapp.mobile",
      processing_status: "received",
    });
    await persistVerification(service, record.user_id, purchaseToken, crypto.randomUUID(), purchase);
    await service.from("billing_notification_events").update({
      processing_status: "processed",
      processed_at: new Date().toISOString(),
    }).eq("provider_event_hash", providerEventHash);
    return Response.json({ ok: true });
  } catch (error) {
    return safeError(error);
  }
});
