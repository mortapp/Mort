import assert from 'node:assert/strict';
import {AuthClient} from '@supabase/supabase-js';
import {createHmac} from 'node:crypto';
import {startFixture} from './fixture.mjs';
import {pending,call,signIn,cleanup} from './provider.test.mjs';
import {captureAssertions} from './evidence.mjs';
export async function run(handle){
 let owner;const client=new AuthClient({url:handle.authUrl,headers:{apikey:handle.anonKey},autoRefreshToken:false,persistSession:false,detectSessionInUrl:false});
 try{
  owner=await pending(handle);assert.equal((await call(handle,'/admin/users/'+owner.id,{email_confirm:true},true,'PUT')).status,200,'Synthetic fixture owner confirmed');
  const signed=await signIn(handle,owner,owner.password);assert.equal(signed.status,200,'Real provider issues fixture session');const token=signed.data.access_token;
  const valid=await client.getUser(token);assert.equal(valid.error,null,'getUser valid token positive control');assert.equal(valid.data.user.id,owner.id,'getUser verifies correct synthetic owner');
  const service=await client.getUser(handle.serviceKey);assert.ok(service.error&&service.data.user===null,'helperEvaluatesUserNotServiceJwt');
  const claims=JSON.parse(Buffer.from(token.split('.')[1],'base64url'));const encoded=Buffer.from(JSON.stringify({...claims,iat:Math.floor(Date.now()/1000)-120,exp:Math.floor(Date.now()/1000)-1})).toString('base64url');const unsigned=token.split('.')[0]+'.'+encoded;const expired=unsigned+'.'+createHmac('sha256',handle.jwtSecret).update(unsigned).digest('base64url');handle.privateAudit.add(expired);const gone=await client.getUser(expired);assert.ok(gone.error&&gone.data.user===null,'getUser expired fixture-signed negative control');
  const logout=await fetch(handle.authUrl+'/logout?scope=global',{method:'POST',headers:{authorization:'Bearer '+token},signal:AbortSignal.timeout(4000)});assert.equal(logout.status,204,'Real global provider revocation');
  const revoked=await client.getUser(token);assert.ok(revoked.error&&revoked.data.user===null,'getUserRejectsRevokedSession');
  const fresh=await signIn(handle,owner,owner.password);assert.equal(fresh.status,200,'Fresh session issued after revocation');const current=await client.getUser(fresh.data.access_token);assert.equal(current.error,null,'Fresh getUser positive control after revocation');assert.equal(current.data.user.id,owner.id,'Fresh session identity preserved');
  handle.sdkSessionEvidence={sdk:'@supabase/supabase-js installed AuthClient',validAccepted:true,serviceRejected:true,expiredRejected:true,revokedRejected:true,freshAccepted:true,expiredControl:'manually fixture-signed expired token; not provider issuance'};
 }finally{await cleanup(handle)}
}
if(process.argv[1]?.replaceAll('\\','/').endsWith('/sdk-session.test.mjs')){try{const handle=await startFixture();const assertions=await captureAssertions('sdk-session',()=>run(handle));console.log(JSON.stringify({status:'PASS',assertions:assertions.length,evidence:handle.sdkSessionEvidence}));}catch(e){console.error(JSON.stringify({status:'FAIL',assertion:e.guardAssertion??null,name:e.name==='AssertionError'?'AssertionError':'Error'}));process.exitCode=1}}
