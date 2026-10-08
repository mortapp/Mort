import { Webhook } from "standardwebhooks";
import nodemailer from "nodemailer";
import pg from "pg";

// Deno-only protocol compatibility probe; run via validated Node fixture runner.
if (Deno.env.get("MORT_FIXTURE_VERIFIED") !== "1") {
  throw new Error("Fixture dependency probe refused");
}
const certificate = Deno.env.get("MORT_FIXTURE_CERT");
if (!certificate) throw new Error("Fixture dependency certificate missing");
const transport = nodemailer.createTransport({
  host: "127.0.0.1",
  port: 55425,
  secure: false,
  requireTLS: true,
  auth: { user: "fixture", pass: "fixture-only" },
  tls: { ca: await Deno.readTextFile(certificate), rejectUnauthorized: true },
  connectionTimeout: 2000,
  greetingTimeout: 2000,
  socketTimeout: 3000,
});
await transport.verify();
transport.close();
if (typeof Webhook !== "function" || typeof pg.Client !== "function") {
  throw new Error("Fixture dependency interface mismatch");
}
console.log(
  "PASS Deno pinned Webhooks/pg imports and real certificate-verified STARTTLS SMTP",
);
