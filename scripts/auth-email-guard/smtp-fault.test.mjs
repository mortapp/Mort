import assert from 'node:assert/strict';
import {readFile,unlink} from 'node:fs/promises';
import {createServer} from 'node:net';
import {TLSSocket,createSecureContext} from 'node:tls';
import {spawn,execFileSync} from 'node:child_process';
import {resolve} from 'node:path';
import {randomUUID} from 'node:crypto';
import {assertMortAuthFixture,observeFixture,fixtureProcessEnv} from './fixture.mjs';
import {fixtureDirectory} from './control.mjs';
export async function run(handle){
  const current=await observeFixture();assertMortAuthFixture(handle,current.observed);
  const capture=current.observed.resourceIds.find(name=>name.includes('-capture-'));
  const certificate=resolve(fixtureDirectory,'smtp.pem'),key=resolve(fixtureDirectory,'smtp.key');
  const wrong=resolve(fixtureDirectory,`wrong-ca-${randomUUID()}`);
  const args={env:fixtureProcessEnv(),stdio:'ignore',windowsHide:true,timeout:20000};
  const openssl=process.platform==='win32'?'C:\\Program Files\\Git\\usr\\bin\\openssl.exe':'openssl';
  execFileSync(openssl,['req','-x509','-newkey','rsa:2048','-nodes','-days','1','-keyout',wrong+'.key','-out',wrong+'.pem','-subj','/CN=unrelated-synthetic-ca'],args);
  const secureContext=createSecureContext({cert:await readFile(certificate),key:await readFile(key)});
  try{
    execFileSync('docker',['stop','--time','1',capture],args);
    for(const mode of ['auth','certificate','downgrade']){
      const sockets=new Set();let server,child,authSeen=false,tlsSeen=false,mailSeen=false;
      try{
        server=createServer(socket=>{
          sockets.add(socket);socket.on('close',()=>sockets.delete(socket));socket.on('error',()=>{});
          socket.write('220 owned fixture SMTP\r\n');
          function commands(peer,encrypted){
            let buffer='';
            const onData=bytes=>{
              buffer+=bytes.toString();if(buffer.length>8192){peer.destroy();return;}
              while(buffer.includes('\r\n')){
                const index=buffer.indexOf('\r\n'),line=buffer.slice(0,index);buffer=buffer.slice(index+2);
                if(line.startsWith('EHLO'))peer.write(encrypted?'250-owned fixture\r\n250 AUTH PLAIN\r\n':mode==='downgrade'?'250 owned fixture\r\n':'250-owned fixture\r\n250 STARTTLS\r\n');
                else if(line==='STARTTLS'){
                  tlsSeen=true;
                  if(mode==='downgrade'){peer.write('454 TLS unavailable\r\n');continue;}
                  peer.removeListener('data',onData);peer.write('220 begin TLS\r\n');
                  const tls=new TLSSocket(peer,{isServer:true,secureContext});sockets.add(tls);tls.on('error',()=>{});tls.on('close',()=>sockets.delete(tls));commands(tls,true);return;
                }else if(line.startsWith('AUTH ')){authSeen=true;peer.write('535 authentication denied\r\n');}
                else if(/^(MAIL|RCPT|DATA)/.test(line)){mailSeen=true;peer.write('550 prohibited\r\n');}
                else if(line==='QUIT'){peer.end('221 bye\r\n');}
                else peer.write('500 command unavailable\r\n');
              }
            };peer.on('data',onData);
          }commands(socket,false);
        });
        await new Promise((done,reject)=>{server.once('error',reject);server.listen(55425,'127.0.0.1',done);});
        const ca=mode==='certificate'?wrong+'.pem':certificate;
        child=spawn('deno',['run','--frozen','--config','supabase/functions/auth-email-guard.deno.json','--allow-env',`--allow-read=${ca}`,'--allow-net=127.0.0.1:55425','supabase/functions/_shared/auth_email_guard/smtp_fault_probe.ts'],{env:{...fixtureProcessEnv(),MORT_FIXTURE_VERIFIED:'1'},windowsHide:true,stdio:['pipe','pipe','pipe']});
        let output='';child.stdout.on('data',data=>{output+=data;if(output.length>4096)child.kill();});child.stderr.on('data',()=>{});
        const timer=setTimeout(()=>child.kill(),15000),exited=new Promise((done,reject)=>{child.once('error',reject);child.once('exit',done);});
        child.stdin.end(JSON.stringify({mode:'local_fixture',fault:mode,certificate:ca}));let status;try{status=await exited;}finally{clearTimeout(timer);}
        assert.ok(status===0&&output.trim()==='PASS owned SMTP fault rejected','Actual owned SMTP fault produces no delivery acknowledgment');
        assert.ok(tlsSeen&&!mailSeen&&(mode==='auth'?authSeen:!authSeen),'Authentication failure, untrusted certificate and TLS downgrade send no email DATA');
      }finally{child?.kill();for(const socket of sockets)socket.destroy();if(server?.listening)await new Promise(done=>server.close(done));}
    }
    console.log('PASS actual SMTP fault boundaries: bad authentication, certificate trust and STARTTLS downgrade, no email DATA');
  }finally{
    execFileSync('docker',['start',capture],args);await observeFixture();
    await unlink(wrong+'.key');await unlink(wrong+'.pem');
  }
}
