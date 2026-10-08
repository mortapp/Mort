import {test} from 'node:test';
import assert from 'node:assert/strict';
import {serializeEvidence,captureAssertions,digestState} from './evidence.mjs';
import {randomUUID} from 'node:crypto';
test('sanitized evidence requires exact candidate, fixture, executed assertions, cleanup and fixed redacted shape',()=>{
  const base={id:'MD2-001',status:'PASS',assertions:[{key:'unit:canonical failures share response and 350ms schedule; success returns only bounded committed capability',suite:'unit',file:'supabase/functions/mort-auth-email-guard/handler_test.ts',line:148,assertion:'named_test',executions:1,status:'PASS'}],head:'a'.repeat(40),fixtureId:randomUUID(),callerRole:'synthetic_fixture',requestShape:'synthetic-redacted-operation',concurrency:1,elapsedMs:1,expected:'named assertions pass',observed:'executed',counterChanges:'asserted by named tests',stateDigest:digestState({clean:true}),logClean:true,cleanup:true};
  assert.equal(JSON.parse(serializeEvidence(base)).head,base.head);
  for(const patch of [{head:''},{fixtureId:''},{requestShape:'raw bearer credential'},{password:'synthetic-private-value'},{cleanup:false},{assertions:[]},{logClean:false}])assert.throws(()=>serializeEvidence({...base,...patch}));
  for(const patch of [{password:'private'},{file:'../../escape'},{line:0},{executions:0},{status:'NOT_RUN'},{key:'unit:private@example.invalid'}])assert.throws(()=>serializeEvidence({...base,assertions:[{...base.assertions[0],...patch}]}));
});
test('runtime assertion capture cannot turn an unexecuted or failing assertion into evidence',async()=>{
  const passed=await captureAssertions('synthetic',()=>assert.ok(true,'Owned fixed assertion'));
  assert.equal(passed.length,1);
  await assert.rejects(()=>captureAssertions('synthetic',()=>assert.ok(false,'Owned fixed assertion')));
  assert.equal((await captureAssertions('synthetic',()=>{})).length,0);
});
