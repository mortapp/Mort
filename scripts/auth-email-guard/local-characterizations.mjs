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
  return output;
}
