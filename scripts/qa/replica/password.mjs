// P1: server-enforced password protection on the production replica.
// Proves weak / leaked / invalid / acceptable handling through password-guard,
// and that direct Supabase Auth calls (signup, password update, recovery) that
// skip password-guard are rejected by the database. Local replica only.
import { writeFileSync } from 'node:fs';
import {
  API_URL, ANON_KEY, assertLocal, record, results, anonClient, guardCall, PASSWORD_GUARD_URL,
  signUpAndConfirm, confirmationLink,
} from './lib.mjs';

assertLocal();
if (!PASSWORD_GUARD_URL) throw new Error('PASSWORD_GUARD_URL is required');
const SERVICE_ROLE_KEY = process.env.SERVICE_ROLE_KEY;
const run = Date.now().toString(36);
const STRONG = 'Plum-Orbit-Kettle-73';
const STRONG2 = 'Cedar-Lantern-Quartz-58';
const LEAKED = 'Password123!';
const UNGUARDED = 'NotGuarded-Strong-4471'; // Passes composition; the DB must still reject direct writes.
const dob = '1990-05-17';
const auth = `${API_URL}/auth/v1`;

async function gotrue(path, { method = 'GET', token, body } = {}) {
  const res = await fetch(`${auth}${path}`, {
    method,
    headers: { apikey: ANON_KEY, 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  let json = {};
  try { json = await res.json(); } catch { /* empty */ }
  return { status: res.status, body: json };
}
async function signIn(email, password) {
  return gotrue('/token?grant_type=password', { method: 'POST', body: { email, password } });
}
const noToken = (o) => !JSON.stringify(o ?? {}).includes('mort_password_attestation');

// ---------------- signup through password-guard ----------------
const weakCases = [
  ['too short', 'Ab1!short', 'password_too_short'],
  ['no symbol', 'NoSymbolsHere123', 'password_complexity_required'],
  ['no uppercase', 'lowercase-only-123', 'password_complexity_required'],
  ['contains email local part', `Xweakling${run}!A1`, 'password_contains_email'],
  ['over 72 bytes', `Aa1!${'z'.repeat(70)}`, 'password_too_long'],
];
for (const [label, pw, code] of weakCases) {
  const email = label === 'contains email local part' ? `weakling${run}@example.test` : `weak-${run}@example.test`;
  const r = await guardCall({ action: 'signup', email, password: pw, date_of_birth: dob });
  record('P1-signup', `weak password rejected (${label})`, r.status === 422 && r.body.code === code, r.body);
}
{
  const r = await guardCall({ action: 'signup', email: `leaked-${run}@example.test`, password: LEAKED, date_of_birth: dob });
  record('P1-signup', 'leaked password rejected (HIBP)', r.status === 422 && r.body.code === 'leaked_password_compromised', r.body);
}
for (const [label, body, code] of [
  ['malformed email', { email: 'not-an-email', password: STRONG, date_of_birth: dob }, 'email_invalid'],
  ['missing date_of_birth', { email: `nodob-${run}@example.test`, password: STRONG }, 'dob_invalid'],
  ['non-ISO date_of_birth', { email: `baddob-${run}@example.test`, password: STRONG, date_of_birth: '05/17/1990' }, 'dob_invalid'],
  ['non-string password', { email: `num-${run}@example.test`, password: 123456789012, date_of_birth: dob }, 'password_required'],
]) {
  const r = await guardCall({ action: 'signup', ...body });
  record('P1-signup', `invalid input rejected (${label})`, [400, 422].includes(r.status) && r.body.code === code, r.body);
}
{
  const r = await guardCall({ action: 'signup', email: `under13-${run}@example.test`, password: STRONG, date_of_birth: '2020-01-01' });
  record('P1-signup', 'under-13 DOB rejected before Auth write', r.status === 400 && r.body.code === 'dob_under_minimum_age', r.body);
}
{
  await fetch(new URL('/__test/hibp-down', PASSWORD_GUARD_URL));
  const r = await guardCall({ action: 'signup', email: `hibpdown-${run}@example.test`, password: STRONG, date_of_birth: dob });
  await fetch(new URL('/__test/hibp-up', PASSWORD_GUARD_URL));
  record('P1-signup', 'HIBP outage fails closed (no account created)', r.status === 503 && r.body.code === 'leaked_password_check_unavailable', r.body);
  const after = await signIn(`hibpdown-${run}@example.test`, STRONG);
  record('P1-signup', 'HIBP outage: no account exists afterwards', after.status === 400, after.body.error_code ?? after.status);
}

// acceptable
const good = await signUpAndConfirm({ email: `good-${run}@example.test`, password: STRONG, dob, displayName: 'good' });
record('P1-signup', 'acceptable password: guarded signup + email confirmation + sign-in', Boolean(good.id));
{
  const { data } = await good.client.auth.getUser();
  record('P1-signup', 'attestation stripped from stored user_metadata and identity_data', noToken(data.user), JSON.stringify(data.user?.user_metadata));
  record('P1-signup', 'date_of_birth delivered to the profile trigger', data.user?.user_metadata?.date_of_birth === dob, data.user?.user_metadata?.date_of_birth);
  const again = await signIn(good.email, STRONG);
  const again2 = await signIn(good.email, STRONG);
  record('P1-signin', 'repeated password sign-in unaffected by the triggers', again.status === 200 && again2.status === 200, `${again.status},${again2.status}`);
}

// ---------------- bypass attempts: direct Auth signup ----------------
for (const [label, pw] of [['strong password', STRONG], ['weak password', 'weak'], ['leaked password', LEAKED]]) {
  const email = `direct-${label.split(' ')[0]}-${run}@example.test`;
  const r = await gotrue('/signup', { method: 'POST', body: { email, password: pw, data: { date_of_birth: dob } } });
  const s = await signIn(email, pw);
  record('P1-bypass', `direct GoTrue signup without attestation rejected (${label})`, r.status >= 400 && s.status === 400, `${r.status} ${r.body.msg ?? r.body.error_code ?? ''}`);
}

// ---------------- password update ----------------
const session = (await signIn(good.email, STRONG)).body;
{
  const r = await gotrue('/user', { method: 'PUT', token: session.access_token, body: { password: 'weakpassword' } });
  const s = await signIn(good.email, STRONG);
  record('P1-bypass', 'direct PUT /auth/v1/user password change (weak) rejected; old password still valid', r.status >= 400 && s.status === 200, `${r.status}/${s.status}`);
}
{
  const r = await gotrue('/user', { method: 'PUT', token: session.access_token, body: { password: STRONG2 } });
  const s = await signIn(good.email, STRONG2);
  record('P1-bypass', 'direct PUT /auth/v1/user password change (strong, no attestation) rejected', r.status >= 400 && s.status === 400, `${r.status}/${s.status}`);
}
const s2 = (await signIn(good.email, STRONG)).body;
for (const [label, pw, code] of [['weak', 'short1!A', 'password_too_short'], ['leaked', LEAKED, 'leaked_password_compromised']]) {
  const r = await guardCall({ action: 'update_password', password: pw }, s2.access_token);
  record('P1-update', `${label} password change rejected by password-guard`, r.status === 422 && r.body.code === code, r.body);
}
{
  const r = await guardCall({ action: 'update_password', password: STRONG2 });
  record('P1-update', 'password-guard update without a session rejected', r.status === 401, r.body);
  const r2 = await guardCall({ action: 'update_password', password: STRONG2 }, ANON_KEY);
  record('P1-update', 'password-guard update with the anon key rejected', r2.status === 401, r2.body);
}
{
  const r = await gotrue('/user', { method: 'PUT', token: s2.access_token, body: { data: { display_name: 'renamed' } } });
  record('P1-update', 'metadata-only update (no password) still works', r.status === 200, `${r.status}`);
}
{
  const r = await guardCall({ action: 'update_password', password: STRONG2 }, s2.access_token);
  const oldPw = await signIn(good.email, STRONG);
  const newPw = await signIn(good.email, STRONG2);
  record('P1-update', 'after guarded change: new password works, old password fails', r.status === 200 && newPw.status === 200 && oldPw.status === 400, `${r.status}/${newPw.status}/${oldPw.status}`);
  const stored = await gotrue('/user', { token: newPw.body.access_token });
  record('P1-update', 'attestation not left in stored metadata after a guarded password change', stored.status === 200 && noToken(stored.body));
}

// ---------------- password recovery ----------------
{
  const c = anonClient();
  const { error } = await c.auth.resetPasswordForEmail(good.email, { redirectTo: 'http://127.0.0.1:3000' });
  record('P1-recovery', 'password reset email requested', !error, error?.message ?? '');
  const link = await confirmationLink(good.email, 'recovery');
  const res = await fetch(link, { redirect: 'manual' });
  const loc = res.headers.get('location') ?? '';
  const frag = new URLSearchParams(loc.split('#')[1] ?? '');
  const recoveryToken = frag.get('access_token');
  record('P1-recovery', 'recovery link yields a recovery session', Boolean(recoveryToken) && frag.get('type') === 'recovery', `${res.status}`);
  const direct = await gotrue('/user', { method: 'PUT', token: recoveryToken, body: { password: UNGUARDED } });
  record('P1-bypass', 'recovery session cannot set a password directly (bypass rejected)', direct.status === 500, `${direct.status}`);
  const leaked = await guardCall({ action: 'update_password', password: LEAKED }, recoveryToken);
  record('P1-recovery', 'recovery: leaked password rejected', leaked.status === 422 && leaked.body.code === 'leaked_password_compromised', leaked.body);
  const ok = await guardCall({ action: 'update_password', password: 'Harbor-Mosaic-Velvet-24' }, recoveryToken);
  const s = await signIn(good.email, 'Harbor-Mosaic-Velvet-24');
  record('P1-recovery', 'recovery: acceptable password set through password-guard, sign-in works', ok.status === 200 && s.status === 200, `${ok.status}/${s.status}`);
}

// ---------------- passwordless creation paths stay open ----------------
if (SERVICE_ROLE_KEY) {
  const admin = (path, body) => fetch(`${auth}${path}`, { method: 'POST', headers: { apikey: SERVICE_ROLE_KEY, authorization: `Bearer ${SERVICE_ROLE_KEY}`, 'content-type': 'application/json' }, body: JSON.stringify(body) });
  const invite = await admin('/invite', { email: `invite-${run}@example.test`, data: { date_of_birth: dob } });
  record('P1-compat', 'passwordless invite creation still allowed (no password written)', invite.status === 200, `${invite.status}`);
  // GoTrue admin create always writes a password (generated if omitted), so it is blocked by design.
  const withPw = await admin('/admin/users', { email: `adminpw-${run}@example.test`, password: STRONG, email_confirm: true, user_metadata: { date_of_birth: dob } });
  record('P1-compat', 'service-role admin create-user is blocked (always writes a password; fail closed, documented)', withPw.status >= 400, `${withPw.status}`);
}
// Real Apple/Google OAuth requires a separately configured QA provider and
// physical-client journey. Do not construct a substitute row in auth.users.

writeFileSync(process.env.PASSWORD_RESULTS ?? 'password.json', JSON.stringify(results, null, 2));
const failed = results.filter((r) => !r.pass);
console.log(`password: ${results.length - failed.length}/${results.length}`);
process.exit(failed.length ? 1 : 0);
