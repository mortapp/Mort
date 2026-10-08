import assert from 'node:assert/strict';
import pg from 'pg';
import {fixtureSql} from './fixture.mjs';

export async function run(handle){
  const schema=await fixtureSql(handle,"SELECT EXISTS(SELECT 1 FROM pg_namespace WHERE nspname='mort_auth_guard');");
  assert.ok(schema.trim()==='t','Private guard schema must exist');
  const disabled=await fixtureSql(handle,'SELECT enabled=false FROM mort_auth_guard.control WHERE singleton;');
  assert.ok(disabled.trim()==='t','Migration must default guard disabled');
  const protectedTables=await fixtureSql(handle,"SELECT count(*)=11 AND bool_and(c.relrowsecurity) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='mort_auth_guard' AND c.relkind='r';");
  assert.ok(protectedTables.trim()==='t','All eleven private store tables require RLS');
  const client=new pg.Client({connectionString:handle.dbUrl,connectionTimeoutMillis:2000});
  try{
    await client.connect();
    const tables=(await client.query("SELECT tablename FROM pg_tables WHERE schemaname='mort_auth_guard' ORDER BY tablename")).rows.map(row=>row.tablename);
    assert.equal(tables.length,11,'Permission regression enumerates all eleven private tables');
    for(const role of ['anon','authenticated','supabase_auth_admin'])for(const table of tables)for(const verb of ['SELECT','INSERT','UPDATE','DELETE']){
      if(!/^[a-z_]+$/.test(table))throw new Error('Private table identifier rejected');
      await client.query('BEGIN');await client.query(`SET LOCAL ROLE ${role}`);
      let denied=false;
      const sql=verb==='SELECT'?`SELECT * FROM mort_auth_guard.${table} LIMIT 0`:verb==='INSERT'?`INSERT INTO mort_auth_guard.${table} DEFAULT VALUES`:verb==='UPDATE'?`UPDATE mort_auth_guard.${table} SET ${table==='control'?'enabled=enabled':table==='account_generations'?'recipient_hash=recipient_hash':table==='families'?'state=state':table==='items'?'state=state':table==='outbox'?'state=state':table==='operation_grants'?'state=state':table==='capabilities'?'state=state':table==='address_proofs'?'source=source':table==='hook_events'?'outcome=outcome':table==='delivery_attempts'?'outcome=outcome':'kind=kind'} WHERE false`:`DELETE FROM mort_auth_guard.${table} WHERE false`;
      try{await client.query(sql);}catch(error){denied=error.code==='42501';}
      await client.query('ROLLBACK');assert.ok(denied,'Every private table denies actual SELECT INSERT UPDATE DELETE for untrusted database roles');
    }
    for(const role of ['anon','authenticated','supabase_auth_admin']){
      await client.query('BEGIN');await client.query(`SET LOCAL ROLE ${role}`);
      let denied=false;
      try{await client.query('SELECT * FROM mort_auth_guard.families');}catch(error){denied=error.code==='42501';}
      await client.query('ROLLBACK');
      assert.ok(denied,'Private reads must reject client database roles');
      await client.query('BEGIN');await client.query(`SET LOCAL ROLE ${role}`);let writeDenied=false;
      try{await client.query('DELETE FROM mort_auth_guard.hook_events');}catch(error){writeDenied=error.code==='42501';}
      await client.query('ROLLBACK');assert.ok(writeDenied,'Private writes must reject client and provider database roles');
    }
    const functions=await client.query("SELECT count(*)=0 AS safe FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='mort_auth_guard' AND (has_function_privilege('anon',p.oid,'EXECUTE') OR has_function_privilege('authenticated',p.oid,'EXECUTE'))");
    assert.ok(functions.rows[0].safe,'No private helper may be executed by client roles');
    assert.ok(!(await client.query("SELECT has_function_privilege('service_role','mort_auth_guard.fixture_transition(text,uuid,bigint)','EXECUTE') allowed")).rows[0].allowed,'Service key cannot execute synthetic cutover or restore control');
  }finally{await client.end();}
  console.log('PASS private schema defaults disabled, eleven RLS tables, client reads/helpers denied');
}
