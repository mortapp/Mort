#!/usr/bin/env node
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const base = new URL('../supabase-production/proposals/', import.meta.url);
const read = async (name) => readFile(new URL(name, base), 'utf8');
const verification = await read('20261102090000_verification_evidence_gate.sql');
const applications = await read('20261102090100_application_pair_lock_and_verification.sql');
const checkins = await read('20261102090200_checkin_idempotency_lifecycle.sql');
const backlog = await read('MORT_BACKEND_SECURITY_REMEDIATION_BACKLOG_2026-11-02.md');
const eligibilityFunction = applications.slice(
  applications.indexOf('CREATE OR REPLACE FUNCTION public.get_job_application_eligibility'),
  applications.indexOf('$function$;', applications.indexOf('CREATE OR REPLACE FUNCTION public.get_job_application_eligibility'))
);

for (const [name, sql] of Object.entries({ verification, applications, checkins })) {
  assert.match(sql, /PROPOSAL ONLY/);
  assert.match(sql, /md5\(pg_get_functiondef\(/);
  assert.match(sql, /begin;[\s\S]*commit;/i);
  assert.doesNotMatch(sql, /^\s*(?:drop\s+table|truncate\s+|delete\s+from)\b/im, `${name} must be additive`);
  assert.doesNotMatch(sql, /(?:update|insert\s+into|delete\s+from)\s+public\.mort_release_control/i, `${name} must not change release controls`);
}

assert.match(verification, /verification_provider_allowlist[\s\S]*is_enabled boolean not null default false/);
assert.match(verification, /verification_provider_results[\s\S]*provider_event_id text not null/);
assert.match(verification, /unique \(provider_key, provider_event_id\)/i);
assert.match(verification, /revoke all on private\.verification_provider_results from public, anon, authenticated, service_role/i);
assert.match(verification, /grant select, insert on private\.verification_provider_results to service_role/i);
assert.match(verification, /result\.provider_reference = v_case\.provider_reference/);
assert.match(verification, /case_appropriate_provider_evidence_required/);
assert.match(verification, /v_case_snapshot public\.verification_cases%rowtype/);
assert.match(verification, /verification_case_changed_retry/);
assert.match(verification, /v_case\.status is distinct from v_case_snapshot\.status/);
assert.match(verification, /v_case\.updated_at is distinct from v_case_snapshot\.updated_at/);
assert.match(verification, /subject profile -> provider allowlist[\s\S]*verification case -> provider result/);
assert.ok(
  verification.indexOf('from public.profiles profile') < verification.indexOf('for update;'),
  'verification reviewer must lock subject profile before locking the case'
);
assert.ok(
  verification.indexOf('for share;') < verification.indexOf('for update;'),
  'provider allowlist/profile locks must precede the case FOR UPDATE'
);
assert.doesNotMatch(verification, /insert\s+into\s+private\.verification_provider_allowlist/i, 'provider allowlist must remain empty');
assert.match(verification, /minimum_age_verification_required/);

assert.match(applications, /pg_advisory_xact_lock/);
assert.match(applications, /least\(v_user, v_app\.applicant_id\)::text \|\| ':' \|\| greatest\(v_user, v_app\.applicant_id\)::text/);
for (const track of ['age', 'school_id', 'school_email']) {
  assert.ok(applications.includes(`'${track}'`), `missing verification track ${track}`);
}
assert.match(applications, /for share/);
assert.match(applications, /clock_timestamp\(\)/);
assert.match(applications, /public_marketplace_disabled/);
assert.ok(
  eligibilityFunction.indexOf('from public.jobs job') < eligibilityFunction.indexOf('pg_advisory_xact_lock')
    && eligibilityFunction.indexOf('pg_advisory_xact_lock') < eligibilityFunction.indexOf('from public.profiles profile'),
  'eligibility must use job -> pair -> profile lock order to match acceptance'
);

assert.match(checkins, /request_interval_minutes integer/);
assert.match(checkins, /completion_request_id uuid/);
assert.match(checkins, /job_safety_checkins_teen_completion_request_uidx/);
assert.match(checkins, /idempotency_key_reused/);
assert.match(checkins, /request_interval_minutes is null[\s\S]*'ok', true, 'replayed', true, 'payload_verified', false/);
assert.match(checkins, /checkin\.status = 'completed'[\s\S]*'ok', true, 'replayed', true, 'payload_verified', false/);
assert.match(checkins, /status not in \('accepted', 'in_progress'\)/);
assert.match(checkins, /status not in \('filled', 'in_progress'\)/);
assert.match(checkins, /'replayed', true/);
assert.match(checkins, /'replayed', false/);

for (const priority of ['Priority 0', 'Priority 1']) assert.ok(backlog.includes(priority));
for (const role of ['Applicant', 'Poster', 'Connected Guardian', 'Revoked Guardian', 'Unrelated user', 'Administrator']) {
  assert.ok(backlog.includes(role), `missing QA role ${role}`);
}
assert.match(backlog, /No production migration or the stale Guardian-ID response-mask proposal was applied/);

console.log('[qa-security-remediation-proposals-static] PASS: guarded additive drafts, evidence gate, shared pair lock, verification rechecks, check-in idempotency/lifecycle, backlog and QA prerequisites');
