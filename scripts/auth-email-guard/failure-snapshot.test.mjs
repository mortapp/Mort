import assert from 'node:assert/strict';
import {test,mock} from 'node:test';
import {createHash} from 'node:crypto';

let createFailureSnapshotRunner;
try{({createFailureSnapshotRunner}=await import('./failure-snapshot.mjs'));}
catch(error){if(error.code!=='ERR_MODULE_NOT_FOUND')throw error;}
const fixtureId='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const roles=['auth','db','realtime','storage'];
const owned=role=>`mort-mobile-auth-guard-qa-${role}-${fixtureId}`;
const labels={'com.docker.compose.project':'mort-mobile','mort.guard.fixture':fixtureId};
const setup=({rejectIdentity=false,foreignRole,failOperation,throwOperation}={})=>{
  assert.equal(typeof createFailureSnapshotRunner,'function','Owned fixture failure snapshot runner must exist');
  const calls=[],privateValue='snapshot-private-secret',email='snapshot-private@example.invalid';
  const handle={fixtureId,observed:{},password:privateValue,privateAudit:new Set(['private-audit-value'])};
  const log=`ERROR: permission denied for schema private_schema\n${privateValue}\n${email}\nprivate-audit-value\n`;
  const snapshot=createFailureSnapshotRunner({
    assertFixture:(received,observed)=>{assert.equal(received,handle);assert.equal(observed,handle.observed);if(rejectIdentity)throw new Error(privateValue);},
    spawn:(command,args,options)=>{
      assert.equal(command,'docker');assert.equal(options.timeout,5000);assert.equal(options.windowsHide,true);
      assert.equal(options.encoding,'utf8');assert.ok(options.maxBuffer<=1024*1024);
      const role=roles.find(value=>args.includes(owned(value)));assert.ok(role);
      const operation=args[0]==='logs'?'logs':args.includes('{{json .Config.Labels}}')?'ownership':'status';
      calls.push({role,operation,args});
      if(throwOperation===operation&&role==='auth')throw Object.assign(new Error(privateValue),{code:'ETIMEDOUT',stderr:privateValue});
      if(failOperation===operation&&role==='auth')return {status:7,signal:null,stderr:privateValue,stdout:privateValue};
      if(operation==='ownership')return {status:0,stdout:JSON.stringify({...labels,...(foreignRole===role?{'mort.guard.fixture':'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'}:{})}),stderr:''};
      if(operation==='status')return {status:0,stdout:JSON.stringify({Status:'running',Running:true,Paused:false,Restarting:false,Dead:false,OOMKilled:false,ExitCode:0,Error:privateValue,StartedAt:privateValue}),stderr:''};
      assert.deepEqual(args.slice(0,-1),['logs','--since','2m','--tail','200']);
      return {status:0,stdout:log,stderr:''};
    },
  });
  return {snapshot,handle,calls,log,privateValue,email};
};

test('failure snapshot rejects fixture identity before any Docker read',()=>{
  const {snapshot,handle,calls,privateValue}=setup({rejectIdentity:true});
  const result=snapshot(handle);
  assert.deepEqual(result.roles,[]);assert.equal(result.failures[0].operation,'identity');
  assert.equal(calls.length,0);assert.ok(!JSON.stringify(result).includes(privateValue));
});

test('failure snapshot verifies exact ownership before bounded role status and recent log reads',()=>{
  const {snapshot,handle,calls}=setup();const result=snapshot(handle);
  assert.deepEqual(result.roles.map(value=>value.role),roles);assert.deepEqual(result.failures,[]);
  for(const role of roles){
    assert.deepEqual(calls.filter(call=>call.role===role).map(call=>call.operation),['ownership','status','logs']);
    assert.equal(result.roles.find(value=>value.role===role).status.status,'running');
  }
  assert.equal(calls.length,12);
});

test('failure snapshot exports only safe status log fingerprints classes and privacy booleans',()=>{
  const {snapshot,handle,log,privateValue,email}=setup();const logger=mock.method(console,'error',()=>{});
  try{
    const result=snapshot(handle),serialized=JSON.stringify(result);
    for(const value of [privateValue,email,'private-audit-value','private_schema',fixtureId,'StartedAt','Error'])assert.ok(!serialized.includes(value));
    assert.equal(logger.mock.callCount(),0);
    const logs=result.roles[0].logs;
    assert.equal(logs.bytes,Buffer.byteLength(log));assert.equal(logs.sha256,createHash('sha256').update(log).digest('hex'));
    assert.deepEqual(logs.classifications,['permission_denied']);
    assert.deepEqual(logs.privacyPresence,{trackedCredential:true,emailLike:true});
  }finally{logger.mock.restore();}
});

test('failure snapshot skips all status and log reads for a foreign resource',()=>{
  const {snapshot,handle,calls}=setup({foreignRole:'auth'});const result=snapshot(handle);
  assert.deepEqual(calls.filter(call=>call.role==='auth').map(call=>call.operation),['ownership']);
  assert.equal(result.failures[0].role,'auth');assert.equal(result.failures[0].operation,'ownership');
  assert.equal(result.roles[0].status,null);assert.equal(result.roles[0].logs,null);
  assert.ok(result.roles.slice(1).every(value=>value.status.status==='running'));
});

test('snapshot status failures are independently retained while other reads complete without private values',()=>{
  const {snapshot,handle,privateValue}=setup({failOperation:'status'});const result=snapshot(handle);
  assert.equal(result.failures[0].operation,'status');assert.equal(result.failures[0].diagnostic.status,7);
  assert.equal(result.roles[0].status,null);assert.ok(result.roles[0].logs);
  assert.ok(result.roles.slice(1).every(value=>value.status.status==='running'));
  assert.ok(!JSON.stringify(result).includes(privateValue));
});

test('thrown snapshot operation errors cannot replace a primary failure or expose their message',()=>{
  const primary=new Error('original-primary-failure');
  const {snapshot,handle,calls,privateValue}=setup({throwOperation:'ownership'});const result=snapshot(handle);
  assert.equal(primary.message,'original-primary-failure');
  assert.equal(result.failures[0].diagnostic.errorCode,'ETIMEDOUT');
  assert.deepEqual(calls.filter(call=>call.role==='auth').map(call=>call.operation),['ownership']);
  assert.ok(!JSON.stringify(result).includes(privateValue));
});
