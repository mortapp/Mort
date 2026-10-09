import assert from 'node:assert/strict';
import {createHash,randomUUID,randomBytes} from 'node:crypto';
import pg from 'pg';
import {assertMortAuthFixture,fixtureProcessEnv} from './fixture.mjs';
import {spawnSync} from './subprocess-runner.mjs';
import {pending,call,cleanup,signIn,signupLink,confirmed} from './provider.test.mjs';
import {startOidcFixture} from './oidc-fixture.mjs';
import {createServer} from 'node:http';
import {createFixtureProvider} from '../../supabase/functions/_shared/auth_email_guard/provider.ts';
const digest=v=>createHash('sha256').update(v).digest('hex');
export async function run(handle){
  assertMortAuthFixture(handle,handle.observed);
  const db=new pg.Client({connectionString:handle.dbUrl,connectionTimeoutMillis:2000});let connected=false;
  const accounts=[],operations=[];let stage='setup';const began=new Date().toISOString();
  async function seed(purpose='recovery'){
    await db.query('UPDATE mort_auth_guard.control SET enabled=false');
    const user=await pending(handle);accounts.push(user.id);
    if(purpose==='recovery')assert.ok((await call(handle,`/admin/users/${user.id}`,{email_confirm:true},true,'PUT')).status===200,'Owned recovery fixture starts confirmed');
    const family=randomUUID(),cap=digest(randomBytes(32)),verifier=digest(randomBytes(32)),recipient=digest(user.email);
    await db.query('INSERT INTO mort_auth_guard.account_generations(account_id,recipient_hash) VALUES($1,$2)',[user.id,recipient]);
    if(purpose==='recovery')await db.query(`INSERT INTO mort_auth_guard.address_proofs(account_id,address_generation,recipient_hash,activation_generation,restore_generation,source,proved_at)
      SELECT $1,1,$2,activation_generation,restore_generation,'confirmed_baseline',clock_timestamp() FROM mort_auth_guard.control`,[user.id,recipient]);
    await db.query(`WITH timing AS(SELECT clock_timestamp() AS n) INSERT INTO mort_auth_guard.families(id,account_id,purpose,recipient_hash,source_hash,address_generation,credential_generation,activation_generation,restore_generation,issued_at,family_expires_at,state)
      SELECT $1,$2,$3,$4,$5,1,1,activation_generation,restore_generation,n,n+interval '600 seconds','consumed' FROM mort_auth_guard.control,timing`,[family,user.id,purpose,recipient,digest(randomBytes(32))]);
    await db.query(`WITH timing AS(SELECT clock_timestamp() AS n) INSERT INTO mort_auth_guard.capabilities(digest,family_id,account_id,purpose,address_generation,credential_generation,activation_generation,restore_generation,verifier_hash,issued_at,expires_at)
      SELECT $1,$2,$3,$4,1,1,activation_generation,restore_generation,$5,n,n+interval '300 seconds' FROM mort_auth_guard.control,timing`,[cap,family,user.id,purpose,verifier]);
    await db.query('UPDATE mort_auth_guard.control SET enabled=true');
    return {user,cap,verifier,purpose,family};
  }
  async function reserve(row,patch={}){
    const operationId=randomUUID();const result=(await db.query('SELECT mort_auth_guard.reserve_password($1::jsonb) AS result',[JSON.stringify({capabilityDigest:row.cap,verifierHash:row.verifier,passwordValid:true,operationId,...patch})])).rows[0].result;
    if(result.ok)operations.push(result.operationId);return result;
  }
  const marker=(row,op)=>call(handle,`/admin/users/${row.user.id}`,{app_metadata:{mort_email_operation_id:op.operationId}},true,'PUT');
  const apply=(row,op,password)=>call(handle,`/admin/users/${row.user.id}`,{app_metadata:{mort_email_operation_id:op.operationId},password,...(row.purpose==='confirmation'?{email_confirm:true}:{})},true,'PUT');
  try{
    await db.connect();connected=true;
    assert.ok((await db.query("SELECT to_regprocedure('mort_auth_guard.reserve_password(jsonb)') IS NOT NULL AS installed")).rows[0].installed,'Private reservation helper must exist');
    const recovery=await seed();
    const preReset=await signIn(handle,recovery.user,recovery.user.password);assert.ok(preReset.status===200,'Recovery begins with a real verified session');
    assert.ok(!(await reserve(recovery,{verifierHash:digest(randomBytes(32))})).ok,'Incorrect verifier cannot reserve');
    const policy=await reserve(recovery,{passwordValid:false});assert.ok(policy.policy===true,'Correct possession reveals policy without consuming');
    assert.ok((await db.query("SELECT state='issued' FROM mort_auth_guard.capabilities WHERE digest=$1",[recovery.cap])).rows[0]['?column?'],'Policy denial keeps capability issued');
    const op=await reserve(recovery);assert.ok(op.ok&&op.accountId===recovery.user.id&&op.purpose==='recovery','Capability binds server-owned account/purpose');
    assert.ok(!(await reserve(recovery)).ok,'Reservation is one use');
    assert.ok((await marker(recovery,op)).status===200,'Private grant permits metadata correlator only');
    const replacement=`Aa9!${randomBytes(20).toString('base64url')}`;
    assert.ok((await apply(recovery,op,replacement)).status===200,'Supported granted recovery succeeds');
    const resetLogin=await signIn(handle,recovery.user,replacement);
    const resetCode=/^[a-z_]+$/.test(resetLogin.data.error_code??'')?resetLogin.data.error_code:'unspecified';
    assert.ok(resetLogin.status===200,`Granted replacement password signs in (HTTP ${resetLogin.status}, ${resetCode})`);
    const login=await signIn(handle,recovery.user,replacement);
    assert.ok((await call(handle,'/token?grant_type=refresh_token',{refresh_token:login.data.refresh_token})).status===200,'Current proved refresh remains supported');
    const claims=JSON.parse(Buffer.from(login.data.access_token.split('.')[1],'base64url').toString());
    assert.ok(!('mort_email_operation_id' in (claims.app_metadata??{})),'Operation correlator is removed from minted claims');
    const builtIn=await call(handle,'/admin/generate_link',{type:'magiclink',email:recovery.user.email},true);
    assert.ok(builtIn.status===200&&builtIn.data.action_link,'Owned provider magic-link negative control must exist');
    const legacy=await fetch(builtIn.data.action_link,{redirect:'manual',signal:AbortSignal.timeout(10000)});
    assert.ok(!/(?:access_token|refresh_token)=/.test(legacy.headers.get('location')??''),'Built-in email-link login must not mint a session');
    assert.ok((await signIn(handle,recovery.user,recovery.user.password)).status!==200,'Previous password no longer signs in');
    assert.ok((await call(handle,'/token?grant_type=refresh_token',{refresh_token:preReset.data.refresh_token})).status!==200,'Final guarded reset revokes old refresh session');
    assert.ok((await db.query('SELECT mort_auth_guard.reconcile_operation($1::uuid) AS state',[op.operationId])).rows[0].state==='committed','Provider-transaction commit reconciles privately');
    assert.ok((await apply(recovery,op,recovery.user.password)).status!==200,'Committed grant cannot mutate a second time');
    stage='lost-admin-response';
    const lost=await seed(),lostOp=await reserve(lost);let dropped=false,reconcileBlocked=true,proxyRequests=0;
    const sockets=new Set(),tasks=new Set();
    const proxy=createServer((request,response)=>{
      const work=(async()=>{
        if(request.url!==`/admin/users/${lost.user.id}`||request.method!=='PUT'||request.headers.authorization!==`Bearer ${handle.serviceKey}`){response.writeHead(404);response.end();return;}
        let body='';for await(const part of request){body+=part;if(body.length>16384){request.destroy();return;}}
        proxyRequests++;
        const upstream=await fetch(`${handle.authUrl}${request.url}`,{method:'PUT',headers:{'content-type':'application/json',authorization:`Bearer ${handle.serviceKey}`},body,signal:AbortSignal.timeout(10000)});
        await upstream.body?.cancel();
        if(Object.hasOwn(JSON.parse(body),'password')){dropped=true;request.socket.destroy();return;}
        response.writeHead(upstream.status,{'content-type':'application/json'});response.end('{}');
      })();tasks.add(work);work.catch(()=>response.destroy()).finally(()=>tasks.delete(work));
    });
    proxy.on('connection',socket=>{sockets.add(socket);socket.once('close',()=>sockets.delete(socket));});
    try{
      await new Promise((done,reject)=>{proxy.once('error',reject);proxy.listen(55426,'127.0.0.1',done);});
      const store={reconcile:async id=>{
        if(dropped&&reconcileBlocked)throw new Error('Synthetic reconciliation outage');
        return (await db.query('SELECT mort_auth_guard.reconcile_operation($1::uuid) state',[id])).rows[0].state;
      }};
      const provider=await createFixtureProvider({mode:'local_fixture',authUrl:handle.authUrl,serviceKey:handle.serviceKey},store,(input,init)=>{
        const url=String(input);
        if(url===`${handle.authUrl}/health`)return fetch(input,init);
        if(url!==`${handle.authUrl}/admin/users/${lost.user.id}`)throw new Error('Owned proxy route rejected');
        return fetch(`http://127.0.0.1:55426/admin/users/${lost.user.id}`,init);
      });
      handle.privateAudit.add(replacement);
      assert.equal(await provider.dispatch(lostOp,replacement,new AbortController().signal),'pending','Lost actual Admin response and unavailable reconciliation never report success');
      assert.ok(dropped&&proxyRequests===2,'Unknown outcome uses an actual committed provider write and destroyed response socket');
      assert.ok(!(await reserve(lost)).ok,'Lost Admin response never reopens consumed capability');
      reconcileBlocked=false;
      assert.equal(await store.reconcile(lostOp.operationId),'committed','Private reconciliation resolves actual lost Admin response safely');
      assert.equal(await provider.dispatch(lostOp,lost.user.password,new AbortController().signal),'fenced','Retry of reconciled lost operation cannot repeat provider mutation');
      assert.equal(proxyRequests,2,'Lost operation retry sends no further Admin write');
      assert.equal((await signIn(handle,lost.user,replacement)).status,200,'Owner can sign in with committed replacement after lost-response reconciliation');
    }finally{
      for(const socket of sockets)socket.destroy();
      if(proxy.listening)await new Promise(done=>proxy.close(done));await Promise.allSettled([...tasks]);
    }
    stage='public-password-borrow';
    const guardedCaller=await seed(),callerSession=await signIn(handle,guardedCaller.user,guardedCaller.user.password),callerOp=await reserve(guardedCaller);
    assert.ok(callerSession.status===200&&(await marker(guardedCaller,callerOp)).status===200,'Owned authenticated caller and live grant negative control');
    const bypass=await fetch(`${handle.authUrl}/user`,{method:'PUT',headers:{'content-type':'application/json',authorization:`Bearer ${callerSession.data.access_token}`},body:JSON.stringify({password:replacement}),signal:AbortSignal.timeout(10000)});
    assert.ok(bypass.status!==200,'Direct public password update cannot borrow a private reserved operation');
    assert.ok((await apply(guardedCaller,callerOp,replacement)).status===200,'Denied public borrowing must preserve the real granted operation');
    stage='stale-admin-current-grant';
    const stale=await seed(),oldOp=await reserve(stale);assert.ok((await marker(stale,oldOp)).status===200,'Old live marker prepared');
    const newFamily=randomUUID(),newCap=digest(randomBytes(32)),newVerifier=digest(randomBytes(32));
    await db.query(`INSERT INTO mort_auth_guard.families(id,account_id,purpose,recipient_hash,source_hash,address_generation,credential_generation,activation_generation,restore_generation,issued_at,family_expires_at,state)
      SELECT $1,account_id,purpose,recipient_hash,source_hash,address_generation,credential_generation,activation_generation,restore_generation,issued_at,family_expires_at,'consumed' FROM mort_auth_guard.families WHERE id=$2`,[newFamily,stale.family]);
    await db.query(`WITH timing AS(SELECT clock_timestamp() AS n) INSERT INTO mort_auth_guard.capabilities(digest,family_id,account_id,purpose,address_generation,credential_generation,activation_generation,restore_generation,verifier_hash,issued_at,expires_at)
      SELECT $1,$2,account_id,purpose,address_generation,credential_generation,activation_generation,restore_generation,$3,n,n+interval '300 seconds' FROM mort_auth_guard.capabilities,timing WHERE digest=$4`,[newCap,newFamily,newVerifier,stale.cap]);
    const newer={...stale,cap:newCap,verifier:newVerifier},newOp=await reserve(newer);
    assert.ok(newOp.ok&&(await marker(newer,newOp)).status===200,'New owner operation fences old grant and replaces correlator');
    assert.ok((await apply(stale,oldOp,replacement)).status!==200,'Old Admin body cannot borrow a currently reserved newer grant');
    assert.ok((await db.query("SELECT state IN('reserved','pending') AS intact FROM mort_auth_guard.operation_grants WHERE id=$1",[newOp.operationId])).rows[0].intact,'Rejected old Admin transaction rolls back any transient newer-grant writes');
    assert.ok((await apply(newer,newOp,replacement)).status===200,'New legitimate operation still completes after stale request denial');
    const confirmation=await seed('confirmation'),direct=await signupLink(handle,confirmation.user);
    await fetch(direct,{redirect:'manual',signal:AbortSignal.timeout(10000)});assert.ok(!await confirmed(handle,confirmation.user.id),'Direct provider link cannot confirm tracked pending account');
    assert.ok((await call(handle,`/admin/users/${confirmation.user.id}`,{app_metadata:{mort_email_operation_id:randomUUID()},password:replacement,email_confirm:true},true,'PUT')).status!==200,'Spoofed metadata without private grant cannot authorize');
    const confirmOp=await reserve(confirmation);assert.ok(confirmOp.ok&&(await marker(confirmation,confirmOp)).status===200,'Confirmation grant prepares correlator');
    assert.ok((await apply(confirmation,confirmOp,replacement)).status===200&&await confirmed(handle,confirmation.user.id),'One supported transaction confirms and replaces password');
    assert.ok((await signIn(handle,confirmation.user,confirmation.user.password)).status!==200&&(await signIn(handle,confirmation.user,replacement)).status===200,'Original signup password never becomes usable');
    assert.ok((await db.query("SELECT source='mort_challenge' AND retired_at IS NULL FROM mort_auth_guard.address_proofs WHERE account_id=$1",[confirmation.user.id])).rows[0]['?column?'],'Proof is written in provider commit');
    const parallel=await seed('confirmation'),parallelOp=await reserve(parallel);assert.ok((await marker(parallel,parallelOp)).status===200,'Concurrent granted writes have a real reserved-operation positive control');
    const writes=await Promise.all([apply(parallel,parallelOp,replacement),apply(parallel,parallelOp,replacement)]);
    assert.ok(writes.filter(r=>r.status===200).length===1,'One grant permits exactly one of two actual concurrent Admin password writes');
    const expired=await seed();
    await db.query("UPDATE mort_auth_guard.capabilities SET issued_at='2020-01-01Z',expires_at='2020-01-01Z'::timestamptz+interval '300 seconds' WHERE digest=$1",[expired.cap]);assert.ok(!(await reserve(expired)).ok,'At/after expiry never reserves');
    const delayed=await seed(),delayedOp=await reserve(delayed);assert.ok((await marker(delayed,delayedOp)).status===200,'Delayed fixture marker prepares');
    const locker=new pg.Client({connectionString:handle.dbUrl,connectionTimeoutMillis:2000});
    try{
      await locker.connect();await locker.query('BEGIN');await locker.query('SELECT id FROM auth.users WHERE id=$1 FOR UPDATE',[delayed.user.id]);
      const request=apply(delayed,delayedOp,replacement);let waiting=false;
      for(let i=0;i<50;i++){if((await db.query("SELECT EXISTS(SELECT 1 FROM pg_stat_activity WHERE usename='supabase_auth_admin' AND wait_event_type='Lock') AS waiting")).rows[0].waiting){waiting=true;break;}await new Promise(r=>setTimeout(r,30));}
      assert.ok(waiting,'Actual provider request must wait at account mutation boundary');
      await db.query("UPDATE mort_auth_guard.operation_grants SET expires_at=clock_timestamp()-interval '1 second' WHERE id=$1",[delayedOp.operationId]);await locker.query('COMMIT');
      assert.ok((await request).status!==200&&(await signIn(handle,delayed.user,delayed.user.password)).status===200,'Dispatched-live write rechecks expiry after lock and preserves password');
      assert.ok((await db.query('SELECT mort_auth_guard.reconcile_operation($1::uuid) AS state',[delayedOp.operationId])).rows[0].state==='fenced','Expired operation reconciles terminally');
    }finally{await locker.query('ROLLBACK').catch(()=>{});await locker.end();}
    const changed=await seed();
    assert.ok((await call(handle,`/admin/users/${changed.user.id}`,{email:`qa-${randomUUID()}@mort-fixture.invalid`},true,'PUT')).status===200,'Supported account address change succeeds');
    assert.ok((await call(handle,`/admin/users/${changed.user.id}`,{email:changed.user.email},true,'PUT')).status===200,'Supported change-back succeeds');
    assert.ok(!(await reserve(changed)).ok,'Address change-and-change-back cannot revive old capability');
    assert.ok((await db.query('SELECT address_generation=3 FROM mort_auth_guard.account_generations WHERE account_id=$1',[changed.user.id])).rows[0]['?column?'],'Each real address transition increments private generation');
    assert.ok((await signIn(handle,changed.user,changed.user.password)).status!==200,'Address change-back requires fresh proof before password sign-in');
    const oauth=await seed('confirmation'),issuer=await startOidcFixture(handle);
    try {
      // An unverified provider attempt may create a separate pending identity.
      // Keep it on a different owned mailbox from the positive linking control.
      const negative=await seed('confirmation');
      const forged=await call(handle,'/token?grant_type=id_token',{provider:'keycloak',id_token:issuer.token(negative.user.email,false)});
      if(forged.data.user?.id)handle.trackedAccounts.add(forged.data.user.id);
      assert.ok(forged.status!==200||forged.data.user?.id!==negative.user.id,'Unverified provider claim cannot confirm pending owner');
      const linked=await call(handle,'/token?grant_type=id_token',{provider:'keycloak',id_token:issuer.token(oauth.user.email,true)});
      const oauthCode=/^[a-z_]+$/.test(linked.data.error_code??'')?linked.data.error_code:'unspecified';
      assert.ok(linked.status===200&&linked.data.user?.id===oauth.user.id,`Real verified fixture OAuth stays live under final private guard (HTTP ${linked.status}, ${oauthCode})`);
      assert.ok((await signIn(handle,oauth.user,oauth.user.password)).status!==200,'OAuth cannot legitimize preconfirmation password');
    }finally{await issuer.close();}
    const log=spawnSync('docker',['logs','--since',began,`mort-mobile-auth-guard-qa-db-${handle.fixtureId}`],{env:fixtureProcessEnv(),windowsHide:true,encoding:'utf8',maxBuffer:4*1024*1024});
    assert.ok(log.status===0,'Owned method observation logs must be readable');
    const methods=[...new Set([...(log.stdout+log.stderr).matchAll(/MORT fixture auth method (password|oauth|token_refresh|otp|magiclink|recovery|invite|email\/signup|email_change|totp|sso\/saml|anonymous)\b/g)].map(match=>match[1]))].sort();
    assert.ok(['password','oauth','token_refresh'].every(name=>methods.includes(name)),'Actual successful provider method labels must be observed');
    assert.ok(methods.includes('magiclink')||methods.includes('otp'),'Actual denied email-link method must be observed');
    console.log('PASS observed fixture provider method labels: '+methods.join(', '));
    console.log('PASS actual guarded grant/provider integration: possession, policy, one-use, confirmation/recovery, direct-link/spoof/public-password-borrow/replay denial, delayed write and address change-back');
  }catch(error){
    console.error('FAIL guarded grant stage:',stage,error.name==='AssertionError'?error.message:(/^[0-9A-Z_]{1,24}$/.test(error.code??'')?error.code:['TypeError','AbortError','TimeoutError'].includes(error.name)?error.name:'setup or transport unavailable'));
    throw error;
  }finally{
    let failed=false;
    if(connected){
      try{await db.query('UPDATE mort_auth_guard.control SET enabled=false');}catch{failed=true;}
      try{await cleanup(handle);}catch{failed=true;}
      try{await db.query('DELETE FROM mort_auth_guard.operation_grants WHERE account_id=ANY($1::uuid[])',[accounts]);await db.query('DELETE FROM mort_auth_guard.address_proofs WHERE account_id=ANY($1::uuid[])',[accounts]);await db.query('DELETE FROM mort_auth_guard.capabilities WHERE account_id=ANY($1::uuid[])',[accounts]);await db.query('DELETE FROM mort_auth_guard.families WHERE account_id=ANY($1::uuid[])',[accounts]);await db.query('DELETE FROM mort_auth_guard.account_generations WHERE account_id=ANY($1::uuid[])',[accounts]);}catch{failed=true;}
    }
    await db.end();if(failed)throw new Error('Fixture grant cleanup failed');
  }
}
