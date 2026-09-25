import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  acceptsRevenueCatWebhookAuthorization,
  revenueCatWebhookCredential,
  testStoreWebhookUserAllowed,
} from "./revenuecat_webhook_auth.ts";

Deno.test("RevenueCat webhook accepts the existing and Play credentials", () => {
  assert(
    acceptsRevenueCatWebhookAuthorization(
      "Bearer legacy-value",
      "Bearer legacy-value",
      "Bearer play-value",
    ),
  );
  assert(
    acceptsRevenueCatWebhookAuthorization(
      "Bearer play-value",
      "Bearer legacy-value",
      "Bearer play-value",
    ),
  );
  assertEquals(
    acceptsRevenueCatWebhookAuthorization(
      "Bearer wrong",
      "Bearer legacy-value",
      "Bearer play-value",
    ),
    false,
  );
  assertEquals(
    acceptsRevenueCatWebhookAuthorization("", undefined, undefined),
    false,
  );
  assertEquals(
    acceptsRevenueCatWebhookAuthorization("", "Bearer legacy-value", undefined),
    false,
  );
});

Deno.test("RevenueCat Test Store webhook uses its own credential", () => {
  assertEquals(
    revenueCatWebhookCredential(
      "Bearer test-value",
      "Bearer legacy-value",
      "Bearer play-value",
      "Bearer test-value",
    ),
    "test",
  );
  assertEquals(
    revenueCatWebhookCredential(
      "Bearer play-value",
      "Bearer legacy-value",
      "Bearer play-value",
      "Bearer test-value",
    ),
    "play",
  );
  assertEquals(
    revenueCatWebhookCredential(
      "Bearer wrong",
      "Bearer legacy-value",
      "Bearer play-value",
      "Bearer test-value",
    ),
    null,
  );
});

Deno.test("Test Store backend updates require the correct app, sandbox, and controlled user", () => {
  const user = "11111111-1111-4111-8111-111111111111";
  const allowed = user;
  const event = {
    app_id: "app0f5777aab7",
    store: "TEST_STORE",
    environment: "SANDBOX",
    app_user_id: user,
    product_id: "weekly",
  };
  assert(testStoreWebhookUserAllowed(event, "app0f5777aab7", allowed));
  assertEquals(
    testStoreWebhookUserAllowed(
      { ...event, app_user_id: "22222222-2222-4222-8222-222222222222" },
      "app0f5777aab7",
      allowed,
    ),
    false,
  );
  assertEquals(
    testStoreWebhookUserAllowed(
      { ...event, app_id: "app8eaa6ee77f" },
      "app0f5777aab7",
      allowed,
    ),
    false,
  );
  assertEquals(
    testStoreWebhookUserAllowed(
      { ...event, store: "PLAY_STORE" },
      "app0f5777aab7",
      allowed,
    ),
    false,
  );
  assertEquals(
    testStoreWebhookUserAllowed(
      { ...event, product_id: "mort_pro:weekly" },
      "app0f5777aab7",
      allowed,
    ),
    false,
  );
  assertEquals(
    testStoreWebhookUserAllowed(
      { ...event, environment: "PRODUCTION" },
      "app0f5777aab7",
      allowed,
    ),
    false,
  );
  assertEquals(testStoreWebhookUserAllowed(event, "app0f5777aab7", ""), false);
});
