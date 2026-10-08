import {copyFileSync,mkdirSync,readFileSync,writeFileSync} from 'node:fs';
import {dirname,join,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
const here=dirname(fileURLToPath(import.meta.url));
export function buildGuardPages(output,{mode='disabled',endpoint}={}){
  // This generator cannot activate a hosted guard or overwrite the provider pages by default.
  if(mode==='disabled')return {enabled:false};
  if(mode!=='local_fixture'||endpoint!=='http://127.0.0.1:55426')throw new Error('Guard page configuration unavailable.');
  const root=resolve(output),assets=join(root,'auth','challenge');mkdirSync(assets,{recursive:true});
  for(const name of ['controller.mjs','transport.mjs','page.mjs','style.css'])copyFileSync(join(here,name),join(assets,name));
  copyFileSync(join(here,'..','password-policy.mjs'),join(root,'auth','password-policy.mjs'));
  writeFileSync(join(assets,'config.mjs'),`export default ${JSON.stringify({mode,endpoint})};\n`);
  const headers={
    'Cache-Control':'no-store', 'Referrer-Policy':'no-referrer', 'X-Content-Type-Options':'nosniff',
    'Content-Security-Policy':`default-src 'none'; script-src 'self'; style-src 'self'; connect-src ${endpoint}; img-src 'none'; font-src 'none'; frame-src 'none'; frame-ancestors 'none'; worker-src 'none'; base-uri 'none'; form-action 'none'`,
    'Permissions-Policy':'camera=(), microphone=(), geolocation=()',
  };
  writeFileSync(join(assets,'headers.json'),JSON.stringify(headers,null,2)+'\n');
  const template=readFileSync(join(here,'page.html'),'utf8');
  for(const purpose of ['confirmation','recovery']){
    const target=join(root,'auth',purpose);mkdirSync(target,{recursive:true});
    writeFileSync(join(target,'index.html'),template.replaceAll('{{title}}',purpose==='confirmation'?'Confirm your email':'Choose a new password'));
  }
  return {enabled:true,headers};
}
