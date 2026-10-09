import assert from 'node:assert/strict';
import {test} from 'node:test';

let createSessionLatencyRunner;
try{({createSessionLatencyRunner}=await import('./session-latency.mjs'));}catch(error){if(error.code!=='ERR_MODULE_NOT_FOUND')throw error;}
const setup=({commandTags=false}={})=>{
  assert.equal(typeof createSessionLatencyRunner,'function','Bounded session latency runner must exist');
  const state={protected:true,round:0,clock:0,restored:0,probes:0,active:0,maxActive:0};
  const runner=createSessionLatencyRunner({
    assertFixture:(handle,observed)=>{if(handle.fixtureId!=='owned'||observed!==handle.observed)throw new Error('private fixture rejection');},
    sql:async(_handle,statement)=>{
      if(statement.includes('CREATE POLICY')){state.protected=true;state.restored++;}
      else if(statement.includes('DROP POLICY'))state.protected=false;
      const result=state.protected?'t':'f';
      return commandTags&&statement.includes('BEGIN;')?'BEGIN\nSET\nSET\nDROP POLICY\nNOTIFY\nCOMMIT\n'+result+'\n':result;
    },now:()=>state.clock,
  });
  const handle={fixtureId:'owned',observed:{}},token='private-owner-token',id='12345678-1234-4234-8234-123456789abc';
  const probe=async(receivedHandle,receivedToken,receivedId,options)=>{
    assert.equal(receivedHandle,handle);assert.equal(receivedToken,token);assert.equal(receivedId,id);assert.equal(options.parallel,true);
    state.active++;state.maxActive=Math.max(state.maxActive,state.active);state.probes++;
    const latency=state.protected?20+state.round++:10+(state.probes-11);
    const result={postgrest:{status:200,accepted:true,denied:false,checkedAtMs:state.clock+latency},storage:{status:200,accepted:true,denied:false,checkedAtMs:state.clock+latency+2},realtime:{status:'ok',checkedAtMs:state.clock+latency+4}};
    state.clock+=latency+4;state.active--;return result;
  };
  return {state,runner,handle,token,id,probe};
};

test('latency benchmark computes measured percentile deltas and restores fixture protection',async()=>{
  const {state,runner,handle,token,id,probe}=setup();
  const result=await runner(handle,token,id,probe);
  assert.deepEqual(result.protected.postgrest,{p50Ms:24,p95Ms:29,samples:10});
  assert.deepEqual(result.baseline.postgrest,{p50Ms:14,p95Ms:19,samples:10});
  assert.deepEqual(result.delta.postgrest,{p50Ms:10,p95Ms:10});
  assert.equal(result.roundsPerProfile,10);assert.equal(result.requestConcurrency,3);
  assert.equal(result.policiesRestored,true);assert.equal(result.hostedChanged,false);
  assert.equal(result.scope,'owned SELECT private GET new private joins');
  assert.equal(state.probes,20);assert.equal(state.maxActive,1);assert.equal(state.protected,true);assert.equal(state.restored,1);
  assert.ok(!JSON.stringify(result).includes('private-owner-token'));
});

test('a failed baseline request restores policies and exports no private failure message',async()=>{
  const {state,runner,handle,token,id,probe}=setup();
  await assert.rejects(()=>runner(handle,token,id,async(...args)=>{
    if(!state.protected)throw new Error('private baseline token payload');
    return probe(...args);
  }),error=>error.message==='Session latency measurement failed at baseline');
  assert.equal(state.protected,true);assert.equal(state.restored,1);
});

test('unknown or denied owner responses cannot become a successful latency sample',async()=>{
  const {state,runner,handle,token,id,probe}=setup();
  await assert.rejects(()=>runner(handle,token,id,async(...args)=>{
    const result=await probe(...args);result.realtime.status='connection_rejected';return result;
  }),/Session latency measurement failed at protected/);
  assert.equal(state.probes,1);assert.equal(state.protected,true);
});

test('missing or earlier completion clocks reject measurements',async()=>{
  const {runner,handle,token,id,probe}=setup();
  await assert.rejects(()=>runner(handle,token,id,async(...args)=>{
    const result=await probe(...args);result.storage.checkedAtMs=-1;return result;
  }),/Session latency measurement failed at protected/);
});

test('unowned fixture is rejected before policy or request activity',async()=>{
  const {state,runner,handle,token,id,probe}=setup();
  await assert.rejects(()=>runner({...handle,fixtureId:'foreign'},token,id,probe),/Session latency measurement failed at identity/);
  assert.equal(state.probes,0);assert.equal(state.restored,0);
});

test('expired measurement budget stops further rounds and restores baseline policies',async()=>{
  const {state,runner,handle,token,id,probe}=setup();
  await assert.rejects(()=>runner(handle,token,id,async(...args)=>{
    const result=await probe(...args);if(!state.protected)state.clock+=60_000;return result;
  }),/Session latency measurement failed at baseline/);
  assert.equal(state.probes,11);assert.equal(state.protected,true);assert.equal(state.restored,1);
});

test('failed restoration verification prevents a successful report',async()=>{
  assert.equal(typeof createSessionLatencyRunner,'function');
  let baseline=false,restored=false;
  const runner=createSessionLatencyRunner({assertFixture:()=>{},sql:async(_handle,statement)=>{
    if(statement.includes('CREATE POLICY')){restored=true;return 'f';}
    if(statement.includes('DROP POLICY'))baseline=true;
    return baseline?'f':'t';
  },now:()=>0});
  const probe=async()=>({postgrest:{status:200,accepted:true,denied:false,checkedAtMs:1},storage:{status:200,accepted:true,denied:false,checkedAtMs:1},realtime:{status:'ok',checkedAtMs:1}});
  await assert.rejects(()=>runner({observed:{}},'private','12345678-1234-4234-8234-123456789abc',probe),/Session latency measurement failed at restoration/);
  assert.equal(restored,true);
});

test('baseline and restoration failures preserve both safe phases and the primary failure',async()=>{
  let baseline=false,restorationAttempts=0;
  const runner=createSessionLatencyRunner({assertFixture:()=>{},sql:async(_handle,statement)=>{
    if(statement.includes('CREATE POLICY')){
      restorationAttempts++;
      const error=new Error('private restoration stderr');error.cause='private restoration cause';throw error;
    }
    if(statement.includes('DROP POLICY'))baseline=true;
    return baseline?'f':'t';
  },now:()=>0});
  const probe=async()=>{
    if(baseline){const error=new Error('private baseline token');error.cause='private baseline cause';throw error;}
    return {postgrest:{status:200,accepted:true,denied:false,checkedAtMs:1},storage:{status:200,accepted:true,denied:false,checkedAtMs:1},realtime:{status:'ok',checkedAtMs:1}};
  };
  await assert.rejects(()=>runner({observed:{}},'private-owner-token','12345678-1234-4234-8234-123456789abc',probe),error=>{
    assert.equal(error.message,'Session latency measurement failed at baseline; policy restoration also failed');
    assert.deepEqual(error.latencyFailure,{primaryStage:'baseline',restorationStage:'restoration'});
    assert.equal(error.cause,undefined);
    assert.ok(!JSON.stringify(error).includes('private'));
    assert.ok(!error.stack.includes('private'));
    return true;
  });
  assert.equal(restorationAttempts,1);
});

test('transaction command tags do not hide the final fixture policy boolean row',async()=>{
  const {state,runner,handle,token,id,probe}=setup({commandTags:true});
  const result=await runner(handle,token,id,probe);
  assert.equal(result.policiesRestored,true);assert.equal(state.probes,20);
});

test('a nonboolean final SQL row cannot borrow an earlier successful row',async()=>{
  assert.equal(typeof createSessionLatencyRunner,'function');
  const runner=createSessionLatencyRunner({assertFixture:()=>{},sql:async()=> 'BEGIN\nt\nCOMMIT\n',now:()=>0});
  await assert.rejects(()=>runner({observed:{}},'private','12345678-1234-4234-8234-123456789abc',async()=>{}),/Session latency measurement failed at policies/);
});

test('budget expiry waits for the bounded probe before restoring fixture policies',async()=>{
  const {state,runner,handle,token,id,probe}=setup();
  let release,active=false;
  const pending=new Promise(resolve=>{release=resolve;});
  const completed=runner(handle,token,id,async(...args)=>{
    if(state.protected){const result=await probe(...args);if(state.probes===10)state.clock=59_999;return result;}
    active=true;await pending;active=false;state.clock=60_001;return probe(...args);
  });
  const outcome=completed.then(()=>null,error=>error);
  try{
    await new Promise(resolve=>setTimeout(resolve,15));
    assert.equal(active,true);
    assert.equal(state.protected,false,'Policy restoration must wait for the active request');
    assert.equal(state.restored,0);
  }finally{release();await outcome;}
  assert.match((await outcome).message,/Session latency measurement failed at baseline/);
  assert.equal(state.protected,true);assert.equal(state.restored,1);
});
