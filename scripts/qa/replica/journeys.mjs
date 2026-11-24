// Fresh-user acceptance journeys on the LOCAL production replica.
// Every end-user identity is created through public GoTrue signup + the
// emailed confirmation link, then the production onboarding RPCs, the
// production Storage policies, and the production staff-review RPCs.
//
// The single out-of-band step is the staff root of trust: production has no
// RPC that grants private.user_roles, so the replica bootstraps one admin and
// one moderator exactly the way production staff must be provisioned (owner
// SQL on private.user_roles). That step is recorded in the output.
import pg from 'pg';
import {
  assertLocal, record, results, signUpAndConfirm, rpc, okData, reqId, randomUUID, JPEG,
} from './lib.mjs';

assertLocal();
const run = Date.now().toString(36);
const PW = 'Mort-Replica-Journey-7731!';
const yearsAgo = (y, extraDays = 40) => {
  const d = new Date();
  d.setUTCFullYear(d.getUTCFullYear() - y);
  d.setUTCDate(d.getUTCDate() - extraDays);
  return d.toISOString().slice(0, 10);
};

const db = new pg.Client({ connectionString: process.env.DB_URL });
await db.connect();

export const actors = {};

async function onboardAccount(a, payload) {
  const r = await rpc(a.client, 'save_my_onboarding_account_v2', {
    p_payload: payload, p_client_request_id: reqId(), p_payload_version: 1,
  });
  return r;
}

async function acceptLegal(a, signature) {
  const req = await rpc(a.client, 'get_my_legal_requirements');
  if (req.error) return { ok: false, error: req.error.message };
  const docs = (req.data?.requirements ?? req.data?.documents ?? []);
  let accepted = 0;
  for (const d of docs) {
    const id = d.version_id ?? d.document_version_id;
    const r = await rpc(a.client, 'submit_legal_acceptance', {
      p_document_version_id: id, p_affirmative_checkbox: true, p_teen_summary_viewed: true,
      p_electronic_signature_text: signature, p_platform: 'android', p_app_version: '0.9.13-replica',
    });
    if (okData(r)) accepted += 1; else return { ok: false, doc: d.document_key, r };
  }
  return { ok: accepted > 0 && accepted === docs.length, accepted, total: docs.length };
}

async function complete(a) {
  return rpc(a.client, 'complete_my_onboarding_v2', { p_payload: {}, p_client_request_id: reqId(), p_payload_version: 1 });
}

async function submitEvidence(a, type) {
  const path = `${a.id}/${randomUUID()}.jpg`;
  const up = await a.client.storage.from('verification-evidence').upload(path, JPEG, { contentType: 'image/jpeg' });
  if (up.error) return { ok: false, step: 'upload', error: up.error.message };
  const r = await rpc(a.client, 'submit_my_verification_evidence_v1', { p_verification_type: type, p_evidence_path: path });
  return { ok: okData(r), r, path };
}

async function caseFor(a, type) {
  const { rows } = await db.query(
    "select id from public.verification_cases where user_id=$1 and verification_type=$2 and status in ('pending','needs_review') order by created_at desc limit 1",
    [a.id, type]);
  return rows[0]?.id;
}

async function staffVerify(staff, a, type) {
  // Staff discover the case through the staff-visible table (RLS: owner or staff).
  const list = await staff.client.from('verification_cases').select('id,status,verification_type,user_id')
    .eq('user_id', a.id).eq('verification_type', type).in('status', ['pending', 'needs_review']);
  const caseId = list.data?.[0]?.id ?? null;
  if (!caseId) return { ok: false, step: 'staff_list', error: list.error?.message, dbCase: await caseFor(a, type) };
  const rec = await rpc(staff.client, 'mort_record_staff_document_review', { p_case_id: caseId, p_decision: 'verified', p_note: 'replica acceptance' });
  if (!okData(rec)) return { ok: false, step: 'record', rec };
  const rev = await rpc(staff.client, 'mort_review_verification_case', { p_case_id: caseId, p_status: 'verified', p_note: 'replica acceptance' });
  if (rev.error) return { ok: false, step: 'review', error: rev.error.message };
  return { ok: true, caseId };
}

async function profileOf(a) {
  const { data } = await a.client.from('profiles').select('id,role,account_status,guardian_setup_status,onboarding_completed_at,verification_status').eq('id', a.id).single();
  return data;
}

// ---------- staff root of trust ----------
async function makeStaff(label, role) {
  const a = await signUpAndConfirm({ email: `${label}-${run}@staff.mort.test`, password: PW, dob: yearsAgo(30), displayName: label });
  await db.query('insert into private.user_roles(user_id, role) values ($1, $2::public.mort_role)', [a.id, role]);
  await db.query("update public.profiles set role=$2::public.mort_role, account_status='active', display_name=$3, username=$4, updated_at=now() where id=$1",
    [a.id, role, label, `${label.replace(/[^a-z0-9]/g, '_')}_${run}`.slice(0, 24)]);
  record('bootstrap', `${role} root-of-trust provisioned via owner SQL on private.user_roles (replica only)`, true);
  return a;
}

actors.admin = await makeStaff('admin', 'admin');
actors.moderator = await makeStaff('moderator', 'moderator');

// ---------- email signup without DOB (current Flutter client contract) ----------
{
  const { anonClient } = await import('./lib.mjs');
  const c = anonClient();
  const { error } = await c.auth.signUp({ email: `nodob-${run}@example.test`, password: PW });
  record('P4-signup', 'email signup without date_of_birth metadata (what flutter_mort main sends) is rejected by the database',
    Boolean(error), error?.message ?? 'accepted');
}

// ---------- adults ----------
async function adultJourney(key, role) {
  const a = await signUpAndConfirm({ email: `${key}-${run}@example.test`, password: PW, dob: yearsAgo(34), displayName: key });
  actors[key] = a;
  const acct = await onboardAccount(a, { role, display_name: key, username: `${key}_${run}`.slice(0, 24), dob: yearsAgo(34), city: 'Indianapolis', state: 'IN', location_setup_mode: 'city_state' });
  record('P4-onboarding', `${key}: account step`, okData(acct), acct.error?.message ?? acct.data?.active_step);
  const work = await rpc(a.client, 'save_my_onboarding_work_v2', { p_payload: {}, p_client_request_id: reqId(), p_payload_version: 1 });
  const safety = await rpc(a.client, 'save_my_onboarding_safety_v2', { p_payload: { notification_intent: 'ask_later' }, p_client_request_id: reqId(), p_payload_version: 1 });
  record('P4-onboarding', `${key}: work + safety steps`, okData(work) && okData(safety), safety.data?.active_step ?? safety.error?.message);
  const legal = await acceptLegal(a, `${key} replica`);
  record('P4-onboarding', `${key}: current legal acceptances`, legal.ok, legal);
  const done = await complete(a);
  record('P4-onboarding', `${key}: complete_my_onboarding_v2`, okData(done), done.data ?? done.error?.message);
  return a;
}

await adultJourney('adult_a', 'adult');
await adultJourney('adult_b', 'adult');
await adultJourney('guardian', 'guardian');

for (const key of ['adult_a', 'adult_b']) {
  const a = actors[key];
  const ev = await submitEvidence(a, 'identity');
  record('P4-verification', `${key}: identity evidence upload + submit`, ev.ok, ev.ok ? '' : ev);
  const sv = await staffVerify(actors.moderator, a, 'identity');
  record('P4-verification', `${key}: moderator records + verifies identity case`, sv.ok, sv.ok ? '' : sv);
  const act = await rpc(actors.admin.client, 'admin_set_account_status_v2', { p_user_id: a.id, p_status: 'active', p_reason_code: 'verification_complete', p_reason: 'Replica acceptance activation' });
  record('P4-activation', `${key}: admin activation`, okData(act), act.data ?? act.error?.message);
  const p = await profileOf(a);
  record('P4-activation', `${key}: profile active adult`, p?.account_status === 'active' && p?.role === 'adult', p);
}

// ---------- teens ----------
async function teenJourney(key, guardianEmail) {
  const a = await signUpAndConfirm({ email: `${key}-${run}@herronriverside.org`, password: PW, dob: yearsAgo(16), displayName: key });
  actors[key] = a;
  const acct = await onboardAccount(a, { role: 'teen', display_name: key, username: `${key}_${run}`.slice(0, 24), dob: yearsAgo(16), approximate_area: 'Near north side' });
  record('P4-onboarding', `${key}: account step (approved school email)`, okData(acct), acct.error?.message ?? acct.data?.active_step);
  const work = await rpc(a.client, 'save_my_onboarding_work_v2', { p_payload: { availability: 'Weekends', preferred_job_categories: ['yard_work'], transportation_methods: ['walking'] }, p_client_request_id: reqId(), p_payload_version: 1 });
  record('P4-onboarding', `${key}: work step`, okData(work), work.data?.active_step ?? work.error?.message);
  // Skip path first (documented teen choice) -- observe whether it can succeed while pending.
  const skip = await rpc(a.client, 'save_my_onboarding_safety_v2', { p_payload: { notification_intent: 'ask_later', guardian_choice: 'skip' }, p_client_request_id: reqId(), p_payload_version: 1 });
  const pAfterSkip = await profileOf(a);
  record('P4-onboarding', `${key}: guardian "skip" during onboarding advances to review`, skip.data?.active_step === 'review',
    { active_step: skip.data?.active_step, missing: skip.data?.missing_requirements, guardian_setup_status: pAfterSkip?.guardian_setup_status });
  let invite = null;
  if (guardianEmail) {
    invite = await rpc(a.client, 'create_guardian_invite_v2', { p_invite_email: guardianEmail });
    record('P4-guardian', `${key}: create_guardian_invite_v2 while pending`, okData(invite), invite.data?.code ?? invite.error?.message ?? '');
    const safety = await rpc(a.client, 'save_my_onboarding_safety_v2', { p_payload: { notification_intent: 'ask_later', guardian_choice: 'existing' }, p_client_request_id: reqId(), p_payload_version: 1 });
    record('P4-onboarding', `${key}: safety step with pending guardian invite`, safety.data?.active_step === 'review', safety.data?.active_step ?? safety.error?.message);
  }
  const legal = await acceptLegal(a, `${key} replica`);
  record('P4-onboarding', `${key}: current legal acceptances`, legal.ok, legal);
  const done = await complete(a);
  record('P4-onboarding', `${key}: complete_my_onboarding_v2`, okData(done), done.data ?? done.error?.message);
  for (const type of ['age', 'school_id']) {
    const ev = await submitEvidence(a, type);
    record('P4-verification', `${key}: ${type} evidence upload + submit`, ev.ok, ev.ok ? '' : ev);
    const sv = await staffVerify(actors.moderator, a, type);
    record('P4-verification', `${key}: moderator verifies ${type}`, sv.ok, sv.ok ? '' : sv);
  }
  const act = await rpc(actors.admin.client, 'admin_set_account_status_v2', { p_user_id: a.id, p_status: 'active', p_reason_code: 'verification_complete', p_reason: 'Replica acceptance activation' });
  record('P4-activation', `${key}: admin activation`, okData(act), act.data ?? act.error?.message);
  const p = await profileOf(a);
  record('P4-activation', `${key}: profile active teen`, p?.account_status === 'active' && p?.role === 'teen', p);
  return { a, invite };
}

const teenA = await teenJourney('teen_a', actors.guardian.email);
await teenJourney('teen_b', null);

// ---------- activation must require completed onboarding (D3 regression) ----------
{
  const a = await signUpAndConfirm({ email: `adult_c-${run}@example.test`, password: PW, dob: yearsAgo(40), displayName: 'adult_c' });
  actors.adult_c = a;
  await onboardAccount(a, { role: 'adult', display_name: 'adult_c', username: `adult_c_${run}`.slice(0, 24), dob: yearsAgo(40), city: 'Indianapolis', state: 'IN', location_setup_mode: 'city_state' });
  // Deliberately stops before legal acceptance / complete_my_onboarding_v2.
  const ev = await submitEvidence(a, 'identity');
  const sv = await staffVerify(actors.moderator, a, 'identity');
  const act = await rpc(actors.admin.client, 'admin_set_account_status_v2', { p_user_id: a.id, p_status: 'active', p_reason_code: 'verification_complete', p_reason: 'Replica negative test' });
  const p = await profileOf(a);
  record('P4-activation', 'adult_c: verified identity but incomplete onboarding cannot be activated', p?.account_status === 'pending',
    { evidence: ev.ok, verified: sv.ok, activation: act.data ?? act.error?.message, status: p?.account_status });
  // Completing onboarding afterwards queues activation through the normal path.
  await rpc(a.client, 'save_my_onboarding_work_v2', { p_payload: {}, p_client_request_id: reqId(), p_payload_version: 1 });
  await rpc(a.client, 'save_my_onboarding_safety_v2', { p_payload: { notification_intent: 'ask_later' }, p_client_request_id: reqId(), p_payload_version: 1 });
  await acceptLegal(a, 'adult_c replica');
  const done = await complete(a);
  const act2 = await rpc(actors.admin.client, 'admin_set_account_status_v2', { p_user_id: a.id, p_status: 'active', p_reason_code: 'verification_complete', p_reason: 'Replica acceptance activation' });
  const p2 = await profileOf(a);
  record('P4-activation', 'adult_c: after completing onboarding, staff activation succeeds', p2?.account_status === 'active', { complete: done.data?.ok, activation: act2.data ?? act2.error?.message });
}

// ---------- guardian activation + linking ----------
{
  const g = actors.guardian;
  const pre = await profileOf(g);
  const ev = await submitEvidence(g, 'identity');
  record('P4-guardian', 'guardian: identity evidence upload + submit', ev.ok, ev.ok ? '' : ev);
  const sv = await staffVerify(actors.moderator, g, 'identity');
  record('P4-guardian', 'guardian: moderator verifies identity', sv.ok, sv.ok ? '' : sv);
  const act = await rpc(actors.admin.client, 'admin_set_account_status_v2', { p_user_id: g.id, p_status: 'active', p_reason_code: 'verification_complete', p_reason: 'Replica acceptance activation' });
  const post = await profileOf(g);
  record('P4-guardian', 'guardian: account can be activated through staff review', post?.account_status === 'active', { before: pre?.account_status, activation: act.data ?? act.error?.message, after: post?.account_status });
  const code = teenA.invite?.data?.invite_code;
  const acc = code ? await rpc(g.client, 'accept_guardian_invite', { p_invite_code: code }) : { error: { message: 'no invite code' } };
  record('P4-guardian', 'guardian: accept_guardian_invite links teen_a', !acc.error, acc.error?.message ?? acc.data);
}

const fs = await import('node:fs');
fs.writeFileSync(process.env.ACTORS_OUT ?? '/tmp/replica-actors.json', JSON.stringify(
  Object.fromEntries(Object.entries(actors).map(([k, v]) => [k, { id: v.id, email: v.email, password: v.password }])), null, 2));
await db.end();
const failed = results.filter((r) => !r.pass);
console.log(`\njourneys: ${results.length - failed.length}/${results.length} passed`);
fs.writeFileSync(process.env.JOURNEY_RESULTS ?? '/tmp/replica-journeys.json', JSON.stringify(results, null, 2));
process.exitCode = failed.length ? 1 : 0;
