import assert from 'node:assert/strict';import {readFile} from 'node:fs/promises';import {randomBytes,randomUUID} from 'node:crypto';
import {startFixture,startFixtureTransports,fixtureSql} from './fixture.mjs';
import {pending,call,signIn,cleanup} from './provider.test.mjs';
import {backupFixture,restoreFixture,discardBackup} from './control.mjs';
import {completeCleanup} from './cleanup-primary.mjs';import {captureAssertions} from './evidence.mjs';
import {captureFailureSnapshot} from './failure-snapshot.mjs';
import {nativeCatalogCoverage} from './native-catalog.mjs';import {openNativeChannel} from './native-realtime.mjs';
const buckets=['financial-receipts','identity-evidence','incident-evidence','mort-document-vault','mort-verify-evidence','proof-uploads','support-attachments','support-evidence','teen-school-id','verification-uploads','profile-avatars'];
export async function run(handle){
  let owner,backup,primary,hadOldChannel=false,phase='setup';const channels=[],createdBuckets=new Set(),uploadedBuckets=new Set();const observations=[],openWindows=[];
  const api=async(path,token,{method='GET',body,contentType='application/json'}={})=>{
    const response=await fetch('http://127.0.0.1:55432/'+path,{method,headers:{authorization:'Bearer '+token,'content-type':contentType},...(body!==undefined?{body:contentType==='application/json'?JSON.stringify(body):body}:{}),signal:AbortSignal.timeout(4000)});
    return {status:response.status,text:await response.text()};
  };
  const rest=async(token,method='GET',value='synthetic')=>{
    const response=await fetch('http://127.0.0.1:55431/native_published'+(method==='GET'?'?owner=eq.'+owner.id:''),{method,headers:{authorization:'Bearer '+token,'content-type':'application/json',Prefer:'return=representation'},...(method==='POST'?{body:JSON.stringify({id:randomUUID(),owner:owner.id,value})}:{}),signal:AbortSignal.timeout(4000)});return {status:response.status,data:await response.json()};
  };
  try{
    await startFixtureTransports(handle);
    assert.equal(await fixtureSql(handle,'SELECT enabled FROM mort_fixture.pre_request_control'),'f','Native session enforcement defaults off');
    hadOldChannel=await fixtureSql(handle,"SELECT EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='realtime' AND tablename='messages' AND policyname='guard_fixture_live_channel')")==='t';
    await fixtureSql(handle,'DROP POLICY IF EXISTS guard_fixture_live_channel ON realtime.messages');
    await fixtureSql(handle,await readFile(new URL('./native-resources.sql',import.meta.url),'utf8'));
    await fixtureSql(handle,await readFile(new URL('./pre-request.sql',import.meta.url),'utf8'));
    owner=await pending(handle);assert.equal((await call(handle,'/admin/users/'+owner.id,{email_confirm:true},true,'PUT')).status,200);
    let current=await signIn(handle,owner,owner.password);assert.equal(current.status,200,'Actual confirmed owner signs in for native fixture');
    phase='bucket-setup';
    for(const bucket of buckets){
      assert.equal(await fixtureSql(handle,`SELECT count(*) FROM storage.buckets WHERE id='${bucket}'`),'0','Native named bucket has no preexisting data');
      createdBuckets.add(bucket);
      assert.equal((await api('bucket',handle.serviceKey,{method:'POST',body:{id:bucket,name:bucket,public:false}})).status,200,'Disposable native bucket created private');
      const row=JSON.parse((await api('bucket/'+bucket,handle.serviceKey)).text);assert.equal(row.public,false,'bucketNotPublic includes profile avatars');
      uploadedBuckets.add(bucket);
      assert.equal((await api('object/'+bucket+'/'+owner.id+'/probe.txt',current.data.access_token,{method:'POST',body:'synthetic',contentType:'text/plain'})).status,200,'Fresh owner uploads private synthetic placeholder');
      assert.equal((await api('object/authenticated/'+bucket+'/'+owner.id+'/probe.txt',current.data.access_token)).text,'synthetic','Fresh owner reads private synthetic placeholder');
    }
    for(let i=0;i<40;i++){if((await rest(current.data.access_token)).status===200)break;await new Promise(r=>setTimeout(r,100));}
    assert.equal((await rest(current.data.access_token,'POST')).status,201,'Fresh owner creates published synthetic row');
    await fixtureSql(handle,'UPDATE mort_fixture.pre_request_control SET enabled=true');
    phase='catalog';
    let catalog=JSON.parse(await fixtureSql(handle,await readFile(new URL('./native-catalog.sql',import.meta.url),'utf8')));
    assert.equal(nativeCatalogCoverage(catalog).passed,true,'Actual native bucket channel and publication catalog is covered');
    phase='uncovered-bucket';
    createdBuckets.add('guard-native-uncovered');
    assert.equal((await api('bucket',handle.serviceKey,{method:'POST',body:{id:'guard-native-uncovered',name:'guard-native-uncovered',public:false}})).status,200,'Uncovered catalog probe uses real Storage API creation');
    try{const added=JSON.parse(await fixtureSql(handle,await readFile(new URL('./native-catalog.sql',import.meta.url),'utf8')));assert.equal(nativeCatalogCoverage(added).passed,false,'coverageFailsForUncoveredBucket added in actual catalog');}
    finally{assert.equal((await api('bucket/guard-native-uncovered',handle.serviceKey,{method:'DELETE'})).status,200,'Uncovered catalog probe uses supported Storage API cleanup');createdBuckets.delete('guard-native-uncovered');}
    phase='uncovered-publication';
    await fixtureSql(handle,'CREATE TABLE mort_transport.native_uncovered(id uuid);ALTER TABLE mort_transport.native_uncovered ENABLE ROW LEVEL SECURITY;GRANT SELECT ON mort_transport.native_uncovered TO authenticated;ALTER PUBLICATION supabase_realtime ADD TABLE mort_transport.native_uncovered');
    try{const added=JSON.parse(await fixtureSql(handle,await readFile(new URL('./native-catalog.sql',import.meta.url),'utf8')));assert.equal(nativeCatalogCoverage(added).passed,false,'Published newly granted table without session policy fails actual catalog coverage');}
    finally{await fixtureSql(handle,'DROP TABLE mort_transport.native_uncovered');}
    for(const event of ['revocation','passwordChange','restore']){
      phase='lifecycle-'+event;
      const old=current.data.access_token;const claims=JSON.parse(Buffer.from(old.split('.')[1],'base64url'));
      assert.ok(claims.exp*1000>Date.now()+30000,'Native lifecycle uses actual token with more than30 seconds remaining');
      const opened=await openNativeChannel(handle,old,owner.id,{published:true});channels.push(opened);assert.equal(opened.status,'ok','Owner joins actual private published channel before lifecycle event');
      assert.equal(await opened.broadcast(),'received','Already-open channel has real broadcast positive control');
      let eventAt;
      if(event==='revocation'){
        const r=await fetch(handle.authUrl+'/logout?scope=global',{method:'POST',headers:{authorization:'Bearer '+old},signal:AbortSignal.timeout(4000)});assert.equal(r.status,204,'Actual provider global revocation succeeds');eventAt=Date.now();
      }else if(event==='passwordChange'){
        const next=`Dd6!${randomBytes(20).toString('base64url')}`;assert.equal((await call(handle,'/admin/users/'+owner.id,{password:next},true,'PUT')).status,200,'Actual Admin native password change succeeds');eventAt=Date.now();owner.password=next;
      }else{
        backup=await backupFixture(handle);try{await restoreFixture(handle,backup,{localFixture:true,apply:true,privateProviderRehearsal:true});eventAt=Date.now();}finally{if(backup){await discardBackup(handle,backup);backup=null;}}
        assert.equal(await fixtureSql(handle,`SELECT EXISTS(SELECT 1 FROM auth.sessions WHERE id='${claims.session_id}')`),'t','Native restore retains old session row');
        await fixtureSql(handle,'UPDATE mort_auth_guard.control SET enabled=false;UPDATE mort_fixture.pre_request_control SET enabled=true;NOTIFY pgrst,\'reload schema\'');
      }
      current=await signIn(handle,owner,owner.password);assert.equal(current.status,200,'Fresh native owner signs in after lifecycle');
      const bucketRows=[];
      for(const bucket of buckets){
        const denied=await api('object/authenticated/'+bucket+'/'+owner.id+'/probe.txt',old),elapsedMs=Date.now()-eventAt;
        assert.ok([400,401,403,404].includes(denied.status),`storageReadDeniedWithin30s_${event}_${bucket}`);
        assert.ok(elapsedMs<=30000,'Native Storage preserves fixed30-second lifecycle margin');
        const good=await api('object/authenticated/'+bucket+'/'+owner.id+'/probe.txt',current.data.access_token);assert.equal(good.status,200,'Fresh native Storage read positive control');assert.equal(good.text,'synthetic');bucketRows.push({bucket,status:denied.status,elapsedMs});
      }
      const joined=await openNativeChannel(handle,old,owner.id);channels.push(joined);
      assert.equal(joined.status,'error',`realtimeJoinDeniedWithin30s_${event}`);assert.ok(Date.now()-eventAt<=30000,'New private native join preserves fixed30-second lifecycle margin');
      const fresh=await openNativeChannel(handle,current.data.access_token,owner.id,{published:true});channels.push(fresh);assert.equal(fresh.status,'ok','Fresh native Realtime join positive control');
      const hidden=await rest(old);assert.ok(hidden.status===401||hidden.status===200&&Array.isArray(hidden.data)&&hidden.data.length===0,`publishedTableChangeStreamCovered_${event}`);
      assert.ok((await rest(current.data.access_token)).data.length>0,'Fresh published-table read positive control');
      const existingBroadcast=await opened.broadcast();
      const changeValue='synthetic-'+randomUUID();const oldChange=opened.waitChange(changeValue),freshChange=fresh.waitChange(changeValue);
      assert.equal((await rest(current.data.access_token,'POST',changeValue)).status,201,'Fresh owner writes actual published change');
      assert.equal(await freshChange,'received','Fresh private subscriber receives actual published change');
      const oldChangeResult=await oldChange;assert.notEqual(oldChangeResult,'received','Retired already-open subscriber receives no protected published change');
      await opened.reauthorize(old);const oldReauthorized=await opened.broadcast();
      await fresh.reauthorize(current.data.access_token);assert.equal(await fresh.broadcast(),'received','Fresh token reauthorization keeps native broadcast working');
      openWindows.push({event,existingBroadcast,oldReauthorized,protectedPublishedChange:oldChangeResult,window:'Observation only; any cached broadcast access through original JWT lifetime remains for CP15 characterization'});
      observations.push({event,buckets:bucketRows,newJoin:joined.status,publishedOldStatus:hidden.status});
      opened.close();joined.close();fresh.close();
    }
    handle.nativeSessionEvidence={observations,openWindows,catalog,profileAvatarsPublic:false,thresholdMs:30000,hostedChanged:false};
    console.log('OBSERVED native lifecycle: '+JSON.stringify(handle.nativeSessionEvidence));
  }catch(e){primary=e;e.nativePhase=phase;console.error('NATIVE failure phase '+phase);try{console.error('NATIVE snapshot '+JSON.stringify(captureFailureSnapshot(handle)));}catch{console.error('NATIVE snapshot unavailable; primary retained');}throw e;}
  finally{
    await completeCleanup(primary,[
      async()=>{for(const channel of channels)channel.close();},
      async()=>{if(backup)await discardBackup(handle,backup);},
      async()=>{for(const bucket of uploadedBuckets){const r=await api('object/'+bucket,handle.serviceKey,{method:'DELETE',body:{prefixes:[owner.id+'/probe.txt']}});assert.equal(r.status,200,'Owned native placeholder cleanup succeeds');}},
      async()=>{for(const bucket of createdBuckets)assert.equal((await api('bucket/'+bucket,handle.serviceKey,{method:'DELETE'})).status,200,'Owned native bucket cleanup succeeds');},
      ()=>fixtureSql(handle,`ALTER ROLE authenticator RESET pgrst.db_pre_request;UPDATE mort_fixture.pre_request_control SET enabled=false;DROP TABLE IF EXISTS mort_transport.native_uncovered;DROP TABLE IF EXISTS mort_transport.native_published;DROP POLICY IF EXISTS guard_native_owner_read ON storage.objects;DROP POLICY IF EXISTS guard_native_owner_write ON storage.objects;DROP POLICY IF EXISTS guard_native_storage_live ON storage.objects;DROP POLICY IF EXISTS guard_native_channel_owner_read ON realtime.messages;DROP POLICY IF EXISTS guard_native_channel_owner_write ON realtime.messages;DROP POLICY IF EXISTS guard_native_channel_live ON realtime.messages;DROP FUNCTION IF EXISTS mort_fixture.native_guard_enabled();${hadOldChannel?'CREATE POLICY guard_fixture_live_channel ON realtime.messages AS RESTRICTIVE FOR ALL TO authenticated USING((SELECT mort_fixture.session_is_live())) WITH CHECK((SELECT mort_fixture.session_is_live()));':''}NOTIFY pgrst,'reload config';NOTIFY pgrst,'reload schema';`),
      ()=>cleanup(handle),
    ]);
  }
}
if(process.argv[1]&&import.meta.filename===process.argv[1]){
  try{const h=await startFixture();const assertions=await captureAssertions('native-session-live',()=>run(h));console.log('PASS native assertions: '+assertions.length);}
  catch(e){console.error('FAIL native '+JSON.stringify({assertion:e.guardAssertion??null,phase:e.nativePhase??'startup',name:e.name==='AssertionError'?'AssertionError':'Error'}));process.exitCode=1;}
}
