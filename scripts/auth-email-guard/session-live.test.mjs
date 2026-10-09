import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {randomBytes,randomUUID} from 'node:crypto';
import {startFixtureTransports,fixtureSql,refreshFixtureApiCredentials} from './fixture.mjs';
import {pending,call,signIn,cleanup} from './provider.test.mjs';
import {probe} from './jwt-transports.test.mjs';
import {backupFixture,restoreFixture,discardBackup} from './control.mjs';
import {strictExpiryObservation} from './transport-observation.mjs';

export async function run(handle,{signedExpiry=false}={}){
  const transports=await startFixtureTransports(handle);let owner,backup;
  try{
    for(let i=0;i<100;i++){
      if(await fixtureSql(handle,"SELECT to_regclass('realtime.messages') IS NOT NULL AND to_regclass('storage.objects') IS NOT NULL")==='t')break;
      if(i===99)assert.fail('Transport migrations did not complete');
      await new Promise(resolve=>setTimeout(resolve,100));
    }
    await fixtureSql(handle,await readFile(new URL('./transport-schema.sql',import.meta.url),'utf8'));
    await fixtureSql(handle,await readFile(new URL('./session-live.sql',import.meta.url),'utf8'));
    await fixtureSql(handle,'UPDATE mort_auth_guard.control SET enabled=false');
    owner=await pending(handle);
    assert.equal((await call(handle,`/admin/users/${owner.id}`,{email_confirm:true},true,'PUT')).status,200);
    const session=await signIn(handle,owner,owner.password);assert.equal(session.status,200);
    (handle.privateAudit??=new Set()).add(session.data.access_token);
    const claims=JSON.parse(Buffer.from(session.data.access_token.split('.')[1],'base64url'));
    assert.ok(/^[0-9a-f-]{36}$/.test(claims.session_id),'Actual provider token has session_id');
    assert.equal(claims.exp-claims.iat,3600,'Original access-token lifetime is unchanged');
    await fixtureSql(handle,`INSERT INTO mort_transport.records VALUES('${owner.id}','${owner.id}','synthetic')`);
    await fetch(`${transports.storageUrl}/bucket`,{method:'POST',headers:{authorization:`Bearer ${handle.serviceKey}`,'content-type':'application/json'},body:JSON.stringify({id:'mort-fixture',name:'mort-fixture',public:false})});
    const upload=await fetch(`${transports.storageUrl}/object/mort-fixture/${owner.id}/probe.txt`,{method:'POST',headers:{authorization:`Bearer ${session.data.access_token}`,'content-type':'text/plain'},body:'synthetic'});
    assert.equal(upload.status,200,'Live session uploads its private object');
    const before=await probe(handle,session.data.access_token,owner.id);
    assert.ok(before.postgrest.accepted&&before.storage.accepted&&before.realtime.status==='ok','All three real transports accept the live owner session');
    const revoke=await fetch(`${handle.authUrl}/logout?scope=global`,{method:'POST',headers:{authorization:`Bearer ${session.data.access_token}`}});
    assert.equal(revoke.status,204,'Real provider global logout succeeds');
    const revokedAt=Date.now();
    assert.equal(await fixtureSql(handle,`SELECT count(*) FROM auth.sessions WHERE id='${claims.session_id}' AND user_id='${owner.id}'`),'0','Provider actually removes the revoked session');
    const after=await probe(handle,session.data.access_token,owner.id);
    assert.ok(after.postgrest.denied,'Revoked session cannot read owner record before token expiry');
    assert.ok(after.storage.denied,'Revoked session cannot download private object before token expiry');
    assert.equal(after.realtime.status,'error','Revoked session cannot join private channel before token expiry');
    const fresh=await signIn(handle,owner,owner.password);assert.equal(fresh.status,200);
    handle.privateAudit.add(fresh.data.access_token);
    const positive=await probe(handle,fresh.data.access_token,owner.id);
    assert.ok(positive.postgrest.accepted&&positive.storage.accepted&&positive.realtime.status==='ok','Fresh owner session retains access to all three transports');
    const nextPassword=`Bb8!${randomBytes(20).toString('base64url')}`;
    assert.equal((await call(handle,`/admin/users/${owner.id}`,{password:nextPassword},true,'PUT')).status,200,'Actual provider password replacement succeeds');
    const changedAt=Date.now();
    owner.password=nextPassword;
    const passwordDenied=await probe(handle,fresh.data.access_token,owner.id);
    assert.ok(passwordDenied.postgrest.denied&&passwordDenied.storage.denied&&passwordDenied.realtime.status==='error','Pre-password-change token is denied by all three fixture transports');
    const current=await signIn(handle,owner,owner.password);assert.equal(current.status,200,'Owner can sign in with the new password');
    handle.privateAudit.add(current.data.access_token);
    const currentPositive=await probe(handle,current.data.access_token,owner.id);
    assert.ok(currentPositive.postgrest.accepted&&currentPositive.storage.accepted&&currentPositive.realtime.status==='ok','Post-password-change owner retains all three transport paths');
    const currentClaims=JSON.parse(Buffer.from(current.data.access_token.split('.')[1],'base64url'));
    const expiredClaims={sub:owner.id,role:'authenticated',session_id:currentClaims.session_id,exp:Math.floor(Date.now()/1000)-1};
    const expiryResult=await fixtureSql(handle,`BEGIN;SET LOCAL ROLE authenticated;SELECT set_config('request.jwt.claims','${JSON.stringify(expiredClaims)}',true) IS NOT NULL;SELECT mort_fixture.session_is_live();ROLLBACK`);
    assert.ok(expiryResult.split('\n').includes('f'),'Injected expired SQL claims fail the private expiry predicate');
    const livePredicate=await fixtureSql(handle,`BEGIN;SET LOCAL ROLE authenticated;SELECT set_config('request.jwt.claims','${JSON.stringify(currentClaims)}',true) IS NOT NULL;SELECT mort_fixture.session_is_live();ROLLBACK`);
    assert.ok(livePredicate.split('\n').filter(line=>line==='t').length===2,'Actual current session claims satisfy the private predicate positive control');
    for(const sid of [undefined,'invalid',randomUUID(),claims.session_id]){
      const value={sub:owner.id,role:'authenticated',exp:currentClaims.exp,...(sid?{session_id:sid}:{})};
      assert.ok(value.exp>Math.floor(Date.now()/1000),'Invalid session cases retain a valid future expiry');
      const result=await fixtureSql(handle,`BEGIN;SET LOCAL ROLE authenticated;SELECT set_config('request.jwt.claims','${JSON.stringify(value)}',true) IS NOT NULL;SELECT mort_fixture.session_is_live();ROLLBACK`);
      assert.ok(result.split('\n').includes('f'),'Missing malformed unknown or revoked session claims cannot satisfy the private predicate');
    }
    backup=await backupFixture(handle);
    await restoreFixture(handle,backup,{localFixture:true,apply:true,privateProviderRehearsal:true});
    const restoredAt=Date.now();
    await discardBackup(handle,backup);backup=null;
    await fixtureSql(handle,'UPDATE mort_auth_guard.control SET enabled=false');
    assert.equal(await fixtureSql(handle,`SELECT count(*) FROM auth.sessions WHERE id='${currentClaims.session_id}' AND user_id='${owner.id}'`),'1','Restore retains the old session row, so generation denial is not simulated by deleting it');
    const restoreDenied=await probe(handle,current.data.access_token,owner.id);
    assert.ok(restoreDenied.postgrest.denied&&restoreDenied.storage.denied&&restoreDenied.realtime.status==='error','Pre-restore token is denied on all three transports despite its restored session row');
    const afterRestore=await signIn(handle,owner,owner.password);assert.equal(afterRestore.status,200,'Restored verified owner can sign in');
    handle.privateAudit.add(afterRestore.data.access_token);
    const restoredPositive=await probe(handle,afterRestore.data.access_token,owner.id);
    assert.ok(restoredPositive.postgrest.accepted&&restoredPositive.storage.accepted&&restoredPositive.realtime.status==='ok','Fresh post-restore owner retains all three transport paths');
    const timings=(sample,at)=>Object.fromEntries(Object.entries(sample).map(([name,value])=>[name,{status:value.status,denied:name==='realtime'?value.status==='error':value.denied,measuredAfterLifecycleMs:value.checkedAtMs-at}]));
    handle.sessionLiveEvidence={jwtLifetimeSeconds:3600,revocation:timings(after,revokedAt),passwordChange:timings(passwordDenied,changedAt),restore:timings(restoreDenied,restoredAt),scope:'owned SELECT private GET new private joins',hostedChanged:false};
    if(signedExpiry){
      const token=afterRestore.data.access_token;
      const signedClaims=JSON.parse(Buffer.from(token.split('.')[1],'base64url'));
      assert.equal(signedClaims.exp-signedClaims.iat,3600,'Guarded signed-token expiry retains the original one-hour lifetime');
      const expiryMs=signedClaims.exp*1000;
      while(Date.now()<expiryMs){
        assert.equal(await fixtureSql(handle,"SELECT count(*) FROM pg_policies WHERE policyname IN('guard_fixture_live_record','guard_fixture_live_storage','guard_fixture_live_channel')"),'3','All three session-live RLS policies remain installed during real expiry measurement');
        if(Date.now()<expiryMs-2000){
          const live=await probe(handle,token,owner.id);
          assert.ok(live.postgrest.accepted&&live.storage.accepted&&live.realtime.status==='ok','Actual unexpired live token retains all three transport paths');
        }
        const remaining=expiryMs-Date.now();
        if(remaining>0)await new Promise(resolve=>setTimeout(resolve,Math.min(30_000,remaining)));
        console.log('PROGRESS guarded signed expiry: '+JSON.stringify({remainingSeconds:Math.max(0,Math.ceil((expiryMs-Date.now())/1000)),policiesInstalled:true}));
      }
      const checkpointStartedAtMs=Date.now();
      const expired=await probe(handle,token,owner.id,{parallel:true});
      assert.ok(strictExpiryObservation(expired,{signedExpiryMs:expiryMs,startedAtMs:checkpointStartedAtMs}).withinStrictWindow,'Strict expiry collects all three actual denials by original signed expiry plus one second; delayed measurement is not PASS');
      assert.equal(await fixtureSql(handle,`SELECT count(*) FROM auth.sessions WHERE id='${signedClaims.session_id}' AND user_id='${owner.id}'`),'1','Expired-token control retains the actual session row');
      assert.equal(await fixtureSql(handle,"SELECT count(*) FROM pg_policies WHERE policyname IN('guard_fixture_live_record','guard_fixture_live_storage','guard_fixture_live_channel')"),'3','All three session-live RLS policies are installed at the signed-expiry checkpoint');
      const replacement=await signIn(handle,owner,owner.password);assert.equal(replacement.status,200,'Verified owner signs in after original signed-token expiry');
      handle.privateAudit.add(replacement.data.access_token);
      const replacementPositive=await probe(handle,replacement.data.access_token,owner.id);
      assert.ok(replacementPositive.postgrest.accepted&&replacementPositive.storage.accepted&&replacementPositive.realtime.status==='ok','Fresh actual token retains owner access after guarded expiry denial');
      handle.guardedExpiryEvidence={policy:'REJECT_BY_SIGNED_EXPIRY_PLUS_1_SECOND',jwtLifetimeSeconds:3600,signedExpiryMs:expiryMs,checkpointStartedAtMs,observations:Object.fromEntries(Object.entries(expired).map(([name,value])=>[name,{status:value.status,denied:name==='realtime'?value.status==='error':value.denied,checkedAtMs:value.checkedAtMs,afterSignedExpiryMs:value.checkedAtMs-expiryMs}])),scope:'owned SELECT private GET new private joins',policiesInstalled:true,hostedChanged:false};
    }
  }finally{
    refreshFixtureApiCredentials(handle);
    if(backup)await discardBackup(handle,backup);
    if(owner){
      const deleted=await fetch(`${transports.storageUrl}/object/mort-fixture`,{method:'DELETE',headers:{authorization:`Bearer ${handle.serviceKey}`,'content-type':'application/json'},body:JSON.stringify({prefixes:[`${owner.id}/probe.txt`]})});
      assert.ok(deleted.ok,'Session-live test removes its exact synthetic object');
    }
    await fixtureSql(handle,'DELETE FROM mort_transport.records;UPDATE mort_auth_guard.control SET enabled=false');
    await cleanup(handle);
    await fixtureSql(handle,`DROP POLICY IF EXISTS guard_fixture_live_record ON mort_transport.records;DROP POLICY IF EXISTS guard_fixture_live_storage ON storage.objects;DROP POLICY IF EXISTS guard_fixture_live_channel ON realtime.messages;DROP TRIGGER IF EXISTS mort_fixture_password_fence ON auth.users;DROP FUNCTION IF EXISTS mort_fixture.retire_password_sessions();DROP FUNCTION IF EXISTS mort_fixture.session_is_live();DROP TABLE IF EXISTS mort_fixture.credential_fences;REVOKE USAGE ON SCHEMA mort_fixture FROM authenticated`);
  }
}
