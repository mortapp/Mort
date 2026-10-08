import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
// Record assertion identity and outcome, never assertion arguments or private
// error payloads. Capture only after the real assertion has succeeded.
export async function captureAssertions(suite,execute){
  const seen=new Map(),originals=new Map();
  for(const name of ['ok','equal','notEqual','strictEqual','notStrictEqual','deepEqual','deepStrictEqual','rejects','throws']){
    const original=assert[name];originals.set(name,original);
    assert[name]=function(...args){
      const location=(new Error().stack??'').split('\n').find(line=>/auth-email-guard[\\/].*test\.mjs:\d+/.test(line));
      const match=location?.match(/auth-email-guard[\\/]([^()]+test\.mjs):(\d+):(\d+)/);
      const title=typeof args.at(-1)==='string'?args.at(-1):null;
      const record=()=>{
        if(match&&title&&title.length<250&&!/[\r\n@]/.test(title)){
          const key=`${suite}:${title}`;const old=seen.get(key);
          seen.set(key,{key,suite,file:`scripts/auth-email-guard/${match[1].replaceAll('\\','/')}`,line:Number(match[2]),assertion:name,executions:(old?.executions??0)+1,status:'PASS'});
        }
      };
      const value=original.apply(this,args);
      if(value instanceof Promise)return value.then(result=>{record();return result;});
      record();return value;
    };
  }
  try{await execute();return [...seen.values()];}finally{for(const [name,original] of originals)assert[name]=original;}
}
export function serializeEvidence(record){
  const allowed=['id','status','reason','assertions','head','fixtureId','callerRole','requestShape','concurrency','elapsedMs','expected','observed','counterChanges','stateDigest','logClean','cleanup'];
  if(Object.keys(record).some(key=>!allowed.includes(key)))throw new Error('Evidence field rejected');
  if(!/^(?:MD2|MD)-\d{3}$/.test(record.id)||!['PASS','BLOCKED','OWNER_SCOPED_OUT','NOT_RUN'].includes(record.status)
    ||!/^[a-f0-9]{40}$/.test(record.head)||!/^[a-f0-9-]{36}$/.test(record.fixtureId)
    ||record.callerRole!=='synthetic_fixture'||record.requestShape!=='synthetic-redacted-operation'
    ||record.expected!=='named assertions pass'||!['executed','not executed'].includes(record.observed)
    ||record.counterChanges!=='asserted by named tests'||!Number.isInteger(record.concurrency)||record.concurrency<1||record.concurrency>20
    ||!Number.isFinite(record.elapsedMs)||record.elapsedMs<0)throw new Error('Evidence identity or redaction contract rejected');
  if(record.status==='PASS'&&(!record.assertions?.length||record.logClean!==true||record.cleanup!==true))throw new Error('Evidence proof missing');
  for(const proof of record.assertions??[]){
    const fields=['key','suite','file','line','assertion','executions','status'];
    if(Object.keys(proof).some(key=>!fields.includes(key))||proof.status!=='PASS'||typeof proof.key!=='string'||proof.key.length>250||/[\r\n@]/.test(proof.key)
      ||!/^[a-z-]+$/.test(proof.suite)||!proof.key.startsWith(proof.suite+':')
      ||typeof proof.file!=='string'||! /^(?:scripts\/auth-email-guard|supabase\/functions|web\/auth)\/[A-Za-z0-9_./-]+$/.test(proof.file)||proof.file.includes('..')
      ||!Number.isInteger(proof.line)||proof.line<1||!Number.isInteger(proof.executions)||proof.executions<1
      ||!['ok','equal','notEqual','strictEqual','notStrictEqual','deepEqual','deepStrictEqual','rejects','throws','named_test'].includes(proof.assertion))throw new Error('Evidence assertion provenance rejected');
  }
  if(record.stateDigest&&!/^[a-f0-9]{64}$/.test(record.stateDigest))throw new Error('Evidence digest rejected');
  return JSON.stringify(record);
}
export const digestState=value=>createHash('sha256').update(JSON.stringify(value)).digest('hex');
