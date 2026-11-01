import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const proposal = await readFile(
  new URL('../proposals/marketplace_application_submission_race.sql', import.meta.url),
  'utf8',
);

test('submission rechecks time-sensitive eligibility after all locks are acquired', () => {
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

