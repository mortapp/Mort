import {startFixture,assertMortAuthFixture,fixtureProcessEnv} from './fixture.mjs';
import {spawnSync} from 'node:child_process';
import {resolve} from 'node:path';
const [flag,suite]=process.argv.slice(2);
const allowed=new Set(['health','dependency','provider','bypass','hook-boundary','smtp-fault','state','issuance','delivery','grant','security','cutover','retention','load','log-audit','provider-ingress','provider-recovery','session-live','guarded-jwt-transports','transport-cleanup','jwt-transports','provider-drift','logging']);
if(flag!=='--suite'||!allowed.has(suite))throw new Error('Use --suite with an explicit fixture suite');
try {
  const handle=await startFixture();assertMortAuthFixture(handle,handle.observed);
  if(suite==='health')console.log('PASS isolated MORT fixture: confirmation required, GoTrue v2.197.0, owned DB/capture');
  else if(suite==='dependency'){
    const certificate=resolve(import.meta.dirname,'../../.superpowers/sdd/2026-10-08-managed-email-challenge-guard/fixture/smtp.pem');
    const probe=spawnSync('deno',['run','--frozen','--config','supabase/functions/auth-email-guard.deno.json','--allow-env',`--allow-read=${certificate}`,'--allow-net=127.0.0.1:55425','supabase/functions/_shared/auth_email_guard/dependency_probe.ts'],{env:{...fixtureProcessEnv(),MORT_FIXTURE_VERIFIED:'1',MORT_FIXTURE_CERT:certificate},encoding:'utf8',timeout:30_000,windowsHide:true});
    if(probe.status!==0)throw new Error('Fixture dependency protocol compatibility failed (redacted)');
    console.log('PASS Deno pinned Webhooks/pg imports and certificate-verified STARTTLS SMTP');
  }
  else {const {run}=await import(`./${suite}.test.mjs`);await run(handle);}
}catch(error){
  console.error(`FAIL ${suite}: ${/^(Fixture|Use --suite)/.test(error.message)?error.message:'fixture assertion or setup failed (redacted)'}`);
  process.exitCode=1;
}
