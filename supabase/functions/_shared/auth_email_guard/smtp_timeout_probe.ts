import { type DeliveryLease, sendFixedEmail } from "./delivery.ts";
import { makeSecret, secretDigest } from "./crypto.ts";
import { fixedMail } from "./mail.ts";
if (Deno.env.get("MORT_FIXTURE_VERIFIED") !== "1") {
  throw new Error("Fixture deadline refused");
}
const raw = await new Response(Deno.stdin.readable).text();
if (raw.length > 4096) throw new Error("Fixture deadline refused");
const config = JSON.parse(raw);
if (config.mode !== "local_fixture") {
  throw new Error("Fixture deadline refused");
}
const recipient = "synthetic@mort-fixture.invalid";
const lease: DeliveryLease = {
  ok: true,
  itemId: crypto.randomUUID(),
  accountId: crypto.randomUUID(),
  attemptId: crypto.randomUUID(),
  generation: 1,
  purpose: "confirmation",
  recipientHash: await secretDigest(recipient),
  sourceHash: await secretDigest("owned-deadline-probe"),
  addressGeneration: 1,
  credentialGeneration: 1,
  activationGeneration: 1,
  restoreGeneration: 1,
  encryptedEnvelope: "unused",
  familyExpiresAt: new Date(Date.now() + 600000).toISOString(),
  leaseExpiresAt: new Date(Date.now() + 1000).toISOString(),
};
const start = performance.now();
const result = await sendFixedEmail(
  fixedMail({ recipient, code: "00000000", linkSecret: makeSecret() }, lease),
  lease,
  {
    mode: "local_fixture",
    host: "127.0.0.1",
    port: 55425,
    user: "fixture",
    password: "fixture-only",
    ca: await Deno.readTextFile(config.certificate),
  },
);
if (
  result !== "ambiguous" || performance.now() - start < 350 ||
  performance.now() - start > 1300
) throw new Error("Fixture deadline assertion failed");
console.log("PASS isolated SMTP deadline");
// Keep process alive so its eventual exit cannot masquerade as socket teardown.
await new Promise((resolve) => setTimeout(resolve, 1200));
