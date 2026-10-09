import assert from 'node:assert/strict';
import {spawnSync} from './subprocess-runner.mjs';
import {configureFixtureAuth,fixtureSql,fixtureProcessEnv} from './fixture.mjs';
import {cleanup} from './provider.test.mjs';
import {run as providerIngress} from './provider-ingress.test.mjs';
export async function run(handle){
  const evidence=[];
  const originalDbLevel=await fixtureSql(handle,'SHOW log_min_messages');
  assert.ok(/^(debug[1-5]|info|notice|warning|error|log|fatal|panic)$/.test(originalDbLevel),'Fixture database log level is an allowlisted value');
  try{
    for(const level of ['info','fatal']){
      const databaseLevel=level==='fatal'?'fatal':originalDbLevel;
      await fixtureSql(handle,`ALTER SYSTEM SET log_min_messages='${databaseLevel}';SELECT pg_reload_conf()`);
      assert.equal(await fixtureSql(handle,'SHOW log_min_messages'),databaseLevel,'Database log level is actually applied for the profile');
      await providerIngress(handle,{logLevel:level,beforeCleanup:async({email,id})=>{
      const since=new Date(Date.now()-60_000).toISOString();
      const sinks={};
      for(const [sink,role] of [['provider','auth'],['smtp','capture'],['database','db']]){
        const r=spawnSync('docker',['logs','--since',since,`mort-mobile-auth-guard-qa-${role}-${handle.fixtureId}`],{env:fixtureProcessEnv(),encoding:'utf8',windowsHide:true,timeout:10000,maxBuffer:8*1024*1024});
        assert.equal(r.status,0,'Owned raw log sink is readable without exporting its contents');
        const raw=r.stdout+r.stderr;
        const privateValues=[handle.password,handle.jwtSecret,handle.anonKey,handle.serviceKey,...handle.privateAudit].filter(value=>value.length>=8&&!value.includes('@'));
        sinks[sink]={addressOccurrences:raw.split(email).length-1,otherPrivateOccurrences:privateValues.filter(value=>raw.includes(value)).length,bytesInspected:Buffer.byteLength(raw)};
      }
      const audits=await fixtureSql(handle,`SELECT count(*) FROM auth.audit_log_entries WHERE payload::text LIKE '%${email}%'`);
      sinks.databaseAudit={addressOccurrences:Number(audits)};
      sinks.hook=handle.hookLogEvidence;
      evidence.push({providerLevel:level,databaseLevel,smtpLevel:'default',sinks});
      if(process.env.MORT_EXPECT_RAW_LOG_CLEAN==='1')assert.equal(sinks.provider.addressOccurrences,0,'RED default provider logging must not expose addresses');
      await fixtureSql(handle,`DELETE FROM auth.audit_log_entries WHERE payload::text LIKE '%${email}%'`);
      }});
    }
    assert.ok(evidence[0].sinks.provider.addressOccurrences>0,'Finding: default provider output contains the synthetic address');
    assert.equal(evidence[1].sinks.provider.addressOccurrences,0,'Fatal provider output suppresses address events in this tested path');
    assert.ok(evidence.every(row=>row.sinks.databaseAudit.addressOccurrences>0),'Finding: database Auth audit payload retains address at both provider levels');
    handle.loggingEvidence=evidence;
    console.log('GREEN logging characterization; RED provider default output and database audit address findings remain');
    console.log('MORT_LOG_OBSERVATIONS '+JSON.stringify(evidence));
  }finally{await fixtureSql(handle,`ALTER SYSTEM SET log_min_messages='${originalDbLevel}';SELECT pg_reload_conf();UPDATE mort_auth_guard.control SET enabled=false`);await configureFixtureAuth(handle);await cleanup(handle);await fetch(`${handle.captureUrl}/api/v1/messages`,{method:'DELETE'});}
}
