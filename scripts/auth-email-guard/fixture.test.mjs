import assert from 'node:assert/strict';
import {randomBytes,randomUUID,createHmac} from 'node:crypto';
import test from 'node:test';
import {assertMortAuthFixture, assertOwnedResource,fixtureProcessEnv} from './fixture.mjs';

function fixture() {
  const id = randomUUID();
  const config = {
    fixtureId:id, project:'mort-mobile', mode:'local_fixture',
    authUrl:'http://127.0.0.1:55421', dbHost:'127.0.0.1', dbPort:55422,
    captureUrl:'http://127.0.0.1:55424', smtpHost:'127.0.0.1', smtpPort:55425,
    guardUrl:'http://127.0.0.1:55426', credentialOrigin:'generated_fixture',
  };
  const observed = {
    ...config, dbFixtureId:id, imageVerified:true, volumeVerified:true,
    confirmationRequired:true, phoneEnabled:false, anonymousEnabled:false,
    emailExpiry:600, jwtExpiry:3600, providerVersion:'v2.197.0',
    resourceIds:['db','auth','capture'].map(role=>`mort-mobile-auth-guard-qa-${role}-${id}`),
  };
  return {config,observed};
}

test('acceptsExactSyntheticFixture', () => {
  const {config,observed} = fixture();
  assert.doesNotThrow(()=>assertMortAuthFixture(config,observed));
});

test('fixture role credentials renew with unchanged lifetime and preserve provider tokens',async()=>{
  const {config,observed}=fixture();
  const handle={...config,observed,jwtSecret:randomBytes(48).toString('hex'),anonKey:'expired-fixture-role',serviceKey:'expired-fixture-role',providerToken:'opaque-provider-token'};
  const refresh=(await import('./fixture.mjs')).refreshFixtureApiCredentials;
  assert.equal(typeof refresh,'function');
  refresh(handle);
  for(const [field,role] of [['anonKey','anon'],['serviceKey','service_role']]){
    const [header,body,signature]=handle[field].split('.');
    const claims=JSON.parse(Buffer.from(body,'base64url'));
    assert.equal(claims.role,role);assert.equal(claims.exp-claims.iat,3600);
    assert.ok(claims.exp>Math.floor(Date.now()/1000));
    assert.equal(signature,createHmac('sha256',handle.jwtSecret).update(`${header}.${body}`).digest('base64url'));
  }
  assert.equal(handle.providerToken,'opaque-provider-token');
  assert.throws(()=>refresh({...handle,mode:'production'}),/Fixture target rejected/);
});

for (const patch of [
  {authUrl:'https://rakjydmgwwgtdislanbt.supabase.co'},
  {authUrl:'http://127.0.0.1:54321'},
  {authUrl:'http://127.0.0.1.evil.invalid:55421'},
  {authUrl:'http://localhost:55421'},
  {dbPort:55322}, {project:'loop'}, {credentialOrigin:'repository_env'},
  {smtpHost:'smtp.ionos.com'}, {smtpPort:465},
]) {
  test(`rejectsWrongTargetBeforeImport: ${Object.keys(patch)[0]} ${Object.values(patch)[0]}`,()=>{
    const {config,observed}=fixture();
    assert.throws(()=>assertMortAuthFixture({...config,...patch},observed),/Fixture target rejected/);
  });
}

for (const patch of [
  {confirmationRequired:false},{phoneEnabled:true},{anonymousEnabled:true},
  {dbFixtureId:randomUUID()},{imageVerified:false},{volumeVerified:false},
  {providerVersion:'v2.191.0'},{resourceIds:['supabase_db_loop']},
]) {
  test(`rejectsObservedMismatch: ${Object.keys(patch)[0]}`,()=>{
    const {config,observed}=fixture();
    assert.throws(()=>assertMortAuthFixture(config,{...observed,...patch}),/Fixture target rejected/);
  });
}

test('cleanupNeverTouchesOtherResources',()=>{
  const {config}=fixture();
  const own=`mort-mobile-auth-guard-qa-db-${config.fixtureId}`;
  const labels={'com.docker.compose.project':'mort-mobile','mort.guard.fixture':config.fixtureId};
  assert.doesNotThrow(()=>assertOwnedResource(own,labels,config.fixtureId));
  for (const name of ['supabase_db_loop','supabase_db_mort-mobile',`mort-mobile-auth-guard-qa-db-${randomUUID()}`]) {
    assert.throws(()=>assertOwnedResource(name,labels,config.fixtureId),/Fixture resource rejected/);
  }
  assert.throws(()=>assertOwnedResource(own,{...labels,'mort.guard.fixture':randomUUID()},config.fixtureId),/Fixture resource rejected/);
});

test('duplicate or invented resource roles cannot satisfy observed identity',()=>{
  const {config,observed}=fixture();
  for(const resourceIds of [[observed.resourceIds[0],observed.resourceIds[0],observed.resourceIds[2]],[...observed.resourceIds,'extra'],observed.resourceIds.map(name=>name.replace('-db-','-invented-'))]){
    assert.throws(()=>assertMortAuthFixture(config,{...observed,resourceIds}),/Fixture target rejected/);
  }
});
test('process environment allowlist excludes credentials and remote Docker targets',()=>{
  const names=['SUPABASE_SERVICE_ROLE_KEY','GOTRUE_JWT_SECRET','DOCKER_HOST','SMTP_PASSWORD'];
  const old=new Map(names.map(name=>[name,process.env[name]]));
  try{for(const name of names)process.env[name]='synthetic-not-an-actual-secret';const allowed=fixtureProcessEnv();assert.ok(names.every(name=>!(name in allowed)));}
  finally{for(const [name,value] of old){if(value===undefined)delete process.env[name];else process.env[name]=value;}}
});
