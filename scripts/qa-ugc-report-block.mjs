import { assert, pass, reviewClient, serviceClient } from './play-release-qa-helpers.mjs';

const scope = 'qa-ugc-report-block';
const teen = await reviewClient('teen');
const adult = await reviewClient('adult');
const { data: threads, error: threadError } = await teen.client.from('message_threads').select('id').eq('teen_id', teen.user.id).eq('adult_id', adult.user.id).limit(1);
assert(!threadError && threads.length === 1, 'Synthetic job-context thread is unavailable.');
const threadId = threads[0].id;
const marker = `Closed-test report QA ${Date.now()}`;

const { error: blockError } = await teen.client.from('blocks').insert({ blocker_id: teen.user.id, blocked_id: adult.user.id });
assert(!blockError || blockError.code === '23505', 'Teen could not block the adult fixture.');
const blockedSend = await adult.client.rpc('send_safe_message', { p_thread_id: threadId, p_body: 'This message must be rejected while blocked.' });
assert(blockedSend.error, 'Blocked user sent a direct message.');

const report = await teen.client.rpc('submit_safety_report', {
  p_target_user_id: adult.user.id, p_target_job_id: null, p_target_message_id: null,
  p_target_review_id: null, p_application_id: null, p_category: 'other_urgent_concern',
  p_severity: 'moderate', p_immediate_danger: false, p_details: marker,
  p_occurred_at: null, p_location_type: null,
  p_desired_outcome: 'Synthetic closed-test moderation verification.',
  p_confidential_safety_feedback: false,
});
assert(!report.error && report.data?.ok === true, 'Safety report RPC failed.');

await teen.client.from('blocks').delete().eq('blocker_id', teen.user.id).eq('blocked_id', adult.user.id);
const admin = serviceClient();
await admin.from('reports').delete().eq('reporter_id', teen.user.id).eq('details', marker);
await teen.client.auth.signOut();
await adult.client.auth.signOut();
pass(scope, 'report creation passed and a block prevented job-context messaging');
