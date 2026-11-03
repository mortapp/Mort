#!/usr/bin/env node
import assert from 'node:assert/strict';
import { spawn, execFileSync } from 'node:child_process';
import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const container = 'mort-pg1711-reviewfresh-mort20261102';
const repoRoot = fileURLToPath(new URL('../', import.meta.url));
const proposalsDir = join(repoRoot, 'supabase-production', 'proposals');
const proposals = [
  '20261102090000_verification_evidence_gate.sql',
  '20261102090100_application_pair_lock_and_verification.sql',
  '20261102090200_checkin_idempotency_lifecycle.sql',
];

function query(sql) {
  return execFileSync('docker', ['exec', container, 'psql', '-U', 'postgres', '-d', 'postgres', '-At', '-v', 'ON_ERROR_STOP=1', '-c', sql], { encoding: 'utf8' }).trim();
}

function apply(bytes) {
  return new Promise((resolve, reject) => {
    const child = spawn('docker', ['exec', '-i', container, 'psql', '-U', 'postgres', '-d', 'postgres', '-v', 'ON_ERROR_STOP=1'], { stdio: ['pipe', 'inherit', 'inherit'], windowsHide: true });
    child.once('error', reject);
    child.once('close', (code) => code === 0 ? resolve() : reject(new Error(`proposal compile psql exited ${code}`)));
    child.stdin.end(bytes);
  });
}

assert.equal(query('show server_version_num'), '170011');
assert.equal(query("select count(*)||'|'||min(version)||'|'||max(version) from public.qa_production_migration_replay"), '73|20261026194801|20261102113314');
assert.equal(query("select count(*) from public.qa_production_migration_replay where source_sha256 !~ '^[0-9a-f]{64}$'"), '0');
assert.equal(query("select count(*) from public.profiles"), '0', 'do not use real or synthetic account fixtures in this fixture-free compile run');
assert.equal(query("select count(*) from auth.users"), '0', 'do not use Auth fixtures in this fixture-free compile run');

const alreadyCompiled = query(`SELECT (
  to_regclass('private.verification_provider_allowlist') IS NOT NULL
  AND to_regclass('public.job_safety_checkins_teen_completion_request_uidx') IS NOT NULL
  AND position('provider_result_id' in pg_get_functiondef('public.mort_review_verification_case(uuid,public.mort_verification_status,text,timestamp with time zone)'::regprocedure)) > 0
  AND position('school_id_verification_required' in pg_get_functiondef('public.get_job_application_eligibility(uuid)'::regprocedure)) > 0
  AND position('checkin.completion_request_id is not null' in pg_get_functiondef('public.complete_active_job_checkin(uuid,uuid)'::regprocedure)) > 0
)::text`);
if (alreadyCompiled === 'true') {
  assert.equal(query("select count(*) from private.verification_provider_allowlist"), '0', 'provider allowlist must remain empty');
  assert.equal(query("select count(*) from public.mort_release_control where coalesce(public_marketplace_enabled,true) or coalesce(real_document_collection,true)"), '0', 'local release controls must remain disabled');
  console.log('SECURITY_PROPOSAL_COMPILE=PASS proposals=3 already_compiled=true providers=0 marketplace=disabled real_document_collection=disabled');
  process.exit(0);
}
assert.equal(query("select to_regclass('private.verification_provider_allowlist') is null and to_regclass('public.job_safety_checkins_teen_completion_request_uidx') is null"), 't', 'partial proposal artifacts exist; use a new clean baseline');

const releaseFlags = query('SELECT coalesce(public_marketplace_enabled,true)::text||\'|\'||coalesce(real_document_collection,true)::text FROM public.mort_release_control WHERE is_primary');
assert.equal(releaseFlags, 'true|false', 'expected migration replay to contain its historical marketplace activation before local test override');
query("UPDATE public.mort_release_control SET public_marketplace_enabled=false, real_document_collection=false WHERE is_primary");
assert.equal(query("select count(*) from public.mort_release_control where coalesce(public_marketplace_enabled,true) or coalesce(real_document_collection,true)"), '0', 'local test-only release flags must remain disabled');

for (const proposal of proposals) {
  console.log(`COMPILE ${proposal}`);
  await apply(await readFile(join(proposalsDir, proposal)));
  console.log(`COMPILE_PASS ${proposal}`);
}

assert.equal(query("select count(*) from private.verification_provider_allowlist"), '0', 'provider allowlist must remain empty');
assert.equal(query("select count(*) from public.mort_release_control where coalesce(public_marketplace_enabled,true) or coalesce(real_document_collection,true)"), '0', 'local release controls must remain disabled');
console.log('SECURITY_PROPOSAL_COMPILE=PASS proposals=3 providers=0 marketplace=disabled real_document_collection=disabled local_override=true');
