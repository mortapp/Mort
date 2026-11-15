import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { X509Certificate } from "node:crypto";
import { readFileSync } from "node:fs";
import test from "node:test";

import {
  createSupabaseDirectClientConfig,
  createSupabasePoolerClientConfig,
  productionProjectRef,
  sessionPoolerHost,
  supabaseVerifiedSsl,
} from "./supabase-remote-tls.mjs";

// Pinned SHA-256 fingerprint of the vendored Supabase Root 2021 CA. This is
// the trust anchor Supabase documents for sslmode=verify-full against both
// the direct endpoint and the shared session pooler. The fingerprint was
// cross-checked against the live pooler chain and independent TLS scans of
// the direct endpoint; any change to the vendored certificate must be a
// deliberate, reviewed decision.
const pinnedRootFingerprint =
  "80:70:25:AD:50:D4:ED:21:9D:2C:9C:7D:29:9C:00:4F:82:4E:B0:0C:F7:F6:5A:FE:F6:07:D0:7B:72:E6:CA:FA";

test("vendored Supabase root CA matches its pinned fingerprint", () => {
  const certificate = readFileSync(
    new URL("./supabase-prod-ca-2021.crt", import.meta.url),
    "utf8",
  );
  const parsed = new X509Certificate(certificate);
  assert.ok(parsed.subject.includes("CN=Supabase Root 2021 CA"));
  assert.ok(parsed.subject.includes("O=Supabase Inc"));
  const fingerprint = createHash("sha256")
    .update(parsed.raw)
    .digest("hex")
    .toUpperCase()
    .replace(/(..)/g, "$1:")
    .replace(/:$/, "");
  assert.equal(fingerprint, pinnedRootFingerprint);
});

test("supabaseVerifiedSsl never disables certificate verification", () => {
  const ssl = supabaseVerifiedSsl();
  assert.equal(ssl.rejectUnauthorized, true);
  assert.ok(typeof ssl.ca === "string" && ssl.ca.includes("BEGIN CERTIFICATE"));
});

test("pooler client config verifies TLS and uses the session pooler", () => {
  const config = createSupabasePoolerClientConfig({
    projectRef: productionProjectRef,
    password: "dummy",
  });
  assert.equal(config.host, sessionPoolerHost);
  assert.equal(config.port, 5432);
  assert.equal(config.user, `postgres.${productionProjectRef}`);
  assert.equal(config.ssl.rejectUnauthorized, true);
  assert.ok(config.ssl.ca.includes("BEGIN CERTIFICATE"));
});

test("direct client config verifies TLS against the direct endpoint", () => {
  const config = createSupabaseDirectClientConfig({
    projectRef: productionProjectRef,
    password: "dummy",
  });
  assert.equal(config.host, `db.${productionProjectRef}.supabase.co`);
  assert.equal(config.user, "postgres");
  assert.equal(config.ssl.rejectUnauthorized, true);
});

test("client configs fail closed without credentials", () => {
  assert.throws(() => createSupabasePoolerClientConfig({ projectRef: "x", password: "" }),
    /supabase_db_password_required/);
  assert.throws(() => createSupabaseDirectClientConfig({ projectRef: "", password: "x" }),
    /supabase_project_ref_required/);
});
