import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createChallengeTransport} from './transport.mjs';
test('fixture transport posts authority only to fixed owned endpoint, with no cookie/query/redirect storage',async()=>{
  const calls=[];
  const t=createChallengeTransport({mode:'local_fixture',endpoint:'http://127.0.0.1:55426'},async(url,init)=>{calls.push({url,init});return Response.json({ok:false,message:'MORT is busy. Try again shortly.',retryAfterSeconds:1},{status:429});});
  const result=await t.continue({itemId:'fixture locator',code:'00000000',verifierHash:'fixture digest'},new AbortController().signal);
  assert.equal(result.retryAfterSeconds,1);assert.equal(calls[0].url,'http://127.0.0.1:55426/continue');assert.equal(calls[0].init.method,'POST');assert.equal(calls[0].init.credentials,'omit');assert.equal(calls[0].init.redirect,'error');assert.equal(calls[0].init.cache,'no-store');assert.equal(calls[0].init.referrerPolicy,'no-referrer');
  await t.password({capability:'fixture capability',verifier:'fixture verifier',password:'fixture password'},new AbortController().signal);assert.equal(calls[1].url,'http://127.0.0.1:55426/password');
});
test('disabled, wrong host, query and oversized/ambiguous failure cannot masquerade as verified',async()=>{
  for(const config of [{mode:'disabled',endpoint:'http://127.0.0.1:55426'},{mode:'local_fixture',endpoint:'https://untrusted.invalid'},{mode:'local_fixture',endpoint:'http://127.0.0.1:55426?token=discard'}])assert.throws(()=>createChallengeTransport(config));
  const t=createChallengeTransport({mode:'local_fixture',endpoint:'http://127.0.0.1:55426'},async()=>new Response('x'.repeat(16385),{status:200}));
  await assert.rejects(()=>t.continue({},new AbortController().signal));
  const fake=createChallengeTransport({mode:'local_fixture',endpoint:'http://127.0.0.1:55426'},async()=>Response.json({ok:true},{status:503}));await assert.rejects(()=>fake.continue({},new AbortController().signal));
});
