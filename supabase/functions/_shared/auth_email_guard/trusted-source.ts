export type TrustedSourceConfig={mode:'local_fixture';header:string;trustedPeers:readonly string[];key:CryptoKey};
const deny=():never=>{throw Error('Source unavailable')};
function bucket(value:string):string{
 if(value.includes(':')){
  if(!/^[0-9a-fA-F:]+$/.test(value))return deny();let canonical:string;try{canonical=new URL('http://['+value+']/').hostname.slice(1,-1)}catch{return deny()}
  const halves=canonical.split('::');if(halves.length>2)return deny();const left=halves[0]?halves[0].split(':'):[],right=halves.length===2&&halves[1]?halves[1].split(':'):[];
  const words=halves.length===2?[...left,...Array(8-left.length-right.length).fill('0'),...right]:left;if(words.length!==8)return deny();return words.slice(0,4).map(x=>x.padStart(4,'0')).join(':')+'/64';
 }
 const parts=value.split('.');if(parts.length!==4||parts.some(x=>!/^\d{1,3}$/.test(x)||(x.length>1&&x[0]==='0')||Number(x)>255))return deny();return parts.join('.');
}
export async function trustedSource(request:Request,actualPeer:string,config:TrustedSourceConfig):Promise<string>{
 // actualPeer is supplied by the socket-owning runtime. Never derive it from request headers.
 if(config.mode!=='local_fixture'||!/^x-mort-fixture-[a-z-]+$/.test(config.header)||!config.trustedPeers.includes(actualPeer)||config.key.algorithm.name!=='HMAC'||!config.key.usages.includes('sign'))return deny();
 const value=request.headers.get(config.header);if(!value||value.length>64||value!==value.trim())return deny();const identity=bucket(value);const digest=await crypto.subtle.sign('HMAC',config.key,new TextEncoder().encode(JSON.stringify(['mort-source-v1',identity])));return Array.from(new Uint8Array(digest),x=>x.toString(16).padStart(2,'0')).join('');
}
export async function directPeerSource(actualPeer:string,key:CryptoKey):Promise<string>{
 const request=new Request('http://127.0.0.1',{headers:{'x-mort-fixture-peer':actualPeer}});return await trustedSource(request,actualPeer,{mode:'local_fixture',header:'x-mort-fixture-peer',trustedPeers:[actualPeer],key});
}
