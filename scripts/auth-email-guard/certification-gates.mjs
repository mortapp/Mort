import {readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {resolve} from 'node:path';
export async function loadExternalGates(gates,directory,{head,sourceSha256},read=path=>readFile(path,'utf8')){
  let manifest;
  try{const text=await read(resolve(directory,'manifest.json'));if(text.length>262144)throw new Error();manifest=JSON.parse(text);if(manifest.head!==head||manifest.sourceSha256!==sourceSha256)throw new Error();}
  catch{manifest=null;}
  return Promise.all(gates.map(async gate=>{
    const fallback={id:gate.id,status:gate.id==='unexplained-failures'?'FAIL':gate.id.startsWith('architecture-')?'NOT_RUN':'BLOCKED',head,sourceSha256};
    if(!/^[a-z][a-z0-9-]{0,80}$/.test(gate.id)||!manifest)return fallback;
    try{
      const text=await read(resolve(directory,gate.id+'.json'));
      if(text.length>262144||createHash('sha256').update(text).digest('hex')!==manifest.files?.[gate.id])return fallback;
      const row=JSON.parse(text);
      if(row.id!==gate.id||row.head!==head||row.sourceSha256!==sourceSha256||Object.hasOwn(row,'fullGuardCertified'))return fallback;
      return Object.fromEntries(['id','status','head','sourceSha256','executions','assertionKeys','cleanup','logClean'].filter(key=>Object.hasOwn(row,key)).map(key=>[key,row[key]]));
    }catch{return fallback;}
  }));
}
export function computeCertification(registry,evidence,{head,sourceSha256}){
  if(Object.hasOwn(evidence??{},'fullGuardCertified'))throw new Error('Certification is derived, never an input');
  const identity=/^[a-f0-9]{40}$/.test(head)&&/^[a-f0-9]{64}$/.test(sourceSha256)
    &&evidence?.schema===1&&evidence.head===head&&evidence.sourceSha256===sourceSha256&&evidence.sourceClean===true;
  const required=registry?.schema===1&&Array.isArray(registry.gates)?registry.gates:[];
  const rows=Array.isArray(evidence?.gates)?evidence.gates:[];
  const unique=required.length>0&&new Set(required.map(row=>row.id)).size===required.length
    &&new Set(rows.map(row=>row.id)).size===rows.length&&rows.length===required.length;
  const gates=required.map(gate=>{
    const row=rows.find(value=>value.id===gate.id);
    const current=identity&&row?.head===head&&row?.sourceSha256===sourceSha256;
    const scoped=current&&gate.scopeOutApproved===true&&row.status==='OWNER_SCOPED_OUT';
    const executed=current&&row.status==='PASS'&&Number.isSafeInteger(row.executions)&&row.executions>0
      &&row.cleanup===true&&row.logClean===true&&Array.isArray(row.assertionKeys)&&row.assertionKeys.length>0
      &&row.assertionKeys.every(key=>typeof key==='string'&&key.length<250&&!/[\r\n@]/.test(key)&&key.includes(':'));
    return Object.freeze({id:gate.id,status:scoped?'OWNER_SCOPED_OUT':executed?'PASS':current&&['FAIL','BLOCKED','NOT_RUN'].includes(row?.status)?row.status:'NOT_RUN'});
  });
  return Object.freeze({fullGuardCertified:Boolean(unique&&identity&&gates.every(row=>['PASS','OWNER_SCOPED_OUT'].includes(row.status))),gates:Object.freeze(gates)});
}
