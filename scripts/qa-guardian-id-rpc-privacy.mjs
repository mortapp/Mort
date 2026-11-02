#!/usr/bin/env node
/**
 * Isolated integration regression for public.get_my_job_applications(uuid).
 *
 * Requires synthetic, pre-created isolated-project accounts and one application:
 *   QA_SUPABASE_URL
 *   QA_SUPABASE_ANON_KEY
 *   QA_SUPABASE_SERVICE_ROLE_KEY (kept server-side; never printed)
 *   QA_APPLICATION_ID
 *   QA_GUARDIAN_ID
 *   QA_APPLICANT_EMAIL / QA_APPLICANT_PASSWORD
 *   QA_POSTER_EMAIL / QA_POSTER_PASSWORD
 *   QA_UNRELATED_EMAIL / QA_UNRELATED_PASSWORD
 *   QA_CONNECTED_GUARDIAN_EMAIL / QA_CONNECTED_GUARDIAN_PASSWORD
 *   QA_REVOKED_GUARDIAN_EMAIL / QA_REVOKED_GUARDIAN_PASSWORD
 *   QA_ADMIN_EMAIL / QA_ADMIN_PASSWORD
 *
 * Run only against ckcxakhxqlkhppsxxjhv. The admin assertion below checks that
 * this user-scoped RPC does not grant cross-user access; the service-role check
 * preserves the existing authorized server-side administrative data path.
 */
import assert from 'node:assert/strict';
import { createClient } from '@supabase/supabase-js';

const projectUrl = process.env.QA_SUPABASE_URL;
const anonKey = process.env.QA_SUPABASE_ANON_KEY;
const serviceRoleKey = process.env.QA_SUPABASE_SERVICE_ROLE_KEY;
const applicationId = process.env.QA_APPLICATION_ID;
const guardianId = process.env.QA_GUARDIAN_ID;
const required = [
  'QA_SUPABASE_URL', 'QA_SUPABASE_ANON_KEY', 'QA_SUPABASE_SERVICE_ROLE_KEY',
  'QA_APPLICATION_ID', 'QA_GUARDIAN_ID',
  'QA_APPLICANT_EMAIL', 'QA_APPLICANT_PASSWORD',
  'QA_POSTER_EMAIL', 'QA_POSTER_PASSWORD',
  'QA_UNRELATED_EMAIL', 'QA_UNRELATED_PASSWORD',
  'QA_CONNECTED_GUARDIAN_EMAIL', 'QA_CONNECTED_GUARDIAN_PASSWORD',
  'QA_REVOKED_GUARDIAN_EMAIL', 'QA_REVOKED_GUARDIAN_PASSWORD',
  'QA_ADMIN_EMAIL', 'QA_ADMIN_PASSWORD',
];
const missing = required.filter((name) => !process.env[name]);
assert.deepEqual(missing, [], `Missing QA-only environment variables: ${missing.join(', ')}`);
assert.match(projectUrl, /^https:\/\/[a-z0-9]+\.supabase\.co$/i);
assert.match(projectUrl, /ckcxakhxqlkhppsxxjhv/i, 'Refusing to run outside the isolated QA project');
assert.notMatch(projectUrl, /jxbnrkasktbhtiujkhay|rakjydmgwwgtdislanbt/i, 'Production/deleted project is prohibited');

const baseClient = () => createClient(projectUrl, anonKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});
const service = createClient(projectUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

async function signedIn(name) {
  const client = baseClient();
  const { data, error } = await client.auth.signInWithPassword({
    email: process.env[`QA_${name}_EMAIL`],
    password: process.env[`QA_${name}_PASSWORD`],
  });
  assert.ifError(error);
  assert.ok(data.session?.access_token, `${name} did not receive a session`);
  return client;
}

async function readApplication(client, id = applicationId) {
  const { data, error } = await client.rpc('get_my_job_applications', {
    p_application_id: id,
  });
  assert.ifError(error);
  assert.equal(data?.ok, true, 'application reader did not return success');
  return data.items.find((item) => item.id === applicationId) ?? null;
}

const results = [];
const applicant = await signedIn('APPLICANT');
const own = await readApplication(applicant);
assert.ok(own, 'applicant must retrieve their own application');
assert.equal(own.guardian_id, guardianId, 'applicant must retain their own Guardian identifier');
results.push('applicant: own application and Guardian identifier visible');

const poster = await signedIn('POSTER');
const posterRow = await readApplication(poster);
assert.ok(posterRow, 'poster must retrieve the authorized application');
assert.equal(posterRow.guardian_id, null, 'poster must not retrieve Guardian identifier');
results.push('poster: authorized application visible, Guardian identifier masked');

const { data: statusUpdate, error: statusError } = await poster.rpc(
  'update_my_job_application_status',
  {
    p_application_id: applicationId,
    p_action: 'viewed',
    p_expected_updated_at: null,
  },
);
assert.ifError(statusError);
assert.equal(statusUpdate?.ok, true, 'poster status RPC should return the authorized update');
assert.equal(
  statusUpdate?.application?.guardian_id,
  null,
  'nested status RPC response must also mask the Guardian identifier',
);
results.push('poster: nested status RPC response masks Guardian identifier');

const unrelated = await signedIn('UNRELATED');
assert.equal(await readApplication(unrelated), null, 'unrelated user must not retrieve application');
results.push('unrelated authenticated user: application absent');

const connectedGuardian = await signedIn('CONNECTED_GUARDIAN');
const connectedRow = await readApplication(connectedGuardian);
assert.ok(connectedRow, 'currently connected Guardian must retrieve the authorized application');
assert.equal(connectedRow.guardian_id, guardianId, 'connected Guardian must retain authorized identifier');
results.push('connected Guardian: authorized application and identifier visible');

const revokedGuardian = await signedIn('REVOKED_GUARDIAN');
assert.equal(await readApplication(revokedGuardian), null, 'revoked Guardian must not retrieve application');
results.push('revoked Guardian: application absent');

const admin = await signedIn('ADMIN');
assert.equal(await readApplication(admin), null, 'user-scoped RPC must not grant admin cross-user access');
results.push('admin: scoped RPC does not grant cross-user access');

const anonymous = baseClient();
const { data: anonData, error: anonError } = await anonymous.rpc('get_my_job_applications', {
  p_application_id: applicationId,
});
assert.ok(anonError || anonData?.ok === false, 'anonymous request must be denied');
results.push('anonymous: RPC denied');

const { data: directRows, error: directError } = await poster
  .from('job_applications')
  .select('id,guardian_id')
  .eq('id', applicationId);
assert.ok(directError || !directRows?.length, 'poster must not read the application table directly');
results.push('poster: direct table read denied or returns no rows');

const { data: serviceRows, error: serviceError } = await service
  .from('job_applications')
  .select('id,guardian_id')
  .eq('id', applicationId);
assert.ifError(serviceError);
assert.equal(serviceRows?.[0]?.guardian_id, guardianId, 'existing server-side privileged access remains');
results.push('service role: existing server-side application read preserved');

for (const result of results) console.log(`PASS ${result}`);
console.log(`Guardian RPC privacy matrix passed: ${results.length} assertions`);
