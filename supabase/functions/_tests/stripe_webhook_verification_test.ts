import Stripe from "npm:stripe@22.1.1";
import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import { PublicError } from "../_shared/stripe.ts";
import { assertWebhookEventRoute, verifyWebhookEvent } from "../stripe-webhook/verification.ts";

const platformSecret = "whsec_platform";
const connectSecret = "whsec_connect";
const stripe = new Stripe("sk_test_placeholder", { telemetry: false });

async function signature(body: string, secret: string) {
  const timestamp = Math.floor(Date.now() / 1000);
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const digest = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(`${timestamp}.${body}`),
  );
  const hex = Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
  return `t=${timestamp},v1=${hex}`;
}

async function signedEvent(account?: string, eventType?: string) {
  const event = {
    id: crypto.randomUUID(),
    object: "event",
    api_version: "2026-07-29.dahlia",
    created: Math.floor(Date.now() / 1000),
    data: { object: { id: "pi_test", object: "payment_intent" } },
    livemode: false,
    pending_webhooks: 1,
    request: null,
    type: eventType ?? (account ? "account.updated" : "payment_intent.succeeded"),
    ...(account ? { account } : {}),
  };
  const body = JSON.stringify(event);
  return { body, signature: await signature(body, account ? connectSecret : platformSecret) };
}

Deno.test("accepts a valid platform signature", async () => {
  const signed = await signedEvent();
  const verified = await verifyWebhookEvent(stripe, signed.body, signed.signature, {
    platform: platformSecret,
    connect: connectSecret,
  });
  assertEquals(verified.source, "platform");
  assertEquals(verified.event.account, undefined);
});

Deno.test("accepts requires-action as a platform payment event", async () => {
  const signed = await signedEvent(undefined, "payment_intent.requires_action");
  const verified = await verifyWebhookEvent(stripe, signed.body, signed.signature, {
    platform: platformSecret,
    connect: connectSecret,
  });
  assertEquals(verified.source, "platform");
  assertEquals(verified.event.type, "payment_intent.requires_action");
  assertWebhookEventRoute(verified.event, verified.source);
});

Deno.test("accepts a valid Connect signature", async () => {
  const signed = await signedEvent("acct_connected");
  const verified = await verifyWebhookEvent(stripe, signed.body, signed.signature, {
    platform: platformSecret,
    connect: connectSecret,
  });
  assertEquals(verified.source, "connect");
  assertEquals(verified.event.account, "acct_connected");
});

Deno.test("rejects invalid signatures", async () => {
  const signed = await signedEvent();
  await assertRejects(() => verifyWebhookEvent(stripe, signed.body, "t=1,v1=invalid", {
    platform: platformSecret,
    connect: connectSecret,
  }), PublicError);
});

Deno.test("rejects a Connect event signed only with the platform secret", async () => {
  const signed = await signedEvent("acct_connected");
  const platformSigned = {
    ...signed,
    signature: await signature(signed.body, platformSecret),
  };
  await assertRejects(() => verifyWebhookEvent(stripe, platformSigned.body, platformSigned.signature, {
    platform: platformSecret,
    connect: connectSecret,
  }));
});

Deno.test("rejects a platform event signed only with the Connect secret", async () => {
  const signed = await signedEvent();
  const connectSigned = {
    ...signed,
    signature: await signature(signed.body, connectSecret),
  };
  await assertRejects(() => verifyWebhookEvent(stripe, connectSigned.body, connectSigned.signature, {
    platform: platformSecret,
    connect: connectSecret,
  }));
});

Deno.test("fails closed when the required secret is missing", async () => {
  const platform = await signedEvent();
  await assertRejects(() => verifyWebhookEvent(stripe, platform.body, platform.signature, {
    platform: undefined,
    connect: connectSecret,
  }));

  const connect = await signedEvent("acct_connected");
  await assertRejects(() => verifyWebhookEvent(stripe, connect.body, connect.signature, {
    platform: platformSecret,
    connect: undefined,
  }));
});

Deno.test("enforces platform and Connect event routing", async () => {
  const platform = await signedEvent();
  const verifiedPlatform = await verifyWebhookEvent(stripe, platform.body, platform.signature, {
    platform: platformSecret,
    connect: connectSecret,
  });
  assertWebhookEventRoute(verifiedPlatform.event, verifiedPlatform.source);

  const connect = await signedEvent("acct_connected");
  const verifiedConnect = await verifyWebhookEvent(stripe, connect.body, connect.signature, {
    platform: platformSecret,
    connect: connectSecret,
  });
  assertWebhookEventRoute(verifiedConnect.event, verifiedConnect.source);

  await assertRejects(async () => {
    assertWebhookEventRoute(verifiedConnect.event, "platform");
  });
});
