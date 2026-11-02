import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const migration = await readFile(
  new URL('../migrations/20261102003713_atomic_application_and_guardian_resend_contract.sql', import.meta.url),
  'utf8',
);
const resend = migration.split('create or replace function public.resend_guardian_invite')[1]
  .split('$$;')[0];

test('Guardian resend serializes the teen rate check before rotating one pending link', () => {
  const lock = resend.indexOf('perform pg_catalog.pg_advisory_xact_lock(v_rate_key)');
  const lookup = resend.indexOf('where link.id = p_link_id');
  const count = resend.indexOf('select count(*) into v_invite_count');
  const consume = resend.indexOf('where guardian_link_id = p_link_id and consumed_at is null');

  assert.ok(lock >= 0 && lookup >= 0 && count >= 0, 'resend must have rate lock, link lock, and rate count');
  assert.ok(lock < lookup && lookup < count, 'rate and selected-link locks must precede the rate count');
  assert.ok(consume > count, 'only the selected link code may be consumed after the rate check');
  assert.match(resend, /guardian_invite_code_missing/, 'missing selected code must fail closed');
  assert.match(resend, /current_role\(\)\s+is distinct from\s+'teen'::public\.mort_role/i,
    'missing/null role state must not pass the teen role gate');
  assert.doesNotMatch(resend, /update public\.guardian_links\s+set status\s*=\s*['"]revoked['"]/i,
    'resend must not revoke unrelated pending links');
});
