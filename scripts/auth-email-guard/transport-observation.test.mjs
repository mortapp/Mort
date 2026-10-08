import assert from 'node:assert/strict';
import {test} from 'node:test';

let recordTransportSample;
try { ({recordTransportSample}=await import('./transport-observation.mjs')); }
catch(error) { if(error.code!=='ERR_MODULE_NOT_FOUND')throw error; }
const observe=(...args)=>{
  assert.equal(typeof recordTransportSample,'function','Transport measurement helper must exist');
  return recordTransportSample(...args);
};
const clocks={signedExpiryMs:10_000,lifecycleAtMs:1_000,checkedAtMs:11_000};
const accepted=()=>({postgrest:{status:200,accepted:true,denied:false},storage:{status:200,accepted:true,denied:false},realtime:{status:'ok'}});
const denied=()=>({postgrest:{status:401,accepted:false,denied:true},storage:{status:403,accepted:false,denied:true},realtime:{status:'error'}});

test('PostgREST acceptance at expiry plus one second remains RED after rejection at plus thirty-one',()=>{
  const row={},sample=denied();sample.postgrest=accepted().postgrest;
  assert.deepEqual(observe(row,sample,clocks),{allAccepted:false,allDenied:false});
  assert.equal(row.strictExpiryCheck.policy,'REJECT_BY_SIGNED_EXPIRY_PLUS_1_SECOND');
  assert.equal(row.strictExpiryCheck.status,'RED_FINDING');
  assert.equal(row.strictExpiryCheck.result.postgrest.status,200);
  const strict=structuredClone(row.strictExpiryCheck);
  assert.deepEqual(observe(row,denied(),{...clocks,checkedAtMs:41_000}),{allAccepted:false,allDenied:true});
  assert.deepEqual(row.strictExpiryCheck,strict);
  assert.equal(row.perTransport.postgrest.lastAcceptedMs,10_000);
  assert.equal(row.perTransport.postgrest.firstRejectedMs,40_000);
  assert.equal(row.perTransport.postgrest.rejectionAfterSignedExpiryMs,31_000);
});

test('each transport records its own measured acceptance and first rejection',()=>{
  const row={};observe(row,accepted(),{...clocks,checkedAtMs:9_000});
  const sample=denied();
  sample.postgrest.checkedAtMs=11_100;sample.storage.checkedAtMs=11_200;sample.realtime.checkedAtMs=11_300;
  observe(row,sample,clocks);
  for(const [name,offset] of [['postgrest',100],['storage',200],['realtime',300]]){
    assert.equal(row.perTransport[name].lastAcceptedMs,8_000);
    assert.equal(row.perTransport[name].firstRejectedMs,10_000+offset);
    assert.equal(row.perTransport[name].afterSignedExpiryMs,1_000+offset);
    assert.equal(row.perTransport[name].status,'DENIED');
  }
  observe(row,denied(),{...clocks,checkedAtMs:12_000});
  assert.equal(row.perTransport.storage.firstRejectedMs,10_200);
  assert.equal(row.perTransport.storage.afterSignedExpiryMs,2_000);
});

test('before-expiry samples preserve original row fields without creating a strict checkpoint',()=>{
  const original={event:'restore',jwtLifetimeSeconds:3600,samples:[{elapsedMs:5}]},row=structuredClone(original);
  assert.deepEqual(observe(row,accepted(),{...clocks,checkedAtMs:9_999}),{allAccepted:true,allDenied:false});
  assert.equal(row.strictExpiryCheck,undefined);
  assert.equal(row.perTransport.postgrest.afterSignedExpiryMs,-1);
  for(const key of Object.keys(original))assert.deepEqual(row[key],original[key]);
});

test('missing ambiguous and unknown transport states fail measurement without mutating the row',()=>{
  assert.equal(typeof recordTransportSample,'function');
  const invalid=[undefined,{}, {...accepted(),storage:undefined}, {...accepted(),postgrest:{status:200,accepted:true,denied:true}},
    {...accepted(),postgrest:{status:200,accepted:false,denied:false}}, {...accepted(),storage:{status:200,accepted:'true',denied:false}},
    {...accepted(),realtime:{status:'timeout'}}, {...accepted(),realtime:{status:'connection_rejected'}},
    {...accepted(),realtime:{status:'http_500'}}, {...accepted(),realtime:{status:'unknown'}}];
  for(const sample of invalid){const row={event:'restore'};assert.throws(()=>observe(row,sample,clocks),/Transport measurement/);assert.deepEqual(row,{event:'restore'});}
});

test('invalid clocks fail measurement before recording evidence',()=>{
  assert.equal(typeof recordTransportSample,'function');
  for(const patch of [{checkedAtMs:NaN},{checkedAtMs:Infinity},{checkedAtMs:'11000'},{signedExpiryMs:undefined},{lifecycleAtMs:null}]){
    const row={};assert.throws(()=>observe(row,accepted(),{...clocks,...patch}),/Transport measurement/);assert.deepEqual(row,{});
  }
  const sample=accepted();sample.storage.checkedAtMs=NaN;
  assert.throws(()=>observe({},sample,clocks),/Transport measurement/);
});

test('strict checkpoint requires all transport measurement clocks to reach the unchanged deadline',()=>{
  const row={},sample=accepted();sample.postgrest.checkedAtMs=10_999;
  observe(row,sample,clocks);assert.equal(row.strictExpiryCheck,undefined);
  sample.postgrest.checkedAtMs=11_000;
  observe(row,sample,clocks);assert.equal(row.strictExpiryCheck.status,'RED_FINDING');
  assert.equal(row.strictExpiryCheck.result.postgrest.afterSignedExpiryMs,1_000);
});

test('a denied checkpoint records only sampled nonacceptance without claiming certification',()=>{
  for(const status of ['error','http_401','http_403']){
    const row={},sample=denied();sample.realtime.status=status;
    assert.deepEqual(observe(row,sample,clocks),{allAccepted:false,allDenied:true});
    assert.equal(row.strictExpiryCheck.status,'NO_ACCEPTANCE_OBSERVED_AT_THIS_SAMPLE');
    assert.equal(row.strictExpiryCheck.result.realtime.status,status);
    assert.equal(row.strictExpiryCheck.result.realtime.afterSignedExpiryMs,1_000);
  }
});

test('strict checkpoint retains a sanitized copy of the first sample',()=>{
  const row={},sample=accepted();sample.postgrest.privateValue='fixture-private-data';
  observe(row,sample,clocks);sample.postgrest.status=999;sample.realtime.status='error';
  assert.equal(row.strictExpiryCheck.result.postgrest.status,200);
  assert.equal(row.strictExpiryCheck.result.realtime.status,'ok');
  assert.ok(!JSON.stringify(row).includes('fixture-private-data'));
});
