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
  if (!uuid.test(fixtureId) || !new RegExp(`^mort-mobile-auth-guard-qa-(db|auth|capture|network|data|storage|rest|realtime|guard|issuer)-${fixtureId}$`).test(name)
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
  return {...environment,FIXTURE_ID:state.fixtureId,FIXTURE_DIR:stateDir.replaceAll('\\','/'),FIXTURE_DB_PASSWORD:state.password,FIXTURE_JWT_SECRET:state.jwtSecret};
}
function container(state,role){return `mort-mobile-auth-guard-qa-${role}-${state.fixtureId}`;}
function inspect(state,role) {
  const name=container(state,role);
  // Never inspect/export the environment: it contains private fixture credentials.
  const details=JSON.parse(docker(['inspect','--format','{{json .Config.Labels}}',name]));
  assertOwnedResource(name,details,state.fixtureId);
  const image=docker(['inspect','--format','{{.Image}}',name]);
  if (image!==IMAGES[role].split('@')[1]) throw new Error('Fixture image rejected');
  const expectedPorts={db:{'5432/tcp':'55422'},auth:{'9999/tcp':'55421'},capture:{'8025/tcp':'55424','1025/tcp':'55425'}}[role];
  const bindings=JSON.parse(docker(['inspect','--format','{{json .HostConfig.PortBindings}}',name]));
  if(Object.keys(bindings).length!==Object.keys(expectedPorts).length||Object.entries(expectedPorts).some(([port,published])=>bindings[port]?.length!==1||bindings[port][0].HostIp!=='127.0.0.1'||bindings[port][0].HostPort!==published))throw new Error('Fixture published ports rejected');
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
