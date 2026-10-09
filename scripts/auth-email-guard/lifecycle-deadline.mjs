export function lifecycleDeadline(sample,lifecycleAtMs){
  const limitMs=30000;
  const observations=Object.fromEntries(['postgrest','storage','realtime'].map(name=>{
    const value=sample?.[name];
    const elapsedMs=value?.checkedAtMs-lifecycleAtMs;
    const denied=name==='realtime'?['error','http_401','http_403'].includes(value?.status):value?.denied===true;
    return [name,{denied,elapsedMs:Number.isFinite(elapsedMs)?elapsedMs:null,withinDeadline:Number.isFinite(lifecycleAtMs)&&Number.isFinite(elapsedMs)&&elapsedMs>=0&&elapsedMs<=limitMs}];
  }));
  return {policy:'REFUSE_PROTECTED_TRANSPORTS_WITHIN_30_SECONDS',limitMs,passed:Object.values(observations).every(value=>value.denied&&value.withinDeadline),observations};
}
