import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const target = process.env.MORT_QA_TARGET;
const databaseUrl = process.env.SUPABASE_DB_URL;
const confirmation = process.env.MORT_QA_SCHEMA_PREFLIGHT_CONFIRM;
const allowedStagingRef = process.env.MORT_QA_ALLOWED_PROJECT_REF;

if (!['local', 'staging'].includes(target)) {
  throw new Error('Set MORT_QA_TARGET=local or MORT_QA_TARGET=staging. Production is refused.');
}
if (confirmation !== 'ISOLATED_SCHEMA_ONLY') {
  throw new Error('Set MORT_QA_SCHEMA_PREFLIGHT_CONFIRM=ISOLATED_SCHEMA_ONLY.');
}
if (!databaseUrl) throw new Error('SUPABASE_DB_URL is required.');
const parsedDatabaseUrl = new URL(databaseUrl);
if (!['postgres:', 'postgresql:'].includes(parsedDatabaseUrl.protocol)) {
  throw new Error('SUPABASE_DB_URL must use the PostgreSQL protocol.');
}
if (/jxbnrkasktbhtiujkhay|rakjydmgwwgtdislanbt/i.test(parsedDatabaseUrl.href)) {
  throw new Error('Refusing to run the schema preflight against the production or deleted project.');
}
const databaseHost = parsedDatabaseUrl.hostname.replace(/^\[|\]$/g, '');
const localHosts = new Set(['localhost', '127.0.0.1', '::1']);
if (target === 'local' && !localHosts.has(databaseHost)) {
  throw new Error('MORT_QA_TARGET=local requires a localhost database URL.');
}
if (target === 'staging') {
  if (!allowedStagingRef || /jxbnrkasktbhtiujkhay|rakjydmgwwgtdislanbt/i.test(allowedStagingRef)) {
    throw new Error('Set MORT_QA_ALLOWED_PROJECT_REF to the isolated staging project reference.');
  }
  const expectedHost = `db.${allowedStagingRef}.supabase.co`;
  if (databaseHost !== expectedHost) {
    throw new Error('Staging database host must match MORT_QA_ALLOWED_PROJECT_REF.');
  }
}

const sqlFile = fileURLToPath(new URL('../supabase/tests/safety_contract_schema_preflight.sql', import.meta.url));
const databaseName = decodeURIComponent(parsedDatabaseUrl.pathname.replace(/^\//, '')) || 'postgres';
const psqlEnvironment = { ...process.env };
if (parsedDatabaseUrl.password) psqlEnvironment.PGPASSWORD = decodeURIComponent(parsedDatabaseUrl.password);
const sslMode = parsedDatabaseUrl.searchParams.get('sslmode');
if (target === 'staging') psqlEnvironment.PGSSLMODE = 'require';
else if (sslMode) psqlEnvironment.PGSSLMODE = sslMode;
const output = execFileSync('psql', [
  '--host', databaseHost,
  '--port', parsedDatabaseUrl.port || '5432',
  '--username', decodeURIComponent(parsedDatabaseUrl.username),
  '--dbname', databaseName,
  '-X',
  '-v', 'ON_ERROR_STOP=1',
  '-f', sqlFile,
], {
  encoding: 'utf8',
  stdio: ['ignore', 'pipe', 'pipe'],
  env: psqlEnvironment,
});

if (!output.includes('safety-contract schema preflight: PASS')) {
  throw new Error('Schema preflight did not report PASS.');
}
console.log('[qa-safety-contract-schema-preflight] PASS');
