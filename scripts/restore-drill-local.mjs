// Local backup restore drill.
//
//   node scripts/restore-drill-local.mjs snapshot   # source DB -> encrypted envelope
//   supabase db reset --local --no-seed             # fresh target from full migration chain
//   node scripts/restore-drill-local.mjs restore    # envelope -> target DB, verify
//
// Exercises the production snapshot code (backup-feature-snapshot.mjs) and the
// production envelope format (backup-envelope.mjs) against a disposable local
// Supabase stack. Refuses any non-local database. Never prints row contents or
// user identifiers: reports only table names, counts and hashes.

import { createHash, randomBytes } from "node:crypto";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import pg from "pg";

import { decryptBackupEnvelope, encryptBackupEnvelope } from "./backup-envelope.mjs";
import { collectFeatureDataSnapshot, quoteIdentifier } from "./backup-feature-snapshot.mjs";

const mode = process.argv[2];
const dbUrl = process.env.MORT_RESTORE_DRILL_DB_URL ?? "postgresql://postgres:postgres@127.0.0.1:54322/postgres";
const keyText = process.env.MORT_RESTORE_DRILL_KEY;
const projectRef = "local-restore-drill";
const kind = "feature-data";
const repoRoot = dirname(dirname(fileURLToPath(import.meta.url)));
const workDir = process.env.MORT_RESTORE_DRILL_DIR ?? join(repoRoot, "backups", "restore-drill");
const envelopePath = join(workDir, "feature-data.envelope.json");
const reportPath = join(workDir, "restore-drill-report.json");

function fail(message) {
  console.error(`[restore-drill] FAIL: ${message}`);
  process.exit(1);
}

const parsedUrl = new URL(dbUrl);
if (!["127.0.0.1", "localhost"].includes(parsedUrl.hostname)) {
  fail(`refusing non-local database host ${parsedUrl.hostname}`);
}
if (!["snapshot", "restore"].includes(mode)) fail("usage: restore-drill-local.mjs snapshot|restore");
if (!keyText) fail("set MORT_RESTORE_DRILL_KEY (base64 32 bytes, e.g. `openssl rand -base64 32`)");

const qualify = (key) => key.split(".").map(quoteIdentifier).join(".");

async function fingerprints(client, keys) {
  const out = {};
  for (const key of keys) {
    // Hash the canonical jsonb text of every row, order-independent.
    const { rows } = await client.query(`
      select count(*)::int as n,
             md5(coalesce(string_agg(v, E'\\n' order by v), '')) as h
      from (select to_jsonb(t)::text as v from ${qualify(key)} t) s`);
    out[key] = { rows: rows[0].n, md5: rows[0].h };
  }
  return out;
}

// Rows that live outside the feature-data snapshot scope. A restore from the
// snapshot alone cannot bring these back.
async function uncoveredInventory(client) {
  const { rows } = await client.query(`
    select n.nspname as schema_name, c.relname as table_name
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where c.relkind in ('r','p')
      and (n.nspname in ('private','auth')
           or (n.nspname = 'storage' and c.relname not in ('buckets','objects','migrations')))
    order by 1, 2`);
  const out = {};
  for (const r of rows) {
    const key = `${r.schema_name}.${r.table_name}`;
    const { rows: c } = await client.query(`select count(*)::int as n from ${qualify(key)}`);
    if (c[0].n > 0) out[key] = c[0].n;
  }
  return out;
}

async function orphanedForeignKeys(client, schemas) {
  const { rows: fks } = await client.query(`
    select co.conname,
           format('%I.%I', n.nspname, c.relname) as child,
           format('%I.%I', rn.nspname, r.relname) as parent,
           rn.nspname as parent_schema,
           (select array_agg(format('%I', a.attname) order by k.ord)
              from unnest(co.conkey) with ordinality k(attnum, ord)
              join pg_attribute a on a.attrelid = co.conrelid and a.attnum = k.attnum) as child_cols,
           (select array_agg(format('%I', a.attname) order by k.ord)
              from unnest(co.confkey) with ordinality k(attnum, ord)
              join pg_attribute a on a.attrelid = co.confrelid and a.attnum = k.attnum) as parent_cols
    from pg_constraint co
    join pg_class c on c.oid = co.conrelid join pg_namespace n on n.oid = c.relnamespace
    join pg_class r on r.oid = co.confrelid join pg_namespace rn on rn.oid = r.relnamespace
    where co.contype = 'f' and n.nspname = any($1)`, [schemas]);
  const orphans = [];
  for (const fk of fks) {
    const notNull = fk.child_cols.map((col) => `ch.${col} is not null`).join(" and ");
    const join = fk.child_cols.map((col, i) => `p.${fk.parent_cols[i]} = ch.${col}`).join(" and ");
    const { rows } = await client.query(
      `select count(*)::int as n from ${fk.child} ch where ${notNull}
         and not exists (select 1 from ${fk.parent} p where ${join})`);
    if (rows[0].n > 0) orphans.push({ constraint: fk.conname, child: fk.child, parent: fk.parent, orphanRows: rows[0].n });
  }
  return orphans;
}

async function snapshotPhase(client) {
  const started = Date.now();
  const snapshot = await collectFeatureDataSnapshot(client, {
    projectRef,
    handling: "Local restore drill only. Disposable synthetic data.",
  });
  const keys = Object.keys(snapshot.tables);
  const source = await fingerprints(client, keys);
  const uncovered = await uncoveredInventory(client);
  const body = Buffer.from(JSON.stringify({ snapshot, source, uncovered }));
  const envelope = encryptBackupEnvelope({ projectRef, kind, plaintext: body, keyText });

  // Envelope integrity must hold before we rely on it.
  const flipped = JSON.parse(envelope.toString("utf8"));
  const ct = Buffer.from(flipped.ciphertext, "base64");
  ct[0] ^= 0x01;
  flipped.ciphertext = ct.toString("base64");
  let tamperRejected = false;
  try {
    decryptBackupEnvelope({ envelope: JSON.stringify(flipped), keyText, expectedProjectRef: projectRef, expectedKind: kind });
  } catch { tamperRejected = true; }
  if (!tamperRejected) fail("tampered envelope was accepted");
  let wrongKeyRejected = false;
  try {
    decryptBackupEnvelope({ envelope, keyText: randomBytes(32).toString("base64"), expectedProjectRef: projectRef, expectedKind: kind });
  } catch { wrongKeyRejected = true; }
  if (!wrongKeyRejected) fail("envelope decrypted with the wrong key");

  mkdirSync(workDir, { recursive: true });
  writeFileSync(envelopePath, envelope, { mode: 0o600 });
  const rowCount = Object.values(source).reduce((s, t) => s + t.rows, 0);
  console.log(`[restore-drill] snapshot: tables=${keys.length} rows=${rowCount} envelope_bytes=${envelope.length} sha256=${createHash("sha256").update(envelope).digest("hex")}`);
  console.log(`[restore-drill] envelope tamper rejected=${tamperRejected} wrong-key rejected=${wrongKeyRejected}`);
  console.log(`[restore-drill] snapshot took ${Date.now() - started}ms`);
}

async function restorePhase(client) {
  const started = Date.now();
  const envelope = readFileSync(envelopePath);
  const { snapshot, source, uncovered } = JSON.parse(
    decryptBackupEnvelope({ envelope, keyText, expectedProjectRef: projectRef, expectedKind: kind }).toString("utf8"),
  );

  const { rows: present } = await client.query(`
    select format('%s.%s', table_schema, table_name) as key from information_schema.tables
    where table_type = 'BASE TABLE' and table_schema in ('public','storage')`);
  const presentSet = new Set(present.map((r) => r.key));
  const missingInTarget = Object.keys(snapshot.tables).filter((k) => !presentSet.has(k));
  if (missingInTarget.length) fail(`target is missing snapshot tables: ${missingInTarget.join(", ")}`);

  const uncoveredBefore = await uncoveredInventory(client);

  await client.query("begin");
  try {
    // Replica role: skip user triggers (audit, guards, timestamps) and FK
    // ordering so rows land exactly as captured.
    await client.query("set local session_replication_role = replica");
    for (const [key, rows] of Object.entries(snapshot.tables)) {
      const [schema, table] = key.split(".");
      await client.query(`delete from ${qualify(key)}`);
      if (rows.length === 0) continue;
      const { rows: cols } = await client.query(`
        select column_name, identity_generation from information_schema.columns
        where table_schema = $1 and table_name = $2 and is_generated = 'NEVER'
        order by ordinal_position`, [schema, table]);
      const list = cols.map((c) => quoteIdentifier(c.column_name)).join(", ");
      const overriding = cols.some((c) => c.identity_generation === "ALWAYS") ? "overriding system value" : "";
      await client.query(
        `insert into ${qualify(key)} (${list}) ${overriding}
         select ${list} from jsonb_populate_recordset(null::${qualify(key)}, $1::jsonb)`,
        [JSON.stringify(rows)],
      );
    }
    // Advance owned sequences past restored keys.
    const { rows: seqs } = await client.query(`
      select format('%I.%I', tn.nspname, t.relname) as tbl, a.attname as col,
             format('%I.%I', sn.nspname, s.relname) as seq
      from pg_depend d
      join pg_class s on s.oid = d.objid and s.relkind = 'S' join pg_namespace sn on sn.oid = s.relnamespace
      join pg_class t on t.oid = d.refobjid join pg_namespace tn on tn.oid = t.relnamespace
      join pg_attribute a on a.attrelid = t.oid and a.attnum = d.refobjsubid
      where d.deptype in ('a','i') and tn.nspname in ('public','storage')`);
    for (const s of seqs) {
      await client.query(
        `select setval('${s.seq}', greatest(coalesce((select max(${quoteIdentifier(s.col)}) from ${s.tbl}), 0), 1),
                (select max(${quoteIdentifier(s.col)}) from ${s.tbl}) is not null)`);
    }
    await client.query("commit");
  } catch (error) {
    await client.query("rollback");
    throw error;
  }
  const restoreMs = Date.now() - started;

  const target = await fingerprints(client, Object.keys(snapshot.tables));
  const mismatches = Object.keys(source).filter(
    (k) => source[k].rows !== target[k].rows || source[k].md5 !== target[k].md5,
  ).map((k) => ({ table: k, sourceRows: source[k].rows, targetRows: target[k].rows, hashMatch: source[k].md5 === target[k].md5 }));
  const orphans = await orphanedForeignKeys(client, ["public", "storage"]);

  // Data that existed in the source outside snapshot scope and is not
  // reproduced by the migration chain in the fresh target.
  const lostOutsideScope = Object.entries(uncovered)
    .filter(([k, n]) => (uncoveredBefore[k] ?? 0) < n)
    .map(([k, n]) => ({ table: k, sourceRows: n, targetRows: uncoveredBefore[k] ?? 0 }));

  const rowCount = Object.values(target).reduce((s, t) => s + t.rows, 0);
  const report = {
    generatedAt: new Date().toISOString(),
    snapshotGeneratedAt: snapshot.generatedAt,
    tables: Object.keys(target).length,
    rowsRestored: rowCount,
    restoreMs,
    fingerprintMismatches: mismatches,
    orphanedForeignKeys: orphans,
    outsideSnapshotScope: { source: uncovered, freshTarget: uncoveredBefore, notRecoverable: lostOutsideScope },
  };
  writeFileSync(reportPath, JSON.stringify(report, null, 2) + "\n");

  console.log(`[restore-drill] restored tables=${report.tables} rows=${rowCount} in ${restoreMs}ms`);
  console.log(`[restore-drill] fingerprint mismatches=${mismatches.length}`);
  for (const m of mismatches) console.log(`  - ${m.table}: source=${m.sourceRows} target=${m.targetRows} hash_match=${m.hashMatch}`);
  console.log(`[restore-drill] orphaned foreign keys=${orphans.length}`);
  for (const o of orphans) console.log(`  - ${o.child} -> ${o.parent} (${o.constraint}): ${o.orphanRows} rows`);
  console.log(`[restore-drill] outside-scope tables not recoverable from snapshot=${lostOutsideScope.length}`);
  for (const l of lostOutsideScope) console.log(`  - ${l.table}: source=${l.sourceRows} fresh_target=${l.targetRows}`);
  console.log(`[restore-drill] report: ${reportPath}`);

  if (mismatches.length) fail("restored data does not match the source snapshot");
  if (process.env.MORT_RESTORE_DRILL_STRICT === "1" && (orphans.length || lostOutsideScope.length)) {
    fail("strict mode: snapshot scope does not cover all source data");
  }
}

const client = new pg.Client({ connectionString: dbUrl });
await client.connect();
try {
  if (mode === "snapshot") await snapshotPhase(client);
  else await restorePhase(client);
} finally {
  await client.end();
}
