import assert from 'node:assert/strict';
import {test,mock} from 'node:test';
import {once} from 'node:events';
let runner;
try{runner=await import('./subprocess-runner.mjs');}catch(error){if(error.code!=='ERR_MODULE_NOT_FOUND')throw error;}
const implementation=()=>assert.ok(runner,'Shared subprocess runner must exist');
const diagnostic=logger=>logger.mock.calls.map(call=>call.arguments.join(' ')).find(line=>line.startsWith('Fixture subprocess failed: '));
const parsed=logger=>JSON.parse(diagnostic(logger).slice('Fixture subprocess failed: '.length));
const metadata=(logger,event)=>logger.mock.calls.map(call=>call.arguments.join(' '))
  .filter(line=>line.startsWith('Fixture subprocess '+event+': ')).map(line=>JSON.parse(line.slice(('Fixture subprocess '+event+': ').length)));

test('sync spawn retains status and output while logging only redacted failure metadata',()=>{
  implementation();const logger=mock.method(console,'error',()=>{});
  try{
    const result=runner.spawnSync(process.execPath,['-e',"process.stdout.write('private-stdout');process.stderr.write('private-stderr');process.exit(7)"],{encoding:'utf8',windowsHide:true});
    assert.equal(result.status,7);assert.equal(result.stdout,'private-stdout');assert.equal(result.stderr,'private-stderr');
    assert.equal(parsed(logger).status,7);
    assert.ok(!diagnostic(logger).includes('private-stdout'));assert.ok(!diagnostic(logger).includes('private-stderr'));
  }finally{logger.mock.restore();}
});

test('sync exec captures ignored stderr silently and preserves its exception exit status',()=>{
  implementation();const logger=mock.method(console,'error',()=>{});
  try{
    assert.throws(()=>runner.execFileSync(process.execPath,['-e',"process.stderr.write('ignored-private-error');process.exit(8)"],{stdio:'ignore',windowsHide:true}),error=>error.status===8);
    assert.equal(parsed(logger).status,8);assert.equal(parsed(logger).stderrBytes,21);
    assert.ok(!diagnostic(logger).includes('ignored-private-error'));
  }finally{logger.mock.restore();}
});

test('successful sync exec preserves string return and emits only safe lifecycle metadata',()=>{
  implementation();const logger=mock.method(console,'error',()=>{});
  try{
    assert.equal(runner.execFileSync(process.execPath,['-e',"process.stdout.write('synthetic-success')"],{encoding:'utf8',windowsHide:true}),'synthetic-success');
    assert.equal(diagnostic(logger),undefined);
    assert.equal(metadata(logger,'started').length,1);assert.equal(metadata(logger,'completed').length,1);
    assert.equal(metadata(logger,'completed')[0].diagnostic.status,0);
    assert.equal(metadata(logger,'completed')[0].stderrAvailable,false);
    assert.ok(!JSON.stringify(logger.mock.calls).includes('synthetic-success'));
  }finally{logger.mock.restore();}
});

test('async spawn preserves child streams and close event while recording failure stderr',async()=>{
  implementation();const logger=mock.method(console,'error',()=>{});
  try{
    const child=runner.spawn(process.execPath,['-e',"process.stdin.once('data',()=>{process.stdout.write('child-private-output');process.stderr.write('child-private-error');process.exit(9)})"],{stdio:['pipe','pipe','pipe'],windowsHide:true});
    let output='',errors='';child.stdout.on('data',bytes=>{output+=bytes;});child.stderr.on('data',bytes=>{errors+=bytes;});
    const closed=once(child,'close');child.stdin.end('synthetic-input');
    const [status,signal]=await closed;
    assert.equal(status,9);assert.equal(signal,null);assert.equal(output,'child-private-output');assert.equal(errors,'child-private-error');
    assert.equal(parsed(logger).status,9);assert.equal(parsed(logger).stderrBytes,19);
    assert.ok(!diagnostic(logger).includes('child-private'));
  }finally{logger.mock.restore();}
});

test('async stderr capture is bounded while consumers retain the complete stream',async()=>{
  implementation();const logger=mock.method(console,'error',()=>{});
  try{
    const child=runner.spawn(process.execPath,['-e',"process.stderr.write(Buffer.alloc(4*1024*1024+17,120),()=>process.exit(3))"],{stdio:['ignore','ignore','pipe'],windowsHide:true});
    let bytes=0;child.stderr.on('data',chunk=>{bytes+=chunk.length;});await once(child,'close');
    assert.equal(bytes,4*1024*1024+17);assert.equal(parsed(logger).stderrBytes,4*1024*1024);
    assert.ok(logger.mock.calls.some(call=>call.arguments.join(' ').includes('stderr capture truncated')));
  }finally{logger.mock.restore();}
});

test('spawn errors retain their error event and emit one safe diagnostic',async()=>{
  implementation();const logger=mock.method(console,'error',()=>{});
  try{
    const child=runner.spawn('synthetic-private-missing-command',[],{stdio:'pipe',windowsHide:true});
    const errorPromise=new Promise(resolve=>child.once('error',resolve));
    const closed=new Promise(resolve=>child.once('close',resolve));
    const error=await errorPromise;await closed;
    assert.equal(error.code,'ENOENT');assert.equal(logger.mock.callCount(),3);
    assert.equal(parsed(logger).errorCode,'ENOENT');assert.ok(!diagnostic(logger).includes('synthetic-private-missing-command'));
  }finally{logger.mock.restore();}
});

test('sync lifecycle records UTC start, monotonic duration, timeout, and redacted completion',()=>{
  implementation();const logger=mock.method(console,'error',()=>{});
  try{
    const before=Date.now();
    const result=runner.spawnSync(process.execPath,['-e',"process.stderr.write('timing-private-secret');setTimeout(()=>process.exit(6),25)"],{timeout:1500,encoding:'utf8',windowsHide:true});
    const after=Date.now(),[start]=metadata(logger,'started'),[completed]=metadata(logger,'completed');
    assert.equal(result.status,6);
    assert.equal(start.api,'spawnSync');assert.equal(start.executable,'node');assert.equal(start.dockerOperation,null);
    assert.match(start.startedAt,/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/);
    assert.ok(Date.parse(start.startedAt)>=before&&Date.parse(start.startedAt)<=after);
    assert.equal(start.timeoutMs,1500);assert.equal(completed.startedAt,start.startedAt);assert.equal(completed.timeoutMs,1500);
    assert.ok(Number.isFinite(completed.elapsedMs)&&completed.elapsedMs>=25);
    assert.equal(completed.diagnostic.status,6);assert.equal(completed.diagnostic.stderrBytes,21);
    assert.equal(completed.diagnostic.signal,null);assert.equal(completed.stderrAvailable,true);
    assert.ok(!JSON.stringify(logger.mock.calls).includes('timing-private-secret'));
  }finally{logger.mock.restore();}
});

test('command labels allowlist executables and Docker operations without echoing arguments',()=>{
  implementation();assert.equal(typeof runner.subprocessCommandMetadata,'function');
  assert.deepEqual(runner.subprocessCommandMetadata('C:\\private-path\\docker.exe',['exec','private-container','private-token']),{executable:'docker',dockerOperation:'exec',fixtureRole:null,commandKind:'unclassified'});
  assert.deepEqual(runner.subprocessCommandMetadata('docker',['volume','inspect','private-volume']),{executable:'docker',dockerOperation:'volume.inspect',fixtureRole:null,commandKind:null});
  assert.deepEqual(runner.subprocessCommandMetadata('docker',['private-operation','private-token']),{executable:'docker',dockerOperation:'unclassified',fixtureRole:null,commandKind:null});
  assert.deepEqual(runner.subprocessCommandMetadata('private-executable',[]),{executable:'unclassified',dockerOperation:null,fixtureRole:null,commandKind:null});
  assert.deepEqual(runner.subprocessCommandMetadata('docker',['volume','private-operation']),{executable:'docker',dockerOperation:'unclassified',fixtureRole:null,commandKind:null});
});

test('owned Docker targets expose only the exact fixture role and fixed exec command kind',()=>{
  const uuid='12345678-1234-4234-8234-123456789abc';
  for(const role of ['db','auth','capture','network','data','storage','rest','realtime','guard','issuer','drift-db','drift-auth','drift-data']){
    const name='mort-mobile-auth-guard-qa-'+role+'-'+uuid;
    const observed=runner.subprocessCommandMetadata('docker',['inspect','--format','private-template',name]);
    assert.equal(observed.fixtureRole,role);assert.equal(observed.commandKind,null);
    assert.ok(!JSON.stringify(observed).includes(uuid));assert.ok(!JSON.stringify(observed).includes('private-template'));
  }
  for(const kind of ['psql','pg_isready','sh','node']){
    const observed=runner.subprocessCommandMetadata('docker',['exec','-i','mort-mobile-auth-guard-qa-db-'+uuid,kind,'private-argument']);
    assert.equal(observed.fixtureRole,'db');assert.equal(observed.commandKind,kind);
    assert.ok(!JSON.stringify(observed).includes('private-argument'));
  }
  const volume=runner.subprocessCommandMetadata('docker',['volume','inspect','mort-mobile-auth-guard-qa-data-'+uuid]);
  assert.equal(volume.fixtureRole,'data');assert.equal(volume.commandKind,null);
});

test('private and malformed Docker names cannot appear in role or command metadata',()=>{
  const uuid='12345678-1234-4234-8234-123456789abc',owned='mort-mobile-auth-guard-qa-db-'+uuid;
  for(const name of ['private-container','C:/private-path/'+owned,owned+'-private-suffix','private-prefix-'+owned,
    'mort-mobile-auth-guard-qa-private-role-'+uuid,owned.replace('4234','1234'),owned.replace('8234','7234'),owned+'\n']){
    const observed=runner.subprocessCommandMetadata('C:/private-path/docker.exe',['exec',name,'/private-path/psql']);
    assert.equal(observed.fixtureRole,null);assert.equal(observed.commandKind,'unclassified');
    assert.ok(!JSON.stringify(observed).includes('private'));assert.ok(!JSON.stringify(observed).includes(uuid));
  }
  // A matching string in an option or in the child arguments is not the target.
  assert.equal(runner.subprocessCommandMetadata('docker',['inspect','--format',owned,'private-container']).fixtureRole,null);
  assert.equal(runner.subprocessCommandMetadata('docker',['exec','private-container','node',owned]).fixtureRole,null);
  assert.equal(runner.subprocessCommandMetadata('docker',['inspect',owned,'private-container']).fixtureRole,null);
  assert.equal(runner.subprocessCommandMetadata('docker',['exec','--private-option',owned,'psql']).fixtureRole,null);
});

test('async lifecycle starts before child completion and preserves signal/status metadata',async()=>{
  implementation();const logger=mock.method(console,'error',()=>{});
  try{
    const child=runner.spawn(process.execPath,['-e',"process.stdin.once('data',()=>{process.stderr.write('async-private-secret');process.exit(4)})"],{timeout:1500,stdio:['pipe','pipe','pipe'],windowsHide:true});
    assert.equal(metadata(logger,'started').length,1);assert.equal(metadata(logger,'completed').length,0);
    const closed=once(child,'close');child.stdin.end('private-input');const [status,signal]=await closed;
    const [completed]=metadata(logger,'completed');assert.equal(completed.api,'spawn');
    assert.equal(completed.timeoutMs,1500);assert.equal(completed.diagnostic.status,status);assert.equal(completed.diagnostic.signal,signal);
    assert.ok(Number.isFinite(completed.elapsedMs)&&completed.elapsedMs>=0);
    assert.ok(!JSON.stringify(logger.mock.calls).includes('async-private-secret'));
  }finally{logger.mock.restore();}
});

test('exec timeout completion retains safe timeout and original native exception',()=>{
  implementation();const logger=mock.method(console,'error',()=>{});
  try{
    assert.throws(()=>runner.execFileSync(process.execPath,['-e','setInterval(()=>{},1000)'],{timeout:20,stdio:'ignore',windowsHide:true}),error=>error.code==='ETIMEDOUT');
    const [start]=metadata(logger,'started'),[completed]=metadata(logger,'completed');
    assert.equal(start.api,'execFileSync');assert.equal(start.timeoutMs,20);
    assert.equal(completed.diagnostic.category,'timeout');assert.equal(completed.diagnostic.errorCode,'ETIMEDOUT');
    assert.ok(completed.elapsedMs>=0);assert.equal(completed.stderrAvailable,true);
    assert.ok(!JSON.stringify(logger.mock.calls).includes('setInterval'));
  }finally{logger.mock.restore();}
});

test('exec timeout records its original timeout code without printing synthetic arguments',()=>{
  implementation();const logger=mock.method(console,'error',()=>{});
  try{
    assert.throws(()=>runner.execFileSync(process.execPath,['-e','setInterval(()=>{},1000)'],{timeout:20,stdio:'ignore',windowsHide:true}),error=>error.code==='ETIMEDOUT');
    assert.equal(parsed(logger).errorCode,'ETIMEDOUT');assert.ok(!diagnostic(logger).includes('setInterval'));
  }finally{logger.mock.restore();}
});
