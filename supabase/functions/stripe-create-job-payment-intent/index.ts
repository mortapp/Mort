import { assertUuid, authenticate, json, options, readJson, requireRateLimit, runtime, safeError } from "../_shared/stripe.ts";

type PaymentRequest = {
  quote_id?: unknown;
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
    const quoteId = assertUuid(payload.quote_id, "quote_id");
    const requestId = assertUuid(payload.request_id, "request_id");
    const savePaymentMethod = payload.save_payment_method === true;
    const consentVersion = typeof payload.saved_payment_consent_version === "string"
      ? payload.saved_payment_consent_version
      : "";

    const { data: quote, error: quoteError } = await context.userClient.rpc("get_my_job_funding_quote_v1", {
      p_quote_id: quoteId,
    });
    if (quoteError) throw quoteError;
    if (savePaymentMethod) {
      if (!/^saved-payment-consent-v[0-9]+$/.test(consentVersion)) {
        return json({ ok: false, code: "explicit_saved_payment_consent_required" }, 400);
      }
      const { error: consentError } = await context.serviceClient.rpc(
        "stripe_server_validate_saved_payment_consent",
        {
          p_adult_id: context.user.id,
          p_contract_id: quote.contract_id,
          p_consent_version: consentVersion,
        },
      );
      if (consentError) throw consentError;
    }

    const { data: consumed, error: consumeError } = await context.serviceClient.rpc(
      "stripe_server_consume_job_funding_quote_v1",
      {
        p_payer_id: context.user.id,
        p_quote_id: quoteId,
        p_attempt_request_id: requestId,
      },
    );
    if (consumeError) throw consumeError;
    if (consumed?.ok === false) return json(consumed, 409);

    const stripeRuntime = await runtime(context);
    const { data: prepared, error: prepareError } = await context.serviceClient.rpc(
      "stripe_server_prepare_quote_payment_v1",
      {
        p_quote_id: quoteId,
        p_request_id: requestId,
      },
    );
    if (prepareError) throw prepareError;
    if (
      prepared.total_amount_cents !== consumed.authoritative_total_cents ||
      prepared.earnings_amount_cents !== consumed.base_pay_cents ||
      prepared.service_fee_cents !== consumed.service_fee_cents ||
      prepared.currency_code !== consumed.currency_code
    ) {
      return json({ ok: false, code: "funding_quote_obsolete" }, 409);
    }

    const { data: preparedAttempt, error: attemptError } = await context.serviceClient.rpc(
      "stripe_server_prepare_payment_intent_v2",
      {
        p_quote_id: quoteId,
        p_request_id: requestId,
      },
    );
    if (attemptError) throw attemptError;

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

    const paymentIntent = prepared.provider_payment_intent_id
      ? await stripeRuntime.stripe.paymentIntents.retrieve(
          prepared.provider_payment_intent_id,
        )
      : await stripeRuntime.stripe.paymentIntents.create({
          amount: consumed.authoritative_total_cents,
          currency: String(consumed.currency_code).toLowerCase(),
          customer: customerId,
          automatic_payment_methods: { enabled: true },
          setup_future_usage: savePaymentMethod ? "off_session" : undefined,
          transfer_group: prepared.transfer_group,
          metadata: {
            mort_quote_ref: quoteId,
            mort_contract_ref: consumed.contract_id,
            mort_environment: stripeRuntime.environment,
          },
        }, { idempotencyKey: preparedAttempt.idempotency_key });
    if (!paymentIntent.client_secret) throw new Error("payment_intent_client_secret_unavailable");

    const ephemeralKey = await stripeRuntime.stripe.ephemeralKeys.create(
      { customer: customerId },
      { apiVersion: "2026-03-25.dahlia" },
    );
    const { data: recorded, error: recordError } = await context.serviceClient.rpc(
      "stripe_server_record_payment_intent_v2",
      {
        p_quote_id: quoteId,
        p_request_id: requestId,
        p_provider_customer_id: customerId,
        p_provider_payment_intent_id: paymentIntent.id,
        p_provider_status: paymentIntent.status,
        p_provider_created_at: new Date(paymentIntent.created * 1000).toISOString(),
      },
    );
    if (recordError) throw recordError;
    return json({
      ok: true,
      payment_intent_id: recorded.payment_intent_id,
      payment_attempt_id: preparedAttempt.attempt_id,
      environment: stripeRuntime.environment,
      publishable_key: stripeRuntime.publishableKey,
      payment_intent_client_secret: paymentIntent.client_secret,
      customer_id: customerId,
      customer_ephemeral_key_secret: ephemeralKey.secret,
      base_pay_cents: consumed.base_pay_cents,
      service_fee_cents: consumed.service_fee_cents,
      total_amount_cents: consumed.authoritative_total_cents,
      currency_code: consumed.currency_code,
      save_payment_method_requested: savePaymentMethod,
      saved_payment_consent_version: savePaymentMethod ? consentVersion : null,
    });
  } catch (error) {
    return safeError(error);
  }
});
