import assert from 'node:assert/strict';
import {test} from 'node:test';
import {lifecycleDeadline} from './lifecycle-deadline.mjs';
const sample=at=>({postgrest:{denied:true,checkedAtMs:at},storage:{denied:true,checkedAtMs:at},realtime:{status:'error',checkedAtMs:at}});
test('approved lifecycle gate requires all actual denials by thirty seconds',()=>{
  assert.equal(lifecycleDeadline(sample(31000),1000).passed,true);
  assert.equal(lifecycleDeadline(sample(31001),1000).passed,false);
});
test('late missing accepted and connection-fault observations cannot pass lifecycle gate',()=>{
  const row=sample(5000);row.realtime.status='connection_rejected';assert.equal(lifecycleDeadline(row,1000).passed,false);
  row.realtime.status='ok';assert.equal(lifecycleDeadline(row,1000).passed,false);
  delete row.storage;assert.equal(lifecycleDeadline(row,1000).passed,false);
  assert.equal(lifecycleDeadline(sample(999),1000).passed,false);
});
