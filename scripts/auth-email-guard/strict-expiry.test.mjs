import assert from 'node:assert/strict';
import {test} from 'node:test';
import * as observations from './transport-observation.mjs';
const sample=at=>({postgrest:{denied:true,checkedAtMs:at},storage:{denied:true,checkedAtMs:at},realtime:{status:'error',checkedAtMs:at}});
test('strict expiry rejects a late sample that could borrow native provider clock skew',()=>{
  assert.equal(typeof observations.strictExpiryObservation,'function');
  assert.equal(observations.strictExpiryObservation(sample(32000),{signedExpiryMs:1000,startedAtMs:1000}).withinStrictWindow,false);
});
test('strict expiry accepts only actual denials measured inside the original one-second window',()=>{
  assert.equal(typeof observations.strictExpiryObservation,'function');
  assert.equal(observations.strictExpiryObservation(sample(1500),{signedExpiryMs:1000,startedAtMs:1010}).withinStrictWindow,true);
});
test('strict expiry refuses early, accepting and invalid observations',()=>{
  assert.equal(typeof observations.strictExpiryObservation,'function');
  for(const [s,start] of [[sample(900),900],[{...sample(1500),storage:{denied:false,checkedAtMs:1500}},1010],[sample(NaN),1010]])assert.equal(observations.strictExpiryObservation(s,{signedExpiryMs:1000,startedAtMs:start}).withinStrictWindow,false);
});
