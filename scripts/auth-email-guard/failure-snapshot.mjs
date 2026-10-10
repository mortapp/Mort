import {spawnSync} from './subprocess-runner.mjs';
import {createHash} from 'node:crypto';
import {assertMortAuthFixture,assertOwnedResource,fixtureProcessEnv} from './fixture.mjs';
import {subprocessDiagnostic} from './subprocess-diagnostic.mjs';

const roles=['auth','db','realtime','storage','rest','guard'];
const statuses=new Set(['created','running','paused','restarting','removing','exited','dead']);
const bytes=value=>Buffer.isBuffer(value)?value:typeof value==='string'?Buffer.from(value):Buffer.alloc(0);
const errorDiagnostic=error=>subprocessDiagnostic({status:error?.status??null,signal:error?.signal,error,stderr:error?.stderr});

// This reads only already-owned local resources. Returned failures belong to
// the snapshot; callers keep and rethrow their original operation failure.
// Raw logs, inspect errors, environment, command arguments and credentials
// never appear in the result or console. Presence flags cover only known
// fixture credentials and an email pattern, not complete privacy certification.
export function createFailureSnapshotRunner({assertFixture=assertMortAuthFixture,spawn=spawnSync}={}){
  return function captureFailureSnapshot(handle){
    const result={roles:[],failures:[]};
    try{assertFixture(handle,handle?.observed);}
    catch{result.failures.push({operation:'identity',category:'identity_rejected'});return result;}
    const knownCredentials=[handle.password,handle.jwtSecret,handle.anonKey,handle.serviceKey,...(handle.privateAudit instanceof Set||Array.isArray(handle.privateAudit)?handle.privateAudit:[])].filter(value=>typeof value==='string'&&value.length>=8);
    const read=(role,operation,args)=>{
      try{
        const child=spawn('docker',args,{env:fixtureProcessEnv(),encoding:'utf8',timeout:5000,maxBuffer:1024*1024,windowsHide:true});
        if(child.status!==0){result.failures.push({role,operation,diagnostic:subprocessDiagnostic(child)});return null;}
        return child;
      }catch(error){result.failures.push({role,operation,diagnostic:errorDiagnostic(error)});return null;}
    };
    for(const role of roles){
      const name=`mort-mobile-auth-guard-qa-${role}-${handle.fixtureId}`;
      const row={role,status:null,logs:null};result.roles.push(row);
      const inspected=read(role,'ownership',['inspect','--format','{{json .Config.Labels}}',name]);
      if(!inspected)continue;
      try{assertOwnedResource(name,JSON.parse(bytes(inspected.stdout).toString('utf8')),handle.fixtureId);}
      catch{result.failures.push({role,operation:'ownership',category:'ownership_rejected'});continue;}
      const state=read(role,'status',['inspect','--format','{{json .State}}',name]);
      if(state){
        try{
          const value=JSON.parse(bytes(state.stdout).toString('utf8'));
          if(!value||!['Running','Paused','Restarting','Dead','OOMKilled'].every(key=>typeof value[key]==='boolean')||!Number.isSafeInteger(value.ExitCode))throw new Error();
          row.status={status:statuses.has(value.Status)?value.Status:'unclassified',running:value.Running,paused:value.Paused,restarting:value.Restarting,dead:value.Dead,oomKilled:value.OOMKilled,exitCode:value.ExitCode};
        }catch{result.failures.push({role,operation:'status',category:'invalid_status'});}
      }
      const captured=read(role,'logs',['logs','--since','2m','--tail','200',name]);
      if(captured){
        const log=Buffer.concat([bytes(captured.stdout),bytes(captured.stderr)]),text=log.toString('utf8');
        row.logs={bytes:log.length,sha256:createHash('sha256').update(log).digest('hex'),classifications:subprocessDiagnostic({status:0,stderr:log}).stderrCategories,
          privacyPresence:{trackedCredential:knownCredentials.some(value=>text.includes(value)),emailLike:/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i.test(text)}};
      }
    }
    return result;
  };
}

export const captureFailureSnapshot=createFailureSnapshotRunner();
