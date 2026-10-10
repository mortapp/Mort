const concurrency=20,samplesPerMode=200,wallBudgetMs=60000;
const summarize=samples=>{const ordered=[...samples].sort((a,b)=>a-b);return {samples:samples.length,p50Ms:ordered[Math.ceil(samples.length*.5)-1],p95Ms:ordered[Math.ceil(samples.length*.95)-1]};};
export async function measureRequestGateLoad({request,setEnabled,now=()=>performance.now()}){
  const began=now(),signal=AbortSignal.timeout(wallBudgetMs);let primary,result;
  const check=()=>{if(signal.aborted||now()-began>=wallBudgetMs)throw new Error('Request gate load wall budget exceeded');};
  try{
    const profiles={};
    for(const mode of ['off','on']){
      check();await setEnabled(mode==='on');check();
      let next=0,failure;const samples=[];
      const outcomes=await Promise.allSettled(Array.from({length:concurrency},async()=>{
        while(next<samplesPerMode&&!failure){
          const index=next++;try{check();const value=await request(signal,index);check();
            if(value?.status!==200||!Number.isFinite(value.elapsedMs)||value.elapsedMs<0)throw new Error('Request gate live positive control failed');
            samples.push(value.elapsedMs);
          }catch(e){failure=e;throw e;}
        }
      }));
      if(failure||outcomes.some(r=>r.status==='rejected')||samples.length!==samplesPerMode)throw failure??new Error('Request gate incomplete sample');
      profiles[mode]=summarize(samples);
    }
    result={...profiles,requests:samplesPerMode*2,concurrency,poolMax:8,wallBudgetMs,scope:'client-observed owner table GET; off then on; overhead included',delta:{p50Ms:profiles.on.p50Ms-profiles.off.p50Ms,p95Ms:profiles.on.p95Ms-profiles.off.p95Ms}};
  }catch(e){primary=e;}
  try{await setEnabled(true);check();}catch(e){if(!primary)primary=e;}
  if(primary)throw primary;
  return {...result,elapsedMs:now()-began};
}
