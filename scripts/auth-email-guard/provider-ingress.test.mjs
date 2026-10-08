import assert from 'node:assert/strict';
import {fixtureSql,configureFixtureAuth,fixtureProcessEnv} from './fixture.mjs';
import {readFile} from 'node:fs/promises';
import {randomBytes,randomUUID} from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {resolve} from 'node:path';
import {call,cleanup} from './provider.test.mjs';
export async function run(handle,{logLevel='fatal',beforeCleanup}={}){
  try{
    await fixtureSql(handle,await readFile(new URL('./send-email-hook.sql',import.meta.url),'utf8'));
    await fixtureSql(handle,'UPDATE mort_auth_guard.control SET enabled=true');
    await configureFixtureAuth(handle,{sendEmail:true,logLevel});
    assert.equal(await fixtureSql(handle,"SELECT to_regprocedure('mort_fixture.send_email(jsonb)') IS NOT NULL"),'t','Real provider Send Email hook must be installed');
    const email=`qa-${randomUUID()}@mort-fixture.invalid`;
    (handle.trackedEmails??=new Set()).add(email);
    const signup=await call(handle,'/signup',{email,password:`Aa9!${randomBytes(20).toString('base64url')}`});
    assert.equal(signup.status,200,'Actual public provider signup reaches the installed Send Email hook');
    const id=signup.data.id;assert.ok(id,'Provider returns the synthetic account');handle.trackedAccounts.add(id);
    assert.equal(await fixtureSql(handle,`SELECT count(*) FROM mort_fixture.email_ingress WHERE account_id='${id}' AND used_at IS NULL`),'1','Provider transaction commits exactly one private ingress event');
    const certificate=resolve(import.meta.dirname,'../../.superpowers/sdd/2026-10-08-managed-email-challenge-guard/fixture/smtp.pem');
    const child=spawnSync('deno',['run','--frozen','--config','supabase/functions/auth-email-guard.deno.json','--allow-env',`--allow-read=${certificate}`,'--allow-net=127.0.0.1:55422,127.0.0.1:55424,127.0.0.1:55425,127.0.0.1:55426','supabase/functions/_shared/auth_email_guard/provider_ingress_probe.ts'],{env:{...fixtureProcessEnv(),MORT_FIXTURE_VERIFIED:'1'},input:JSON.stringify({mode:'local_fixture',fixtureId:handle.fixtureId,dbUrl:handle.dbUrl,accountId:id,certificate}),encoding:'utf8',timeout:40_000,windowsHide:true});
    assert.equal(child.status,0,'Actual provider ingress relay, wrong-secret, external-path and replay assertions pass');
    assert.equal(child.stdout.trim(),'PASS provider-origin relay; outside-path, replay and wrong-secret denied; synthetic SMTP acknowledged','Probe must execute every named ingress assertion');
    handle.hookLogEvidence={addressOccurrences:(child.stdout+child.stderr).split(email).length-1,bytesInspected:Buffer.byteLength(child.stdout+child.stderr)};
    assert.equal(handle.hookLogEvidence.addressOccurrences,0,'Real guard hook relay stdout and stderr contain no synthetic address');
    if(beforeCleanup)await beforeCleanup({email,id});
  }finally{
    await configureFixtureAuth(handle);
    await fixtureSql(handle,'UPDATE mort_auth_guard.control SET enabled=false;DELETE FROM mort_fixture.email_ingress;DELETE FROM mort_auth_guard.families;DELETE FROM mort_auth_guard.quota_events;DELETE FROM mort_auth_guard.account_generations');
    await cleanup(handle);
    await fetch(`${handle.captureUrl}/api/v1/messages`,{method:'DELETE'});
  }
}
