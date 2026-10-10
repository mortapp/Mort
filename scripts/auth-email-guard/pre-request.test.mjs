import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {startFixture,startFixtureTransports,fixtureSql} from './fixture.mjs';
import {pending,call,signIn,cleanup} from './provider.test.mjs';
import {captureAssertions} from './evidence.mjs';
import {captureFailureSnapshot} from './failure-snapshot.mjs';
import {catalogCoverage} from './catalog-coverage.mjs';
export async function run(handle,{verifyLifecycle}={}){
  let owner,primaryFailure;let phase='transport-start';
  const request=async(path,token,method='GET',outerSignal)=>{
    const started=performance.now();
    const response=await fetch('http://127.0.0.1:55431/'+path,{method,headers:{...(token?{authorization:'Bearer '+token}:{}),'content-type':'application/json'},...(method==='POST'?{body:'{}'}:{}),signal:outerSignal?AbortSignal.any([outerSignal,AbortSignal.timeout(4000)]):AbortSignal.timeout(4000)});
    const data=await response.json();return {status:response.status,data,elapsedMs:performance.now()-started};
  };
  try{
    await startFixtureTransports(handle);
    phase='fixture-setup';
    await fixtureSql(handle,await readFile(new URL('./transport-schema.sql',import.meta.url),'utf8'));
    const predicate=(await readFile(new URL('./session-live.sql',import.meta.url),'utf8')).split('create policy guard_fixture_live_record')[0];
    await fixtureSql(handle,predicate);
    await fixtureSql(handle,`DROP POLICY IF EXISTS guard_fixture_live_record ON mort_transport.records;
      CREATE TABLE IF NOT EXISTS mort_fixture.pre_request_control(enabled boolean NOT NULL DEFAULT false);
      TRUNCATE mort_fixture.pre_request_control; INSERT INTO mort_fixture.pre_request_control VALUES(false);
      REVOKE ALL ON mort_fixture.pre_request_control FROM public,anon,authenticated,service_role;
      CREATE OR REPLACE VIEW mort_transport.guard_probe_view WITH(security_invoker=true) AS SELECT * FROM mort_transport.records;
      GRANT SELECT ON mort_transport.guard_probe_view TO authenticated;
      GRANT USAGE ON SCHEMA mort_transport TO anon;
      CREATE TABLE IF NOT EXISTS mort_transport.guard_unregistered_resource(value text NOT NULL);
      TRUNCATE mort_transport.guard_unregistered_resource;INSERT INTO mort_transport.guard_unregistered_resource VALUES('synthetic');
      GRANT SELECT ON mort_transport.guard_unregistered_resource TO authenticated;
      CREATE OR REPLACE FUNCTION mort_transport.guard_probe_rpc() RETURNS text LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$ SELECT 'synthetic'::text $$;
      REVOKE ALL ON FUNCTION mort_transport.guard_probe_rpc() FROM public;GRANT EXECUTE ON FUNCTION mort_transport.guard_probe_rpc() TO authenticated;
      CREATE OR REPLACE FUNCTION mort_transport.guard_probe_anon() RETURNS text LANGUAGE sql SET search_path='' AS $$ SELECT 'synthetic'::text $$;
      REVOKE ALL ON FUNCTION mort_transport.guard_probe_anon() FROM public;GRANT EXECUTE ON FUNCTION mort_transport.guard_probe_anon() TO anon;
      UPDATE mort_auth_guard.control SET enabled=false;NOTIFY pgrst,'reload schema';`);
    try{await fixtureSql(handle,await readFile(new URL('./pre-request.sql',import.meta.url),'utf8'));}
    catch(error){if(error.code!=='ENOENT')throw error;}
    owner=await pending(handle);assert.equal((await call(handle,'/admin/users/'+owner.id,{email_confirm:true},true,'PUT')).status,200);
    const session=await signIn(handle,owner,owner.password);assert.equal(session.status,200);
    await fixtureSql(handle,`INSERT INTO mort_transport.records VALUES('${owner.id}','${owner.id}','synthetic');`);
    const paths=[['records?id=eq.'+owner.id,'GET'],['guard_probe_view?id=eq.'+owner.id,'GET'],['rpc/guard_probe_rpc','POST']];
    for(let i=0;i<40;i++){if((await request(paths[1][0],session.data.access_token)).status===200)break;await new Promise(resolve=>setTimeout(resolve,100));}
    assert.equal(await fixtureSql(handle,'SELECT enabled FROM mort_fixture.pre_request_control'),'f','Fixture request enforcement defaults off');
    for(const [path,method] of paths)assert.equal((await request(path,session.data.access_token,method)).status,200,'Live session accesses each table view and definer RPC with enforcement off');
    assert.equal((await request('rpc/guard_probe_anon',null,'POST')).status,200,'Anonymous positive control succeeds before enforcement');
    const logout=await fetch(handle.authUrl+'/logout?scope=global',{method:'POST',headers:{authorization:'Bearer '+session.data.access_token},signal:AbortSignal.timeout(4000)});assert.equal(logout.status,204);
    for(const [path,method] of paths)assert.equal((await request(path,session.data.access_token,method)).status,200,'Flag off preserves prior behavior for each revoked-token path');
    await fixtureSql(handle,'UPDATE mort_fixture.pre_request_control SET enabled=true');
    for(const [path,method] of paths){const result=await request(path,session.data.access_token,method);assert.equal(result.status,401,'Pre-request denies revoked tokens on tables views and security-definer RPCs');assert.equal(result.data.message,'Session ended','Pre-request denial has the session-live reason');}
    assert.equal((await request('rpc/guard_probe_anon',null,'POST')).status,200,'Anonymous role remains unaffected with enforcement on');
    const fresh=await signIn(handle,owner,owner.password);assert.equal(fresh.status,200);
    for(const [path,method] of paths)assert.equal((await request(path,fresh.data.access_token,method)).status,200,'Fresh session accesses every protected PostgREST surface');
    assert.equal((await request('guard_unregistered_resource',session.data.access_token)).status,401,'Gate covers a newly granted relation absent from any handwritten resource list');
    assert.equal((await request('guard_unregistered_resource',fresh.data.access_token)).status,200,'Fresh control accesses the newly granted relation');
    const catalog=JSON.parse(await fixtureSql(handle,await readFile(new URL('./catalog-resources.sql',import.meta.url),'utf8')));
    assert.ok(catalog.some(row=>row.kind==='view'&&row.reachable)&&catalog.some(row=>row.kind==='rpc'&&row.reachable&&row.securityDefiner),'Actual catalog contains reachable view and definer RPC');
    assert.ok(catalogCoverage(catalog,{gateVerified:true,policies:[]}).passed,'Verified request gate covers every catalog-reachable PostgREST resource');
    assert.ok(!catalogCoverage(catalog,{gateVerified:false,policies:[]}).passed,'Actual catalog coverage fails without a verified gate or resource policy');
    console.log('OBSERVED PostgREST catalog coverage: '+JSON.stringify({resources:catalog.length,reachable:catalog.filter(row=>row.reachable).length,scope:'fixture exposed schemas only',missingWhenGateAbsent:true}));
    const timings={off:[],on:[]};
    for(const mode of ['off','on']){
      await fixtureSql(handle,'UPDATE mort_fixture.pre_request_control SET enabled='+String(mode==='on'));
      for(let i=0;i<20;i++){const result=await request(paths[0][0],fresh.data.access_token);assert.equal(result.status,200,'Bounded latency sample retains live owner access');timings[mode].push(result.elapsedMs);}
    }
    const percentile=(rows,p)=>[...rows].sort((a,b)=>a-b)[Math.ceil(rows.length*p)-1];
    handle.preRequestEvidence={scope:'fixture PostgREST table view definer RPC',latencyScope:'owner table GET; serial off then on; client-observed, not isolated SQL cost',requests:40,concurrency:1,off:{p50Ms:percentile(timings.off,.5),p95Ms:percentile(timings.off,.95)},on:{p50Ms:percentile(timings.on,.5),p95Ms:percentile(timings.on,.95)},hostedChanged:false};
    console.log('OBSERVED pre-request latency: '+JSON.stringify(handle.preRequestEvidence));
    if(verifyLifecycle)await verifyLifecycle({owner,fresh,paths,request});
  }catch(error){primaryFailure=error;console.error('FAIL pre-request fixture: '+JSON.stringify(error.guardAssertion??{stage:phase,name:['Error','TypeError','TimeoutError','AbortError'].includes(error.name)?error.name:'unknown',healthDiagnostic:/^Fixture transport health timeout: port [0-9]+, outcome [A-Za-z0-9_]+$/.test(error.message??'')?error.message:null,valuesRedacted:true}));console.error('FAILURE fixture snapshot: '+JSON.stringify(captureFailureSnapshot(handle)));throw error;}
  finally{
    try{
    await fixtureSql(handle,`ALTER ROLE authenticator RESET pgrst.db_pre_request;UPDATE mort_fixture.pre_request_control SET enabled=false;NOTIFY pgrst,'reload config';DELETE FROM mort_transport.records;
      DROP VIEW IF EXISTS mort_transport.guard_probe_view;DROP TABLE IF EXISTS mort_transport.guard_unregistered_resource;DROP FUNCTION IF EXISTS mort_transport.guard_probe_rpc();DROP FUNCTION IF EXISTS mort_transport.guard_probe_anon();`);
    await cleanup(handle);
    }catch(error){console.error('FAIL pre-request cleanup; primary failure retained');if(!primaryFailure)throw error;}
  }
}
if(process.argv[1]&&import.meta.filename===process.argv[1]){
  try{const fixture=await startFixture();const assertions=await captureAssertions('pre-request',()=>run(fixture));console.log('PASS actual pre-request fixture assertions: '+assertions.length);}
  catch{process.exitCode=1;}
}
