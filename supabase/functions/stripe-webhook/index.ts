import Stripe from "npm:stripe@22.1.1";
import { json, safeError, serviceClient, sha256, webhookRuntime } from "../_shared/stripe.ts";

const maximumWebhookBytes = 512 * 1024;

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") return json({ ok: false, code: "post_required" }, 405);
  let eventId: string | null = null;
  let environment: "test" | "live" | null = null;
  try {
    const runtime = webhookRuntime();
    environment = runtime.environment;
    const signature = request.headers.get("Stripe-Signature");
    if (!signature) return json({ ok: false, code: "stripe_signature_required" }, 401);
    const length = Number(request.headers.get("content-length") ?? "0");
    if (Number.isFinite(length) && length > maximumWebhookBytes) return json({ ok: false, code: "payload_too_large" }, 413);
    const rawBody = await request.text();
    if (new TextEncoder().encode(rawBody).byteLength > maximumWebhookBytes) return json({ ok: false, code: "payload_too_large" }, 413);

    const event = await runtime.stripe.webhooks.constructEventAsync(rawBody, signature, runtime.webhookSecret!);
    eventId = event.id;
    if (event.livemode !== (environment === "live")) return json({ ok: false, code: "stripe_environment_mismatch" }, 400);
    const supabase = serviceClient();
    const { data: claimed, error: claimError } = await supabase.rpc("stripe_server_claim_webhook_event", {
      p_environment: environment,
      p_provider_event_id: event.id,
      p_event_type: event.type,
      p_provider_created_at: new Date(event.created * 1000).toISOString(),
      p_payload_sha256: await sha256(rawBody),
    });
    if (claimError) throw claimError;
    if (claimed.claimed !== true) return json({ ok: true, duplicate: true });

    await processEvent(supabase, runtime.stripe, environment, event);
    return json({ ok: true, event_id: event.id });
  } catch (error) {
    if (eventId && environment) {
      try {
        await serviceClient().rpc("stripe_server_fail_webhook_event", {
          p_environment: environment,
          p_provider_event_id: eventId,
          p_safe_failure_code: "webhook_processing_failed",
        });
      } catch {
        // The provider retry remains the source of recovery if failure recording also fails.
      }
    }
    return safeError(error);
  }
});

async function processEvent(
  supabase: ReturnType<typeof serviceClient>,
  stripe: Stripe,
  environment: "test" | "live",
  event: Stripe.Event,
) {
  if (["payment_intent.succeeded", "payment_intent.processing", "payment_intent.payment_failed", "payment_intent.canceled"].includes(event.type)) {
    const intent = event.data.object as Stripe.PaymentIntent;
    const chargeId = typeof intent.latest_charge === "string" ? intent.latest_charge : intent.latest_charge?.id ?? null;
    const failureCode = intent.last_payment_error?.code ?? null;
    return rpc(supabase, "stripe_server_apply_payment_event", {
      p_environment: environment,
      p_provider_event_id: event.id,
      p_event_type: event.type,
      p_provider_payment_intent_id: intent.id,
      p_provider_charge_id: chargeId,
      p_amount_cents: intent.amount,
      p_currency_code: intent.currency.toUpperCase(),
      p_safe_failure_code: failureCode,
    });
  }

  if (event.type === "account.updated") {
    const account = event.data.object as Stripe.Account;
    const due = account.requirements?.currently_due ?? [];
    const pastDue = account.requirements?.past_due ?? [];
    const transfers = account.capabilities?.transfers ?? "inactive";
    const requirements = pastDue.length ? "past_due" : due.length ? "currently_due" : account.requirements?.pending_verification?.length ? "pending_verification" : "satisfied";
    const status = account.details_submitted && transfers === "active" ? "complete" : pastDue.length ? "action_required" : "in_progress";
    await rpc(supabase, "stripe_server_record_connected_account_status", {
      p_provider_account_id: account.id,
      p_environment: environment,
      p_onboarding_status: status,
      p_details_submitted: account.details_submitted,
      p_charges_enabled: account.charges_enabled,
      p_payouts_enabled: account.payouts_enabled,
      p_transfers_capability_status: transfers === "active" ? "active" : transfers === "pending" ? "pending" : transfers === "inactive" ? "inactive" : "restricted",
      p_requirements_status: requirements,
      p_guardian_requirement_status: due.some((item) => item.includes("guardian")) || pastDue.some((item) => item.includes("guardian")) ? "provider_managed_required" : "provider_managed_unknown",
      p_disabled_reason_code: account.requirements?.disabled_reason ?? null,
      p_country: account.country?.toUpperCase() ?? null,
      p_default_currency: account.default_currency?.toUpperCase() ?? null,
    });
    return complete(supabase, environment, event.id, "processed", "account_status_synchronized");
  }

  if (["charge.dispute.created", "charge.dispute.updated", "charge.dispute.closed"].includes(event.type)) {
    const dispute = event.data.object as Stripe.Dispute;
    const paymentIntentId = typeof dispute.payment_intent === "string" ? dispute.payment_intent : dispute.payment_intent?.id;
    if (!paymentIntentId) throw new Error("dispute payment intent unavailable");
    return rpc(supabase, "stripe_server_apply_dispute_event", {
      p_environment: environment,
      p_provider_event_id: event.id,
      p_provider_payment_intent_id: paymentIntentId,
      p_provider_dispute_id: dispute.id,
      p_amount_cents: dispute.amount,
      p_currency_code: dispute.currency.toUpperCase(),
      p_status: mapDisputeStatus(dispute.status),
      p_reason_code: dispute.reason,
      p_evidence_due_at: dispute.evidence_details?.due_by ? new Date(dispute.evidence_details.due_by * 1000).toISOString() : null,
    });
  }

  if (["transfer.created", "transfer.updated", "transfer.reversed"].includes(event.type)) {
    const transfer = event.data.object as Stripe.Transfer;
    return rpc(supabase, "stripe_server_apply_transfer_event", {
      p_environment: environment,
      p_provider_event_id: event.id,
      p_provider_transfer_id: transfer.id,
      p_status: event.type === "transfer.reversed" ? "reversed" : transfer.reversed ? "reversed" : "paid",
      p_failure_code: null,
    });
  }

  if (["payout.created", "payout.updated", "payout.paid", "payout.failed", "payout.canceled"].includes(event.type)) {
    const payout = event.data.object as Stripe.Payout;
    const accountId = typeof event.account === "string" ? event.account : null;
    if (!accountId) throw new Error("payout connected account unavailable");
    const destination = payout.destination;
    const destinationObject = typeof destination === "object" ? destination : null;
    return rpc(supabase, "stripe_server_apply_payout_event", {
      p_environment: environment,
      p_provider_event_id: event.id,
      p_provider_account_id: accountId,
      p_provider_payout_id: payout.id,
      p_amount_cents: payout.amount,
      p_currency_code: payout.currency.toUpperCase(),
      p_status: mapPayoutStatus(payout.status),
      p_destination_type: destinationObject?.object === "card" ? "debit_card" : destinationObject?.object === "bank_account" ? "bank_account" : "unknown",
      p_destination_last4: destinationObject?.last4 ?? null,
      p_arrival_at: payout.arrival_date ? new Date(payout.arrival_date * 1000).toISOString() : null,
      p_failure_code: payout.failure_code ?? null,
    });
  }

  if (["refund.created", "refund.updated", "refund.failed"].includes(event.type)) {
    const refund = event.data.object as Stripe.Refund;
    return applyRefund(supabase, stripe, environment, event.id, refund);
  }

  if (event.type === "charge.refunded") {
    const charge = event.data.object as Stripe.Charge;
    const refunds = charge.refunds?.data ?? [];
    if (!refunds.length) {
      return complete(supabase, environment, event.id, "ignored", "charge_refund_list_unavailable");
    }
    let result: unknown = null;
    for (const refund of refunds) {
      result = await applyRefund(supabase, stripe, environment, event.id, refund, charge.payment_intent);
    }
    return result;
  }

  return complete(supabase, environment, event.id, "ignored", "event_not_used_by_mort");
}

async function applyRefund(
  supabase: ReturnType<typeof serviceClient>,
  stripe: Stripe,
  environment: "test" | "live",
  eventId: string,
  refund: Stripe.Refund,
  fallbackPaymentIntent?: string | Stripe.PaymentIntent | null,
) {
  let paymentIntent = refund.payment_intent ?? fallbackPaymentIntent ?? null;
  if (!paymentIntent && refund.charge) {
    const chargeId = typeof refund.charge === "string" ? refund.charge : refund.charge.id;
    const charge = await stripe.charges.retrieve(chargeId);
    paymentIntent = charge.payment_intent;
  }
  const paymentIntentId = typeof paymentIntent === "string" ? paymentIntent : paymentIntent?.id;
  if (!paymentIntentId) throw new Error("refund payment intent unavailable");
  return rpc(supabase, "stripe_server_apply_refund_event", {
    p_environment: environment,
    p_provider_event_id: eventId,
    p_provider_payment_intent_id: paymentIntentId,
    p_provider_refund_id: refund.id,
    p_amount_cents: refund.amount,
    p_currency_code: refund.currency.toUpperCase(),
    p_status: mapRefundStatus(refund.status),
    p_failure_code: refund.failure_reason ?? null,
  });
}

async function complete(supabase: ReturnType<typeof serviceClient>, environment: string, eventId: string, status: string, code: string) {
  return rpc(supabase, "stripe_server_complete_webhook_event", {
    p_environment: environment,
    p_provider_event_id: eventId,
    p_processing_status: status,
    p_safe_result_code: code,
  });
}

async function rpc(client: ReturnType<typeof serviceClient>, name: string, parameters: Record<string, unknown>) {
  const { data, error } = await client.rpc(name, parameters);
  if (error) throw error;
  return data;
}

function mapDisputeStatus(status: Stripe.Dispute.Status) {
  switch (status) {
    case "warning_needs_response": return "warning_received";
    case "needs_response": return "needs_response";
    case "under_review": return "under_review";
    case "won": return "won";
    case "lost": return "lost";
    default: return "closed";
  }
}

function mapPayoutStatus(status: Stripe.Payout.Status) {
  switch (status) {
    case "in_transit": return "in_transit";
    case "paid": return "paid";
    case "failed": return "failed";
    case "canceled": return "canceled";
    default: return "pending";
  }
}

function mapRefundStatus(status: Stripe.Refund.Status | null) {
  switch (status) {
    case "succeeded": return "succeeded";
    case "failed": return "failed";
    case "canceled": return "canceled";
    default: return "pending";
  }
}
