import assert from 'node:assert/strict';
import {test} from 'node:test';
import {readFile} from 'node:fs/promises';
import {computeCertification,loadExternalGates} from './certification-gates.mjs';
const head='a'.repeat(40),sourceSha256='b'.repeat(64);
const registry={schema:1,gates:[{id:'local',scopeOutApproved:false},{id:'external',scopeOutApproved:false}]};
const proof=id=>({id,status:'PASS',head,sourceSha256,executions:1,assertionKeys:['unit:Owned fixed assertion'],cleanup:true,logClean:true});
const evidence={schema:1,head,sourceSha256,sourceClean:true,gates:registry.gates.map(row=>proof(row.id))};
test('computed certification becomes true only for complete exact-candidate executed evidence',()=>{
  assert.equal(computeCertification(registry,evidence,{head,sourceSha256}).fullGuardCertified,true);
  for(const patch of [{head:'c'.repeat(40)},{sourceSha256:'c'.repeat(64)},{sourceClean:false},{gates:[]},{gates:[proof('local')]}])assert.equal(computeCertification(registry,{...evidence,...patch},{head,sourceSha256}).fullGuardCertified,false);
});
test('blocked failed missing empty stale and duplicate gate evidence cannot certify',()=>{
  for(const patch of [{status:'BLOCKED'},{status:'FAIL'},{status:'NOT_RUN'},{executions:0},{assertionKeys:[]},{cleanup:false},{logClean:false},{head:'c'.repeat(40)},{sourceSha256:'c'.repeat(64)},{status:'OWNER_SCOPED_OUT'}]){
    assert.equal(computeCertification(registry,{...evidence,gates:[proof('local'),{...proof('external'),...patch}]},{head,sourceSha256}).fullGuardCertified,false);
  }
  assert.equal(computeCertification(registry,{...evidence,gates:[...evidence.gates,proof('local')]},{head,sourceSha256}).fullGuardCertified,false);
});
test('direct flag input or mutation cannot override computed result',()=>{
  assert.throws(()=>computeCertification(registry,{...evidence,fullGuardCertified:true},{head,sourceSha256}));
  const result=computeCertification(registry,{...evidence,gates:[]},{head,sourceSha256});
  assert.throws(()=>{result.fullGuardCertified=true;});assert.equal(result.fullGuardCertified,false);
});
test('only a specifically approved scope-out can be excluded from computation',()=>{
  const approved={schema:1,gates:[{id:'local',scopeOutApproved:false},{id:'external',scopeOutApproved:true}]};
  assert.equal(computeCertification(approved,{...evidence,gates:[proof('local'),{id:'external',status:'OWNER_SCOPED_OUT',head,sourceSha256}]},{head,sourceSha256}).fullGuardCertified,true);
});
test('runtime certifier never assigns a literal full certification flag',async()=>{
  const source=await readFile(new URL('./certify.mjs',import.meta.url),'utf8');
  assert.ok(!/fullGuardCertified\s*:\s*(?:true|false)\b/.test(source));
});
test('external evidence requires a matching file digest and exact candidate before it can pass',async()=>{
  const {createHash}=await import('node:crypto');
  const file=JSON.stringify(proof('external'));
  const manifest=JSON.stringify({head,sourceSha256,files:{external:createHash('sha256').update(file).digest('hex')}});
  const read=async name=>name.endsWith('manifest.json')?manifest:file;
  assert.equal((await loadExternalGates(registry.gates,'synthetic',{head,sourceSha256},read)).find(row=>row.id==='external').status,'PASS');
  assert.notEqual((await loadExternalGates(registry.gates,'synthetic',{head,sourceSha256},async name=>name.endsWith('manifest.json')?manifest:file+' ')).find(row=>row.id==='external').status,'PASS');
  assert.notEqual((await loadExternalGates(registry.gates,'synthetic',{head:'c'.repeat(40),sourceSha256},read)).find(row=>row.id==='external').status,'PASS');
});
