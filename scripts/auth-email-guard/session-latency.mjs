import {assertMortAuthFixture,fixtureSql} from './fixture.mjs';

const names=['postgrest','storage','realtime'];
const rounds=10,budgetMs=60_000;
const inventory=`SELECT count(*)=3 AND coalesce(bool_and(permissive='RESTRICTIVE' AND roles=ARRAY['authenticated']::name[] AND
  (schemaname,tablename,policyname) IN (('mort_transport','records','guard_fixture_live_record'),
  ('storage','objects','guard_fixture_live_storage'),('realtime','messages','guard_fixture_live_channel'))),false)
  FROM pg_policies WHERE policyname IN('guard_fixture_live_record','guard_fixture_live_storage','guard_fixture_live_channel')`;
const drops=`DROP POLICY IF EXISTS guard_fixture_live_record ON mort_transport.records;
  DROP POLICY IF EXISTS guard_fixture_live_storage ON storage.objects;
  DROP POLICY IF EXISTS guard_fixture_live_channel ON realtime.messages;`;
const restore=`${drops}
  CREATE POLICY guard_fixture_live_record ON mort_transport.records AS RESTRICTIVE
    FOR SELECT TO authenticated USING((SELECT mort_fixture.session_is_live()));
  CREATE POLICY guard_fixture_live_storage ON storage.objects AS RESTRICTIVE
    FOR ALL TO authenticated USING(bucket_id<>'mort-fixture' OR (SELECT mort_fixture.session_is_live()))
    WITH CHECK(bucket_id<>'mort-fixture' OR (SELECT mort_fixture.session_is_live()));
  CREATE POLICY guard_fixture_live_channel ON realtime.messages AS RESTRICTIVE
    FOR ALL TO authenticated USING((SELECT mort_fixture.session_is_live()))
    WITH CHECK((SELECT mort_fixture.session_is_live()));`;
const transaction=statements=>`BEGIN;SET LOCAL lock_timeout='5s';SET LOCAL statement_timeout='5s';${statements}
  NOTIFY pgrst,'reload schema';COMMIT;${inventory};`;
const percentile=(samples,quantile)=>[...samples].sort((a,b)=>a-b)[Math.ceil(samples.length*quantile)-1];
const summarize=samples=>Object.fromEntries(names.map(name=>[name,{p50Ms:percentile(samples[name],0.5),p95Ms:percentile(samples[name],0.95),samples:samples[name].length}]));
const policyBoolean=output=>{
  if(typeof output!=='string')throw new Error();
  const finalRow=output.split(/\r?\n/).map(line=>line.trim()).filter(Boolean).at(-1);
  if(finalRow!=='t'&&finalRow!=='f')throw new Error();
  return finalRow==='t';
};

// The boundary permits unit tests of sampling and restoration without invoking
// Docker. The public runner below binds the actual owned-fixture checks and SQL.
export function createSessionLatencyRunner({assertFixture,sql,now=Date.now}){
  return async function runSessionLatency(handle,token,id,probe){
    let stage='identity',restoreNeeded=false,result,failure;
    try{
      assertFixture(handle,handle?.observed);
      if(typeof token!=='string'||!token.length||token.length>8192
        ||typeof id!=='string'||! /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(id)
        ||typeof probe!=='function')throw new Error();
      stage='policies';
      if(!policyBoolean(await sql(handle,inventory)))throw new Error();
      const began=now();
      const measure=async profile=>{
        stage=profile;
        const samples=Object.fromEntries(names.map(name=>[name,[]]));
        for(let round=0;round<rounds;round++){
          const startedAtMs=now(),remaining=budgetMs-(startedAtMs-began);
          if(!Number.isFinite(startedAtMs)||remaining<=0)throw new Error();
          // The supplied fixture probe already bounds HTTP and WebSocket work
          // at 4s/8s. Await that completion before restoring policies, even when
          // the measurement budget expires during the active read-only round.
          const sample=await probe(handle,token,id,{parallel:true});
          if(now()-began>=budgetMs)throw new Error();
          for(const name of names){
            const value=sample?.[name];
            const valid=name==='realtime'?value?.status==='ok':value?.status===200&&value.accepted===true&&value.denied===false;
            if(!valid||!Number.isFinite(value.checkedAtMs)||value.checkedAtMs<startedAtMs)throw new Error();
            samples[name].push(value.checkedAtMs-startedAtMs);
          }
        }
        return summarize(samples);
      };
      const protectedProfile=await measure('protected');
      stage='baseline';restoreNeeded=true;
      if(policyBoolean(await sql(handle,transaction(drops))))throw new Error();
      const baseline=await measure('baseline');
      result={scope:'owned SELECT private GET new private joins',roundsPerProfile:rounds,
        requestConcurrency:3,totalRequests:rounds*2*3,measurementBudgetMs:budgetMs,
        method:'Client-observed parallel response completion; nearest-rank percentiles; protected then baseline; includes probe and credential overhead.',
        protected:protectedProfile,baseline,
        delta:Object.fromEntries(names.map(name=>[name,{p50Ms:protectedProfile[name].p50Ms-baseline[name].p50Ms,p95Ms:protectedProfile[name].p95Ms-baseline[name].p95Ms}])),
        policiesRestored:false,hostedChanged:false};
    }catch{
      failure=new Error('Session latency measurement failed at '+stage);
      failure.latencyFailure={primaryStage:stage};
    }finally{
      if(restoreNeeded){
        try{
          if(!policyBoolean(await sql(handle,transaction(restore))))throw new Error();
          if(result)result.policiesRestored=true;
        }catch{
          if(failure){
            failure.message+='; policy restoration also failed';
            failure.latencyFailure.restorationStage='restoration';
          }else{
            failure=new Error('Session latency measurement failed at restoration');
            failure.latencyFailure={primaryStage:'restoration'};
          }
        }
      }
    }
    if(failure)throw failure;
    return result;
  };
}

export const runSessionLatency=createSessionLatencyRunner({assertFixture:assertMortAuthFixture,sql:fixtureSql});
