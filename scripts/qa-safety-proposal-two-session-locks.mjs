#!/usr/bin/env node
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { performance } from 'node:perf_hooks';

// Fixture-free protocol test only. This deliberately connects to the task's
// disposable local Docker database; it does not create Auth users or call
// production/hosted APIs. Full RPC races still require approved QA fixtures.
const container = process.env.MORT_LOCAL_DB_CONTAINER ?? 'mort-pg1711-reviewfresh-mort20261102';
assert.equal(container, 'mort-pg1711-reviewfresh-mort20261102', 'refusing any database other than the clean PG17.11 production-baseline container');

function query(sql) {
  return spawn('docker', [
    'exec', container, 'psql', '-U', 'postgres', '-d', 'postgres', '-X', '-qAt',
    '-v', 'ON_ERROR_STOP=1', '-c', sql,
  ], { windowsHide: true });
}

function runAndCapture(child) {
  return new Promise((resolve, reject) => {
    let stdout = '';
    let stderr = '';
    child.stdout.setEncoding('utf8').on('data', (chunk) => { stdout += chunk; });
    child.stderr.setEncoding('utf8').on('data', (chunk) => { stderr += chunk; });
    child.on('error', reject);
    child.on('close', (code) => code === 0
      ? resolve(stdout.trim())
      : reject(new Error(`local psql exited ${code}: ${stderr.trim()}`)));
  });
}

async function waitForOutput(child, phrase) {
  return new Promise((resolve, reject) => {
    let stdout = '';
    let stderr = '';
    const timeout = setTimeout(() => reject(new Error(`timed out waiting for ${phrase}`)), 10_000);
    child.stdout.setEncoding('utf8').on('data', (chunk) => {
      stdout += chunk;
      if (stdout.includes(phrase)) {
        clearTimeout(timeout);
        resolve();
      }
    });
    child.stderr.setEncoding('utf8').on('data', (chunk) => { stderr += chunk; });
    child.on('error', (error) => { clearTimeout(timeout); reject(error); });
    child.on('close', (code) => {
      if (code !== 0) {
        clearTimeout(timeout);
        reject(new Error(`local holder exited ${code}: ${stderr.trim()}`));
      }
    });
  });
}

async function assertSerialized(label, holderExpression, contenderExpression) {
  const holder = spawn('docker', [
    'exec', '-i', container, 'psql', '-U', 'postgres', '-d', 'postgres', '-X', '-qAt',
    '-v', 'ON_ERROR_STOP=1',
  ], { windowsHide: true });
  const holderDone = runAndCapture(holder);
  holder.stdin.end(`begin;\nselect pg_advisory_xact_lock(${holderExpression});\nselect 'holder_locked';\nselect pg_sleep(2.2);\ncommit;\n\\q\n`);
  await waitForOutput(holder, 'holder_locked');

  const contenderSql = `begin; select pg_try_advisory_xact_lock(${contenderExpression}); select pg_advisory_xact_lock(${contenderExpression}); select 'contender_acquired'; commit;`;
  const started = performance.now();
  const contenderOutput = await runAndCapture(query(contenderSql));
  const elapsed = performance.now() - started;
  await holderDone;

  assert.match(contenderOutput, /(?:^|\n)f(?:\n|$)/, `${label}: reversed/equivalent key must be busy while holder owns it`);
  assert.match(contenderOutput, /contender_acquired/, `${label}: waiter must acquire the lock after release`);
  assert.ok(elapsed >= 700, `${label}: contender did not demonstrably wait (${Math.round(elapsed)} ms)`);
  console.log(`[qa-safety-proposal-two-session-locks] PASS ${label}: serialized in ${Math.round(elapsed)} ms`);
}

async function assertFailFast(label, holderExpression, contenderExpression) {
  const holder = spawn('docker', [
    'exec', '-i', container, 'psql', '-U', 'postgres', '-d', 'postgres', '-X', '-qAt',
    '-v', 'ON_ERROR_STOP=1',
  ], { windowsHide: true });
  const holderDone = runAndCapture(holder);
  holder.stdin.end(`begin;\nselect pg_advisory_xact_lock(${holderExpression});\nselect 'holder_locked';\nselect pg_sleep(2.2);\ncommit;\n\\q\n`);
  await waitForOutput(holder, 'holder_locked');

  const started = performance.now();
  const contenderOutput = await runAndCapture(query(`select pg_try_advisory_xact_lock(${contenderExpression});`));
  const elapsed = performance.now() - started;
  await holderDone;

  assert.equal(contenderOutput, 'f', `${label}: a competing acceptance must fail fast while the job lock is held`);
  assert.ok(elapsed < 1_800, `${label}: contender waited instead of failing fast (${Math.round(elapsed)} ms)`);
  console.log(`[qa-safety-proposal-two-session-locks] PASS ${label}: fail-fast in ${Math.round(elapsed)} ms`);
}

const pairA = `pg_catalog.hashtextextended(least('10000000-0000-4000-8000-000000000001'::uuid,'10000000-0000-4000-8000-000000000002'::uuid)::text || ':' || greatest('10000000-0000-4000-8000-000000000001'::uuid,'10000000-0000-4000-8000-000000000002'::uuid)::text,0)`;
const pairB = `pg_catalog.hashtextextended(least('10000000-0000-4000-8000-000000000002'::uuid,'10000000-0000-4000-8000-000000000001'::uuid)::text || ':' || greatest('10000000-0000-4000-8000-000000000002'::uuid,'10000000-0000-4000-8000-000000000001'::uuid)::text,0)`;
const checkinA = `pg_catalog.hashtextextended('job-checkin-complete:10000000-0000-4000-8000-000000000001:20000000-0000-4000-8000-000000000001',0)`;
const acceptanceJobA = `pg_catalog.hashtextextended('mort-accept-job:' || '30000000-0000-4000-8000-000000000001',0)`;

await assertSerialized('accept/block/message participant-pair key', pairA, pairB);
await assertSerialized('check-in completion idempotency key', checkinA, checkinA);
await assertFailFast('same-job acceptance serialization key (protocol only)', acceptanceJobA, acceptanceJobA);
