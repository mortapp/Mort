import { randomBytes } from 'node:crypto';
import { anonClient, assert, pass, serviceClient } from './play-release-qa-helpers.mjs';

const scope = 'qa-under-13-block';
const admin = serviceClient();
const email = `under13-${randomBytes(8).toString('hex')}@mort.test`;
const password = `Qa!${randomBytes(20).toString('base64url')}`;
const { data: created, error: createError } = await admin.auth.admin.createUser({ email, password, email_confirm: true });
if (createError || !created.user) throw new Error('Could not create disposable age-gate QA user.');
try {
  const client = anonClient();
  const { error: signInError } = await client.auth.signInWithPassword({ email, password });
  if (signInError) throw new Error('Disposable age-gate QA sign-in failed.');
  const birth = new Date();
  birth.setUTCFullYear(birth.getUTCFullYear() - 12);
  const { error } = await client.from('profiles').update({
    role: 'teen', display_name: 'Under 13 QA', dob: birth.toISOString().slice(0, 10),
    city: 'Testville', state: 'IN', onboarding_completed: true,
  }).eq('id', created.user.id);
  assert(error, 'Server accepted under-13 onboarding.');
  assert(/13|age|profile/i.test(error.message), 'Under-13 rejection did not come from an age/profile rule.');
  pass(scope, 'server trigger rejected completion of an under-13 registration');
} finally {
  await admin.auth.admin.deleteUser(created.user.id, false);
}
