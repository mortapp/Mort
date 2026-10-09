import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {createRequire} from 'node:module';
import {randomBytes,randomUUID,createHash} from 'node:crypto';
import {mkdtemp,readFile,realpath,rm} from 'node:fs/promises';
import {join,sep,resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {buildGuardPages} from './build.mjs';
const check=(condition,message)=>assert.ok(condition,message);
const listen=server=>new Promise((resolve,reject)=>{server.once('error',reject);server.listen(0,'127.0.0.1',resolve);});
const close=server=>new Promise(resolve=>{server.closeAllConnections();server.close(resolve);});
test('disposable real browser: scanner/reload/back make no redemption; human-only POST, memory verifier, green/red and headers', {timeout:60000},async()=>{
  const dir=await mkdtemp(join(tmpdir(),'mort-guard-browser-test-'));let browser,site,gateway;
  try {
    const bundle=process.env.MORT_GUARD_BROWSER_MODULES;
    const require=bundle?createRequire(join(resolve(bundle),'package.json')):createRequire(import.meta.url);
    const {chromium}=require('playwright');
    const {headers}=buildGuardPages(dir,{mode:'local_fixture',endpoint:'http://127.0.0.1:55426'});
    const requests=[],posts=[];let reply='busy',verifierHash,cap=randomBytes(32).toString('base64url');
    site=createServer(async(req,res)=>{
      try{
        const path=new URL(req.url,'http://localhost').pathname;
        if(path==='/blank'){res.writeHead(200,{'Content-Type':'text/html',...headers});res.end('<!doctype html><html lang="en"><title>Fixture blank</title><p>Fixture navigation</p></html>');return;}
        const name=path.endsWith('/')?path+'index.html':path;
        if(!/^\/auth\/(?:confirmation\/index\.html|recovery\/index\.html|password-policy\.mjs|challenge\/[a-z-]+\.(?:mjs|css))$/.test(name)){res.writeHead(404);res.end();return;}
        const bytes=await readFile(join(dir,name));res.writeHead(200,{...headers,'Content-Type':name.endsWith('.html')?'text/html':name.endsWith('.css')?'text/css':'text/javascript'});res.end(bytes);
      }catch{res.writeHead(404);res.end();}
    });await listen(site);const base='http://127.0.0.1:'+site.address().port;
    gateway=createServer(async(req,res)=>{
      res.setHeader('Access-Control-Allow-Origin',base);res.setHeader('Access-Control-Allow-Headers','content-type');res.setHeader('Cache-Control','no-store');
      if(req.method==='OPTIONS'){res.writeHead(204);res.end();return;}
      const parts=[];let size=0;for await(const part of req){size+=part.length;if(size>16384){res.writeHead(400);res.end();return;}parts.push(part);}
      const data=JSON.parse(Buffer.concat(parts).toString('utf8'));posts.push({path:req.url,data});
      const out=reply==='busy'?{ok:false,message:'MORT is busy. Try again shortly.',retryAfterSeconds:1}:reply==='deny'?{ok:false,message:'That request is not valid.'}:req.url==='/continue'?{ok:true,capability:cap,purpose:'confirmation',maskedRecipient:'q***@example.invalid',familyExpiresAt:new Date(Date.now()+600000).toISOString(),capabilityExpiresAt:new Date(Date.now()+300000).toISOString()}:{ok:true,message:'Password updated. Return to MORT to sign in.'};
      res.writeHead(reply==='busy'?429:reply==='deny'?400:200,{'Content-Type':'application/json'});res.end(JSON.stringify(out));
    });await new Promise((resolve,reject)=>{gateway.once('error',reject);gateway.listen(55426,'127.0.0.1',resolve);});
    browser=await chromium.launch({headless:true});const context=await browser.newContext({serviceWorkers:'block'}),page=await context.newPage();
    context.on('request',req=>requests.push({url:req.url(),method:req.method(),headers:req.headers(),resourceType:req.resourceType()}));
    const link=randomBytes(32).toString('base64url'),id=randomUUID(),url=base+'/auth/confirmation/#itemId='+id+'&linkSecret='+link;
    await page.goto(url);await page.waitForFunction(()=>location.hash==='');check(posts.length===0,'Page load performs no redemption');
    check((await page.locator('#status').textContent()).includes('Press Continue'),'Neutral human-click message');
    check(!await page.locator('#password-form').isVisible(),'No initial password verification');
    await page.locator('#continue').click();await page.waitForFunction(()=>document.getElementById('status').textContent.includes('busy'));
    check(posts.length===1,'One explicit Continue request');verifierHash=posts[0].data.verifierHash;
    reply='success';await page.locator('#continue').click();await page.locator('#password-form').waitFor({state:'visible'});
    check(posts.length===2&&posts[1].data.verifierHash===verifierHash,'Busy preserves verifier binding');
    check((await page.locator('#status').textContent()).includes('replace'),'Confirmation requires password replacement');
    check(await page.locator('#deadlines').isVisible(),'Server deadlines visible');
    const password='FixtureOnly!'+randomBytes(16).toString('hex');
    await page.locator('#password').fill(password);await page.locator('#confirmation').fill(password);await page.locator('#update').click();
    await page.waitForFunction(()=>document.getElementById('status').classList.contains('success'));
    check(posts.length===3&&posts[2].path==='/password','Password sent only by explicit POST');
    check(posts[2].data.capability===cap&&posts[2].data.password===password,'Only current in-memory authority sent');
    check(createHash('sha256').update(posts[2].data.verifier).digest('hex')===verifierHash,'Actual browser verifier binds to Continue digest');
    check(await page.locator('#password').inputValue()===''&&await page.locator('#confirmation').inputValue()==='','Password fields cleared');
    const publicHtml=await page.content();check(![link,cap,password,posts[2].data.verifier].some(value=>publicHtml.includes(value)),'No secret retained in DOM');
    check(await page.evaluate(()=>localStorage.length===0&&sessionStorage.length===0),'No web storage');
    await page.reload();await page.waitForFunction(()=>document.getElementById('status').textContent.includes('Press Continue'));await page.locator('#continue').click();check(posts.length===3,'Reload cannot replay or rebind');
    await page.goto(base+'/blank');await page.goBack();await page.locator('#continue').waitFor();await page.locator('#continue').click();check(posts.length===3,'Back navigation cannot restore capability');
    await page.goto(base+'/auth/recovery/?token=discard#itemId='+id+'&linkSecret='+link);await page.waitForFunction(()=>document.getElementById('status').classList.contains('error'));
    check(posts.length===3&&!page.url().includes('?')&&!page.url().includes('#'),'Query authority refused and history stripped');
    reply='deny';await page.goto(url);await page.locator('#continue').click();await page.waitForFunction(()=>document.getElementById('status').classList.contains('error'));
    check((await page.locator('#status').textContent()).startsWith('✕'),'Failure has text/icon as well as red');
    check(await page.locator('#status').getAttribute('aria-live')==='polite','Status announced');
    check(requests.every(req=>![link,cap,password,posts[2].data.verifier].some(value=>req.url.includes(value)||(req.headers.referer??'').includes(value))),'No secret in request URLs/referrers');
    check(requests.every(req=>req.url.startsWith(base+'/')||req.url.startsWith('http://127.0.0.1:55426/')),'No third-party network');
    assert.deepEqual([...new Set(requests.filter(req=>req.resourceType==='script').map(req=>new URL(req.url).pathname))].sort(),['/auth/challenge/config.mjs','/auth/challenge/controller.mjs','/auth/challenge/page.mjs','/auth/challenge/transport.mjs','/auth/password-policy.mjs'],'Actual local auth origin loads exactly the approved script inventory');
    check((await page.evaluate(()=>navigator.serviceWorker.getRegistrations().then(rows=>rows.length)))===0,'Disposable auth origin has no registered service worker');
    const response=await fetch(base+'/auth/recovery/');check(response.headers.get('cache-control')==='no-store'&&response.headers.get('referrer-policy')==='no-referrer','Runtime security headers');
    await context.close();
  }catch{throw new Error('Disposable guard browser assertion/setup failed (redacted).');}
  finally{
    await browser?.close();if(gateway)await close(gateway);if(site)await close(site);
    const absolute=await realpath(dir),parent=await realpath(tmpdir());if(!absolute.startsWith(parent+sep+'mort-guard-browser-test-'))throw new Error('Temporary cleanup target refused');await rm(absolute,{recursive:true});
  }
});
