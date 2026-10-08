import {test} from 'node:test';
import assert from 'node:assert/strict';
import {randomBytes,randomUUID,webcrypto} from 'node:crypto';
import {createChallengeController} from './controller.mjs';
const secret=()=>randomBytes(32).toString('base64url');
const failure={ok:false,message:'That request is not valid.'};
function setup(overrides={}){
  const calls=[],states=[];let cleared=0;
  const link=secret(),id=randomUUID(),cap=secret();
  const transport={continue:async input=>{calls.push(['continue',input]);return {ok:true,capability:cap,purpose:'confirmation',maskedRecipient:'q***@example.invalid',familyExpiresAt:new Date(Date.now()+600000).toISOString(),capabilityExpiresAt:new Date(Date.now()+300000).toISOString()};},password:async input=>{calls.push(['password',input]);return {ok:true,message:'Password updated. Return to MORT to sign in.'};},...overrides};
  const controller=createChallengeController({transport,crypto:webcrypto,now:()=>Date.now(),onState:s=>states.push(s),clearFragment:()=>{cleared++;}});
  return {controller,calls,states,link,id,cap,fragment:`#itemId=${id}&linkSecret=${link}`,cleared:()=>cleared};
}
test('scanner load removes fragment but performs zero transport; human Continue and password keep authority in memory only',async()=>{
  const s=setup();s.controller.load(s.fragment);assert.equal(s.cleared(),1);assert.equal(s.calls.length,0);assert.equal(s.states.at(-1).state,'neutral');
  await s.controller.continue();assert.equal(s.calls.length,1);assert.equal(s.states.at(-1).state,'password');assert.equal(s.states.at(-1).maskedRecipient,'q***@example.invalid');
  assert.ok(s.calls[0][1].linkSecret===s.link,'Owned link passed only in explicit transport');assert.ok(/^[0-9a-f]{64}$/.test(s.calls[0][1].verifierHash),'Verifier sent as digest');
  await s.controller.submitPassword('Good!Password7','Good!Password7');assert.equal(s.states.at(-1).state,'success');
  const raw=s.calls[1][1];assert.ok(raw.capability===s.cap,'Owned capability remains bound');assert.equal(raw.verifier.length,43);assert.ok(raw.password==='Good!Password7','Password in explicit transport only');
  const digest=Buffer.from(await webcrypto.subtle.digest('SHA-256',new TextEncoder().encode(raw.verifier))).toString('hex');assert.ok(digest===s.calls[0][1].verifierHash,'Raw verifier matches immutable digest');
  const publicStates=JSON.stringify(s.states);for(const hidden of [s.cap,s.link,raw.verifier,raw.password])assert.ok(!publicStates.includes(hidden));
  await s.controller.submitPassword('Another!Pass7','Another!Pass7');assert.equal(s.calls.length,2);
});
test('locator alone is neutral; duplicates, provider sessions and mixed fragment authority never call transport',async()=>{
  const s=setup();s.controller.load('#itemId='+s.id);assert.equal(s.states.at(-1).state,'neutral');await s.controller.continue();assert.equal(s.calls.length,0);
  for(const value of [s.fragment+'&itemId='+s.id,s.fragment+'&access_token=discard',s.fragment+'&email=someone@example.invalid','#access_token=discard&refresh_token=discard','#itemId='+s.id+'&linkSecret=bad']){s.controller.load(value);await s.controller.continue();assert.equal(s.calls.length,0);assert.notEqual(s.states.at(-1).state,'password');}
  s.controller.load('#itemId='+s.id);await s.controller.continue('00000000');assert.equal(s.calls[0][1].code,'00000000');assert.ok(!('linkSecret' in s.calls[0][1]));
});
test('Busy keeps the same verifier/link; unknown lost response is terminal and cannot rebind or replay',async()=>{
  const s=setup({continue:async input=>{s.calls.push(['continue',input]);return s.calls.length===1?{ok:false,message:'MORT is busy. Try again shortly.',retryAfterSeconds:1}:{ok:true,capability:s.cap,purpose:'recovery',maskedRecipient:'q***@example.invalid',familyExpiresAt:new Date(Date.now()+600000).toISOString(),capabilityExpiresAt:new Date(Date.now()+300000).toISOString()};}});
  s.controller.load(s.fragment);await s.controller.continue();assert.equal(s.states.at(-1).state,'neutral');assert.equal(s.states.at(-1).retryAfterSeconds,1);await s.controller.continue();assert.ok(s.calls[0][1].verifierHash===s.calls[1][1].verifierHash,'Busy retry does not rebind');assert.equal(s.states.at(-1).state,'password');
  const lost=setup({continue:async input=>{lost.calls.push(['continue',input]);throw new Error('transport unavailable');}});lost.controller.load(lost.fragment);await lost.controller.continue();assert.equal(lost.states.at(-1).state,'failure');await lost.controller.continue();assert.equal(lost.calls.length,1);
  const refreshed=setup();refreshed.controller.load('');await refreshed.controller.continue();assert.equal(refreshed.calls.length,0);
});
test('double-click, disposal and stale asynchronous completion cannot reopen password UI',async()=>{
  let release,entered;const reached=new Promise(resolve=>{entered=resolve;});const s=setup({continue:async input=>{s.calls.push(['continue',input]);entered();return await new Promise(resolve=>{release=resolve;});}});
  s.controller.load(s.fragment);const first=s.controller.continue();await reached;await s.controller.continue();assert.equal(s.calls.length,1);
  s.controller.dispose();release({ok:true,capability:s.cap,purpose:'confirmation',maskedRecipient:'q***@example.invalid',familyExpiresAt:new Date(Date.now()+600000).toISOString(),capabilityExpiresAt:new Date(Date.now()+300000).toISOString()});await first;assert.notEqual(s.states.at(-1).state,'password');
});
test('client policy and possession-only server policy preserve a valid capability; generic denial clears it',async()=>{
  const s=setup({password:async input=>{s.calls.push(['password',input]);return s.calls.length===2?{ok:false,message:'Choose a password that meets the requirements.'}:failure;}});
  s.controller.load(s.fragment);await s.controller.continue();await s.controller.submitPassword('weak','weak');assert.equal(s.calls.length,1);assert.equal(s.states.at(-1).state,'password');
  await s.controller.submitPassword('Good!Password7','Good!Password7');assert.equal(s.states.at(-1).state,'password');await s.controller.submitPassword('Other!Password8','Other!Password8');assert.equal(s.states.at(-1).state,'failure');await s.controller.submitPassword('Another!Pass9','Another!Pass9');assert.equal(s.calls.length,3);
});
