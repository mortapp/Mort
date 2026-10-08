import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,readFile,rm,writeFile} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {randomUUID} from 'node:crypto';
import {advanceJournal,readJournal,assertActivationReadiness} from './control.mjs';
test('partial activation and missing runtime/key configuration cannot pass the full cutover gate',()=>{
  const complete={sendEmailHook:true,tokenHook:true,mutationGuard:true,browser:true,delivery:true,trustedIngress:true,keyConfiguration:true,providerCompatibility:true};
  assert.doesNotThrow(()=>assertActivationReadiness(complete));
  for(const key of Object.keys(complete)){
    assert.throws(()=>assertActivationReadiness({...complete,[key]:false}));
    const partial=Object.fromEntries(Object.keys(complete).map(k=>[k,k===key]));assert.throws(()=>assertActivationReadiness(partial));
  }
  assert.throws(()=>assertActivationReadiness({}));
});
test('external journal advances, rejects wrong identity, corrupt state and concurrent writer',async()=>{
  const directory=await mkdtemp(join(tmpdir(),'mort-guard-journal-')),id=randomUUID();
  try{
    assert.equal(await readJournal(directory,id),null);
    assert.equal(await advanceJournal(directory,id,1),2);
    assert.equal(await advanceJournal(directory,id,2),3);
    await assert.rejects(()=>advanceJournal(directory,randomUUID(),3));
    await writeFile(join(directory,'generation.lock'),'owned');
    await assert.rejects(()=>advanceJournal(directory,id,3));
    await rm(join(directory,'generation.lock'));
    const raw=JSON.parse(await readFile(join(directory,'generation.json'),'utf8'));
    assert.equal(raw.generation,3);
    await writeFile(join(directory,'generation.json'),'{broken');
    await assert.rejects(()=>advanceJournal(directory,id,3));
  }finally{await rm(directory,{recursive:true,force:true});}
});
