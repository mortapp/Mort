import { assertUuid, authenticate, json, options, providerStatus, readJson, requireRateLimit, runtime, safeError } from "../_shared/stripe.ts";

type PaymentRequest = {
  contract_id?: unknown;
  operation_version?: unknown;
  request_id?: unknown;
  save_payment_method?: unknown;
  saved_payment_consent_version?: unknown;
};

Deno.serve(async (request: Request) => {
  const preflight = options(request);
  if (preflight) return preflight;
  if (request.method !== "POST") return json({ ok: false, code: "post_required" }, 405);
  try {
    const context = await authenticate(request);
    await requireRateLimit(context, "stripe_job_payment_intent");
    const payload = await readJson<PaymentRequest>(request);
    const contractId = assertUuid(payload.contract_id, "contract_id");
    const requestId = assertUuid(payload.request_id, "request_id");
    const operationVersion = Number.isInteger(payload.operation_version) ? Number(payload.operation_version) : 1;
    const savePaymentMethod = payload.save_payment_method === true;
    const consentVersion = typeof payload.saved_payment_consent_version === "string"
      ? payload.saved_payment_consent_version
      : "";
    const stripeRuntime = await runtime(context);
    if (savePaymentMethod) {
      if (!/^saved-payment-consent-v[0-9]+$/.test(consentVersion)) {
        return json({ ok: false, code: "explicit_saved_payment_consent_required" }, 400);
      }
      const { error: consentError } = await context.serviceClient.rpc(
        "stripe_server_validate_saved_payment_consent",
        {
          p_adult_id: context.user.id,
          p_contract_id: contractId,
          p_consent_version: consentVersion,
        },
      );
      if (consentError) throw consentError;
    }
    const { data: prepared, error: prepareError } = await context.serviceClient.rpc("stripe_server_prepare_job_payment", {
      p_adult_id: context.user.id,
      p_contract_id: contractId,
      p_environment: stripeRuntime.environment,
      p_operation_version: operationVersion,
    });
    if (prepareError) throw prepareError;

    let customerId = prepared.provider_customer_id as string | null;
    if (!customerId) {
      const customer = await stripeRuntime.stripe.customers.create({
        email: context.user.email,
        metadata: { mort_user_ref: context.user.id, mort_environment: stripeRuntime.environment },
      }, { idempotencyKey: `${stripeRuntime.environment}:customer:${context.user.id}` });
      customerId = customer.id;
      const { error } = await context.serviceClient.rpc("stripe_server_record_customer", {
        p_user_id: context.user.id,
        p_environment: stripeRuntime.environment,
        p_provider_customer_id: customerId,
      });
      if (error) throw error;
    }

    let paymentIntent;
    if (prepared.existing && prepared.provider_payment_intent_id) {
      paymentIntent = await stripeRuntime.stripe.paymentIntents.retrieve(prepared.provider_payment_intent_id);
    } else {
      paymentIntent = await stripeRuntime.stripe.paymentIntents.create({
        amount: prepared.total_amount_cents,
        currency: String(prepared.currency_code).toLowerCase(),
        customer: customerId,
        automatic_payment_methods: { enabled: true },
        setup_future_usage: savePaymentMethod ? "off_session" : undefined,
        transfer_group: prepared.transfer_group,
        metadata: {
          mort_contract_ref: prepared.contract_id,
          mort_contract_version_ref: prepared.contract_version_id,
          mort_payment_record_ref: prepared.record_id ?? "pending",
          mort_environment: stripeRuntime.environment,
        },
      }, { idempotencyKey: prepared.idempotency_key });
    }
    if (!paymentIntent.client_secret) throw new Error("payment intent client secret unavailable");

    const ephemeralKey = await stripeRuntime.stripe.ephemeralKeys.create(
      { customer: customerId },
      { apiVersion: "2026-03-25.dahlia" },
    );
    const { data: recorded, error: recordError } = await context.serviceClient.rpc("stripe_server_record_payment_intent", {
      p_adult_id: context.user.id,
      p_contract_id: contractId,
      p_environment: stripeRuntime.environment,
      p_operation_version: operationVersion,
      p_provider_customer_id: customerId,
      p_provider_payment_intent_id: paymentIntent.id,
      p_provider_status: providerStatus(paymentIntent.status),
      p_request_id: requestId,
    });
    if (recordError) throw recordError;
    return json({
      ok: true,
      payment_record_id: recorded.payment_record_id,
      environment: stripeRuntime.environment,
      publishable_key: stripeRuntime.publishableKey,
      payment_intent_client_secret: paymentIntent.client_secret,
      customer_id: customerId,
      customer_ephemeral_key_secret: ephemeralKey.secret,
      earnings_amount_cents: prepared.earnings_amount_cents,
      service_fee_cents: prepared.service_fee_cents,
      total_amount_cents: prepared.total_amount_cents,
      currency_code: prepared.currency_code,
      save_payment_method_requested: savePaymentMethod,
      saved_payment_consent_version: savePaymentMethod ? consentVersion : null,
    });
  } catch (error) {
    return safeError(error);
  }
});
