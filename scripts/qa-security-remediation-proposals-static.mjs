#!/usr/bin/env node
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const base = new URL('../supabase-production/proposals/', import.meta.url);
const read = async (name) => readFile(new URL(name, base), 'utf8');
const verification = await read('20261102090000_verification_evidence_gate.sql');
const applications = await read('20261102090100_application_pair_lock_and_verification.sql');
const checkins = await read('20261102090200_checkin_idempotency_lifecycle.sql');
const localAcl = await readFile(new URL('./qa-local-hosted-job-applications-acl.ps1', import.meta.url), 'utf8');
const baselineReplay = await readFile(new URL('./qa-replay-production-baseline-17-11.mjs', import.meta.url), 'utf8');
const proposalCompiler = await readFile(new URL('./qa-compile-security-proposals-pg1711.mjs', import.meta.url), 'utf8');
const twoSessionLocks = await readFile(new URL('./qa-safety-proposal-two-session-locks.mjs', import.meta.url), 'utf8');
const fixtureFreeTests = await readFile(new URL('../supabase-production/proposals/tests/20261102090600_fixture_free_proposal_contracts.sql', import.meta.url), 'utf8');
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
assert.ok(
  verification.indexOf('v_now := clock_timestamp();') < verification.indexOf("extract(year from age(v_now::date, v_date_of_birth)) < 13"),
  'verification age gate must initialize its clock before evaluating DOB'
);
assert.match(verification, /result\.received_at >= coalesce\(v_case\.submitted_at, v_case\.created_at\)/);
assert.match(verification, /'provider_result_id',v_evidence_result_id/);

assert.match(applications, /pg_advisory_xact_lock/);
assert.match(applications, /least\(v_user, v_app\.applicant_id\)::text \|\| ':' \|\| greatest\(v_user, v_app\.applicant_id\)::text/);
for (const track of ['age', 'school_id', 'school_email']) {
  assert.ok(applications.includes(`'${track}'`), `missing verification track ${track}`);
}
assert.match(applications, /for share/);
assert.match(applications, /clock_timestamp\(\)/);
assert.match(applications, /public_marketplace_disabled/);
assert.doesNotMatch(applications, /guardian_decision_status|guardian_decided_by|guardian_preferences|optional_job_approval_enabled/i, 'production contract must not import QA-only Guardian decision or preference fields');
assert.match(applications, /verification_type = 'school_id'[\s\S]*'school_id_verification_required'/);
assert.match(applications, /verification_type = 'school_email'[\s\S]*'school_email_verification_required'/);
assert.match(applications, /verification_type = 'identity'[\s\S]*v_poster_identity_verified/);
assert.ok(
  eligibilityFunction.indexOf('from public.jobs job') < eligibilityFunction.indexOf('pg_advisory_xact_lock')
    && eligibilityFunction.indexOf('pg_advisory_xact_lock') < eligibilityFunction.indexOf('from public.profiles profile'),
  'eligibility must use job -> pair -> profile lock order to match acceptance'
);
const eligibilityGuardianLock = eligibilityFunction.indexOf('from public.guardian_links gl');
const eligibilityTeenProfileLock = eligibilityFunction.indexOf('from public.profiles profile where profile.id = auth.uid() for share');
assert.ok(
  eligibilityGuardianLock < eligibilityTeenProfileLock,
  'eligibility must lock Guardian link/identity rows before the teen profile to match unlink/revocation order'
);
const acceptanceFunction = applications.slice(
  applications.indexOf('CREATE OR REPLACE FUNCTION public.mort_accept_job_application'),
  applications.indexOf('$function$;', applications.indexOf('CREATE OR REPLACE FUNCTION public.mort_accept_job_application'))
);
assert.ok(
  acceptanceFunction.indexOf('from public.guardian_links gl') < acceptanceFunction.indexOf('from public.profiles profile\n  where profile.id = v_app.applicant_id'),
  'acceptance must lock Guardian link/identity rows before the teen profile'
);
assert.ok(
  acceptanceFunction.indexOf('pg_try_advisory_xact_lock') < acceptanceFunction.indexOf('from public.jobs\n  where id = v_app.job_id\n  for update'),
  'acceptance must fail fast on the same-job serialization lock before waiting on the job row'
);
assert.match(acceptanceFunction, /job_acceptance_in_progress_retry/);

assert.match(checkins, /request_interval_minutes integer/);
assert.match(checkins, /completion_request_id uuid/);
assert.match(checkins, /job_safety_checkins_teen_completion_request_uidx/);
assert.match(checkins, /idempotency_key_reused/);
assert.match(checkins, /request_interval_minutes is null[\s\S]*'ok', true, 'replayed', true, 'payload_verified', false/);
assert.match(checkins, /checkin\.status = 'completed'[\s\S]*'ok', true, 'replayed', true, 'payload_verified', false/);
assert.match(checkins, /if checkin\.completion_request_id is not null then\s+return jsonb_build_object\('ok', false, 'code', 'idempotency_key_reused'\)/);
assert.match(checkins, /status not in \('accepted', 'in_progress'\)/);
assert.match(checkins, /status not in \('filled', 'in_progress'\)/);
assert.match(checkins, /'replayed', true/);
assert.match(checkins, /'replayed', false/);

assert.match(localAcl, /mort-pg1711-baseline6-mort20261102/);
assert.doesNotMatch(localAcl, /supabase_db_mort-proposals-local-20261102/, 'ACL bootstrap must reject the older non-parity database');
assert.match(localAcl, /migration_count <> 73/);
assert.match(localAcl, /GRANT ALL PRIVILEGES ON TABLE public\.job_applications TO service_role/);
assert.match(localAcl, /has_any_column_privilege\('authenticated', 'public\.job_applications', 'SELECT'\)/);
assert.doesNotMatch(localAcl, /grant\s+[^;]*\b(?:anon|authenticated)\b/i, 'local ACL parity must never grant API roles');
assert.match(baselineReplay, /mort-pg1711-baseline6-mort20261102/);
assert.match(baselineReplay, /source_bytes=exact/);
assert.match(baselineReplay, /spawn\('docker'/);
assert.match(proposalCompiler, /mort-pg1711-baseline6-mort20261102/);
assert.match(proposalCompiler, /public_marketplace_enabled=false, real_document_collection=false/);
assert.match(twoSessionLocks, /mort-pg1711-baseline6-mort20261102/);
assert.match(twoSessionLocks, /same-job acceptance serialization key \(protocol only\)/);
assert.match(fixtureFreeTests, /extensions\.plan\(19\)/);
assert.doesNotMatch(fixtureFreeTests, /\b(?:insert\s+into|update\s+public\.|delete\s+from|truncate\s+)/i, 'fixture-free regression test must not seed or mutate application records');

for (const priority of ['Priority 0', 'Priority 1']) assert.ok(backlog.includes(priority));
for (const role of ['Applicant', 'Poster', 'Connected Guardian', 'Revoked Guardian', 'Unrelated user', 'Administrator']) {
  assert.ok(backlog.includes(role), `missing QA role ${role}`);
}
assert.match(backlog, /No production migration or the stale Guardian-ID response-mask proposal was applied/);

console.log('[qa-security-remediation-proposals-static] PASS: guarded additive drafts, evidence gate, shared pair lock, verification rechecks, check-in idempotency/lifecycle, backlog and QA prerequisites');
