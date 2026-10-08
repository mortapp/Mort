import {spawnSync} from 'node:child_process';
import {assertMortAuthFixture,fixtureProcessEnv} from './fixture.mjs';
export function auditFixtureLogs(handle,since){
  assertMortAuthFixture(handle,handle.observed);
  const secrets=[handle.password,handle.jwtSecret,handle.serviceKey,handle.anonKey,...(handle.privateAudit??[])];
  let clean=true;
  for(const role of ['auth','db','capture']){
    const result=spawnSync('docker',['logs','--since',since,`mort-mobile-auth-guard-qa-${role}-${handle.fixtureId}`],{env:fixtureProcessEnv(),encoding:'utf8',windowsHide:true,timeout:10000,maxBuffer:8*1024*1024});
    if(result.status!==0)throw new Error('Fixture log audit unavailable');
    const text=result.stdout+result.stderr;
    if(secrets.some(secret=>secret.length>=8&&text.includes(secret))){clean=false;console.error('Private runtime data detected in owned log:',role);}
  }
  if(!clean)throw new Error('Fixture log audit found private runtime data (values redacted)');
  return true;
}
