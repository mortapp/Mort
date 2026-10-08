import assert from 'node:assert/strict';
import {call,pending,cleanup} from './provider.test.mjs';
import {auditFixtureLogs} from './log-audit.mjs';
export async function run(handle){
  const since=new Date().toISOString();
  try{
    const user=await pending(handle);await call(handle,'/token?grant_type=password',{email:user.email,password:user.password});
    assert.ok(auditFixtureLogs(handle,since),'Owned provider, database and SMTP logs contain no tracked credentials or full synthetic recipients');
    console.log('PASS actual fixture runtime log audit: values never exported');
  }finally{await cleanup(handle);}
}
