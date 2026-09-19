import { assertQa, qaLog, withDatabase } from "./feature-qa-helpers.mjs";

const lockedTables = [
  "stripe_job_settlements",
  "stripe_financial_ledger_events",
  "stripe_tip_attempts",
  "stripe_tip_transfers",
  "financial_document_sequences",
  "financial_documents",
];

await withDatabase(async (database) => {
  const tableResult = await database.query(
    `
      select c.relname,
             c.relrowsecurity,
             c.relforcerowsecurity
        from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
       where n.nspname = 'private'
         and c.relname = any($1::text[])
       order by c.relname
    `,
    [lockedTables],
  );
  assertQa(
    tableResult.rows.length === lockedTables.length,
    "one or more hardened Stripe financial tables are missing",
  );
  for (const row of tableResult.rows) {
    assertQa(row.relrowsecurity === true, `${row.relname} must have RLS enabled`);
    assertQa(row.relforcerowsecurity === true, `${row.relname} must force RLS`);
  }

  const grants = await database.query(
    `
      select table_name, grantee, privilege_type
        from information_schema.role_table_grants
       where table_schema = 'private'
         and table_name = any($1::text[])
         and grantee in ('PUBLIC', 'anon', 'authenticated')
    `,
    [lockedTables],
  );
  assertQa(
    grants.rowCount === 0,
    "anon/authenticated/PUBLIC retain direct access to hardened financial tables",
  );

  const serviceFunctions = await database.query(`
    select p.oid,
           n.nspname,
           p.proname,
           has_function_privilege('anon', p.oid, 'EXECUTE') as anon_execute,
           has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated_execute
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.proname like 'stripe_server_%'
  `);
  assertQa(serviceFunctions.rowCount > 0, "service-only Stripe RPC inventory is empty");
  for (const fn of serviceFunctions.rows) {
    assertQa(fn.anon_execute === false, `${fn.proname} is executable by anon`);
    assertQa(
      fn.authenticated_execute === false,
      `${fn.proname} is executable by authenticated clients`,
    );
  }

  const documentReads = await database.query(`
    select p.proname,
           has_function_privilege('anon', p.oid, 'EXECUTE') as anon_execute,
           has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated_execute,
           pg_get_functiondef(p.oid) as definition
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.proname in (
         'get_my_financial_document_v1',
         'get_my_financial_history_v1',
         'get_my_job_financial_document_v1',
         'get_my_job_settlement_v1',
         'get_my_tip_attempt_state_v1'
       )
  `);
  assertQa(documentReads.rowCount >= 5, "caller-bound financial read RPC inventory is incomplete");
  for (const fn of documentReads.rows) {
    assertQa(fn.anon_execute === false, `${fn.proname} must reject anon execution`);
    assertQa(fn.authenticated_execute === true, `${fn.proname} must be available to authenticated callers`);
    const definition = String(fn.definition ?? "");
    assertQa(
      definition.includes("auth.uid()") || definition.includes("owner_id = auth.uid()"),
      `${fn.proname} does not bind access to the authenticated caller`,
    );
  }
});

qaLog(
  "stripe-financial-access",
  "new Stripe financial tables force RLS, client table grants are absent, service mutations are non-client, and read RPCs stay caller-bound",
);
