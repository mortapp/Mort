import assert from 'node:assert/strict';
import {createHash,randomBytes,randomUUID} from 'node:crypto';
import pg from 'pg';
import {pending,call,cleanup,confirmed,signIn} from './provider.test.mjs';
export async function run(handle){
  const db=new pg.Client({connectionString:handle.dbUrl}),accounts=[];
  const digest=v=>createHash('sha256').update(v).digest('hex');
  async function seed(purpose){
    await db.query('UPDATE mort_auth_guard.control SET enabled=false');
    const u=await pending(handle);accounts.push(u.id);
    if(purpose==='recovery')assert.equal((await call(handle,`/admin/users/${u.id}`,{email_confirm:true},true,'PUT')).status,200);
    await db.query('INSERT INTO mort_auth_guard.account_generations(account_id,recipient_hash) VALUES($1,$2)',[u.id,digest(u.email)]);
    if(purpose==='recovery')await db.query(`INSERT INTO mort_auth_guard.address_proofs(account_id,address_generation,recipient_hash,activation_generation,restore_generation,source,proved_at) SELECT $1,1,$2,activation_generation,restore_generation,'confirmed_baseline',clock_timestamp() FROM mort_auth_guard.control`,[u.id,digest(u.email)]);
    await db.query('UPDATE mort_auth_guard.control SET enabled=true');return u;
  }
  try{
    await db.connect();
    for(const purpose of ['signup','recovery'])for(const form of ['get','hash','code']){
      const user=await seed(purpose);
      const generated=await call(handle,'/admin/generate_link',{type:purpose,email:user.email,...(purpose==='signup'?{password:user.password}:{})},true);
      assert.equal(generated.status,200,'Provider-only credential exists as a genuine negative control');
      let result;
      if(form==='get'){
        const response=await fetch(generated.data.action_link,{redirect:'manual',signal:AbortSignal.timeout(10000)});
        const location=response.headers.get('location')??'';
        result={status:response.status,data:{},location};
      }else result=await call(handle,'/verify',form==='hash'?{type:purpose,token_hash:generated.data.hashed_token}:{type:purpose,email:user.email,token:generated.data.email_otp});
      const leaked=Boolean(result.data.access_token||result.data.refresh_token||/(?:[#?&])(?:access_token|refresh_token|code)=/.test(result.location??''));
      if(leaked)console.error('Provider bypass denial failed:',purpose,form,'session-or-code-present');
      assert.ok(!leaked,'GET, POST token-hash and typed provider-code forms cannot mint a guarded session');
      if(purpose==='signup'){
        assert.equal(await confirmed(handle,user.id),false,'Provider-only confirmation variants do not verify pending account');
        assert.notEqual((await signIn(handle,user,user.password)).status,200,'Provider-only variants cannot activate signup password');
      }else assert.equal((await signIn(handle,user,user.password)).status,200,'Legitimate verified password remains live after provider-bypass denial');
    }
    const legitimate=await seed('recovery'),login=await signIn(handle,legitimate,legitimate.password);
    assert.equal(login.status,200,'Forged-token denial has real authorized-session positive control');
    const duplicate=await call(handle,'/admin/users',{email:legitimate.email.toUpperCase(),password:legitimate.password,email_confirm:false},true);
    if(duplicate.data.id)handle.trackedAccounts.add(duplicate.data.id);
    assert.ok([400,422].includes(duplicate.status),'Provider email case canonicalization cannot create a second account sharing proof');
    const aliasEmail=legitimate.email.replace('@','+guard-alias@');
    const alias=await call(handle,'/admin/users',{email:aliasEmail,password:legitimate.password,email_confirm:false},true);
    if(alias.data.id){handle.trackedAccounts.add(alias.data.id);handle.trackedEmails.add(aliasEmail);accounts.push(alias.data.id);}
    assert.ok(alias.status===200&&alias.data.id!==legitimate.id,'Plus alias is a distinct synthetic pending account without canonical proof sharing');
    assert.notEqual((await signIn(handle,{email:aliasEmail},legitimate.password)).status,200,'Distinct alias cannot inherit verified address proof or usable password');
    const parts=login.data.access_token.split('.');parts[2]=(parts[2][0]==='A'?'B':'A')+parts[2].slice(1);
    const forged=await fetch(`${handle.authUrl}/user`,{headers:{authorization:`Bearer ${parts.join('.')}`},signal:AbortSignal.timeout(10000)});
    assert.ok([401,403].includes(forged.status),'Forged JWT cannot read account or establish authenticated authority');
    assert.notEqual((await call(handle,'/otp',{phone:'+15555550123'})).status,200,'Disabled phone provider cannot produce login challenge');
    assert.notEqual((await call(handle,'/signup',{})).status,200,'Disabled anonymous provider cannot produce session');
    assert.ok(!(await call(handle,'/token?grant_type=pkce',{auth_code:randomBytes(32).toString('base64url'),code_verifier:randomBytes(32).toString('base64url')})).data.access_token,'Unknown PKCE exchange cannot invent a session');
    await db.query('UPDATE mort_auth_guard.control SET enabled=false');
    const pkceUser={email:`qa-${randomUUID()}@mort-fixture.invalid`,password:`Aa9!${randomBytes(20).toString('base64url')}`};
    const verifier=randomBytes(32).toString('base64url'),challenge=createHash('sha256').update(verifier).digest('base64url');
    handle.trackedEmails.add(pkceUser.email);
    const signup=await call(handle,'/signup',{...pkceUser,code_challenge:challenge,code_challenge_method:'s256'});
    if(signup.data.id){handle.trackedAccounts.add(signup.data.id);accounts.push(signup.data.id);pkceUser.id=signup.data.id;}
    assert.ok(signup.status===200&&pkceUser.id,'Real PKCE signup creates owned pending negative control');
    const flow=(await db.query('SELECT auth_code,code_challenge,code_challenge_method FROM auth.flow_state WHERE user_id=$1',[pkceUser.id])).rows[0];
    assert.ok(flow?.auth_code&&flow.code_challenge===challenge&&flow.code_challenge_method==='s256','PKCE denial uses a genuine provider-created code and matching verifier');
    handle.privateAudit.add(flow.auth_code);handle.privateAudit.add(verifier);
    await db.query('INSERT INTO mort_auth_guard.account_generations(account_id,recipient_hash) VALUES($1,$2)',[pkceUser.id,digest(pkceUser.email)]);
    await db.query('UPDATE mort_auth_guard.control SET enabled=true');
    const exchange=await call(handle,'/token?grant_type=pkce',{auth_code:flow.auth_code,code_verifier:verifier});
    assert.ok(!exchange.data.access_token&&!exchange.data.refresh_token&&exchange.status!==200,'Valid PKCE exchange cannot mint an unauthorized pending-account session');
    assert.equal(await confirmed(handle,pkceUser.id),false,'Valid PKCE bypass denial preserves pending account');
    assert.notEqual((await signIn(handle,pkceUser,pkceUser.password)).status,200,'Valid PKCE denial cannot activate attacker-selected signup password');
    for(const guardEnabled of [false,true]){
      await db.query('UPDATE mort_auth_guard.control SET enabled=false');
      const email=`qa-${randomUUID()}@mort-fixture.invalid`,password=`Aa9!${randomBytes(20).toString('base64url')}`;
      const codeVerifier=randomBytes(32).toString('base64url'),codeChallenge=createHash('sha256').update(codeVerifier).digest('base64url');
      handle.trackedEmails.add(email);
      const created=await call(handle,'/signup',{email,password,code_challenge:codeChallenge,code_challenge_method:'s256'});
      if(created.data.id){handle.trackedAccounts.add(created.data.id);accounts.push(created.data.id);}
      assert.ok(created.status===200&&created.data.id,'PKCE hook test starts with actual provider-created pending account');
      assert.equal((await call(handle,`/admin/users/${created.data.id}`,{email_confirm:true},true,'PUT')).status,200);
      const code=(await db.query('SELECT auth_code FROM auth.flow_state WHERE user_id=$1',[created.data.id])).rows[0].auth_code;
      handle.privateAudit.add(code);
      await db.query('INSERT INTO mort_auth_guard.account_generations(account_id,recipient_hash) VALUES($1,$2)',[created.data.id,digest(email)]);
      await db.query('UPDATE mort_auth_guard.control SET enabled=$1',[guardEnabled]);
      const result=await call(handle,'/token?grant_type=pkce',{auth_code:code,code_verifier:codeVerifier});
      if(guardEnabled)assert.ok(result.status!==200&&!result.data.access_token&&!result.data.refresh_token,'Real PKCE token hook denies provider-confirmed account lacking private proof');
      else assert.ok(result.status===200&&result.data.access_token&&result.data.refresh_token,'PKCE positive control proves real code and matching verifier are otherwise redeemable');
    }
    console.log('PASS provider bypass: GET/hash/code signup/recovery denials, real PKCE positive and proof-denial controls, verified password positives, forged JWT and disabled providers');
  }catch(error){
    console.error('Bypass assertion location:',(error.stack??'').split('\n').find(line=>line.includes('bypass.test.mjs'))?.replace(/.*bypass.test.mjs/,'bypass.test.mjs'));
    throw error;
  }finally{
    await db.query('UPDATE mort_auth_guard.control SET enabled=false');await cleanup(handle);
    for(const table of ['address_proofs','account_generations'])await db.query(`DELETE FROM mort_auth_guard.${table} WHERE account_id=ANY($1::uuid[])`,[accounts]);await db.end();
  }
}
