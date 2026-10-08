import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import pg from 'pg';
import {pending,call,signIn,cleanup} from './provider.test.mjs';
export async function run(handle){
  const db=new pg.Client({connectionString:handle.dbUrl}),accounts=[];
  const digest=v=>createHash('sha256').update(v).digest('hex');
  async function user(withProof){
    await db.query('UPDATE mort_auth_guard.control SET enabled=false');
    const u=await pending(handle);accounts.push(u.id);
    assert.equal((await call(handle,`/admin/users/${u.id}`,{email_confirm:true,user_metadata:{verified:true,mort_verified:true,role:'admin'}},true,'PUT')).status,200);
    const legacy=await signIn(handle,u,u.password);assert.equal(legacy.status,200,'Hook boundary negative controls start with actual provider session');
    await db.query('INSERT INTO mort_auth_guard.account_generations(account_id,recipient_hash) VALUES($1,$2)',[u.id,digest(u.email)]);
    if(withProof)await db.query(`INSERT INTO mort_auth_guard.address_proofs(account_id,address_generation,recipient_hash,activation_generation,restore_generation,source,proved_at) SELECT $1,1,$2,activation_generation,restore_generation,'confirmed_baseline',clock_timestamp() FROM mort_auth_guard.control`,[u.id,digest(u.email)]);
    await db.query('UPDATE mort_auth_guard.control SET enabled=true');return {u,legacy};
  }
  try{
    await db.connect();
    const denied=await user(false);
    assert.notEqual((await signIn(handle,denied.u,denied.u.password)).status,200,'Client user_metadata verification claims cannot replace private address proof');
    assert.notEqual((await call(handle,'/token?grant_type=refresh_token',{refresh_token:denied.legacy.data.refresh_token})).status,200,'Refresh after provider-only confirmation without private proof fails closed');
    const allowed=await user(true);
    assert.equal((await signIn(handle,allowed.u,allowed.u.password)).status,200,'Hook boundary verified owner remains able to sign in');
    for(const malformed of [true,{},[],null]){
      let rejected=false;try{await db.query('SELECT mort_auth_guard.custom_access_token_hook($1::jsonb)',[JSON.stringify({user_id:allowed.u.id,claims:[],authentication_method:malformed})]);}catch(e){rejected=['P0001','22P02'].includes(e.code);}
      assert.ok(rejected,'Malformed provider method or claim type cannot exploit token-hook truthiness');
    }
    const locker=new pg.Client({connectionString:handle.dbUrl});
    try{
      await locker.connect();await locker.query('BEGIN');await locker.query('LOCK TABLE mort_auth_guard.address_proofs IN ACCESS EXCLUSIVE MODE');
      const started=performance.now();let timedOut=false;
      const result=await Promise.race([signIn(handle,allowed.u,allowed.u.password),new Promise((_,reject)=>{const timer=setTimeout(()=>{timedOut=true;reject(new Error('Provider hook deadline not enforced'));},5000);timer.unref();})]);
      assert.ok(!timedOut&&result.status!==200&&performance.now()-started<5000,'Actual GoTrue hook timeout fails closed before five-second fixture deadline');
    }finally{await locker.query('ROLLBACK').catch(()=>{});await locker.end();}
    assert.equal((await signIn(handle,allowed.u,allowed.u.password)).status,200,'Hook timeout recovery restores legitimate sign-in');
    console.log('PASS real token-hook boundary: forged metadata, unauthorized refresh, malformed method/claim types, provider-enforced timeout and legitimate recovery');
  }catch(e){console.error('Hook assertion location:',(e.stack??'').split('\n').find(line=>line.includes('hook-boundary.test.mjs'))?.replace(/.*hook-boundary.test.mjs/,'hook-boundary.test.mjs'));throw e;}
  finally{
    await db.query('UPDATE mort_auth_guard.control SET enabled=false');await cleanup(handle);
    for(const table of ['address_proofs','account_generations'])await db.query(`DELETE FROM mort_auth_guard.${table} WHERE account_id=ANY($1::uuid[])`,[accounts]);await db.end();
  }
}
