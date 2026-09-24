import { assert, assertEquals } from "jsr:@std/assert@1";
import { acceptsRevenueCatWebhookAuthorization } from "./revenuecat_webhook_auth.ts";

Deno.test("RevenueCat webhook accepts the existing and Play credentials", () => {
  assert(acceptsRevenueCatWebhookAuthorization("Bearer legacy-value", "Bearer legacy-value", "Bearer play-value"));
  assert(acceptsRevenueCatWebhookAuthorization("Bearer play-value", "Bearer legacy-value", "Bearer play-value"));
  assertEquals(acceptsRevenueCatWebhookAuthorization("Bearer wrong", "Bearer legacy-value", "Bearer play-value"), false);
  assertEquals(acceptsRevenueCatWebhookAuthorization("", undefined, undefined), false);
  assertEquals(acceptsRevenueCatWebhookAuthorization("", "Bearer legacy-value", undefined), false);
});
