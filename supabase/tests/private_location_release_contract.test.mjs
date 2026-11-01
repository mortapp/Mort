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

const migrationReleaseRpc = migration.split('create or replace function public.get_released_job_location(')[1]
  .split('$$;')[0];

test('retired private-location proposal cannot be mistaken for the active migration', () => {
  assert.match(proposal, /SUPERSEDED\s+—\s+DO NOT APPLY/i);
  assert.doesNotMatch(proposal, /create\s+table|create\s+or\s+replace\s+function/i,
    'retired SQL must not remain executable beside the current proposal');
});

test('migration released private location binds the assignment to the application job', () => {
  assert.match(migrationReleaseRpc, /v_assignment\.job_id\s*=\s*v_job\.id/i,
    'migration must reject an assignment from another job');
  assert.match(migrationReleaseRpc, /v_assignment\.teen_user_id\s*=\s*v_user_id/i,
    'migration must bind exact release to the assigned teen');
  assert.match(migrationReleaseRpc, /v_agreement\.location_version\s*=\s*v_location\.location_version/i,
    'migration must require the confirmed location version to equal the current location version');
  assert.match(migrationReleaseRpc, /coalesce\(v_allowed, false\) is not true/i,
    'migration must fail closed on NULL or missing authorization');
});

test('migration keeps exact coordinates outside the exposed public schema', () => {
  assert.match(migration, /create table private\.job_private_locations/i,
    'exact locations must be stored in the non-exposed private schema');
  assert.doesNotMatch(migration, /create table(?: if not exists)? public\.job_private_locations/i,
    'a table in public is reachable through more data API paths than needed');
  assert.match(migration, /create table private\.job_private_location_access_events/i,
    'access auditing must also be private');
  assert.match(migration, /\(latitude is null\) = \(longitude is null\)/i,
    'coordinates must be both present or both absent; CHECK NULL semantics must not allow one-sided pairs');
});

test('migration preserves legacy address data and aborts for separate review if present', () => {
  assert.match(migration, /private_job_location_requires_legacy_address_review/i,
    'migration must stop rather than silently leave or overwrite legacy public addresses');
  assert.doesNotMatch(migration, /update\s+public\.jobs\s+set\s+exact_address/i,
    'the additive contract must not clear or overwrite existing job addresses');
  assert.doesNotMatch(migration, /insert\s+into\s+private\.job_private_locations[\s\S]{0,500}?select[\s\S]{0,250}?job\.exact_address/i,
    'the migration must not backfill or copy existing production address data');
});

test('migration location save is address-only, idempotent, and preserves prior versions', () => {
  assert.match(migration, /create table private\.job_private_location_requests/i,
    'location writes need a persistent idempotency boundary');
  assert.match(migration, /create table private\.job_private_location_history/i,
    'changed address versions must retain a restricted audit copy');
  assert.match(migration, /arrival_instructions text,[\s\S]*?access_notes text,[\s\S]*?location_version integer/i,
    'private location history must preserve the old arrival and access terms');
  assert.match(migration, /create or replace function public\.save_job_private_location_v1\(\s*p_job_id uuid,\s*p_exact_address text,\s*p_arrival_instructions text,\s*p_access_notes text,\s*p_client_request_id uuid/i,
    'the write contract accepts private address/arrival terms and a request key, not client coordinates');
  const saveStart = migration.indexOf('create or replace function public.save_job_private_location_v1(');
  const saveEnd = migration.indexOf('create or replace function public.get_released_job_location(', saveStart);
  const saveRpc = migration.slice(saveStart, saveEnd);
  assert.doesNotMatch(saveRpc, /p_latitude|p_longitude/i,
    'clients cannot provide coordinates used for private distance calculations');
  assert.match(saveRpc, /v_location\.arrival_instructions\s+is distinct from/i,
    'changing arrival instructions must version and invalidate prior consent');
  assert.match(saveRpc, /v_location\.access_notes\s+is distinct from/i,
    'changing access instructions must version and invalidate prior consent');
  assert.match(saveRpc, /idempotency_key_reused/i,
    'reusing a request key for another payload must fail closed');
  assert.match(saveRpc, /address_fingerprint/i,
    'a stable address fingerprint must preserve same-address retry idempotency');
});

test('Flutter location repository sends only the supported private-location contract', async () => {
  const flutterRepository = await readFile(
    new URL('../../flutter_mort/lib/data/repositories/trust_safety_repository.dart', import.meta.url),
    'utf8',
  );
  const methodStart = flutterRepository.indexOf('Future<void> savePrivateJobLocation(');
  const methodEnd = flutterRepository.indexOf('Future<Map<String, dynamic>> getReleasedJobLocation(', methodStart);
  const method = flutterRepository.slice(methodStart, methodEnd);

  assert.match(method, /'save_job_private_location_v1'/,
    'the active Flutter path must call the additive private-location RPC');
  assert.match(method, /'p_arrival_instructions'/,
    'arrival instructions must be sent and stored through the private contract');
  assert.match(method, /'p_access_notes'/,
    'access notes must be sent and stored through the private contract');
  assert.match(method, /'p_client_request_id':\s*_uuid\.v4\(\)/,
    'each write must have an idempotency key');
  assert.doesNotMatch(method, /'p_latitude'|'p_longitude'|'p_location_accuracy_meters'/,
    'Flutter must not supply coordinates to the private-location contract');
});

test('safety agreement snapshot binds location availability and version without embedding the address', () => {
  const start = migration.indexOf('create or replace function private.job_safety_terms(');
  const end = migration.indexOf('$$;', start);
  const terms = migration.slice(start, end);
  assert.match(terms, /private_location_version/i,
    'participants must confirm a snapshot tied to the current private location version');
  assert.match(terms, /private_location_available/i,
    'agreement must state whether a private location is configured');
  assert.doesNotMatch(terms, /exact_address|latitude|longitude/i,
    'the consent snapshot must not disclose exact address or coordinates');
});

test('migration serializes location release with location edits, assignment changes, and blocks', () => {
  const saveStart = migration.indexOf('create or replace function public.save_job_private_location_v1(');
  const saveEnd = migration.indexOf('create or replace function public.get_released_job_location(', saveStart);
  const saveRpc = migration.slice(saveStart, saveEnd);
  const saveJobLock = saveRpc.indexOf('for update');
  const locationWrite = saveRpc.indexOf('insert into private.job_private_locations');

  assert.ok(saveJobLock >= 0 && locationWrite >= 0 && saveJobLock < locationWrite,
    'location edits must lock the owning job before writing a location version');
  assert.match(saveRpc, /private\.current_role\(\)\s+is distinct from\s+'adult'/i,
    'only the active adult job owner may set exact location');
  assert.match(migrationReleaseRpc, /for share/i,
    'release must lock the assignment/agreement/location snapshot it authorizes');
  const pairLock = migrationReleaseRpc.indexOf('pg_advisory_xact_lock');
  const blockCheck = migrationReleaseRpc.indexOf('from public.user_blocks');
  assert.ok(pairLock >= 0 && blockCheck > pairLock,
    'release must share the canonical participant pair lock with block_user_v2');
  assert.match(migration, /revoke all on function public\.sync_safety_agreement_location_version\(\) from public, anon, authenticated/i,
    'trigger helper must not retain default PUBLIC execute');
});

test('migration revokes exact-location access after terminal job or assignment state', () => {
  assert.match(migrationReleaseRpc, /v_job\.status::text\s+in\s*\('cancelled',\s*'completed'\)/i,
    'both owner and assigned teen reads must stop after job cancellation or completion');
  assert.match(migrationReleaseRpc, /v_assignment\.id\s+is\s+not\s+null\s+and\s+v_assignment\.status\s+in\s*\('cancelled',\s*'completed'\)/i,
    'both sides must stop reading after assignment cancellation or completion');
  assert.match(migrationReleaseRpc, /v_pair_other\s*:=\s*v_assignment\.teen_user_id/i,
    'owner reads must also be revoked when the assigned teen and poster block each other');
  assert.match(migrationReleaseRpc, /block\.blocker_id\s*=\s*v_pair_other[\s\S]*?block\.blocked_id\s*=\s*v_user_id/i,
    'all release checks must test both directions of the actor-participant block');
});
