import assert from 'node:assert/strict';
import {test} from 'node:test';
import {idleUntil} from './idle-wait.mjs';
test('idle expiry wait emits timestamped gaps without running subprocess probes',async()=>{
  let wall=1000,mono=0;const events=[];
  await idleUntil(91000,{wallNow:()=>wall,monoNow:()=>mono,sleep:async ms=>{wall+=ms;mono+=ms;},emit:row=>events.push(row)});
  assert.equal(events.length,3);
  assert.deepEqual(events.map(row=>row.gapMs),[30000,30000,30000]);
  assert.equal(events.at(-1).remainingMs,0);
  assert.ok(events.every(row=>typeof row.timestamp==='string'&&row.monotonicGapMs===30000));
});
test('idle heartbeat exposes wall-clock pause and does not conceal elapsed time',async()=>{
  let wall=1000,mono=0;const events=[];
  await idleUntil(61000,{wallNow:()=>wall,monoNow:()=>mono,sleep:async ms=>{wall+=ms+120000;mono+=ms;},emit:row=>events.push(row)});
  assert.equal(events.length,1);assert.equal(events[0].gapMs,150000);assert.equal(events[0].monotonicGapMs,30000);
});
