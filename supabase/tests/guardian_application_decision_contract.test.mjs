import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const migration = await readFile(
  new URL('../migrations/20261102010300_guardian_application_decision_contract.sql', import.meta.url),
  'utf8',
);

test('Guardian decisions are a separate application state and are not inferred from a Guardian link', () => {
  assert.match(migration, /guardian_decision_status text not null default 'not_required'/i);
  assert.match(migration, /guardian_decision_status.*'pending'.*'approved'.*'rejected'/is);
  assert.match(migration, /optional_job_approval_enabled/i);
  assert.match(migration, /guardian_approval_required/i);
});

test('submission records a pending decision when the job or linked Guardian preference requires it', () => {
  assert.match(migration, /case[\s\S]*guardian_approval_required[\s\S]*then 'pending'[\s\S]*else 'not_required'/i);
  assert.match(migration, /guardian_submission_insert_patch_failed/i);
  assert.match(migration, /guardian_decision_status', v_application\.guardian_decision_status/i);
});

test('only an active, adult, email-confirmed, dual-consented Guardian can decide', () => {
  const start = migration.indexOf('create or replace function public.guardian_decide_job_application');
  const end = migration.indexOf('$function$;', start);
  const rpc = migration.slice(start, end);
  assert.match(rpc, /gl\.status='active'/i);
  assert.match(rpc, /gl\.teen_consent_at is not null/i);
  assert.match(rpc, /gl\.guardian_consent_at is not null/i);
  assert.match(rpc, /guardian_profile\.role='guardian'/i);
  assert.match(rpc, /extract\(year from age\(v_now::date,guardian_profile\.date_of_birth\)\)>=18/i);
  assert.match(rpc, /guardian_auth\.email_confirmed_at is not null/i);
  assert.match(rpc, /for share of gl,guardian_profile,guardian_auth/i);
});

test('pending or rejected applications are hidden from posters and cannot be accepted', () => {
  assert.match(migration, /guardian_decision_status='approved'/i);
  assert.match(migration, /guardian_decision_status <> 'approved'/i);
  assert.match(migration, /drop policy if exists applications_select_parties/i);
  assert.match(migration, /guardian_decision_status='pending'/i);
});

test('Guardian revocation invalidates prior approval and forces a new decision', () => {
  assert.match(migration, /reset_guardian_application_decisions_on_revocation/i);
  assert.match(migration, /guardian_decision_status='pending'/i);
  assert.match(migration, /guardian_decided_by=null/i);
  assert.match(migration, /guardian link was revoked; prior decision invalidated/i);
});

test('Guardian decision RPC is authenticated-only and uses optimistic concurrency', () => {
  assert.match(migration, /revoke all on function public\.guardian_decide_job_application[\s\S]*from public,anon,authenticated/i);
  assert.match(migration, /grant execute on function public\.guardian_decide_job_application[\s\S]*to authenticated/i);
  assert.match(migration, /p_expected_updated_at is null/i);
  assert.match(migration, /application_changed_refresh/i);
});
