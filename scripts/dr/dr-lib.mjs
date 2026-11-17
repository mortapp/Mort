// Shared scope, integrity and target-safety logic for the MORT full
// disaster-recovery backup (dr-full-backup.mjs) and restore
// (dr-full-restore.mjs). Prints only table names, counts and hashes.
import { createHash } from "node:crypto";

export const PRODUCTION_REF = "jxbnrkasktbhtiujkhay";
// Deleted project. Never read from or write to it.
export const FORBIDDEN_REFS = new Set([PRODUCTION_REF, "rakjydmgwwgtdislanbt"]);

export const quoteIdent = (v) => `"${String(v).replaceAll('"', '""')}"`;
export const qualified = (key) => key.split(".").map(quoteIdent).join(".");

// Auth tables that carry durable identity state. Sessions, refresh tokens,
// one-time tokens, flow state and MFA challenges are deliberately excluded:
// they are bound to the source project's JWT secret / time window and are
// useless (or unsafe) on a recovered project. Users sign in again.
export const AUTH_TABLES = [
  "users",
  "identities",
  "mfa_factors",
  "mfa_recovery_code_sets",
  "mfa_recovery_codes",
  "webauthn_credentials",
  "sso_providers",
  "sso_domains",
  "saml_providers",
  "custom_oauth_providers",
  "oauth_clients",
  "oauth_consents",
  "audit_log_entries",
];
export const STORAGE_TABLES = ["buckets", "objects"];

// Columns excluded from the integrity hash, with reason. storage.objects.version
// names the byte blob on the storage backend; re-uploading bytes on the target
// necessarily assigns a new version.
export const HASH_EXCLUDED_COLUMNS = { "storage.objects": ["version"] };

export const EXCLUDED_SCOPE = [
  ["auth.sessions, auth.refresh_tokens, auth.one_time_tokens, auth.flow_state, auth.mfa_challenges, auth.mfa_amr_claims, auth.webauthn_challenges, auth.saml_relay_states, auth.oauth_authorizations, auth.oauth_client_states", "ephemeral; bound to source JWT secret; users re-authenticate"],
  ["auth.instances, auth.schema_migrations, storage.migrations", "owned by the platform; created by the target project"],
  ["vault.secrets", "encrypted with the source project's root key; not portable; re-create from the key manager (see runbook)"],
  ["storage.s3_multipart_uploads*, storage.*vector*, storage.*analytics*, storage.*lifecycle*", "in-flight uploads / unused features"],
  ["supabase_migrations.*", "re-created by applying the production-baseline recovery set"],
];

export async function scopeTables(client) {
  const { rows } = await client.query(
    `select n.nspname || '.' || c.relname as key
       from pg_class c join pg_namespace n on n.oid = c.relnamespace
      where c.relkind in ('r','p') and not c.relispartition
        and (n.nspname in ('public','private')
             or (n.nspname = 'auth' and c.relname = any($1))
             or (n.nspname = 'storage' and c.relname = any($2)))
      order by 1`,
    [AUTH_TABLES, STORAGE_TABLES],
  );
  return rows.map((r) => r.key);
}

export async function tableColumns(client, key) {
  const [schema, table] = key.split(".");
  const { rows } = await client.query(
    `select a.attname as name, a.attgenerated <> '' as generated, a.attidentity as identity
       from pg_attribute a
      where a.attrelid = to_regclass($1) and a.attnum > 0 and not a.attisdropped
      order by a.attnum`,
    [`${quoteIdent(schema)}.${quoteIdent(table)}`],
  );
  return rows;
}

// Canonical content hash: sha256 over the sorted jsonb text of every row.
export async function tableHash(client, key) {
  const excluded = HASH_EXCLUDED_COLUMNS[key] ?? [];
  const { rows } = await client.query(
    `select count(*)::int as n,
            encode(sha256(convert_to(coalesce(string_agg(x, E'\\n' order by x), ''), 'UTF8')), 'hex') as h
       from (select (to_jsonb(t) - $1::text[])::text as x from ${qualified(key)} t) s`,
    [excluded],
  );
  return { count: rows[0].n, sha256: rows[0].h };
}

export async function scopeSequences(client) {
  const { rows } = await client.query(
    `select schemaname || '.' || sequencename as key, last_value::text as last_value
       from pg_sequences where schemaname in ('public','private','auth') order by 1`,
  );
  return rows;
}

// Every foreign key whose child table is in scope must resolve after restore.
export async function orphanedForeignKeys(client) {
  const { rows: fks } = await client.query(
    `select con.conname, cn.nspname || '.' || cc.relname as child, pn.nspname || '.' || pc.relname as parent,
            array(select quote_ident(attname) from unnest(con.conkey) with ordinality k(n, i)
                    join pg_attribute on attrelid = con.conrelid and attnum = k.n order by i) as ccols,
            array(select quote_ident(attname) from unnest(con.confkey) with ordinality k(n, i)
                    join pg_attribute on attrelid = con.confrelid and attnum = k.n order by i) as pcols
       from pg_constraint con
       join pg_class cc on cc.oid = con.conrelid join pg_namespace cn on cn.oid = cc.relnamespace
       join pg_class pc on pc.oid = con.confrelid join pg_namespace pn on pn.oid = pc.relnamespace
      where con.contype = 'f' and cn.nspname in ('public','private','auth','storage')`,
  );
  const orphans = [];
  for (const fk of fks) {
    const notNull = fk.ccols.map((c) => `c.${c} is not null`).join(" and ");
    const join = fk.ccols.map((c, i) => `p.${fk.pcols[i]} = c.${c}`).join(" and ");
    const { rows } = await client.query(
      `select count(*)::int as n from ${qualified(fk.child)} c
        where ${notNull} and not exists (select 1 from ${qualified(fk.parent)} p where ${join})`,
    );
    if (rows[0].n > 0) orphans.push({ constraint: fk.conname, child: fk.child, parent: fk.parent, rows: rows[0].n });
  }
  return { checked: fks.length, orphans };
}

export const sha256 = (buf) => createHash("sha256").update(buf).digest("hex");

export function assertSafeTarget({ targetRef, host }) {
  if (targetRef && FORBIDDEN_REFS.has(targetRef)) throw new Error(`dr_target_forbidden:${targetRef}`);
  for (const ref of FORBIDDEN_REFS) {
    if (host && String(host).includes(ref)) throw new Error(`dr_target_forbidden_host:${ref}`);
  }
}

export const encodeObjectPath = (name) => name.split("/").map(encodeURIComponent).join("/");
