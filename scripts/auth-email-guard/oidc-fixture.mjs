import {createServer} from 'node:http';
import {generateKeyPairSync,randomUUID,sign} from 'node:crypto';
import {assertMortAuthFixture} from './fixture.mjs';

export async function startOidcFixture(handle){
  assertMortAuthFixture(handle,handle.observed);
  const {privateKey,publicKey}=generateKeyPairSync('rsa',{modulusLength:2048});
  const kid=randomUUID();
  const subjects=new Map();
  const issuer='http://host.docker.internal:55428';
  const jwk={...publicKey.export({format:'jwk'}),kid,alg:'RS256',use:'sig'};
  const server=createServer((request,response)=>{
    response.setHeader('content-type','application/json');response.setHeader('cache-control','no-store');
    if(request.method==='GET'&&request.url==='/.well-known/openid-configuration'){
      response.end(JSON.stringify({issuer,jwks_uri:`${issuer}/jwks`,authorization_endpoint:`${issuer}/authorize`,token_endpoint:`${issuer}/token`,response_types_supported:['code'],subject_types_supported:['public'],id_token_signing_alg_values_supported:['RS256']}));
    }else if(request.method==='GET'&&request.url==='/jwks')response.end(JSON.stringify({keys:[jwk]}));
    else{response.statusCode=404;response.end('{}');}
  });
  await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(55428,'127.0.0.1',resolve);});
  return {issuer,close:()=>new Promise(resolve=>server.close(resolve)),token(email,verified,audience='mort-fixture-client'){
    if(!/^qa-[0-9a-f-]+@mort-fixture\.invalid$/.test(email))throw new Error('Synthetic OIDC account required');
    const now=Math.floor(Date.now()/1000);
    if(!['mort-fixture-client','fixture-other-client'].includes(audience))throw new Error('Synthetic OIDC audience required');
    if(!subjects.has(email))subjects.set(email,randomUUID());
    const head=Buffer.from(JSON.stringify({alg:'RS256',typ:'JWT',kid})).toString('base64url');
    const body=Buffer.from(JSON.stringify({iss:issuer,aud:audience,sub:subjects.get(email),iat:now,exp:now+60,email,email_verified:verified})).toString('base64url');
    return `${head}.${body}.${sign('RSA-SHA256',Buffer.from(`${head}.${body}`),privateKey).toString('base64url')}`;
  }};
}
