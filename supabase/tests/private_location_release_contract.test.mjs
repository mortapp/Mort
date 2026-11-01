import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const proposal = await readFile(
  new URL('../proposals/private_job_location_lifecycle.sql', import.meta.url),
  'utf8',
);
const migration = await readFile(
  new URL('../migrations/20261101123000_private_location_and_block_message_contract.sql', import.meta.url),
  'utf8',
);

const proposalReleaseRpc = proposal.split('create or replace function public.get_released_job_location_v1')[1]
  .split('$function$;')[0];
const migrationReleaseRpc = migration.split('create or replace function public.get_released_job_location(')[1]
  .split('$$;')[0];

test('proposal released private location is bound to the locked assignment, application, and job', () => {
  assert.match(proposalReleaseRpc, /v_assignment\.job_id\s*<>\s*v_job\.id/i,
    'assignment must still reference the job whose location was locked');
  assert.match(proposalReleaseRpc, /v_application\.job_id\s*<>\s*v_job\.id/i,
    'application must belong to the same job as the assignment and location');
});

test('migration released private location binds the assignment to the application job', () => {
  assert.match(migrationReleaseRpc, /v_assignment\.job_id\s*=\s*v_job\.id/i,
    'migration must reject an assignment from another job');
  assert.match(migrationReleaseRpc, /v_assignment\.teen_user_id\s*=\s*v_user_id/i,
    'migration must bind exact release to the assigned teen');
  assert.match(migrationReleaseRpc, /v_agreement\.location_version\s*=\s*v_location\.location_version/i,
    'migration must require reconfirmation for changed locations');
  assert.match(migrationReleaseRpc, /coalesce\(v_allowed, false\) is not true/i,
    'migration must fail closed on NULL or missing authorization');
});
