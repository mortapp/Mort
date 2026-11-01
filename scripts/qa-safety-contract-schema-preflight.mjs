import { execFileSync } from "node:child_process";

const target = process.env.MORT_QA_TARGET;
const databaseUrl = process.env.SUPABASE_DB_URL;
const confirmation = process.env.MORT_QA_SCHEMA_PREFLIGHT_CONFIRM;

if (!['local', 'staging'].includes(target)) {
  throw new Error('Set MORT_QA_TARGET=local or MORT_QA_TARGET=staging. Production is refused.');
}
if (confirmation !== 'ISOLATED_SCHEMA_ONLY') {
  throw new Error('Set MORT_QA_SCHEMA_PREFLIGHT_CONFIRM=ISOLATED_SCHEMA_ONLY.');
}
if (!databaseUrl) throw new Error('SUPABASE_DB_URL is required.');
if (/jxbnrkasktbhtiujkhay|rakjydmgwwgtdislanbt|supabase\.co/i.test(databaseUrl)) {
  throw new Error('Refusing to run the schema preflight against the production or deleted project.');
}
if (!/localhost|127\.0\.0\.1|::1|staging|qa|test/i.test(databaseUrl)) {
  throw new Error('Database URL must identify localhost or an explicitly named QA/staging target.');
}

const sqlFile = new URL('../supabase/tests/safety_contract_schema_preflight.sql', import.meta.url);
const output = execFileSync('psql', [databaseUrl, '-X', '-v', 'ON_ERROR_STOP=1', '-f', sqlFile.pathname], {
  encoding: 'utf8',
  stdio: ['ignore', 'pipe', 'pipe'],
});

if (!output.includes('safety-contract schema preflight: PASS')) {
  throw new Error('Schema preflight did not report PASS.');
}
console.log('[qa-safety-contract-schema-preflight] PASS');
