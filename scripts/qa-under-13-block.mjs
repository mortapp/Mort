import { randomBytes, randomUUID } from 'node:crypto';
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
  const { data, error } = await client.rpc('save_my_onboarding_age', {
    p_dob: birth.toISOString().slice(0, 10),
    p_client_request_id: randomUUID(),
  });
  assert(!error, 'Canonical age gate returned a transport or database error.');
  assert(
    data?.ok === false && data?.code === 'under_13_not_eligible',
    'Canonical age gate did not return the under-13 rejection code.',
  );
  pass(scope, 'canonical server age gate rejected an under-13 registration');
} finally {
  await admin.auth.admin.deleteUser(created.user.id, false);
}
