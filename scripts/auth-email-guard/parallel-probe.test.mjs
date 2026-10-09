import assert from 'node:assert/strict';
import {test} from 'node:test';
import {completeParallelRequests} from './parallel-probe.mjs';
test('parallel probe drains sibling requests before reporting a private failure',async()=>{
  let finish,settled=false;
  const sibling=new Promise(resolve=>{finish=()=>{settled=true;resolve(2);};});
  const result=completeParallelRequests([Promise.reject(new Error('private-marker')),sibling]);
  let done=false;result.catch(()=>{done=true;});
  await new Promise(resolve=>setImmediate(resolve));assert.equal(done,false);
  finish();await assert.rejects(result,/Parallel fixture probe failed/);assert.equal(settled,true);
});
test('parallel probe preserves successful transport ordering',async()=>{
  assert.deepEqual(await completeParallelRequests([Promise.resolve(1),Promise.resolve(2)]),[1,2]);
});
