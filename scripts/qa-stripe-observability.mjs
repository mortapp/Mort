import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { assertQa, qaLog, withDatabase } from "./feature-qa-helpers.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

await withDatabase(async (database) => {
  const columns = await database.query(`
    select column_name
    from information_schema.columns
    where table_schema='private' and table_name='stripe_reconciliation_runs'
  `);
  const names = new Set(columns.rows.map((row) => row.column_name));
  for (const required of [
    "request_id","processing_lease_token","processing_lease_until",
    "attempt_count","updated_at",
  ]) assertQa(names.has(required), `reconciliation column missing ${required}`);

  const indexes = await database.query(`
    select indexdef from pg_indexes
    where schemaname='private' and tablename='stripe_reconciliation_runs'
  `);
  assertQa(indexes.rows.some((row) =>
    /unique index.*environment.*request_id/i.test(String(row.indexdef))),
    "reconciliation request idempotency index is missing");
  assertQa(indexes.rows.some((row) =>
    /status.*processing_lease_until.*started_at/i.test(String(row.indexdef))),
    "reconciliation lease queue index is missing");

  for (const [signature, tokens] of [
    [
      "public.stripe_server_claim_reconciliation_v1(uuid,text,text,uuid,integer)",
      ["private.require_stripe_service_role()","for update","stale_lease_reclaimed",
       "attempt_count=attempt_count+1","reconciliation_lease_claimed"],
    ],
    [
      "public.stripe_server_complete_reconciliation_v1(uuid,uuid,text,text)",
      ["private.require_stripe_service_role()","reconciliation_lease_invalid",
       "processing_lease_token is distinct from p_lease_token","reconciliation_completed"],
    ],
  ]) {
    const result = await database.query(
      `select p.oid,
              has_function_privilege('anon', p.oid, 'EXECUTE') as anon_execute,
              has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated_execute,
              has_function_privilege('service_role', p.oid, 'EXECUTE') as service_execute,
              pg_get_functiondef(p.oid) as definition
         from pg_proc p where p.oid=to_regprocedure($1)`,
      [signature],
    );
    const row = result.rows[0];
    assertQa(Boolean(row), `${signature} is missing`);
    assertQa(row.anon_execute === false && row.authenticated_execute === false,
      `${signature} must not be client executable`);
    assertQa(row.service_execute === true, `${signature} must be service executable`);
    const source = String(row.definition ?? "");
    for (const token of tokens) assertQa(source.includes(token), `${signature} missing ${token}`);
  }

  const incident = await database.query(`
    select pg_get_functiondef(to_regprocedure(
      'public.stripe_server_record_financial_incident(uuid,text,text,text,text,uuid,integer,text,text)'
    )) as definition
  `);
  const incidentSource = String(incident.rows[0]?.definition ?? "");
  for (const required of [
    "financial_incident_replay_conflict","payload_sha256",
    "safe_code","stripe_financial_audit_events",
  ]) assertQa(incidentSource.includes(required), `financial incident recorder missing ${required}`);

  const rate = await database.query(`
    select pg_get_functiondef(to_regprocedure('public.consume_my_edge_action_limit(text)')) as definition
  `);
  const rateSource = String(rate.rows[0]?.definition ?? "");
  for (const action of [
    "stripe_job_payment_status","stripe_financial_document","stripe_financial_history",
  ]) assertQa(rateSource.includes(action), `Edge rate registry missing ${action}`);
  assertQa(rateSource.includes("pg_advisory_xact_lock"), "Edge rate limit is not atomic");
});

const observability = await readFile(
  path.join(root,"supabase","functions","_shared","observability.ts"),"utf8");
const stripe = await readFile(
  path.join(root,"supabase","functions","_shared","stripe.ts"),"utf8");
for (const required of [
  "SafeLogFields","safeEvent","correlation_id","Cache-Control",
]) assertQa(observability.includes(required), `shared observability missing ${required}`);
assertQa(!observability.includes("secretKey"), "observability helper references Stripe secret keys");
assertQa(stripe.includes("structuredLog"), "Stripe safeError path is not structured");
assertQa(stripe.includes("safeProviderCode"), "Stripe provider error code is not sanitized");
assertQa(!/error\.message/.test(stripe.slice(stripe.indexOf("export function safeError"))),
  "Stripe safeError logs raw error messages");

qaLog(
  "stripe-observability",
  "reconciliation uses retry-safe leases, incidents are idempotent/audited, new Edge rate actions are atomic, and logs remain correlated/minimized",
);
