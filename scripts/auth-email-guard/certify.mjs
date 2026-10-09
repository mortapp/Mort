import {readFile,writeFile} from 'node:fs/promises';
import {spawnSync} from './subprocess-runner.mjs';
import {recordSubprocessFailure} from './subprocess-diagnostic.mjs';
import {resolve} from 'node:path';
import pg from 'pg';
import {startFixture,fixtureProcessEnv} from './fixture.mjs';
import {captureAssertions,serializeEvidence,digestState} from './evidence.mjs';
import {caseMappings,operationalMappings,runCase} from './cases.mjs';
import {loadRequirements} from './coverage.mjs';
import {auditFixtureLogs} from './log-audit.mjs';
import {sessionLiveCharacterization} from './local-characterizations.mjs';
import {captureFailureSnapshot} from './failure-snapshot.mjs';
import {computeCertification,loadExternalGates} from './certification-gates.mjs';
import {fixtureDirectory} from './control.mjs';
const root=resolve(import.meta.dirname,'../..');
const cleanText=text=>text.replace(/\x1b\[[0-9;]*m/g,'');
let certificationStage='initialization';
async function stateDigest(handle){
  const db=new pg.Client({connectionString:handle.dbUrl,connectionTimeoutMillis:2000});
  try{
    await db.connect();
    const state=(await db.query(`SELECT enabled,activation_generation,restore_generation,
      (SELECT count(*) FROM mort_auth_guard.families) families,
      (SELECT count(*) FROM mort_auth_guard.families WHERE state='active') active_families,
      (SELECT count(*) FROM mort_auth_guard.capabilities WHERE state IN('issued','reserved')) capabilities,
      (SELECT count(*) FROM mort_auth_guard.operation_grants WHERE state IN('reserved','pending')) grants,
      (SELECT count(*) FROM mort_auth_guard.outbox WHERE encrypted_envelope IS NOT NULL) encrypted_payloads,
      (SELECT count(*) FROM mort_auth_guard.quota_events) quota_events,
      (SELECT count(*) FROM mort_auth_guard.address_proofs WHERE retired_at IS NULL) proofs
      FROM mort_auth_guard.control`)).rows[0];return digestState(state);
  }finally{await db.end();}
}
function child(command,args,extra={}){
  const result=spawnSync(command,args,{cwd:root,env:{...fixtureProcessEnv(),...extra},windowsHide:true,encoding:'utf8',timeout:90_000,maxBuffer:8*1024*1024});
  recordSubprocessFailure(result);
  if(result.status!==0)throw new Error('Certification child assertion failed (output redacted)');
  return cleanText(result.stdout);
}
async function sourceOwner(name,files,kind){
  for(const file of files){
    const source=await readFile(resolve(root,file),'utf8');
    const pattern=kind==='deno'?/Deno\.test\("([^"\n]+)"/g:/test\(['"]([^'"\n]+)['"]/g;
    for(const match of source.matchAll(pattern))if(match[1]===name)return {file,line:source.slice(0,match.index).split('\n').length};
    if(file.endsWith('fixture.test.mjs')&&['rejectsObservedMismatch:','rejectsWrongTargetBeforeImport:'].some(prefix=>name.startsWith(prefix))){
      const stem=name.split(':')[0];return {file,line:source.slice(0,source.indexOf('test(`'+stem+':')).split('\n').length};
    }
  }
  throw new Error('Executed test lacks reviewed source owner');
}
export async function run(){
  certificationStage='requirements';
  const requirements=await loadRequirements(),head=child('git',['rev-parse','HEAD']).trim();
  const sourcePaths=['scripts/auth-email-guard','web/auth/challenge','supabase/functions/_shared/auth_email_guard','supabase/functions/mort-auth-email-hook','supabase/functions/mort-auth-email-guard','supabase/migrations/20261008130945_mort_email_fixture_control_retention.sql','supabase/migrations/20261008135853_mort_email_restore_session_epoch.sql','supabase/migrations/20261008151312_mort_email_fixture_baseline_snapshot.sql'];
  const sourceStatus=()=>child('git',['status','--porcelain','--',...sourcePaths]).trim();
  const sourceSnapshot=async()=>{
    const files=[...new Set(child('git',['ls-files','--cached','--others','--exclude-standard','--',...sourcePaths]).trim().split('\n').filter(Boolean))].sort();
    const hashes=[];for(const file of files)hashes.push([file,digestState((await readFile(resolve(root,file))).toString('utf8'))]);
    return digestState(hashes);
  };
  const startSourceStatus=sourceStatus();
  const guardSourceSha256=await sourceSnapshot();
  let guardSourceClean=!startSourceStatus;
  if(!/^[a-f0-9]{40}$/.test(head))throw new Error('Candidate identity unavailable');
  certificationStage='fixture-start';
  const fixture=await startFixture(),observations=[],started=performance.now();
  const suiteNames=['provider-ingress','provider-recovery','session-live','transport-cleanup','guarded-jwt-transports','provider-drift','logging','state','issuance','grant','bypass','hook-boundary','delivery','smtp-fault','cutover','retention','load','security','log-audit'];
  const timings={},suiteStates={};
  for(const name of suiteNames){
    certificationStage=name+':state-before';
    const since=new Date().toISOString(),began=performance.now(),before=await stateDigest(fixture);
    const suite=await import(`./${name}.test.mjs`);
    certificationStage=name+':assertions';
    try{observations.push(...await captureAssertions(name,()=>suite.run(fixture)));}
    catch(error){
      try{console.error('FAILURE certified suite snapshot: '+JSON.stringify(captureFailureSnapshot(fixture)));}
      catch{console.error('FAILURE certified suite snapshot unavailable; primary failure retained');}
      throw error;
    }
    // Logging intentionally characterizes unsafe raw default output. Its named
    // assertions are observations, never a raw-telemetry privacy certification.
    certificationStage=name+':log-audit';
    if(name!=='logging')auditFixtureLogs(fixture,since);timings[name]=Math.round(performance.now()-began);
    certificationStage=name+':state-after';
    suiteStates[name]={before,after:await stateDigest(fixture)};
    console.log('PASS certified isolated suite:',name);
  }
  const denoFiles=['supabase/functions/mort-auth-email-hook/handler_test.ts','supabase/functions/mort-auth-email-guard/handler_test.ts','supabase/functions/_shared/secure_codes_test.ts',...['admission','config','crypto','outbox','parser','provider','redaction'].map(s=>`supabase/functions/_shared/auth_email_guard/${s}_test.ts`)];
  denoFiles.push('supabase/functions/_shared/auth_email_guard/store-initialization-diagnostic_test.ts');
  const unitOutput=child('deno',['test','--frozen','--allow-env=ETHEREAL_API,ETHEREAL_WEB,ETHEREAL_API_KEY,ETHEREAL_CACHE','--config','supabase/functions/auth-email-guard.deno.json',...denoFiles]);
  for(const match of unitOutput.matchAll(/^(.+?) \.\.\. ok(?: |$)/gm)){
    const name=match[1];observations.push({key:`unit:${name}`,suite:'unit',...await sourceOwner(name,denoFiles,'deno'),assertion:'named_test',executions:1,status:'PASS'});
  }
  const nodeFiles=['scripts/auth-email-guard/fixture.test.mjs','scripts/auth-email-guard/control.test.mjs','scripts/auth-email-guard/coverage.test.mjs','scripts/auth-email-guard/evidence.test.mjs','scripts/auth-email-guard/transport-observation.test.mjs','scripts/auth-email-guard/local-characterizations.test.mjs','scripts/auth-email-guard/transport-role-tokens.test.mjs','scripts/auth-email-guard/strict-expiry.test.mjs'];
  nodeFiles.push('scripts/auth-email-guard/subprocess-diagnostic.test.mjs','scripts/auth-email-guard/session-latency.test.mjs');
  nodeFiles.push('scripts/auth-email-guard/parallel-probe.test.mjs');
  nodeFiles.push('scripts/auth-email-guard/subprocess-runner.test.mjs');
  nodeFiles.push('scripts/auth-email-guard/idle-wait.test.mjs');
  nodeFiles.push('scripts/auth-email-guard/lifecycle-deadline.test.mjs');
  nodeFiles.push('scripts/auth-email-guard/failure-snapshot.test.mjs');
  nodeFiles.push('scripts/auth-email-guard/certification-gates.test.mjs');
  const browserFiles=['web/auth/challenge/controller.test.mjs','web/auth/challenge/transport.test.mjs','web/auth/challenge/build.test.mjs','web/auth/challenge/browser.test.mjs'];
  const nodeOutput=child('node',['--test','--test-reporter=tap',...nodeFiles,...browserFiles],{MORT_GUARD_BROWSER_MODULES:process.env.MORT_GUARD_BROWSER_MODULES??'C:\\Users\\micha\\.cache\\codex-runtimes\\codex-primary-runtime\\dependencies\\node\\node_modules'});
  for(const match of nodeOutput.matchAll(/^ok \d+ - (.+)$/gm)){
    const name=match[1],owner=await sourceOwner(name,[...nodeFiles,...browserFiles],'node'),suite=owner.file.startsWith('web/')?'browser':'unit';
    observations.push({key:`${suite}:${name}`,suite,...owner,assertion:'named_test',executions:1,status:'PASS'});
  }
  const db=new pg.Client({connectionString:fixture.dbUrl});let state;
  try{
    await db.connect();
    state=(await db.query(`SELECT enabled,activation_generation,restore_generation,
      (SELECT count(*)::int FROM mort_auth_guard.families WHERE state='active' AND family_expires_at>clock_timestamp()) active_families,
      (SELECT count(*)::int FROM mort_auth_guard.operation_grants WHERE state IN('reserved','pending')) temporary_permissions,
      (SELECT count(*)::int FROM mort_auth_guard.outbox WHERE encrypted_envelope IS NOT NULL) encrypted_payloads,
      (SELECT count(*)::int FROM mort_transport.records) transport_records,
      (SELECT count(*)::int FROM storage.objects WHERE bucket_id='mort-fixture') transport_objects FROM mort_auth_guard.control`)).rows[0];
    if(state.enabled||state.active_families||state.temporary_permissions||state.encrypted_payloads||state.transport_records||state.transport_objects||fixture.trackedAccounts.size)throw new Error('Fixture cleanup proof failed');
  }finally{await db.end();}
  const context={head,fixtureId:fixture.fixtureId,callerRole:'synthetic_fixture',requestShape:'synthetic-redacted-operation',concurrency:20,elapsedMs:Math.round(performance.now()-started),expected:'named assertions pass',observed:'executed',counterChanges:'asserted by named tests',stateDigest:digestState(state),logClean:true,cleanup:true};
  const cases=caseMappings.map(row=>{
    const evidence=runCase(row.id,observations,context);
    if(evidence.status!=='PASS')evidence.observed='not executed';
    return JSON.parse(serializeEvidence(evidence));
  });
  const summary=Object.fromEntries(['PASS','NOT_RUN','BLOCKED','OWNER_SCOPED_OUT'].map(status=>[status,cases.filter(c=>c.status===status).length]));
  const operationalCases=operationalMappings.map(row=>{
    const evidence=runCase(row.id,observations,context);if(evidence.status!=='PASS')evidence.observed='not executed';return JSON.parse(serializeEvidence(evidence));
  });
  const operationalSummary=Object.fromEntries(['PASS','NOT_RUN','BLOCKED'].map(status=>[status,operationalCases.filter(c=>c.status===status).length]));
  if(child('git',['rev-parse','HEAD']).trim()!==head||sourceStatus()!==startSourceStatus||await sourceSnapshot()!==guardSourceSha256)throw new Error('Candidate changed during certification');
  guardSourceClean=guardSourceClean&&!sourceStatus();
  const externalRegistry=JSON.parse(await readFile(new URL('./external-gates.json',import.meta.url),'utf8'));
  const registry={schema:1,gates:[...caseMappings,...operationalMappings].map(row=>({id:row.id,scopeOutApproved:['MD2-162','MD2-163','MD2-164','MD2-165','MD2-166'].includes(row.id)})).concat(externalRegistry.gates)};
  const externalEvidence=await loadExternalGates(externalRegistry.gates,resolve(fixtureDirectory,'external-gates'),{head,sourceSha256:guardSourceSha256});
  const gateFile={schema:1,head,sourceSha256:guardSourceSha256,sourceClean:guardSourceClean,gates:[...cases,...operationalCases].map(row=>({id:row.id,status:row.status,head,sourceSha256:guardSourceSha256,executions:row.assertions.reduce((total,proof)=>total+proof.executions,0),assertionKeys:row.assertions.map(proof=>proof.key),cleanup:row.cleanup,logClean:row.logClean})).concat(externalEvidence)};
  const evidencePath=resolve(fixtureDirectory,'certification-gates-evidence.json');
  const gateEvidenceSha256=digestState(gateFile);
  await writeFile(evidencePath,JSON.stringify(gateFile),{mode:0o600});
  const persistedGateFile=JSON.parse(await readFile(evidencePath,'utf8'));
  if(digestState(persistedGateFile)!==gateEvidenceSha256)throw new Error('Persisted gate evidence changed');
  const certification=computeCertification(registry,persistedGateFile,{head,sourceSha256:guardSourceSha256});
  if(child('git',['rev-parse','HEAD']).trim()!==head||sourceStatus()!==startSourceStatus||await sourceSnapshot()!==guardSourceSha256)throw new Error('Candidate changed during gate evidence persistence');
  const report=Object.freeze({schema:1,head,guardSourceClean,guardSourceSha256,gateEvidenceSha256,gates:certification.gates,fixtureId:fixture.fixtureId,sourceSha256:requirements.sourceSha256,currentRequirements:191,retainedHistoricalRecords:328,totalHistoricalAndCurrentRecords:519,fullGuardCertified:certification.fullGuardCertified,activationProfile:'private_provider_rehearsal',summary,operationalSummary,operationalCases,timings,suiteStates,executedAssertions:observations.length,cases,historical:requirements.records.filter(r=>!r.id.startsWith('MD2-')).map(r=>({id:r.id,status:'RETAINED_HISTORY_NOT_INHERITED',source:r.source})),hostedChanged:false});
  // Deduplicate exact assertion provenance in output; the validated case records
  // reference it by key. Never persist raw provider/SQL/request values.
  const compactCase=row=>({id:row.id,status:row.status,...(row.reason?{reason:row.reason}:{}),assertionKeys:row.assertions.map(proof=>proof.key)});
  const output={...report,context,assertions:observations,cases:cases.map(compactCase),operationalCases:operationalCases.map(compactCase),localCharacterizations:{oldJwt:{requirements:['MD2-070','MD2-145'],status:'RED_FINDING',observations:fixture.transportEvidence},logging:{requirement:'MD-119',status:'RED_FINDING',hostedTelemetryCertified:false,observations:fixture.loggingEvidence}},rawDefaultTelemetryCertified:false,logCleanScope:'Only audited non-logging-suite paths; raw default telemetry is explicitly not certified.',cleanupState:state};
  output.localCharacterizations.sessionLive=sessionLiveCharacterization(fixture.sessionLiveEvidence);
  output.localCharacterizations.sessionLatency=fixture.sessionLatencyEvidence;
  delete output.localCharacterizations.oldJwt.observations;
  output.localCharacterizations.oldJwt.status='HISTORICAL_RED_FINDING_UNPROTECTED_BASELINE';
  output.localCharacterizations.oldJwt.historicalHead='082e8431b1aa4b788b6edb4c9c3245f007f1660c';
  output.localCharacterizations.guardedJwt=fixture.guardedExpiryEvidence;
  console.log('MORT_GUARD_EVIDENCE_JSON '+JSON.stringify(output));return report;
}
if(process.argv[1]&&resolve(process.argv[1])===resolve(import.meta.filename)){
  try{const result=await run();if(result.summary.NOT_RUN||result.operationalSummary.NOT_RUN)process.exitCode=1;else if(!result.fullGuardCertified&&!process.argv.includes('--allow-external-gates'))process.exitCode=2;}
  catch(error){const name=['Error','AssertionError','TypeError','TimeoutError','AbortError'].includes(error.name)?error.name:'unclassified';const code=/^[A-Z0-9_]{1,24}$/.test(error.code??'')?error.code:'unclassified';console.error('FAIL certification: '+(error.guardAssertion?JSON.stringify(error.guardAssertion):`stage=${certificationStage} name=${name} code=${code}; values redacted`));process.exitCode=1;}
}
