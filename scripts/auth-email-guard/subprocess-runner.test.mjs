import assert from 'node:assert/strict';
import {test,mock} from 'node:test';
import {once} from 'node:events';
let runner;
try{runner=await import('./subprocess-runner.mjs');}catch(error){if(error.code!=='ERR_MODULE_NOT_FOUND')throw error;}
const implementation=()=>assert.ok(runner,'Shared subprocess runner must exist');
const diagnostic=logger=>logger.mock.calls.map(call=>call.arguments.join(' ')).find(line=>line.startsWith('Fixture subprocess failed: '));
const parsed=logger=>JSON.parse(diagnostic(logger).slice('Fixture subprocess failed: '.length));

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

test('successful sync exec preserves string return and stays silent',()=>{
  implementation();const logger=mock.method(console,'error',()=>{});
  try{
    assert.equal(runner.execFileSync(process.execPath,['-e',"process.stdout.write('synthetic-success')"],{encoding:'utf8',windowsHide:true}),'synthetic-success');
    assert.equal(logger.mock.callCount(),0);
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
    assert.equal(error.code,'ENOENT');assert.equal(logger.mock.callCount(),1);
    assert.equal(parsed(logger).errorCode,'ENOENT');assert.ok(!diagnostic(logger).includes('synthetic-private-missing-command'));
  }finally{logger.mock.restore();}
});

test('exec timeout records its original timeout code without printing synthetic arguments',()=>{
  implementation();const logger=mock.method(console,'error',()=>{});
  try{
    assert.throws(()=>runner.execFileSync(process.execPath,['-e','setInterval(()=>{},1000)'],{timeout:20,stdio:'ignore',windowsHide:true}),error=>error.code==='ETIMEDOUT');
    assert.equal(parsed(logger).errorCode,'ETIMEDOUT');assert.ok(!diagnostic(logger).includes('setInterval'));
  }finally{logger.mock.restore();}
});
