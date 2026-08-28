import { assert, pass, read } from './play-release-qa-helpers.mjs';

const scope = 'qa-account-deletion-enumeration';
const source = read('web/public/assets/account-deletion.js');
const generic = 'This page never confirms whether an account exists.';
assert(source.includes('shouldCreateUser: false'), 'Deletion links could create an account.');
assert(
  /finally\s*\{[\s\S]*result\.textContent\s*=\s*['"][^'"]*This page never confirms whether an account exists\./.test(source),
  'Success and error paths do not share a generic finally response.',
);
assert(source.split(generic).length - 1 === 1, 'Generic response should have one shared source of truth.');
assert(!/error\.message|console\.(log|error)|user\.email/.test(source), 'Deletion page exposes backend/account detail.');
pass(scope, 'public request-link success and error paths do not disclose account existence');
