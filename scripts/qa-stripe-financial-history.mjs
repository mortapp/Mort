import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { assertQa, qaLog, withDatabase } from "./feature-qa-helpers.mjs";
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

await withDatabase(async (database) => {
  const result = await database.query(\`
    select p.oid,
      has_function_privilege('anon', p.oid, 'EXECUTE') as anon_execute,
      has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated_execute,
      pg_get_functiondef(p.oid) as definition
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='get_my_financial_history_v2'
  \`);
  const row = result.rows[0];
  assertQa(Boolean(row), "get_my_financial_history_v2 is missing");
  assertQa(row.anon_execute === false, "financial history v2 must reject anon execution");
  assertQa(row.authenticated_execute === true, "financial history v2 must allow authenticated callers");
  const source = String(row.definition ?? "");
  for (const required of [
    "actor uuid := auth.uid()",
    "(e.occurred_at, e.event_id) < (p_cursor_at, p_cursor_id)",
    "limit v_limit + 1",
    "least(coalesce(p_limit, 50), 50)",
    "private.financial_documents",
    "private.stripe_job_payment_attempts",
    "private.stripe_financial_ledger_events",
    "private.stripe_tip_attempts",
    "private.stripe_job_disputes",
    "private.stripe_payout_events",
  ]) assertQa(source.includes(required), \`financial history v2 missing \${required}\`);
  for (const forbidden of [
    "provider_payment_intent_id","provider_customer_id","provider_account_id",
    "provider_dispute_id","provider_payout_id",
  ]) assertQa(!source.includes(forbidden), \`financial history v2 leaks \${forbidden}\`);
});

const edge = await readFile(path.join(root,"supabase","functions","stripe-list-financial-history","index.ts"),"utf8");
const shared = await readFile(path.join(root,"supabase","functions","_shared","stripe_financial_reads.ts"),"utf8");
assertQa(edge.includes('"get_my_financial_history_v2"'), "history Edge function is not on v2");
assertQa(edge.includes("p_cursor_at") && edge.includes("p_cursor_id"), "history Edge function does not forward tuple cursor");
assertQa(shared.includes("encodeFinancialHistoryCursor"), "opaque history cursor encoding is missing");
assertQa(shared.includes("decodeFinancialHistoryCursor"), "opaque history cursor decoding is missing");
assertQa(shared.includes("rawLimit > 50"), "history page cap is not enforced at Edge");
assertQa(shared.includes("minimizeHistoryEvent"), "history event DTO minimization is missing");
qaLog("stripe-financial-history",
  "history v2 is caller-bound, stable-paginated, capped at 50, comprehensive, and exposes opaque minimized cursors");
