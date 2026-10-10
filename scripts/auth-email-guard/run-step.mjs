import {subprocessDiagnostic} from './subprocess-diagnostic.mjs';
// Names are reviewed labels, never argv, HTTP paths, user IDs or error text.
export function runStep({name,timeoutMs,run}){
 if(!/^(hang|cleanup|startup|late-probe|subprocess\.(spawn|spawnSync|execFileSync)\.(node|deno|docker|git|whoami|icacls|openssl|pnpm|npm|unclassified)(\.[a-z_.-]+)?)$/.test(name))throw new Error('Unreviewed step name');
 const startedAt=new Date().toISOString(),began=performance.now();
 const finish=result=>({name,startedAt,elapsedMs:performance.now()-began,timeoutMs,
  exitCode:result.status??null,signal:result.signal??null,
  stderrRedacted:subprocessDiagnostic(result),failed:result.status!==0});
 if(!run)return {finish};
 try{const value=run();return value&&typeof value.then==='function'?value.then(finish,error=>finish({error,status:null,stderr:error?.stderr})):finish(value);}
 catch(error){return finish({error,status:null,stderr:error?.stderr});}
}
