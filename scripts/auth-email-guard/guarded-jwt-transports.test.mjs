import assert from 'node:assert/strict';
import {run as sessionLive} from './session-live.test.mjs';
export async function run(handle,{signedExpiry=false,sessionRunner=sessionLive}={}){
  await sessionRunner(handle,{signedExpiry});
  assert.ok(handle.sessionLiveEvidence,'Guarded transport lifecycle suite executes actual session-live assertions');
  if(!signedExpiry){
    handle.guardedLifecycleEvidence={policy:'REFUSE_PROTECTED_TRANSPORTS_WITHIN_30_SECONDS',historicalStrictPolicy:'REJECT_BY_SIGNED_EXPIRY_PLUS_1_SECOND',expiryCharacterized:false,scope:'owned SELECT private GET new private joins',hostedChanged:false};
    return;
  }
  assert.ok(handle.guardedExpiryEvidence,'Guarded transport test executes actual signed-token expiry with session-live policies installed');
  assert.equal(handle.guardedExpiryEvidence.policy,'REFUSE_PROTECTED_TRANSPORTS_WITHIN_30_SECONDS','Owner-approved lifecycle acceptance policy is explicit');
  assert.equal(handle.guardedExpiryEvidence.historicalStrictPolicy,'REJECT_BY_SIGNED_EXPIRY_PLUS_1_SECOND','Historical strict policy remains recorded separately');
}
