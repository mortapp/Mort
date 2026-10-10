import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const module=await import('./verify-blueprint-lock.mjs').catch(()=>({}));
const parts=await Promise.all(['PART1.md','PART2.md'].map(name=>readFile(new URL('../../docs/security/auth-guard-blueprint/'+name,import.meta.url),'utf8')));
test('blueprintLockVerifiesWhenUntouched',()=>{
 assert.equal(typeof module.makeLock,'function','Immutable lock implementation missing');
 const lock=module.makeLock(parts);assert.equal(module.verifyLock(parts,lock),true);
});
test('blueprintLockFailsOnEditedImmutableSection',()=>{
 assert.equal(typeof module.makeLock,'function','Immutable lock implementation missing');
 const lock=module.makeLock(parts);
 const changed=[parts[0].replace('IMM-01. Never claim','IMM-01. Always claim'),parts[1]];
 assert.throws(()=>module.verifyLock(changed,lock),/Immutable blueprint mismatch/);
 assert.equal(module.verifyLock([parts[0].replace('Total checkpoints: CP0 to CP16','Total checkpoints: unchanged scope CP0 to CP16'),parts[1]],lock),true);
 assert.throws(()=>module.verifyLock([parts[0].replace('## 2. THE IMMUTABLE CORE [IMMUTABLE]','## 2. THE IMMUTABLE CORE'),parts[1]],lock),/Immutable blueprint mismatch/);
});
