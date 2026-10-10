import {spawn as nodeSpawn,spawnSync as nodeSpawnSync,execFileSync as nodeExecFileSync} from 'node:child_process';
import {performance} from 'node:perf_hooks';
import {recordSubprocessFailure,subprocessDiagnostic} from './subprocess-diagnostic.mjs';
import {runStep} from './run-step.mjs';

const captureLimit=4*1024*1024;
const executables=new Set(['node','deno','docker','git','whoami','icacls','openssl','pnpm','npm']);
const dockerOperations=new Set(['inspect','logs','exec','start','stop','compose','info','version','ps','images','pull']);
const dockerResourceOperations=new Set(['inspect','create','rm','ls']);
const ownedResource=/^mort-mobile-auth-guard-qa-(db|auth|capture|network|data|storage|rest|realtime|guard|issuer|drift-db|drift-auth|drift-data)-[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const commandKinds=new Set(['psql','pg_isready','sh','node']);
function dockerTargetIndex(args,start,kind){
  const flags=kind==='exec'?new Set(['-i','-t','-it','-ti','--interactive','--tty','-d','--detach','--privileged']):new Set(['-s','--size']);
  const options=kind==='exec'?new Set(['-e','--env','--env-file','-u','--user','-w','--workdir','--detach-keys']):new Set(['-f','--format','--type']);
  for(let index=start;index<args.length;index++){
    const arg=args[index];
    if(typeof arg!=='string')return null;
    if(arg==='--')return index+1<args.length?index+1:null;
    if(flags.has(arg))continue;
    if(options.has(arg)){if(typeof args[++index]!=='string')return null;continue;}
    if([...options].some(option=>option.startsWith('--')&&arg.startsWith(option+'=')))continue;
    if(arg.startsWith('-'))return null;
    return index;
  }
  return null;
}
export function subprocessCommandMetadata(file,args){
  const basename=typeof file==='string'?file.split(/[\\/]/).at(-1).toLowerCase().replace(/\.(exe|cmd|bat)$/,''):'';
  const executable=executables.has(basename)?basename:'unclassified';
  let dockerOperation=null,fixtureRole=null,commandKind=null;
  if(executable==='docker'){
    const operation=Array.isArray(args)?args[0]:undefined;
    dockerOperation=dockerOperations.has(operation)?operation:'unclassified';
    if((operation==='volume'||operation==='network')&&dockerResourceOperations.has(args[1]))dockerOperation=operation+'.'+args[1];
    if(operation==='exec'){
      const target=dockerTargetIndex(args,1,'exec');
      if(target!==null){
        fixtureRole=typeof args[target]==='string'?ownedResource.exec(args[target])?.[1]??null:null;
        commandKind=commandKinds.has(args[target+1])?args[target+1]:'unclassified';
      }else commandKind='unclassified';
    }else if(dockerOperation==='inspect'||dockerOperation==='volume.inspect'||dockerOperation==='network.inspect'){
      const target=dockerTargetIndex(args,dockerOperation==='inspect'?1:2,'inspect');
      if(target!==null&&target===args.length-1)fixtureRole=typeof args[target]==='string'?ownedResource.exec(args[target])?.[1]??null:null;
    }
  }
  return {executable,dockerOperation,fixtureRole,commandKind};
}
function begin(api,file,args,options){
  const metadata={api,...subprocessCommandMetadata(file,args),startedAt:new Date().toISOString(),
    timeoutMs:Number.isFinite(options?.timeout)&&options.timeout>=0?options.timeout:null};
  const began=performance.now();
  console.error('Fixture subprocess started: '+JSON.stringify(metadata));
  const name=['subprocess',api,metadata.executable,metadata.dockerOperation,metadata.fixtureRole,metadata.commandKind].filter(Boolean).join('.');
  return {metadata,began,step:runStep({name,timeoutMs:metadata.timeoutMs})};
}
function complete(context,result,{stderrAvailable=result.stderr!=null,truncated=false}={}){
  const stderr=Buffer.isBuffer(result.stderr)?result.stderr:typeof result.stderr==='string'?Buffer.from(result.stderr):Buffer.alloc(0);
  const bounded={status:result.status,signal:result.signal,error:result.error,stderr:stderr.subarray(0,captureLimit)};
  truncated=truncated||stderr.length>captureLimit;
  console.error('Fixture subprocess completed: '+JSON.stringify({...context.metadata,
    ...context.step.finish(bounded),stderrAvailable,stderrTruncated:truncated,diagnostic:subprocessDiagnostic(bounded)}));
  if(result.status!==0){
    if(truncated)console.error('Fixture subprocess stderr capture truncated at 4194304 bytes; fingerprint covers captured prefix only');
    recordSubprocessFailure(bounded);
  }
  return result;
}

export function spawnSync(...args){
  const context=begin('spawnSync',args[0],args[1],Array.isArray(args[1])?args[2]:args[1]);
  try{return complete(context,nodeSpawnSync(...args));}
  catch(error){complete(context,{status:error.status??null,signal:error.signal,error,stderr:error.stderr});throw error;}
}

export function execFileSync(file,args,options){
  if(!Array.isArray(args)){options=args;args=[];}
  const settings={...options};
  // Explicit pipe prevents Node's implicit forwarding of exception stderr.
  // Preserve stdin/stdout modes and return type while capturing stderr silently.
  const modes=Array.isArray(settings.stdio)?[...settings.stdio]:Array(3).fill(settings.stdio??'pipe');
  modes[2]='pipe';settings.stdio=modes;
  const context=begin('execFileSync',file,args,settings);
  try{
    const output=nodeExecFileSync(file,args,settings);
    // The native success API returns stdout only, so no stderr bytes are known.
    complete(context,{status:0,signal:null,stderr:null},{stderrAvailable:false});return output;
  }catch(error){complete(context,{status:error.status??null,signal:error.signal,error,stderr:error.stderr});throw error;}
}

export function spawn(...args){
  const context=begin('spawn',args[0],args[1],Array.isArray(args[1])?args[2]:args[1]);
  let child;
  try{child=nodeSpawn(...args);}
  catch(error){complete(context,{status:null,signal:null,error,stderr:null});throw error;}
  let error,bytes=0,truncated=false;const chunks=[];
  child.stderr?.on('data',value=>{
    const chunk=Buffer.isBuffer(value)?value:Buffer.from(value);
    const remaining=captureLimit-bytes;
    if(chunk.length>remaining)truncated=true;
    if(remaining>0){const captured=chunk.subarray(0,remaining);chunks.push(captured);bytes+=captured.length;}
  });
  child.on('error',value=>{error=value;});
  child.once('close',(status,signal)=>{
    complete(context,{status,signal,error,stderr:Buffer.concat(chunks,bytes)},{stderrAvailable:child.stderr!=null,truncated});
  });
  return child;
}
