import {readFile,writeFile,rename,unlink,open} from 'node:fs/promises';
import {resolve,dirname} from 'node:path';
import {randomUUID,createHash} from 'node:crypto';
import {spawnSync as nodeSpawnSync} from 'node:child_process';
import {recordSubprocessFailure} from './subprocess-diagnostic.mjs';
import pg from 'pg';
import {assertMortAuthFixture,assertOwnedResource,fixtureProcessEnv} from './fixture.mjs';
const spawnSync=(...args)=>recordSubprocessFailure(nodeSpawnSync(...args));
export const fixtureDirectory=resolve(import.meta.dirname,'../../.superpowers/sdd/2026-10-08-managed-email-challenge-guard/fixture');
export function assertActivationReadiness(checks){
  const required=['sendEmailHook','tokenHook','mutationGuard','browser','delivery','trustedIngress','keyConfiguration','providerCompatibility'];
  if(!checks||Object.keys(checks).length!==required.length||required.some(key=>checks[key]!==true))throw new Error('Full guard activation requires every verified runtime component');
}
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
export async function readJournal(directory,id){
  if(!uuid.test(id))throw new Error('Fixture journal identity rejected');
  let raw;try{raw=await readFile(resolve(directory,'generation.json'),'utf8');}catch(error){if(error.code==='ENOENT')return null;throw error;}
  const value=JSON.parse(raw);
  if(value.fixtureId!==id||!Number.isSafeInteger(value.generation)||value.generation<2)throw new Error('Fixture journal state rejected');
  return value.generation;
}
export async function advanceJournal(directory,id,databaseGeneration){
  if(!Number.isSafeInteger(databaseGeneration)||databaseGeneration<1)throw new Error('Fixture database generation rejected');
  const lockPath=resolve(directory,'generation.lock'),lock=await open(lockPath,'wx',0o600);
  try{
    const previous=await readJournal(directory,id);
    if(resolve(directory)===fixtureDirectory){
      const statePath=resolve(directory,'fixture.json'),state=JSON.parse(await readFile(statePath,'utf8'));
      if(state.fixtureId!==id||(previous===null&&state.guardJournalRequired===true))throw new Error('Fixture initialized journal missing');
      if(state.guardJournalRequired!==true){
        const temporaryState=resolve(directory,`fixture-state-${randomUUID()}.tmp`),file=await open(temporaryState,'wx',0o600);
        try{await file.writeFile(JSON.stringify({...state,guardJournalRequired:true}));await file.sync();}finally{await file.close();}
        await rename(temporaryState,statePath);
      }
    }
    if(previous===null&&databaseGeneration!==1)throw new Error('Fixture journal missing for initialized authority');
    if(previous!==null&&databaseGeneration>previous)throw new Error('Fixture database ahead of external journal');
    const next=Math.max(previous??1,databaseGeneration)+1;
    if(!Number.isSafeInteger(next))throw new Error('Fixture journal generation exhausted');
    const temporary=resolve(directory,`generation-${randomUUID()}.tmp`);
    const file=await open(temporary,'wx',0o600);
    try{await file.writeFile(JSON.stringify({fixtureId:id,generation:next}));await file.sync();}finally{await file.close();}
    await rename(temporary,resolve(directory,'generation.json'));return next;
  }finally{await lock.close();await unlink(lockPath);}
}
function docker(handle,args,input,binary=false){
  assertMortAuthFixture(handle,handle.observed);
  const name=`mort-mobile-auth-guard-qa-${args[0]==='exec'?'db':'auth'}-${handle.fixtureId}`;
  const inspected=spawnSync('docker',['inspect','--format','{{json .Config.Labels}}',name],{env:fixtureProcessEnv(),encoding:'utf8',windowsHide:true});
  if(inspected.status!==0)throw new Error('Fixture resource unavailable');
  assertOwnedResource(name,JSON.parse(inspected.stdout),handle.fixtureId);
  const result=spawnSync('docker',[args[0],...(args[0]==='exec'?['-i']:[]),name,...args.slice(1)],{input,env:fixtureProcessEnv(),...(binary?{}:{encoding:'utf8'}),timeout:60_000,maxBuffer:32*1024*1024,windowsHide:true});
  if(result.status!==0){
    throw new Error('Fixture control operation failed (output redacted)');
  }return result.stdout;
}
async function connection(handle){assertMortAuthFixture(handle,handle.observed);const db=new pg.Client({connectionString:handle.dbUrl,connectionTimeoutMillis:2000});await db.connect();return db;}
export async function planControl(action,handle){
  if(!['activate','rollback','restore'].includes(action))throw new Error('Fixture action rejected');
  const db=await connection(handle);
  try{
    const row=(await db.query('SELECT enabled,activation_generation,restore_generation FROM mort_auth_guard.control')).rows[0];
    return Object.freeze({action,fixtureId:handle.fixtureId,dryRun:true,databaseGeneration:Number(row.restore_generation),enabled:row.enabled,scope:'private_provider_rehearsal',fullGuardActivationReady:false});
  }finally{await db.end();}
}
function explicit(plan,handle,options){
  assertMortAuthFixture(handle,handle.observed);
  if(options?.localFixture!==true||options?.apply!==true)throw new Error('Fixture control requires explicit localFixture/apply');
  if(plan.fixtureId!==handle.fixtureId||!['activate','rollback','restore'].includes(plan.action))throw new Error('Fixture control plan rejected');
}
async function exclusive(operation){
  const path=resolve(fixtureDirectory,'operation.lock'),lock=await open(path,'wx',0o600);
  try{return await operation();}finally{await lock.close();await unlink(path);}
}
async function transition(plan,handle){
  const db=await connection(handle);
  try{
    const current=Number((await db.query('SELECT restore_generation FROM mort_auth_guard.control')).rows[0].restore_generation);
    const next=await advanceJournal(fixtureDirectory,handle.fixtureId,current);
    await db.query('BEGIN');await db.query("SET LOCAL lock_timeout='3s';SET LOCAL statement_timeout='10s'");
    await db.query('SELECT mort_auth_guard.fixture_transition($1,$2::uuid,$3::bigint)',[plan.action,handle.fixtureId,next]);
    await db.query('COMMIT');return next;
  }catch{await db.query('ROLLBACK').catch(()=>{});await db.query('UPDATE mort_auth_guard.control SET enabled=false').catch(()=>{});throw new Error('Fixture transition failed closed (redacted)');}
  finally{await db.end();}
}
async function resume(handle){
  docker(handle,['start']);
  for(let i=0;i<80;i++){try{if((await fetch(`${handle.authUrl}/health`,{signal:AbortSignal.timeout(1000)})).ok)return;}catch{}await new Promise(r=>setTimeout(r,100));}
  throw new Error('Fixture provider resume health failed');
}
export async function applyLocalControl(plan,handle,options){
  explicit(plan,handle,options);
  if(plan.action!=='rollback'&&options.privateProviderRehearsal!==true)throw new Error('Full guard activation unavailable; explicit private provider rehearsal required');
  return exclusive(async()=>{docker(handle,['stop','--time','5']);const generation=await transition(plan,handle);await resume(handle);return generation;});
}
export async function backupFixture(handle){
  return exclusive(async()=>{
    const path=resolve(fixtureDirectory,`backup-${randomUUID()}.dump`);
    // Transport policies reference auth.uid()/auth.jwt(). Include their owned
    // fixture schemas so restore's dependency order does not drop Auth functions
    // underneath live out-of-snapshot RLS policies. Missing schemas are harmless.
    const data=docker(handle,['exec','sh','-c','PGPASSWORD="$POSTGRES_PASSWORD" pg_dump -U supabase_admin -d postgres -Fc --schema=auth --schema=mort_auth_guard --schema=mort_fixture --schema=mort_transport --schema=storage --schema=realtime'],undefined,true);
    if(data.length<5||data.subarray(0,5).toString()!=='PGDMP')throw new Error('Fixture backup integrity rejected');
    await writeFile(path,data,{mode:0o600,flag:'wx'});
    await writeFile(path+'.sha256',JSON.stringify({fixtureId:handle.fixtureId,sha256:createHash('sha256').update(data).digest('hex')}),{mode:0o600,flag:'wx'});return path;
  });
}
export async function restoreFixture(handle,path,options){
  const plan={action:'restore',fixtureId:handle.fixtureId};explicit(plan,handle,options);
  if(options.privateProviderRehearsal!==true)throw new Error('Full guard activation unavailable; explicit private provider rehearsal required');
  if(dirname(resolve(path))!==fixtureDirectory||!/^backup-[0-9a-f-]+\.dump$/.test(resolve(path).split(/[\\/]/).at(-1)))throw new Error('Fixture restore path rejected');
  return exclusive(async()=>{
    const data=await readFile(path);
    if(data.subarray(0,5).toString()!=='PGDMP')throw new Error('Fixture backup format rejected');
    const integrity=JSON.parse(await readFile(path+'.sha256','utf8'));
    if(integrity.fixtureId!==handle.fixtureId||integrity.sha256!==createHash('sha256').update(data).digest('hex'))throw new Error('Fixture backup integrity rejected');
    // Provider ingress stays stopped on every failure. Never boot a restored old
    // generation before the independent journal and authority retirement commit.
    docker(handle,['stop','--time','5']);
    // pg_restore --clean tries to drop inherited constraints individually on
    // Realtime's partitioned tables. Replace the explicitly owned snapshot
    // schemas together, then load the verified dump within one transaction.
    // ON_ERROR_STOP rolls the entire replacement back on any statement failure.
    const sql=docker(handle,['exec','pg_restore','--file=-'],data,true);
    const transaction=Buffer.concat([Buffer.from('BEGIN;\nDROP SCHEMA IF EXISTS auth,mort_auth_guard,mort_fixture,mort_transport,storage,realtime CASCADE;\n'),sql,Buffer.from('\nCOMMIT;\n')]);
    docker(handle,['exec','sh','-c','PGPASSWORD="$POSTGRES_PASSWORD" psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1'],transaction,true);
    const db=await connection(handle);
    try{if((await db.query('SELECT id FROM mort_fixture.identity')).rows.length!==1||(await db.query('SELECT id FROM mort_fixture.identity')).rows[0].id!==handle.fixtureId)throw new Error('Fixture restored identity rejected');}finally{await db.end();}
    const generation=await transition(plan,handle);await resume(handle);return generation;
  });
}
export async function discardBackup(handle,path){
  assertMortAuthFixture(handle,handle.observed);
  if(dirname(resolve(path))!==fixtureDirectory||!/^backup-[0-9a-f-]+\.dump$/.test(resolve(path).split(/[\\/]/).at(-1)))throw new Error('Fixture backup cleanup rejected');
  await unlink(path);await unlink(path+'.sha256');
}
