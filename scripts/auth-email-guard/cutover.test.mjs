import assert from 'node:assert/strict';
import pg from 'pg';
import {readFile,writeFile} from 'node:fs/promises';
import {createHash,randomBytes,randomUUID} from 'node:crypto';
import {assertMortAuthFixture,startFixture} from './fixture.mjs';
import {planControl,applyLocalControl,backupFixture,restoreFixture,advanceJournal,fixtureDirectory,discardBackup} from './control.mjs';
import {pending,call,signIn,cleanup} from './provider.test.mjs';
export async function run(handle){
  assertMortAuthFixture(handle,handle.observed);
  const db=new pg.Client({connectionString:handle.dbUrl}),accounts=[];
  const rehearsal={localFixture:true,apply:true,privateProviderRehearsal:true};
  let backup;
  const hash=()=>createHash('sha256').update(randomBytes(32)).digest('hex');
  try{
    await db.connect();
    assert.ok((await db.query("SELECT to_regprocedure('mort_auth_guard.fixture_transition(text,uuid,bigint)') IS NOT NULL AS ok")).rows[0].ok,'Owned transition helper installed');
    await db.query('UPDATE mort_auth_guard.control SET enabled=false');
    const verified=await pending(handle),unverified=await pending(handle);accounts.push(verified.id,unverified.id);
    assert.equal((await call(handle,`/admin/users/${verified.id}`,{email_confirm:true},true,'PUT')).status,200);
    const racing=await pending(handle);accounts.push(racing.id);
    const locker=new pg.Client({connectionString:handle.dbUrl}),boundary=new pg.Client({connectionString:handle.dbUrl,application_name:'mort_guard_cutover_race'});
    try{
      await locker.connect();await boundary.connect();await locker.query('BEGIN');
      await locker.query('SELECT id FROM auth.users WHERE id=$1 FOR UPDATE',[racing.id]);
      const confirmation=call(handle,`/admin/users/${racing.id}`,{email_confirm:true},true,'PUT');
      for(let i=0;i<100;i++){
        if((await db.query("SELECT EXISTS(SELECT 1 FROM pg_stat_activity WHERE usename='supabase_auth_admin' AND wait_event_type='Lock') ok")).rows[0].ok)break;
        if(i===99)assert.fail('Provider confirmation did not reach real mutation lock');await new Promise(r=>setTimeout(r,10));
      }
      const current=Number((await db.query('SELECT restore_generation FROM mort_auth_guard.control')).rows[0].restore_generation);
      const generation=await advanceJournal(fixtureDirectory,handle.fixtureId,current);
      await boundary.query('BEGIN');
      const transition=boundary.query('SELECT mort_auth_guard.fixture_transition($1,$2::uuid,$3::bigint)',['activate',handle.fixtureId,generation]);
      for(let i=0;i<100;i++){
        if((await db.query("SELECT EXISTS(SELECT 1 FROM pg_stat_activity WHERE application_name='mort_guard_cutover_race' AND wait_event_type='Lock') ok")).rows[0].ok)break;
        if(i===99)assert.fail('Cutover did not wait behind provider transaction');await new Promise(r=>setTimeout(r,10));
      }
      await locker.query('COMMIT');assert.equal((await confirmation).status,200);
      await transition;await boundary.query('COMMIT');
      assert.equal((await db.query('SELECT count(*)::int n FROM mort_auth_guard.address_proofs WHERE account_id=$1 AND retired_at IS NULL',[racing.id])).rows[0].n,0,'Concurrent confirmation cannot inherit pre-cutover baseline proof');
      assert.notEqual((await signIn(handle,racing,racing.password)).status,200,'Concurrent confirmation original password cannot sign in without proof');
    }finally{await locker.query('ROLLBACK').catch(()=>{});await boundary.query('ROLLBACK').catch(()=>{});await locker.end();await boundary.end();}
    const plan=await planControl('activate',handle);
    assert.equal(plan.dryRun,true);
    await assert.rejects(()=>applyLocalControl(plan,handle),/explicit/);
    await assert.rejects(()=>applyLocalControl(plan,handle,{localFixture:true,apply:true}),/Full guard activation unavailable/,'Partial fixture readiness cannot activate the full guard');
    await applyLocalControl(plan,handle,rehearsal);
    assert.equal((await signIn(handle,verified,verified.password)).status,200,'Existing verified user signs in after activation');
    assert.notEqual((await signIn(handle,unverified,unverified.password)).status,200,'Pending user never inherits baseline');
    assert.equal((await db.query('SELECT count(*)::int AS n FROM mort_auth_guard.address_proofs WHERE account_id=$1 AND retired_at IS NULL',[unverified.id])).rows[0].n,0);
    const beforeBackupSession=await signIn(handle,verified,verified.password);assert.equal(beforeBackupSession.status,200,'Restore negative control has a real pre-backup refresh session');
    const family=randomUUID(),item=randomUUID(),link=hash(),cap=hash(),verifier=hash(),capFamily=randomUUID(),operationId=randomUUID();
    await db.query(`WITH t AS(SELECT clock_timestamp() n) INSERT INTO mort_auth_guard.families(id,account_id,purpose,recipient_hash,source_hash,address_generation,credential_generation,activation_generation,restore_generation,issued_at,family_expires_at,state)
      SELECT $1,g.account_id,'recovery',g.recipient_hash,$2,g.address_generation,g.credential_generation,c.activation_generation,c.restore_generation,n,n+interval '600 seconds',$3
      FROM mort_auth_guard.account_generations g,mort_auth_guard.control c,t WHERE g.account_id=$4`,[family,hash(),'active',verified.id]);
    await db.query(`INSERT INTO mort_auth_guard.items(id,family_id,code_hmac,link_digest,state,delivery_state,issued_at,promoted_at) VALUES($1,$2,$3,$4,'usable','acknowledged',clock_timestamp(),clock_timestamp())`,[item,family,hash(),link]);
    await db.query(`INSERT INTO mort_auth_guard.families SELECT $1,account_id,purpose,recipient_hash,source_hash,address_generation,credential_generation,activation_generation,restore_generation,issued_at,family_expires_at,failures,'consumed',last_promoted_at,inflight_until FROM mort_auth_guard.families WHERE id=$2`,[capFamily,family]);
    await db.query(`WITH t AS(SELECT clock_timestamp() n) INSERT INTO mort_auth_guard.capabilities(digest,family_id,account_id,purpose,address_generation,credential_generation,activation_generation,restore_generation,verifier_hash,issued_at,expires_at)
      SELECT $1,id,account_id,purpose,address_generation,credential_generation,activation_generation,restore_generation,$2,n,n+interval '300 seconds' FROM mort_auth_guard.families,t WHERE id=$3`,[cap,verifier,capFamily]);
    assert.ok((await db.query('SELECT mort_auth_guard.reserve_password($1::jsonb) result',[JSON.stringify({capabilityDigest:cap,verifierHash:verifier,passwordValid:true,operationId})])).rows[0].result.ok,'Backup contains live private grant negative control');
    assert.equal((await call(handle,`/admin/users/${verified.id}`,{app_metadata:{mort_email_operation_id:operationId}},true,'PUT')).status,200);
    const expiredFamily=randomUUID(),expiredItem=randomUUID(),expiredLink=hash(),consumedFamily=randomUUID(),consumedItem=randomUUID(),consumedLink=hash();
    for(const [fid,iid,secret,terminal] of [[expiredFamily,expiredItem,expiredLink,'expired'],[consumedFamily,consumedItem,consumedLink,'consumed']]){
      await db.query(`WITH t AS(SELECT clock_timestamp()-interval '601 seconds' n) INSERT INTO mort_auth_guard.families SELECT $1,account_id,purpose,recipient_hash,source_hash,address_generation,credential_generation,activation_generation,restore_generation,n,n+interval '600 seconds',failures,$3,last_promoted_at,inflight_until FROM mort_auth_guard.families,t WHERE id=$2`,[fid,family,terminal]);
      await db.query(`INSERT INTO mort_auth_guard.items(id,family_id,code_hmac,link_digest,state,delivery_state,issued_at,promoted_at) VALUES($1,$2,$3,$4,'retired','acknowledged',clock_timestamp()-interval '601 seconds',clock_timestamp()-interval '600 seconds')`,[iid,fid,hash(),secret]);
    }
    backup=await backupFixture(handle);
    const originalBackup=await readFile(backup),corrupt=Buffer.from(originalBackup);corrupt[corrupt.length-1]^=1;
    await writeFile(backup,corrupt);
    try{await assert.rejects(()=>restoreFixture(handle,backup,rehearsal),/Fixture backup integrity rejected/,'Corrupt database backup cannot enter restore boundary');}
    finally{await writeFile(backup,originalBackup);}
    const consume=async()=> (await db.query('SELECT mort_auth_guard.consume_item($1::jsonb,$2::jsonb) result',[JSON.stringify({itemId:item,kind:'link',credentialDigest:link,verifierHash:hash()}),JSON.stringify({capabilityDigest:hash()})])).rows[0].result;
    assert.ok((await consume()).ok,'Pre-backup live item genuinely consumes before restore');
    const replacement=`Aa9!${randomBytes(20).toString('base64url')}`;
    const oldApply=()=>call(handle,`/admin/users/${verified.id}`,{app_metadata:{mort_email_operation_id:operationId},password:replacement},true,'PUT');
    assert.equal((await oldApply()).status,200,'Pre-backup grant genuinely commits before restore');
    const before=(await db.query('SELECT restore_generation FROM mort_auth_guard.control')).rows[0].restore_generation;
    await applyLocalControl(await planControl('rollback',handle),handle,rehearsal);
    assert.equal((await signIn(handle,verified,replacement)).status,200,'Verified login works after rollback');
    assert.equal((await db.query('SELECT enabled FROM mort_auth_guard.control')).rows[0].enabled,false);
    assert.ok(!(await consume()).ok,'Rollback never reopens a consumed guard challenge');
    await restoreFixture(handle,backup,rehearsal);
    assert.ok(BigInt((await db.query('SELECT restore_generation FROM mort_auth_guard.control')).rows[0].restore_generation)>BigInt(before),'Old backup never chooses its own restore generation');
    assert.equal((await signIn(handle,verified,verified.password)).status,200,'Verified user signs in after real restore');
    assert.notEqual((await signIn(handle,unverified,unverified.password)).status,200,'Restore preserves pending account isolation');
    assert.notEqual((await call(handle,'/token?grant_type=refresh_token',{refresh_token:beforeBackupSession.data.refresh_token})).status,200,'Restore never revives a pre-backup refresh session revoked by recovery');
    assert.ok(!(await consume()).ok,'Restored once-used item cannot issue authority again');
    for(const [iid,secret] of [[expiredItem,expiredLink],[consumedItem,consumedLink]]){
      const result=(await db.query('SELECT mort_auth_guard.consume_item($1::jsonb,$2::jsonb) result',[JSON.stringify({itemId:iid,kind:'link',credentialDigest:secret,verifierHash:hash()}),JSON.stringify({capabilityDigest:hash()})])).rows[0].result;
      assert.ok(!result.ok,'Snapshot expired and consumed challenges remain unusable after actual restore');
    }
    assert.ok(!(await db.query('SELECT mort_auth_guard.reserve_password($1::jsonb) result',[JSON.stringify({capabilityDigest:cap,verifierHash:verifier,passwordValid:true,operationId:randomUUID()})])).rows[0].result.ok,'Restored capability cannot reserve again');
    assert.notEqual((await oldApply()).status,200,'Restored old Admin grant cannot change a password');
    assert.equal((await signIn(handle,verified,verified.password)).status,200,'Rejected stale restore write preserves verified password');
    const currentGeneration=Number((await db.query('SELECT restore_generation FROM mort_auth_guard.control')).rows[0].restore_generation);
    await advanceJournal(fixtureDirectory,handle.fixtureId,currentGeneration);
    await assert.rejects(()=>startFixture(),/Fixture journal mismatch/,'Runner restart refuses old or partially transitioned database authority');
    await applyLocalControl(await planControl('restore',handle),handle,rehearsal);
    assert.equal((await signIn(handle,verified,verified.password)).status,200,'Explicit fenced reconciliation restores verified-user liveness');
    console.log('PASS cutover: explicit dry-run/apply, verified baseline, pending exclusion, rollback, real database backup/restore, external monotonic generation');
  }catch(error){
    console.error('Cutover assertion location:',(error.stack??'').split('\n').find(line=>line.includes('cutover.test.mjs'))?.replace(/.*cutover.test.mjs/,'cutover.test.mjs'));
    throw error;
  }finally{
    await db.query('UPDATE mort_auth_guard.control SET enabled=false').catch(()=>{});
    await cleanup(handle,accounts);
    await db.query('DELETE FROM mort_auth_guard.operation_grants WHERE account_id=ANY($1::uuid[])',[accounts]);
    await db.query('DELETE FROM mort_auth_guard.families WHERE account_id=ANY($1::uuid[])',[accounts]);
    await db.query('DELETE FROM mort_auth_guard.address_proofs WHERE account_id=ANY($1::uuid[])',[accounts]);
    await db.query('DELETE FROM mort_auth_guard.account_generations WHERE account_id=ANY($1::uuid[])',[accounts]);
    await db.end();
    if(backup)await discardBackup(handle,backup);
  }
}
