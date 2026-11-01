import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const proposal = await readFile(
  new URL('../proposals/private_job_location_lifecycle.sql', import.meta.url),
  'utf8',
);
const releaseRpc = proposal.split('create or replace function public.get_released_job_location_v1')[1]
  .split('$function$;')[0];

test('released private location is bound to the locked assignment, application, and job', () => {
  assert.match(releaseRpc, /v_assignment\.job_id\s*<>\s*v_job\.id/i,
    'assignment must still reference the job whose location was locked');
  assert.match(releaseRpc, /v_application\.job_id\s*<>\s*v_job\.id/i,
    'application must belong to the same job as the assignment and location');
});

