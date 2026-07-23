import { assertUuid, authenticate, json, options, readJson, requireRateLimit, runtime, safeError } from "../_shared/stripe.ts";

type ResolutionRequest = {
  action?: unknown;
  dispute_id?: unknown;
  contract_id?: unknown;
  resolution_id?: unknown;
  request_id?: unknown;
};

Deno.serve(async (request: Request) => {
  const preflight = options(request);
  if (preflight) return preflight;
  if (request.method !== "POST") return json({ ok: false, code: "post_required" }, 405);
  try {
    const context = await authenticate(request);
    await requireRateLimit(context, "stripe_job_resolution", 20, 3600);
    const payload = await readJson<ResolutionRequest>(request);
    const action = typeof payload.action === "string" ? payload.action : "";
    const requestId = assertUuid(payload.request_id, "request_id");
    const stripeRuntime = await runtime(context);
    if (stripeRuntime.environment !== "test") {
      return json({ ok: false, code: "stripe_live_disabled" }, 403);
    }

    if (action === "prepare_dispute") {
      const disputeId = assertUuid(payload.dispute_id, "dispute_id");
      const { data, error } = await context.serviceClient.rpc(
        "stripe_server_prepare_dispute_resolution",
        {
          p_actor_id: context.user.id,
          p_dispute_id: disputeId,
          p_environment: stripeRuntime.environment,
          p_request_id: requestId,
        },
      );
      if (error) throw error;
      return json({ ok: true, ...data, provider_operation_performed: false });
    }

    if (action === "prepare_completion") {
      const contractId = assertUuid(payload.contract_id, "contract_id");
      const { data, error } = await context.serviceClient.rpc(
        "stripe_server_prepare_completion_resolution",
        {
          p_actor_id: context.user.id,
          p_contract_id: contractId,
          p_environment: stripeRuntime.environment,
          p_request_id: requestId,
        },
      );
      if (error) throw error;
      return json({ ok: true, ...data, provider_operation_performed: false });
    }

    if (action !== "execute") {
      return json({ ok: false, code: "invalid_resolution_action" }, 400);
    }

    const resolutionId = assertUuid(payload.resolution_id, "resolution_id");
    const { data: prepared, error: prepareError } = await context.serviceClient.rpc(
      "stripe_server_load_resolution_for_execution",
      {
        p_actor_id: context.user.id,
        p_resolution_id: resolutionId,
        p_environment: stripeRuntime.environment,
        p_request_id: requestId,
      },
    );
    if (prepareError) throw prepareError;
    if (prepared.replayed === true) return json({ ok: true, ...prepared });

    let transferId: string | null = null;
    let refundId: string | null = null;
    if (Number(prepared.transfer_amount_cents) > 0) {
      const transfer = await stripeRuntime.stripe.transfers.create(
        {
          amount: Number(prepared.transfer_amount_cents),
          currency: String(prepared.currency_code).toLowerCase(),
          destination: String(prepared.provider_connected_account_id),
          source_transaction: String(prepared.provider_source_charge_id),
          metadata: {
            mort_resolution_ref: resolutionId,
            mort_environment: stripeRuntime.environment,
          },
        },
        { idempotencyKey: String(prepared.transfer_idempotency_key) },
      );
      transferId = transfer.id;
    }
    if (Number(prepared.refund_amount_cents) > 0) {
      const refund = await stripeRuntime.stripe.refunds.create(
        {
          payment_intent: String(prepared.provider_payment_intent_id),
          amount: Number(prepared.refund_amount_cents),
          metadata: {
            mort_resolution_ref: resolutionId,
            mort_environment: stripeRuntime.environment,
          },
        },
        { idempotencyKey: String(prepared.refund_idempotency_key) },
      );
      refundId = refund.id;
    }
    const { data: recorded, error: recordError } = await context.serviceClient.rpc(
      "stripe_server_record_resolution_result",
      {
        p_resolution_id: resolutionId,
        p_environment: stripeRuntime.environment,
        p_provider_transfer_id: transferId,
        p_provider_refund_id: refundId,
        p_provider_status: "succeeded",
        p_safe_failure_code: null,
      },
    );
    if (recordError) throw recordError;
    return json({
      ok: true,
      resolution_id: resolutionId,
      status: recorded.status,
      provider_operation_performed: true,
    });
  } catch (error) {
    return safeError(error);
  }
});
