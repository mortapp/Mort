import {spawn as nodeSpawn,spawnSync as nodeSpawnSync,execFileSync as nodeExecFileSync} from 'node:child_process';
import {recordSubprocessFailure} from './subprocess-diagnostic.mjs';

const captureLimit=4*1024*1024;
function record(result){
  if(result.status===0)return result;
  const stderr=Buffer.isBuffer(result.stderr)?result.stderr:typeof result.stderr==='string'?Buffer.from(result.stderr):Buffer.alloc(0);
  if(stderr.length>captureLimit)console.error('Fixture subprocess stderr capture truncated at 4194304 bytes; fingerprint covers captured prefix only');
  recordSubprocessFailure({status:result.status,signal:result.signal,error:result.error,stderr:stderr.subarray(0,captureLimit)});
  return result;
}

export function spawnSync(...args){
  try{return record(nodeSpawnSync(...args));}
  catch(error){record({status:error.status??null,signal:error.signal,error,stderr:error.stderr});throw error;}
}

export function execFileSync(file,args,options){
  if(!Array.isArray(args)){options=args;args=[];}
  const settings={...options};
  // Explicit pipe prevents Node's implicit forwarding of exception stderr.
  // Preserve stdin/stdout modes and return type while capturing stderr silently.
  const modes=Array.isArray(settings.stdio)?[...settings.stdio]:Array(3).fill(settings.stdio??'pipe');
  modes[2]='pipe';settings.stdio=modes;
  try{return nodeExecFileSync(file,args,settings);}
  catch(error){record({status:error.status??null,signal:error.signal,error,stderr:error.stderr});throw error;}
}

export function spawn(...args){
  let child;
  try{child=nodeSpawn(...args);}
  catch(error){record({status:null,signal:null,error,stderr:null});throw error;}
  let error,bytes=0,truncated=false;const chunks=[];
  child.stderr?.on('data',value=>{
    const chunk=Buffer.isBuffer(value)?value:Buffer.from(value);
    const remaining=captureLimit-bytes;
    if(chunk.length>remaining)truncated=true;
    if(remaining>0){const captured=chunk.subarray(0,remaining);chunks.push(captured);bytes+=captured.length;}
  });
  child.on('error',value=>{error=value;});
  child.once('close',(status,signal)=>{
    if(status===0&&!error)return;
    if(truncated)console.error('Fixture subprocess stderr capture truncated at 4194304 bytes; fingerprint covers captured prefix only');
    recordSubprocessFailure({status,signal,error,stderr:Buffer.concat(chunks,bytes)});
  });
  return child;
}
