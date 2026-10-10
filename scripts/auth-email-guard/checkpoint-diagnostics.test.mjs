import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mock} from 'node:test';
import {spawnSync} from './subprocess-runner.mjs';
import {idleUntil} from './idle-wait.mjs';
const step=await import('./run-step.mjs').catch(()=>({}));
const sleep=await import('./long-run-safety.mjs').catch(()=>({}));
test('forcedHangProducesNamedFailureWithElapsed',()=>{
 assert.equal(typeof step.runStep,'function','Named step implementation missing');
 const log=mock.method(console,'error',()=>{});
 try{const result=step.runStep({name:'hang',timeoutMs:40,run:()=>spawnSync(process.execPath,['-e','setTimeout(()=>{},10000)'],{timeout:40,encoding:'utf8',windowsHide:true})});assert.equal(result.name,'hang');assert.ok(result.elapsedMs>=40);assert.equal(result.exitCode,null);assert.ok(result.signal);assert.ok(!JSON.stringify(result).includes('setTimeout'));}finally{log.mock.restore();}
});
test('heartbeatGapFlagged',async()=>{
 let time=0;const rows=[];await idleUntil(60000,{wallNow:()=>time,monoNow:()=>time,sleep:async()=>{time+=90000;},emit:r=>rows.push(r)});assert.equal(rows[0].possibleHostPause,true);
});
test('cleanupFailureDoesNotMaskPrimary',()=>{
 assert.equal(typeof step.runStep,'function','Named step implementation missing');
 const result=step.runStep({name:'cleanup',timeoutMs:100,run:()=>{throw Object.assign(new Error('private-content'),{code:'ECONNREFUSED'});}});
 assert.equal(result.name,'cleanup');assert.equal(result.exitCode,null);assert.ok(!JSON.stringify(result).includes('private-content'));assert.ok(result.failed);
});
test('startupFailureNamesPhase',()=>{
 assert.equal(typeof step.runStep,'function','Named step implementation missing');
 const result=step.runStep({name:'startup',timeoutMs:100,run:()=>({status:1,stderr:'private-content'})});assert.equal(result.name,'startup');assert.equal(result.exitCode,1);assert.ok(!JSON.stringify(result).includes('private-content'));
});
test('sleepEnabledRefusesLongRun',()=>{
 assert.equal(typeof sleep.assertLongRunSafety,'function','Long-run safety implementation missing');
 assert.throws(()=>sleep.assertLongRunSafety({durationMs:3600000,powerRequestVerified:false}),/Sleep prevention/);
 assert.equal(sleep.assertLongRunSafety({durationMs:3600000,powerRequestVerified:true}),true);
});
import {createFailureSnapshotRunner} from './failure-snapshot.mjs';
test('snapshotIsRedactedIncludingRestAndGuardRoles',()=>{
 const roles=[];
 const snapshot=createFailureSnapshotRunner({assertFixture:()=>{},spawn:(_cmd,args)=>{
  const role=args.at(-1).split('-qa-')[1].split('-aaaaaaaa')[0];roles.push(role);
  if(args.includes('{{json .Config.Labels}}'))return {status:1,stderr:'sensitive',stdout:''};
  return {status:0,stderr:'',stdout:''};
 }});
 const result=snapshot({fixtureId:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',observed:{}});
 assert.ok(roles.includes('rest')&&roles.includes('guard'),'Snapshot missing PostgREST and guard services');
 assert.ok(!JSON.stringify(result).includes('sensitive'));
});
test('reviewedPgIsReadyCommandNameIsAccepted',()=>{
 const result=step.runStep({name:'subprocess.spawnSync.docker.exec.db.pg_isready',timeoutMs:100,run:()=>({status:0,stderr:''})});
 assert.equal(result.failed,false);assert.equal(result.name,'subprocess.spawnSync.docker.exec.db.pg_isready');
});
