import assert from 'node:assert/strict';
import {test,mock} from 'node:test';
import {createHash} from 'node:crypto';
import {spawnSync} from 'node:child_process';

let subprocessDiagnostic,recordSubprocessFailure;
try{({subprocessDiagnostic,recordSubprocessFailure}=await import('./subprocess-diagnostic.mjs'));}
catch(error){if(error.code!=='ERR_MODULE_NOT_FOUND')throw error;}
const diagnose=result=>{
  assert.equal(typeof subprocessDiagnostic,'function','Redacted child diagnostics must exist');
  return subprocessDiagnostic(result);
};
test('Storage direct-delete protection is classified without exposing provider details',()=>{
  const r=diagnose({status:3,stderr:'ERROR: Direct deletion from storage tables is not allowed. Use the Storage API instead.\nprivate provider detail'});
  assert.deepEqual(r.stderrCategories,['storage_delete_protected']);
});
test('SMTP fixed categories survive redaction while arbitrary SMTP details do not',()=>{
  const result=diagnose({status:1,stderr:'Fixture SMTP failed: class=socket\nFixture SMTP failed: class=private-value\n'});
  assert.deepEqual(result.reviewedLines,['Fixture SMTP failed: class=socket']);
});

test('nonzero child status retains exit metadata and stderr fingerprint without arbitrary values',()=>{
  const stderr='private-fixture-secret\nprivate@example.invalid\n';
  const result=diagnose({status:7,signal:null,stderr,error:undefined});
  assert.equal(result.category,'exit_code');assert.equal(result.status,7);
  assert.equal(result.signal,null);assert.equal(result.errorCode,null);
  assert.equal(result.stderrBytes,Buffer.byteLength(stderr));
  assert.equal(result.stderrSha256,createHash('sha256').update(stderr).digest('hex'));
  assert.deepEqual(result.reviewedLines,[]);
  assert.ok(!JSON.stringify(result).includes('private-fixture-secret'));
  assert.ok(!JSON.stringify(result).includes('private@example.invalid'));
});

test('reviewed failure lines retain exact fixed labels and reject secret-bearing suffixes',()=>{
  const stderr=[
    'Fixture ingress diagnostic: stage=delivery name=Error code=ECONNREFUSED',
    'error: Uncaught (in promise) Error: Fixture ingress assertion failed: delivery',
    'Recovery control failed: replacement password signs in',
    'Recovery control failed: private secret words',
    'Recovery control failed: replacement password signs in private-secret',
    'Fixture ingress diagnostic: stage=private-secret name=Error code=ECONNREFUSED',
    'Fixture ingress diagnostic: stage=delivery name=Error code=PRIVATESECRET',
    'Fixture ingress assertion failed: delivery private-secret',
  ].join('\n');
  const result=diagnose({status:1,stderr});
  assert.deepEqual(result.reviewedLines,[
    'Fixture ingress diagnostic: stage=delivery name=Error code=ECONNREFUSED',
    'Fixture ingress assertion failed: delivery',
    'Recovery control failed: replacement password signs in',
  ]);
  assert.ok(!JSON.stringify(result).includes('private-secret'));
  assert.ok(!JSON.stringify(result).includes('private secret words'));
  assert.ok(!JSON.stringify(result).includes('PRIVATESECRET'));
});

test('timeout and spawn errors expose only allowlisted codes and signals',()=>{
  const timeout=diagnose({status:null,signal:'SIGTERM',error:{code:'ETIMEDOUT',message:'private-secret'},stderr:null});
  assert.equal(timeout.category,'timeout');assert.equal(timeout.status,null);
  assert.equal(timeout.signal,'SIGTERM');assert.equal(timeout.errorCode,'ETIMEDOUT');
  assert.equal(timeout.stderrBytes,0);
  assert.equal(diagnose({status:null,error:{code:'ENOENT'}}).category,'spawn_error');
  assert.equal(diagnose({status:null,signal:'SIGKILL'}).category,'signal');
  const unknown=diagnose({status:'private-secret',signal:'PRIVATESECRET',error:{code:'PRIVATESECRET'}});
  assert.equal(unknown.category,'unknown_failure');assert.equal(unknown.status,null);
  assert.equal(unknown.signal,'unclassified');assert.equal(unknown.errorCode,'unclassified');
  assert.ok(!JSON.stringify(unknown).includes('PRIVATESECRET'));
});

test('buffer stderr and repeated reviewed diagnostics produce bounded output',()=>{
  const stderr=Buffer.from(('Fixture ingress assertion failed: receipt\r\n').repeat(100));
  const result=diagnose({status:1,stderr});
  assert.equal(result.stderrBytes,stderr.length);
  assert.deepEqual(result.reviewedLines,['Fixture ingress assertion failed: receipt']);
  assert.equal(diagnose({status:0,stderr:''}).category,'success');
});

test('real failing subprocess emits a usable redacted diagnostic without its synthetic secret',()=>{
  const child=spawnSync(process.execPath,['-e',"process.stderr.write('synthetic-private-secret\\nFixture ingress assertion failed: trusted-relay\\n');process.exit(9)"],{encoding:'utf8',windowsHide:true});
  const result=diagnose(child);
  assert.equal(result.category,'exit_code');assert.equal(result.status,9);
  assert.deepEqual(result.reviewedLines,['Fixture ingress assertion failed: trusted-relay']);
  assert.ok(!JSON.stringify(result).includes('synthetic-private-secret'));
});

test('failure recorder emits safe metadata and leaves successful subprocesses silent',()=>{
  const logger=mock.method(console,'error',()=>{});
  try{
    const failed={status:3,stderr:'recorder-private-secret',stdout:'stdout-private-secret',error:{code:'PRIVATESECRET',message:'error-private-secret'}};
    assert.equal(recordSubprocessFailure(failed),failed);
    recordSubprocessFailure({status:0,stderr:'successful-private-secret'});
    assert.equal(logger.mock.callCount(),1);
    const output=logger.mock.calls[0].arguments.join(' ');
    assert.ok(output.startsWith('Fixture subprocess failed: '));
    assert.ok(output.includes('"status":3'));assert.ok(output.includes('"errorCode":"unclassified"'));
    for(const value of ['recorder-private-secret','stdout-private-secret','error-private-secret','successful-private-secret','PRIVATESECRET'])assert.ok(!output.includes(value));
  }finally{logger.mock.restore();}
});

test('database stderr failures expose fixed classes without identifiers or SQL values',()=>{
  const cases=[
    ['ERROR: policy "private-secret-policy" already exists','duplicate_object'],
    ['ERROR: function private_secret_fn(text) does not exist','undefined_function'],
    ['ERROR: relation "private_secret_table" does not exist','undefined_object'],
    ['ERROR: permission denied for schema private_secret_schema','permission_denied'],
    ['ERROR: must be owner of table private_secret_table','permission_denied'],
    ['ERROR: cannot drop function private_secret_fn() because other objects depend on it','dependency'],
    ['ERROR: syntax error at or near "private-secret-value"','syntax'],
    ['psql: error: connection to server at "private-secret-host" failed: Connection refused','connection'],
  ];
  for(const [stderr,category] of cases){
    const result=diagnose({status:1,stderr});
    assert.deepEqual(result.stderrCategories,[category]);
    assert.ok(!JSON.stringify(result).includes('private-secret'));
    assert.ok(!JSON.stringify(result).includes('private_secret'));
  }
  assert.deepEqual(diagnose({status:1,stderr:'arbitrary private-secret words'}).stderrCategories,[]);
});

test('store initialization stderr retains reviewed classes and measured elapsed time without arbitrary values',()=>{
  const stderr=[
    'Fixture store initialization failed: class=connection_deadline sqlstate=none elapsedMs=104',
    'Fixture store initialization failed: class=database_sqlstate sqlstate=42P01 elapsedMs=17',
    'Fixture store initialization failed: class=database_sqlstate sqlstate=unclassified elapsedMs=17',
    'Fixture store initialization failed: class=private-secret sqlstate=none elapsedMs=104',
    'Fixture store initialization failed: class=database_sqlstate sqlstate=S3CR3 elapsedMs=17',
    'Fixture store initialization failed: class=query_deadline sqlstate=none elapsedMs=1000 private-secret',
  ].join('\n');
  const result=diagnose({status:1,stderr});
  assert.deepEqual(result.reviewedLines,stderr.split('\n').slice(0,3));
  assert.ok(!JSON.stringify(result).includes('private-secret'));
  assert.ok(!JSON.stringify(result).includes('S3CR3'));
});
