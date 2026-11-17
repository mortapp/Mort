// MORT full disaster-recovery backup: auth identities, public + private
// schemas, Storage metadata AND object bytes, sequences, and an integrity
// manifest, sealed in the AES-256-GCM backup envelope.
//
// Production (owner-approved workflow only; read-only against production):
//   DR_SOURCE=production SUPABASE_DB_PASSWORD=... SUPABASE_SERVICE_ROLE_KEY=... \
//   MORT_BACKUP_ENCRYPTION_KEY=<base64 32 bytes> DR_OUT=dir node scripts/dr/dr-full-backup.mjs
// Local replica (drill / CI):
//   DR_SOURCE=local DR_LOCAL_DB_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres \
//   DR_LOCAL_API_URL=http://127.0.0.1:54321 SUPABASE_SERVICE_ROLE_KEY=... MORT_BACKUP_ENCRYPTION_KEY=... \
//   node scripts/dr/dr-full-backup.mjs
//
// The service-role key is used only server-side, here, to read Storage bytes.
import { gzipSync } from "node:zlib";
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import pg from "pg";

import { encryptBackupEnvelope } from "../backup-envelope.mjs";
import { createSupabasePoolerClientConfig } from "../supabase-remote-tls.mjs";
import {
  EXCLUDED_SCOPE, HASH_EXCLUDED_COLUMNS, PRODUCTION_REF, encodeObjectPath, qualified,
  scopeSequences, scopeTables, sha256, tableColumns, tableHash,
} from "./dr-lib.mjs";

const need = (k) => { const v = process.env[k]; if (!v) throw new Error(`${k}_required`); return v; };
const source = need("DR_SOURCE");
const keyText = need("MORT_BACKUP_ENCRYPTION_KEY");
const serviceKey = need("SUPABASE_SERVICE_ROLE_KEY");
const out = process.env.DR_OUT ?? "backups/dr";

let projectRef, clientConfig, apiUrl;
if (source === "production") {
  projectRef = PRODUCTION_REF;
  clientConfig = createSupabasePoolerClientConfig({ projectRef, password: need("SUPABASE_DB_PASSWORD") });
  apiUrl = `https://${projectRef}.supabase.co`;
} else if (source === "local") {
  projectRef = "local-replica";
  const url = new URL(need("DR_LOCAL_DB_URL"));
  if (!["127.0.0.1", "localhost"].includes(url.hostname)) throw new Error("dr_local_source_must_be_loopback");
  clientConfig = { connectionString: url.toString() };
  apiUrl = need("DR_LOCAL_API_URL");
  if (!/^http:\/\/(127\.0\.0\.1|localhost):/.test(apiUrl)) throw new Error("dr_local_api_must_be_loopback");
} else {
  throw new Error("DR_SOURCE must be production or local");
}

const started = Date.now();
const client = new pg.Client(clientConfig);
await client.connect();
const payload = {
  format: "mort-full-dr-v1",
  projectRef,
  generatedAt: new Date().toISOString(),
  handling: "Contains personal data, password hashes and identity evidence. Encrypted at rest; never commit or log.",
  excluded: EXCLUDED_SCOPE,
  hashExcludedColumns: HASH_EXCLUDED_COLUMNS,
  tables: {},
  sequences: [],
  objects: [],
};
try {
  // One consistent snapshot for every table and the object list.
  await client.query("begin isolation level repeatable read read only");
  for (const key of await scopeTables(client)) {
    const columns = (await tableColumns(client, key)).filter((c) => !c.generated);
    // Rows stay as jsonb TEXT end to end: parsing into JS numbers would change
    // numeric scale (25.00 -> 25) and precision (> 2^53) and break fidelity.
    const { rows } = await client.query(`select to_jsonb(t)::text as r from ${qualified(key)} t`);
    payload.tables[key] = { columns: columns.map((c) => c.name), rows: rows.map((r) => r.r), ...(await tableHash(client, key)) };
  }
  payload.sequences = await scopeSequences(client);
  const objects = (await client.query(
    "select bucket_id, name, metadata->>'mimetype' as mimetype, (metadata->>'size')::bigint as size from storage.objects order by 1, 2",
  )).rows;
  await client.query("commit");

  for (const o of objects) {
    const res = await fetch(`${apiUrl}/storage/v1/object/authenticated/${encodeURIComponent(o.bucket_id)}/${encodeObjectPath(o.name)}`, {
      headers: { apikey: serviceKey, authorization: `Bearer ${serviceKey}` },
    });
    if (!res.ok) throw new Error(`storage_download_failed:${o.bucket_id}:${res.status}`);
    const bytes = Buffer.from(await res.arrayBuffer());
    if (o.size != null && Number(o.size) !== bytes.length) throw new Error(`storage_size_mismatch:${o.bucket_id}`);
    payload.objects.push({ bucket: o.bucket_id, name: o.name, contentType: o.mimetype ?? "application/octet-stream", size: bytes.length, sha256: sha256(bytes), data: bytes.toString("base64") });
  }
} finally {
  await client.end();
}

const plaintext = gzipSync(Buffer.from(JSON.stringify(payload)));
const envelope = encryptBackupEnvelope({ projectRef, kind: "full-dr-v1", plaintext, keyText });
mkdirSync(out, { recursive: true });
const stamp = payload.generatedAt.replace(/[:.]/g, "-");
const file = join(out, `mort-full-dr-${projectRef}-${stamp}.enc`);
writeFileSync(file, envelope, { mode: 0o600 });
writeFileSync(`${file}.sha256`, `${sha256(envelope)}  ${file.split("/").pop()}\n`);

const tableCount = Object.keys(payload.tables).length;
const rowCount = Object.values(payload.tables).reduce((n, t) => n + t.count, 0);
const summary = { file, projectRef, generatedAt: payload.generatedAt, tables: tableCount, rows: rowCount,
  authUsers: payload.tables["auth.users"]?.count ?? 0, privateTables: Object.keys(payload.tables).filter((k) => k.startsWith("private.")).length,
  objects: payload.objects.length, objectBytes: payload.objects.reduce((n, o) => n + o.size, 0), seconds: (Date.now() - started) / 1000 };
console.log(JSON.stringify(summary));
if (process.env.DR_SUMMARY) writeFileSync(process.env.DR_SUMMARY, JSON.stringify(summary, null, 2));
