import {test} from 'node:test';import assert from 'node:assert/strict';import {readFile} from 'node:fs/promises';
let api={};try{api=await import('./request-gate-load.mjs');}catch(e){if(e.code!=='ERR_MODULE_NOT_FOUND')throw e;}
test('bounded request gate load caps concurrency requests wall time and preserves positive controls',async()=>{
  assert.equal(typeof api.measureRequestGateLoad,'function');
  let active=0,maximum=0,count=0;
  const result=await api.measureRequestGateLoad({setEnabled:async()=>{},request:async()=>{active++;maximum=Math.max(active,maximum);count++;await new Promise(r=>setTimeout(r,1));active--;return {status:200,elapsedMs:2};}});
  assert.equal(count,400);assert.ok(maximum<=20);assert.equal(result.poolMax,8);assert.equal(result.wallBudgetMs,60000);assert.equal(result.off.samples,200);assert.equal(result.on.samples,200);assert.equal(result.on.p95Ms,2);
  await assert.rejects(api.measureRequestGateLoad({setEnabled:async()=>{},request:async()=>({status:401,elapsedMs:1})}));
  let clock=0;await assert.rejects(api.measureRequestGateLoad({now:()=>clock+=60001,setEnabled:async()=>{},request:async()=>({status:200,elapsedMs:1})}));
});
test('pinned request fixture explicitly caps PostgREST pool at eight',async()=>{
  assert.ok(/PGRST_DB_POOL: ['"]?8['"]?(?:\r?\n)/.test(await readFile('scripts/auth-email-guard/compose.yaml','utf8')),'Pinned request pool must not exceed eight');
});
