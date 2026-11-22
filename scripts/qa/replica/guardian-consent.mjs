// Opt-in consent regression. All RPC authorization uses email-confirmed local
// GoTrue sessions provisioned by journeys.mjs, not constructed JWT claims.
// Owner SQL is used only for explicitly named, disposable fixture history and
// inspection. No real documents or guardian authority records are present.
import { anonClient, randomUUID, record, rpc } from './lib.mjs';

const STATUS = 'get_teen_guardian_consent_status_v1';
const ATTEST = 'attest_teen_guardian_authority_v1';
const ASSENT = 'record_teen_guardian_assent_v1';
const CONSENT = 'accept_teen_guardian_consent_v1';
const WITHDRAW = 'withdraw_teen_guardian_consent_v1';
const INVALIDATE = 'invalidate_teen_guardian_consent_v1';
const resultCode = (r) => r.data?.code ?? r.error?.code ?? '';
const denied = (r, code = 'request_unavailable') => !r.error && r.data?.ok === false && r.data?.code === code;
const succeeded = (r, code) => !r.error && r.data?.ok === true && r.data?.code === code;
const forRequest = (id, version = 1) => ({ p_request_id: id, p_consent_version: version });
const note = (name, pass, detail = '') => record('P4-mandatory-consent', name, pass, detail);

export async function exerciseGuardianConsent({ actors, db, profileOf, activateGuardian }) {
  const { admin, moderator, guardian, guardian_other: other, adult_a: adult, teen_a: a, teen_b: b, teen_c: c } = actors;
  const call = (actor, fn, args) => rpc(actor.client, fn, args);
  const issueArgs = (teen, assignee = guardian, ref = randomUUID(), ver = 1) => ({
    p_teen_id: teen.id, p_guardian_id: assignee.id, p_authority_ref: ref, p_consent_version: ver,
  });
  const activate = (teen) => call(admin, 'admin_set_account_status_v2', {
    p_user_id: teen.id, p_status: 'active', p_reason_code: 'replica_consent', p_reason: 'Disposable consent acceptance',
  });
  const review = (id) => call(admin, 'mort_review_role_request', {
    p_request_id: id, p_approve: true, p_reason: 'Disposable consent acceptance',
  });
  const queue = async (teen) => (await db.query(
    "select id from public.role_requests where user_id=$1 and status='pending'", [teen.id],
  )).rows[0]?.id;
  const status = async (teen) => (await call(teen, STATUS)).data;

  const anonymous = await rpc(anonClient(), STATUS);
  const nonTeen = await call(guardian, STATUS);
  note('anonymous and non-teen cannot retrieve teen status', Boolean(anonymous.error) && denied(nonTeen, 'not_eligible'));
  const { rows: [acl] } = await db.query(`
    select
      (select relrowsecurity from pg_class where oid = 'private.teen_guardian_activation_consent'::regclass) as rls,
      has_table_privilege('authenticated','private.teen_guardian_activation_consent','SELECT,INSERT,UPDATE,DELETE') as auth_table,
      has_table_privilege('service_role','private.teen_guardian_activation_consent','SELECT,INSERT,UPDATE,DELETE') as service_table,
      has_function_privilege('authenticated','private.teen_guardian_activation_consent_valid(uuid)','EXECUTE') as auth_helper`);
  note('RLS enabled; no direct table rights or internal helper grant', acl.rls && !acl.auth_table && !acl.service_table && !acl.auth_helper, acl);

  const initA = await status(a);
  const initB = await status(b);
  const baseStatus = { ok: true, contract_version: 1, consent_version: 1, status: 'required', request_id: null, expires_at: null };
  note('accepted optional guardian link still leaves mandatory consent required', initA?.status === 'required');
  note('skipped optional guardian mode still leaves mandatory consent required',
    Object.entries(baseStatus).every(([key, v]) => initB?.[key] === v) && Object.keys(initB ?? {}).length === 6);
  const noQueue = await queue(b);
  const noApprove = await activate(b);
  note('account-status approval does not activate a fully verified teen who skipped monitoring and has no consent',
    !noQueue && denied(noApprove, 'activation_request_required') && (await profileOf(b))?.account_status === 'pending', resultCode(noApprove));

  // Emulate a previously queued staff request created before the new gate, not
  // a user-written request. This proves the recheck if a queue already exists.
  const { rows: [historical] } = await db.query(
    "insert into public.role_requests(user_id,requested_role,status) values($1,'teen','pending') returning id", [a.id],
  );
  const preDirect = await review(historical.id);
  const preAdmin = await activate(a);
  note('direct staff review denies a preexisting request before valid consent',
    Boolean(preDirect.error) && /required verification tracks/.test(preDirect.error.message));
  note('account-status staff review denies a preexisting request before valid consent',
    denied(preAdmin, 'activation_review_failed') && (await profileOf(a))?.account_status === 'pending', resultCode(preAdmin));

  const unauthorized = await Promise.all([moderator, guardian, adult, a].map((actor) => call(actor, ATTEST, issueArgs(a))));
  note('moderator, guardian, adult and teen cannot attest authority', unauthorized.every((r) => denied(r, 'administrator_required')));
  await db.query("update public.profiles set account_status='suspended' where id=$1", [admin.id]);
  try {
    const staleStaff = await call(admin, ATTEST, issueArgs(a));
    const staleReview = await review(historical.id);
    note('suspended staff with prior real session cannot attest or approve',
      denied(staleStaff, 'administrator_required') && Boolean(staleReview.error));
  } finally {
    await db.query("update public.profiles set account_status='active' where id=$1", [admin.id]);
  }

  const pendingGuardian = await call(admin, ATTEST, issueArgs(a, other));
  const verifiedAdult = await call(admin, ATTEST, issueArgs(a, adult));
  note('pending guardian or verified adult without guardian role is not a valid assignee',
    denied(pendingGuardian) && denied(verifiedAdult));
  await activateGuardian(other, 'guardian_other');

  const proofRef = randomUUID();
  const staleIssue = await call(admin, ATTEST, issueArgs(a, guardian, proofRef, 0));
  note('out-of-date consent version cannot be attested', denied(staleIssue, 'consent_version_required'));
  const first = await call(admin, ATTEST, issueArgs(a, guardian, proofRef));
  const firstId = first.data?.request_id ?? randomUUID();
  const issued = await status(a);
  note('active admin records relationship authority; teen status has no guardian identity/proof metadata',
    succeeded(first, 'authority_attested') && issued?.request_id === firstId
      && issued?.expires_at === first.data?.expires_at && issued?.status === 'awaiting_teen_assent'
      && Object.keys(issued).sort().join(',') === 'consent_version,contract_version,expires_at,ok,request_id,status'
      && !JSON.stringify(issued).includes(proofRef) && !JSON.stringify(issued).includes(guardian.id));
  const proofReplay = await call(admin, ATTEST, issueArgs(b, guardian, proofRef));
  note('opaque authority references cannot be reused for another teen', denied(proofReplay));

  const early = await call(guardian, CONSENT, forRequest(firstId));
  const wrongTeen = await call(b, ASSENT, forRequest(firstId));
  const invalidVersion = await call(a, ASSENT, forRequest(firstId, 2));
  note('assigned guardian needs separate teen assent; unrelated teen and wrong version cannot record it',
    denied(early) && denied(wrongTeen) && denied(invalidVersion, 'consent_version_required'));
  const assent = await call(a, ASSENT, forRequest(firstId));
  const assentReplay = await call(a, ASSENT, forRequest(firstId));
  const beforeConsent = await activate(a);
  note('current assent advances to guardian action but is one-use and cannot activate',
    succeeded(assent, 'teen_assent_recorded') && denied(assentReplay)
    && (await status(a))?.status === 'awaiting_guardian_consent' && denied(beforeConsent, 'activation_review_failed'));

  const unexpected = await Promise.all([other, adult, a, moderator].map((actor) => call(actor, CONSENT, forRequest(firstId))));
  const nonexistent = await call(guardian, CONSENT, forRequest(randomUUID()));
  note('unrelated guardian, adult, teen, staff and unknown request receive the same non-disclosing denial',
    [...unexpected, nonexistent].every((r) => denied(r)));
  const wrongVersion = await call(guardian, CONSENT, forRequest(firstId, null));
  note('missing/current-version mismatch cannot sign consent', denied(wrongVersion, 'consent_version_required'));

  const parallel = await Promise.all([1, 2].map(() => call(guardian, CONSENT, forRequest(firstId))));
  const ready = await status(a);
  note('two concurrent real-session accept attempts record exactly one consent while the teen remains pending',
    parallel.filter((r) => succeeded(r, 'guardian_consent_recorded')).length === 1
    && parallel.filter((r) => denied(r)).length === 1
    && ready?.status === 'ready_for_staff_review' && (await profileOf(a))?.account_status === 'pending',
  parallel.map(resultCode).sort().join(','));
  const direct = await review(historical.id);
  note('direct staff approval activates the correct teen after current assent and consent',
    direct.data === historical.id && (await profileOf(a))?.account_status === 'active'
    && (await profileOf(b))?.account_status === 'pending' && (await status(a))?.status === 'consent_recorded');

  const b1 = await call(admin, ATTEST, issueArgs(b));
  const bId = b1.data?.request_id ?? randomUUID();
  await call(b, ASSENT, forRequest(bId));
  await call(guardian, CONSENT, forRequest(bId));
  const queueB = await queue(b);
  const viaStatus = await activate(b);
  const guardianReadB = await guardian.client.from('profiles').select('id').eq('id', b.id);
  const { rows: [links] } = await db.query('select count(*)::int as n from public.guardian_links where teen_user_id=$1', [b.id]);
  note('normal consent queues and enables account-status approval while optional monitoring stays absent',
    Boolean(queueB) && succeeded(viaStatus, 'activation_approved') && (await profileOf(b))?.account_status === 'active'
    && links.n === 0 && !guardianReadB.data?.length);

  const c1 = await call(admin, ATTEST, issueArgs(c));
  const cExpired = c1.data?.request_id ?? randomUUID();
  await db.query(`update private.teen_guardian_activation_consent
    set issued_at=now()-interval '8 days', expires_at=now()-interval '1 day',
        teen_assented_at=now()-interval '2 days' where request_id=$1`, [cExpired]);
  const expired = await call(guardian, CONSENT, forRequest(cExpired));
  note('expired request cannot be accepted, even if the teen assented on time',
    denied(expired) && (await status(c))?.status === 'expired' && !(await queue(c)));

  const c2 = await call(admin, ATTEST, issueArgs(c));
  const cPending = c2.data?.request_id ?? randomUUID();
  const unrelatedWithdraw = await call(other, WITHDRAW, { p_request_id: cPending });
  const selfWithdraw = await call(c, WITHDRAW, { p_request_id: cPending });
  const afterPendingWithdrawal = await call(guardian, CONSENT, forRequest(cPending));
  note('pending teen withdrawal does not suspend, and neither unrelated withdrawal nor later acceptance works',
    denied(unrelatedWithdraw) && succeeded(selfWithdraw, 'consent_withdrawn') && denied(afterPendingWithdrawal)
    && (await status(c))?.status === 'withdrawn' && (await profileOf(c))?.account_status === 'pending');

  const c3 = await call(admin, ATTEST, issueArgs(c));
  const cStale = c3.data?.request_id ?? randomUUID();
  await call(c, ASSENT, forRequest(cStale));
  await call(guardian, CONSENT, forRequest(cStale));
  const queueC = await queue(c);
  await db.query('update private.teen_guardian_activation_consent set consent_version=2 where request_id=$1', [cStale]);
  const staleDirect = await review(queueC ?? randomUUID());
  const staleAdmin = await activate(c);
  const staleState = await status(c);
  note('stored consent from a noncurrent version cannot be approved on either route',
    Boolean(queueC) && Boolean(staleDirect.error) && denied(staleAdmin, 'activation_review_failed') && staleState?.status === 'required');
  const moderatorInvalidate = await call(moderator, INVALIDATE, { p_request_id: cStale, p_reason_code: 'policy_recheck' });
  const invalidate = await call(admin, INVALIDATE, { p_request_id: cStale, p_reason_code: 'policy_recheck' });
  const invalidReplay = await call(guardian, CONSENT, forRequest(cStale));
  note('only active admin can invalidate authority and the old request cannot be signed again',
    denied(moderatorInvalidate, 'administrator_required') && succeeded(invalidate, 'consent_invalidated') && denied(invalidReplay));

  const c4 = await call(admin, ATTEST, issueArgs(c));
  const cLive = c4.data?.request_id ?? randomUUID();
  await call(c, ASSENT, forRequest(cLive));
  await db.query("update public.profiles set account_status='suspended' where id=$1", [guardian.id]);
  try {
    const suspended = await call(guardian, CONSENT, forRequest(cLive));
    note('suspended assignee is denied with the existing GoTrue session',
      denied(suspended) && (await status(c))?.status === 'guardian_not_eligible');
  } finally {
    await db.query("update public.profiles set account_status='active' where id=$1", [guardian.id]);
  }
  await call(guardian, CONSENT, forRequest(cLive));
  await db.query("update public.profiles set account_status='suspended' where id=$1", [guardian.id]);
  try {
    const failed = await activate(c);
    note('accepted consent is rechecked for guardian eligibility at teen approval',
      denied(failed, 'activation_review_failed') && (await profileOf(c))?.account_status === 'pending');
  } finally {
    await db.query("update public.profiles set account_status='active' where id=$1", [guardian.id]);
  }
  const cActivated = await activate(c);
  const beforeWithdraw = await profileOf(c);
  const withdrewActive = await call(guardian, WITHDRAW, { p_request_id: cLive });
  const withdrawReplay = await call(guardian, WITHDRAW, { p_request_id: cLive });
  const afterWithdraw = await profileOf(c);
  const { rows: [history] } = await db.query(`select
    count(*)::int as retained,
    bool_or(request_id=$2 and authority_ref is not null and teen_assented_at is not null
      and guardian_consented_at is not null and close_reason='participant_withdrew'
      and closed_by=$3 and closed_at is not null) as final_evidence
    from private.teen_guardian_activation_consent where teen_id=$1`, [c.id, cLive, guardian.id]);
  const eligibility = await call(c, 'get_job_application_eligibility', { p_job_id: randomUUID() });
  const deletion = await call(c, 'get_my_account_deletion_request');
  note('guardian withdrawal suspends active teen in the same transaction and cannot be replayed',
    succeeded(cActivated, 'activation_approved') && beforeWithdraw?.account_status === 'active'
    && succeeded(withdrewActive, 'consent_withdrawn') && denied(withdrawReplay)
    && afterWithdraw?.account_status === 'suspended' && (await status(c))?.status === 'withdrawn'
    && history.retained === 4 && history.final_evidence);
  note('post-withdrawal marketplace eligibility denied; signed-in deletion status stays available',
    eligibility.data?.code === 'active_teen_account_required' && eligibility.data?.eligible === false
    && deletion.data?.ok === true && deletion.data?.request === null, resultCode(eligibility));
}
