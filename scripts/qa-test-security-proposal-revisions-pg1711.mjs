#!/usr/bin/env node
import assert from 'node:assert/strict';
import { spawn, execFileSync } from 'node:child_process';
import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const allowedContainers = new Set([
  'mort-pg1711-reviewfresh-mort20261102',
  'mort-pg1711-finalreview-20261102',
]);
const containerArg = process.argv.indexOf('--container');
const container = containerArg >= 0
  ? process.argv[containerArg + 1]
  : 'mort-pg1711-reviewfresh-mort20261102';
assert.ok(allowedContainers.has(container), 'refusing any target except an explicitly named disposable local container');
const repoRoot = fileURLToPath(new URL('../', import.meta.url));
const proposalDir = join(repoRoot, 'supabase-production', 'proposals');
const testPath = join(proposalDir, 'tests', '20261102090600_fixture_free_proposal_contracts.sql');

function query(sql) {
  return execFileSync('docker', [
    'exec', container, 'psql', '-U', 'postgres', '-d', 'postgres', '-X', '-qAt',
    '-v', 'ON_ERROR_STOP=1', '-c', sql,
  ], { encoding: 'utf8' }).trim();
}

function functionSource(sql, marker) {
  const start = sql.indexOf(marker);
  assert.notEqual(start, -1, `missing ${marker}`);
  const endToken = '$function$;';
  const end = sql.indexOf(endToken, start);
  assert.notEqual(end, -1, `missing function end for ${marker}`);
  return Buffer.from(sql.slice(start, end + endToken.length), 'utf8');
}

function runSql(bytes) {
  return new Promise((resolve, reject) => {
    const child = spawn('docker', [
      'exec', '-i', container, 'psql', '-U', 'postgres', '-d', 'postgres', '-X',
      '-v', 'ON_ERROR_STOP=1',
    ], { stdio: ['pipe', 'inherit', 'inherit'], windowsHide: true });
    child.once('error', reject);
    child.once('close', (code) => code === 0
      ? resolve()
      : reject(new Error(`proposal revision test exited with code ${code}`)));
    child.stdin.end(bytes);
  });
}

assert.equal(query('show server_version_num'), '170011');
assert.equal(query("select count(*)||'|'||min(version)||'|'||max(version) from public.qa_production_migration_replay"), '73|20261026194801|20261102113314');
assert.equal(query('select count(*) from auth.users'), '0');
assert.equal(query('select count(*) from public.profiles'), '0');
assert.equal(query('select count(*) from private.verification_provider_allowlist'), '0');
assert.equal(query("select count(*) from public.mort_release_control where coalesce(public_marketplace_enabled,true) or coalesce(real_document_collection,true)"), '0');

const verificationSql = await readFile(join(proposalDir, '20261102090000_verification_evidence_gate.sql'), 'utf8');
const checkinSql = await readFile(join(proposalDir, '20261102090200_checkin_idempotency_lifecycle.sql'), 'utf8');
const verificationFunction = functionSource(verificationSql, 'CREATE OR REPLACE FUNCTION public.mort_review_verification_case(');
const scheduleFunction = functionSource(checkinSql, 'CREATE OR REPLACE FUNCTION public.schedule_active_job_checkin(');
const fixtureFreeTests = await readFile(testPath);
const before = query(`select md5(pg_get_functiondef('public.mort_review_verification_case(uuid,public.mort_verification_status,text,timestamp with time zone)'::regprocedure)) || '|' || md5(pg_get_functiondef('public.schedule_active_job_checkin(uuid,integer,uuid)'::regprocedure))`);

await runSql(Buffer.concat([
  Buffer.from('BEGIN;\n', 'utf8'),
  verificationFunction,
  Buffer.from('\n', 'utf8'),
  scheduleFunction,
  Buffer.from('\n', 'utf8'),
  fixtureFreeTests,
]));

const after = query(`select md5(pg_get_functiondef('public.mort_review_verification_case(uuid,public.mort_verification_status,text,timestamp with time zone)'::regprocedure)) || '|' || md5(pg_get_functiondef('public.schedule_active_job_checkin(uuid,integer,uuid)'::regprocedure))`);
assert.equal(after, before, 'test transaction must roll both proposal revisions back');
console.log('[qa-test-security-proposal-revisions-pg1711] PASS: revised proposal 900/902 definitions passed fixture-free pgTAP and rolled back');
