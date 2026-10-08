import assert from 'node:assert/strict';
import {randomBytes,randomUUID} from 'node:crypto';
import {fixtureSql} from './fixture.mjs';
import {readFile} from 'node:fs/promises';
import pg from 'pg';
import {startOidcFixture} from './oidc-fixture.mjs';

async function call(handle,path,body,admin=false,method='POST') {
  const response=await fetch(`${handle.authUrl}${path}`,{
    method,headers:{'content-type':'application/json',authorization:`Bearer ${admin?handle.serviceKey:handle.anonKey}`},
    ...(body?{body:JSON.stringify(body)}:{}),signal:AbortSignal.timeout(10_000),redirect:'manual',
  });
  let data={};try{data=await response.json();}catch{}
  return {status:response.status,data};
}
async function pending(handle) {
  const email=`qa-${randomUUID()}@mort-fixture.invalid`;
  const password=`Aa9!${randomBytes(20).toString('base64url')}`;
  const result=await call(handle,'/admin/users',{email,password,email_confirm:false},true);
  assert.ok(result.status===200&&result.data.id,'Fixture pending account creation must succeed');
  handle.trackedAccounts.add(result.data.id);
  (handle.trackedEmails??=new Set()).add(email);
  return {id:result.data.id,email,password};
}
async function signupLink(handle,user) {
  const result=await call(handle,'/admin/generate_link',{type:'signup',email:user.email,password:user.password},true);
  assert.ok(result.status===200&&result.data.action_link,'Fixture link generation must succeed');
  return result.data.action_link;
}
async function confirmed(handle,id) {
  return (await fixtureSql(handle,`SELECT email_confirmed_at IS NOT NULL FROM auth.users WHERE id='${id}';`)).trim()==='t';
}
async function signIn(handle,user,password) {
  return await call(handle,'/token?grant_type=password',{email:user.email,password});
}
async function cleanup(handle){
  // A provider denial can still create an unconfirmed OAuth identity/account.
  // Resolve only mailbox addresses generated and owned by this specific run.
  for(const email of handle.trackedEmails??[]){
    if(!/^qa-[0-9a-f-]+@mort-fixture\.invalid$/.test(email))throw new Error('Fixture cleanup mailbox rejected');
    const ids=await fixtureSql(handle,`SELECT u.id FROM auth.users u WHERE u.email='${email}' OR EXISTS(SELECT 1 FROM auth.identities i WHERE i.user_id=u.id AND i.identity_data->>'email'='${email}');`);
    for(const id of ids.split('\n').map(x=>x.trim()).filter(Boolean)){
      if(!/^[0-9a-f-]{36}$/.test(id))throw new Error('Fixture cleanup identity rejected');handle.trackedAccounts.add(id);
    }
  }
  for(const id of handle.trackedAccounts){
    const result=await call(handle,`/admin/users/${id}`,null,true,'DELETE');
    assert.ok(result.status===200,'Synthetic provider account cleanup must succeed');
    handle.trackedAccounts.delete(id);
  }
  handle.trackedEmails?.clear();
}
export async function run(handle) {
  const guarded=process.env.MORT_GUARD_PROBE==='1';
  if(guarded)await fixtureSql(handle,await readFile(new URL('./provider-probe.sql',import.meta.url),'utf8'));
  async function track(user){
    if(guarded)await fixtureSql(handle,`INSERT INTO mort_provider_probe.generations(account_id) VALUES('${user.id}');`);
  }
  async function authorize(user,purpose='confirmation',seconds=300){
    const operationId=randomUUID();
    await fixtureSql(handle,`INSERT INTO mort_provider_probe.grants(id,account_id,generation,purpose,expires_at) SELECT '${operationId}','${user.id}',generation,'${purpose}',clock_timestamp()+interval '${seconds} seconds' FROM mort_provider_probe.generations WHERE account_id='${user.id}';`);
    const marker=await call(handle,`/admin/users/${user.id}`,{app_metadata:{mort_email_operation_id:operationId}},true,'PUT');
    assert.ok(marker.status===200,'Private granted marker preparation must succeed');
    return operationId;
  }
  const tests=[
    ['P1 direct confirmation denied at provider write',async()=>{
      const user=await pending(handle);
      await track(user);
      assert.ok(!await confirmed(handle,user.id),'Pending positive control starts unconfirmed');
      const link=await signupLink(handle,user);
      await fetch(link,{redirect:'manual',signal:AbortSignal.timeout(10_000)});
      assert.ok(!await confirmed(handle,user.id),'Direct provider verification must not confirm without MORT proof');
    }],
    ['P2 supported Admin replacement and confirmation positive',async()=>{
      const user=await pending(handle);
      await track(user);
      const next=`Bb8!${randomBytes(20).toString('base64url')}`;
      const operation=guarded?await authorize(user):null;
      const updated=await call(handle,`/admin/users/${user.id}`,{password:next,email_confirm:true},true,'PUT');
      assert.ok(updated.status===200&&await confirmed(handle,user.id),'Supported Admin update must atomically confirm and replace');
      assert.ok((await signIn(handle,user,user.password)).status!==200,'Original preconfirmation password must not sign in');
      assert.ok((await signIn(handle,user,next)).status===200,'Replacement password must sign in');
      if(guarded)assert.ok((await fixtureSql(handle,`SELECT state='committed' AND confirmed_applied AND password_applied FROM mort_provider_probe.grants WHERE id='${operation}';`)).trim()==='t','One operation commits both mutations and private proof');
    }],
    ...(guarded?[
      ['P3 dispatched-before-expiry write denied after lock',async()=>{
        const user=await pending(handle);
        await call(handle,`/admin/users/${user.id}`,{email_confirm:true},true,'PUT');
        await track(user);
        const operation=await authorize(user,'recovery');
        const locker=new pg.Client({connectionString:handle.dbUrl,connectionTimeoutMillis:2000});
        const inspector=new pg.Client({connectionString:handle.dbUrl,connectionTimeoutMillis:2000});
        try{
          await locker.connect();await inspector.connect();await locker.query('BEGIN');
          await locker.query('SELECT id FROM auth.users WHERE id=$1 FOR UPDATE',[user.id]);
          const candidate=`Cc7!${randomBytes(20).toString('base64url')}`;
          const delayed=call(handle,`/admin/users/${user.id}`,{password:candidate},true,'PUT');
          let waiting=false;
          for(let i=0;i<50;i++){
            const result=await inspector.query("SELECT EXISTS(SELECT 1 FROM pg_stat_activity WHERE usename='supabase_auth_admin' AND wait_event_type='Lock') AS waiting");
            if(result.rows[0].waiting){waiting=true;break;}
            await new Promise(r=>setTimeout(r,50));
          }
          assert.ok(waiting,'Real provider write must be waiting on the account row lock');
          await inspector.query("UPDATE mort_provider_probe.grants SET expires_at=clock_timestamp()-interval '1 second' WHERE id=$1",[operation]);
          await locker.query('COMMIT');
          assert.ok((await delayed).status!==200,'Mutation dispatched live but written expired must be denied');
          assert.ok((await signIn(handle,user,user.password)).status===200,'Expired write preserves original legitimate password');
          const nextOperation=await authorize(user,'recovery');
          const next=`Dd6!${randomBytes(20).toString('base64url')}`;
          assert.ok((await call(handle,`/admin/users/${user.id}`,{password:next},true,'PUT')).status===200,'Later legitimate owner operation must succeed');
          assert.ok((await signIn(handle,user,next)).status===200,'Later replacement signs in');
          assert.ok((await call(handle,`/admin/users/${user.id}`,{app_metadata:{mort_email_operation_id:operation},password:candidate},true,'PUT')).status!==200,'Old request cannot reintroduce expired marker after new commit');
          assert.ok((await signIn(handle,user,next)).status===200,'Stale marker attempt preserves newer password');
          assert.ok(nextOperation!==operation,'Later operation identity differs');
        }finally{
          await locker.query('ROLLBACK').catch(()=>{});await locker.end();await inspector.end();
        }
      }],
      ['P5 reset clears tokens and refresh session positive',async()=>{
        const user=await pending(handle);
        await call(handle,`/admin/users/${user.id}`,{email_confirm:true},true,'PUT');
        const before=await signIn(handle,user,user.password);
        assert.ok(before.status===200&&before.data.refresh_token,'Real pre-reset session must exist');
        const oldRefresh=before.data.refresh_token;
        await track(user);await authorize(user,'recovery');
        const next=`Ee5!${randomBytes(20).toString('base64url')}`;
        assert.ok((await call(handle,`/admin/users/${user.id}`,{password:next},true,'PUT')).status===200,'Granted recovery reset succeeds');
        const stale=await call(handle,'/token?grant_type=refresh_token',{refresh_token:oldRefresh});
        assert.ok(stale.status!==200,'Old refresh session must be revoked');
        const tokens=await fixtureSql(handle,`SELECT coalesce(recovery_token,'')='' AND coalesce(confirmation_token,'')='' FROM auth.users WHERE id='${user.id}';`);
        assert.ok(tokens.trim()==='t','Outstanding provider credential tokens must be cleared');
        assert.ok((await signIn(handle,user,next)).status===200,'New password remains usable after token cleanup');
      }],
    ]:[]),
    ['P4 real verified OIDC clears unconfirmed password identity',async()=>{
      const user=await pending(handle);
      const issuer=await startOidcFixture(handle);
      try{
        // Custom-provider configuration rejects private issuers under SSRF.
        // The built-in Keycloak adapter explicitly supports an operator-owned
        // local issuer and still performs real signature/audience verification.
        // This fixture adapter is never configured in hosted MORT.
        const badAudience=await call(handle,'/token?grant_type=id_token',{provider:'keycloak',id_token:issuer.token(user.email,true,'fixture-other-client')});
        assert.ok(badAudience.status!==200&&!await confirmed(handle,user.id),'Wrong audience cannot confirm the pending account');
        const parts=issuer.token(user.email,true).split('.');parts[2]=(parts[2][0]==='A'?'B':'A')+parts[2].slice(1);
        const badSignature=await call(handle,'/token?grant_type=id_token',{provider:'keycloak',id_token:parts.join('.')});
        assert.ok(badSignature.status!==200&&!await confirmed(handle,user.id),'Invalid signature cannot confirm the pending account');
        const verified=await call(handle,'/token?grant_type=id_token',{provider:'keycloak',id_token:issuer.token(user.email,true)});
        if(verified.data.user?.id && verified.data.user.id!==user.id)handle.trackedAccounts.add(verified.data.user.id);
        const diagnostic=/^[a-z_]+$/.test(verified.data.error_code??'')?verified.data.error_code:'unspecified';
        assert.ok(verified.status===200,`Real signature-verified matching OIDC identity must sign in (HTTP ${verified.status}, ${diagnostic})`);
        assert.ok(verified.data.user?.id===user.id,'Verified OAuth must link the existing pending account');
        const cleared=await fixtureSql(handle,`SELECT coalesce(encrypted_password,'')='' FROM auth.users WHERE id='${user.id}';`);
        assert.ok(cleared.trim()==='t','Pinned provider must discard unconfirmed attacker-chosen password on verified OAuth linking');
        assert.ok((await signIn(handle,user,user.password)).status!==200,'Preconfirmation password gains no OAuth password authority');
        // The denial case uses a separate owned pending mailbox. A stock
        // unverified OAuth denial may persist a second pending identity, so it
        // cannot contaminate the positive linking/cleanup control above.
        const negative=await pending(handle);
        const unverified=await call(handle,'/token?grant_type=id_token',{provider:'keycloak',id_token:issuer.token(negative.email,false)});
        if(unverified.data.user?.id && unverified.data.user.id!==negative.id)handle.trackedAccounts.add(unverified.data.user.id);
        assert.ok(unverified.status!==200||unverified.data.user?.id!==negative.id,'Provider-unverified email cannot take over pending password account');
        assert.ok(!await confirmed(handle,negative.id),'Unverified OAuth leaves original pending account unconfirmed');
        assert.ok((await signIn(handle,negative,negative.password)).status!==200,'Unverified OAuth cannot legitimize original pending password');
      }finally{
        await issuer.close();
      }
    }],
  ];
  let failed=0;
  try{
    for(const [name,test] of tests){
      try{await test();console.log(`PASS ${name}`);}catch(error){
        failed++;console.log(`FAIL ${name}: ${error.name==='AssertionError'?error.message:'setup or transport failure'} (no values)`);
      }
    }
  }finally{
    if(guarded)await fixtureSql(handle,'DROP TRIGGER IF EXISTS mort_provider_probe_mutation ON auth.users; DROP SCHEMA IF EXISTS mort_provider_probe CASCADE;');
    await cleanup(handle);
  }
  if(failed)throw new Error('Fixture provider checkpoint assertions failed');
}
export {call,pending,signupLink,confirmed,signIn,cleanup};
