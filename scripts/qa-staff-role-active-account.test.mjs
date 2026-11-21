import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

const migration = readFileSync(
  new URL('../supabase/migrations/20261121151941_staff_role_requires_active_account.sql', import.meta.url),
  'utf8',
);
const root = new URL('..', import.meta.url).pathname;
function collectSqlFiles(directory) {
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) return collectSqlFiles(path);
    return entry.isFile() && path.endsWith('.sql') ? [path] : [];
  });
}
const sourceFiles = [
  ...collectSqlFiles(join(root, 'supabase/migrations')),
  ...collectSqlFiles(join(root, 'supabase/production-baseline-migrations')),
  ...collectSqlFiles(join(root, 'supabase/production-baseline-recovery')),
];
const sqlSources = sourceFiles.map((path) => readFileSync(path, 'utf8'));
const baseline = sqlSources.join('\n');

const expectedGatedFunctions = [
  'admin_review_team_hustle_v1',
  'admin_set_account_status_v2',
  'close_team_hustle_v1',
  'create_team_hustle_v1',
  'list_message_moderation_queue',
  'list_team_hustles_v1',
  'mort_admin_list_users_v1',
  'mort_moderate_message',
  'mort_record_staff_document_review',
  'mort_review_job',
  'mort_review_role_request',
  'mort_review_verification_case',
  'mort_set_guardian_pause_v1',
  'can_access_application_status_events',
  'can_access_assignment',
  'can_access_job_status_events',
];

function functionBodies(source, name) {
  const escaped = name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const declaration = new RegExp('CREATE(?: OR REPLACE)? FUNCTION\\s+(?:public|private)\\.' + escaped + '\\s*\\(', 'gi');
  const bodies = [];
  for (const match of source.matchAll(declaration)) {
    const asMatch = /\bAS\s+(\$[A-Za-z0-9_]*\$)/ig;
    asMatch.lastIndex = match.index;
    const delimiterMatch = asMatch.exec(source);
    if (!delimiterMatch) continue;
    const delimiter = delimiterMatch[1];
    const bodyStart = delimiterMatch.index + delimiterMatch[0].length;
    const bodyEnd = source.indexOf(delimiter, bodyStart);
    if (bodyEnd !== -1) bodies.push(source.slice(bodyStart, bodyEnd));
  }
  return bodies;
}

// Migration contract: preserve caller identity, role matching, and hardening;
// additionally require a matching active profile (missing profile fails closed).
assert.match(migration, /create or replace function private\.has_staff_role\(required_roles public\.mort_role\[\]\)/i);
assert.match(migration, /security definer/i);
assert.match(migration, /stable/i);
assert.match(migration, /set search_path\s*=\s*''/i);
assert.match(migration, /ur\.user_id\s*=\s*\(select auth\.uid\(\)\)/i);
assert.match(migration, /ur\.role\s*=\s*any\(required_roles\)/i);
assert.match(migration, /join public\.profiles p on p\.id = ur\.user_id/i);
assert.match(migration, /p\.account_status\s*=\s*'active'/i);
assert.doesNotMatch(migration, /grant\s+|revoke\s+/i, 'migration must not alter existing function ACLs');

// Inventory contract: every QA-confirmed dependent function continues to call
// the centralized helper, so the helper change covers every affected path.
for (const name of expectedGatedFunctions) {
  assert.ok(functionBodies(baseline, name).some((body) => /private\.has_staff_role\s*\(/i.test(body)), `${name} still delegates staff authorization to the helper`);
}

// Both affected RLS policies must remain helper-gated.
for (const policy of ['guardian_links_select_participants_or_staff', 'profiles_select_self_or_staff']) {
  const escaped = policy.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const re = new RegExp('CREATE POLICY ' + escaped + '[\\s\\S]*?;', 'i');
  const match = baseline.match(re);
  assert.ok(match, `baseline contains ${policy}`);
  assert.match(match[0], /private\.has_staff_role\s*\(/i, `${policy} retains centralized staff authorization`);
}

// Decision-model cases are a deterministic unit oracle for the intended rule.
function hasStaffRole({ userId, roleRows, profile }) {
  return Boolean(
    userId &&
    profile &&
    profile.id === userId &&
    profile.account_status === 'active' &&
    roleRows.some((row) => row.user_id === userId && ['admin', 'moderator'].includes(row.role)),
  );
}
const userId = '10000000-0000-4000-8000-000000000001';
const roleRows = [{ user_id: userId, role: 'admin' }];
assert.equal(hasStaffRole({ userId, roleRows, profile: { id: userId, account_status: 'active' } }), true, 'active staff retains access');
for (const account_status of ['suspended', 'banned', 'disabled', 'deleted', null]) {
  assert.equal(hasStaffRole({ userId, roleRows, profile: { id: userId, account_status } }), false, `${account_status} staff is denied`);
}
assert.equal(hasStaffRole({ userId: null, roleRows, profile: { id: userId, account_status: 'active' } }), false, 'anonymous caller is denied');
assert.equal(hasStaffRole({ userId, roleRows: [], profile: { id: userId, account_status: 'active' } }), false, 'non-staff active account is denied');
assert.equal(hasStaffRole({ userId, roleRows, profile: null }), false, 'missing profile fails closed');
assert.equal(hasStaffRole({ userId, roleRows: [{ user_id: 'other', role: 'admin' }], profile: { id: userId, account_status: 'active' } }), false, 'another user staff row does not grant access');

console.log(`PASS: migration contract; ${expectedGatedFunctions.length} dependent functions; 2 RLS policy contracts; 10 decision-model cases.`);
