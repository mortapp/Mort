import { assert, pass, reviewClient } from './play-release-qa-helpers.mjs';

const scope = 'qa-closed-test-marketplace-lock';
const teen = await reviewClient('teen');
const eligibility = await teen.client.rpc('get_closed_pilot_eligibility', { p_action: 'browse', p_job_id: null });
assert(!eligibility.error && eligibility.data, 'Closed-pilot policy RPC failed.');
assert(eligibility.data.unrestricted_public_access_enabled === false, 'Unrestricted public marketplace is enabled.');
assert(eligibility.data.production_identity_verification_enabled !== true, 'Production identity verification is enabled.');
await teen.client.auth.signOut();
pass(scope, 'remote policy reports unrestricted public access off and no production identity enablement');
