const failure=()=>{throw new Error('Session evidence incomplete or unsafe');};
export function sessionLiveCharacterization(value){
  if(value?.jwtLifetimeSeconds!==3600||value.scope!=='owned SELECT private GET new private joins'||value.hostedChanged!==false)failure();
  const output={status:'LOCAL_NAMED_ASSERTIONS_EXECUTED',jwtLifetimeSeconds:3600,scope:value.scope,hostedChanged:false};
  for(const event of ['revocation','passwordChange','restore']){
    output[event]={};
    for(const name of ['postgrest','storage','realtime']){
      const probe=value[event]?.[name];
      if(probe?.denied!==true||!Number.isFinite(probe.measuredAfterLifecycleMs)||probe.measuredAfterLifecycleMs<0)failure();
      if(name==='realtime'?probe.status!=='error':![200,400,401,403,404].includes(probe.status))failure();
      output[event][name]={status:probe.status,denied:true,measuredAfterLifecycleMs:probe.measuredAfterLifecycleMs};
    }
  }
  if(value.earlySamples!==undefined){
    output.earlySamples={};
    for(const event of ['revocation','passwordChange','restore']){
      const samples=value.earlySamples[event];
      if(!Array.isArray(samples)||samples.length!==2)failure();
      output.earlySamples[event]=samples.map((sample,index)=>{
        const targetOffsetMs=index===0?5000:30000;
        if(sample.targetOffsetMs!==targetOffsetMs||sample.freshControlsPassed!==true||sample.predicateDenied!==true)failure();
        const observations={};
        for(const name of ['postgrest','storage','realtime']){
          const observed=sample.observations?.[name];
          if(!Number.isFinite(observed?.measuredAfterLifecycleMs)||observed.measuredAfterLifecycleMs<targetOffsetMs||(name==='realtime'?observed.status!=='error':![200,400,401,403,404].includes(observed.status)))failure();
          observations[name]={status:observed.status,measuredAfterLifecycleMs:observed.measuredAfterLifecycleMs};
        }
        const reason={};
        for(const field of ['sessionPresent','passwordFenceRejects','restoreFenceRejects','accountActive']){
          if(typeof sample.reason?.[field]!=='boolean')failure();
          reason[field]=sample.reason[field];
        }
        if(!reason.accountActive||(event==='revocation'?reason.sessionPresent:event==='passwordChange'?(reason.sessionPresent&&!reason.passwordFenceRejects):(!reason.sessionPresent||!reason.restoreFenceRejects)))failure();
        return {targetOffsetMs,freshControlsPassed:true,predicateDenied:true,observations,reason};
      });
    }
  }
  return output;
}
