import { type DeliveryLease, sendFixedEmail } from "./delivery.ts";
import { makeSecret, secretDigest } from "./crypto.ts";
import { fixedMail } from "./mail.ts";
if (Deno.env.get("MORT_FIXTURE_VERIFIED") !== "1") {
  throw new Error("Fixture SMTP fault refused");
}
const raw = await new Response(Deno.stdin.readable).text();
if (raw.length > 4096) throw new Error("Fixture SMTP fault refused");
const config = JSON.parse(raw);
if (
  config.mode !== "local_fixture" ||
  !["auth", "certificate", "downgrade"].includes(config.fault)
) throw new Error("Fixture SMTP fault refused");
const recipient = "synthetic@mort-fixture.invalid";
const lease: DeliveryLease = {
  ok: true,
  itemId: crypto.randomUUID(),
  accountId: crypto.randomUUID(),
  attemptId: crypto.randomUUID(),
  generation: 1,
  purpose: "confirmation",
  recipientHash: await secretDigest(recipient),
  sourceHash: await secretDigest("owned-smtp-fault"),
  addressGeneration: 1,
  credentialGeneration: 1,
  activationGeneration: 1,
  restoreGeneration: 1,
  encryptedEnvelope: "unused",
  familyExpiresAt: new Date(Date.now() + 600000).toISOString(),
  leaseExpiresAt: new Date(Date.now() + 20000).toISOString(),
};
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
  result === "acknowledged" || (config.fault === "auth" && result !== "failed")
) throw new Error("Fixture SMTP fault was not denied");
console.log("PASS owned SMTP fault rejected");
