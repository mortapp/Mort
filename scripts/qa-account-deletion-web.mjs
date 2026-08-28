import { assert, pass, read } from './play-release-qa-helpers.mjs';

const scope = 'qa-account-deletion-web';
const html = read('web/public/account-deletion/index.html');
const script = read('web/public/assets/account-deletion.js');
assert(html.includes('deletion-link-form') && html.includes('submit-deletion'), 'External deletion controls are missing.');
assert(script.includes('signInWithOtp') && script.includes('shouldCreateUser: false'), 'External ownership verification is unsafe or missing.');
assert(script.includes("client.rpc('request_account_deletion'"), 'External flow does not create a deletion request.');
assert(script.includes("client.rpc('get_my_account_deletion_request'"), 'External flow does not show status.');
pass(scope, 'external deletion uses magic-link ownership verification and the server deletion request RPC');
