import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,readFile,rm,realpath} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join,sep} from 'node:path';
import {buildGuardPages} from './build.mjs';
test('guard page builder defaults off; explicit fixture build has no third-party SDK, query authority or weak headers',async()=>{
  const dir=await mkdtemp(join(tmpdir(),'mort-guard-page-test-'));
  try{
    assert.equal(buildGuardPages(dir,{mode:'disabled'}).enabled,false);
    assert.throws(()=>buildGuardPages(dir,{mode:'local_fixture',endpoint:'https://untrusted.invalid'}));
    const result=buildGuardPages(dir,{mode:'local_fixture',endpoint:'http://127.0.0.1:55426'});assert.equal(result.enabled,true);
    for(const purpose of ['confirmation','recovery']){
      const html=await readFile(join(dir,'auth',purpose,'index.html'),'utf8');assert.match(html,/aria-live="polite"/);assert.match(html,/Press Continue/);assert.match(html,/new-password/);assert.ok(!html.includes('cdn.jsdelivr')&&!html.includes('window.supabase')&&!html.includes('access_token'));
    }
    const rules=JSON.parse(await readFile(join(dir,'auth','challenge','headers.json'),'utf8'));
    assert.equal(rules['Cache-Control'],'no-store');assert.equal(rules['Referrer-Policy'],'no-referrer');assert.match(rules['Content-Security-Policy'],/frame-ancestors 'none'/);assert.match(rules['Content-Security-Policy'],/worker-src 'none'/);
    const css=await readFile(join(dir,'auth','challenge','style.css'),'utf8');assert.match(css,/success/);assert.match(css,/error/);
  }finally{const absolute=await realpath(dir),parent=await realpath(tmpdir());if(!absolute.startsWith(parent+sep+'mort-guard-page-test-'))throw new Error('Temporary cleanup target refused');await rm(absolute,{recursive:true});}
});
