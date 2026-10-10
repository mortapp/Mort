import WebSocket from 'ws';import {randomUUID} from 'node:crypto';
export async function openNativeChannel(handle,token,id,{published=false}={}){
  const topic='realtime:guard-native:'+id;
  const ws=new WebSocket(`ws://127.0.0.1:55433/socket/websocket?apikey=${handle.anonKey}&vsn=1.0.0`,{headers:{Host:'realtime-dev.localhost'}});
  const subscribers=new Set();let closed=false;
  ws.on('message',bytes=>{let m;try{m=JSON.parse(bytes.toString())}catch{return}for(const f of [...subscribers])f(m);});
  ws.on('error',()=>{});ws.on('close',()=>{closed=true;for(const f of [...subscribers])f({event:'fixture_closed'});});
  const wait=(predicate,ms=4000)=>new Promise(resolve=>{
    let timer;const listener=m=>{const value=predicate(m);if(value!==undefined)finish(value);};
    function finish(value){clearTimeout(timer);subscribers.delete(listener);resolve(value);}
    subscribers.add(listener);timer=setTimeout(()=>finish('timeout'),ms);if(closed)finish('closed');
  });
  const joined=wait(m=>m.event==='phx_reply'&&m.ref==='1'?m.payload?.status:m.event==='fixture_closed'?'closed':undefined,8000);
  ws.on('open',()=>ws.send(JSON.stringify({topic,event:'phx_join',ref:'1',payload:{access_token:token,config:{private:true,broadcast:{self:true,ack:true},presence:{enabled:false},postgres_changes:published?[{event:'*',schema:'mort_transport',table:'native_published',filter:'owner=eq.'+id}]:[]}}})));
  ws.on('unexpected-response',(_request,response)=>{response.resume();ws.terminate();});
  const status=await joined;
  const close=()=>{if(!closed){closed=true;ws.terminate();}};
  if(status!=='ok'){close();return {status,close,broadcast:async()=> 'closed',reauthorize:async()=>{},waitChange:async()=> 'closed'};}
  return {
    status,close,
    broadcast:async()=>{
      if(closed||ws.readyState!==WebSocket.OPEN)return 'closed';
      const marker=randomUUID(),ref=randomUUID();
      const observed=wait(m=>m.event==='broadcast'&&m.payload?.event==='fixture-probe'&&m.payload?.payload?.marker===marker?'received':m.event==='phx_reply'&&m.ref===ref&&m.payload?.status==='error'?'refused':m.event==='fixture_closed'?'closed':undefined);
      ws.send(JSON.stringify({topic,event:'broadcast',ref,payload:{type:'broadcast',event:'fixture-probe',payload:{marker}}}));return await observed;
    },
    waitChange:value=>wait(m=>m.event==='postgres_changes'&&(m.payload?.data?.record?.value??m.payload?.data?.new?.value??m.payload?.record?.value)===value?'received':m.event==='fixture_closed'?'closed':undefined),
    reauthorize:async next=>{
      if(closed||ws.readyState!==WebSocket.OPEN)return;
      ws.send(JSON.stringify({topic,event:'access_token',ref:randomUUID(),payload:{access_token:next}}));
      await new Promise(r=>setTimeout(r,500));
    },
  };
}
