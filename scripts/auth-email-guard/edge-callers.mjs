import {readFile} from 'node:fs/promises';import {createHash} from 'node:crypto';
const registry=JSON.parse(await readFile(new URL('./edge-callers.json',import.meta.url),'utf8'));
export async function verifyEdgeCallers(read=p=>readFile(p,'utf8')){
 const failures=[],entries=[],excluded=[];const shared={stripe:await read('supabase/functions/_shared/stripe.ts'),support:await read('supabase/functions/_shared/support_runtime.ts'),play:await read('supabase/functions/_shared/google_play.ts')};
 const users=new Set([...((shared.support.match(/const userOperations[\s\S]*?\]\);/)||[])[0]||'').matchAll(/"([a-z-]+)"/g)].map(x=>x[1]));
 for(const item of registry.entries){const source=await read(item.path),user=item.caller.startsWith('USER_SESSION');let verified=false,mechanism='';
  if(source.includes('auth.getUser(')){verified=true;mechanism='direct-getUser'}
  else if(source.includes('"../_shared/stripe.ts"')&&/await authenticate\(request\)/.test(source)){verified=shared.stripe.includes('auth.getUser(accessToken)')&&shared.stripe.includes('if (error || !data.user)');mechanism='shared-stripe-getUser'}
  else if(source.includes('"../_shared/google_play.ts"')&&/await authenticate\(request\)/.test(source)){verified=shared.play.includes('auth.getUser(token)')&&shared.play.includes('if (error || !data.user)');mechanism='shared-play-getUser'}
  else if(source.includes('serveSupportFunction(')){const operation=source.match(/serveSupportFunction\("([a-z-]+)"\)/)?.[1];verified=users.has(operation)&&shared.support.includes('auth.getUser(token)')&&shared.support.includes('await userContext(request, traceId)');mechanism=users.has(operation)?'shared-support-user':'shared-support-internal'}
  if(user&&!verified)failures.push({path:item.path,reason:'verified-user-check-missing'});
  if(item.caller==='USER_SESSION_PLUS_OPERATIONS_SECRET'&&!source.includes('requireOperationsSecret(request);'))failures.push({path:item.path,reason:'hybrid-operations-check-missing'});
  if(!user){const unchanged=createHash('sha256').update(source).digest('hex')===item.baselineSha256;excluded.push({path:item.path,unchanged});if(!unchanged)failures.push({path:item.path,reason:'excluded-caller-changed'});if(verified)failures.push({path:item.path,reason:'excluded-user-classification-conflict'});}
  entries.push({...item,observedMechanism:mechanism||item.mechanism,sourceSha256:createHash('sha256').update(source).digest('hex'),userVerifierPresent:verified});
 }
 return {entries,excluded,userCount:entries.filter(x=>x.caller.startsWith('USER_SESSION')).length,failures};
}
