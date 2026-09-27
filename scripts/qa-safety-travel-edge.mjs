import { randomUUID } from 'node:crypto';
import { anonKey, assertQa, qaLog, supabaseUrl, withQaUsers } from './feature-qa-helpers.mjs';

const scope = 'qa-safety-travel-edge';
assertQa(process.env.MORT_QA_LOCAL_SUPABASE === 'true', 'Safety Edge QA requires the isolated local MORT stack');
const endpoint = `${supabaseUrl}/functions/v1/safety-travel-eta`;
const missingAuth = await fetch(endpoint, {method:'POST',headers:{apikey:anonKey,'content-type':'application/json'},body:'{}'});
assertQa(missingAuth.status === 401, 'Unauthenticated route request accepted');
await withQaUsers(scope, [{key:'teen',role:'teen'}], async ({teen}) => {
  const session = await teen.client.auth.getSession();
  const token = session.data.session?.access_token;
  assertQa(token, 'Local QA session unavailable');
  const invoke = body => fetch(endpoint, {method:'POST',headers:{apikey:anonKey,authorization:`Bearer ${token}`,'content-type':'application/json'},body});
  for (const body of [JSON.stringify({applicationId:randomUUID(),latitude:39.77}), 'x'.repeat(1025), 'null']) {
    const response = await invoke(body);
    assertQa(response.status === 400, 'Forged or oversized route request accepted');
  }
  const disabled = await invoke(JSON.stringify({applicationId:randomUUID()}));
  const result = await disabled.json();
  assertQa(disabled.status === 200 && result.code === 'route_provider_disabled' && result.ok === false,
    'Default provider gate did not fail closed');
  assertQa(!('latitude' in result) && !('longitude' in result) && !('eta_minutes' in result), 'Disabled route exposed GPS or an invented ETA');
  qaLog(scope, 'actual local Edge authentication, bounded/forged input, and disabled-provider behavior verified; no provider call made');
});
