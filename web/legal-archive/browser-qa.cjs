const {chromium}=require('@playwright/test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
fs.mkdirSync('qa-artifacts',{recursive:true});
const sharp=require('sharp');
(async()=>{
const browser=await chromium.launch({args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
const page=await browser.newPage({viewport:{width:1440,height:900}});const errors=[];page.on('pageerror',e=>errors.push(e.message));
const base=process.env.LEGAL_QA_URL||'http://127.0.0.1:4175';
const routes=['/','/privacy/','/terms/','/terms-of-use/','/community-guidelines/','/safety/','/child-safety-standards/','/prohibited-jobs/','/payment-disputes/','/account-deletion/','/support/','/contact/','/accessibility/'];
await page.emulateMedia({reducedMotion:'reduce'});
for(const route of routes){
 const response=await page.goto(base+route);assert.equal(response.status(),200,route);
 assert.equal(await page.locator('h1').count(),1,route);assert(await page.locator('main').isVisible());
 for(const width of [390,1440]){await page.setViewportSize({width,height:900});assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),route+' overflow '+width);}
 if(['/','/privacy/','/terms/','/account-deletion/'].includes(route)){
 await page.screenshot({path:'qa-artifacts/legal-final-'+(route.replaceAll('/','')||'home')+'.png'});
 await page.locator('#reading').scrollIntoViewIfNeeded();await page.screenshot({path:'qa-artifacts/legal-reading-'+(route.replaceAll('/','')||'home')+'.png'});
 }
}
await page.goto(base);for(const width of [390,430,768,1024,1366,1440,1920,2560]){await page.setViewportSize({width,height:900});assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),'archive width '+width);}
await page.setViewportSize({width:1440,height:900});await page.emulateMedia({reducedMotion:'no-preference'});
await page.waitForFunction(()=>document.body.classList.contains('has-webgl'));
await page.waitForTimeout(1800);const clip={x:900,y:130,width:450,height:570};
const a=await page.screenshot({clip,path:'qa-artifacts/archive-idle-a.png'});await page.waitForTimeout(3000);const b=await page.screenshot({clip,path:'qa-artifacts/archive-idle-b.png'});
const aa=await sharp(a).removeAlpha().raw().toBuffer(),bb=await sharp(b).removeAlpha().raw().toBuffer();let changed=0;for(let i=0;i<aa.length;i+=3)if(Math.abs(aa[i]-bb[i])+Math.abs(aa[i+1]-bb[i+1])+Math.abs(aa[i+2]-bb[i+2])>20)changed++;
const fraction=changed/(aa.length/3);assert(fraction>.012,'idle fraction '+fraction);console.log('archive motion',fraction);
await page.getByRole('button',{name:'Pause atmosphere',exact:true}).click();await page.waitForTimeout(600);const pa=await page.screenshot({clip});await page.waitForTimeout(600);assert(pa.equals(await page.screenshot({clip})),'pause must freeze');
await page.reload();assert(await page.getByRole('button',{name:'Resume atmosphere',exact:true}).isVisible());await page.getByRole('button',{name:'Resume atmosphere',exact:true}).click();
await page.screenshot({path:'qa-artifacts/legal-final-home-animated.png'});
await page.mouse.move(1260,520);await page.mouse.move(1160,580);assert.equal(Number(await page.locator('canvas').getAttribute('data-energy')),0);
await page.mouse.down({button:'right'});await page.mouse.move(1200,650);await page.mouse.up({button:'right'});assert.equal(Number(await page.locator('canvas').getAttribute('data-energy')),0);
await page.mouse.down();await page.mouse.move(950,550,{steps:2});await page.waitForFunction(()=>Number(document.querySelector('canvas').dataset.energy)>0);await page.mouse.up();
await page.waitForFunction(()=>Number(document.querySelector('canvas').dataset.energy)<.001,{timeout:20000});
await page.locator('canvas').evaluate(c=>c.getContext('webgl2')?.getExtension('WEBGL_lose_context')?.loseContext());await page.waitForFunction(()=>!document.body.classList.contains('has-webgl'));
await page.keyboard.press('Tab');await page.getByRole('link',{name:'Skip to content',exact:true}).focus();await page.keyboard.press('Enter');assert(await page.locator('#content').evaluate(e=>e===document.activeElement));
await page.setViewportSize({width:390,height:844});await page.screenshot({path:'qa-artifacts/legal-final-fallback-mobile.png'});
const touch=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
const tp=await touch.newPage();await tp.goto(base);await tp.waitForFunction(()=>document.body.classList.contains('has-webgl'));
await tp.screenshot({path:'qa-artifacts/legal-final-mobile-animated.png'});
const cdp=await touch.newCDPSession(tp);
await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:60,y:650}]});
for(let i=1;i<=5;i++)await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:60+i*45,y:651}]});
await tp.waitForFunction(()=>Number(document.querySelector('canvas').dataset.energy)>.001);
await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:180,y:620}]});
for(let i=1;i<=8;i++)await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:181,y:620-i*35}]});
await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
await tp.waitForFunction(()=>scrollY>30);await touch.close();
assert.deepEqual(errors,[]);console.log('PASS 13 routes, 8 widths, motion, pause persistence, primary/right/hover, touch intent/native scroll, context loss, skip link; no client errors');await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});
