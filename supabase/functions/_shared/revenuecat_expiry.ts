// Inputs have already passed the webhook's integer timestamp validation.
export function revenueCatActiveUntil(
  eventType: string,
  expirationMs: number | null,
  graceExpirationMs: number | null,
): string | null {
  const effectiveMs =
    eventType === "billing_issue" && graceExpirationMs !== null
      ? Math.max(expirationMs ?? 0, graceExpirationMs)
      : expirationMs;
  return effectiveMs === null ? null : new Date(effectiveMs).toISOString();
}
