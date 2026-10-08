import assert from 'node:assert/strict';
import {run as transportRun} from './jwt-transports.test.mjs';
import {fixtureSql,startFixtureTransports} from './fixture.mjs';

export async function run(handle){
  await startFixtureTransports(handle);
  for(let i=0;i<100;i++){
    if(await fixtureSql(handle,"SELECT to_regclass('storage.objects') IS NOT NULL AND to_regclass('realtime.messages') IS NOT NULL")==='t')break;
    if(i===99)assert.fail('Transport cleanup probe migrations did not complete');
    await new Promise(resolve=>setTimeout(resolve,100));
  }
  assert.equal(await fixtureSql(handle,"SELECT count(*) FROM storage.objects WHERE bucket_id='mort-fixture'"),'0','Failure-cleanup probe begins without orphan Storage objects');
  await assert.rejects(()=>transportRun(handle,{failAfterUpload:true}),/Injected synthetic transport upload failure/,'Actual failure after upload must reach owned cleanup');
  assert.equal(await fixtureSql(handle,"SELECT count(*) FROM storage.objects WHERE bucket_id='mort-fixture'"),'0','Failed transport run removes its uploaded object');
  assert.equal(await fixtureSql(handle,'SELECT count(*) FROM mort_transport.records'),'0','Failed transport run removes its owned record');
  assert.equal(await fixtureSql(handle,'SELECT count(*) FROM auth.users'),'0','Failed transport run removes its synthetic account');
  assert.equal(await fixtureSql(handle,'SELECT enabled FROM mort_auth_guard.control'),'f','Failed transport run leaves guard disabled');
}
