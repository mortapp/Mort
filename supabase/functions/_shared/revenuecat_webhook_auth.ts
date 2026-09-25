import { constantTimeEqual } from "./observability.ts";

export function acceptsRevenueCatWebhookAuthorization(
  supplied: string,
  legacy: string | undefined,
  play: string | undefined,
): boolean {
  return revenueCatWebhookCredential(supplied, legacy, play) !== null;
}

export function revenueCatWebhookCredential(
  supplied: string,
  legacy: string | undefined,
  play: string | undefined,
  test: string | undefined = undefined,
): "legacy" | "play" | "test" | null {
  if (!supplied) return null;
  const matches = ([
    legacy && constantTimeEqual(legacy, supplied) ? "legacy" : null,
    play && constantTimeEqual(play, supplied) ? "play" : null,
    test && constantTimeEqual(test, supplied) ? "test" : null,
  ] as const).filter((value) => value !== null);
  return matches.length === 1 ? matches[0] : null;
}

export function testStoreWebhookUserAllowed(
  event: Record<string, unknown>,
  testAppId: string,
  allowedUserIds: string,
): boolean {
  const userId = event.app_user_id;
  return event.app_id === testAppId &&
    event.store === "TEST_STORE" &&
    event.environment === "SANDBOX" &&
    typeof event.product_id === "string" &&
    ["weekly", "monthly", "yearly", "lifetime"].includes(event.product_id) &&
    typeof userId === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      .test(userId) &&
    allowedUserIds.split(/[\s,]+/).includes(userId);
}
