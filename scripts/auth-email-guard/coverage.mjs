import {readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
export const canonicalSourceDigest=bytes=>createHash('sha256').update(bytes.toString('utf8').replaceAll('\r\n','\n')).digest('hex');
export async function loadRequirements(){
  const raw=await readFile(new URL('./requirements.json',import.meta.url));
  if(canonicalSourceDigest(raw)!=='71bdfd7e56c977f91d0806d5d4cf5c96509209670fcfddb02b396ecefef05d9f')throw new Error('Immutable historical inventory drift');
  const inventory=JSON.parse(raw.toString('utf8'));
  const source=await readFile(new URL('./sources/matrix.md',import.meta.url));
  if(canonicalSourceDigest(source)!==inventory.sourceSha256)throw new Error('Immutable requirement source drift');
  const numbers=[...source.toString('utf8').matchAll(/^(\d+)\.\s/gm)].map(m=>Number(m[1]));
  if(numbers.length!==191||numbers.some((n,i)=>n!==i+1)||inventory.records.length!==519||new Set(inventory.records.map(r=>r.id)).size!==519)throw new Error('Requirement source truncation or duplicate');
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
