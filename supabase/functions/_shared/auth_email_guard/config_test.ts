import {
  type DeliveryLease,
  type FixedMail,
  type FixtureSmtp,
  sendFixedEmail,
} from "./delivery.ts";
Deno.test("missing SMTP configuration fails closed before opening any transport", async () => {
  const complete = {
    mode: "local_fixture",
    host: "127.0.0.1",
    port: 55425,
    ca: "BEGIN CERTIFICATE",
    user: "fixture",
    password: "synthetic-only",
  };
  for (const key of Object.keys(complete)) {
    const missing = { ...complete } as Record<string, unknown>;
    delete missing[key];
    if (
      await sendFixedEmail(
        {} as FixedMail,
        {} as DeliveryLease,
        missing as FixtureSmtp,
      ) !== "failed"
    ) throw new Error("Missing SMTP field admitted transport");
  }
  if (
    await sendFixedEmail(
      {} as FixedMail,
      {} as DeliveryLease,
      undefined as unknown as FixtureSmtp,
    ) !== "failed"
  ) throw new Error("Missing SMTP configuration admitted transport");
});
