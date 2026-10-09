import assert from 'node:assert/strict';
import {run as sessionLive} from './session-live.test.mjs';
export async function run(handle){
  await sessionLive(handle,{signedExpiry:true});
  assert.ok(handle.guardedExpiryEvidence,'Guarded transport test executes actual signed-token expiry with session-live policies installed');
  assert.equal(handle.guardedExpiryEvidence.policy,'REJECT_BY_SIGNED_EXPIRY_PLUS_1_SECOND','Strict signed-expiry policy is unchanged');
}
