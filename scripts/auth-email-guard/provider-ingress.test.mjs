import assert from 'node:assert/strict';
import {fixtureSql,configureFixtureAuth,fixtureProcessEnv} from './fixture.mjs';
import {readFile,writeFile,unlink} from 'node:fs/promises';
import {randomBytes,randomUUID} from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {resolve} from 'node:path';
import {call,cleanup,pending,signIn} from './provider.test.mjs';
import {planControl,applyLocalControl,fixtureDirectory} from './control.mjs';
import {recordSubprocessFailure} from './subprocess-diagnostic.mjs';
export async function run(handle,{logLevel='fatal',action='signup',recoveryScenario,beforeCleanup}={}){
  assert.ok(['signup','recovery'].includes(action),'Only named fixture ingress actions are allowed');
  const recoveryAuditPath=recoveryScenario?resolve(fixtureDirectory,`recovery-audit-${randomUUID()}.json`):undefined;
  let phase='install';
  try{
    await fixtureSql(handle,await readFile(new URL('./send-email-hook.sql',import.meta.url),'utf8'));
    await fixtureSql(handle,'UPDATE mort_auth_guard.control SET enabled=true');
    phase='configure';
    await configureFixtureAuth(handle,{sendEmail:true,logLevel});
    assert.equal(await fixtureSql(handle,"SELECT to_regprocedure('mort_fixture.send_email(jsonb)') IS NOT NULL"),'t','Real provider Send Email hook must be installed');
    let email,id;
    if(action==='recovery'){
      phase='create-account';
      const user=await pending(handle);email=user.email;id=user.id;
      phase='confirm-account';
      assert.equal((await call(handle,`/admin/users/${id}`,{email_confirm:true},true,'PUT')).status,200,'Recovery positive control is a confirmed synthetic account');
      if(recoveryScenario){
        phase='activate-baseline';
        await applyLocalControl(await planControl('activate',handle),handle,{localFixture:true,apply:true,privateProviderRehearsal:true});
        phase='baseline-signin';
        assert.equal((await signIn(handle,user,user.password)).status,200,'Verified baseline recovery account signs in before reset');
      }
      phase='provider-recover';
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
    if(recoveryAuditPath)await writeFile(recoveryAuditPath,'[]',{mode:0o600});
    const child=spawnSync('deno',['run','--frozen','--config','supabase/functions/auth-email-guard.deno.json','--allow-env',`--allow-read=${certificate}`,...(recoveryAuditPath?[`--allow-write=${recoveryAuditPath}`]:[]),'--allow-net=127.0.0.1:55421,127.0.0.1:55422,127.0.0.1:55424,127.0.0.1:55425,127.0.0.1:55426','supabase/functions/_shared/auth_email_guard/provider_ingress_probe.ts'],{env:{...fixtureProcessEnv(),MORT_FIXTURE_VERIFIED:'1'},input:JSON.stringify({mode:'local_fixture',fixtureId:handle.fixtureId,dbUrl:handle.dbUrl,accountId:id,certificate,...(recoveryScenario?{recoveryScenario,privateAuditPath:recoveryAuditPath,authUrl:handle.authUrl,serviceKey:handle.serviceKey,anonKey:handle.anonKey}: {})}),encoding:'utf8',timeout:40_000,windowsHide:true});
    recordSubprocessFailure(child);
    if(recoveryAuditPath){
      const credentials=JSON.parse(await readFile(recoveryAuditPath,'utf8'));
      assert.ok(Array.isArray(credentials)&&(child.status!==0||credentials.length>=1)&&credentials.every(value=>typeof value==='string'&&value.length<=4096),'Recovery child supplies privately tracked credentials for sink audit');
      for(const value of credentials)(handle.privateAudit??=new Set()).add(value);
      assert.ok(credentials.every(value=>!(child.stdout+child.stderr).includes(value)),'Recovery child diagnostics contain no privately generated credentials');
    }
    assert.equal(child.status,0,'Actual provider ingress relay, wrong-secret, external-path and replay assertions pass');
    assert.equal(child.stdout.trim(),'PASS provider-origin relay; outside-path, replay and wrong-secret denied; synthetic SMTP acknowledged'+(recoveryScenario?'\nPASS real recovery '+recoveryScenario+' controls':''),'Probe must execute every named ingress assertion');
    if(recoveryScenario==='replace')assert.ok(child.stdout.includes('PASS real recovery replace controls'),'Real recovery replaces password and signs in; wrong and reused links and reused capability are denied');
    if(recoveryScenario==='expired')assert.ok(child.stdout.includes('PASS real recovery expired controls'),'Expired recovery link changes no password and issues no capability');
    handle.hookLogEvidence={addressOccurrences:(child.stdout+child.stderr).split(email).length-1,bytesInspected:Buffer.byteLength(child.stdout+child.stderr)};
    assert.equal(handle.hookLogEvidence.addressOccurrences,0,'Real guard hook relay stdout and stderr contain no synthetic address');
    if(beforeCleanup)await beforeCleanup({email,id});
  }catch(error){
    const categories=new Map([['Fixture transition failed closed (redacted)','transition'],['Fixture provider resume health failed','resume-health'],['Fixture provider logging privacy rejected','logging-privacy']]);
    console.error(`Fixture recovery setup failed: phase=${phase} category=${categories.get(error.message)??'unclassified'}`);
    throw error;
  }finally{
    if(recoveryAuditPath)await unlink(recoveryAuditPath).catch(error=>{if(error.code!=='ENOENT')throw error;});
    await configureFixtureAuth(handle);
    await fixtureSql(handle,'UPDATE mort_auth_guard.control SET enabled=false;DELETE FROM mort_fixture.email_ingress;DELETE FROM mort_auth_guard.families;DELETE FROM mort_auth_guard.quota_events;DELETE FROM mort_auth_guard.account_generations');
    await cleanup(handle);
    await fetch(`${handle.captureUrl}/api/v1/messages`,{method:'DELETE'});
  }
}
