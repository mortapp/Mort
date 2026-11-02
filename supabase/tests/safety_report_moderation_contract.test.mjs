import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const migration = await readFile(
  new URL('../migrations/20261102010200_safety_report_moderation_rpc.sql', import.meta.url),
  'utf8',
);

test('safety report moderation is staff-only and fails closed for unauthenticated callers', () => {
  assert.match(migration, /private\.has_staff_role\(array\['admin','moderator'\]/i);
  assert.match(migration, /actor\.account_status = 'active'/i);
  assert.match(migration, /p_action is null/i);
  assert.match(migration, /p_expected_updated_at is null/i);
  assert.match(migration, /safety_report_changed_refresh/i);
});

test('moderation state transitions are allowlisted and preserve terminal-state controls', () => {
  assert.match(migration, /p_action not in \('triage','investigate','resolve','dismiss','reopen','assign','unassign'\)/i);
  assert.match(migration, /v_report\.status not in \('open','triaged','investigating'\)/i);
  assert.match(migration, /v_report\.status not in \('resolved','dismissed'\)/i);
  assert.match(migration, /v_new_status := 'dismissed'/i);
  assert.match(migration, /v_new_status := 'resolved'/i);
});

test('assignments are restricted to active MORT staff and decisions are audited', () => {
  assert.match(migration, /join private\.user_roles staff_role/i);
  assert.match(migration, /assignee\.account_status = 'active'/i);
  assert.match(migration, /staff_role\.role in \('admin'::public\.mort_role, 'moderator'::public\.mort_role\)/i);
  assert.match(migration, /insert into public\.admin_audit_log/i);
  assert.match(migration, /'safety_report_' \|\| p_action/i);
});

test('only authenticated users can execute the moderation RPC', () => {
  assert.match(migration, /revoke all on function public\.mort_review_safety_report[\s\S]*from public, anon, authenticated/i);
  assert.match(migration, /grant execute on function public\.mort_review_safety_report[\s\S]*to authenticated/i);
});
