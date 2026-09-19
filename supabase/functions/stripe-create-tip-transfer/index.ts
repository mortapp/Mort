import { assertUuid, authenticate, json, options, readJson, requireOperationsSecret, runtime, safeError } from "../_shared/stripe.ts";

Deno.serve(async (request: Request) => {
  const preflight = options(request);
  if (preflight) return preflight;
  if (request.method !== "POST") return json({ ok: false, code: "post_required" }, 405);
  try {
    requireOperationsSecret(request);
    const context = await authenticate(request);
    const payload = await readJson<{ tip_attempt_id?: unknown }>(request);
    const tipAttemptId = assertUuid(payload.tip_attempt_id, "tip_attempt_id");
    const stripeRuntime = await runtime(context);
    const { data: prepared, error: prepareError } = await context.serviceClient.rpc(
      "stripe_server_prepare_tip_transfer_v1",
      { p_tip_attempt_id: tipAttemptId, p_environment: stripeRuntime.environment },
    );
    if (prepareError) throw prepareError;
    if (prepared.existing && prepared.provider_transfer_id) return json({ ok: true, duplicate: true, status: prepared.status });
    const transfer = await stripeRuntime.stripe.transfers.create({
      amount: prepared.amount_cents,
      currency: String(prepared.currency_code).toLowerCase(),
      destination: prepared.provider_connected_account_id,
      transfer_group: `MORT_TIP_${tipAttemptId.replaceAll("-", "")}`,
      metadata: { mort_tip_attempt_ref: tipAttemptId, mort_environment: stripeRuntime.environment },
    }, { idempotencyKey: prepared.idempotency_key });
    const { data: recorded, error: recordError } = await context.serviceClient.rpc(
      "stripe_server_record_tip_transfer_v1",
      {
        p_tip_transfer_id: prepared.tip_transfer_id,
        p_provider_transfer_id: transfer.id,
        p_provider_status: "paid",
      },
    );
    if (recordError) throw recordError;
    return json({ ok: true, tip_transfer_id: recorded.tip_transfer_id, status: recorded.status });
  } catch (error) {
    return safeError(error);
  }
});
