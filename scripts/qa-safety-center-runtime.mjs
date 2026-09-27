import { randomUUID } from 'node:crypto';
import { assertQa, qaLog, withDatabase, withQaUsers, saveJob, updateApplicationStatus, confirmSafetyAgreement } from './feature-qa-helpers.mjs';

const scope = 'qa-safety-center-runtime';
await withQaUsers(scope, [
  { key: 'teen', role: 'teen' }, { key: 'outsider', role: 'teen' },
  { key: 'guardian', role: 'guardian' }, { key: 'contact', role: 'adult' },
  { key: 'poster', role: 'adult' },
  { key: 'moderator', role: 'admin' }, { key: 'specialist', role: 'admin' },
], async ({ teen, outsider, guardian, contact, poster, moderator, specialist }) => {
  const initial = await teen.client.rpc('get_my_safety_runtime');
  assertQa(!initial.error && initial.data?.ok === true,
    `Safety runtime is unavailable: ${initial.error?.message ?? initial.data?.code}`);
  await withDatabase(async db => {
    await db.query(`insert into public.guardian_connections(teen_id,guardian_id,status)
      values($1,$2,'active')`, [teen.id, guardian.id]);
    await db.query(`insert into public.safety_circle_members
      (teen_id,contact_id,relationship_label,status,invite_code_hash,invite_expires_at)
      values($1,$2,'Trusted QA contact','active',extensions.digest('synthetic','sha256'),now()+interval '1 day')`,
      [teen.id, contact.id]);
  });
  const request = randomUUID();
  const params = { p_action: 'alert', p_application_id: null,
    p_payload: {}, p_client_request_id: request };
  const sent = await teen.client.rpc('perform_safety_action', params);
  assertQa(!sent.error && sent.data?.ok === true,
    `Alert failed: ${sent.error?.message ?? sent.data?.code}`);
  assertQa(sent.data.guardian_queued === 1 && sent.data.trusted_queued === 1,
    'Explicit alert did not queue both authorized recipient types');
  assertQa(sent.data.delivery_confirmed === false, 'Queue acknowledgment claimed device delivery');
  assertQa(new Date(sent.data.sharing_expires_at) - new Date(sent.data.acknowledged_at) === 3600000,
    'Alert did not create exactly 60 minutes of sharing');
  const eventId = sent.data.event_id;
  const replay = await teen.client.rpc('perform_safety_action', params);
  assertQa(replay.data?.event_id === eventId && replay.data?.replayed === true,
    'Alert replay created another event');
  const changed = await teen.client.rpc('perform_safety_action', {
    ...params, p_action: 'share',
  });
  assertQa(changed.data?.code === 'safety_request_payload_mismatch', 'Payload substitution accepted');
  for (const person of [guardian, contact, outsider]) {
    const start = await person.client.rpc('perform_safety_action', {
      ...params, p_action: 'extend_sharing', p_client_request_id: randomUUID(),
    });
    assertQa(start.data?.code === (person === outsider ? 'location_share_not_active' : 'active_teen_required'),
      `Recipient could extend teen tracking: ${start.error?.message ?? start.data?.code}`);
  }
  const hidden = await outsider.client.rpc('get_safety_event_status', { p_event_id: eventId });
  assertQa(hidden.data?.code === 'safety_event_not_authorized', 'Unrelated teen read safety event');
  const snapshot = await teen.client.rpc('record_safety_device_snapshot', {
    p_application_id: null, p_battery_percent: 5, p_saver_enabled: true,
    p_latitude: 39.77, p_longitude: -86.16, p_location_at: new Date().toISOString(),
    p_expected_actor_id: teen.id,
  });
  assertQa(snapshot.data?.ok === true, `Device snapshot rejected: ${snapshot.error?.message ?? snapshot.data?.code}`);
  const unavailableBattery = await teen.client.rpc('record_safety_device_snapshot', {
    p_application_id:null,p_battery_percent:null,p_saver_enabled:true,
    p_latitude:null,p_longitude:null,p_location_at:null,p_expected_actor_id:teen.id,
  });
  assertQa(unavailableBattery.data?.ok === true, 'A missing battery reading blocked the heartbeat');
  const view = await guardian.client.rpc('get_safety_event_status', { p_event_id: eventId });
  assertQa(view.data?.ok === true && view.data.latitude === 39.77 && view.data.battery_percent === 5,
    'Authorized active share did not expose the confirmed snapshot');
  const rawLocation = await poster.client.from('job_location_share_sessions').select('latitude,longitude').eq('owner_id', teen.id);
  assertQa(!rawLocation.error && rawLocation.data.length === 0, 'Poster read raw precise location');
  await withDatabase(db => db.query("update public.profiles set blocked_until=now()+interval '1 hour' where id=$1", [teen.id]));
  const suspendedView = await guardian.client.rpc('get_safety_event_status', { p_event_id: eventId });
  assertQa(suspendedView.data?.code === 'safety_event_not_authorized', 'Suspended teen retained recipient tracking access');
  const suspendedAction = await teen.client.rpc('perform_safety_action', { ...params, p_client_request_id: randomUUID() });
  assertQa(suspendedAction.data?.code === 'active_teen_required', 'Suspended teen started a new sharing window');
  await withDatabase(db => db.query('update public.profiles set blocked_until=null where id=$1', [teen.id]));
  await withDatabase(async db => {
    await db.query('begin');
    await db.query("select set_config('mort.internal_update','true',true)");
    await db.query("select set_config('mort.onboarding_completion','true',true)");
    await db.query("update public.profiles set role='adult',dob='1990-01-15' where id=$1", [teen.id]);
    await db.query('commit');
  });
  const ageOutView = await guardian.client.rpc('get_safety_event_status', { p_event_id: eventId });
  assertQa(ageOutView.data?.code === 'safety_event_not_authorized', 'Aged-out teen retained guardian tracking access');
  await withDatabase(async db => {
    await db.query('begin');
    await db.query("select set_config('mort.internal_update','true',true)");
    await db.query("select set_config('mort.onboarding_completion','true',true)");
    await db.query("update public.profiles set role='teen',dob='2011-01-15' where id=$1", [teen.id]);
    await db.query('commit');
  });
  const stopped = await teen.client.rpc('perform_safety_action', {
    ...params, p_action: 'stop_sharing', p_client_request_id: randomUUID(),
  });
  assertQa(stopped.data?.ok === true, 'Teen could not stop sharing');
  const ended = await guardian.client.rpc('get_safety_event_status', { p_event_id: eventId });
  assertQa(ended.data?.live_sharing === false, 'Stopped share still claimed to be live');
  await withDatabase(async db => {
    await db.query(`update public.guardian_connections set status='revoked'
      where teen_id=$1 and guardian_id=$2`, [teen.id, guardian.id]);
  });
  const revoked = await guardian.client.rpc('get_safety_event_status', { p_event_id: eventId });
  assertQa(revoked.data?.code === 'safety_event_not_authorized', 'Revoked guardian retained event access');
  const expiredRequest = await teen.client.rpc('perform_safety_action', {
    ...params, p_payload: { requested_at: new Date(Date.now() - 7200000).toISOString() },
    p_client_request_id: randomUUID(),
  });
  assertQa(expiredRequest.data?.ok === true && new Date(expiredRequest.data.sharing_expires_at) < new Date(),
    'Delayed alert silently restarted a fresh tracking window');
  const noNewTracking = await teen.client.rpc('get_authorized_location_shares');
  assertQa(noNewTracking.data?.length === 0, 'Expired queued alert created active location tracking');
  const routineCount = await withDatabase(async db => {
    const rows = await db.query('select count(*)::int count from public.notifications where recipient_id=$1', [contact.id]);
    return rows.rows[0].count;
  });
  await teen.client.rpc('create_safety_ping_v2', { p_status: 'ok', p_note: null,
    p_job_id: null, p_immediate_danger: false, p_client_request_id: randomUUID() });
  const after = await withDatabase(async db => {
    const rows = await db.query('select count(*)::int count from public.notifications where recipient_id=$1', [contact.id]);
    return rows.rows[0].count;
  });
  assertQa(after === routineCount, 'Trusted contact received a routine successful check-in notification');
  const actorSwap = await outsider.client.rpc('record_safety_device_snapshot', {
    p_application_id: null, p_battery_percent: 50, p_saver_enabled: false,
    p_latitude: null, p_longitude: null, p_location_at: null, p_expected_actor_id: teen.id,
  });
  assertQa(actorSwap.data?.code === 'safety_actor_changed', 'Account switch accepted another teen device snapshot');
  const forbiddenWorker = await teen.client.rpc('escalate_missed_job_checkins');
  assertQa(forbiddenWorker.error, 'Teen could run service worker');
  const job = await saveJob(poster.client);
  assertQa(job.result?.ok === true, 'Safety QA job did not publish');
  const application = await teen.client.rpc('submit_job_application', {
    p_job_id: job.result.job.id, p_note: 'Available for supervised organizing work.',
    p_availability_confirmed: true, p_portfolio_ids: [],
  });
  assertQa(application.data?.ok === true, `Safety application failed: ${application.error?.message ?? application.data?.code}`);
  const appId = application.data.application.id;
  const accepted = await updateApplicationStatus(poster.client, { applicationId: appId, action: 'accepted' });
  assertQa(accepted.data?.ok === true, `Safety acceptance failed: ${accepted.error?.message ?? accepted.data?.code}`);
  await confirmSafetyAgreement(teen.client, poster.client, appId);
  const arrivalRequest = randomUUID();
  const arrivalArgs = { p_application_id: appId, p_response: 'worker_arrived_device_unavailable', p_client_request_id: arrivalRequest };
  const forgedArrival = await outsider.client.rpc('record_worker_connection_response', arrivalArgs);
  assertQa(forgedArrival.data?.code === 'job_poster_required', 'Outsider fabricated poster arrival statement');
  const arrivalClaim = await poster.client.rpc('record_worker_connection_response', arrivalArgs);
  assertQa(arrivalClaim.data?.statement_only === true, 'Poster arrival was not recorded as an unverified statement');
  const arrivalReplay = await poster.client.rpc('record_worker_connection_response', arrivalArgs);
  assertQa(arrivalReplay.data?.replayed === true, 'Arrival response retry was not idempotent');
  const arrivalState = await teen.client.rpc('get_job_safety_runtime', { p_application_id: appId });
  assertQa(arrivalState.data?.job_status === 'accepted' && arrivalState.data?.travel_state !== 'arrived',
    'Poster arrival statement started work or fabricated teen arrival');
  const forgedRoute = await teen.client.rpc('safety_server_claim_route', { p_actor_id: teen.id, p_application_id: appId });
  assertQa(forgedRoute.error, 'Client could access service-only route coordinates');
  const trip = await teen.client.rpc('perform_safety_action', { ...params, p_action: 'travel', p_application_id: appId,
    p_payload: { travel_mode: 'WALK' }, p_client_request_id: randomUUID() });
  assertQa(trip.data?.ok === true, 'Explicit manual trip failed');
  await teen.client.rpc('record_safety_device_snapshot', { p_application_id: appId, p_battery_percent: 50,
    p_saver_enabled: false, p_latitude: 39.77, p_longitude: -86.16,
    p_location_at: new Date().toISOString(), p_expected_actor_id: teen.id });
  await withDatabase(async db => {
    await db.query('begin');
    try {
      await db.query("select set_config('request.jwt.claim.role','service_role',true)");
      await db.query(`insert into public.job_private_locations(job_id,poster_id,exact_address,latitude,longitude)
        values($1,$2,'Synthetic local QA destination',39.78,-86.15)
        on conflict(job_id) do update set latitude=excluded.latitude,longitude=excluded.longitude`, [job.result.job.id,poster.id]);
      const claimed = (await db.query('select public.safety_server_claim_route($1,$2) result', [teen.id,appId])).rows[0].result;
      assertQa(claimed.ok === true, `Service route context unavailable: ${claimed.code}`);
      const duplicate = (await db.query('select public.safety_server_claim_route($1,$2) result', [teen.id,appId])).rows[0].result;
      assertQa(duplicate.code === 'route_update_deferred', 'Provider route budget was not bounded');
      const substituted = (await db.query('select public.safety_server_record_route($1,$2,$3,600) result', [teen.id,appId,randomUUID()])).rows[0].result;
      assertQa(substituted.ok === false, 'Stale or forged route result changed ETA');
      const recorded = (await db.query('select public.safety_server_record_route($1,$2,$3,600) result', [teen.id,appId,claimed.request_id])).rows[0].result;
      assertQa(recorded.ok === true, 'Scoped synthetic route duration rejected');
      await db.query("select set_config('request.jwt.claim.sub',$1,true)", [poster.id]);
      const projection = (await db.query('select public.get_job_safety_runtime($1) result', [appId])).rows[0].result;
      assertQa(projection.nearby === true && projection.eta_range_min === 10 && projection.eta_minutes == null &&
        !('latitude' in projection), 'Poster ETA projection exposed exact location or failed the Nearby boundary');
      await db.query("update public.guardian_connections set status='active' where teen_id=$1 and guardian_id=$2", [teen.id,guardian.id]);
      await db.query("select set_config('request.jwt.claim.sub',$1,true)", [guardian.id]);
      const guardianProjection = (await db.query('select public.list_guardian_safety_status() result')).rows[0].result.teens[0];
      assertQa(guardianProjection.eta_minutes == null && guardianProjection.eta_range_min === 10 && guardianProjection.eta_range_max === 15,
        'Guardian arrival projection exposed an exact ETA instead of a range');
      await db.query(`update public.guardian_preferences set accepted_job_summary=false,job_checkin_alerts=false,safety_ping_alerts=false
        where link_id in (select id from public.guardian_connections where teen_id=$1 and guardian_id=$2)`, [teen.id,guardian.id]);
      const masked = (await db.query('select public.list_guardian_safety_status() result')).rows[0].result.teens[0];
      assertQa(masked.job_title == null && masked.eta_range_min == null && masked.last_checkin_at == null && masked.safety_state == null,
        'Disabled guardian preferences leaked a protected Safety projection');
      await db.query("select set_config('request.jwt.claim.sub',$1,true)", [poster.id]);
      await db.query("update private.safety_device_state set eta_observed_at=now()-interval '6 minutes' where teen_id=$1", [teen.id]);
      const stale = (await db.query('select public.get_job_safety_runtime($1) result', [appId])).rows[0].result;
      assertQa(stale.nearby === false && stale.eta_range_min == null, 'Expired route still claimed the worker was Nearby');
    } finally { await db.query('rollback'); }
  });
  const version = await withDatabase(async db => (await db.query(`select v.id from public.job_contract_versions v
    join public.job_contracts c on c.id=v.contract_id where c.application_id=$1 order by v.version_number desc limit 1`, [appId])).rows[0]);
  assertQa(version, 'Accepted Safety fixture did not create a contract version');
  for (const party of [teen, poster]) {
    const confirmation = await party.client.rpc('confirm_job_contract_version', {
      p_contract_version_id: version.id, p_affirmative_checkbox: true,
      p_confirmation_text: 'I reviewed and confirm this exact job agreement.',
      p_platform: 'qa', p_app_version: 'qa-safety-local',
    });
    assertQa(confirmation.data?.ok === true, `Canonical contract confirmation failed: ${confirmation.error?.message ?? confirmation.data?.code}`);
  }
  await withDatabase(async db => {
    await db.query('begin');
    await db.query("select set_config('mort.internal_update','true',true)");
    await db.query("update public.applications set status='in_progress' where id=$1", [appId]);
    await db.query("update public.guardian_connections set status='active' where teen_id=$1", [teen.id]);
    await db.query(`update private.safety_device_state set application_id=$2,safety_state='normal',
      last_seen_at=now(),next_checkin_at=now()-interval '1 second',missed_online_checks=0 where teen_id=$1`, [teen.id, appId]);
    await db.query('commit');
  });
  const contactCount = async () => withDatabase(async db =>
    (await db.query('select count(*)::int count from public.notifications where recipient_id in ($1,$2)', [guardian.id, contact.id])).rows[0].count);
  const newerJob = await saveJob(poster.client, {title:'QA Later Accepted Library Task'});
  assertQa(newerJob.result?.ok === true, 'Second legitimate QA job did not publish');
  const newerApplication = await teen.client.rpc('submit_job_application', {
    p_job_id: newerJob.result.job.id, p_note:'Available for a later organizing task.',
    p_availability_confirmed:true, p_portfolio_ids:[],
  });
  assertQa(newerApplication.data?.ok === true, 'Second job application failed');
  const newerAccepted = await updateApplicationStatus(poster.client, {
    applicationId:newerApplication.data.application.id, action:'accepted',
  });
  assertQa(newerAccepted.data?.ok === true, 'Second job acceptance failed');
  const prioritized = await teen.client.rpc('get_my_safety_runtime');
  assertQa(prioritized.data?.application_id === appId && prioritized.data?.job_status === 'in_progress',
    'A newer accepted job displaced the actual work in progress');
  const baseline = await contactCount();
  await withDatabase(db => db.query('select private.escalate_missed_job_checkins_worker()'));
  assertQa(await contactCount() === baseline, 'First online miss alerted family');
  let state = await teen.client.rpc('get_my_safety_runtime');
  assertQa(state.data?.safety_state === 'checkin_missed', 'First miss state incorrect');
  await withDatabase(db => db.query("update private.safety_device_state set next_checkin_at=now()-interval '1 second',last_seen_at=now() where teen_id=$1", [teen.id]));
  await withDatabase(db => db.query('select private.escalate_missed_job_checkins_worker()'));
  assertQa(await contactCount() === baseline + 2, 'Second miss did not alert both contacts once');
  state = await teen.client.rpc('get_my_safety_runtime');
  assertQa(state.data?.safety_state === 'attention', 'Second miss incorrectly classified as emergency');
  const checkin = await withDatabase(async db => (await db.query("select id from public.job_checkins where application_id=$1 and status='pending' order by expected_at desc limit 1", [appId])).rows[0]);
  const completed = await teen.client.rpc('complete_active_job_checkin', { p_checkin_id: checkin.id, p_client_request_id: randomUUID() });
  assertQa(completed.data?.ok === true, 'Canonical completion failed');
  state = await teen.client.rpc('get_my_safety_runtime');
  assertQa(state.data?.safety_state === 'normal', 'Successful check-in did not reset miss state');
  const offlineBase = await contactCount();
  for (const [minutes, expected, count] of [[2,'connection_lost',0],[5,'connection_lost',2],[15,'attention',2]]) {
    await withDatabase(db => db.query("update private.safety_device_state set last_seen_at=now()-make_interval(mins=>$2::int)-interval '1 second' where teen_id=$1", [teen.id, minutes]));
    await withDatabase(db => db.query('select private.escalate_missed_job_checkins_worker()'));
    state = await teen.client.rpc('get_my_safety_runtime');
    assertQa(state.data?.safety_state === expected && await contactCount() === offlineBase + count,
      `Offline ${minutes}-minute boundary or notification deduplication failed`);
  }
  const unchanged = await withDatabase(async db => (await db.query('select status from public.applications where id=$1', [appId])).rows[0]);
  assertQa(unchanged.status === 'in_progress', 'Offline worker punished job state');
  // A locked UI sends no job identifier. Only the explicit action resolves
  // authenticated current work, and retries retain the original response.
  const contextualAlert = await teen.client.rpc('perform_safety_action', { ...params, p_client_request_id: randomUUID() });
  assertQa(contextualAlert.data?.ok === true, 'Explicit contextual alert failed');
  const alertJob = await withDatabase(async db => (await db.query('select job_id from public.safety_pings where id=$1', [contextualAlert.data.event_id])).rows[0]);
  assertQa(alertJob.job_id === job.result.job.id, 'Locked emergency action omitted current authorized job context');
  const exit = await teen.client.rpc('perform_safety_action', { ...params, p_action: 'exit', p_application_id: appId, p_client_request_id: randomUUID() });
  assertQa(exit.data?.ok === true, `Safety Exit required a PIN or failed: ${exit.error?.message ?? exit.data?.code}`);
  const protectedState = await teen.client.rpc('get_my_safety_runtime');
  assertQa(protectedState.data?.review_hold === true && protectedState.data?.job_status === 'disputed', 'Safety Exit did not preserve review/dispute');
  // Synthetic local provider result only; proves atomic bookkeeping, not a
  // real Stripe charge/refund. Roll back every financial fixture after reading.
  await withDatabase(async db => {
    await db.query('begin');
    try {
      await db.query("select set_config('request.jwt.claim.role','service_role',true)");
      await db.query("select set_config('mort.internal_update','true',true)");
      const context = (await db.query(`select c.id contract_id,v.id version_id,o.id obligation_id
        from public.job_contracts c join public.job_contract_versions v on v.contract_id=c.id
        join public.job_payment_obligations o on o.contract_version_id=v.id
        where c.application_id=$1 order by v.version_number desc limit 1`, [appId])).rows[0];
      assertQa(context, 'Canonical contract/obligation missing from Safety fixture');
      const paymentId = randomUUID(), resolutionId = randomUUID();
      await db.query(`insert into private.stripe_job_payment_intents(id,contract_id,contract_version_id,obligation_id,
        adult_id,teen_id,environment,earnings_amount_cents,service_fee_cents,total_amount_cents,currency_code,
        transfer_group,idempotency_key,status) values($1,$2,$3,$4,$5,$6,'test',100,0,100,'USD',$7,$8,'funded')`,
        [paymentId,context.contract_id,context.version_id,context.obligation_id,poster.id,teen.id,
          'MORT_JOB_'+paymentId.replaceAll('-',''),'safety-qa-payment-'+paymentId]);
      await db.query(`insert into private.stripe_payment_resolutions(id,environment,resolution_source,contract_id,
        payment_intent_id,eligibility_path,transfer_amount_cents,refund_amount_cents,currency_code,status,
        review_request_id,transfer_idempotency_key,refund_idempotency_key)
        values($1,'test','human_dispute_review',$2,$3,'authorized_safety_exit_payment',0,100,'USD',
        'financial_execution_started',$4,$5,$6)`,
        [resolutionId,context.contract_id,paymentId,randomUUID(),'safety-qa-transfer-'+resolutionId,'safety-qa-refund-'+resolutionId]);
      const recorded = await db.query(`select public.stripe_server_record_resolution_result($1,'test',null,'re_SafetySyntheticQA','succeeded',null) result`, [resolutionId]);
      assertQa(recorded.rows[0].result?.status === 'completed', 'Provider acknowledgment was blocked by Safety');
      const jobState = (await db.query('select status from public.applications where id=$1', [appId])).rows[0];
      assertQa(jobState.status === 'disputed', 'Provider acknowledgment fabricated safe job completion');
    } finally { await db.query('rollback'); }
  });
  await withDatabase(async db => {
    await db.query('begin');
    await db.query("select set_config('mort.internal_update','true',true)");
    await db.query('savepoint attempted_completion');
    let rejected = false;
    try { await db.query("update public.applications set status='completed' where id=$1", [appId]); }
    catch (error) { rejected = error.message.includes('safety_review_hold'); }
    await db.query('rollback to savepoint attempted_completion');
    assertQa(rejected, 'Safety review hold allowed forced completion');
    await db.query('rollback');
  });
  const posterEvent = await poster.client.rpc('get_safety_event_status', { p_event_id: exit.data.event_id });
  assertQa(posterEvent.data?.code === 'safety_event_not_authorized', 'Poster read private Safety Exit event');
  const privateCancellation = await poster.client.from('safety_cancellations').select('details').eq('application_id', appId);
  assertQa(!privateCancellation.error && privateCancellation.data.length === 0, 'Poster read the teen’s private cancellation narrative');
  const posterSafety = await poster.client.rpc('get_job_safety_runtime', { p_application_id: appId });
  assertQa(posterSafety.data?.ok === true && posterSafety.data.last_checkin_at == null,
    'Poster received individual six-minute check-in history');
  const safetyContact = await guardian.client.rpc('open_safety_contact', { p_event_id: exit.data.event_id, p_target: 'poster' });
  assertQa(safetyContact.data?.ok === true, `Safety Contact did not open: ${safetyContact.error?.message ?? safetyContact.data?.code}`);
  const contactThread = safetyContact.data.thread_id;
  const normalThread = await withDatabase(async db => (await db.query('select id from public.message_threads where application_id=$1', [appId])).rows[0]);
  assertQa(contactThread !== normalThread?.id, 'Safety Contact exposed the private job conversation');
  const sentContact = await guardian.client.rpc('send_safe_message_v2', {
    p_thread_id: contactThread, p_body: 'Please remain available while we check on this job.', p_client_request_id: randomUUID(),
  });
  assertQa(!sentContact.error, `Authorized guardian Safety Contact send failed: ${sentContact.error?.message}`);
  const posterContact = await poster.client.rpc('get_safety_contact_thread', { p_thread_id: contactThread });
  assertQa(posterContact.data?.messages?.length === 1, 'Poster could not read the isolated safety conversation');
  const privateChat = await guardian.client.rpc('list_thread_messages_page', { p_thread_id: normalThread.id });
  assertQa(privateChat.error, 'Guardian acquired ordinary job chat access');
  const unrelatedContact = await outsider.client.rpc('get_safety_contact_thread', { p_thread_id: contactThread });
  assertQa(unrelatedContact.data?.code === 'safety_contact_not_authorized', 'Unrelated teen read Safety Contact');
  await withDatabase(db => db.query("update public.guardian_connections set status='revoked' where teen_id=$1 and guardian_id=$2", [teen.id, guardian.id]));
  const revokedContact = await poster.client.rpc('get_safety_contact_thread', { p_thread_id: contactThread });
  assertQa(revokedContact.data?.code === 'safety_contact_not_authorized', 'Safety Contact remained active after recipient revocation');
  const reportRequest = randomUUID();
  const reportParams = { p_categories: ['harassment','threats'], p_details: '', p_target_user_id: poster.id,
    p_target_job_id: job.result.job.id, p_target_message_id: null, p_target_review_id: null,
    p_immediate_danger: false, p_client_request_id: reportRequest };
  const report = await teen.client.rpc('submit_safety_report_categories', reportParams);
  assertQa(report.data?.ok === true, `Optional-text report failed: ${report.error?.message ?? report.data?.code}`);
  const reportReplay = await teen.client.rpc('submit_safety_report_categories', reportParams);
  assertQa(reportReplay.data?.report_id === report.data.report_id && reportReplay.data?.replayed, 'Report retry created a duplicate');
  const protectedReport = await poster.client.from('reports').select('details').eq('id', report.data.report_id);
  assertQa(!protectedReport.error && protectedReport.data.length === 0, 'Reported poster read private report text');
  const tagged = await withDatabase(async db => (await db.query('select selected_safety_categories,severity from public.reports where id=$1', [report.data.report_id])).rows[0]);
  assertQa(tagged.selected_safety_categories.length === 2 && tagged.severity === 'high', 'Multi-category report lost tags or downgraded threats');
  const sharedAgain = await teen.client.rpc('perform_safety_action', { ...params, p_action: 'share', p_application_id: appId,
    p_client_request_id: randomUUID() });
  assertQa(sharedAgain.data?.ok === true, 'Explicit sharing during Safety review failed');
  const adultExitRequest = randomUUID();
  const adultExitParams = { p_application_id: appId, p_client_request_id: adultExitRequest };
  const forgedAdultExit = await outsider.client.rpc('perform_adult_safety_exit', adultExitParams);
  assertQa(forgedAdultExit.data?.code === 'job_poster_required', 'Unrelated user ended a job for Safety');
  const adultExit = await poster.client.rpc('perform_adult_safety_exit', adultExitParams);
  assertQa(adultExit.data?.ok === true && adultExit.data.money_moved === false && adultExit.data.fault_determined === false,
    `Adult Safety end failed or determined guilt/payment: ${adultExit.error?.message ?? adultExit.data?.code}`);
  const adultExitReplay = await poster.client.rpc('perform_adult_safety_exit', adultExitParams);
  assertQa(adultExitReplay.data?.cancellation_id === adultExit.data.cancellation_id && adultExitReplay.data?.replayed,
    'Adult Safety end retry created duplicate evidence/cases');
  const preservedSharing = await contact.client.rpc('get_safety_event_status', { p_event_id: sharedAgain.data.event_id });
  assertQa(preservedSharing.data?.live_sharing === true, 'Poster Safety end stopped teen-owned emergency sharing');
  const childReport = await teen.client.rpc('submit_safety_report_categories', {
    ...reportParams, p_categories: ['child_safety_concern'], p_client_request_id: randomUUID(),
  });
  assertQa(childReport.data?.ok === true, 'Sensitive report failed');
  await withDatabase(async db => {
    await db.query("insert into public.admin_role_assignments(user_id,role,grant_reason) values($1,'moderator','Isolated Safety scope QA'),($2,'child_safety_specialist','Isolated Safety scope QA')", [moderator.id, specialist.id]);
  });
  const caseId = childReport.data.incident_id;
  const unauthorizedStaff = await moderator.client.rpc('get_staff_safety_context', { p_incident_id: caseId, p_reason: 'Review the case-specific safety state.' });
  assertQa(unauthorizedStaff.data?.code === 'incident_reviewer_required', 'General moderator accessed sensitive child safety context');
  const authorizedStaff = await specialist.client.rpc('get_staff_safety_context', { p_incident_id: caseId, p_reason: 'Review the case-specific safety state.' });
  assertQa(authorizedStaff.data?.ok === true, 'Child safety specialist was denied authorized context');
  const unexplainedClose = await specialist.client.rpc('admin_update_incident_case', { p_incident_id: caseId, p_status: 'resolved',
    p_public_status_note: 'The case was reviewed by authorized staff.', p_restricted_note: null, p_severity: null });
  assertQa(unexplainedClose.data?.ok === false, 'Sensitive case was closed without a review rationale');
  const unauthorizedManifest = await moderator.client.rpc('get_incident_evidence_manifest', { p_incident_id: caseId });
  assertQa(unauthorizedManifest.error, 'General moderator bypassed sensitive evidence scope');
  const unauthorizedClose = await moderator.client.rpc('admin_update_incident_case', { p_incident_id: caseId, p_status: 'resolved',
    p_public_status_note: 'QA attempted an unauthorized case resolution.', p_restricted_note: null, p_severity: null });
  assertQa(unauthorizedClose.data?.code === 'incident_reviewer_required', 'General moderator resolved a child safety case');
  const forgedStaff = await outsider.client.rpc('get_staff_safety_context', { p_incident_id: caseId, p_reason: 'admin=true claimed by client is not authority' });
  assertQa(forgedStaff.data?.code === 'incident_reviewer_required', 'Client-forged admin authority accessed safety context');
  qaLog(scope, 'child safety staff separation, evidence manifest denial, unauthorized case mutation denial, and client admin forgery denial');
  qaLog(scope, 'isolated Safety Contact, scanner send, ordinary chat denial, revocation, private cancellation/report, optional narrative, multi-category replay');
  qaLog(scope, 'first/second online miss, successful reset, 2/5/15 offline, no job penalty, PIN-free exit, review hold, actor swap, worker authorization');
  qaLog(scope, 'alert, both recipient queues, truthful delivery, replay, owner-only sharing, isolation, revocation, and routine privacy');
});
