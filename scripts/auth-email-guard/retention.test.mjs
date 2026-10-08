import assert from 'node:assert/strict';
import {createHash,randomBytes,randomUUID} from 'node:crypto';
import pg from 'pg';
import {pending,cleanup,call,confirmed} from './provider.test.mjs';
import {startRetention} from './retention.mjs';
export async function run(handle){
  const db=new pg.Client({connectionString:handle.dbUrl}),accounts=[];
  const hash=v=>createHash('sha256').update(v??randomBytes(32)).digest('hex');
  let worker;
  try{
    await db.connect();
    await db.query('UPDATE mort_auth_guard.control SET enabled=false');
    assert.ok((await db.query("SELECT to_regprocedure('mort_auth_guard.maintain_retention()') IS NOT NULL AS ok")).rows[0].ok,'Retention helper installed');
    const user=await pending(handle);accounts.push(user.id);
    const fresh=randomUUID(),old=randomUUID(),expired=randomUUID(),ids=[fresh,old,expired],items=ids.map(()=>randomUUID());
    for(let i=0;i<3;i++){
      await db.query(`WITH t AS(SELECT clock_timestamp()-($6::int*interval '1 second') n)
        INSERT INTO mort_auth_guard.families(id,account_id,purpose,recipient_hash,source_hash,address_generation,credential_generation,activation_generation,restore_generation,issued_at,family_expires_at,state)
        SELECT $1,$2,'confirmation',$3,$4,1,1,activation_generation,restore_generation,n,n+interval '600 seconds',$5 FROM mort_auth_guard.control,t`,[ids[i],user.id,hash(user.email),hash(),i===0?'active':'expired',i===0?0:i===1?90000:601]);
      await db.query(`INSERT INTO mort_auth_guard.items(id,family_id,code_hmac,link_digest,issued_at) VALUES($1,$2,$3,$4,clock_timestamp())`,[items[i],ids[i],hash(),hash()]);
      await db.query(`INSERT INTO mort_auth_guard.outbox(item_id,encrypted_envelope,created_at,expires_at) SELECT $1,'v1.synthetic-encrypted-test',issued_at,family_expires_at FROM mort_auth_guard.families WHERE id=$2`,[items[i],ids[i]]);
    }
    const quota=randomUUID(),staleQuota=randomUUID(),event=hash();
    const orphan=randomUUID();
    await db.query('INSERT INTO mort_auth_guard.account_generations(account_id,recipient_hash) VALUES($1,$2)',[orphan,hash()]);
    await db.query(`INSERT INTO mort_auth_guard.address_proofs(account_id,address_generation,recipient_hash,activation_generation,restore_generation,source,proved_at,retired_at)
      SELECT $1,1,$2,activation_generation,restore_generation,'confirmed_baseline',clock_timestamp()-interval '25 hours',clock_timestamp()-interval '25 hours' FROM mort_auth_guard.control`,[orphan,hash()]);
    const staleOperation=randomUUID(),cap=hash();
    await db.query('INSERT INTO mort_auth_guard.account_generations(account_id,recipient_hash) VALUES($1,$2)',[user.id,hash(user.email)]);
    await db.query(`WITH t AS(SELECT clock_timestamp()-interval '601 seconds' n) INSERT INTO mort_auth_guard.capabilities(digest,family_id,account_id,purpose,address_generation,credential_generation,activation_generation,restore_generation,verifier_hash,issued_at,expires_at,state)
      SELECT $1,id,account_id,purpose,address_generation,credential_generation,activation_generation,restore_generation,$2,n,n+interval '300 seconds','reserved' FROM mort_auth_guard.families,t WHERE id=$3`,[cap,hash(),expired]);
    await db.query(`INSERT INTO mort_auth_guard.operation_grants(id,account_id,capability_digest,purpose,address_generation,credential_generation,fence_generation,activation_generation,restore_generation,expires_at,reserved_at,state)
      SELECT $1,account_id,digest,purpose,address_generation,credential_generation,1,activation_generation,restore_generation,expires_at,issued_at,'pending' FROM mort_auth_guard.capabilities WHERE digest=$2`,[staleOperation,cap]);
    assert.equal((await call(handle,`/admin/users/${user.id}`,{app_metadata:{mort_email_operation_id:staleOperation}},true,'PUT')).status,200);
    await db.query('UPDATE mort_auth_guard.control SET enabled=true');
    await db.query(`INSERT INTO mort_auth_guard.quota_events(id,kind,account_id,recipient_hash,source_hash,occurred_at) VALUES($1,'dispatch',$2,$3,$4,clock_timestamp()),($5,'dispatch',$2,$3,$4,clock_timestamp()-interval '3 hours')`,[quota,user.id,hash(user.email),hash(),staleQuota]);
    await db.query(`INSERT INTO mort_auth_guard.hook_events(event_digest,body_digest,signed_at,received_at,outcome) VALUES($1,$2,clock_timestamp()-interval '25 hours',clock_timestamp()-interval '25 hours','denied')`,[event,hash()]);
    let resolveTick;const tick=new Promise(resolve=>{resolveTick=resolve;});
    worker=startRetention(handle,{intervalMs:50,onSweep:resolveTick});
    await Promise.race([tick,new Promise((_,reject)=>setTimeout(()=>reject(new Error('Retention timer deadline exceeded')),5000))]);await worker.stop();worker=null;
    assert.equal((await db.query('SELECT count(*)::int n FROM mort_auth_guard.families WHERE id=$1',[old])).rows[0].n,0,'Aged terminal challenge rows purged automatically');
    assert.equal((await db.query('SELECT encrypted_envelope FROM mort_auth_guard.outbox WHERE item_id=$1',[items[2]])).rows[0].encrypted_envelope,null,'Expired encrypted recipient/payload erased immediately');
    assert.ok((await db.query('SELECT encrypted_envelope IS NOT NULL AS intact FROM mort_auth_guard.outbox WHERE item_id=$1',[items[0]])).rows[0].intact,'Fresh work is preserved');
    assert.equal((await db.query('SELECT count(*)::int n FROM mort_auth_guard.quota_events WHERE id=$1',[quota])).rows[0].n,1,'Current-hour dispatch is not refunded');
    assert.equal((await db.query('SELECT count(*)::int n FROM mort_auth_guard.quota_events WHERE id=$1',[staleQuota])).rows[0].n,0,'Out-of-window quota data removed');
    assert.equal((await db.query('SELECT count(*)::int n FROM mort_auth_guard.hook_events WHERE event_digest=$1',[event])).rows[0].n,0,'Stale hook metadata removed after signature replay window');
    assert.equal((await db.query('SELECT state FROM mort_auth_guard.operation_grants WHERE id=$1',[staleOperation])).rows[0].state,'fenced','Expired temporary grant is fenced by automatic worker');
    assert.notEqual((await call(handle,`/admin/users/${user.id}`,{app_metadata:{mort_email_operation_id:staleOperation},password:`Aa9!${randomBytes(20).toString('base64url')}`,email_confirm:true},true,'PUT')).status,200,'Delayed old provider write remains denied after cleanup');
    assert.equal(await confirmed(handle,user.id),false,'Delayed cleanup replay cannot verify pending user');
    assert.equal((await db.query('SELECT count(*)::int n FROM mort_auth_guard.account_generations WHERE account_id=$1',[orphan])).rows[0].n,0,'Orphan generation and proof data removed after authority is gone');
    console.log('PASS automatic retention: expired encrypted payloads cleared, aged challenge/hook data purged, current quota and fresh authority retained');
  }finally{
    await worker?.stop();await db.query('UPDATE mort_auth_guard.control SET enabled=false');await cleanup(handle);
    await db.query('DELETE FROM mort_auth_guard.operation_grants WHERE account_id=ANY($1::uuid[])',[accounts]);
    await db.query('DELETE FROM mort_auth_guard.families WHERE account_id=ANY($1::uuid[])',[accounts]);
    await db.query('DELETE FROM mort_auth_guard.quota_events WHERE account_id=ANY($1::uuid[])',[accounts]);
    await db.query('DELETE FROM mort_auth_guard.account_generations WHERE account_id=ANY($1::uuid[])',[accounts]);await db.end();
  }
}
