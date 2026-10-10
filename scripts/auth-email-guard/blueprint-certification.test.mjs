import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
let api={};try{api=await import('./blueprint-certification.mjs');}catch(e){if(e.code!=='ERR_MODULE_NOT_FOUND')throw e;}
const head='a'.repeat(40),sourceSha256='b'.repeat(64);
test('planted gate evidence fails its independent file digest',async()=>{
  assert.equal(typeof api.readBlueprintEvidence,'function');
  const {createHash}=await import('node:crypto');
  const text=JSON.stringify({schema:1,head,sourceSha256,sourceClean:true,gates:[]});
  const manifest=JSON.stringify({head,sourceSha256,sha256:createHash('sha256').update(text).digest('hex')});
  const good=await api.readBlueprintEvidence('fixture',{head,sourceSha256},p=>Promise.resolve(p.endsWith('manifest.json')?manifest:text));
  assert.equal(good.head,head);
  const bad=await api.readBlueprintEvidence('fixture',{head,sourceSha256},p=>Promise.resolve(p.endsWith('manifest.json')?manifest:text+' '));
  assert.equal(bad.sourceClean,false);assert.equal(bad.gates.length,0);
});
test('all immutable appendix gates are registered and missing evidence never certifies',async()=>{
  assert.equal(typeof api.registryFromAppendix,'function');
  const text=await readFile('docs/security/auth-guard-blueprint/PART2.md','utf8');
  const registry=api.registryFromAppendix(text);
  assert.equal(registry.gates.length,47);
  assert.equal(registry.gates.filter(g=>g.tier==='external').length,12);
  const result=api.certifyBlueprint(registry,{schema:1,head,sourceSha256,sourceClean:true,gates:[]},{head,sourceSha256});
  assert.equal(result.fullGuardCertified,false);assert.equal(result.level,'NOT_CERTIFIED');
  assert.throws(()=>api.registryFromAppendix(text.replace(/^\| G01 .*\r?\n/m,'')));
});
test('certification levels require exact evidence and cannot be assigned by an input flag',async()=>{
  assert.equal(typeof api.certifyBlueprint,'function');
  const registry=api.registryFromAppendix(await readFile('docs/security/auth-guard-blueprint/PART2.md','utf8'));
  const rows=registry.gates.map(g=>({id:g.id,head,sourceSha256,status:g.tier==='local'?'PASS':'BLOCKED',executions:1,assertionKeys:['fixture:positive-and-negative-controls'],cleanup:true,logClean:true}));
  const evidence={schema:1,head,sourceSha256,sourceClean:true,gates:rows};
  assert.equal(api.certifyBlueprint(registry,evidence,{head,sourceSha256}).level,'NOT_CERTIFIED','Three consecutive serial reports are mandatory');
  evidence.serialRuns=[1,2,3].map(run=>({run,head,status:'PASS',cleanup:true,logClean:true}));
  assert.equal(api.certifyBlueprint(registry,evidence,{head,sourceSha256}).level,'LOCAL_GUARD_VERIFIED');
  rows[0].head='c'.repeat(40);assert.equal(api.certifyBlueprint(registry,evidence,{head,sourceSha256}).level,'NOT_CERTIFIED');
  assert.throws(()=>api.certifyBlueprint(registry,{...evidence,fullGuardCertified:true},{head,sourceSha256}));
});
