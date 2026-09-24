import { constantTimeEqual } from "./observability.ts";

export function acceptsRevenueCatWebhookAuthorization(
  supplied: string,
  legacy: string | undefined,
  play: string | undefined,
): boolean {
  const legacyMatches = legacy ? constantTimeEqual(legacy, supplied) : false;
  const playMatches = play ? constantTimeEqual(play, supplied) : false;
  return legacyMatches || playMatches;
}
