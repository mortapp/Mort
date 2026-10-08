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
    for(const role of ['anon','authenticated']){
      await client.query('BEGIN');await client.query(`SET LOCAL ROLE ${role}`);
      let denied=false;
      try{await client.query('SELECT * FROM mort_auth_guard.families');}catch(error){denied=error.code==='42501';}
      await client.query('ROLLBACK');
      assert.ok(denied,'Private reads must reject client database roles');
    }
    const functions=await client.query("SELECT count(*)=0 AS safe FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='mort_auth_guard' AND (has_function_privilege('anon',p.oid,'EXECUTE') OR has_function_privilege('authenticated',p.oid,'EXECUTE'))");
    assert.ok(functions.rows[0].safe,'No private helper may be executed by client roles');
  }finally{await client.end();}
  console.log('PASS private schema defaults disabled, eleven RLS tables, client reads/helpers denied');
}
