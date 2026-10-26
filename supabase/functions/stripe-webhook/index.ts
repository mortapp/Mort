import Stripe from "npm:stripe@22.1.1";
import {
  json,
  safeError,
  serviceClient,
  sha256,
  webhookRuntime,
} from "../_shared/stripe.ts";
import { assertWebhookEventRoute, verifyWebhookEvent } from "./verification.ts";

const maximumWebhookBytes = 512 * 1024;

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") {
    return json({ ok: false, code: "post_required" }, 405);
  }
  let eventId: string | null = null;
  let environment: "test" | "live" | null = null;
  let leaseToken: string | null = null;
  try {
    const runtime = webhookRuntime();
    environment = runtime.environment;
    const signature = request.headers.get("Stripe-Signature");
    if (!signature) {
      return json({ ok: false, code: "stripe_signature_required" }, 401);
    }
    const length = Number(request.headers.get("content-length") ?? "0");
    if (Number.isFinite(length) && length > maximumWebhookBytes) {
      return json({ ok: false, code: "payload_too_large" }, 413);
    }
    const rawBody = await request.text();
    if (new TextEncoder().encode(rawBody).byteLength > maximumWebhookBytes) {
      return json({ ok: false, code: "payload_too_large" }, 413);
    }

    const verified = await verifyWebhookEvent(
      runtime.stripe,
      rawBody,
      signature,
      {
        platform: runtime.webhookSecret,
        connect: runtime.connectWebhookSecret,
      },
    );
    const event = verified.event;
    assertWebhookEventRoute(event, verified.source);
    eventId = event.id;
    if (event.livemode !== (environment === "live")) {
      return json({ ok: false, code: "stripe_environment_mismatch" }, 400);
    }
    const supabase = serviceClient();
    const { data: claimed, error: claimError } = await supabase.rpc(
      "stripe_server_claim_webhook_event",
      {
        p_environment: environment,
        p_provider_event_id: event.id,
        p_event_type: event.type,
        p_provider_created_at: new Date(event.created * 1000).toISOString(),
        p_payload_sha256: await sha256(rawBody),
      },
    );
    if (claimError) throw claimError;
    if (claimed.claimed !== true) {
      if (claimed.in_flight === true) {
        return json({ ok: false, code: "webhook_event_in_flight" }, 503);
      }
      return json({
        ok: true,
        duplicate: claimed.duplicate === true,
        in_flight: claimed.in_flight === true,
      });
    }
    if (typeof claimed.lease_token !== "string") {
      throw new Error("webhook_lease_token_missing");
    }
    leaseToken = claimed.lease_token;
    const payload = await normalizeEvent(runtime.stripe, event);
    const { error: applyError } = await supabase.rpc(
      "stripe_server_apply_webhook_event",
      {
        p_environment: environment,
        p_provider_event_id: event.id,
        p_lease_token: leaseToken,
        p_event_type: event.type,
        p_payload: payload,
      },
    );
    if (applyError) throw applyError;
    return json({ ok: true, event_id: event.id });
  } catch (error) {
    if (eventId && environment && leaseToken) {
      try {
        await serviceClient().rpc("stripe_server_fail_webhook_event_fenced", {
          p_environment: environment,
          p_provider_event_id: eventId,
          p_lease_token: leaseToken,
          p_safe_failure_code: "webhook_processing_failed",
        });
      } catch {
        // The provider retry remains the source of recovery if failure recording also fails.
      }
    }
    return safeError(error);
  }
});

async function normalizeEvent(
  stripe: Stripe,
  event: Stripe.Event,
): Promise<Record<string, unknown>> {
  if (
    [
      "payment_intent.succeeded",
      "payment_intent.processing",
      "payment_intent.requires_action",
      "payment_intent.payment_failed",
      "payment_intent.canceled",
    ].includes(event.type)
  ) {
    const intent = event.data.object as Stripe.PaymentIntent;
    const chargeId = typeof intent.latest_charge === "string"
      ? intent.latest_charge
      : intent.latest_charge?.id ?? null;
    const failureCode = intent.last_payment_error?.code ?? null;
    return {
      provider_payment_intent_id: intent.id,
      provider_charge_id: chargeId,
      amount_cents: intent.amount,
      currency_code: intent.currency.toUpperCase(),
      safe_failure_code: failureCode,
    };
  }

  if (event.type === "account.updated") {
    const account = event.data.object as Stripe.Account;
    const due = account.requirements?.currently_due ?? [];
    const pastDue = account.requirements?.past_due ?? [];
    const transfers = account.capabilities?.transfers ?? "inactive";
    const requirements = pastDue.length
      ? "past_due"
      : due.length
      ? "currently_due"
      : account.requirements?.pending_verification?.length
      ? "pending_verification"
      : "satisfied";
    const status = account.details_submitted && transfers === "active"
      ? "complete"
      : pastDue.length
      ? "action_required"
      : "in_progress";
    return {
      provider_account_id: account.id,
      onboarding_status: status,
      details_submitted: account.details_submitted,
      charges_enabled: account.charges_enabled,
      payouts_enabled: account.payouts_enabled,
      transfers_capability_status: transfers === "active"
        ? "active"
        : transfers === "pending"
        ? "pending"
        : transfers === "inactive"
        ? "inactive"
        : "restricted",
      requirements_status: requirements,
      guardian_requirement_status: due.some((item) =>
          item.includes("guardian")
        ) || pastDue.some((item) => item.includes("guardian"))
        ? "provider_managed_required"
        : "provider_managed_unknown",
      disabled_reason_code: account.requirements?.disabled_reason ?? null,
      country: account.country?.toUpperCase() ?? null,
      default_currency: account.default_currency?.toUpperCase() ?? null,
    };
  }

  if (
    [
      "charge.dispute.created",
      "charge.dispute.updated",
      "charge.dispute.closed",
    ].includes(event.type)
  ) {
    const dispute = event.data.object as Stripe.Dispute;
    const paymentIntentId = typeof dispute.payment_intent === "string"
      ? dispute.payment_intent
      : dispute.payment_intent?.id;
    if (!paymentIntentId) throw new Error("dispute payment intent unavailable");
    return {
      provider_payment_intent_id: paymentIntentId,
      provider_dispute_id: dispute.id,
      amount_cents: dispute.amount,
      currency_code: dispute.currency.toUpperCase(),
      status: mapDisputeStatus(dispute.status),
      reason_code: dispute.reason,
      evidence_due_at: dispute.evidence_details?.due_by
        ? new Date(dispute.evidence_details.due_by * 1000).toISOString()
        : null,
    };
  }

  if (
    ["transfer.created", "transfer.updated", "transfer.reversed"].includes(
      event.type,
    )
  ) {
    const transfer = event.data.object as Stripe.Transfer;
    return {
      provider_transfer_id: transfer.id,
      status: event.type === "transfer.reversed"
        ? "reversed"
        : transfer.reversed
        ? "reversed"
        : "paid",
      failure_code: null,
    };
  }

  if (
    [
      "payout.created",
      "payout.updated",
      "payout.paid",
      "payout.failed",
      "payout.canceled",
    ].includes(event.type)
  ) {
    const payout = event.data.object as Stripe.Payout;
    const accountId = typeof event.account === "string" ? event.account : null;
    if (!accountId) throw new Error("payout connected account unavailable");
    const destination = payout.destination;
    const destinationObject = typeof destination === "object"
      ? destination
      : null;
    return {
      provider_account_id: accountId,
      provider_payout_id: payout.id,
      amount_cents: payout.amount,
      currency_code: payout.currency.toUpperCase(),
      status: mapPayoutStatus(payout.status),
      destination_type: destinationObject?.object === "card"
        ? "debit_card"
        : destinationObject?.object === "bank_account"
        ? "bank_account"
        : "unknown",
      destination_last4: destinationObject && "last4" in destinationObject
        ? destinationObject.last4
        : null,
      arrival_at: payout.arrival_date
        ? new Date(payout.arrival_date * 1000).toISOString()
        : null,
      failure_code: payout.failure_code ?? null,
    };
  }

  if (
    ["refund.created", "refund.updated", "refund.failed"].includes(event.type)
  ) {
    const refund = event.data.object as Stripe.Refund;
    return { ...await normalizeRefund(stripe, refund) };
  }

  if (event.type === "charge.refunded") {
    const charge = event.data.object as Stripe.Charge;
    const refunds = charge.refunds?.data ?? [];
    if (!refunds.length) {
      return { refunds: [] };
    }
    const normalized: Record<string, unknown>[] = [];
    for (const refund of refunds) {
      normalized.push(
        await normalizeRefund(stripe, refund, charge.payment_intent),
      );
    }
    return { refunds: normalized };
  }

  return {};
}

async function normalizeRefund(
  stripe: Stripe,
  refund: Stripe.Refund,
  fallbackPaymentIntent?: string | Stripe.PaymentIntent | null,
): Promise<Record<string, unknown>> {
  let paymentIntent = refund.payment_intent ?? fallbackPaymentIntent ?? null;
  if (!paymentIntent && refund.charge) {
    const chargeId = typeof refund.charge === "string"
      ? refund.charge
      : refund.charge.id;
    const charge = await stripe.charges.retrieve(chargeId);
    paymentIntent = charge.payment_intent;
  }
  const paymentIntentId = typeof paymentIntent === "string"
    ? paymentIntent
    : paymentIntent?.id;
  if (!paymentIntentId) throw new Error("refund payment intent unavailable");
  return {
    provider_payment_intent_id: paymentIntentId,
    provider_refund_id: refund.id,
    amount_cents: refund.amount,
    currency_code: refund.currency.toUpperCase(),
    status: mapRefundStatus(refund.status),
    failure_code: refund.failure_reason ?? null,
  };
}

function mapDisputeStatus(status: Stripe.Dispute.Status) {
  switch (status) {
    case "warning_needs_response":
      return "warning_received";
    case "needs_response":
      return "needs_response";
    case "under_review":
      return "under_review";
    case "won":
      return "won";
    case "lost":
      return "lost";
    default:
      return "closed";
  }
}

function mapPayoutStatus(status: string) {
  switch (status) {
    case "in_transit":
      return "in_transit";
    case "paid":
      return "paid";
    case "failed":
      return "failed";
    case "canceled":
      return "canceled";
    default:
      return "pending";
  }
}

function mapRefundStatus(status: string | null) {
  switch (status) {
    case "succeeded":
      return "succeeded";
    case "failed":
      return "failed";
    case "canceled":
      return "canceled";
    default:
      return "pending";
  }
}
