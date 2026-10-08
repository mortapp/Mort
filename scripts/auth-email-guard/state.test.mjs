import assert from 'node:assert/strict';
import {createHash,randomUUID,randomBytes} from 'node:crypto';
import pg from 'pg';
import {assertMortAuthFixture} from './fixture.mjs';
import {pending,call,cleanup} from './provider.test.mjs';
const hash=()=>createHash('sha256').update(randomBytes(32)).digest('hex');
export async function run(handle){
  assertMortAuthFixture(handle,handle.observed);
  const db=new pg.Client({connectionString:handle.dbUrl,connectionTimeoutMillis:2000});
  const accounts=[];let connected=false;
  async function seeded(){
    const user=await pending(handle);await call(handle,`/admin/users/${user.id}`,{email_confirm:true},true,'PUT');
    const account=user.id,family=randomUUID(),item=randomUUID(),code=hash(),link=hash();accounts.push(account);
    const recipient=hash();
    await db.query('INSERT INTO mort_auth_guard.account_generations(account_id,recipient_hash) VALUES($1,$2)',[account,recipient]);
    await db.query(`WITH timing AS(SELECT clock_timestamp() AS now) INSERT INTO mort_auth_guard.families(id,account_id,purpose,recipient_hash,source_hash,address_generation,credential_generation,activation_generation,restore_generation,issued_at,family_expires_at)
      SELECT $1,$2,'recovery',$3,$4,1,1,1,1,now,now+interval '600 seconds' FROM timing`,[family,account,recipient,hash()]);
    // Both timestamp columns must share one value; establish fixture-only exact deadline.
    return {account,family,item,code,link,recipient};
  }
  async function item(row){
    await db.query(`INSERT INTO mort_auth_guard.items(id,family_id,code_hmac,link_digest,state,delivery_state,issued_at,promoted_at)
      VALUES($1,$2,$3,$4,'usable','acknowledged',clock_timestamp(),clock_timestamp())`,[row.item,row.family,row.code,row.link]);
  }
  const consumeWith=async(client,row,digest=row.link,kind='link',cap=hash())=>{
    const result=await client.query('SELECT mort_auth_guard.consume_item($1::jsonb,$2::jsonb) AS result',[
      JSON.stringify({itemId:row.item,kind,credentialDigest:digest,verifierHash:hash()}),JSON.stringify({capabilityDigest:cap})]);
    return result.rows[0].result;
  };
  const consume=(...args)=>consumeWith(db,...args);
  const failures=async(row)=>(await db.query('SELECT failures FROM mort_auth_guard.families WHERE id=$1',[row.family])).rows[0].failures;
  try{
    await db.connect();connected=true;
    const installed=await db.query("SELECT to_regprocedure('mort_auth_guard.consume_item(jsonb,jsonb)') IS NOT NULL AS installed");
    assert.ok(installed.rows[0].installed,'Atomic consume helper must exist');
    await db.query('UPDATE mort_auth_guard.control SET enabled=true WHERE singleton');
    const a=await seeded();await item(a);const b=await seeded();await item(b);
    assert.ok(!(await consume(a,b.link)).ok,'Cross-item secret must be denied');
    assert.ok(await failures(a)===1&&await failures(b)===0,'Wrong recognized secret debits addressed family only');
    for(let i=1;i<5;i++)assert.ok(!(await consume(a,hash(),i%2?'code':'link')).ok,'Wrong code/link must share failure budget');
    assert.ok(await failures(a)===5&&!(await consume(a)).ok,'Fifth failure permanently exhausts the family');
    assert.ok((await consume(b)).ok,'Unrelated legitimate family remains usable');
    assert.ok(!(await consume(b)).ok,'Consumed family cannot issue another capability');
    const c=await seeded();await item(c);const cap=hash();const result=await consume(c,c.link,'link',cap);
    assert.ok(result.ok,'Valid family must produce capability');
    const lease=await db.query("SELECT state='issued' AND expires_at=issued_at+interval '300 seconds' AS valid FROM mort_auth_guard.capabilities WHERE digest=$1",[cap]);
    assert.ok(lease.rows[0].valid,'Capability lease is independently fixed at 300 seconds');
    const d=await seeded();await item(d);
    await db.query("WITH timing AS(SELECT clock_timestamp() AS now) UPDATE mort_auth_guard.families SET issued_at=now-interval '601 seconds',family_expires_at=now-interval '1 second' FROM timing WHERE id=$1",[d.family]);
    assert.ok(!(await consume(d)).ok&&await failures(d)===0,'Expired family rejects without charging a guess');
    const e=await seeded();await item(e);
    let rollback=false;try{await consume(e,e.link,'link',cap);}catch(error){rollback=error.code==='23505';}
    assert.ok(rollback,'Capability collision forces transaction rollback');
    assert.ok((await db.query('SELECT state FROM mort_auth_guard.families WHERE id=$1',[e.family])).rows[0].state==='active','Failed capability insertion must not consume the family');
    assert.ok((await consume(e)).ok,'Legitimate retry after rolled-back insert succeeds');
    const grace=await seeded();await item(grace);const previous={...grace,item:randomUUID(),code:hash(),link:hash()};await item(previous);
    await db.query("UPDATE mort_auth_guard.items SET state='grace',grace_until=clock_timestamp()+interval '60 seconds' WHERE id=$1",[previous.item]);
    assert.ok(!(await consume(grace,hash(),'code')).ok&&!(await consume(previous,hash(),'link')).ok&&await failures(grace)===2,'Current and previous representations share one family budget');
    assert.ok((await consume(previous)).ok&&!(await consume(grace)).ok,'Grace success atomically consumes current item too');
    const race=await seeded();await item(race);
    const other=new pg.Client({connectionString:handle.dbUrl,connectionTimeoutMillis:2000});
    const locker=new pg.Client({connectionString:handle.dbUrl,connectionTimeoutMillis:2000});
    try{
      await other.connect();await locker.connect();
      const results=await Promise.all([consume(race),consumeWith(other,race)]);
      assert.ok(results.filter(result=>result.ok).length===1,'Two actual concurrent connections produce exactly one consume success');
      const afterLock=await seeded();await item(afterLock);
      await db.query("WITH timing AS(SELECT clock_timestamp() AS now) UPDATE mort_auth_guard.families SET issued_at=now-interval '599.9 seconds',family_expires_at=now+interval '0.1 seconds' FROM timing WHERE id=$1",[afterLock.family]);
      await locker.query('BEGIN');await locker.query('SELECT id FROM mort_auth_guard.families WHERE id=$1 FOR UPDATE',[afterLock.family]);
      const delayed=consumeWith(other,afterLock);
      await new Promise(resolve=>setTimeout(resolve,150));await locker.query('COMMIT');
      assert.ok(!(await delayed).ok&&await failures(afterLock)===0,'Family deadline is checked after lock wait and creates no capability');
      await db.query('BEGIN');await db.query('SET LOCAL ROLE service_role');
      const malformed=await db.query("SELECT mort_auth_guard.consume_item('{}'::jsonb,'{}'::jsonb) AS result");
      assert.ok(malformed.rows[0].result.ok===false,'Authorized service can execute private helper without table grants');await db.query('ROLLBACK');
    }finally{await locker.query('ROLLBACK').catch(()=>{});await other.end();await locker.end();}
    console.log('PASS atomic consume: shared failures, exhaustion, grace, one-use concurrent winner, fixed capability lease, post-lock expiration, insertion rollback and service control');
  }finally{
    let cleanupFailed=false;
    if(connected){
      for(const account of accounts){
        try{
          await db.query('DELETE FROM mort_auth_guard.capabilities WHERE account_id=$1',[account]);
          await db.query('DELETE FROM mort_auth_guard.families WHERE account_id=$1',[account]);
          await db.query('DELETE FROM mort_auth_guard.account_generations WHERE account_id=$1',[account]);
        }catch{cleanupFailed=true;}
      }
      try{await db.query('UPDATE mort_auth_guard.control SET enabled=false WHERE singleton');await cleanup(handle);}catch{cleanupFailed=true;}
    }
    await db.end();if(cleanupFailed)throw new Error('Fixture state cleanup failed');
  }
}
