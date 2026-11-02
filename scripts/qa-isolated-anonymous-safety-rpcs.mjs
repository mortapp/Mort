#!/usr/bin/env node
import assert from 'node:assert/strict';
import { createClient } from '@supabase/supabase-js';

const url = process.env.QA_SUPABASE_URL;
const anonKey = process.env.QA_SUPABASE_ANON_KEY;
assert.ok(url && anonKey, 'QA_SUPABASE_URL and QA_SUPABASE_ANON_KEY are required');
assert.match(url, /^https:\/\/ckcxakhxqlkhppsxxjhv\.supabase\.co$/i, 'refusing a non-isolated project URL');
assert.doesNotMatch(url, /jxbnrkasktbhtiujkhay|rakjydmgwwgtdislanbt/i, 'production/deleted project is prohibited');

const client = createClient(url, anonKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});
const fakeIds = {
  application: '00000000-0000-4000-8000-000000000001',
  job: '00000000-0000-4000-8000-000000000002',
  checkin: '00000000-0000-4000-8000-000000000003',
  request: '00000000-0000-4000-8000-000000000004',
};

const rpcCases = [
  ['get_my_job_applications', { p_application_id: null }],
  ['get_job_application_eligibility', { p_job_id: fakeIds.job }],
  ['update_my_job_application_status', {
    p_application_id: fakeIds.application,
    p_action: 'viewed',
    p_expected_updated_at: null,
  }],
  ['mort_accept_job_application', { p_application_id: fakeIds.application }],
  ['schedule_active_job_checkin', {
    p_application_id: fakeIds.application,
    p_minutes_from_now: 30,
    p_client_request_id: fakeIds.request,
  }],
  ['complete_active_job_checkin', {
    p_checkin_id: fakeIds.checkin,
    p_client_request_id: fakeIds.request,
  }],
];

for (const [name, args] of rpcCases) {
  const { data, error } = await client.rpc(name, args);
  const denied = Boolean(error) || data?.ok === false || data?.eligible === false;
  assert.ok(denied, `${name} unexpectedly allowed an anonymous operation`);
  console.log(`[qa-isolated-anonymous-safety-rpcs] PASS ${name}: anonymous request denied${error ? ` (${error.code ?? error.status ?? 'HTTP error'})` : ` (${data?.code ?? 'ok=false'})`}`);
}

const { data: rows, error: tableError } = await client
  .from('job_applications')
  .select('id,guardian_id')
  .limit(1);
assert.ok(tableError, `anonymous direct table read did not return an authorization error (rows=${rows?.length ?? 0})`);
console.log(`[qa-isolated-anonymous-safety-rpcs] PASS job_applications direct SELECT denied (${tableError.code ?? tableError.status ?? 'HTTP error'})`);
