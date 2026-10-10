import assert from 'node:assert/strict';
import {createHash, randomBytes, randomUUID} from 'node:crypto';
import pg from 'pg';
import {assertMortAuthFixture} from './fixture.mjs';
import {pending,call,cleanup} from './provider.test.mjs';
const digest=(value=randomBytes(32))=>createHash('sha256').update(value).digest('hex');
export async function run(handle,{verifySharedSources}={}){
  assertMortAuthFixture(handle,handle.observed);
  const db=new pg.Client({connectionString:handle.dbUrl,connectionTimeoutMillis:2000});
  const pool=new pg.Pool({connectionString:handle.dbUrl,max:8,connectionTimeoutMillis:2000});
  const accounts=new Set();const events=new Set();let connected=false;
  let controlGeneration;
  async function account(confirmed=false){
    const user=await pending(handle);accounts.add(user.id);
    if(confirmed)await call(handle,`/admin/users/${user.id}`,{email_confirm:true},true,'PUT');
    return {...user,recipientHash:digest(user.email)};
  }
  function request(user,source=digest(),purpose='confirmation'){
    const event={accountId:user.id,recipientHash:user.recipientHash,sourceHash:source,purpose,eventDigest:digest(),bodyDigest:digest(),signedAt:new Date().toISOString()};
    const material={familyId:randomUUID(),itemId:randomUUID(),codeDigest:digest(),linkDigest:digest(),encryptedEnvelope:'v1.fixture-ciphertext',addressGeneration:1,credentialGeneration:1,activationGeneration:Number(controlGeneration.activation_generation),restoreGeneration:Number(controlGeneration.restore_generation)};
    events.add(event.eventDigest);accounts.add(user.id);return {event,material};
  }
  const issueWith=async(client,req)=>(await client.query('SELECT mort_auth_guard.issue_event($1::jsonb,$2::jsonb) AS result',[JSON.stringify(req.event),JSON.stringify(req.material)])).rows[0].result;
  const issue=async(req)=>issueWith(db,req);
  const claim=async()=>(await db.query('SELECT mort_auth_guard.claim_delivery() AS result')).rows[0].result;
  const dispatch=async(lease)=>(await db.query('SELECT mort_auth_guard.begin_dispatch($1::jsonb) AS result',[JSON.stringify(lease)])).rows[0].result;
  const finish=async(lease,outcome)=>(await db.query('SELECT mort_auth_guard.finish_delivery($1::jsonb,$2) AS result',[JSON.stringify(lease),outcome])).rows[0].result;
  const inspect=async(item)=>(await db.query('SELECT state,delivery_state,grace_until FROM mort_auth_guard.items WHERE id=$1',[item])).rows[0];
  async function scopeClean(){
    await db.query('DELETE FROM mort_auth_guard.hook_events WHERE event_digest=ANY($1::text[])',[[...events]]);
    await db.query('DELETE FROM mort_auth_guard.quota_events WHERE account_id=ANY($1::uuid[]) OR kind=\'global_threshold\'',[[...accounts]]);
    await db.query('DELETE FROM mort_auth_guard.capabilities WHERE account_id=ANY($1::uuid[])',[[...accounts]]);
    await db.query('DELETE FROM mort_auth_guard.families WHERE account_id=ANY($1::uuid[])',[[...accounts]]);
    await db.query('DELETE FROM mort_auth_guard.account_generations WHERE account_id=ANY($1::uuid[])',[[...accounts]]);
    await db.query('UPDATE mort_auth_guard.control SET last_threshold_alert=NULL');
  }
  try{
    await db.connect();connected=true;
    controlGeneration=(await db.query('SELECT activation_generation,restore_generation FROM mort_auth_guard.control')).rows[0];
    const functions=await db.query("SELECT count(*)=4 AS installed FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='mort_auth_guard' AND p.proname=ANY($1)",[['issue_event','claim_delivery','begin_dispatch','finish_delivery']]);
    assert.ok(functions.rows[0].installed,'Issuance, claim, dispatch and promotion helpers must exist');
    await db.query('UPDATE mort_auth_guard.control SET enabled=true');
    assert.ok((await db.query('SELECT count(*)=0 AS empty FROM mort_auth_guard.outbox WHERE state<>\'terminal\'')).rows[0].empty,'Lifecycle suite requires an idle owned fixture');
    const staleBinding=request({id:randomUUID(),recipientHash:digest()});
    assert.ok(!(await issue({...staleBinding,material:{...staleBinding.material,restoreGeneration:999}})).ok,'Encrypted envelope cannot be admitted with a stale generation binding');
    const user=await account();const source=digest();const first=request(user,source);const accepted=await issue(first);
    assert.ok(accepted.ok,'Signed-bound pending account event issues a queued item');
    assert.ok((await inspect(first.material.itemId)).state==='issued','Queue admission alone does not make a challenge usable');
    assert.ok((await issue(first)).replayed,'Same event replay is idempotent');
    assert.ok(!(await issue({...first,event:{...first.event,bodyDigest:digest()}})).ok,'Modified event replay is rejected');
    assert.ok((await db.query('SELECT count(*)=1 AS once FROM mort_auth_guard.quota_events WHERE account_id=$1 AND kind=\'family\'',[user.id])).rows[0].once,'Idempotent replay charges one family admission');
    const lease=await claim();assert.ok(lease.ok&&lease.itemId===first.material.itemId,'Committed matching account is claimable');
    assert.ok((await db.query('SELECT count(*)=0 AS empty FROM mort_auth_guard.quota_events WHERE kind=\'dispatch\'')).rows[0].empty,'Claim without dispatch consumes zero SMTP quota');
    assert.ok((await dispatch(lease)).ok,'Dispatch reservation has a legitimate positive control');
    assert.ok(!(await dispatch(lease)).ok,'One lease cannot dispatch twice');
    assert.ok(await finish(lease,'acknowledged'),'Acknowledged current attempt promotes');
    assert.ok((await inspect(first.material.itemId)).state==='usable','Only acknowledged item becomes usable');
    assert.ok(!(await issue(request(user,source))).ok,'Resend cooldown begins at successful promotion');
    await db.query("UPDATE mort_auth_guard.families SET last_promoted_at=clock_timestamp()-interval '61 seconds',failures=2 WHERE id=$1",[accepted.familyId]);
    const second=request(user,source);const resend=await issue(second);assert.ok(resend.ok&&resend.familyId===accepted.familyId,'Resend preserves the active family');
    assert.ok(resend.familyExpiresAt===accepted.familyExpiresAt,'Resend cannot renew family expiry');
    assert.ok((await inspect(first.material.itemId)).state==='usable','Queued successor leaves old delivered item current');
    const next=await claim();assert.ok((await dispatch(next)).ok&&await finish(next,'acknowledged'),'Successor can be delivered');
    const grace=await db.query('SELECT i.state=\'grace\' AND i.grace_until=LEAST(f.last_promoted_at+interval \'60 seconds\',f.family_expires_at) AS exact FROM mort_auth_guard.items i JOIN mort_auth_guard.families f ON f.id=i.family_id WHERE i.id=$1',[first.material.itemId]);
    assert.ok(grace.rows[0].exact,'Grace starts at SMTP promotion and respects family deadline');
    await db.query("UPDATE mort_auth_guard.families SET last_promoted_at=clock_timestamp()-interval '61 seconds' WHERE id=$1",[accepted.familyId]);
    const third=request(user,source);assert.ok((await issue(third)).ok,'Third item admission is allowed after cooldown');const thirdLease=await claim();
    assert.ok((await dispatch(thirdLease)).ok&&await finish(thirdLease,'acknowledged'),'Third delivery succeeds');
    assert.ok((await inspect(first.material.itemId)).state==='retired','Older grace can never re-enter');
    assert.ok((await db.query('SELECT count(*)=2 AS bounded FROM mort_auth_guard.items WHERE family_id=$1 AND state IN(\'usable\',\'grace\')',[accepted.familyId])).rows[0].bounded,'At most current and previous items remain eligible');
    assert.ok((await db.query('SELECT failures=2 AS shared FROM mort_auth_guard.families WHERE id=$1',[accepted.familyId])).rows[0].shared,'Resend never resets failure count');
    await db.query("UPDATE mort_auth_guard.families SET last_promoted_at=clock_timestamp()-interval '61 seconds' WHERE id=$1",[accepted.familyId]);
    const failed=request(user,source);assert.ok((await issue(failed)).ok,'Failed successor can be queued');const badLease=await claim();assert.ok((await dispatch(badLease)).ok,'Failed send still reserves quota');
    assert.ok(!await finish(badLease,'ambiguous'),'Ambiguous delivery is never promoted');
    assert.ok((await inspect(third.material.itemId)).state==='usable'&&(await inspect(failed.material.itemId)).state==='retired','Ambiguous successor preserves last delivered item');
    await scopeClean();
    // The signed hook can precede signup commit. No account lookup occurs at admission.
    const failedSend=request(await account());assert.ok((await issue(failedSend)).ok,'SMTP-failure positive has a real queued item');const failedSendLease=await claim();
    assert.ok((await dispatch(failedSendLease)).ok,'SMTP failure keeps an actual charged dispatch reservation');
    assert.ok(!await finish(failedSendLease,'failed')&&(await inspect(failedSend.material.itemId)).state==='retired','Failed SMTP outcome cannot promote challenge eligibility');
    await scopeClean();
    const deferred={id:randomUUID(),recipientHash:digest()};const queued=request(deferred);assert.ok((await issue(queued)).ok,'Admission supports uncommitted synthetic signup');
    assert.ok(!(await claim()).ok,'Uncommitted signup defers instead of sending');
    assert.ok((await db.query('SELECT state=\'deferred\' AND encrypted_envelope IS NOT NULL AS deferred FROM mort_auth_guard.outbox WHERE item_id=$1',[queued.material.itemId])).rows[0].deferred,'Deferral retains bounded encrypted work');
    assert.ok((await db.query('SELECT count(*)=0 AS empty FROM mort_auth_guard.quota_events WHERE kind=\'dispatch\'')).rows[0].empty,'Deferral has zero dispatch charge');
    await db.query("UPDATE mort_auth_guard.outbox SET expires_at=clock_timestamp()-interval '1 second' WHERE item_id=$1",[queued.material.itemId]);await claim();
    assert.ok((await db.query('SELECT state=\'terminal\' AND encrypted_envelope IS NULL AS purged FROM mort_auth_guard.outbox WHERE item_id=$1',[queued.material.itemId])).rows[0].purged,'Rolled-back signup expires and purges ciphertext');
    await scopeClean();
    const mailbox=await account(),mailboxRequest=request(mailbox);assert.ok((await issue(mailboxRequest)).ok,'Recipient-race positive starts with real queued work');
    const mailboxChanged=`qa-${randomUUID()}@mort-fixture.invalid`;handle.trackedEmails.add(mailboxChanged);
    assert.equal((await call(handle,`/admin/users/${mailbox.id}`,{email:mailboxChanged},true,'PUT')).status,200);
    assert.ok(!(await claim()).ok,'Worker cannot claim a queued message after actual recipient binding changes');
    assert.ok((await db.query('SELECT encrypted_envelope IS NULL AND state=\'terminal\' AS erased FROM mort_auth_guard.outbox WHERE item_id=$1',[mailboxRequest.material.itemId])).rows[0].erased,'Address-change race clears stale encrypted recipient payload');
    await scopeClean();
    const sourceA=digest(),sourceB=digest();for(let i=0;i<3;i++)assert.ok((await issue(request(await account(),sourceA))).ok,'Source family quota positive');
    assert.ok(!(await issue(request(await account(),sourceA))).ok,'Fourth source family is denied');
    assert.ok((await issue(request(await account(),sourceB))).ok,'Independent trusted source remains usable');
    const claims=await Promise.all([pool.query('SELECT mort_auth_guard.claim_delivery() AS result'),pool.query('SELECT mort_auth_guard.claim_delivery() AS result'),pool.query('SELECT mort_auth_guard.claim_delivery() AS result')]);
    assert.ok(claims.filter(x=>x.rows[0].result.ok).length===2,'Three actual concurrent workers obtain at most two leases');
    const [one,two]=claims.map(x=>x.rows[0].result).filter(x=>x.ok);
    assert.ok((await dispatch(one)).ok,'First active delivery dispatches');
    await db.query("UPDATE mort_auth_guard.delivery_attempts SET expires_at=clock_timestamp()-interval '1 second' WHERE id=$1",[one.attemptId]);
    assert.ok(!await finish(one,'acknowledged')&&(await inspect(one.itemId)).state==='retired','Late acknowledgment cannot promote an expired attempt');
    assert.ok((await dispatch(two)).ok&&await finish(two,'acknowledged'),'Unrelated second valid lease remains usable');
    await scopeClean();
    // Real quota state at each boundary, with generated synthetic events only.
    const limited=await account(),unrelated=await account();const qSource=digest();
    const q=request(limited,qSource);assert.ok((await issue(q)).ok,'Quota test admission positive');const limitedLease=await claim();
    for(let i=0;i<5;i++)await db.query("INSERT INTO mort_auth_guard.quota_events(id,kind,account_id,recipient_hash,source_hash,occurred_at,attempt_id) VALUES($1,'dispatch',$2,$3,$4,clock_timestamp(),$5)",[randomUUID(),limited.id,digest(),qSource,randomUUID()]);
    assert.ok(!(await dispatch(limitedLease)).ok,'Source fifth attempt exhausts its sixth dispatch across different recipients');
    const uq=request(unrelated,digest());assert.ok((await issue(uq)).ok,'Unrelated quota request remains admissible');const uLease=await claim();assert.ok((await dispatch(uLease)).ok&&await finish(uLease,'acknowledged'),'Source B legitimate delivery works after source A exhaustion');
    await scopeClean();
    const recipientLimited=await account(),recipientRequest=request(recipientLimited);assert.ok((await issue(recipientRequest)).ok,'Recipient quota admission positive');const recipientLease=await claim();
    for(let i=0;i<5;i++)await db.query("INSERT INTO mort_auth_guard.quota_events(id,kind,account_id,recipient_hash,source_hash,occurred_at,attempt_id) VALUES($1,'dispatch',$2,$3,$4,clock_timestamp(),$5)",[randomUUID(),recipientLimited.id,recipientLimited.recipientHash,digest(),randomUUID()]);
    assert.ok(!(await dispatch(recipientLease)).ok,'Recipient sixth dispatch is denied even with a fresh source');
    const familyLimited=await account();for(let i=0;i<5;i++)await db.query("INSERT INTO mort_auth_guard.quota_events(id,kind,account_id,purpose,recipient_hash,source_hash,occurred_at) VALUES($1,'family',$2,'confirmation',$3,$4,clock_timestamp())",[randomUUID(),familyLimited.id,familyLimited.recipientHash,digest()]);
    assert.ok(!(await issue(request(familyLimited))).ok,'Sixth account-purpose family is denied regardless of source');
    await db.query("UPDATE mort_auth_guard.quota_events SET occurred_at=clock_timestamp()-interval '61 minutes' WHERE account_id=$1",[familyLimited.id]);
    assert.ok((await issue(request(familyLimited))).ok,'Rolling-hour expiry restores legitimate family admission');await scopeClean();
    const terminal=await account(true), terminalRequest=request(terminal,digest(),'recovery');const old=await issue(terminalRequest);const terminalLease=await claim();
    assert.ok((await dispatch(terminalLease)).ok&&await finish(terminalLease,'acknowledged'),'Delivered recovery positive');
    const capability=digest();const consumed=await db.query('SELECT mort_auth_guard.consume_item($1::jsonb,$2::jsonb) AS result',[JSON.stringify({itemId:old.itemId,kind:'link',credentialDigest:terminalRequest.material.linkDigest,verifierHash:digest()}),JSON.stringify({capabilityDigest:capability})]);
    assert.ok(consumed.rows[0].result.ok,'Terminal-family test has a genuinely issued capability');
    assert.ok((await issue(request(terminal,digest(),'recovery'))).ok,'Consumed family can start a fresh quota-controlled flow');
    assert.ok((await db.query('SELECT state=\'issued\' AS preserved FROM mort_auth_guard.capabilities WHERE digest=$1',[capability])).rows[0].preserved,'New family never cancels the already-issued independent capability');
    await db.query('DELETE FROM mort_auth_guard.capabilities WHERE digest=$1',[capability]);await scopeClean();
    // Global threshold alert and limit, independent of recipient/source limits.
    const global=await account(),globalRequest=request(global);assert.ok((await issue(globalRequest)).ok,'Global quota positive admission');
    for(let i=0;i<19;i++)await db.query("INSERT INTO mort_auth_guard.quota_events(id,kind,account_id,recipient_hash,source_hash,occurred_at,attempt_id) VALUES($1,'dispatch',$2,$3,$4,clock_timestamp(),$5)",[randomUUID(),global.id,digest(),digest(),randomUUID()]);
    const globalLease=await claim();assert.ok((await dispatch(globalLease)).ok&&await finish(globalLease,'acknowledged'),'Twentieth global dispatch remains allowed');
    assert.ok((await db.query('SELECT count(*)=1 AS once FROM mort_auth_guard.quota_events WHERE kind=\'global_threshold\'')).rows[0].once,'Global twentieth attempt produces one threshold alert');
    const afterThreshold=await account();assert.ok((await issue(request(afterThreshold))).ok,'Post-threshold admission positive');const afterLease=await claim();assert.ok((await dispatch(afterLease)).ok&&await finish(afterLease,'acknowledged'),'Threshold is observability rather than a hard gate');
    assert.ok((await db.query('SELECT count(*)=1 AS once FROM mort_auth_guard.quota_events WHERE kind=\'global_threshold\'')).rows[0].once,'Subsequent dispatch cannot duplicate the alert inside its rolling hour');
    for(let i=21;i<40;i++)await db.query("INSERT INTO mort_auth_guard.quota_events(id,kind,account_id,recipient_hash,source_hash,occurred_at,attempt_id) VALUES($1,'dispatch',$2,$3,$4,clock_timestamp(),$5)",[randomUUID(),global.id,digest(),digest(),randomUUID()]);
    assert.ok((await issue(request(await account()))).ok,'Queued work can be admitted independently of global dispatch');const overGlobal=await claim();assert.ok(!(await dispatch(overGlobal)).ok,'Forty-first global attempt is denied');
    await scopeClean();
    const queuedBatch=Array.from({length:24},()=>request({id:randomUUID(),recipientHash:digest()}));
    const admissions=await Promise.all(queuedBatch.map(req=>issueWith(pool,req)));
    assert.ok(admissions.filter(x=>x.ok).length===20,'Eight real connections atomically admit at most twenty of twenty-four queued events');
    const extra={id:randomUUID(),recipientHash:digest()};assert.ok(!(await issue(request(extra))).ok,'Concurrent-safe queue occupancy is capped at twenty');
    await scopeClean();
    if(verifySharedSources)await verifySharedSources({account,request,issueWith,scopeClean,claim,dispatch,finish,db});
    console.log('PASS issuance/promotion: idempotency, fixed family, cooldown/grace, terminal states, source quotas, delivery concurrency, deferred signup, queue bounds and positive controls');
  }finally{
    let failed=false;if(connected){
      try{await scopeClean();}catch(error){console.error('Fixture cleanup failed: private scope',typeof error.code==='string'?error.code:'unclassified');failed=true;}
      try{await db.query('UPDATE mort_auth_guard.control SET enabled=false');}catch{console.error('Fixture cleanup failed: disable control');failed=true;}
      try{await cleanup(handle);}catch{console.error('Fixture cleanup failed: owned provider accounts');failed=true;}
    }
    await pool.end();await db.end();if(failed)throw new Error('Fixture lifecycle cleanup failed');
  }
}
