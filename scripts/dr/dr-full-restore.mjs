// MORT full disaster-recovery restore + verification. NEVER targets
// production or the deleted project; refuses unless the target is a loopback
// replica or an explicitly confirmed, separate Supabase project whose schema
// was already rebuilt from supabase/production-baseline-recovery (runbook
// step 2).
//
// Local:  DR_TARGET=local DR_LOCAL_DB_URL=... DR_LOCAL_API_URL=... \
//         SUPABASE_SERVICE_ROLE_KEY=... SUPABASE_ANON_KEY=... \
//         MORT_BACKUP_ENCRYPTION_KEY=... DR_BACKUP=file.enc DR_EXPECTED_SOURCE_REF=local-replica \
//         [DR_VERIFY_ACTORS=actors.json] node scripts/dr/dr-full-restore.mjs
// Hosted: DR_TARGET=hosted DR_TARGET_REF=<new ref> DR_CONFIRM_TARGET=<new ref> \
//         DR_TARGET_DB_PASSWORD=... (plus the keys above for the TARGET project)
//
// Restore order (each later step depends on the earlier ones):
//   1 decrypt + integrity check   2 schema compatibility check
//   3 storage.buckets             4 Storage object bytes (API upload, new versions)
//   5 one transaction, triggers suspended: auth -> private -> public tables,
//     storage.objects metadata (keeping the new byte versions), sequences
//   6 verification: per-table hashes, sequences, foreign keys, object bytes,
//     password sign-in + RLS-scoped read for supplied actors.
import { gunzipSync } from "node:zlib";
import { readFileSync, writeFileSync, existsSync } from "node:fs";
import pg from "pg";

import { decryptBackupEnvelope } from "../backup-envelope.mjs";
import { supabaseVerifiedSsl } from "../supabase-remote-tls.mjs";
import {
  FORBIDDEN_REFS, assertSafeTarget, encodeObjectPath, orphanedForeignKeys, qualified, quoteIdent,
  scopeSequences, scopeTables, sha256, tableColumns, tableHash,
} from "./dr-lib.mjs";

const need = (k) => { const v = process.env[k]; if (!v) throw new Error(`${k}_required`); return v; };
const t0 = Date.now();
const timings = {};
const mark = (k, from) => { timings[k] = (Date.now() - from) / 1000; return Date.now(); };

const target = need("DR_TARGET");
let clientConfig, apiUrl, targetRef;
if (target === "local") {
  const url = new URL(need("DR_LOCAL_DB_URL"));
  if (!["127.0.0.1", "localhost"].includes(url.hostname)) throw new Error("dr_local_target_must_be_loopback");
  clientConfig = { connectionString: url.toString() };
  apiUrl = need("DR_LOCAL_API_URL");
  if (!/^http:\/\/(127\.0\.0\.1|localhost):/.test(apiUrl)) throw new Error("dr_local_api_must_be_loopback");
  targetRef = "local-replica";
} else if (target === "hosted") {
  targetRef = need("DR_TARGET_REF");
  if (process.env.DR_CONFIRM_TARGET !== targetRef) throw new Error("dr_confirm_target_mismatch");
  if (!/^[a-z]{20}$/.test(targetRef)) throw new Error("dr_target_ref_invalid");
  const host = process.env.DR_TARGET_DB_HOST ?? `db.${targetRef}.supabase.co`;
  assertSafeTarget({ targetRef, host });
  clientConfig = { host, port: 5432, database: "postgres", user: process.env.DR_TARGET_DB_USER ?? "postgres",
    password: need("DR_TARGET_DB_PASSWORD"), ssl: supabaseVerifiedSsl() };
  apiUrl = `https://${targetRef}.supabase.co`;
} else {
  throw new Error("DR_TARGET must be local or hosted");
}
assertSafeTarget({ targetRef, host: apiUrl });
const serviceKey = need("SUPABASE_SERVICE_ROLE_KEY");
const anonKey = process.env.SUPABASE_ANON_KEY;

// 1. decrypt + integrity
let t = Date.now();
const file = need("DR_BACKUP");
const envelope = readFileSync(file);
if (existsSync(`${file}.sha256`)) {
  const expected = readFileSync(`${file}.sha256`, "utf8").split(/\s+/)[0];
  if (expected !== sha256(envelope)) throw new Error("dr_backup_file_checksum_mismatch");
} else if (process.env.DR_ALLOW_MISSING_CHECKSUM !== "1") {
  throw new Error("dr_backup_checksum_file_missing");
}
const sourceRef = need("DR_EXPECTED_SOURCE_REF");
const payload = JSON.parse(gunzipSync(decryptBackupEnvelope({ envelope, keyText: need("MORT_BACKUP_ENCRYPTION_KEY"), expectedProjectRef: sourceRef, expectedKind: "full-dr-v1" })).toString("utf8"));
if (payload.format !== "mort-full-dr-v1") throw new Error("dr_payload_format_unknown");
if (FORBIDDEN_REFS.has(targetRef)) throw new Error("dr_target_forbidden");
for (const o of payload.objects) if (sha256(Buffer.from(o.data, "base64")) !== o.sha256) throw new Error(`dr_object_hash_mismatch_in_backup:${o.bucket}`);
t = mark("decrypt_and_verify_backup", t);

const client = new pg.Client(clientConfig);
await client.connect();
const report = { target: targetRef, source: sourceRef, backupGeneratedAt: payload.generatedAt, checks: [], timings };
const check = (name, pass, detail = "") => { report.checks.push({ name, pass, detail }); console.log(`${pass ? "PASS" : "FAIL"} ${name}${detail ? ` — ${typeof detail === "string" ? detail : JSON.stringify(detail)}` : ""}`); };
try {
  // 2. schema compatibility
  const targetTables = new Set(await scopeTables(client));
  const missing = Object.keys(payload.tables).filter((k) => !targetTables.has(k));
  const extra = [...targetTables].filter((k) => !payload.tables[k]);
  for (const key of Object.keys(payload.tables)) {
    if (!targetTables.has(key)) continue;
    const cols = (await tableColumns(client, key)).filter((c) => !c.generated).map((c) => c.name);
    const want = payload.tables[key].columns;
    if (want.some((c) => !cols.includes(c))) missing.push(`${key} (columns)`);
  }
  check("target schema contains every backed-up table and column", missing.length === 0, missing.join(", "));
  if (missing.length) throw new Error("dr_target_schema_incompatible: rebuild the target from supabase/production-baseline-recovery first");
  if (extra.length) check("target has no in-scope tables absent from the backup", false, extra.join(", "));
  t = mark("schema_check", t);

  // 3. buckets
  const buckets = payload.tables["storage.buckets"];
  await client.query("begin");
  await client.query("set local session_replication_role = replica");
  await upsertRows(client, "storage.buckets", buckets.columns, buckets.rows, ["id"]);
  await client.query("delete from storage.buckets where not (id = any($1))", [buckets.rows.map((r) => JSON.parse(r).id)]);
  await client.query("commit");
  t = mark("buckets", t);

  // 4. object bytes through the Storage API (target assigns new versions)
  for (const o of payload.objects) {
    const res = await fetch(`${apiUrl}/storage/v1/object/${encodeURIComponent(o.bucket)}/${encodeObjectPath(o.name)}`, {
      method: "POST",
      headers: { apikey: serviceKey, authorization: `Bearer ${serviceKey}`, "content-type": o.contentType, "x-upsert": "true" },
      body: Buffer.from(o.data, "base64"),
    });
    if (!res.ok) throw new Error(`storage_upload_failed:${o.bucket}:${res.status}:${(await res.text()).slice(0, 200)}`);
  }
  t = mark("object_bytes", t);

  // 5. rows, triggers and FK checks suspended, single transaction
  await client.query("begin");
  await client.query("set local session_replication_role = replica");
  const rowTables = Object.keys(payload.tables).filter((k) => !k.startsWith("storage."));
  await client.query(`truncate ${rowTables.map(qualified).join(", ")} cascade`);
  for (const key of rowTables) {
    const tbl = payload.tables[key];
    if (tbl.rows.length) await insertRows(client, key, tbl.columns, tbl.rows);
  }
  // storage.objects: restore every column except the byte version written in step 4.
  const objs = payload.tables["storage.objects"];
  const objCols = objs.columns.filter((c) => c !== "version" && c !== "bucket_id" && c !== "name");
  await client.query(`create temp table dr_objects on commit drop as select * from jsonb_populate_recordset(null::storage.objects, $1::jsonb)`, [jsonArray(objs.rows)]);
  await client.query(`update storage.objects o set ${objCols.map((c) => `${quoteIdent(c)} = d.${quoteIdent(c)}`).join(", ")} from dr_objects d where o.bucket_id = d.bucket_id and o.name = d.name`);
  await client.query("delete from storage.objects o where not exists (select 1 from dr_objects d where d.bucket_id = o.bucket_id and d.name = o.name)");
  for (const s of payload.sequences) {
    if (s.last_value == null) await client.query(`select setval($1::regclass, (select start_value from pg_sequences where schemaname || '.' || sequencename = $2), false)`, [s.key.split(".").map(quoteIdent).join("."), s.key]);
    else await client.query("select setval($1::regclass, $2::bigint, true)", [s.key.split(".").map(quoteIdent).join("."), s.last_value]);
  }
  await client.query("commit");
  t = mark("rows_metadata_sequences", t);

  // 6. verification
  const mismatched = [];
  for (const [key, tbl] of Object.entries(payload.tables)) {
    const h = await tableHash(client, key);
    if (h.count !== tbl.count || h.sha256 !== tbl.sha256) mismatched.push(`${key} (${tbl.count}->${h.count})`);
  }
  const rows = Object.values(payload.tables).reduce((n, x) => n + x.count, 0);
  check(`per-table content hashes match (${Object.keys(payload.tables).length} tables, ${rows} rows)`, mismatched.length === 0, mismatched.join(", "));
  check("auth.users and auth.identities restored", payload.tables["auth.users"].count > 0 && mismatched.every((m) => !m.startsWith("auth.")), `users=${payload.tables["auth.users"].count} identities=${payload.tables["auth.identities"]?.count ?? 0}`);
  const priv = Object.keys(payload.tables).filter((k) => k.startsWith("private."));
  check(`private schema restored (${priv.length} tables)`, mismatched.every((m) => !m.startsWith("private.")), `user_roles=${payload.tables["private.user_roles"]?.count ?? "n/a"}`);
  const seqNow = new Map((await scopeSequences(client)).map((s) => [s.key, s.last_value]));
  const seqBad = payload.sequences.filter((s) => s.last_value != null && seqNow.get(s.key) !== s.last_value).map((s) => s.key);
  check(`sequences restored (${payload.sequences.length})`, seqBad.length === 0, seqBad.join(", "));
  const fk = await orphanedForeignKeys(client);
  check(`no orphaned foreign keys (${fk.checked} constraints)`, fk.orphans.length === 0, fk.orphans);
  const badObjects = [];
  for (const o of payload.objects) {
    const res = await fetch(`${apiUrl}/storage/v1/object/authenticated/${encodeURIComponent(o.bucket)}/${encodeObjectPath(o.name)}`, { headers: { apikey: serviceKey, authorization: `Bearer ${serviceKey}` } });
    const bytes = res.ok ? Buffer.from(await res.arrayBuffer()) : Buffer.alloc(0);
    if (!res.ok || sha256(bytes) !== o.sha256) badObjects.push(`${o.bucket}:${res.status}`);
  }
  check(`Storage object bytes downloadable and identical (${payload.objects.length} objects)`, badObjects.length === 0, badObjects.join(", "));
  t = mark("verification", t);

  const actorsFile = process.env.DR_VERIFY_ACTORS;
  if (actorsFile) {
    if (!anonKey) throw new Error("SUPABASE_ANON_KEY_required_for_actor_checks");
    const actors = JSON.parse(readFileSync(actorsFile, "utf8"));
    for (const [role, a] of Object.entries(actors)) {
      const r = await fetch(`${apiUrl}/auth/v1/token?grant_type=password`, { method: "POST", headers: { apikey: anonKey, "content-type": "application/json" }, body: JSON.stringify({ email: a.email, password: a.password }) });
      const body = await r.json().catch(() => ({}));
      const ok = r.ok && body.user?.id === a.id;
      let own = false;
      if (ok) {
        const p = await fetch(`${apiUrl}/rest/v1/profiles?select=id&id=eq.${a.id}`, { headers: { apikey: anonKey, authorization: `Bearer ${body.access_token}` } });
        own = p.ok && (await p.json()).length === 1;
      }
      check(`restored ${role} signs in with original password and reads own profile under RLS`, ok && own, ok ? (own ? "" : "profile not readable") : `${r.status} ${body.error_code ?? body.msg ?? ""}`);
    }
    const staff = (await client.query("select role::text as role, count(*)::int as n from private.user_roles group by 1 order by 1")).rows;
    check("staff roles present after restore", staff.length > 0, staff);
    t = mark("actor_checks", t);
  }
} finally {
  await client.end().catch(() => {});
}
timings.total = (Date.now() - t0) / 1000;
report.pass = report.checks.every((c) => c.pass);
console.log(JSON.stringify({ pass: report.pass, timings }));
if (process.env.DR_REPORT) writeFileSync(process.env.DR_REPORT, JSON.stringify(report, null, 2));
process.exit(report.pass ? 0 : 1);

async function insertRows(c, key, columns, rows) {
  const cols = columns.map(quoteIdent).join(", ");
  for (let i = 0; i < rows.length; i += 500) {
    await c.query(`insert into ${qualified(key)} (${cols}) overriding system value select ${cols} from jsonb_populate_recordset(null::${qualified(key)}, $1::jsonb)`, [jsonArray(rows.slice(i, i + 500))]);
  }
}

async function upsertRows(c, key, columns, rows, conflict) {
  if (!rows.length) return;
  const cols = columns.map(quoteIdent).join(", ");
  const upd = columns.filter((x) => !conflict.includes(x)).map((x) => `${quoteIdent(x)} = excluded.${quoteIdent(x)}`).join(", ");
  await c.query(`insert into ${qualified(key)} (${cols}) select ${cols} from jsonb_populate_recordset(null::${qualified(key)}, $1::jsonb) on conflict (${conflict.map(quoteIdent).join(", ")}) do update set ${upd}`, [jsonArray(rows)]);
}

// Rows are jsonb text from the backup; never round-trip them through JS values.
function jsonArray(rows) { return `[${rows.join(",")}]`; }
