import Stripe from "npm:stripe@22.1.1";
import { PublicError } from "../_shared/stripe.ts";

export type WebhookSecrets = {
  platform: string | undefined;
  connect: string | undefined;
};

export type VerifiedWebhookEvent = {
  event: Stripe.Event;
  source: "platform" | "connect";
};

const platformEventTypes = new Set([
  "payment_intent.succeeded",
  "payment_intent.processing",
  "payment_intent.payment_failed",
  "payment_intent.canceled",
  "charge.dispute.created",
  "charge.dispute.updated",
  "charge.dispute.closed",
  "transfer.created",
  "transfer.updated",
  "transfer.reversed",
  "refund.created",
  "refund.updated",
  "refund.failed",
  "charge.refunded",
]);

const connectEventTypes = new Set([
  "account.updated",
  "payout.created",
  "payout.updated",
  "payout.paid",
  "payout.failed",
  "payout.canceled",
]);

export async function verifyWebhookEvent(
  stripe: Stripe,
  rawBody: string,
  signature: string,
  secrets: WebhookSecrets,
): Promise<VerifiedWebhookEvent> {
  let platformEvent: Stripe.Event | undefined;
  if (secrets.platform) {
    try {
      platformEvent = await stripe.webhooks.constructEventAsync(rawBody, signature, secrets.platform);
    } catch {
      platformEvent = undefined;
    }
  }

  if (platformEvent && !platformEvent.account) {
    return { event: platformEvent, source: "platform" };
  }

  if (secrets.connect) {
    try {
      const connectEvent = await stripe.webhooks.constructEventAsync(rawBody, signature, secrets.connect);
      if (connectEvent.account) return { event: connectEvent, source: "connect" };
    } catch {
      // Both signature paths are intentionally fail-closed below.
    }
  }

  throw new PublicError("invalid_webhook_signature_or_source", 401);
}

export function assertWebhookEventRoute(event: Stripe.Event, source: VerifiedWebhookEvent["source"]) {
  const allowed = source === "connect" ? connectEventTypes : platformEventTypes;
  if (!allowed.has(event.type)) throw new PublicError("webhook_event_source_mismatch", 400);
}
