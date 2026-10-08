import assert from 'node:assert/strict';
import WebSocket from 'ws';
import {randomBytes} from 'node:crypto';
import {readFile} from 'node:fs/promises';
import {startFixtureTransports,fixtureSql} from './fixture.mjs';
import {pending,call,signIn,cleanup} from './provider.test.mjs';
import {backupFixture,restoreFixture,discardBackup} from './control.mjs';
const pause=ms=>new Promise(r=>setTimeout(r,ms));
async function realtimeJoin(handle,token,id){
  return new Promise(resolve=>{
    const ws=new WebSocket(`ws://127.0.0.1:55433/socket/websocket?apikey=${handle.anonKey}&vsn=1.0.0`,{headers:{Host:'realtime-dev.localhost'}});
    const timer=setTimeout(()=>finish('timeout'),8000);
    function finish(status){clearTimeout(timer);ws.removeAllListeners();ws.on('error',()=>{});ws.terminate();resolve(status);}
    ws.on('open',()=>ws.send(JSON.stringify({topic:`realtime:guard:${id}`,event:'phx_join',ref:'1',payload:{access_token:token,config:{private:true,broadcast:{self:true},presence:{enabled:false},postgres_changes:[]}}})));
    ws.on('message',bytes=>{let message;try{message=JSON.parse(bytes)}catch{return}if(message.ref==='1'&&message.event==='phx_reply')finish(message.payload.status)});
    ws.on('unexpected-response',(_request,response)=>{response.resume();finish(`http_${response.statusCode}`)});
    ws.on('error',()=>finish('connection_rejected'));
    ws.on('close',()=>finish('connection_rejected'));
  });
}
async function probe(handle,token,id){
  const headers={authorization:`Bearer ${token}`};
  const rest=await fetch(`http://127.0.0.1:55431/records?id=eq.${id}`,{headers,signal:AbortSignal.timeout(4000)});
  let rows=[];try{rows=await rest.json()}catch{}
  const storage=await fetch(`http://127.0.0.1:55432/object/authenticated/mort-fixture/${id}/probe.txt`,{headers,signal:AbortSignal.timeout(4000)});
  const text=await storage.text();
  return {postgrest:{status:rest.status,accepted:rest.ok&&Array.isArray(rows)&&rows.length===1&&rows[0].value==='synthetic',denied:[401,403].includes(rest.status)||(rest.ok&&Array.isArray(rows)&&rows.length===0)},storage:{status:storage.status,accepted:storage.ok&&text==='synthetic',denied:[400,401,403,404].includes(storage.status)},realtime:{status:await realtimeJoin(handle,token,id)}};
}
function accepted(result){return result.postgrest.accepted&&result.storage.accepted&&result.realtime.status==='ok'}
export async function run(handle){
  const transports=await startFixtureTransports(handle);let backup;
  const rehearsal={localFixture:true,apply:true,privateProviderRehearsal:true};
  try{
    for(let i=0;i<100;i++){
      if(await fixtureSql(handle,"SELECT to_regclass('realtime.messages') IS NOT NULL AND to_regclass('storage.objects') IS NOT NULL")==='t')break;
      if(i===99)assert.fail('Transport migrations did not complete');await pause(100);
    }
    await fixtureSql(handle,await readFile(new URL('./transport-schema.sql',import.meta.url),'utf8'));
    await pause(1000);
    const bucket=await fetch(`${transports.storageUrl}/bucket`,{method:'POST',headers:{authorization:`Bearer ${handle.serviceKey}`,'content-type':'application/json'},body:JSON.stringify({id:'mort-fixture',name:'mort-fixture',public:false})});
    const actualBucket=await fetch(`${transports.storageUrl}/bucket/mort-fixture`,{headers:{authorization:`Bearer ${handle.serviceKey}`}});
    const bucketData=await actualBucket.json();
    assert.ok(actualBucket.status===200&&bucketData.id==='mort-fixture'&&bucketData.public===false,'Synthetic private bucket is available');
    const observations=[];
    for(const event of ['password_change','session_revocation','restore']){
      await fixtureSql(handle,'UPDATE mort_auth_guard.control SET enabled=false');
      const user=await pending(handle);
      assert.equal((await call(handle,`/admin/users/${user.id}`,{email_confirm:true},true,'PUT')).status,200);
      const session=await signIn(handle,user,user.password);assert.equal(session.status,200,'Old-token test uses an actual provider-issued access token');
      const token=session.data.access_token,claims=JSON.parse(Buffer.from(token.split('.')[1],'base64url'));
      handle.privateAudit.add(token);
      await fixtureSql(handle,`INSERT INTO mort_transport.records VALUES('${user.id}','${user.id}','synthetic')`);
      const upload=await fetch(`${transports.storageUrl}/object/mort-fixture/${user.id}/probe.txt`,{method:'POST',headers:{authorization:`Bearer ${token}`,'content-type':'text/plain'},body:'synthetic'});
      assert.equal(upload.status,200,'Actual owner uploads a private synthetic object');
      const before=await probe(handle,token,user.id);
      assert.ok(accepted(before),'Each real transport accepts the owner token before lifecycle change');
      const outsider=await probe(handle,handle.anonKey,user.id);
      assert.ok(outsider.postgrest.denied&&outsider.storage.denied&&['error','http_401','http_403'].includes(outsider.realtime.status),'Anonymous token cannot read owner record object or private channel');
      const began=Date.now();
      if(event==='password_change'){
        assert.equal((await call(handle,`/admin/users/${user.id}`,{password:`Bb8!${randomBytes(20).toString('base64url')}`},true,'PUT')).status,200,'Supported provider password change succeeds');
      }else if(event==='session_revocation'){
        const revoke=await fetch(`${handle.authUrl}/logout?scope=global`,{method:'POST',headers:{authorization:`Bearer ${token}`}});
        assert.equal(revoke.status,204,'Actual provider global session revocation succeeds');
        assert.notEqual((await call(handle,'/token?grant_type=refresh_token',{refresh_token:session.data.refresh_token})).status,200,'Revoked refresh token is rejected by Auth');
      }else{
        backup=await backupFixture(handle);
        await restoreFixture(handle,backup,rehearsal);await discardBackup(handle,backup);backup=null;
        assert.notEqual((await call(handle,'/token?grant_type=refresh_token',{refresh_token:session.data.refresh_token})).status,200,'Restored old refresh session is rejected by the epoch hook');
      }
      const changedAt=Date.now();
      const after=await probe(handle,token,user.id);await pause(5000);const later=await probe(handle,token,user.id);
      assert.ok(accepted(after)&&accepted(later),'Finding: old JWT retains owner access on all three stateless transports');
      observations.push({event,before,after,later,lifecycleMs:changedAt-began,measuredAcceptanceMs:Date.now()-changedAt,jwtLifetimeSeconds:claims.exp-claims.iat,remainingDeclaredSeconds:claims.exp-Math.floor(Date.now()/1000),expiryBoundaryExecuted:false});
      await fetch(`${transports.storageUrl}/object/mort-fixture`,{method:'DELETE',headers:{authorization:`Bearer ${handle.serviceKey}`,'content-type':'application/json'},body:JSON.stringify({prefixes:[`${user.id}/probe.txt`]})});
      await fixtureSql(handle,`DELETE FROM mort_transport.records WHERE owner='${user.id}';UPDATE mort_auth_guard.control SET enabled=false`);
      await cleanup(handle);
    }
    handle.transportEvidence=observations;
    console.log('GREEN transport characterization: RED security finding confirmed; old JWT accepted after password change, revocation and restore');
    console.log('MORT_JWT_OBSERVATIONS '+JSON.stringify(observations));
  }finally{
    if(backup)await discardBackup(handle,backup);
    await fixtureSql(handle,'UPDATE mort_auth_guard.control SET enabled=false;DELETE FROM mort_transport.records');
    await cleanup(handle);
  }
}
