import {test} from 'node:test';import assert from 'node:assert/strict';
const module=await import('./cleanup-primary.mjs').catch(()=>({}));
test('cleanupAttemptsAllStepsAndNeverMasksPrimary',async()=>{
 assert.equal(typeof module.completeCleanup,'function','Primary-preserving cleanup missing');
 const primary=new Error('primary-private'),secondary=new Error('cleanup-private'),called=[],events=[];
 await assert.rejects(()=>module.completeCleanup(primary,[()=>{called.push(1);throw secondary;},()=>{called.push(2);} ],e=>events.push(e)),e=>e===primary);
 assert.deepEqual(called,[1,2]);assert.ok(!JSON.stringify(events).includes('private'));
 await module.completeCleanup(null,[()=>{called.push(3);} ],e=>events.push(e));assert.deepEqual(called,[1,2,3]);
 await assert.rejects(()=>module.completeCleanup(null,[()=>{throw secondary;}],()=>{}),e=>e===secondary);
});
