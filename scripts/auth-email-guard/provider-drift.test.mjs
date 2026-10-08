import assert from 'node:assert/strict';
import {startDriftFixture,stopDriftFixture} from './fixture.mjs';
import {createFixtureProvider} from '../../supabase/functions/_shared/auth_email_guard/provider.ts';
export async function run(handle){
  await startDriftFixture(handle);
  try{
    const response=await fetch('http://127.0.0.1:55441/health',{signal:AbortSignal.timeout(2000)});
    assert.equal((await response.json()).version,'v2.195.0','Second pinned provider actually runs');
    let health=0,writes=0;
    // Route the existing constructor's fixed health URL to the independently
    // running second provider. No response is mocked or version fabricated.
    const route=async(input,init)=>{if(String(input)==='http://127.0.0.1:55421/health'){health++;return fetch('http://127.0.0.1:55441/health',init)}writes++;throw new Error('Unexpected drift write');};
    await assert.rejects(()=>createFixtureProvider({mode:'local_fixture',authUrl:handle.authUrl,serviceKey:handle.serviceKey},{reconcile:async()=>{throw new Error('Unexpected drift reconciliation')}},route),/Fixture provider refused/,'Guard refuses actual second pinned provider version before authority');
    assert.equal(health,1,'Drift refusal reads actual alternate provider health');assert.equal(writes,0,'Drift refusal performs zero credential writes');
    await assert.doesNotReject(()=>createFixtureProvider({mode:'local_fixture',authUrl:handle.authUrl,serviceKey:handle.serviceKey},{reconcile:async()=> 'pending'}),'Primary pinned provider remains accepted');
    console.log('GREEN actual v2.195.0 refused; v2.197.0 positive; zero drift writes');
  }finally{await stopDriftFixture(handle);}
}
