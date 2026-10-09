import assert from 'node:assert/strict';
import {fixtureSql,configureFixtureAuth,fixtureProcessEnv} from './fixture.mjs';
import {readFile} from 'node:fs/promises';
import {randomBytes,randomUUID} from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {resolve} from 'node:path';
import {call,cleanup,pending} from './provider.test.mjs';
export async function run(handle,{logLevel='fatal',action='signup',beforeCleanup}={}){
  assert.ok(['signup','recovery'].includes(action),'Only named fixture ingress actions are allowed');
  try{
    await fixtureSql(handle,await readFile(new URL('./send-email-hook.sql',import.meta.url),'utf8'));
    await fixtureSql(handle,'UPDATE mort_auth_guard.control SET enabled=true');
    await configureFixtureAuth(handle,{sendEmail:true,logLevel});
    assert.equal(await fixtureSql(handle,"SELECT to_regprocedure('mort_fixture.send_email(jsonb)') IS NOT NULL"),'t','Real provider Send Email hook must be installed');
    let email,id;
    if(action==='recovery'){
      const user=await pending(handle);email=user.email;id=user.id;
      assert.equal((await call(handle,`/admin/users/${id}`,{email_confirm:true},true,'PUT')).status,200,'Recovery positive control is a confirmed synthetic account');
      assert.equal((await call(handle,'/recover',{email})).status,200,'Actual public provider recovery reaches the installed Send Email hook');
    }else{
      email=`qa-${randomUUID()}@mort-fixture.invalid`;
      (handle.trackedEmails??=new Set()).add(email);
      const signup=await call(handle,'/signup',{email,password:`Aa9!${randomBytes(20).toString('base64url')}`});
      assert.equal(signup.status,200,'Actual public provider signup reaches the installed Send Email hook');
      id=signup.data.id;assert.ok(id,'Provider returns the synthetic account');handle.trackedAccounts.add(id);
    }
    assert.equal(await fixtureSql(handle,`SELECT count(*) FROM mort_fixture.email_ingress WHERE account_id='${id}' AND used_at IS NULL`),'1','Provider transaction commits exactly one private ingress event');
    const certificate=resolve(import.meta.dirname,'../../.superpowers/sdd/2026-10-08-managed-email-challenge-guard/fixture/smtp.pem');
    const child=spawnSync('deno',['run','--frozen','--config','supabase/functions/auth-email-guard.deno.json','--allow-env',`--allow-read=${certificate}`,'--allow-net=127.0.0.1:55422,127.0.0.1:55424,127.0.0.1:55425,127.0.0.1:55426','supabase/functions/_shared/auth_email_guard/provider_ingress_probe.ts'],{env:{...fixtureProcessEnv(),MORT_FIXTURE_VERIFIED:'1'},input:JSON.stringify({mode:'local_fixture',fixtureId:handle.fixtureId,dbUrl:handle.dbUrl,accountId:id,certificate}),encoding:'utf8',timeout:40_000,windowsHide:true});
    const diagnostic=child.stderr.includes('ECONNREFUSED')?'connection-refused':child.stderr.includes('certificate')?'certificate':child.stderr.includes('Fixture ingress assertion failed')?'ingress-assertion':child.error?.code==='ETIMEDOUT'?'timeout':'other';
    if(child.status!==0){const stage=child.stderr.match(/Fixture ingress assertion failed: (shape|database|receipt|store|outside|wrong-secret|trusted-relay|replay|delivery)\b/)?.[1]??'unclassified';const detail=child.stderr.match(/Fixture ingress diagnostic: stage=(?:shape|database|receipt|store|outside|wrong-secret|trusted-relay|replay|delivery) name=(?:Error|TypeError|InvalidData|PermissionDenied|ConnectionRefused|ConnectionReset|TimedOut|unclassified) code=(?:[A-Z0-9_]{1,24}|unclassified)\b/)?.[0]??'no reviewed diagnostic';console.error('Fixture ingress failure category:',diagnostic,'stage:',stage,detail);}
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
