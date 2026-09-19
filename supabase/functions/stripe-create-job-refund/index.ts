import { assertUuid, authenticate, json, options, readJson, requireOperationsSecret, runtime, safeError } from "../_shared/stripe.ts";

Deno.serve(async (request: Request) => {
  const preflight = options(request);
  if (preflight) return preflight;
  if (request.method !== "POST") return json({ ok: false, code: "post_required" }, 405);
  try {
    requireOperationsSecret(request);
    const context = await authenticate(request);
    const payload = await readJson<{ settlement_id?: unknown; reason_code?: unknown }>(request);
    const settlementId = assertUuid(payload.settlement_id, "settlement_id");
    const reason = typeof payload.reason_code === "string" ? payload.reason_code : "";
    const stripeRuntime = await runtime(context);
    const { data: prepared, error } = await context.serviceClient.rpc("stripe_server_prepare_settlement_refund_v1", {
      p_settlement_id: settlementId,
      p_environment: stripeRuntime.environment,
      p_reason_code: reason,
      p_requested_by: context.user.id,
    });
    if (error) throw error;
    if (prepared.existing && prepared.provider_refund_id) return json({ ok: true, duplicate: true, status: "already_recorded" });
    const refund = await stripeRuntime.stripe.refunds.create({
      payment_intent: prepared.provider_payment_intent_id,
      amount: prepared.amount_cents,
      metadata: { mort_settlement_ref: settlementId, mort_environment: stripeRuntime.environment },
    }, { idempotencyKey: prepared.idempotency_key });
    const { data: recorded, error: recordError } = await context.serviceClient.rpc("stripe_server_record_settlement_refund_v1", {
      p_refund_record_id: prepared.refund_record_id,
      p_provider_refund_id: refund.id,
      p_provider_status: refund.status ?? "pending",
    });
    if (recordError) throw recordError;
    return json({ ok: true, refund_record_id: recorded.refund_record_id, status: recorded.status, transfer_reversal_review_required: prepared.transfer_reversal_review_required });
  } catch (error) {
    return safeError(error);
  }
});
