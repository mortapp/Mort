import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";

import pg from "npm:pg@8.22.0";

import {
  supportBenignEvaluationCases,
  supportContrastCases,
  supportEvaluationCases,
} from "../supabase/functions/_shared/support_eval_cases.ts";
import { localClassification } from "../supabase/functions/_shared/support_runtime.ts";

const projectRef = "rakjydmgwwgtdislanbt";
const dbPassword = Deno.env.get("SUPABASE_DB_PASSWORD");
const remoteOnly = Deno.args.includes("--remote");
const migrationPaths = Deno.args
  .filter((path) => path !== "--remote")
  .map((path) => resolve(path));
const cases = [
  ...supportEvaluationCases,
  ...supportContrastCases,
  ...supportBenignEvaluationCases,
];

if (!dbPassword) throw new Error("SUPABASE_DB_PASSWORD is required.");
if (!remoteOnly && !migrationPaths.length) {
  throw new Error(
    "Usage: deno run <permissions> scripts/qa-support-sql-ts-parity.mjs (--remote | <migration.sql> [...])",
  );
}

const client = new pg.Client({
  host: `db.${projectRef}.supabase.co`,
  port: 5432,
  database: "postgres",
  user: "postgres",
  password: dbPassword,
  ssl: { rejectUnauthorized: false },
});

await client.connect();
try {
  await client.query("begin");
  for (const path of migrationPaths) {
    const sql = (await readFile(path, "utf8")).replace(/^\uFEFF/, "");
    try {
      await client.query(sql);
    } catch (error) {
      console.error(
        `MIGRATION_PARSE_FAILED=${path} CODE=${
          error?.code ?? "unknown"
        } POSITION=${error?.position ?? "unknown"}`,
      );
      throw error;
    }
  }

  const sqlResults = [];
  for (const testCase of cases) {
    const result = await client.query(
      "select private.support_classify_message($1::text) as classification",
      [testCase.message],
    );
    sqlResults.push(result.rows[0].classification);
  }

  let parityPassed = 0;
  let sqlExpectedPassed = 0;
  const failures = [];
  for (let index = 0; index < cases.length; index += 1) {
    const testCase = cases[index];
    const sql = sqlResults[index];
    const typescript = localClassification(testCase.message);
    const expected = {
      level: testCase.expectedLevel ??
        testCase.level ??
        testCase.expected?.level ??
        null,
      intent: testCase.expectedIntent ??
        testCase.intent ??
        testCase.expected?.intent ??
        null,
    };
    const sqlActual = {
      level: Number(sql.level),
      triage_band: sql.triage_band,
      category: sql.category,
      intent: sql.intent,
      action: sql.action,
      provider_allowed: sql.provider_allowed === true,
    };
    const typescriptActual = {
      level: Number(typescript.level),
      triage_band: typescript.triage_band,
      category: typescript.category,
      intent: typescript.intent,
      action: typescript.action,
      provider_allowed: typescript.provider_allowed === true,
    };
    const parity = Object.keys(sqlActual).every(
      (field) => sqlActual[field] === typescriptActual[field],
    );
    const sqlExpected = sqlActual.level === expected.level &&
      sqlActual.intent === expected.intent;
    if (parity) parityPassed += 1;
    if (sqlExpected) sqlExpectedPassed += 1;
    if (!parity || !sqlExpected) {
      failures.push({
        caseKey: testCase.caseKey,
        parity,
        sqlExpected,
        expected,
        sql: sqlActual,
        typescript: typescriptActual,
      });
    }
  }

  const summary = {
    total: cases.length,
    parityPassed,
    parityFailed: cases.length - parityPassed,
    sqlExpectedPassed,
    sqlExpectedFailed: cases.length - sqlExpectedPassed,
  };
  console.log(`TOTAL=${summary.total}`);
  console.log(`SQL_TS_PARITY_PASSED=${summary.parityPassed}`);
  console.log(`SQL_TS_PARITY_FAILED=${summary.parityFailed}`);
  console.log(`SQL_EXPECTED_PASSED=${summary.sqlExpectedPassed}`);
  console.log(`SQL_EXPECTED_FAILED=${summary.sqlExpectedFailed}`);
  await writeFile(
    "C:/temp/qa_support_sql_ts_parity.json",
    JSON.stringify({ summary, failures }, null, 2),
  );
  if (summary.parityFailed > 0) Deno.exitCode = 1;
} finally {
  await client.query("rollback").catch(() => {});
  await client.end();
}
