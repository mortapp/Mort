import assert from 'node:assert/strict';
import {test} from 'node:test';
let characterize;
try{({sessionLiveCharacterization:characterize}=await import('./local-characterizations.mjs'));}catch(error){if(error.code!=='ERR_MODULE_NOT_FOUND')throw error;}
const fixture=()=>({jwtLifetimeSeconds:3600,scope:'owned SELECT private GET new private joins',hostedChanged:false,...Object.fromEntries(['revocation','passwordChange','restore'].map(event=>[event,Object.fromEntries(['postgrest','storage','realtime'].map(name=>[name,{status:name==='realtime'?'error':200,denied:true,measuredAfterLifecycleMs:5000}]))]))});
test('session characterization preserves measured denials and strips unapproved private values',()=>{
  assert.equal(typeof characterize,'function','Measured session evidence must be exported');
  const value=fixture();value.secret='private-fixture-value';value.restore.postgrest.secret='private-fixture-value';
  const result=characterize(value);
  assert.equal(result.hostedChanged,false);assert.equal(result.status,'LOCAL_NAMED_ASSERTIONS_EXECUTED');
  assert.equal(result.restore.postgrest.measuredAfterLifecycleMs,5000);
  assert.ok(!JSON.stringify(result).includes('private-fixture-value'));
});
test('session characterization refuses missing unexecuted or accepting transport evidence',()=>{
  assert.equal(typeof characterize,'function');
  for(const value of [undefined,{}, {...fixture(),restore:undefined}, {...fixture(),hostedChanged:true}, {...fixture(),jwtLifetimeSeconds:60}])assert.throws(()=>characterize(value),/Session evidence/);
  const value=fixture();value.revocation.storage.denied=false;
  assert.throws(()=>characterize(value),/Session evidence/);
});
test('early session evidence requires paired five and thirty second denials and fresh controls',()=>{
  const value=fixture();
  const samples=Object.fromEntries(['revocation','passwordChange','restore'].map(event=>[event,[5000,30000].map(targetOffsetMs=>({targetOffsetMs,freshControlsPassed:true,predicateDenied:true,secret:'private-marker',observations:Object.fromEntries(['postgrest','storage','realtime'].map(name=>[name,{status:name==='realtime'?'error':200,measuredAfterLifecycleMs:targetOffsetMs+50}]))}))]));
  value.earlySamples=samples;
  const result=characterize(value);
  assert.equal(result.earlySamples.restore[1].targetOffsetMs,30000);
  assert.ok(!JSON.stringify(result).includes('private-marker'));
  for(const bad of [[],[samples.restore[0]],samples.restore.map(row=>({...row,freshControlsPassed:false})),samples.restore.map(row=>({...row,predicateDenied:false}))]){
    assert.throws(()=>characterize({...value,earlySamples:{...samples,restore:bad}}),/Session evidence/);
  }
});
