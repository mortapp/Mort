// Adversarial cross-account and Storage authorization tests on the LOCAL
// production replica. Uses the identities created by journeys.mjs (normal
// signup + onboarding + staff review). No service-role key is used by any
// actor; every request goes through PostgREST / Storage with a user JWT or
// the anon key, exactly like a hostile client would.
import fs from 'node:fs';
import pg from 'pg';
import { assertLocal, anonClient, record, results, rpc, okData, reqId, randomUUID, JPEG, PNG } from './lib.mjs';

assertLocal();
const dbUrl = new URL(process.env.DB_URL);
if (!['postgres:', 'postgresql:'].includes(dbUrl.protocol) ||
    !['127.0.0.1', '[::1]', 'localhost'].includes(dbUrl.hostname) ||
    ['host', 'hostaddr', 'port', 'service'].some((key) => dbUrl.searchParams.has(key))) {
  throw new Error('DB_URL must target only the disposable local replica');
}
const db = new pg.Client({ connectionString: dbUrl.href });
await db.connect();
const postFix = process.env.PRE_FIX !== '1';
const actorsFile = JSON.parse(fs.readFileSync(process.env.ACTORS_OUT ?? '/tmp/replica-actors.json', 'utf8'));
const A = {};
for (const [k, v] of Object.entries(actorsFile)) {
  const c = anonClient();
  const s = await c.auth.signInWithPassword({ email: v.email, password: v.password });
  if (s.error) throw new Error(`${k} sign-in: ${s.error.message}`);
  A[k] = { ...v, client: c };
}
const anon = anonClient();
const denied = (r) => Boolean(r.error) || (r.data && typeof r.data === 'object' && !Array.isArray(r.data) && r.data.ok === false);
const emptyOrDenied = (r) => Boolean(r.error) || (Array.isArray(r.data) && r.data.length === 0) || r.data == null;

// ------------------------------------------------------------------ Storage
const BUCKETS = ['profile-avatars', 'job-evidence', 'dispute-evidence', 'chat-attachments', 'proof-uploads', 'verification-evidence'];

async function up(actor, bucket, path, body = JPEG, contentType = 'image/jpeg', upsert = false) {
  const c = actor === 'anon' ? anon : A[actor].client;
  return c.storage.from(bucket).upload(path, body, { contentType, upsert });
}
async function dl(actor, bucket, path) {
  const c = actor === 'anon' ? anon : A[actor].client;
  return c.storage.from(bucket).download(path);
}
async function rm(actor, bucket, path) {
  const c = actor === 'anon' ? anon : A[actor].client;
  const r = await c.storage.from(bucket).remove([path]);
  // Storage returns 200 with [] when RLS hides the row: treat "nothing removed" as denied.
  return { ...r, removed: Array.isArray(r.data) ? r.data.length : 0 };
}
async function stillExists(bucket, path) {
  const { rows } = await db.query('select 1 from storage.objects where bucket_id=$1 and name=$2', [bucket, path]);
  return rows.length === 1;
}
async function list(actor, bucket, prefix) {
  const c = actor === 'anon' ? anon : A[actor].client;
  return c.storage.from(bucket).list(prefix);
}
async function signed(actor, bucket, path) {
  const c = actor === 'anon' ? anon : A[actor].client;
  return c.storage.from(bucket).createSignedUrl(path, 60);
}

// Unused, policy-less buckets: deny-by-default for every client role.
for (const bucket of ['job-evidence', 'dispute-evidence']) {
  for (const actor of ['anon', 'teen_a', 'adult_a', 'moderator', 'admin']) {
    const owner = actor === 'anon' ? randomUUID() : A[actor].id;
    const r = await up(actor, bucket, `${owner}/${randomUUID()}.jpg`);
    record('P2-storage', `${bucket}: ${actor} upload to own folder denied`, Boolean(r.error), r.error?.message ?? 'UPLOADED');
    const l = await list(actor, bucket, owner);
    record('P2-storage', `${bucket}: ${actor} list returns nothing`, emptyOrDenied(l), l.error?.message ?? `${l.data?.length} items`);
  }
}

// verification-evidence: owner-only + staff read, MIME/size enforcement, no overwrite.
{
  const { rows } = await db.query("select name from storage.objects where bucket_id='verification-evidence' and owner_id=$1 limit 1", [A.teen_a.id]);
  const teenAPath = rows[0]?.name;
  record('P2-storage', 'verification-evidence: teen_a has a registered evidence object', Boolean(teenAPath), teenAPath ?? 'none');
  const r1 = await dl('teen_b', 'verification-evidence', teenAPath);
  record('P2-storage', 'verification-evidence: teen_b cannot download teen_a evidence', Boolean(r1.error), r1.error?.message ?? 'DOWNLOADED');
  const r2 = await dl('adult_a', 'verification-evidence', teenAPath);
  record('P2-storage', 'verification-evidence: adult_a cannot download teen_a evidence', Boolean(r2.error), r2.error?.message ?? 'DOWNLOADED');
  const r3 = await dl('anon', 'verification-evidence', teenAPath);
  record('P2-storage', 'verification-evidence: anon cannot download teen_a evidence', Boolean(r3.error), r3.error?.message ?? 'DOWNLOADED');
  const r3g = await dl('guardian', 'verification-evidence', teenAPath);
  record('P2-storage', 'verification-evidence: guardian cannot download teen identity evidence', Boolean(r3g.error), r3g.error?.message ?? 'DOWNLOADED');
  const r4 = await dl('moderator', 'verification-evidence', teenAPath);
  record('P2-storage', 'verification-evidence: moderator (staff) can download for review', !r4.error, r4.error?.message ?? '');
  const r5 = await signed('teen_b', 'verification-evidence', teenAPath);
  record('P2-storage', 'verification-evidence: teen_b cannot mint a signed URL for teen_a evidence', Boolean(r5.error), r5.error?.message ?? 'SIGNED');
  const r6 = await up('teen_b', 'verification-evidence', teenAPath, PNG, 'image/png', true);
  record('P2-storage', 'verification-evidence: teen_b cannot overwrite teen_a evidence (upsert)', Boolean(r6.error), r6.error?.message ?? 'OVERWRITTEN');
  const r6o = await up('teen_a', 'verification-evidence', teenAPath, PNG, 'image/png', true);
  record('P2-storage', 'verification-evidence: owner cannot replace submitted evidence bytes', Boolean(r6o.error), r6o.error?.message ?? 'OVERWRITTEN');
  const r7 = await rm('teen_b', 'verification-evidence', teenAPath);
  record('P2-storage', 'verification-evidence: teen_b cannot delete teen_a evidence', await stillExists('verification-evidence', teenAPath), r7.error?.message ?? `removed=${r7.removed}`);
  const r7o = await rm('teen_a', 'verification-evidence', teenAPath);
  record('P2-storage', 'verification-evidence: owner cannot delete evidence registered to a case', await stillExists('verification-evidence', teenAPath), r7o.error?.message ?? `removed=${r7o.removed}`);
  const r8 = await up('teen_b', 'verification-evidence', `${A.teen_a.id}/${randomUUID()}.jpg`);
  record('P2-storage', 'verification-evidence: teen_b cannot upload into teen_a folder', Boolean(r8.error), r8.error?.message ?? 'UPLOADED');
  const r9 = await up('teen_b', 'verification-evidence', `${A.teen_b.id}/${randomUUID()}.html`, Buffer.from('<script>alert(1)</script>'), 'text/html');
  record('P2-storage', 'verification-evidence: disallowed MIME (text/html) rejected', Boolean(r9.error), r9.error?.message ?? 'UPLOADED');
  const big = Buffer.alloc(10 * 1024 * 1024 + 1024, 0xff);
  const r10 = await up('teen_b', 'verification-evidence', `${A.teen_b.id}/${randomUUID()}.jpg`, big);
  record('P2-storage', 'verification-evidence: >10MB object rejected', Boolean(r10.error), r10.error?.message ?? 'UPLOADED');
  const l = await list('teen_b', 'verification-evidence', A.teen_a.id);
  record('P2-storage', 'verification-evidence: teen_b list of teen_a folder is empty', emptyOrDenied(l), l.error?.message ?? `${l.data?.length} items`);
  // Unregistered own upload can be deleted by its owner (abandoned upload cleanup).
  const tmp = `${A.teen_b.id}/${randomUUID()}.jpg`;
  await up('teen_b', 'verification-evidence', tmp);
  const r11 = await rm('teen_b', 'verification-evidence', tmp);
  record('P2-storage', 'verification-evidence: owner can delete an unregistered own upload', !(await stillExists('verification-evidence', tmp)), r11.error?.message ?? '');
  // Cross-account case registration with another user's evidence path.
  const r12 = await rpc(A.teen_b.client, 'submit_my_verification_evidence_v1', { p_verification_type: 'age', p_evidence_path: teenAPath });
  record('P2-storage', 'verification-evidence: teen_b cannot register teen_a evidence path as own case', denied(r12), r12.data?.code ?? r12.error?.message);
}

// profile-avatars: owner CRUD, no cross-account read/write.
{
  const path = `${A.teen_a.id}/${randomUUID()}.png`;
  const r0 = await up('teen_a', 'profile-avatars', path, PNG, 'image/png');
  record('P2-storage', 'profile-avatars: owner upload', !r0.error, r0.error?.message ?? '');
  const r1 = await dl('teen_b', 'profile-avatars', path);
  record('P2-storage', 'profile-avatars: teen_b cannot download teen_a avatar directly', Boolean(r1.error), r1.error?.message ?? 'DOWNLOADED');
  const r2 = await dl('adult_a', 'profile-avatars', path);
  record('P2-storage', 'profile-avatars: adult cannot download teen avatar directly', Boolean(r2.error), r2.error?.message ?? 'DOWNLOADED');
  const r3 = await up('teen_b', 'profile-avatars', path, PNG, 'image/png', true);
  record('P2-storage', 'profile-avatars: teen_b cannot overwrite teen_a avatar', Boolean(r3.error), r3.error?.message ?? 'OVERWRITTEN');
  const r4 = await rm('teen_b', 'profile-avatars', path);
  record('P2-storage', 'profile-avatars: teen_b cannot delete teen_a avatar', await stillExists('profile-avatars', path), `removed=${r4.removed}`);
  const r5 = await up('teen_a', 'profile-avatars', `${A.teen_a.id}/${randomUUID()}.pdf`, Buffer.from('%PDF-1.4'), 'application/pdf');
  record('P2-storage', 'profile-avatars: non-image MIME rejected', Boolean(r5.error), r5.error?.message ?? 'UPLOADED');
  const r6 = await rm('teen_a', 'profile-avatars', path);
  record('P2-storage', 'profile-avatars: owner can delete own avatar', !(await stillExists('profile-avatars', path)), r6.error?.message ?? '');
}

// chat-attachments: active users only, own folder, no read without an approved message.
{
  const path = `${A.teen_a.id}/${randomUUID()}.jpg`;
  const r0 = await up('teen_a', 'chat-attachments', path);
  record('P2-storage', 'chat-attachments: active teen can upload to own folder', !r0.error, r0.error?.message ?? '');
  const r1 = await dl('teen_b', 'chat-attachments', path);
  record('P2-storage', 'chat-attachments: non-member teen_b cannot read unattached file', Boolean(r1.error), r1.error?.message ?? 'DOWNLOADED');
  const r2 = await dl('adult_b', 'chat-attachments', path);
  record('P2-storage', 'chat-attachments: non-member adult_b cannot read', Boolean(r2.error), r2.error?.message ?? 'DOWNLOADED');
  const r3 = await up('guardian', 'chat-attachments', `${A.guardian.id}/${randomUUID()}.jpg`);
  record('P2-storage', 'chat-attachments: non-active (pending) account cannot upload', Boolean(r3.error), r3.error?.message ?? 'UPLOADED');
  const r4 = await up('teen_b', 'chat-attachments', `${A.teen_a.id}/${randomUUID()}.jpg`);
  record('P2-storage', 'chat-attachments: teen_b cannot upload into teen_a folder', Boolean(r4.error), r4.error?.message ?? 'UPLOADED');
  const r5 = await rm('teen_a', 'chat-attachments', path);
  record('P2-storage', 'chat-attachments: owner cannot delete (staff-only delete, preserves evidence)', await stillExists('chat-attachments', path), `removed=${r5.removed}`);
  const r6 = await dl('moderator', 'chat-attachments', path);
  record('P2-storage', 'chat-attachments: moderator can read for moderation', !r6.error, r6.error?.message ?? '');
  const r7 = await up('teen_a', 'chat-attachments', path, PNG, 'image/png', true);
  record('P2-storage', 'chat-attachments: owner cannot replace uploaded bytes', Boolean(r7.error), r7.error?.message ?? 'OVERWRITTEN');
}

// proof-uploads: no upload without a pending proof row; no cross-account reads.
{
  const r0 = await up('teen_a', 'proof-uploads', `${A.teen_a.id}/${randomUUID()}.jpg`);
  record('P2-storage', 'proof-uploads: upload without a pending proof registration denied', Boolean(r0.error), r0.error?.message ?? 'UPLOADED');
  const r1 = await up('teen_b', 'proof-uploads', `${A.teen_a.id}/${randomUUID()}.jpg`);
  record('P2-storage', 'proof-uploads: teen_b cannot upload into teen_a folder', Boolean(r1.error), r1.error?.message ?? 'UPLOADED');
}

// ------------------------------------------------------------------ RPC / table boundaries
// Anonymous caller.
for (const [fn, args] of [
  ['save_my_onboarding_account_v2', { p_payload: {}, p_client_request_id: reqId() }],
  ['get_my_legal_requirements', {}],
  ['admin_set_account_status_v2', { p_user_id: A.teen_a.id, p_status: 'active', p_reason_code: 'x', p_reason: 'x' }],
  ['mort_review_verification_case', { p_case_id: randomUUID(), p_status: 'verified' }],
  ['create_guardian_invite_v2', {}],
]) {
  const r = await rpc(anon, fn, args);
  record('P5-anon', `anon cannot use ${fn}`, denied(r) || r.data?.code === 'authentication_required' || r.data == null, r.error?.message ?? JSON.stringify(r.data));
}
for (const table of ['profiles', 'verification_cases', 'guardian_links', 'job_applications', 'messages', 'legal_acceptances', 'admin_audit_log', 'notifications']) {
  const r = await anon.from(table).select('*').limit(5);
  record('P5-anon', `anon reads nothing from ${table}`, emptyOrDenied(r), r.error?.message ?? `${r.data?.length} rows`);
}
{
  const r = await rpc(anon, 'get_release_mode_status');
  record('P5-anon', 'anon can read only the public release status', !r.error, r.error?.message ?? '');
}

// Teen A vs Teen B.
{
  const r1 = await A.teen_b.client.from('profiles').select('id,date_of_birth').eq('id', A.teen_a.id);
  record('P5-teen', 'teen_b cannot read teen_a profile row', emptyOrDenied(r1), `${r1.data?.length ?? 0} rows`);
  const r2 = await A.teen_b.client.from('verification_cases').select('id').eq('user_id', A.teen_a.id);
  record('P5-teen', 'teen_b cannot read teen_a verification cases', emptyOrDenied(r2), `${r2.data?.length ?? 0} rows`);
  const r3 = await A.teen_b.client.from('profiles').update({ display_name: 'pwned' }).eq('id', A.teen_a.id).select();
  record('P5-teen', 'teen_b cannot update teen_a profile', emptyOrDenied(r3), `${r3.data?.length ?? 0} rows`);
  const r4 = await A.teen_b.client.from('legal_acceptances').select('id').eq('user_id', A.teen_a.id);
  record('P5-teen', 'teen_b cannot read teen_a legal acceptances', emptyOrDenied(r4), `${r4.data?.length ?? 0} rows`);
}

// Self-escalation attempts.
for (const actor of ['teen_b', 'adult_b']) {
  const c = A[actor].client;
  const r1 = await c.from('profiles').update({ role: 'admin' }).eq('id', A[actor].id).select();
  record('P5-escalation', `${actor} cannot set own profile role`, Boolean(r1.error), r1.error?.message ?? 'UPDATED');
  const r2 = await c.from('profiles').update({ account_status: 'active' }).eq('id', A[actor].id).select();
  record('P5-escalation', `${actor} cannot set own account_status`, Boolean(r2.error), r2.error?.message ?? 'UPDATED');
  const r3 = await c.from('verification_cases').insert({ user_id: A[actor].id, verification_type: 'identity', status: 'verified', provider: 'mort_staff_review' }).select();
  record('P5-escalation', `${actor} cannot insert a pre-verified case`, Boolean(r3.error), r3.error?.message ?? 'INSERTED');
  const r4 = await rpc(c, 'mort_review_verification_case', { p_case_id: randomUUID(), p_status: 'verified' });
  record('P5-escalation', `${actor} cannot call staff verification review`, Boolean(r4.error), r4.error?.message ?? 'OK');
  const r5 = await c.from('role_requests').insert({ user_id: A[actor].id, requested_role: 'admin', status: 'pending' }).select();
  const r5ok = Boolean(r5.error);
  record('P5-escalation', `${actor} cannot self-file a role request for admin`, r5ok, r5.error?.message ?? 'INSERTED (admin queue spam; approval still requires eligibility)');
}
{
  // Teen bypassing the guardian step by writing guardian_setup_status directly.
  const { rows: [before] } = await db.query('select guardian_setup_status from public.profiles where id=$1', [A.teen_b.id]);
  const r = await A.teen_b.client.from('profiles').update({ guardian_setup_status: 'linked' }).eq('id', A.teen_b.id).select('guardian_setup_status');
  const { rows: [after] } = await db.query('select guardian_setup_status from public.profiles where id=$1', [A.teen_b.id]);
  record('P5-escalation', 'teen cannot self-assert guardian_setup_status=linked without a guardian', after.guardian_setup_status === before.guardian_setup_status,
    { error: r.error?.message, before: before.guardian_setup_status, after: after.guardian_setup_status });
  if (after.guardian_setup_status !== before.guardian_setup_status) {
    await db.query('update public.profiles set guardian_setup_status=$2 where id=$1', [A.teen_b.id, before.guardian_setup_status]);
  }
}

// Moderator vs admin.
{
  const m = A.moderator.client;
  const r1 = await rpc(m, 'admin_set_account_status_v2', { p_user_id: A.guardian.id, p_status: 'active', p_reason_code: 'x', p_reason: 'moderator attempt' });
  record('P5-staff', 'moderator cannot activate accounts (admin only)', denied(r1), r1.data?.code ?? r1.error?.message);
  const r2 = await rpc(m, 'mort_review_role_request', { p_request_id: randomUUID(), p_approve: true });
  record('P5-staff', 'moderator cannot approve role requests', Boolean(r2.error), r2.error?.message ?? 'OK');
  const r3 = await rpc(A.adult_a.client, 'mort_record_staff_document_review', { p_case_id: randomUUID(), p_decision: 'verified' });
  record('P5-staff', 'non-staff adult cannot record document reviews', denied(r3), r3.data?.code ?? r3.error?.message);
  const r4 = await rpc(A.adult_a.client, 'list_message_moderation_queue', {});
  record('P5-staff', 'non-staff adult cannot list moderation queue', denied(r4) || (Array.isArray(r4.data) && r4.data.length === 0), r4.error?.message ?? JSON.stringify(r4.data)?.slice(0, 80));
  // Staff self-review (separation of duties).
  const path = `${A.moderator.id}/${randomUUID()}.jpg`;
  await up('moderator', 'verification-evidence', path);
  const sub = await rpc(m, 'submit_my_verification_evidence_v1', { p_verification_type: 'identity', p_evidence_path: path });
  const { rows } = await db.query("select id from public.verification_cases where user_id=$1 and status='pending' order by created_at desc limit 1", [A.moderator.id]);
  let self = { data: null, error: { message: 'no case' } };
  if (okData(sub) && rows[0]) self = await rpc(m, 'mort_record_staff_document_review', { p_case_id: rows[0].id, p_decision: 'verified' });
  record('P5-staff', 'moderator cannot review their own verification case', denied(self), self.data ?? self.error?.message);
}

// Service-only operations.
{
  const r = await rpc(A.adult_a.client, 'mort_ingest_verification_provider_event', {});
  record('P5-service', 'authenticated user cannot call service-only verification ingest', Boolean(r.error), r.error?.message ?? 'OK');
  const r2 = await rpc(A.adult_a.client, 'mort_send_message', { p_conversation_id: randomUUID(), p_body: 'x' });
  record('P5-service', 'authenticated user cannot call unguarded legacy mort_send_message', Boolean(r2.error), r2.error?.message ?? 'OK');
}

// Job application status (PR #106 regression, against the real production function).
{
  const job = await rpc(A.adult_a.client, 'save_job_draft_or_publish', {
    p_job_id: null, p_client_request_id: reqId(), p_publish: true,
    p_payload: { category: 'yard_work', title: 'Rake leaves in back yard', description: 'Rake and bag leaves from the back yard, tools provided on site.', city: 'Indianapolis', state: 'IN', adult_job_amount_cents: 4000 },
  });
  const jobId = job.data?.job?.id ?? job.data?.job_id ?? job.data?.id;
  record('P5-jobs', 'adult_a publishes a job for review', okData(job) && Boolean(jobId), job.data?.code ?? job.error?.message ?? '');
  const self = await rpc(A.adult_a.client, 'mort_review_job', { p_job_id: jobId, p_approve: true });
  record('P5-jobs', 'job poster cannot approve own job (non-staff)', Boolean(self.error), self.error?.message ?? 'APPROVED');
  const appr = await rpc(A.moderator.client, 'mort_review_job', { p_job_id: jobId, p_approve: true });
  record('P5-jobs', 'moderator approves job', !appr.error, appr.error?.message ?? '');
  const elig = await rpc(A.teen_a.client, 'get_job_application_eligibility', { p_job_id: jobId });
  const apply = await rpc(A.teen_a.client, 'submit_job_application', { p_job_id: jobId, p_note: 'I can do this Saturday.', p_availability_confirmed: true });
  const appId = apply.data?.application_id ?? apply.data?.application?.id ?? apply.data?.id;
  record('P5-jobs', 'teen_a applies', okData(apply) && Boolean(appId), { elig: elig.data?.code, apply: apply.data?.code ?? apply.error?.message });
  if (appId) {
    for (const action of ['accepted', 'rejected', 'shortlisted', 'viewed']) {
      const r = await rpc(A.adult_b.client, 'update_my_job_application_status_v3', { p_application_id: appId, p_action: action, p_client_request_id: reqId() });
      record('P5-jobs', `#106 regression: adult_b cannot ${action} adult_a's application`, r.data?.code === 'application_not_available', r.data?.code ?? r.error?.message);
    }
    const tw = await rpc(A.teen_b.client, 'update_my_job_application_status_v3', { p_application_id: appId, p_action: 'withdrawn', p_client_request_id: reqId() });
    record('P5-jobs', "teen_b cannot withdraw teen_a's application", tw.data?.code === 'application_not_available', tw.data?.code ?? tw.error?.message);
    const ta = await rpc(A.teen_a.client, 'update_my_job_application_status_v3', { p_application_id: appId, p_action: 'accepted', p_client_request_id: reqId() });
    record('P5-jobs', 'teen_a cannot accept their own application', denied(ta), ta.data?.code ?? ta.error?.message);
    const rb = await A.adult_b.client.from('job_applications').select('id').eq('id', appId);
    record('P5-jobs', "adult_b cannot read adult_a's job applications", emptyOrDenied(rb), `${rb.data?.length ?? 0} rows`);
    const ok = await rpc(A.adult_a.client, 'update_my_job_application_status_v3', { p_application_id: appId, p_action: 'shortlisted', p_client_request_id: reqId() });
    record('P5-jobs', 'adult_a (poster) can shortlist', okData(ok), ok.data?.code ?? ok.error?.message ?? '');
    const { rows } = await db.query('select status::text from public.job_applications where id=$1', [appId]);
    record('P5-jobs', 'application status reflects only the poster action', rows[0]?.status === 'shortlisted', rows[0]?.status);
  }
}

// Guardian after revocation (only meaningful once guardians can activate).
{
  const { rows } = await db.query("select id, status from public.guardian_links where teen_user_id=$1 and guardian_user_id=$2", [A.teen_a.id, A.guardian.id]);
  const link = rows.find((r) => r.status === 'active');
  if (!link) {
    record('P5-guardian', 'guardian revocation test requires an active guardian link', false, 'guardian could not be activated/linked (see P4-guardian)');
  } else {
    const before = await A.guardian.client.from('profiles').select('id').eq('id', A.teen_a.id);
    record('P5-guardian', 'linked guardian can read linked teen profile', (before.data?.length ?? 0) === 1, `${before.data?.length ?? 0} rows`);
    const other = await A.guardian.client.from('profiles').select('id').eq('id', A.teen_b.id);
    record('P5-guardian', 'guardian cannot read an unlinked teen', emptyOrDenied(other), `${other.data?.length ?? 0} rows`);
    const un = await rpc(A.teen_a.client, 'unlink_guardian', { p_link_id: link.id });
    record('P5-guardian', 'teen revokes guardian link', !un.error && un.data?.ok !== false, un.error?.message ?? JSON.stringify(un.data));
    const after = await A.guardian.client.from('profiles').select('id').eq('id', A.teen_a.id);
    record('P5-guardian', 'revoked guardian can no longer read teen profile', emptyOrDenied(after), `${after.data?.length ?? 0} rows`);
    const pause = await rpc(A.guardian.client, 'mort_set_guardian_pause_v1', { p_teen_id: A.teen_a.id, p_paused: true });
    record('P5-guardian', 'revoked guardian cannot pause the teen', denied(pause), pause.data?.code ?? pause.error?.message);
  }
}

// Existing signed-in staff lose privileges when the database status changes.
// Owner SQL is fixture setup/reset only; every assertion uses the real user session.
for (const actor of ['moderator', 'admin']) {
  const { id, client } = A[actor];
  const { rows: [object] } = await db.query(
    "select name from storage.objects where bucket_id='verification-evidence' and owner_id=$1 limit 1",
    [A.teen_a.id],
  );
  if (!object) throw new Error('Staff suspension test requires existing private fixture evidence');
  const queue = () => rpc(client, 'list_message_moderation_queue', {});
  const evidence = () => dl(actor, 'verification-evidence', object.name);
  const cases = () => client.from('verification_cases').select('id').eq('user_id', A.teen_a.id);
  const queueAllowed = (r) => !r.error && Array.isArray(r.data?.items);
  const evidenceAllowed = (r) => !r.error && r.data?.size > 0;
  const casesAllowed = (r) => !r.error && Array.isArray(r.data) && r.data.length > 0;
  const before = await Promise.all([queue(), evidence(), cases()]);
  record('P5-staff', `active ${actor} can access queue, private evidence bytes and unrelated verification cases`,
    queueAllowed(before[0]) && evidenceAllowed(before[1]) && casesAllowed(before[2]));

  const suspended = await db.query(
    "update public.profiles set account_status='suspended' where id=$1 and account_status='active'", [id],
  );
  if (suspended.rowCount !== 1) throw new Error(`Expected one active replica fixture ${actor}`);
  try {
    const [auth, moderation, file, rest] = await Promise.all([client.auth.getUser(), queue(), evidence(), cases()]);
    record('P5-staff', `suspended ${actor} still presents the original valid GoTrue session`,
      !auth.error && auth.data?.user?.id === id);
    record('P5-staff', `suspended ${actor} is denied the queue RPC`,
      moderation.error?.message === 'Authorized moderation role required');
    record('P5-staff', `suspended ${actor} is denied private Storage evidence`, Boolean(file.error) && !file.data);
    record('P5-staff', `suspended ${actor} is denied unrelated verification rows by REST RLS`,
      !rest.error && Array.isArray(rest.data) && rest.data.length === 0);
  } finally {
    const restored = await db.query(
      "update public.profiles set account_status='active' where id=$1 and account_status='suspended'", [id],
    );
    if (restored.rowCount !== 1) throw new Error(`Could not restore replica ${actor} fixture`);
  }
  const after = await Promise.all([queue(), evidence(), cases()]);
  record('P5-staff', `reinstated fixture ${actor} regains scoped access on the same session`,
    queueAllowed(after[0]) && evidenceAllowed(after[1]) && casesAllowed(after[2]));
}

if (postFix) {
  const bucket = 'verification-evidence';
  const actor = 'adult_a';
  const { id, client } = A[actor];
  const path = () => `${id}/${randomUUID()}.jpg`;
  const register = (filename) => rpc(client, 'submit_my_verification_evidence_v1', {
    p_verification_type: 'identity', p_evidence_path: filename,
  });
  const staged = path();
  const upload = await up(actor, bucket, staged);
  if (upload.error) throw new Error(`Replica evidence fixture upload failed: ${upload.error.code ?? upload.error.name}`);
  const missing = await register(path());
  record('document-intake', 'case registration requires an existing owned object',
    !missing.error && missing.data?.code === 'evidence_document_missing');

  const { rows: [settings] } = await db.query(
    'select real_document_collection, maintenance_mode from public.mort_release_control where is_primary',
  );
  const setRelease = (enabled, maintenance) => db.query(
    'update public.mort_release_control set real_document_collection=$1, maintenance_mode=$2 where is_primary',
    [enabled, maintenance],
  );
  if (!settings) throw new Error('Missing replica release settings');
  try {
    for (const [enabled, maintenance, reason] of [[false, false, 'collection off'], [true, true, 'maintenance']]) {
      await setRelease(enabled, maintenance);
      const [newUpload, registration, staffRead] = await Promise.all([
        up(actor, bucket, path()), register(staged), dl('moderator', bucket, staged),
      ]);
      record('document-intake', `${reason}: Storage intake denied`, Boolean(newUpload.error));
      record('document-intake', `${reason}: registration denied`,
        !registration.error && registration.data?.code === 'document_collection_unavailable');
      record('document-intake', `${reason}: active staff can still read already uploaded synthetic bytes`,
        !staffRead.error && Buffer.from(await staffRead.data.arrayBuffer()).equals(JPEG));
    }
    await setRelease(true, false);
    const status = (from, to) => db.query(
      'update public.profiles set account_status=$1 where id=$2 and account_status=$3', [to, id, from],
    );
    if ((await status('active', 'suspended')).rowCount !== 1) throw new Error('Fixture is not active');
    try {
      const [auth, newUpload, registration] = await Promise.all([
        client.auth.getUser(), up(actor, bucket, path()), register(staged),
      ]);
      record('document-intake', 'suspended account still has original real Auth session',
        !auth.error && auth.data.user?.id === id);
      record('document-intake', 'suspended account cannot upload', Boolean(newUpload.error));
      record('document-intake', 'suspended account cannot attach prior upload',
        !registration.error && registration.data?.code === 'document_collection_unavailable');
    } finally {
      if ((await status('suspended', 'active')).rowCount !== 1) throw new Error('Could not restore fixture account');
    }
    await setRelease(false, false);
    const clean = await rm(actor, bucket, staged);
    record('document-intake', 'owner can clear unregistered fixture bytes with intake disabled',
      !clean.error && !(await stillExists(bucket, staged)) && Boolean((await dl(actor, bucket, staged)).error));
  } finally {
    await setRelease(settings.real_document_collection, settings.maintenance_mode);
  }

  for (const who of ['anon', 'teen_a', 'adult_a', 'guardian', 'moderator', 'admin']) {
    const r = await rpc(who === 'anon' ? anon : A[who].client, 'support_internal_authorize');
    record('support-internal', `${who} cannot enter the service-only support surface`, Boolean(r.error) && !r.data);
  }
}

await db.end();
const failed = results.filter((r) => !r.pass);
console.log(`\nauthz: ${results.length - failed.length}/${results.length} passed`);
fs.writeFileSync(process.env.AUTHZ_RESULTS ?? '/tmp/replica-authz.json', JSON.stringify(results, null, 2));
process.exitCode = failed.length ? 1 : 0;
