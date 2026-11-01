import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const proposal = await readFile(
  new URL('../proposals/marketplace_application_submission_race.sql', import.meta.url),
  'utf8',
);
const migration = await readFile(
  new URL('../migrations/20261101120000_atomic_application_and_guardian_resend_contract.sql', import.meta.url),
  'utf8',
);

test('proposal: submission rechecks time-sensitive eligibility after all locks are acquired', () => {
  const lock = proposal.indexOf('for update;');
  const eligibility = proposal.indexOf('v_eligibility := public.get_job_application_eligibility');
  const wallClock = proposal.indexOf('clock_timestamp()', lock);

  assert.ok(lock >= 0, 'job row lock must remain');
  assert.ok(wallClock > lock && wallClock < eligibility,
    'capture wall clock after the job lock and before eligibility checks');
  assert.match(proposal, /v_job\.expires_at\s*<=\s*v_now/i,
    'reject a job that expired while this transaction waited for locks');
  assert.match(proposal, /verification\.expires_at\s+is\s+null\s+or\s+verification\.expires_at\s*>\s*v_now[\s\S]*?for share/i,
    'lock an age-verification row that remains valid at wall-clock time');
  assert.match(proposal, /age\(v_today,\s*v_profile\.date_of_birth\)/i,
    'recalculate applicant age using the post-lock date');
  assert.match(proposal, /for share of gl, guardian_profile, guardian_auth/i,
    'lock the exact dual-consented Guardian records that authorize submission');
});

test('migration: submit wrapper locks the job and eligibility uses a fresh locked snapshot', () => {
  const submitStart = migration.indexOf('create or replace function public.submit_job_application');
  const submitSql = migration.slice(submitStart);
  const lock = submitSql.indexOf('for update;');
  const eligibility = submitSql.indexOf('v_eligibility := public.get_job_application_eligibility');

  assert.ok(submitStart >= 0, 'deployable submission RPC must exist');
  assert.ok(lock >= 0 && lock < eligibility, 'submission must lock the job before eligibility');
  assert.match(migration, /v_now\s+timestamptz\s*:=\s*clock_timestamp\(\)/i,
    'eligibility must capture a wall-clock snapshot at execution time');
  assert.match(migration, /v_job\.expires_at\s*<=\s*v_now/i,
    'eligibility must use the fresh wall-clock snapshot for expiry');
  assert.match(migration, /vc\.expires_at\s+is\s+null\s+or\s+vc\.expires_at\s*>\s*v_now/i,
    'age verification expiry must use the fresh wall-clock snapshot');
  assert.match(migration, /vc\.expires_at\s+is\s+null[\s\S]*?for share\s*\n\s*\)/i,
    'valid age-verification row must be locked during the eligibility decision');
  assert.match(migration, /age\(v_now::date,\s*v_profile\.date_of_birth\)/i,
    'applicant age must use the fresh wall-clock snapshot');
  assert.match(migration, /for share of gl, guardian_profile, guardian_auth/i,
    'dual-consented Guardian rows must be locked before eligibility is returned');
});
