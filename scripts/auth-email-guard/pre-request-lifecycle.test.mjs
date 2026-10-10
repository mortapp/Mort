import assert from 'node:assert/strict';
import {randomBytes} from 'node:crypto';
import {run as requestGate} from './pre-request.test.mjs';
import {startFixture,fixtureSql} from './fixture.mjs';
import {call,signIn} from './provider.test.mjs';
import {backupFixture,restoreFixture,discardBackup} from './control.mjs';
import {captureAssertions} from './evidence.mjs';
import {measureRequestGateLoad} from './request-gate-load.mjs';
export async function run(handle){
  let executed=false,backup;
  await requestGate(handle,{verifyLifecycle:async({owner,fresh,paths,request})=>{
    executed=true;
    const observations=[];
    const claims=token=>JSON.parse(Buffer.from(token.split('.')[1],'base64url'));
    const verify=async(event,oldToken,current,eventAt)=>{
      assert.ok(claims(oldToken).exp*1000>Date.now()+30000,'Lifecycle denial uses a token with more than30 seconds remaining');
      for(const [index,[path,method]] of paths.entries()){
        const old=await request(path,oldToken,method),elapsedMs=Date.now()-eventAt;
        const label=['table','view','rpc'][index];
        assert.equal(old.status,401,`${event}DeniesOldTokenWithin30s_${label}`);
        assert.equal(old.data.message,'Session ended',`${event} denial uses session-live reason_${label}`);
        assert.ok(elapsedMs<=30000,`${event} fixed30-second lifecycle margin_${label}`);
        assert.equal((await request(path,current,method)).status,200,`${event}FreshSessionControl_${label}`);
        observations.push({event,surface:label,elapsedMs,denialReason:'Session ended',freshAccepted:true});
      }
    };
    // The parent suite already runs real global revocation. Repeat independently for this complete nine-case set.
    let old=fresh.data.access_token;
    const logout=await fetch(handle.authUrl+'/logout?scope=global',{method:'POST',headers:{authorization:'Bearer '+old},signal:AbortSignal.timeout(4000)});
    assert.equal(logout.status,204,'Lifecycle set uses real provider global revocation');
    let eventAt=Date.now(),current=await signIn(handle,owner,owner.password);
    assert.equal(current.status,200,'Fresh revoked owner signs in');
    await verify('globalRevocation',old,current.data.access_token,eventAt);
    old=current.data.access_token;const oldClaims=claims(old);
    const next=`Cc7!${randomBytes(20).toString('base64url')}`;
    assert.equal((await call(handle,'/admin/users/'+owner.id,{password:next},true,'PUT')).status,200,'Real Admin path replaces synthetic password');
    eventAt=Date.now();owner.password=next;current=await signIn(handle,owner,next);
    assert.equal(current.status,200,'Fresh owner signs in after actual password replacement');
    const passwordFence=JSON.parse(await fixtureSql(handle,`SELECT json_build_object('sessionPresent',EXISTS(SELECT 1 FROM auth.sessions WHERE id='${oldClaims.session_id}'),'credentialFence',EXISTS(SELECT 1 FROM mort_fixture.credential_fences f JOIN auth.sessions s ON s.user_id=f.account_id WHERE s.id='${oldClaims.session_id}' AND s.created_at<f.not_before))`));
    assert.ok(!passwordFence.sessionPresent||passwordFence.credentialFence,'Admin password path removes session or trigger fence independently rejects it');
    await verify('passwordChange',old,current.data.access_token,eventAt);
    old=current.data.access_token;const restoredClaims=claims(old);
    backup=await backupFixture(handle);
    try{await restoreFixture(handle,backup,{localFixture:true,apply:true,privateProviderRehearsal:true});}
    finally{if(backup){await discardBackup(handle,backup);backup=null;}}
    eventAt=Date.now();
    await fixtureSql(handle,'UPDATE mort_auth_guard.control SET enabled=false;UPDATE mort_fixture.pre_request_control SET enabled=true;NOTIFY pgrst,\'reload config\'');
    const reason=JSON.parse(await fixtureSql(handle,`SELECT json_build_object('sessionPresent',EXISTS(SELECT 1 FROM auth.sessions WHERE id='${restoredClaims.session_id}'),'generationFence',EXISTS(SELECT 1 FROM auth.sessions s CROSS JOIN mort_auth_guard.control c WHERE s.id='${restoredClaims.session_id}' AND s.created_at<c.session_not_before))`));
    assert.equal(reason.sessionPresent,true,'preRestoreTokenDeniedByGeneration retains restored session');
    assert.equal(reason.generationFence,true,'preRestoreTokenDeniedByGeneration proves generation boundary');
    current=await signIn(handle,owner,owner.password);assert.equal(current.status,200,'Fresh restored verified owner signs in');
    await verify('restore',old,current.data.access_token,eventAt);
    await fixtureSql(handle,'GRANT USAGE ON SCHEMA mort_transport TO service_role;GRANT EXECUTE ON FUNCTION mort_transport.guard_probe_rpc() TO service_role');
    for(const enabled of [false,true]){
      await fixtureSql(handle,'UPDATE mort_fixture.pre_request_control SET enabled='+String(enabled));
      assert.equal((await request('rpc/guard_probe_rpc',handle.serviceKey,'POST')).status,200,'serviceRoleUnchanged preserves authorized synthetic RPC control');
    }
    const load=await measureRequestGateLoad({setEnabled:enabled=>fixtureSql(handle,'UPDATE mort_fixture.pre_request_control SET enabled='+String(enabled)),request:signal=>request(paths[0][0],current.data.access_token,'GET',signal)});
    assert.equal(load.requests,400,'latencyReported executes400 bounded positive requests');
    assert.ok(load.elapsedMs<60000,'latencyReported preserves fixed60-second wall budget');
    assert.equal(observations.length,9,'All nine request-gate lifecycle combinations execute');
    handle.preRequestLifecycleEvidence={observations,passwordFence,restoreReason:reason,load,thresholdMs:30000,hostedChanged:false};
    console.log('OBSERVED nine pre-request lifecycles: '+JSON.stringify(handle.preRequestLifecycleEvidence));
  }});
  assert.equal(executed,true,'Lifecycle extension executes rather than silently skipping new tests');
}
if(process.argv[1]&&import.meta.filename===process.argv[1]){
  try{const handle=await startFixture();const proof=await captureAssertions('pre-request-lifecycle',()=>run(handle));console.log('PASS pre-request lifecycle assertions: '+proof.length);}
  catch(e){console.error('FAIL lifecycle '+JSON.stringify({assertion:e.guardAssertion??null,name:e.name==='AssertionError'?'AssertionError':'Error'}));process.exitCode=1;}
}
