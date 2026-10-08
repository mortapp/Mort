export function createChallengeTransport(config,request=fetch){
  if(config?.mode!=='local_fixture'||config.endpoint!=='http://127.0.0.1:55426')throw new Error('Guard transport unavailable.');
  const post=async(route,value,parent)=>{
    const response=await request(config.endpoint+route,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify(value),credentials:'omit',cache:'no-store',redirect:'error',referrerPolicy:'no-referrer',signal:AbortSignal.any([parent,AbortSignal.timeout(15000)])});
    if(![200,400,429].includes(response.status))throw new Error('Guard transport unavailable.');
    const reader=response.body?.getReader();if(!reader)throw new Error('Guard transport unavailable.');
    let size=0;const parts=[];
    try {
      while(true){const {done,value:chunk}=await reader.read();if(done)break;size+=chunk.length;if(size>16384)throw new Error('Guard transport unavailable.');parts.push(chunk);}
    }finally{await reader.cancel().catch(()=>{});reader.releaseLock();}
    const bytes=new Uint8Array(size);let offset=0;for(const chunk of parts){bytes.set(chunk,offset);offset+=chunk.length;}
    let data;try{data=JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(bytes));}catch{throw new Error('Guard transport unavailable.');}
    if(!data||typeof data!=='object'||Array.isArray(data)||typeof data.ok!=='boolean'||(response.status===200)!==data.ok||response.status===429&&(data.message!=='MORT is busy. Try again shortly.'||data.retryAfterSeconds!==1))throw new Error('Guard transport unavailable.');
    return data;
  };
  return {continue:(value,signal)=>post('/continue',value,signal),password:(value,signal)=>post('/password',value,signal)};
}
