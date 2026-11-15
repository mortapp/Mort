// Shared TLS-verified PostgreSQL client configuration for remote Supabase
// connections (production backups and read-only security audits).
//
// Both the shared session pooler (aws-0-<region>.pooler.supabase.com) and the
// direct endpoint (db.<project-ref>.supabase.co) present certificates issued by
// Supabase's own "Supabase Root 2021 CA", which is not in Node's default trust
// store. Supabase documents `sslmode=verify-full` with this root as the
// recommended client configuration:
//   https://supabase.com/docs/guides/platform/ssl-enforcement
//
// The root certificate is vendored at scripts/supabase-prod-ca-2021.crt. Its
// SHA-256 fingerprint is pinned in supabase-remote-tls.test.mjs so any
// tampering with the trust anchor fails CI.
//
// Never send a database password over a connection that accepts an untrusted
// or hostname-mismatched TLS certificate: always use the configs from this
// module (rejectUnauthorized: true) instead of `ssl: { rejectUnauthorized: false }`.

import { readFileSync } from "node:fs";
import { createHash, X509Certificate } from "node:crypto";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const productionProjectRef = "jxbnrkasktbhtiujkhay";
const sessionPoolerHost = "aws-0-us-east-2.pooler.supabase.com";

function loadSupabaseRootCa() {
  const certificatePath = join(
    dirname(fileURLToPath(import.meta.url)),
    "supabase-prod-ca-2021.crt",
  );
  const certificate = readFileSync(certificatePath, "utf8");
  // Fingerprint over the DER encoding (matches `openssl x509 -fingerprint`).
  const fingerprint = createHash("sha256")
    .update(new X509Certificate(certificate).raw)
    .digest("hex")
    .toUpperCase()
    .replace(/(..)/g, "$1:")
    .replace(/:$/, "");
  if (fingerprint !== "80:70:25:AD:50:D4:ED:21:9D:2C:9C:7D:29:9C:00:4F:82:4E:B0:0C:F7:F6:5A:FE:F6:07:D0:7B:72:E6:CA:FA") {
    throw new Error("supabase_root_ca_fingerprint_mismatch");
  }
  return certificate;
}

const supabaseRootCa = loadSupabaseRootCa();

export function supabaseVerifiedSsl() {
  return { ca: supabaseRootCa, rejectUnauthorized: true };
}

function requireCredentials({ projectRef, password }) {
  if (!projectRef || typeof projectRef !== "string") {
    throw new Error("supabase_project_ref_required");
  }
  if (typeof password !== "string" || password.length === 0) {
    throw new Error("supabase_db_password_required");
  }
}

// Session pooler (IPv4-reachable from CI runners). The direct endpoint is
// IPv6-only, which is unreachable from IPv4-only CI runners.
export function createSupabasePoolerClientConfig({ projectRef, password, database = "postgres" }) {
  requireCredentials({ projectRef, password });
  return {
    host: sessionPoolerHost,
    port: 5432,
    database,
    user: `postgres.${projectRef}`,
    password,
    ssl: supabaseVerifiedSsl(),
  };
}

// Direct endpoint (IPv6-only). Use only from IPv6-capable environments.
export function createSupabaseDirectClientConfig({ projectRef, password, database = "postgres" }) {
  requireCredentials({ projectRef, password });
  return {
    host: `db.${projectRef}.supabase.co`,
    port: 5432,
    database,
    user: "postgres",
    password,
    ssl: supabaseVerifiedSsl(),
  };
}

export { productionProjectRef, sessionPoolerHost };
