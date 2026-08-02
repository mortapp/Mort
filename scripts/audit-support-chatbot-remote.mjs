import pg from "pg";

const projectRef = "rakjydmgwwgtdislanbt";
const password = process.env.SUPABASE_DB_PASSWORD;
if (!password)
  throw new Error("SUPABASE_DB_PASSWORD is required and is never printed.");

const tables = [
  "support_conversations",
  "support_messages",
  "support_ticket_events",
  "support_attachments",
  "support_kb_documents",
  "support_kb_chunks",
  "support_ai_feedback",
  "support_ai_incidents",
  "support_ai_evaluations",
  "support_action_audit",
  "support_rate_limits",
  "support_global_rate_limits",
  "support_escalation_rules",
  "support_macros",
  "support_retention_jobs",
  "support_user_preferences",
];

const database = new pg.Client({
  host: `db.${projectRef}.supabase.co`,
  port: 5432,
  database: "postgres",
  user: "postgres",
  password,
  ssl: { rejectUnauthorized: false },
});

await database.connect();
try {
  const tableResult = await database.query(
    `select c.relname as table_name,
            c.relrowsecurity as rls_enabled,
            c.relforcerowsecurity as rls_forced
       from pg_class c
       join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public' and c.relname = any($1::text[])
      order by c.relname`,
    [tables],
  );
  const policyResult = await database.query(
    `select count(*)::integer as count
       from pg_policies
      where schemaname in ('public', 'storage')
        and (tablename like 'support_%'
          or (schemaname = 'storage' and policyname like 'storage_support_%'))`,
  );
  const functionResult = await database.query(
    `select count(*)::integer as count
       from pg_proc p
       join pg_namespace n on n.oid = p.pronamespace
      where n.nspname in ('public', 'private') and p.proname like 'support_%'`,
  );
  const knowledgeResult = await database.query(
    `select
       (select count(*)::integer from public.support_kb_documents where status = 'published') as documents,
       (select count(*)::integer from public.support_kb_chunks) as chunks`,
  );
  const evaluationResult = await database.query(
    `select run_id,
            count(*)::integer as total,
            count(*) filter (where passed)::integer as passed
       from public.support_ai_evaluations
      group by run_id
      order by max(created_at) desc
      limit 1`,
  );
  const bucketResult = await database.query(
    `select id, public, file_size_limit, allowed_mime_types
       from storage.buckets
      where id = 'support-attachments'`,
  );

  const missingTables = tables.filter(
    (table) => !tableResult.rows.some((row) => row.table_name === table),
  );
  const rlsFailures = tableResult.rows.filter(
    (row) => row.rls_enabled !== true || row.rls_forced !== true,
  );
  const report = {
    project_ref: projectRef,
    expected_tables: tables.length,
    found_tables: tableResult.rows.length,
    missing_tables: missingTables,
    rls_failures: rlsFailures,
    support_policy_count: policyResult.rows[0].count,
    support_database_function_count: functionResult.rows[0].count,
    knowledge: knowledgeResult.rows[0],
    latest_evaluation: evaluationResult.rows[0] ?? null,
    attachment_bucket: bucketResult.rows[0] ?? null,
  };
  console.log(JSON.stringify(report, null, 2));
  if (missingTables.length || rlsFailures.length || !report.attachment_bucket) {
    process.exitCode = 1;
  }
} finally {
  await database.end();
}
