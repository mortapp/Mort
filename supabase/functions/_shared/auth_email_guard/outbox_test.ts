import { decryptEnvelope, encryptEnvelope } from "./outbox.ts";
Deno.test("outbox AEAD binds ciphertext to item context; tamper and wrong key fail", async () => {
  const key = await crypto.subtle.importKey(
    "raw",
    crypto.getRandomValues(new Uint8Array(32)),
    "AES-GCM",
    false,
    ["encrypt", "decrypt"],
  );
  const other = await crypto.subtle.importKey(
    "raw",
    crypto.getRandomValues(new Uint8Array(32)),
    "AES-GCM",
    false,
    ["encrypt", "decrypt"],
  );
  const body = new TextEncoder().encode(
    JSON.stringify({ synthetic: crypto.randomUUID() }),
  );
  const binding = JSON.stringify({
    item: crypto.randomUUID(),
    purpose: "confirmation",
    generation: 1,
  });
  const first = await encryptEnvelope(body, binding, key),
    second = await encryptEnvelope(body, binding, key);
  if (
    first === second ||
    new TextDecoder().decode(await decryptEnvelope(first, binding, key)) !==
      new TextDecoder().decode(body)
  ) throw new Error("Outbox encryption assertion (redacted)");
  for (
    const attempt of [
      () => decryptEnvelope(first, binding + "x", key),
      () => decryptEnvelope(first, binding, other),
      () => decryptEnvelope(first.slice(0, -4) + "AAAA", binding, key),
      () => decryptEnvelope("invalid", binding, key),
    ]
  ) {
    let denied = false;
    try {
      await attempt();
    } catch (error) {
      denied = error instanceof Error &&
        error.message === "Envelope unavailable";
    }
    if (!denied) throw new Error("Outbox binding denial failed (redacted)");
  }
});
