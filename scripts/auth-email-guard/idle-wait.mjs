export async function idleUntil(expiryMs,{wallNow=Date.now,monoNow=()=>performance.now(),sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms)),emit=row=>console.log('HEARTBEAT guarded expiry: '+JSON.stringify(row))}={}){
  let wall=wallNow(),mono=monoNow();
  while(wall<expiryMs){
    await sleep(Math.min(30000,expiryMs-wall));
    const nextWall=wallNow(),nextMono=monoNow();
    emit({timestamp:new Date(nextWall).toISOString(),gapMs:nextWall-wall,monotonicGapMs:Math.round(nextMono-mono),remainingMs:Math.max(0,expiryMs-nextWall)});
    wall=nextWall;mono=nextMono;
  }
}
