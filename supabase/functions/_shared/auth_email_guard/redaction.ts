export const publicFailure = () => ({
  ok: false as const,
  message: "That request is not valid.",
});
export const busy = () => ({
  ok: false as const,
  message: "MORT is busy. Try again shortly.",
  retryAfterSeconds: 1,
});
const outcomes = new Set([
  "accepted",
  "denied",
  "busy",
  "acknowledged",
  "ambiguous",
  "expired",
  "quota_limited",
  "deferred",
]);
export function safeEvent(
  _id: string,
  outcome: string,
): Record<string, string> {
  if (!outcomes.has(outcome)) throw new Error("Invalid diagnostic outcome");
  // No supplied locator, recipient or exception is accepted in diagnostic data.
  return { event: "mort_email_guard", outcome };
}
