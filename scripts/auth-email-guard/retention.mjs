import pg from 'pg';
import {assertMortAuthFixture} from './fixture.mjs';
// Local automatic worker only. Production scheduling requires separate hosted
// activation review; no untrusted clock, target or retention override exists.
export function startRetention(handle,{intervalMs=60_000,onSweep=()=>{},onFailure=()=>{}}={}){
  assertMortAuthFixture(handle,handle.observed);
  if(!Number.isInteger(intervalMs)||intervalMs<50||intervalMs>60_000)throw new Error('Fixture retention interval rejected');
  let stopped=false,pending=null;
  async function sweep(){
    if(stopped||pending)return;
    pending=(async()=>{
      const db=new pg.Client({connectionString:handle.dbUrl,connectionTimeoutMillis:1000});
      try{
        await db.connect();await db.query('BEGIN');
        await db.query("SET LOCAL lock_timeout='200ms';SET LOCAL statement_timeout='2s'");
        await db.query('SELECT mort_auth_guard.maintain_retention()');await db.query('COMMIT');onSweep();
      }catch{await db.query('ROLLBACK').catch(()=>{});onFailure('retention_retry_required');}
      finally{await db.end();}
    })();
    try{await pending;}finally{pending=null;}
  }
  const timer=setInterval(()=>{void sweep();},intervalMs);timer.unref();
  void sweep();
  return {async stop(){stopped=true;clearInterval(timer);await pending;}};
}
