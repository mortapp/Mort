import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const proposal = await readFile(
  new URL('../proposals/marketplace_application_submission_race.sql', import.meta.url),
  'utf8',
);
const migration = await readFile(
  new URL('../migrations/20261102003713_atomic_application_and_guardian_resend_contract.sql', import.meta.url),
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
  assert.match(submitSql, /p_note text default null,\s*p_availability_confirmed boolean default false,\s*p_portfolio_ids uuid\[\] default '\{\}'::uuid\[\]/i,
    'replacement RPC must preserve all live parameter defaults and call compatibility');
  const lock = submitSql.indexOf('for update;');
  const eligibility = submitSql.indexOf('v_eligibility := public.get_job_application_eligibility');

  assert.ok(submitStart >= 0, 'deployable submission RPC must exist');
  assert.ok(lock >= 0 && lock < eligibility, 'submission must lock the job before eligibility');
  assert.match(submitSql, /coalesce\(v_eligibility->>'eligible',\s*'false'\)\s*<>\s*'true'/i,
    'a missing or null eligibility result must fail closed');
  assert.match(migration, /current_role\(\)\s+is distinct from\s+'teen'::public\.mort_role/i,
    'the lower-level insert must deny missing/null role state');
  assert.match(migration, /v_now\s*:=\s*clock_timestamp\(\)/i,
    'eligibility must capture a wall-clock snapshot at execution time');
  assert.match(migration, /v_job\.expires_at\s*<=\s*v_now/i,
    'eligibility must use the fresh wall-clock snapshot for expiry');
  assert.match(migration, /vc\.expires_at\s+is\s+null\s+or\s+vc\.expires_at\s*>\s*v_now/i,
    'age verification expiry must use the fresh wall-clock snapshot');
  assert.match(migration, /from public\.verification_cases verification[\s\S]*?for share/i,
    'age-verification rows must be locked before the fresh clock is captured');
  assert.match(migration, /age\(v_now::date,\s*v_profile\.date_of_birth\)/i,
    'applicant age must use the fresh wall-clock snapshot');
  assert.match(migration, /for share of gl, guardian_profile, guardian_auth/i,
    'dual-consented Guardian rows must be locked before eligibility is returned');
});

test('migration: eligibility captures time and serializes block checks after all decision locks', () => {
  const eligibilityStart = migration.indexOf(
    'create or replace function public.get_job_application_eligibility',
  );
  const eligibilityEnd = migration.indexOf(
    'create or replace function public.submit_job_application',
    eligibilityStart,
  );
  const eligibility = migration.slice(eligibilityStart, eligibilityEnd);
  const guardianLock = eligibility.indexOf('for share of gl, guardian_profile, guardian_auth');
  const verificationLock = eligibility.indexOf('for share', eligibility.indexOf('verification_cases'));
  const pairLock = eligibility.indexOf('pg_advisory_xact_lock');
  const blockCheck = eligibility.indexOf('from public.user_blocks');
  const freshClock = eligibility.indexOf('v_now := clock_timestamp()');

  assert.ok(guardianLock >= 0 && verificationLock >= 0,
    'Guardian and age verification evidence must be locked');
  assert.ok(pairLock >= 0 && blockCheck > pairLock,
    'application eligibility must serialize with block_user_v2 before reading block state');
  assert.ok(freshClock > guardianLock && freshClock > verificationLock && freshClock > pairLock,
    'clock must be captured after all mutable eligibility rows/pair locks are acquired');
  assert.match(eligibility, /poster[\s\S]*?for share/i,
    'poster active-account state must remain stable through eligibility evaluation');
});
