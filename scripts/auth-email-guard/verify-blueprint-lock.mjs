import {createHash} from 'node:crypto';
import {readFile} from 'node:fs/promises';
import {resolve} from 'node:path';
const sha=value=>createHash('sha256').update(value).digest('hex');
export function makeLock(parts){
 const sections=[];
 for(const [part,text] of parts.entries()){
  const lines=text.replace(/\r\n/g,'\n').split('\n');
  for(let i=0;i<lines.length;i++){
   const header=/^(#{1,6}) (.+)$/.exec(lines[i]);
   if(!header||!header[2].includes('[IMMUTABLE]'))continue;
   let end=i+1;
   for(;end<lines.length;end++){const next=/^(#{1,6}) /.exec(lines[end]);if(next&&next[1].length<=header[1].length)break;}
   sections.push({part:part+1,heading:header[2],sha256:sha(lines.slice(i,end).join('\n'))});
  }
 }
 if(!sections.length)throw new Error('Immutable blueprint sections missing');
 return {schema:1,algorithm:'SHA-256',normalization:'CRLF to LF only',sections,sha256:sha(JSON.stringify(sections))};
}
export function verifyLock(parts,lock){
 const observed=makeLock(parts);
 if(JSON.stringify(observed)!==JSON.stringify(lock))throw new Error('Immutable blueprint mismatch; hard stop');
 return true;
}
export async function verifyBlueprintLock(){
 const directory=new URL('../../docs/security/auth-guard-blueprint/',import.meta.url);
 const parts=await Promise.all(['PART1.md','PART2.md'].map(file=>readFile(new URL(file,directory),'utf8')));
 const lock=JSON.parse(await readFile(new URL('blueprint.lock',directory),'utf8'));
 verifyLock(parts,lock);return lock.sha256;
}
if(process.argv[1]&&resolve(process.argv[1])===resolve(import.meta.filename)){
 try{console.log('PASS immutable blueprint lock '+await verifyBlueprintLock());}
 catch{console.error('FAIL immutable blueprint lock; hard stop');process.exitCode=1;}
}
