import pg from "pg";

import { createSupabaseDirectClientConfig } from "./supabase-remote-tls.mjs";

const projectRef = "jxbnrkasktbhtiujkhay";
const runId = process.argv[2];
const password = process.env.SUPABASE_DB_PASSWORD;

if (!runId || !/^[0-9a-f-]{36}$/i.test(runId)) {
  throw new Error("Usage: node scripts/audit-support-evaluation.mjs <run-id>");
}
if (!password)
  throw new Error("SUPABASE_DB_PASSWORD is required and is never printed.");

// TLS verifies Supabase's root CA and the endpoint hostname; the database
// password is never sent over an unverified connection.
const database = new pg.Client(
  createSupabaseDirectClientConfig({ projectRef, password }),
);

await database.connect();
try {
  const result = await database.query(
    `select case_key, expected_outcome, actual_outcome
       from public.support_ai_evaluations
      where run_id = $1 and not passed
      order by case_key`,
    [runId],
  );
  console.log(JSON.stringify({ run_id: runId, failed: result.rows }, null, 2));
} finally {
  await database.end();
}
