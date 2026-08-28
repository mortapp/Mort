import {
  assert,
  pass,
  reviewClient,
  serviceClient,
} from './play-release-qa-helpers.mjs';

const scope = 'validate-play-review-tenant';
const teen = await reviewClient('teen');
const adult = await reviewClient('adult');
const admin = serviceClient();

try {
  const { data: release, error: releaseError } = await teen.client.rpc(
    'get_release_mode_status',
  );
  assert(!releaseError && release?.ok === true, 'Release mode RPC failed.');
  assert(
    release.release_mode === 'closed_test',
    'Active release mode is not closed_test.',
  );
  assert(
    release.marketplace_mode === 'closed_pilot',
    'Marketplace mode is not closed_pilot.',
  );
  for (const flag of [
    'public_marketplace_enabled',
    'real_document_collection',
    'live_ads',
    'live_billing',
    'remote_push',
  ]) {
    assert(release[flag] === false, `${flag} is not disabled.`);
  }

  for (const entry of [
    { role: 'teen', session: teen },
    { role: 'adult', session: adult },
  ]) {
    const { data: rows, error } = await entry.session.client.rpc(
      'get_my_profile',
    );
    const profile = rows?.[0];
    assert(
      !error && profile?.role === entry.role,
      `${entry.role} profile is invalid.`,
    );
    assert(
      profile.is_test_account === true,
      `${entry.role} profile is not isolated test data.`,
    );
    assert(
      profile.account_status === 'active',
      `${entry.role} review account is restricted.`,
    );
  }

  const { data: reviewMode, error: reviewModeError } = await teen.client.rpc(
    'current_profile_is_test',
  );
  assert(
    !reviewModeError && reviewMode === true,
    'Teen review account is not in the isolated test environment.',
  );
  const { data: jobs, error: jobsError } = await teen.client
    .from('jobs')
    .select('id,is_test,pilot_review_status,pilot_organization_id')
    .eq('title', 'Play Review Yard Organizing')
    .eq('status', 'open')
    .eq('applications_open', true)
    .eq('is_test', reviewMode);
  assert(
    !jobsError && jobs.length === 1,
    'Synthetic review job is unavailable.',
  );
  assert(
    jobs[0].is_test === true && jobs[0].pilot_review_status === 'eligible',
    'Review job is not safely pilot-scoped.',
  );

  const { data: threads, error: threadError } = await teen.client
    .from('message_threads')
    .select('id,application_id,adult_id')
    .eq('adult_id', adult.user.id);
  assert(
    !threadError && threads.length === 1,
    'Synthetic job conversation is unavailable.',
  );
  const { data: messages, error: messageError } = await teen.client
    .from('messages')
    .select('id,scanner_status')
    .eq('thread_id', threads[0].id);
  assert(
    !messageError && messages.length >= 2,
    'Synthetic safe messages are unavailable.',
  );
  assert(
    messages.every((message) => message.scanner_status === 'clean'),
    'Review messages are not scanner-clean.',
  );

  const { data: contracts, error: contractError } = await teen.client
    .from('job_contracts')
    .select('id,status,active_version_id')
    .eq('application_id', threads[0].application_id);
  assert(
    !contractError && contracts.length === 1 && contracts[0].active_version_id,
    'Synthetic contract is unavailable.',
  );
  const contractId = contracts[0].id;

  const [agreements, arrivals, completions, obligations, disputes] =
    await Promise.all([
      teen.client
        .from('job_safety_agreements')
        .select('id,status')
        .eq('application_id', threads[0].application_id),
      admin
        .from('job_arrival_handshakes')
        .select('id,checkin_at,teen_checkout_at,adult_checkout_at')
        .eq('application_id', threads[0].application_id),
      teen.client
        .from('job_completion_assertions')
        .select('id,assertion_type')
        .eq('contract_id', contractId),
      teen.client
        .from('job_payment_obligations')
        .select('id,status')
        .eq('contract_id', contractId),
      teen.client
        .from('payment_disputes')
        .select('id,status,guilt_determined')
        .eq('contract_id', contractId),
    ]);
  assert(
    !agreements.error && agreements.data?.[0]?.status === 'confirmed',
    'Mutual Safety Agreement fixture is unavailable.',
  );
  assert(
    !arrivals.error &&
      arrivals.data?.[0]?.checkin_at &&
      arrivals.data?.[0]?.teen_checkout_at &&
      arrivals.data?.[0]?.adult_checkout_at,
    'Arrival/completion handshake history is unavailable.',
  );
  assert(
    !completions.error && completions.data?.length >= 2,
    'Completion events are unavailable.',
  );
  assert(
    !obligations.error && obligations.data?.[0]?.status === 'disputed',
    'Payment obligation fixture is unavailable.',
  );
  assert(
    !disputes.error && disputes.data?.[0]?.guilt_determined === false,
    'Private payment disagreement is unavailable or makes an improper guilt finding.',
  );

  const { data: partner, error: partnerError } = await adult.client.rpc(
    'get_my_partner_staff_context',
  );
  assert(
    !partnerError && partner?.items?.length === 1,
    'Partner staff context is unavailable.',
  );
  assert(
    partner.messages_included === false && partner.earnings_included === false,
    'Partner context includes prohibited data.',
  );
  const organizationId = partner.items[0].organization_id;
  const { data: roster, error: rosterError } = await adult.client.rpc(
    'get_partner_connected_participants',
    { p_organization_id: organizationId },
  );
  assert(
    !rosterError && roster?.ok === true && roster.items?.length >= 1,
    'Partner roster is unavailable.',
  );
  assert(
    roster.messages_included === false &&
      roster.earnings_included === false &&
      roster.housing_status_included === false,
    'Partner roster exposed prohibited categories.',
  );

  const { data: demoUsers, error: demoError } =
    await admin.auth.admin.listUsers({ page: 1, perPage: 1000 });
  assert(!demoError, 'Could not inspect synthetic review identities.');
  const demo = demoUsers.users.find(
    (user) =>
      user.user_metadata?.play_review_fixture === true &&
      user.user_metadata?.display_name === 'Blocked Demo Account',
  );
  assert(demo, 'Block/deletion demonstration account is unavailable.');
  const [blocks, reports, deletion] = await Promise.all([
    admin
      .from('blocks')
      .select('id')
      .eq('blocker_id', teen.user.id)
      .eq('blocked_id', demo.id),
    admin
      .from('reports')
      .select('id')
      .eq('reporter_id', teen.user.id)
      .eq('target_user_id', demo.id),
    admin
      .from('account_deletion_requests')
      .select('id,status')
      .eq('user_id', demo.id),
  ]);
  assert(
    !blocks.error && blocks.data.length === 1,
    'Block demonstration is unavailable.',
  );
  assert(
    !reports.error && reports.data.length >= 1,
    'Report demonstration is unavailable.',
  );
  assert(
    !deletion.error && deletion.data.some((row) => row.status === 'requested'),
    'Deletion demonstration is unavailable.',
  );

  const { data: verificationRows, error: verificationError } = await admin
    .from('identity_verifications')
    .select('environment,risk_flags')
    .in('user_id', [teen.user.id, adult.user.id]);
  assert(
    !verificationError && verificationRows.length >= 2,
    'Sandbox verification fixture is unavailable.',
  );
  assert(
    verificationRows.every(
      (row) =>
        row.environment === 'sandbox' &&
        row.risk_flags?.documents_collected === false,
    ),
    'Review tenant contains production or document-backed verification.',
  );

  pass(
    scope,
    'closed-test modes, password login, isolated profiles, job, conversation, contract, safety/start/completion, payment disagreement, partner scope, report, block, deletion path, and sandbox-only verification passed',
  );
} finally {
  await teen.client.auth.signOut();
  await adult.client.auth.signOut();
}
