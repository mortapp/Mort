import { assert, pass, reviewClient, serviceClient } from './play-release-qa-helpers.mjs';

const scope = 'qa-play-review-account-isolation';
const admin = serviceClient();
const { data: ordinaryProfiles, error: ordinaryError } = await admin.from('profiles').select('id').eq('is_test_account', false).limit(25);
assert(!ordinaryError, 'Could not establish the ordinary-profile isolation control set.');
for (const role of ['teen', 'adult']) {
  const { client, user } = await reviewClient(role);
  const { data: ownRows, error: selfError } = await client.rpc('get_my_profile');
  const self = ownRows?.[0];
  assert(!selfError && self?.is_test_account === true && self.role === role, `${role} fixture is not correctly isolated.`);
  if (ordinaryProfiles.length > 0) {
    const { data: leakedProfiles, error: profileError } = await client.from('profiles').select('id,display_name').in('id', ordinaryProfiles.map(({ id }) => id));
    assert(!profileError && leakedProfiles.length === 0, `${role} fixture could read an ordinary profile.`);
  }
  const { data: visibleJobs, error: jobError } = await client.from('jobs').select('id,is_test').limit(200);
  assert(!jobError, `${role} could not read its permitted job set.`);
  assert(visibleJobs.every((job) => job.is_test === true), `${role} fixture could read a non-test job.`);
  await client.auth.signOut();
}
const adult = await reviewClient('adult');
const { data: partnerContext, error: partnerError } = await adult.client.rpc('get_my_partner_staff_context');
assert(!partnerError && partnerContext?.ok === true && partnerContext.items?.length === 1, 'Adult reviewer partner context is unavailable.');
assert(partnerContext.messages_included === false && partnerContext.earnings_included === false && partnerContext.raw_identity_documents_included === false, 'Partner context exposed prohibited categories.');
await adult.client.auth.signOut();
pass(scope, 'reviewer accounts are synthetic, RLS hides ordinary profiles/jobs, and partner scope excludes prohibited data');
