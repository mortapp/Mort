export type WebhookClaimResult = {
  claimed?: unknown;
  duplicate?: unknown;
  in_flight?: unknown;
};

export type WebhookClaimResponse = {
  body: Record<string, unknown>;
  status: number;
};

/** Returns the HTTP response for a terminal/unclaimed event, or null if this
 * request owns the lease and should continue processing the webhook. */
export function webhookClaimResponse(
  claimed: WebhookClaimResult,
): WebhookClaimResponse | null {
  if (claimed.claimed === true) return null;
  if (claimed.in_flight === true) {
    return {
      body: { ok: false, code: "webhook_event_in_flight" },
      status: 503,
    };
  }
  return {
    body: {
      ok: true,
      duplicate: claimed.duplicate === true,
      in_flight: false,
    },
    status: 200,
  };
}
