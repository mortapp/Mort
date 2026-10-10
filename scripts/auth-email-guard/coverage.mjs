import {readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
export const canonicalSourceDigest=bytes=>createHash('sha256').update(bytes.toString('utf8').replaceAll('\r\n','\n')).digest('hex');
export function validateRequirementInventory(inventory,matrix){
  const records=inventory?.records;
  const numbers=[...matrix.matchAll(/^(\d+)\.\s/gm)].map(m=>Number(m[1]));
  if(!Array.isArray(records)||!records.length||!numbers.length||numbers.some((n,i)=>n!==i+1)||new Set(records.map(r=>r.id)).size!==records.length)throw new Error('Requirement source truncation or duplicate');
  const current=records.filter(r=>/^MD2-\d+$/.test(r.id));
  if(current.length!==numbers.length||current.some((r,i)=>r.id!==`MD2-${String(i+1).padStart(3,'0')}`))throw new Error('Requirement source truncation or duplicate');
  const counts={currentRequirements:current.length,retainedHistoricalRequirements:records.length-current.length,total:records.length};
  if(inventory.currentCount!==undefined&&inventory.currentCount!==counts.currentRequirements||inventory.historicalCount!==undefined&&inventory.historicalCount!==counts.retainedHistoricalRequirements)throw new Error('Declared inventory count drift');
  return Object.freeze(counts);
}
export async function loadRequirements(){
  const raw=await readFile(new URL('./requirements.json',import.meta.url));
  if(canonicalSourceDigest(raw)!=='71bdfd7e56c977f91d0806d5d4cf5c96509209670fcfddb02b396ecefef05d9f')throw new Error('Immutable historical inventory drift');
  const inventory=JSON.parse(raw.toString('utf8'));
  const source=await readFile(new URL('./sources/matrix.md',import.meta.url));
  if(canonicalSourceDigest(source)!==inventory.sourceSha256)throw new Error('Immutable requirement source drift');
  if(inventory.sourceSha256!=='cb2e8b61e78c3f3aa9fbd6f5f7dcdc13c0cf113b5a4052d47e0e26bb0f6fbe31')throw new Error('Immutable matrix pin drift');
  inventory.counts=validateRequirementInventory(inventory,source.toString('utf8'));
  return inventory;
}
export function validateCoverage(ids,mapping){
  if(mapping.length!==ids.length||new Set(mapping.map(row=>row.id)).size!==ids.length)throw new Error('Missing/duplicate coverage');
  for(const id of ids){
    const row=mapping.find(row=>row.id===id);
    if(!row||row.status!==undefined||!['EXECUTE','BLOCKED','OWNER_SCOPED_OUT'].includes(row.disposition))throw new Error('Inherited or unknown runtime result');
    if(row.disposition==='EXECUTE'&&(!Array.isArray(row.assertions)||!row.assertions.length||row.assertions.some(s=>typeof s!=='string'||!s.includes(':'))))throw new Error('Empty/unowned executable assertion');
    if(row.disposition!=='EXECUTE'&&(!row.reason||row.assertions?.length))throw new Error('Unexplained or fabricated disposition');
  }
}
