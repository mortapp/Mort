import {test} from 'node:test';
import assert from 'node:assert/strict';
import * as coverage from './coverage.mjs';
const {validateCoverage,loadRequirements,canonicalSourceDigest}=coverage;
import {readFile} from 'node:fs/promises';
import {spawnSync} from './subprocess-runner.mjs';
import {caseMappings} from './cases.mjs';
import {fixtureProcessEnv} from './fixture.mjs';
test('catalog counts derive from complete consecutive matrix and retained records without magic totals',()=>{
  assert.equal(typeof coverage.validateRequirementInventory,'function');
  const inventory={records:[{id:'MD-001'},{id:'MD2-001'},{id:'MD2-002'}]};
  assert.deepEqual(coverage.validateRequirementInventory(inventory,'1. First\n2. Second\n'),{currentRequirements:2,retainedHistoricalRequirements:1,total:3});
  assert.throws(()=>coverage.validateRequirementInventory(inventory,'1. First\n'));
  assert.throws(()=>coverage.validateRequirementInventory({records:[...inventory.records,{id:'MD-001'}]},'1. First\n2. Second\n'));
  assert.throws(()=>coverage.validateRequirementInventory(inventory,'1. First\n3. Third\n'));
});
test('immutable requirement digests tolerate Git line-ending conversion but reject content changes',async()=>{
  const source=await readFile(new URL('./sources/matrix.md',import.meta.url));
  assert.equal(canonicalSourceDigest(source),canonicalSourceDigest(Buffer.from(source.toString('utf8').replaceAll('\n','\r\n'))));
  assert.notEqual(canonicalSourceDigest(source),canonicalSourceDigest(Buffer.concat([source,Buffer.from('changed requirement')])));
});

test('eight owner-excluded BLOCKED gates retain the exact baseline disposition and reason',async()=>{
  const result=spawnSync('git',['show','90b09744048c7e52837bce45d5d8c8b0f4840b0b:scripts/auth-email-guard/cases.mjs'],{env:fixtureProcessEnv(),encoding:'utf8',windowsHide:true});
  assert.equal(result.status,0);
  const source=result.stdout.replace("from './coverage.mjs'",`from '${new URL('./coverage.mjs',import.meta.url).href}'`);
  const baseline=await import('data:text/javascript;base64,'+Buffer.from(source).toString('base64'));
  const ids=new Set([29,95,115,126,134,135,136,168].map(id=>`MD2-${String(id).padStart(3,'0')}`));
  const before=baseline.caseMappings.filter(row=>ids.has(row.id)),after=caseMappings.filter(row=>ids.has(row.id));
  assert.equal(before.length,8);assert.equal(after.length,8);
  assert.deepEqual(after,before);assert.ok(after.every(row=>row.disposition==='BLOCKED'&&row.assertions.length===0&&row.reason));
});
test('191 consecutive current IDs and 519 preserved records cannot inherit historical PASS',async()=>{
  const source=await loadRequirements();
  assert.equal(source.records.length,519);
  assert.equal(new Set(source.records.map(r=>r.id)).size,519);
  const ids=source.records.filter(r=>r.id.startsWith('MD2-')).map(r=>r.id);
  assert.deepEqual(ids,Array.from({length:191},(_,i)=>`MD2-${String(i+1).padStart(3,'0')}`));
  assert.throws(()=>validateCoverage(ids,[]));
  assert.throws(()=>validateCoverage(ids,ids.map(id=>({id,status:'PASS',assertions:[]}))));
  assert.throws(()=>validateCoverage(ids,ids.map(id=>({id,disposition:'EXECUTE',assertions:[],reason:''}))));
  assert.throws(()=>validateCoverage(ids,ids.map(id=>({id,disposition:'BLOCKED',assertions:[],reason:''}))));
});
