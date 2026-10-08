import { Webhook } from "standardwebhooks";
import { handleEmailHook, type HookDeps } from "./handler.ts";
import { decryptEnvelope } from "../_shared/auth_email_guard/outbox.ts";
import { envelopeBinding } from "../_shared/auth_email_guard/mail.ts";
const encoder = new TextEncoder();
function check(value: unknown, message: string): asserts value {
  if (!value) throw new Error(message);
}
async function fixture() {
  const secret = crypto.getRandomValues(new Uint8Array(32));
  const webhook = new Webhook(secret, { format: "raw" });
  const encryptionKey = await crypto.subtle.generateKey(
    { name: "AES-GCM", length: 256 },
    false,
    ["encrypt", "decrypt"],
  );
  const codeKey = await crypto.subtle.generateKey(
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const context = {
    addressGeneration: 1,
    credentialGeneration: 1,
    activationGeneration: 1,
    restoreGeneration: 1,
  };
  let calls = 0;
  let issued: Record<string, unknown> | undefined;
  const deps: HookDeps = {
    mode: "local_fixture",
    signingSecret: secret,
    encryptionKey,
    codeKey,
    resolveTrustedSource: async () => "a".repeat(64),
    store: {
      context: async () => context,
      issue: async (event, material) => {
        calls++;
        issued = { event, material };
        return { ok: true };
      },
    },
  };
  const body = JSON.stringify({
    user: {
      id: crypto.randomUUID(),
      email: "synthetic@mort-fixture.invalid",
      user_metadata: { forwarded_for: "untrusted" },
    },
    email_data: {
      email_action_type: "signup",
      token: "provider-value-discarded",
      redirect_to: "https://untrusted.invalid",
    },
  });
  function request(payload = body, offset = 0, signer = webhook) {
    const id = crypto.randomUUID(), date = new Date(Date.now() + offset * 1000);
    return new Request("http://127.0.0.1:55426/hook", {
      method: "POST",
      body: payload,
      headers: {
        "content-type": "application/json",
        "webhook-id": id,
        "webhook-timestamp": String(Math.floor(date.getTime() / 1000)),
        "webhook-signature": signer.sign(id, date, payload),
        "x-forwarded-for": "untrusted",
      },
    });
  }
  return {
    deps,
    body,
    request,
    encryptionKey,
    calls: () => calls,
    issued: () => issued,
  };
}
Deno.test("missing signing encryption or HMAC configuration never issues a challenge", async () => {
  for (const key of ["signingSecret", "encryptionKey", "codeKey"]) {
    const f = await fixture();
    const deps = { ...f.deps, [key]: undefined } as unknown as HookDeps;
    check(
      (await handleEmailHook(f.request(), deps)).status === 400 &&
        f.calls() === 0,
      "Omitted secret cannot enqueue or use a weak fallback",
    );
  }
});
Deno.test("signed provider bytes admit only a digest-bound encrypted custom envelope", async () => {
  const f = await fixture();
  const response = await handleEmailHook(f.request(), f.deps);
  check(
    response.status === 200 && f.calls() === 1,
    "Valid signed event must admit exactly one encrypted outbox item",
  );
  const issued = f.issued()!;
  const event = issued.event as Record<string, unknown>,
    material = issued.material as Record<string, unknown>;
  check(
    !JSON.stringify(issued).includes("provider-value-discarded") &&
      !JSON.stringify(issued).includes("untrusted.invalid"),
    "Provider token/redirect cannot escape into custom challenge authority",
  );
  const binding = envelopeBinding(
    { ...event, ...material } as Parameters<typeof envelopeBinding>[0],
  );
  const plain = JSON.parse(
    new TextDecoder().decode(
      await decryptEnvelope(
        material.encryptedEnvelope as string,
        binding,
        f.encryptionKey,
      ),
    ),
  );
  check(
    plain.recipient === "synthetic@mort-fixture.invalid" &&
      /^\d{8}$/.test(plain.code) &&
      /^[A-Za-z0-9_-]{43}$/.test(plain.linkSecret),
    "Envelope contains only generated independent credentials and signed recipient",
  );
  check(
    !JSON.stringify(material).includes(plain.code) &&
      !JSON.stringify(material).includes(plain.linkSecret),
    "No code/link plaintext is inserted in private store material",
  );
});
Deno.test("signature, freshness and canonical parsing denials never enqueue", async () => {
  const f = await fixture(),
    other = new Webhook(crypto.getRandomValues(new Uint8Array(32)), {
      format: "raw",
    });
  for (
    const request of [
      f.request(f.body, 0, other),
      f.request(f.body, -301),
      f.request(f.body, 31),
      f.request('{"user":{},"u\\u0073er":{},"email_data":{}}'),
      f.request("x".repeat(16385)),
      f.request(f.body.replace('"signup"', '"email_change"')),
      new Request("http://127.0.0.1:55426/hook"),
    ]
  ) {
    const response = await handleEmailHook(request, f.deps);
    check(
      response.status !== 200,
      "Unsigned/stale/malformed/unsupported provider event must fail",
    );
  }
  check(f.calls() === 0, "Invalid hook events must never charge issuance");
  check(
    (await handleEmailHook(f.request(), f.deps)).status === 200,
    "Legitimate event still works after denials",
  );
});
Deno.test("missing owned ingress binding and disabled mode fail closed despite signed payload", async () => {
  const f = await fixture();
  check(
    (await handleEmailHook(f.request(), {
      ...f.deps,
      resolveTrustedSource: async () => null,
    })).status !== 200,
    "Signed event alone cannot invent source identity",
  );
  check(
    (await handleEmailHook(f.request(), { ...f.deps, mode: "disabled" }))
          .status === 503 && f.calls() === 0,
    "Disabled mode cannot enqueue or use forwarded metadata",
  );
});
Deno.test("new transport ID cannot reuse an old signed event", async () => {
  const f = await fixture();
  const request = f.request();
  request.headers.set("webhook-id", crypto.randomUUID());
  check(
    (await handleEmailHook(request, f.deps)).status !== 200 && f.calls() === 0,
    "Changed transport identity must fail signature before issuance",
  );
  check(
    (await handleEmailHook(f.request(), f.deps)).status === 200,
    "Fresh correctly signed positive remains available",
  );
});
Deno.test("hook dependency timeout aborts before issuance and legitimate retry remains live", async () => {
  const f = await fixture();
  let aborted = false;
  const started = performance.now();
  const result = await handleEmailHook(f.request(), {
    ...f.deps,
    resolveTrustedSource: async (_event, _account, signal) =>
      await new Promise((resolve) => {
        signal.addEventListener("abort", () => {
          aborted = true;
          resolve(null);
        }, { once: true });
      }),
  });
  check(
    result.status !== 200 && aborted && f.calls() === 0 &&
      performance.now() - started < 3500,
    "Timed-out hook cannot enqueue late authority",
  );
  check(
    (await handleEmailHook(f.request(), f.deps)).status === 200,
    "Bounded timeout must preserve later legitimate admission",
  );
});
