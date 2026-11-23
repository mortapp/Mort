import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const migrationPath = path.resolve(
  import.meta.dirname,
  '../../supabase/migrations/20261122133500_harden_staff_role_active_status.sql',
);
const migration = fs.readFileSync(migrationPath, 'utf8');

function hasStaffRole({ uid, profile, assignedRoles, requiredRoles }) {
  if (!uid || !profile || profile.id !== uid) return false;
  if (profile.account_status !== 'active') return false;
  return assignedRoles.some((role) => requiredRoles.includes(role));
}

const activeStaff = {
  id: 'staff-1',
  account_status: 'active',
};

for (const [name, input, expected] of [
  ['active staff with requested role',
    { uid: 'staff-1', profile: activeStaff, assignedRoles: ['moderator'], requiredRoles: ['admin', 'moderator'] }, true],
  ['suspended staff',
    { uid: 'staff-1', profile: { ...activeStaff, account_status: 'suspended' }, assignedRoles: ['moderator'], requiredRoles: ['moderator'] }, false],
  ['inactive staff',
    { uid: 'staff-1', profile: { ...activeStaff, account_status: 'inactive' }, assignedRoles: ['moderator'], requiredRoles: ['moderator'] }, false],
  ['pending staff',
    { uid: 'staff-1', profile: { ...activeStaff, account_status: 'pending' }, assignedRoles: ['moderator'], requiredRoles: ['moderator'] }, false],
  ['revoked role',
    { uid: 'staff-1', profile: activeStaff, assignedRoles: [], requiredRoles: ['moderator'] }, false],
  ['role changed away from requested role',
    { uid: 'staff-1', profile: activeStaff, assignedRoles: ['admin'], requiredRoles: ['moderator'] }, false],
  ['unauthenticated caller',
    { uid: null, profile: activeStaff, assignedRoles: ['admin'], requiredRoles: ['admin'] }, false],
  ['profile for a different caller',
    { uid: 'staff-2', profile: activeStaff, assignedRoles: ['admin'], requiredRoles: ['admin'] }, false],
]) {
  test(`staff authorization: ${name}`, () => {
    assert.equal(hasStaffRole(input), expected);
  });
}

test('migration checks the actual profile state and preserves the policy grant', () => {
  assert.match(migration, /join public\.profiles profile on profile\.id = ur\.user_id/);
  assert.match(migration, /\(select auth\.uid\(\)\) is not null/);
  assert.match(migration, /ur\.user_id = \(select auth\.uid\(\)\)/);
  assert.match(migration, /ur\.role = any\(required_roles\)/);
  assert.match(migration, /profile\.account_status = 'active'/);
  assert.doesNotMatch(migration, /blocked_until/);
  assert.match(migration, /set search_path = ''/);
  assert.match(migration, /revoke all on function private\.has_staff_role\(public\.mort_role\[\]\) from public, anon;/);
  assert.match(migration, /grant execute on function private\.has_staff_role\(public\.mort_role\[\]\) to authenticated;/);
});
