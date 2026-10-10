import {test} from 'node:test';
import assert from 'node:assert/strict';
import {run} from './guarded-jwt-transports.test.mjs';
test('serial certification executes lifecycle checks without repeating a signed-expiry wait',async()=>{
  const handle={};let invoked;
  await run(handle,{sessionRunner:async(h,options)=>{invoked=options;h.sessionLiveEvidence={jwtLifetimeSeconds:3600,earlySamples:{revocation:[],passwordChange:[],restore:[]}};}});
  assert.deepEqual(invoked,{signedExpiry:false});
  assert.equal(handle.guardedLifecycleEvidence.policy,'REFUSE_PROTECTED_TRANSPORTS_WITHIN_30_SECONDS');
  assert.equal(handle.guardedLifecycleEvidence.expiryCharacterized,false);
});
test('explicit guarded expiry characterization preserves the original assertions',async()=>{
  const handle={};let invoked;
  await run(handle,{signedExpiry:true,sessionRunner:async(h,options)=>{invoked=options;h.sessionLiveEvidence={};h.guardedExpiryEvidence={policy:'REFUSE_PROTECTED_TRANSPORTS_WITHIN_30_SECONDS',historicalStrictPolicy:'REJECT_BY_SIGNED_EXPIRY_PLUS_1_SECOND'};}});
  assert.deepEqual(invoked,{signedExpiry:true});
});
test('missing executed lifecycle evidence cannot be treated as a pass',async()=>{
  await assert.rejects(run({},{sessionRunner:async()=>{}}));
});
