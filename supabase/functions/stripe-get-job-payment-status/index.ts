import Stripe from "npm:stripe@22.1.1";
import {
  authenticate,
  options,
  PublicError,
  requireRateLimit,
  runtime,
  type StripeContext,
} from "../_shared/stripe.ts";
import {
  createPaymentStatusHandler,
  PaymentStatusHttpError,
  type PaymentStatusContext,
} from "./handler.ts";

function asStripeContext(context: PaymentStatusContext) {
  return context.rawContext as StripeContext;
}

function eventTypeFor(intent: Stripe.PaymentIntent) {
  switch (intent.status) {
    case "succeeded":
      return "payment_intent.succeeded";
    case "processing":
      return "payment_intent.processing";
    case "requires_action":
      return "payment_intent.requires_action";
    case "canceled":
      return "payment_intent.canceled";
    case "requires_payment_method":
      return intent.last_payment_error ? "payment_intent.payment_failed" : null;
    default:
      return null;
  }
}

const handler = createPaymentStatusHandler({
  authenticate: async (request) => {
    try {
      const context = await authenticate(request);
      return { userId: context.user.id, rawContext: context };
    } catch (error) {
      if (error instanceof PublicError && error.status === 401) return null;
      if (error instanceof PublicError) {
        throw new PaymentStatusHttpError(error.code, error.status);
      }
      throw error;
    }
  },
  enforceRateLimit: async (context) => {
    try {
      await requireRateLimit(
        asStripeContext(context),
        "stripe_job_payment_status",
      );
    } catch (error) {
      if (error instanceof PublicError) {
        throw new PaymentStatusHttpError(error.code, error.status);
      }
      throw error;
    }
  },
  loadAuthorizedState: async (context, providerPaymentIntentId) => {
    const { data, error } = await asStripeContext(context).userClient.rpc(
      "get_my_payment_attempt_state_v1",
      { p_payment_intent_id: providerPaymentIntentId },
    );
    if (error) {
      throw new PaymentStatusHttpError("payment_status_unavailable", 503);
    }
    if (!data || typeof data !== "object" || Array.isArray(data)) return null;
    return data as Record<string, unknown>;
  },
  reconcile: async (context, providerPaymentIntentId) => {
    const stripeContext = asStripeContext(context);
    let stripeRuntime;
    try {
      stripeRuntime = await runtime(stripeContext);
    } catch (error) {
      if (error instanceof PublicError) {
        throw new PaymentStatusHttpError(error.code, error.status);
      }
      throw error;
    }

    let intent: Stripe.PaymentIntent;
    try {
      intent = await stripeRuntime.stripe.paymentIntents.retrieve(
        providerPaymentIntentId,
      );
    } catch (error) {
      if (
        error instanceof Stripe.errors.StripeError &&
        error.code === "resource_missing"
      ) {
        throw new PaymentStatusHttpError("payment_status_not_found", 404);
      }
      throw new PaymentStatusHttpError("provider_status_unavailable", 503);
    }

    if (intent.livemode !== (stripeRuntime.environment === "live")) {
      throw new PaymentStatusHttpError("stripe_environment_mismatch", 409);
    }
    if (
      intent.metadata?.mort_environment &&
      intent.metadata.mort_environment !== stripeRuntime.environment
    ) {
      throw new PaymentStatusHttpError("stripe_environment_mismatch", 409);
    }

    const eventType = eventTypeFor(intent);
    if (!eventType) return;

    const chargeId = typeof intent.latest_charge === "string"
      ? intent.latest_charge
      : intent.latest_charge?.id ?? null;
    const { error } = await stripeContext.serviceClient.rpc(
      "stripe_server_apply_payment_event_v2",
      {
        p_environment: stripeRuntime.environment,
        p_provider_event_id: "reconcile:" + crypto.randomUUID(),
        p_event_type: eventType,
        p_provider_payment_intent_id: intent.id,
        p_provider_charge_id: chargeId,
        p_amount_cents: intent.amount,
        p_currency_code: intent.currency.toUpperCase(),
        p_safe_failure_code: intent.last_payment_error?.code ?? null,
      },
    );
    if (error) {
      const message = error.message ?? "";
      if (
        message.includes("amount_mismatch") ||
        message.includes("currency_mismatch")
      ) {
        throw new PaymentStatusHttpError(
          "provider_payment_facts_mismatch",
          409,
        );
      }
      throw new PaymentStatusHttpError("payment_reconciliation_failed", 503);
    }
  },
});

Deno.serve(async (request: Request) => {
  const preflight = options(request);
  if (preflight) return preflight;
  return handler(request);
});
