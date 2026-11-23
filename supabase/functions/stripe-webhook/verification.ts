import Stripe from "npm:stripe@22.1.1";
import { PublicError } from "../_shared/stripe.ts";
import { webhookRoutes } from "./observation.ts";

export type WebhookSecrets = {
  platform: string | undefined;
  connect: string | undefined;
};

export type VerifiedWebhookEvent = {
  event: Stripe.Event;
  source: "platform" | "connect";
};

export async function verifyWebhookEvent(
  stripe: Stripe,
  rawBody: string,
  signature: string,
  secrets: WebhookSecrets,
): Promise<VerifiedWebhookEvent> {
  let platformEvent: Stripe.Event | undefined;
  if (secrets.platform) {
    try {
      platformEvent = await stripe.webhooks.constructEventAsync(
        rawBody,
        signature,
        secrets.platform,
      );
    } catch {
      platformEvent = undefined;
    }
  }

  if (platformEvent && !platformEvent.account) {
    return { event: platformEvent, source: "platform" };
  }

  if (secrets.connect) {
    try {
      const connectEvent = await stripe.webhooks.constructEventAsync(
        rawBody,
        signature,
        secrets.connect,
      );
      if (connectEvent.account) {
        return { event: connectEvent, source: "connect" };
      }
    } catch {
      // Both signature paths are intentionally fail-closed below.
    }
  }

  throw new PublicError("invalid_webhook_signature_or_source", 401);
}

export function assertWebhookEventRoute(
  event: Stripe.Event,
  source: VerifiedWebhookEvent["source"],
) {
  if (!Object.hasOwn(webhookRoutes[source], event.type)) {
    throw new PublicError("webhook_event_source_mismatch", 400);
  }
}
