import { assertUuid, authenticate, json, options, readJson, requireRateLimit, runtime, safeError } from "../_shared/stripe.ts";

type TipRequest = {
  settlement_id?: unknown;
  amount_cents?: unknown;
  request_id?: unknown;
};

Deno.serve(async (request: Request) => {
  const preflight = options(request);
  if (preflight) return preflight;
  if (request.method !== "POST") return json({ ok: false, code: "post_required" }, 405);
  try {
    const context = await authenticate(request);
    await requireRateLimit(context, "stripe_tip_payment_intent");
    const payload = await readJson<TipRequest>(request);
    const settlementId = assertUuid(payload.settlement_id, "settlement_id");
    const requestId = assertUuid(payload.request_id, "request_id");
    const amount = Number(payload.amount_cents);
    if (!Number.isSafeInteger(amount) || amount <= 0) {
      return json({ ok: false, code: "invalid_tip_amount" }, 400);
    }

    const stripeRuntime = await runtime(context);
    const { data: prepared, error: prepareError } = await context.serviceClient.rpc(
      "stripe_server_prepare_tip_v1",
      {
        p_settlement_id: settlementId,
        p_amount_cents: amount,
        p_request_id: requestId,
        p_payer_id: context.user.id,
      },
    );
    if (prepareError) throw prepareError;
    if (prepared.idempotent && prepared.provider_payment_intent_id) {
      return json(prepared);
    }

    const customer = await stripeRuntime.stripe.customers.create({
      email: context.user.email,
      metadata: { mort_user_ref: context.user.id, mort_environment: stripeRuntime.environment },
    }, { idempotencyKey: `${stripeRuntime.environment}:customer:${context.user.id}` });
    const { error: customerError } = await context.serviceClient.rpc("stripe_server_record_customer", {
      p_user_id: context.user.id,
      p_environment: stripeRuntime.environment,
      p_provider_customer_id: customer.id,
    });
    if (customerError) throw customerError;

    const paymentIntent = await stripeRuntime.stripe.paymentIntents.create({
      amount: prepared.amount_cents,
      currency: String(prepared.currency_code).toLowerCase(),
      customer: customer.id,
      automatic_payment_methods: { enabled: true },
      metadata: {
        mort_tip_attempt_ref: prepared.tip_attempt_id,
        mort_environment: stripeRuntime.environment,
      },
    }, { idempotencyKey: prepared.idempotency_key });
    if (!paymentIntent.client_secret) throw new Error("tip_payment_intent_client_secret_unavailable");

    const { data: recorded, error: recordError } = await context.serviceClient.rpc(
      "stripe_server_record_tip_payment_v1",
      {
        p_tip_attempt_id: prepared.tip_attempt_id,
        p_provider_customer_id: customer.id,
        p_provider_payment_intent_id: paymentIntent.id,
        p_provider_status: paymentIntent.status,
      },
    );
    if (recordError) throw recordError;
    return json({
      ok: true,
      tip_attempt_id: recorded.tip_attempt_id,
      provider_payment_intent_id: recorded.provider_payment_intent_id,
      normalized_state: recorded.normalized_state,
      environment: stripeRuntime.environment,
      publishable_key: stripeRuntime.publishableKey,
      payment_intent_client_secret: paymentIntent.client_secret,
      customer_id: customer.id,
      amount_cents: prepared.amount_cents,
      teen_amount_cents: prepared.teen_amount_cents,
      mort_fee_cents: prepared.mort_fee_cents,
      currency_code: prepared.currency_code,
    });
  } catch (error) {
    return safeError(error);
  }
});
