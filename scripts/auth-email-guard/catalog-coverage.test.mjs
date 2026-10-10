import assert from 'node:assert/strict';
import {test} from 'node:test';
import {catalogCoverage} from './catalog-coverage.mjs';
test('catalog coverage denies a newly reachable relation or RPC without a gate or policy',()=>{
  const resources=[{name:'exposed.table',kind:'table',reachable:true},{name:'exposed.rpc()',kind:'rpc',reachable:true}];
  assert.equal(catalogCoverage(resources,{gateVerified:false,policies:[]}).passed,false);
  assert.equal(catalogCoverage(resources,{gateVerified:true,policies:[]}).passed,true);
});
test('nonclient private resources need no policy while native transports require specific coverage',()=>{
  const resources=[{name:'private.secret',kind:'table',reachable:false},{name:'private-bucket',kind:'storage',reachable:true},{name:'private-channel',kind:'realtime',reachable:true},{name:'exposed.published',kind:'publication',reachable:true}];
  assert.equal(catalogCoverage(resources,{gateVerified:true,policies:[]}).passed,false);
  assert.equal(catalogCoverage(resources,{gateVerified:true,policies:['private-bucket','private-channel','exposed.published']}).passed,true);
});
