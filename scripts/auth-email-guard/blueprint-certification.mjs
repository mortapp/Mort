import {computeCertification} from './certification-gates.mjs';
import {readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {resolve} from 'node:path';
export async function readBlueprintEvidence(directory,identity,read=p=>readFile(p,'utf8')){
  const fallback={schema:1,...identity,sourceClean:false,gates:[]};
  try{
    const manifestText=await read(resolve(directory,'manifest.json'));
    const text=await read(resolve(directory,'evidence.json'));
    if(manifestText.length>262144||text.length>1048576)throw new Error('Evidence size limit');
    const manifest=JSON.parse(manifestText),evidence=JSON.parse(text);
    if(manifest.head!==identity.head||manifest.sourceSha256!==identity.sourceSha256||manifest.sha256!==createHash('sha256').update(text).digest('hex')||evidence.head!==identity.head||evidence.sourceSha256!==identity.sourceSha256||Object.hasOwn(evidence,'fullGuardCertified'))throw new Error('Invalid evidence identity');
    return evidence;
  }catch{return fallback;}
}
export function registryFromAppendix(text){
  const rows=[...text.matchAll(/^\| ([GH]\d{2}) \| ([^|]+) \| ([^|]+) \|\r?$/gm)];
  const expected=[...Array.from({length:35},(_,i)=>`G${String(i+1).padStart(2,'0')}`),...Array.from({length:12},(_,i)=>`H${String(i+1).padStart(2,'0')}`)];
  if(rows.length!==expected.length||rows.some((r,i)=>r[1]!==expected[i]))throw new Error('Incomplete or reordered immutable gates registry');
  return Object.freeze({schema:1,gates:Object.freeze(rows.map(r=>Object.freeze({id:r[1],description:r[2].trim(),tier:r[1].startsWith('G')?'local':'external',requiredEvidenceType:'exact-head-executed-named-assertions',scopeOutApproved:false,blockedBy:r[1].startsWith('H')?r[3].trim():null,checkpoint:r[3].trim()})))});
}
export function certifyBlueprint(registry,evidence,identity){
  const base=computeCertification(registry,evidence,identity);
  const streak=Array.isArray(evidence?.serialRuns)&&evidence.serialRuns.length===3&&evidence.serialRuns.every((r,i)=>r.run===i+1&&r.head===identity.head&&r.status==='PASS'&&r.cleanup===true&&r.logClean===true);
  const local=streak&&registry.gates.filter(g=>g.tier==='local').every(g=>base.gates.find(r=>r.id===g.id)?.status==='PASS');
  // Staging readiness additionally requires the separate owner review; it is never inferred from a build.
  const staging=local&&evidence?.stagingApproval?.head===identity.head&&evidence.stagingApproval.approved===true;
  const fullGuardCertified=base.fullGuardCertified&&local;
  return Object.freeze({...base,fullGuardCertified,level:fullGuardCertified?'FULL_GUARD_CERTIFIED':staging?'STAGING_READY':local?'LOCAL_GUARD_VERIFIED':'NOT_CERTIFIED'});
}
