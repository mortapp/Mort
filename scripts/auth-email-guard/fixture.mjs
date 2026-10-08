import {execFileSync, spawnSync} from 'node:child_process';
import {createHmac, randomBytes, randomUUID} from 'node:crypto';
import {mkdir, readFile, writeFile} from 'node:fs/promises';
import {createServer} from 'node:net';
import {dirname, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

const root=resolve(dirname(fileURLToPath(import.meta.url)),'../..');
const stateDir=resolve(root,'.superpowers/sdd/2026-10-08-managed-email-challenge-guard/fixture');
const statePath=resolve(stateDir,'fixture.json');
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
export const IMAGES=Object.freeze({
  db:'public.ecr.aws/supabase/postgres@sha256:6501843661b1f8ff97e85c02de33edc0ee2e2693888ad596ee86222f02dc8ecc',
  auth:'public.ecr.aws/supabase/gotrue@sha256:1736a63078f5922b198c4cbe50f80ab9a2d3b54fe8b7b6cfb2e9dc5dbbc12c6b',
  capture:'public.ecr.aws/supabase/mailpit@sha256:37a38e48e9338cd7e89dfeb487f37b02ebfcd9cb23111bed2d345e79d37d6dd6',
  rest:'public.ecr.aws/supabase/postgrest@sha256:d2009b5c9deffc210c8a5592698472fede14fd9f6ca89823c8474ca54d58c012',
  storage:'public.ecr.aws/supabase/storage-api@sha256:4ae1890ba0c6fd24d975c34f3aa201a01d410171c8ba6eddeb675ef92341a62d',
  realtime:'public.ecr.aws/supabase/realtime@sha256:3211f8ebd59edcd0aa772186f1c8249c82c6b1ae5565f40dedb7aa93e951fe37',
  'drift-db':'public.ecr.aws/supabase/postgres@sha256:6501843661b1f8ff97e85c02de33edc0ee2e2693888ad596ee86222f02dc8ecc',
  'drift-auth':'public.ecr.aws/supabase/gotrue@sha256:362659ca70eaa75ba05bbaf963caa84c1c5afe5e8fbf0777e17b830dd5f0f60a',
});
const target=Object.freeze({
  project:'mort-mobile',mode:'local_fixture',authUrl:'http://127.0.0.1:55421',
  dbHost:'127.0.0.1',dbPort:55422,captureUrl:'http://127.0.0.1:55424',
  smtpHost:'127.0.0.1',smtpPort:55425,guardUrl:'http://127.0.0.1:55426',credentialOrigin:'generated_fixture',
});
function assertConfig(config) {
  if (!config || !uuid.test(config.fixtureId) || Object.entries(target).some(([k,v])=>config[k]!==v)) throw new Error('Fixture target rejected');
}
export function assertMortAuthFixture(config,observed) {
  assertConfig(config);
  if (!observed || Object.entries(target).some(([k,v])=>observed[k]!==v)
    || observed.fixtureId!==config.fixtureId || observed.dbFixtureId!==config.fixtureId
    || !observed.imageVerified || !observed.volumeVerified || !observed.confirmationRequired
    || observed.phoneEnabled!==false || observed.anonymousEnabled!==false
    || observed.emailExpiry!==600 || observed.jwtExpiry!==3600 || observed.providerVersion!=='v2.197.0'
    || !Array.isArray(observed.resourceIds) || observed.resourceIds.length!==3
    || ['db','auth','capture'].some(role=>observed.resourceIds.filter(name=>name===container(config,role)).length!==1)) throw new Error('Fixture target rejected');
}
export function assertOwnedResource(name,labels,fixtureId) {
  if (!uuid.test(fixtureId) || !new RegExp(`^mort-mobile-auth-guard-qa-(db|auth|capture|network|data|storage|rest|realtime|guard|issuer|drift-db|drift-auth|drift-data)-${fixtureId}$`).test(name)
    || labels?.['com.docker.compose.project']!=='mort-mobile'
    || labels?.['mort.guard.fixture']!==fixtureId) throw new Error('Fixture resource rejected');
}
function docker(args,input) {
  const result=spawnSync('docker',args,{input,encoding:'utf8',timeout:60_000,maxBuffer:4*1024*1024,windowsHide:true});
  if (result.status!==0) throw new Error(`Fixture Docker operation failed: ${args[0]}`);
  return result.stdout.trim();
}
export function fixtureProcessEnv(){
  return Object.fromEntries(Object.entries(process.env).filter(([name])=>/^(PATH|SystemRoot|WINDIR|TEMP|TMP|APPDATA|LOCALAPPDATA|USERPROFILE|HOME|ProgramFiles|ProgramFiles\(x86\)|ComSpec|PATHEXT)$/i.test(name)));
}
function composeEnv(state) {
  const environment=fixtureProcessEnv();
  return {...environment,FIXTURE_ID:state.fixtureId,FIXTURE_DIR:stateDir.replaceAll('\\','/'),FIXTURE_DB_PASSWORD:state.password,FIXTURE_JWT_SECRET:state.jwtSecret,FIXTURE_ANON_KEY:signJwt(state.jwtSecret,'anon'),FIXTURE_SERVICE_KEY:signJwt(state.jwtSecret,'service_role'),FIXTURE_REALTIME_KEY:state.password.slice(0,16),FIXTURE_SECRET_BASE:state.password};
}
function container(state,role){return `mort-mobile-auth-guard-qa-${role}-${state.fixtureId}`;}
function inspect(state,role) {
  const name=container(state,role);
  // Never inspect/export the environment: it contains private fixture credentials.
  const details=JSON.parse(docker(['inspect','--format','{{json .Config.Labels}}',name]));
  assertOwnedResource(name,details,state.fixtureId);
  const image=docker(['inspect','--format','{{.Image}}',name]);
  if (image!==IMAGES[role].split('@')[1]) throw new Error('Fixture image rejected');
  const expectedPorts={db:{'5432/tcp':'55422'},auth:{'9999/tcp':'55421'},capture:{'8025/tcp':'55424','1025/tcp':'55425'},rest:{'3000/tcp':'55431'},storage:{'5000/tcp':'55432'},realtime:{'4000/tcp':'55433'},'drift-db':{'5432/tcp':'55442'},'drift-auth':{'9999/tcp':'55441'}}[role];
  const bindings=JSON.parse(docker(['inspect','--format','{{json .HostConfig.PortBindings}}',name]));
  if(Object.keys(bindings).length!==Object.keys(expectedPorts).length||Object.entries(expectedPorts).some(([port,published])=>bindings[port]?.length!==1||bindings[port][0].HostIp!=='127.0.0.1'||bindings[port][0].HostPort!==published))throw new Error('Fixture published ports rejected');
  const network=JSON.parse(docker(['inspect','--format','{{json .NetworkSettings.Networks}}',name]));
  if(Object.keys(network).length!==1||!network[container(state,'network')])throw new Error('Fixture network rejected');
  if(role==='storage'||role==='drift-db'){
    const volume=container(state,role==='storage'?'storage':'drift-data');
    assertOwnedResource(volume,JSON.parse(docker(['volume','inspect','--format','{{json .Labels}}',volume])),state.fixtureId);
    const mounts=JSON.parse(docker(['inspect','--format','{{json .Mounts}}',name]));
    if(mounts.length!==1||mounts[0].Name!==volume||mounts[0].Destination!==(role==='storage'?'/var/lib/storage':'/var/lib/postgresql/data'))throw new Error('Fixture transport mount rejected');
  }
  return name;
}
function preflightExisting(state){
  for(const role of ['db','auth','capture']){
    const result=spawnSync('docker',['inspect','--format','{{.Name}}',container(state,role)],{encoding:'utf8',windowsHide:true});
    if(result.status===0)inspect(state,role);
    else if(!result.stderr?.includes('No such object')&&!result.stderr?.includes('No such container'))throw new Error('Fixture resource preflight failed');
  }
  for(const [kind,role] of [['volume','data'],['network','network']]){
    const name=container(state,role), result=spawnSync('docker',[kind,'inspect','--format','{{json .Labels}}',name],{encoding:'utf8',windowsHide:true});
    if(result.status===0)assertOwnedResource(name,JSON.parse(result.stdout),state.fixtureId);
    else if(!result.stderr?.includes('not found')&&!result.stderr?.includes('No such'))throw new Error('Fixture resource preflight failed');
  }
}
async function portFree(port){
  await new Promise((resolvePort,reject)=>{
    const server=createServer();server.once('error',()=>reject(new Error(`Fixture port collision: ${port}`)));
    server.listen(port,'127.0.0.1',()=>server.close(resolvePort));
  });
}
function restrictFixtureDirectory(){
  if(process.platform!=='win32')return;
  const owner=execFileSync('whoami',[],{encoding:'utf8',windowsHide:true}).trim();
  if(!/^[A-Za-z0-9_. -]+\\[A-Za-z0-9_. -]+$/.test(owner))throw new Error('Fixture private owner rejected');
  // POSIX mode bits do not restrict Windows ACLs. Apply explicit file rights
  // separately from inheritable directory rights; never modify the repo ACL.
  const base=[stateDir,'/inheritance:r','/T','/Q'];
  execFileSync('icacls',base,{stdio:'ignore',windowsHide:true});
  execFileSync('icacls',[stateDir,'/grant:r',`${owner}:F`,'*S-1-5-18:F','*S-1-5-32-544:F','/T','/Q'],{stdio:'ignore',windowsHide:true});
  execFileSync('icacls',[stateDir,'/grant:r',`${owner}:(OI)(CI)F`,'*S-1-5-18:(OI)(CI)F','*S-1-5-32-544:(OI)(CI)F','/Q'],{stdio:'ignore',windowsHide:true});
}
async function loadState() {
  const state=JSON.parse(await readFile(statePath,'utf8'));assertConfig(state);
  if (!/^[a-f0-9]{64}$/.test(state.password) || !/^[a-f0-9]{64}$/.test(state.jwtSecret)) throw new Error('Fixture credential rejected');
  return state;
}
function signJwt(secret,role) {
  const head=Buffer.from(JSON.stringify({alg:'HS256',typ:'JWT'})).toString('base64url');
  const body=Buffer.from(JSON.stringify({role,iss:'fixture',aud:'authenticated',iat:Math.floor(Date.now()/1000),exp:Math.floor(Date.now()/1000)+3600})).toString('base64url');
  return `${head}.${body}.${createHmac('sha256',secret).update(`${head}.${body}`).digest('base64url')}`;
}
export function refreshFixtureApiCredentials(handle){
  assertMortAuthFixture(handle,handle.observed);
  if(typeof handle.jwtSecret!=='string'||handle.jwtSecret.length<32)throw new Error('Fixture signing configuration rejected');
  // Renew only synthetic API role credentials, with the original 3600s TTL.
  // Never replace, re-sign or extend a provider-issued account access token.
  const audit=handle.privateAudit??=new Set();
  for(const field of ['anonKey','serviceKey'])if(handle[field])audit.add(handle[field]);
  handle.anonKey=signJwt(handle.jwtSecret,'anon');
  handle.serviceKey=signJwt(handle.jwtSecret,'service_role');
  audit.add(handle.anonKey);audit.add(handle.serviceKey);
}
// Temporary, allowlisted profiles for this UUID-owned disposable provider only.
// Overrides are private ignored files; no normal/hosted configuration changes.
export async function configureFixtureAuth(handle,{sendEmail=false,logLevel='fatal'}={}){
  assertMortAuthFixture(handle,handle.observed);inspect(handle,'auth');
  if(!['fatal','info'].includes(logLevel)||typeof sendEmail!=='boolean')throw new Error('Fixture profile rejected');
  const state=await loadState();
  const path=resolve(stateDir,'auth-profile.yaml');
  await writeFile(path,`services:\n  auth:\n    environment:\n      GOTRUE_LOG_LEVEL: ${logLevel}\n      GOTRUE_HOOK_SEND_EMAIL_ENABLED: '${sendEmail}'\n      GOTRUE_HOOK_SEND_EMAIL_URI: pg-functions://postgres/mort_fixture/send_email\n`,{mode:0o600});
  const result=spawnSync('docker',['compose','--env-file',resolve(stateDir,'empty.env'),'-p','mort-mobile','-f',resolve(root,'scripts/auth-email-guard/compose.yaml'),'-f',path,'up','-d','--no-deps','auth'],{env:composeEnv(state),encoding:'utf8',timeout:60_000,windowsHide:true});
  if(result.status!==0)throw new Error('Fixture profile startup failed');inspect(state,'auth');
  for(let i=0;i<100;i++){
    try{if((await fetch(`${handle.authUrl}/health`,{signal:AbortSignal.timeout(1000)})).ok)return;}catch{}
    await new Promise(r=>setTimeout(r,100));
  }
  throw new Error('Fixture profile health failed');
}
export async function startFixtureTransports(handle){
  assertMortAuthFixture(handle,handle.observed);
  const state=await loadState();
  for(const role of ['rest','storage','realtime']){
    const existing=spawnSync('docker',['inspect',container(state,role)],{encoding:'utf8',windowsHide:true});
    if(existing.status===0)inspect(state,role);
    else await portFree({rest:55431,storage:55432,realtime:55433}[role]);
  }
  await fixtureSql(handle,`ALTER ROLE authenticator PASSWORD '${state.password}';ALTER ROLE supabase_storage_admin PASSWORD '${state.password}';CREATE SCHEMA IF NOT EXISTS _realtime;ALTER SCHEMA _realtime OWNER TO supabase_admin;CREATE SCHEMA IF NOT EXISTS mort_transport;`);
  const started=spawnSync('docker',['compose','--env-file',resolve(stateDir,'empty.env'),'-p','mort-mobile','-f',resolve(root,'scripts/auth-email-guard/compose.yaml'),'up','-d','--no-deps','rest','storage','realtime'],{env:composeEnv(state),encoding:'utf8',timeout:60_000,windowsHide:true});
  if(started.status!==0)throw new Error('Fixture transport startup failed');
  for(const role of ['rest','storage','realtime'])inspect(state,role);
  for(const url of ['http://127.0.0.1:55431/','http://127.0.0.1:55432/status','http://127.0.0.1:55433/healthcheck']){
    for(let i=0;i<100;i++){
      try{if((await fetch(url,{signal:AbortSignal.timeout(1000)})).ok)break;}catch{}
      if(i===99)throw new Error('Fixture transport health timeout');await new Promise(r=>setTimeout(r,100));
    }
  }
  return {restUrl:'http://127.0.0.1:55431',storageUrl:'http://127.0.0.1:55432',realtimeUrl:'ws://127.0.0.1:55433',resourceIds:['rest','storage','realtime'].map(role=>container(state,role))};
}
export async function startDriftFixture(handle){
  assertMortAuthFixture(handle,handle.observed);const state=await loadState();
  for(const role of ['drift-db','drift-auth']){
    const found=spawnSync('docker',['inspect',container(state,role)],{encoding:'utf8',windowsHide:true});
    if(found.status===0)inspect(state,role);else await portFree(role==='drift-db'?55442:55441);
  }
  const args=['compose','--env-file',resolve(stateDir,'empty.env'),'-p','mort-mobile','-f',resolve(root,'scripts/auth-email-guard/compose.yaml')];
  const up=roles=>{const result=spawnSync('docker',[...args,'up','-d','--no-deps',...roles],{env:composeEnv(state),encoding:'utf8',timeout:60_000,windowsHide:true});if(result.status!==0)throw new Error('Fixture drift startup failed');};
  up(['drift-db']);inspect(state,'drift-db');
  for(let i=0;i<100;i++){try{docker(['exec',container(state,'drift-db'),'pg_isready','-h','drift-db','-U','postgres']);break;}catch{}if(i===99)throw new Error('Fixture drift DB health failed');await new Promise(r=>setTimeout(r,100));}
  docker(['exec','-i',container(state,'drift-db'),'sh','-c','PGPASSWORD="$POSTGRES_PASSWORD" psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1'],`ALTER ROLE supabase_auth_admin PASSWORD '${state.password}';CREATE SCHEMA IF NOT EXISTS mort_fixture;CREATE TABLE IF NOT EXISTS mort_fixture.identity(id uuid primary key);INSERT INTO mort_fixture.identity VALUES('${state.fixtureId}') ON CONFLICT DO NOTHING;`);
  const identity=docker(['exec',container(state,'drift-db'),'sh','-c','PGPASSWORD="$POSTGRES_PASSWORD" psql -U supabase_admin -d postgres -At -c "SELECT id FROM mort_fixture.identity"']);
  if(identity!==state.fixtureId)throw new Error('Fixture drift database identity rejected');
  up(['drift-auth']);inspect(state,'drift-auth');
  for(let i=0;i<100;i++){try{if((await fetch('http://127.0.0.1:55441/health',{signal:AbortSignal.timeout(1000)})).ok)return;}catch{}if(i===99)throw new Error('Fixture drift provider health failed');await new Promise(r=>setTimeout(r,100));}
}
export async function stopDriftFixture(handle){
  assertMortAuthFixture(handle,handle.observed);for(const role of ['drift-auth','drift-db']){inspect(handle,role);docker(['stop','--time','2',container(handle,role)]);}
}
export async function startFixture(){
  let state;
  try {state=await loadState();} catch (error) {
    if (error.code!=='ENOENT') throw error;
    for (const port of [55421,55422,55424,55425,55426]) await portFree(port);
    state={...target,fixtureId:randomUUID(),password:randomBytes(32).toString('hex'),jwtSecret:randomBytes(32).toString('hex')};
    await mkdir(stateDir,{recursive:true,mode:0o700});restrictFixtureDirectory();await writeFile(statePath,JSON.stringify(state),{mode:0o600,flag:'wx'});
    const openssl=process.platform==='win32'?'C:\\Program Files\\Git\\usr\\bin\\openssl.exe':'openssl';
    execFileSync(openssl,['req','-x509','-newkey','rsa:2048','-nodes','-days','2','-keyout',resolve(stateDir,'smtp.key'),'-out',resolve(stateDir,'smtp.pem'),'-subj','/CN=capture','-addext','subjectAltName=DNS:capture,DNS:localhost,IP:127.0.0.1'],{stdio:'ignore',windowsHide:true});
  }
  assertConfig(state);
  restrictFixtureDirectory();
  preflightExisting(state);
  const emptyEnv=resolve(stateDir,'empty.env');await writeFile(emptyEnv,'# No repository environment is loaded.\n',{mode:0o600});
  const args=['compose','--env-file',emptyEnv,'-p','mort-mobile','-f',resolve(root,'scripts/auth-email-guard/compose.yaml')];
  // Explicit named services only. Never invoke project-wide down/prune/reset.
  const started=spawnSync('docker',[...args,'up','-d','db','capture'],{env:composeEnv(state),encoding:'utf8',timeout:60_000,windowsHide:true});
  if (started.status!==0) throw new Error('Fixture database/capture startup failed');
  const dbName=inspect(state,'db');inspect(state,'capture');
  for(let i=0;i<60;i++){
    try{docker(['exec',dbName,'pg_isready','-U','postgres','-d','postgres']);break;}
    catch{if(i===59)throw new Error('Fixture database health timeout');await new Promise(r=>setTimeout(r,250));}
  }
  const sql=`ALTER ROLE supabase_auth_admin PASSWORD '${state.password}';\nCREATE SCHEMA IF NOT EXISTS mort_fixture;\nREVOKE ALL ON SCHEMA mort_fixture FROM PUBLIC;\nCREATE TABLE IF NOT EXISTS mort_fixture.identity(id uuid PRIMARY KEY);\nINSERT INTO mort_fixture.identity VALUES ('${state.fixtureId}') ON CONFLICT DO NOTHING;\n`;
  docker(['exec','-i',dbName,'sh','-c','PGPASSWORD="$POSTGRES_PASSWORD" psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1'],sql);
  docker(['exec','-i',dbName,'sh','-c','PGPASSWORD="$POSTGRES_PASSWORD" psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1'],await readFile(resolve(root,'scripts/auth-email-guard/token-observer.sql'),'utf8'));
  // A restored database is never its own freshness authority. Refuse provider
  // startup if the private journal and DB disagree, even after runner restart.
  const hasControl=docker(['exec',dbName,'sh','-c','PGPASSWORD="$POSTGRES_PASSWORD" psql -U supabase_admin -d postgres -At -c "SELECT to_regclass(\'mort_auth_guard.control\') IS NOT NULL"']);
  if(hasControl==='t'){
    const generation=Number(docker(['exec',dbName,'sh','-c','PGPASSWORD="$POSTGRES_PASSWORD" psql -U supabase_admin -d postgres -At -c "SELECT restore_generation FROM mort_auth_guard.control"']));
    const {readJournal}=await import('./control.mjs');
    let safe=false;
    try{const external=await readJournal(stateDir,state.fixtureId);safe=(external===null&&generation===1&&state.guardJournalRequired!==true)||external===generation;}catch{}
    if(!safe){
      const present=spawnSync('docker',['inspect','--format','{{.Name}}',container(state,'auth')],{encoding:'utf8',windowsHide:true});
      if(present.status===0){inspect(state,'auth');docker(['stop','--time','5',container(state,'auth')]);}
      throw new Error('Fixture journal mismatch; provider remains stopped');
    }
  }
  const authStarted=spawnSync('docker',[...args,'up','-d','auth'],{env:composeEnv(state),encoding:'utf8',timeout:60_000,windowsHide:true});
  if(authStarted.status!==0)throw new Error('Fixture Auth startup failed');inspect(state,'auth');
  for(let i=0;i<100;i++){
    try{const health=await fetch(`${state.authUrl}/health`,{signal:AbortSignal.timeout(1000)});if(health.ok)break;}catch{}
    if(i===99)throw new Error('Fixture Auth health timeout');await new Promise(r=>setTimeout(r,250));
  }
  return await observeFixture(state);
}
export async function observeFixture(state) {
  state ??= await loadState();
  const resourceIds=['db','auth','capture'].map(role=>inspect(state,role));
  const volume=`mort-mobile-auth-guard-qa-data-${state.fixtureId}`;
  assertOwnedResource(volume,JSON.parse(docker(['volume','inspect','--format','{{json .Labels}}',volume])),state.fixtureId);
  const mounts=JSON.parse(docker(['inspect','--format','{{json .Mounts}}',container(state,'db')]));
  if (!mounts.some(x=>x.Name===volume&&x.Destination==='/var/lib/postgresql/data')) throw new Error('Fixture mount rejected');
  const identity=docker(['exec',container(state,'db'),'sh','-c','PGPASSWORD="$POSTGRES_PASSWORD" psql -U supabase_admin -d postgres -At -c "SELECT id FROM mort_fixture.identity"']);
  const health=await (await fetch(`${state.authUrl}/health`,{signal:AbortSignal.timeout(2000)})).json();
  const settings=await (await fetch(`${state.authUrl}/settings`,{signal:AbortSignal.timeout(2000)})).json();
  const observed={...state,dbFixtureId:identity,imageVerified:true,volumeVerified:true,resourceIds,
    confirmationRequired:settings.mailer_autoconfirm===false,phoneEnabled:settings.external?.phone===true,
    anonymousEnabled:settings.external?.anonymous_users===true,emailExpiry:600,jwtExpiry:3600,providerVersion:health.version};
  // Inspect only allowlisted non-secret settings, not the container's full environment.
  const values=docker(['exec',container(state,'auth'),'sh','-c','printf "%s %s %s %s" "$GOTRUE_MAILER_OTP_EXP" "$GOTRUE_JWT_EXP" "$GOTRUE_EXTERNAL_PHONE_ENABLED" "$GOTRUE_EXTERNAL_ANONYMOUS_USERS_ENABLED"']).split(' ');
  if(docker(['exec',container(state,'auth'),'sh','-c','printf "%s" "$GOTRUE_LOG_LEVEL"'])!=='fatal')throw new Error('Fixture provider logging privacy rejected');
  [observed.emailExpiry,observed.jwtExpiry]=values.slice(0,2).map(Number);
  observed.phoneEnabled=values[2]!=='false';observed.anonymousEnabled=values[3]!=='false';assertMortAuthFixture(state,observed);
  return {...state,observed,dbUrl:`postgresql://supabase_admin:${state.password}@127.0.0.1:55422/postgres`,serviceKey:signJwt(state.jwtSecret,'service_role'),anonKey:signJwt(state.jwtSecret,'anon'),smtpUrl:'smtp://127.0.0.1:55425',imageDigests:IMAGES,trackedAccounts:new Set()};
}
export async function fixtureSql(handle,sql){
  assertMortAuthFixture(handle,handle.observed);inspect(handle,'db');
  return docker(['exec','-i',container(handle,'db'),'sh','-c','PGPASSWORD="$POSTGRES_PASSWORD" psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1 -At'],sql);
}
export async function stopFixture(handle) {
  assertMortAuthFixture(handle,handle.observed);
  for(const role of ['auth','capture','db']){const name=inspect(handle,role);docker(['rm','-f',name]);}
  // Preserve the explicitly owned volume for resumption. No global Compose teardown.
}
