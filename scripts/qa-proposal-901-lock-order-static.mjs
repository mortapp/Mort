#!/usr/bin/env node
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const migration = await readFile(new URL('../supabase-production/proposals/20261102090100_application_pair_lock_and_verification.sql', import.meta.url), 'utf8');

function bodyFor(name) {
  const escaped = name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const match = migration.match(new RegExp(`CREATE OR REPLACE FUNCTION public\\.${escaped}\\([\\s\\S]*?\\$function\\$;`, 'i'));
  assert.ok(match, `missing replacement for ${name}`);
  return match[0].toLowerCase();
}

const requiredSourceGuards = [
  "public.get_job_application_eligibility(uuid)'::regprocedure",
  "public.mort_accept_job_application(uuid)'::regprocedure",
  "public.update_my_job_application_status(uuid,text,timestamp with time zone)'::regprocedure",
];
for (const guard of requiredSourceGuards) assert.ok(migration.includes(guard), `missing exact production source guard: ${guard}`);
assert.ok(migration.includes("<> '783f373cd4ad853ee690eae22abc6289'"), 'status wrapper guard must match the verified production definition');

const acceptance = bodyFor('mort_accept_job_application');
const targetLookup = acceptance.indexOf('select application.job_id, application.applicant_id');
const authorizedJobLock = acceptance.indexOf('from public.jobs');
const activeProfileLock = acceptance.indexOf('from public.profiles');
const pairLock = acceptance.indexOf('pg_advisory_xact_lock');
const applicationLock = acceptance.indexOf('for update', pairLock);
assert.ok(targetLookup >= 0, 'acceptance must discover target IDs without locking the application');
assert.ok(authorizedJobLock > targetLookup, 'acceptance must resolve and authorize the job after the nonlocking application lookup');
assert.ok(activeProfileLock > authorizedJobLock && pairLock > activeProfileLock, 'acceptance must lock the active poster profile between job and pair locks');
assert.ok(applicationLock > pairLock, 'acceptance must lock the application only after job and pair locks');
assert.ok(!acceptance.includes('mort-accept-job:'), 'acceptance must use the job row as its per-job serialization lock');

const wrapper = bodyFor('update_my_job_application_status');
const wrapperTargetLookup = wrapper.indexOf('select ja.job_id, ja.applicant_id');
const acceptedBranch = wrapper.indexOf("p_action = 'accepted'");
const wrapperJobLock = wrapper.indexOf('from public.jobs', acceptedBranch);
const wrapperProfileLock = wrapper.indexOf('from public.profiles', wrapperJobLock);
const wrapperPairLock = wrapper.indexOf('pg_advisory_xact_lock');
const wrapperApplicationLock = wrapper.indexOf('for update', wrapperPairLock);
assert.ok(wrapperTargetLookup >= 0 && acceptedBranch > wrapperTargetLookup, 'status wrapper must perform an unlocked, caller-scoped target lookup');
assert.ok(wrapperJobLock > acceptedBranch, 'acceptance wrapper must lock the owned job before the application');
assert.ok(wrapperProfileLock > wrapperJobLock && wrapperPairLock > wrapperProfileLock, 'acceptance wrapper must lock the active poster profile between job and pair locks');
assert.ok(wrapperApplicationLock > wrapperPairLock, 'acceptance wrapper must lock the application last');
assert.ok(wrapper.indexOf('mort_accept_job_application(v_app.id)') > wrapperApplicationLock, 'wrapper must retain the existing acceptance RPC and response contract');

console.log('PROPOSAL_901_LOCK_ORDER_STATIC=PASS functions=2 exact_source_guards=3 order=job,pair,application');
