import {test} from 'node:test';import assert from 'node:assert/strict';
const module=await import('./startup-diagnostic.mjs').catch(()=>({}));
test('startupDiagnosticNamesFailedPhaseAndKeepsPrimaryAfterSnapshotFailure',async()=>{
 assert.equal(typeof module.runStartup,'function','Startup phase diagnostics missing');
 const primary=new Error('private-content'),events=[];
 await assert.rejects(()=>module.runStartup(async context=>{context.phase('database-health');throw primary;},{emit:e=>events.push(e),snapshot:()=>{throw new Error('private-snapshot');}}),e=>e===primary);
 assert.equal(events[0].phase,'database-health');assert.ok(!JSON.stringify(events).includes('private'));
 assert.equal(await module.runStartup(async context=>{context.phase('database-health');return 42;},{emit:e=>events.push(e)}),42);
});
