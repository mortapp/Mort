import {test} from 'node:test';
import assert from 'node:assert/strict';
import {validateCoverage,loadRequirements,canonicalSourceDigest} from './coverage.mjs';
import {readFile} from 'node:fs/promises';
test('immutable requirement digests tolerate Git line-ending conversion but reject content changes',async()=>{
  const source=await readFile(new URL('./sources/matrix.md',import.meta.url));
  assert.equal(canonicalSourceDigest(source),canonicalSourceDigest(Buffer.from(source.toString('utf8').replaceAll('\n','\r\n'))));
  assert.notEqual(canonicalSourceDigest(source),canonicalSourceDigest(Buffer.concat([source,Buffer.from('changed requirement')])));
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
