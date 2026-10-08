import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {assertMortAuthFixture,fixtureProcessEnv} from './fixture.mjs';
import {pending,call,cleanup} from './provider.test.mjs';
export async function run(handle){
  assertMortAuthFixture(handle,handle.observed);
  try {
    const accounts=[];
    for(let i=0;i<2;i++){
      const account=await pending(handle);accounts.push({id:account.id,recipient:account.email});
      assert.ok((await call(handle,`/admin/users/${account.id}`,{email_confirm:true},true,'PUT')).status===200,'Owned load account positive setup');
    }
    const child=spawn('deno',['run','--frozen','--config','supabase/functions/auth-email-guard.deno.json','--allow-env','--allow-net=127.0.0.1:55422,127.0.0.1:55426','supabase/functions/_shared/auth_email_guard/load_probe.ts'],{env:{...fixtureProcessEnv(),MORT_FIXTURE_VERIFIED:'1'},windowsHide:true,stdio:['pipe','pipe','pipe']});
    let output='',error='';child.stdout.on('data',bytes=>{output+=bytes;if(output.length>8192)child.kill();});child.stderr.on('data',bytes=>{error+=bytes;if(error.length>8192)child.kill();});
    const deadline=setTimeout(()=>child.kill(),60000),exited=new Promise((resolve,reject)=>{child.once('error',()=>reject(new Error('Fixture load process unavailable')));child.once('exit',resolve);});
    child.stdin.end(JSON.stringify({mode:'local_fixture',fixtureId:handle.fixtureId,dbUrl:handle.dbUrl,accounts}));
    let code;try{code=await exited;}finally{clearTimeout(deadline);}
    assert.ok(code===0&&output.trim()==='PASS bounded actual HTTP load: source isolation, non-charged Busy, bounded denial and legitimate post-load consume','Bounded actual gateway load must pass');console.log(output.trim());
  }finally{await cleanup(handle);}
}
