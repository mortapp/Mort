import { assertUuid, authenticate, json, options, readJson, requireOperationsSecret, runtime, safeError } from "../_shared/stripe.ts";

Deno.serve(async (request: Request) => {
  const preflight = options(request);
  if (preflight) return preflight;
  if (request.method !== "POST") return json({ ok: false, code: "post_required" }, 405);
  try {
    requireOperationsSecret(request);
    const context = await authenticate(request);
    const payload = await readJson<{ contract_id?: unknown; eligibility_path?: unknown }>(request);
    const contractId = assertUuid(payload.contract_id, "contract_id");
    const eligibilityPath = typeof payload.eligibility_path === "string" ? payload.eligibility_path : "";
    const stripeRuntime = await runtime(context);
    const { data: prepared, error } = await context.serviceClient.rpc("stripe_server_prepare_transfer", {
      p_contract_id: contractId,
      p_environment: stripeRuntime.environment,
      p_eligibility_path: eligibilityPath,
    });
    if (error) throw error;
    if (prepared.existing && prepared.provider_transfer_id) return json({ ok: true, duplicate: true, status: "already_recorded" });
    const transfer = await stripeRuntime.stripe.transfers.create({
      amount: prepared.amount_cents,
      currency: String(prepared.currency_code).toLowerCase(),
      destination: prepared.provider_connected_account_id,
      source_transaction: prepared.provider_source_charge_id,
      transfer_group: prepared.transfer_group,
      metadata: { mort_payment_ref: prepared.payment_record_id, mort_environment: stripeRuntime.environment },
    }, { idempotencyKey: prepared.idempotency_key });
    const { data: recorded, error: recordError } = await context.serviceClient.rpc("stripe_server_record_transfer", {
      p_contract_id: contractId,
      p_environment: stripeRuntime.environment,
      p_eligibility_path: eligibilityPath,
      p_provider_transfer_id: transfer.id,
      p_provider_status: "paid",
    });
    if (recordError) throw recordError;
    return json({ ok: true, transfer_record_id: recorded.transfer_record_id, status: recorded.status });
  } catch (error) {
    return safeError(error);
  }
});
