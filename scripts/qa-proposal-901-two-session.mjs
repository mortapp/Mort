#!/usr/bin/env node
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { spawn, execFileSync } from 'node:child_process';

const allowedContainer = 'mort-pg1711-proposal901-fresh-20261104';
const containerArg = process.argv.indexOf('--container');
const container = containerArg >= 0 ? process.argv[containerArg + 1] : '';
const databaseArg = process.argv.indexOf('--database');
const database = databaseArg >= 0 ? process.argv[databaseArg + 1] : '';
const expectLegacyBlock = process.argv.includes('--expect-legacy-block');
assert.equal(container, allowedContainer, 'refusing any non-disposable local PostgreSQL container');
assert.ok(['proposal901_legacy', 'proposal901_fixed'].includes(database), 'refusing any database except the named proposal test clones');

function dockerQuery(sql) {
  return execFileSync('docker', ['exec', container, 'psql', '-X', '-U', 'postgres', '-d', database, '-At', '-v', 'ON_ERROR_STOP=1', '-c', sql], { encoding: 'utf8' }).trim();
}

function runPsql(sql) {
  return new Promise((resolve, reject) => {
    const child = spawn('docker', ['exec', '-i', container, 'psql', '-X', '-q', '-U', 'postgres', '-d', database, '-A', '-t', '-v', 'ON_ERROR_STOP=1'], { stdio: ['pipe', 'pipe', 'pipe'], windowsHide: true });
    let stdout = '';
    let stderr = '';
    const started = performance.now();
    child.stdout.setEncoding('utf8').on('data', (chunk) => { stdout += chunk; });
    child.stderr.setEncoding('utf8').on('data', (chunk) => { stderr += chunk; });
    child.once('error', reject);
    child.once('close', (code) => resolve({ code, stdout, stderr, elapsedMs: Math.round(performance.now() - started) }));
    child.stdin.end(sql);
  });
}

function startApplicationLock(applicationId) {
  const child = spawn('docker', ['exec', '-i', container, 'psql', '-X', '-q', '-U', 'postgres', '-d', database, '-A', '-t', '-v', 'ON_ERROR_STOP=1'], { stdio: ['pipe', 'pipe', 'pipe'], windowsHide: true });
  let stdout = '';
  let stderr = '';
  child.stdout.setEncoding('utf8').on('data', (chunk) => { stdout += chunk; });
  child.stderr.setEncoding('utf8').on('data', (chunk) => { stderr += chunk; });
  child.stdin.end(`BEGIN;\nSELECT id FROM public.job_applications WHERE id='${applicationId}' FOR UPDATE;\n\\echo MORT_APPLICATION_LOCK_HELD\nSELECT pg_sleep(3);\nCOMMIT;\n`);
  const locked = new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(`application lock holder did not start; stderr=${stderr}`)), 5000);
    const poll = setInterval(() => {
      if (stdout.includes('MORT_APPLICATION_LOCK_HELD')) {
        clearInterval(poll);
        clearTimeout(timer);
        resolve();
      } else if (child.exitCode !== null) {
        clearInterval(poll);
        clearTimeout(timer);
        reject(new Error(`application lock holder exited ${child.exitCode}; stderr=${stderr}`));
      }
    }, 10);
  });
  return { child, locked };
}

assert.equal(dockerQuery('show server_version_num'), '170011', 'requires PostgreSQL 17.11');
assert.equal(dockerQuery("select count(*) from public.qa_production_migration_replay"), '73', 'requires the exact 73-migration baseline');
assert.equal(dockerQuery('select count(*) from auth.users'), '0', 'requires an empty fixture database');

const posterA = randomUUID();
const posterB = randomUUID();
const applicant = randomUUID();
const jobId = randomUUID();
const applicationId = randomUUID();
const fixtureSql = `
insert into auth.users(id,aud,role,email,encrypted_password,email_confirmed_at,raw_user_meta_data)
values
 ('${posterA}','authenticated','authenticated','${posterA}@example.test','',clock_timestamp(),jsonb_build_object('date_of_birth','1980-01-01')),
 ('${posterB}','authenticated','authenticated','${posterB}@example.test','',clock_timestamp(),jsonb_build_object('date_of_birth','1981-01-01')),
 ('${applicant}','authenticated','authenticated','${applicant}@example.test','',clock_timestamp(),jsonb_build_object('date_of_birth','2011-01-01'));
update public.profiles set role='adult'::public.mort_role, account_status='active' where id in ('${posterA}','${posterB}');
update public.profiles set role='teen'::public.mort_role, account_status='active', date_of_birth=date '2011-01-01' where id='${applicant}';
insert into public.jobs(id,poster_id,title,description,category,pay_amount,city,region,status,safety_review_status)
values ('${jobId}','${posterB}','QA lock test job','Synthetic local lock test, no real user or location data.','other',20,'Local QA','IN','open','approved');
insert into public.job_applications(id,job_id,applicant_id,status)
values ('${applicationId}','${jobId}','${applicant}','submitted');
`;
execFileSync('docker', ['exec', '-i', container, 'psql', '-X', '-U', 'postgres', '-d', database, '-v', 'ON_ERROR_STOP=1'], { input: fixtureSql, stdio: ['pipe', 'ignore', 'pipe'] });

const direct = startApplicationLock(applicationId);
await direct.locked;
const directCall = await runPsql(`
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','${posterA}',true);
select set_config('request.jwt.claims','{"sub":"${posterA}","role":"authenticated"}',true);
select public.mort_accept_job_application('${applicationId}');
commit;
`);
await new Promise((resolve, reject) => {
  if (direct.child.exitCode !== null) return direct.child.exitCode === 0 ? resolve() : reject(new Error(direct.stderr));
  direct.child.once('close', (code) => code === 0 ? resolve() : reject(new Error(direct.stderr)));
});
assert.notEqual(directCall.code, 0, `unauthorized direct acceptance unexpectedly succeeded: ${directCall.stdout}`);
assert.match(directCall.stderr, /Application not found/i, `unexpected direct denial: ${directCall.stderr}`);

if (expectLegacyBlock) {
  assert.ok(directCall.elapsedMs >= 2500, `legacy function did not reproduce its application-row lock contention (${directCall.elapsedMs}ms)`);
} else {
  assert.ok(directCall.elapsedMs < 1000, `unauthorized direct call waited for another user's application lock (${directCall.elapsedMs}ms)`);
}

const wrapper = startApplicationLock(applicationId);
await wrapper.locked;
const wrapperCall = await runPsql(`
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','${posterA}',true);
select set_config('request.jwt.claims','{"sub":"${posterA}","role":"authenticated"}',true);
select public.update_my_job_application_status('${applicationId}','accepted',null);
commit;
`);
await new Promise((resolve, reject) => {
  if (wrapper.child.exitCode !== null) return wrapper.child.exitCode === 0 ? resolve() : reject(new Error(wrapper.stderr));
  wrapper.child.once('close', (code) => code === 0 ? resolve() : reject(new Error(wrapper.stderr)));
});
assert.equal(wrapperCall.code, 0, `status wrapper failed: ${wrapperCall.stderr}`);
assert.match(wrapperCall.stdout, /application_not_available/, `status wrapper returned the wrong contract: ${wrapperCall.stdout}`);
assert.ok(wrapperCall.elapsedMs < 1000, `unauthorized wrapper waited for an application lock (${wrapperCall.elapsedMs}ms)`);

console.log(`PROPOSAL_901_TWO_SESSION=PASS database=${database} postgres=170011 unauthorized_direct_ms=${directCall.elapsedMs} wrapper_ms=${wrapperCall.elapsedMs} verification_fixtures=none`);
