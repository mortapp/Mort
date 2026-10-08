import assert from 'node:assert/strict';
import {spawn,execFileSync} from 'node:child_process';
import {createServer} from 'node:net';
import {resolve} from 'node:path';
import {assertMortAuthFixture,fixtureProcessEnv,observeFixture} from './fixture.mjs';
import {pending,cleanup} from './provider.test.mjs';
export async function run(handle){
  assertMortAuthFixture(handle,handle.observed);
  try{
    const user=await pending(handle),certificate=resolve(import.meta.dirname,'../../.superpowers/sdd/2026-10-08-managed-email-challenge-guard/fixture/smtp.pem');
    const child=spawn('deno',['run','--frozen','--config','supabase/functions/auth-email-guard.deno.json','--allow-env',`--allow-read=${certificate}`,'--allow-net=127.0.0.1:55422,127.0.0.1:55424,127.0.0.1:55425','supabase/functions/_shared/auth_email_guard/delivery_probe.ts'],{env:{...fixtureProcessEnv(),MORT_FIXTURE_VERIFIED:'1'},windowsHide:true,stdio:['pipe','pipe','pipe']});
    let output='',errors='';child.stdout.on('data',bytes=>{output+=bytes;if(output.length>8192)child.kill();});child.stderr.on('data',bytes=>{errors+=bytes;if(errors.length>8192)child.kill();});
    const timer=setTimeout(()=>child.kill(),45_000);
    const exited=new Promise((resolve,reject)=>{child.once('error',()=>reject(new Error('Fixture delivery runtime could not start')));child.once('exit',code=>resolve(code));});
    child.stdin.end(JSON.stringify({mode:'local_fixture',fixtureId:handle.fixtureId,dbUrl:handle.dbUrl,certificate,accountId:user.id,recipient:user.email}));
    let status;try{status=await exited;}finally{clearTimeout(timer);}
    if(errors.trim()==='Private context positive')console.log('FAIL owned delivery stage: missing private context adapter');
    assert.ok(status===0&&output.trim()==='PASS isolated signed-hook/encrypted-queue/SMTP-delivery integration','Actual isolated encrypted delivery must pass without exposing runtime secrets');console.log(output.trim());
    await stalledSocket(handle,certificate);
  }finally{await cleanup(handle);}
}
async function stalledSocket(handle,certificate){
  const current=await observeFixture();assertMortAuthFixture(handle,current.observed);
  const capture=current.observed.resourceIds.find(id=>id.includes('-capture-'));
  assert.ok(capture?.endsWith(handle.fixtureId),'Protocol stall requires the exact owned capture resource');
  const dockerArgs={env:fixtureProcessEnv(),stdio:'ignore',windowsHide:true,timeout:20_000};
  let server,child;const sockets=new Set(),drips=new Set();let restored=false;
  try{
    // Only this disposable capture is paused; normal MORT/Loop remain untouched.
    execFileSync('docker',['stop','--time','1',capture],dockerArgs);
    let received=0,accepted=0,authoritySent=false;
    server=createServer(socket=>{
      accepted++;sockets.add(socket);let drip;
      socket.write('220 owned fixture SMTP ready\r\n');
      socket.on('data',bytes=>{
        received+=bytes.length;const command=bytes.toString();if(/AUTH |MAIL FROM|RCPT TO|DATA/i.test(command))authoritySent=true;
        if(!drip&&command.startsWith('EHLO')){
          socket.write('250-owned fixture\r\n');
          // Keep progress/idle timers alive without completing EHLO/TLS.
          drip=setInterval(()=>socket.write('250-PIPELINING\r\n'),100);drips.add(drip);
        }
      });
      socket.on('close',()=>{sockets.delete(socket);if(drip){clearInterval(drip);drips.delete(drip);}});socket.on('error',()=>{});
    });
    await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(55425,'127.0.0.1',resolve);});
    child=spawn('deno',['run','--frozen','--config','supabase/functions/auth-email-guard.deno.json','--allow-env',`--allow-read=${certificate}`,'--allow-net=127.0.0.1:55425','supabase/functions/_shared/auth_email_guard/smtp_timeout_probe.ts'],{env:{...fixtureProcessEnv(),MORT_FIXTURE_VERIFIED:'1'},windowsHide:true,stdio:['pipe','pipe','pipe']});
    let output='',observed=false,closedAtDeadline=false;
    child.stdout.on('data',bytes=>{output+=bytes;if(output.includes('PASS isolated SMTP deadline')&&!observed){observed=true;setTimeout(()=>{closedAtDeadline=accepted===1&&sockets.size===0&&received>0&&!authoritySent;},100);}});
    child.stderr.on('data',()=>{});const timer=setTimeout(()=>child.kill(),20_000);
    const exited=new Promise((resolve,reject)=>{child.once('error',reject);child.once('exit',resolve);});
    child.stdin.end(JSON.stringify({mode:'local_fixture',certificate}));let status;try{status=await exited;}finally{clearTimeout(timer);}
    assert.ok(status===0&&closedAtDeadline,'Deadline must destroy the actual socket before process exit or SMTP greeting timeout');
    console.log('PASS actual SMTP deadline destroys stalled owned socket before process exit');
  }finally{
    child?.kill();for(const drip of drips)clearInterval(drip);for(const socket of sockets)socket.destroy();
    if(server?.listening)await new Promise(resolve=>server.close(resolve));
    execFileSync('docker',['start',capture],dockerArgs);restored=true;
    await observeFixture();
    if(!restored)throw new Error('Fixture capture restoration failed');
  }
}
